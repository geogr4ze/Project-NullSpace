extends Node
#Test System
var test_enable: bool = false # Enable explicitly to run the test wave.
var test_random: bool = true
var selection_T: int = 5
var test_SN: int = 20
const WaveLoader = preload("res://scripts/waves/wave_loader.gd")
const WaveSpawner = preload("res://scripts/waves/wave_spawner.gd")

#Wave System
var wave: int = 1
const max_wave: int = 50
var spawnrate: float = 0.01 # in seconds
# Enemy types must be declared before the initial value.
enum {BASIC = 0, SPEED, SUPPORT, TANK, RAILGUN, MINESHIP}
var enemy: int = BASIC
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Enemy dictionary: speed, score, reward, health, and animation.
var enemies: Dictionary = {
	BASIC: {"id": "basic", "threat": 1, "enemy_speed": 0.45, "score": 1, "reward": 1, "health": 3, "enemy_skin": "basic"}, 
	SPEED: {"id": "speed", "threat": 2, "enemy_speed": 1.8, "speed_multiplier": 1.5, "score": 2, "reward": 3, "health": 2, "enemy_skin": "speed"},
	SUPPORT: {"id": "support", "threat": 4, "enemy_speed": 0.1, "score": 4, "reward": 10, "health": 20, "enemy_skin": "support"},
	TANK: {"id": "tank", "threat": 7, "enemy_speed": 0.2, "score": 8, "reward": 30, "health": 75, "enemy_skin": "tank"},
	RAILGUN: {"id": "railgun", "threat": 9, "enemy_speed": 0.05, "score": 20, "reward": 40, "health": 100, "enemy_skin": "railgun"},
	MINESHIP: {"id": "mineship", "threat": 6, "enemy_speed": 0.1, "score": 25, "reward": 35, "health": 50, "enemy_skin": "mineship"}
}
 
## Set the currently selected enemy type number; does not spawn an enemy.
func set_type(type_number: int):
	enemy = type_number

var total_enemy_count: int
var enemy_kc: int = 0
const WAVE_FILE_PATH: String = "res://data/waves/waves.json"
var campaign: Array[Dictionary] = []
# Remaining counts keyed by registered enemy type, not fixed columns.
var enemy_per_round: Dictionary = {}
var max_alive: int = 0
var spawned_enemy_count: int = 0
var wave_threat: int = 0
var selection: int
var spawn_in_progress: bool = false
var wave_active: bool = false
var finished: bool = false
var spawn_generation: int = 0

## Invalidate old spawn sequences and reset campaign state to wave one, including current enemy totals.
func reset_run() -> void:
	spawn_generation += 1
	wave = 1
	enemy = BASIC
	selection = BASIC
	enemy_kc = 0
	spawn_in_progress = false
	wave_active = false
	finished = false
	new_enemy_totals()

## Invalidate outstanding spawn coroutines and mark the run finished/inactive.
func stop_run() -> void:
	spawn_generation += 1
	wave_active = false
	spawn_in_progress = false
	finished = true

## Initialize RNG, load campaign definitions, calculate totals and connect the kill-count signal.
func _ready():
	rng.randomize()
	campaign = WaveLoader.load_campaign(WAVE_FILE_PATH, enemies, max_wave)
	new_enemy_totals()
	Signalbus.kc_point.connect(kill_count)
	# Test spawning is started by Main after its signal handlers are connected.

# Wave completion is checked only when an enemy dies, not every frame.

# Collects total number of enemies that are meant to spawn
## Reset counters and load the current wave's counts, capacity and threat from its campaign definition; leave empty if outside campaign range.
func new_enemy_totals() -> void:
	total_enemy_count = 0
	spawned_enemy_count = 0
	max_alive = 0
	wave_threat = 0
	enemy_per_round.clear()
	if wave < 1 or wave > campaign.size():
		return
	var definition: Dictionary = campaign[wave - 1]
	enemy_per_round = definition["counts"].duplicate()
	total_enemy_count = definition["total"]
	wave_threat = definition["threat"]
	spawnrate = definition["spawn_interval"]
	max_alive = definition["max_alive"]

## Record eligible enemy deaths and advance or finish the campaign when the current wave's total is reached; ignores inactive/test runs and excess counts.
func kill_count() -> void:
	if test_enable or finished or not wave_active or enemy_kc >= spawned_enemy_count:
		return
	enemy_kc += 1
	if enemy_kc < total_enemy_count:
		return
	var completed_wave: int = wave
	spawn_generation += 1
	spawn_in_progress = false
	wave_active = false
	enemy_kc = 0
	wave += 1
	total_enemy_count = 0
	if wave > max_wave:
		stop_run()
		Signalbus.game_over.emit(true)
		return
	new_enemy_totals()
	Signalbus.wave_complete.emit(completed_wave)

# Choose only from enemy types that still have spawns remaining.
## Return a random registered enemy type using the manager RNG.
func get_enemy() -> int:
	var types: Array = enemies.keys()
	return int(types[rng.randi_range(0, types.size() - 1)])

## Choose a remaining enemy type from the current wave via WaveSpawner.
func get_next_wave_enemy() -> int:
	return WaveSpawner.choose_enemy(enemy_per_round, rng)

## Return whether spawned enemies minus recorded kills leave room under max_alive.
func has_spawn_capacity() -> bool:
	return WaveSpawner.has_capacity(spawned_enemy_count, enemy_kc, max_alive)

## Return whether a non-test, unfinished, inactive wave has a valid index and positive enemy count.
func can_start_wave() -> bool:
	return not finished and not test_enable and not wave_active and not spawn_in_progress and wave <= max_wave and total_enemy_count > 0

## Start an eligible wave and asynchronously emit/spawn enemies at configured intervals subject to capacity and generation cancellation. Mutates wave state.
func spawn_enemy() -> void:
	if not can_start_wave():
		return
	wave_active = true
	spawn_in_progress = true
	spawn_generation += 1
	var generation: int = spawn_generation
	Signalbus.next_wave.emit()
	while generation == spawn_generation and wave_active and not finished and spawned_enemy_count < total_enemy_count:
		await get_tree().create_timer(spawnrate, false).timeout
		if generation != spawn_generation or finished or not wave_active:
			return
		if not has_spawn_capacity():
			continue
		var enemy_type: int = get_next_wave_enemy()
		if enemy_type < 0:
			push_error("Wave roster exhausted before expected spawn count")
			break
		enemy_per_round[enemy_type] -= 1
		spawned_enemy_count += 1
		# Mark the final spawn before emitting, in case a listener defeats it immediately.
		if spawned_enemy_count == total_enemy_count:
			spawn_in_progress = false
		Signalbus.new_enemy.emit(enemy_type)
	if generation == spawn_generation:
		spawn_in_progress = false

# Test enemy spawns retain their explicitly selected type.
## Asynchronously spawn configured test enemies, optionally randomized; stop when the spawn generation changes or run finishes.
func test_spawn() -> void:
	spawn_generation += 1
	var generation: int = spawn_generation
	for i: int in test_SN:
		var enemy_type: int = selection_T
		if test_random:
			enemy_type = get_enemy()
		await get_tree().create_timer(0.01, false).timeout
		if generation != spawn_generation or finished:
			return
		Signalbus.new_enemy.emit(enemy_type)
