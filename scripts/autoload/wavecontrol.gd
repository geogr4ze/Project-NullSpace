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
var file_index: int = 0

# Enemy dictionary: speed, score, reward, health, and animation.
var enemies: Dictionary = {
	BASIC: {"enemy_speed": 0.45, "score": 1, "reward": 1, "health": 3, "enemy_skin": "basic"}, 
	SPEED: {"enemy_speed": 1.8, "score": 2, "reward": 3, "health": 2, "enemy_skin": "speed"},
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
var enemy_per_round: Dictionary = {
	"0": 0,
	"1": 0,
	"2": 0,
	"3": 0,
	"4": 0,
	"5": 0 
}
var selection: int
var spawn_in_progress: bool = false

func _ready():
	rng.randomize()
	new_enemy_totals()
	Signalbus.kc_point.connect(kill_count)
	# Test spawning is started by Main after its signal handlers are connected.

# Wave completion is checked only when an enemy dies, not every frame.

# Collects total number of enemies that are meant to spawn
func new_enemy_totals() -> void:
	total_enemy_count = 0
	for i: int in ENEMY_TYPE_COUNT:
		enemy_per_round[str(i)] = 0
	var file: FileAccess = FileAccess.open(wave_file_path, FileAccess.READ)
	if file == null:
		push_error("Could not open wave data: " + wave_file_path)
		return
	file_index = (wave - 1) * ENEMY_TYPE_COUNT
	for i: int in file_index:
		if file.eof_reached():
			push_error("Wave data is missing wave " + str(wave))
			return
		file.get_line()
	for i: int in ENEMY_TYPE_COUNT:
		if file.eof_reached():
			push_error("Missing enemy count for wave " + str(wave) + ", type " + str(i))
			return
		var amount: int = maxi(0, file.get_line().to_int())
		enemy_per_round[str(i)] = amount
		total_enemy_count += amount

# Counter for total enemies that are meant to spawn.
func kill_count() -> void:
	enemy_kc += 1
	if test_enable or total_enemy_count <= 0 or enemy_kc < total_enemy_count:
		return
	Signalbus.wave_complete.emit(wave)
	enemy_kc = 0
	wave += 1
	total_enemy_count = 0
	if wave <= max_wave:
		new_enemy_totals()

# Choose only from enemy types that still have spawns remaining.
func get_enemy() -> int:
	return rng.randi_range(0, ENEMY_TYPE_COUNT - 1)

func get_next_wave_enemy() -> int:
	var remaining: int = 0
	for i: int in ENEMY_TYPE_COUNT:
		remaining += int(enemy_per_round[str(i)])
	if remaining <= 0:
		return -1
	var roll: int = rng.randi_range(0, remaining - 1)
	for i: int in ENEMY_TYPE_COUNT:
		roll -= int(enemy_per_round[str(i)])
		if roll < 0:
			return i
	return -1

func spawn_enemy() -> void:
	if spawn_in_progress or test_enable:
		return
	spawn_in_progress = true
	for i: int in total_enemy_count:
		var enemy_type: int = get_next_wave_enemy()
		if enemy_type < 0:
			break
		enemy_per_round[str(enemy_type)] = int(enemy_per_round[str(enemy_type)]) - 1
		await get_tree().create_timer(spawnrate).timeout
		Signalbus.new_enemy.emit(enemy_type)
	spawn_in_progress = false

# Test enemy spawns retain their explicitly selected type.
func test_spawn() -> void:
	for i: int in test_SN:
		var enemy_type: int = selection_T
		if test_random:
			enemy_type = get_enemy()
		await get_tree().create_timer(0.01).timeout
		Signalbus.new_enemy.emit(enemy_type)
