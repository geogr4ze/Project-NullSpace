extends Node
#Test System
var test_enable = true
var test_random = true
var selection_T = 5
var test_SN = 20

#Wave System
var wave := 1
var max_wave := 25
var spawnrate := 0.01 # in seconds
var enemy = BASIC
var rng = RandomNumberGenerator.new()
var file_index = 0

#Enemy Dictionary(Speed, Score when killed, HP, Skin) and setting enemy
enum{BASIC = 0, SPEED, SUPPORT, TANK, RAILGUN, MINESHIP}
var enemies = {
	BASIC: {"enemy_speed": 0.45, "score": 1, "reward": 1, "health": 3, "enemy_skin": "basic"}, 
	SPEED: {"enemy_speed": 1.6, "score": 2, "reward": 3, "health": 2, "enemy_skin": "speed"},
	SUPPORT: {"enemy_speed": 0.1, "score": 4, "reward": 10, "health": 20, "enemy_skin": "support"},
	TANK: {"enemy_speed": 0.2, "score": 8, "reward": 30, "health": 75, "enemy_skin": "tank"},
	RAILGUN: {"enemy_speed": 0.05, "score": 20, "reward": 40, "health": 100, "enemy_skin": "railgun"},
	MINESHIP: {"enemy_speed": 0.1, "score": 25, "reward": 35, "health": 50, "enemy_skin": "mineship"}
}
 
func set_type(type_number):
	enemy = type_number

var total_enemy_count: int
var enemy_kc = 0
var wave_file_path = "res://Waves/waveinfo.txt"
# Number of enemies meant to spawn that round
var enemy_per_round = {
	"0": 0,
	"1": 0,
	"2": 0,
	"3": 0,
	"4": 0,
	"5": 0 
}
var selection: int

func _ready():
	new_enemy_totals()
	Signalbus.kc_point.connect(kill_count)
	if test_enable:
		test_spawn()
		await get_tree().create_timer(1).timeout
		Signalbus.test_mode.emit()

# Game check for the next wave
func _process(_delta):
	if enemy_kc == total_enemy_count and !test_enable:
		Signalbus.wave_complete.emit(wave)
		enemy_kc = 0
		wave += 1
		total_enemy_count = 0
		if wave <= max_wave:
			new_enemy_totals()
		else: 
			total_enemy_count = 10000 #temperary 

# Collects total number of enemies that are meant to spawn
func new_enemy_totals() -> void:
	var file = FileAccess.open(wave_file_path, FileAccess.READ)
	var line_content = ""
	file_index = (wave - 1) * 6
	for i in file_index:
		line_content = file.get_line()
	for i in 6:
		line_content = file.get_line()
		enemy_per_round[str(i)] = int(line_content)
		total_enemy_count += int(line_content)

# Counter for total enemies that are meant to spawn
func kill_count() -> void:
	enemy_kc += 1

# Randomly selects an enemy and returns the type if its available
func get_enemy() -> int:
	rng.randomize()
	return rng.randi_range(0, 5)

func spawn_enemy() -> void:
	for i in total_enemy_count:
		var reroll = 0
		while enemy_per_round[str(selection)] == 0 and reroll <= 100:
			selection = get_enemy()
			reroll += 1
		await get_tree().create_timer(spawnrate).timeout
		Signalbus.new_enemy.emit()
		enemy_per_round[str(selection)] -= 1

# Test Enemy Function
func test_spawn() -> void:
	for i in test_SN:
		if test_random:
			selection = get_enemy()
		else:
			selection = selection_T
		await get_tree().create_timer(0.01).timeout
		Signalbus.new_enemy.emit()
