extends Node
#Test System
var test_enable: bool = false # Enable explicitly to run the test wave.
var test_random: bool = true
var selection_T: int = 5
var test_SN: int = 20
const ENEMY_TYPE_COUNT: int = 6

#Wave System
var wave: int = 1
var max_wave: int = 25
var spawnrate: float = 0.01 # in seconds
# Enemy types must be declared before the initial value.
enum {BASIC = 0, SPEED, SUPPORT, TANK, RAILGUN, MINESHIP}
var enemy: int = BASIC
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Enemy dictionary: speed, score, reward, health, and animation.
var enemies: Dictionary = {
	BASIC: {"enemy_speed": 0.45, "score": 1, "reward": 1, "health": 3, "enemy_skin": "basic"}, 
	SPEED: {"enemy_speed": 1.8, "speed_multiplier": 1.5, "score": 2, "reward": 3, "health": 2, "enemy_skin": "speed"},
	SUPPORT: {"enemy_speed": 0.1, "score": 4, "reward": 10, "health": 20, "enemy_skin": "support"},
	TANK: {"enemy_speed": 0.2, "score": 8, "reward": 30, "health": 75, "enemy_skin": "tank"},
	RAILGUN: {"enemy_speed": 0.05, "score": 20, "reward": 40, "health": 100, "enemy_skin": "railgun"},
	MINESHIP: {"enemy_speed": 0.1, "score": 25, "reward": 35, "health": 50, "enemy_skin": "mineship"}
}
 
func set_type(type_number: int):
	enemy = type_number

var total_enemy_count: int
var enemy_kc: int = 0
var wave_file_path: String = "res://data/waves/waveinfo.txt"
# Number of enemies meant to spawn that round
var enemy_per_round: Array[int] = []
var selection: int
var spawn_in_progress: bool = false
var wave_active: bool = false
var finished: bool = false
var spawn_generation: int = 0

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

func stop_run() -> void:
	spawn_generation += 1
	wave_active = false
	spawn_in_progress = false
	finished = true

func _ready():
	rng.randomize()
	new_enemy_totals()
	Signalbus.kc_point.connect(kill_count)
	# Test spawning is started by Main after its signal handlers are connected.

# Wave completion is checked only when an enemy dies, not every frame.

# Collects total number of enemies that are meant to spawn
func new_enemy_totals() -> void:
	total_enemy_count = 0
	enemy_per_round.resize(ENEMY_TYPE_COUNT)
	enemy_per_round.fill(0)
	var file: FileAccess = FileAccess.open(wave_file_path, FileAccess.READ)
	if file == null:
		push_error("Could not open wave data: " + wave_file_path)
		return
	for i: int in range(wave - 1):
		if file.eof_reached():
			push_error("Wave data is missing wave " + str(wave))
			return
		file.get_line()
	var counts: PackedStringArray = file.get_line().strip_edges().split(",")
	if counts.size() != ENEMY_TYPE_COUNT:
		push_error("Invalid enemy counts for wave " + str(wave))
		return
	for i: int in ENEMY_TYPE_COUNT:
		if not counts[i].strip_edges().is_valid_int() or counts[i].to_int() < 0:
			push_error("Invalid enemy count for wave " + str(wave))
			enemy_per_round.fill(0)
			total_enemy_count = 0
			return
		enemy_per_round[i] = counts[i].to_int()
		total_enemy_count += enemy_per_round[i]

func kill_count() -> void:
	if test_enable or finished or not wave_active:
		return
	enemy_kc += 1
	if enemy_kc < total_enemy_count:
		return
	var completed_wave: int = wave
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
func get_enemy() -> int:
	return rng.randi_range(0, ENEMY_TYPE_COUNT - 1)

func get_next_wave_enemy() -> int:
	var remaining: int = 0
	for i: int in ENEMY_TYPE_COUNT:
		remaining += enemy_per_round[i]
	if remaining <= 0:
		return -1
	var roll: int = rng.randi_range(0, remaining - 1)
	for i: int in ENEMY_TYPE_COUNT:
		roll -= enemy_per_round[i]
		if roll < 0:
			return i
	return -1

func can_start_wave() -> bool:
	return not finished and not test_enable and not wave_active and not spawn_in_progress and wave <= max_wave and total_enemy_count > 0

func spawn_enemy() -> void:
	if not can_start_wave():
		return
	wave_active = true
	spawn_in_progress = true
	spawn_generation += 1
	var generation: int = spawn_generation
	var count: int = total_enemy_count
	Signalbus.next_wave.emit()
	for i: int in count:
		await get_tree().create_timer(spawnrate, false).timeout
		if generation != spawn_generation or finished:
			return
		var enemy_type: int = get_next_wave_enemy()
		if enemy_type < 0:
			break
		enemy_per_round[enemy_type] -= 1
		Signalbus.new_enemy.emit(enemy_type)
	if generation == spawn_generation:
		spawn_in_progress = false

# Test enemy spawns retain their explicitly selected type.
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
