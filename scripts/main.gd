extends Node2D

var enemy_scene = preload("res://scenes/enemy.tscn")
var bullet_scene = preload("res://scenes/bullet.tscn") 
var portal_scene = preload("res://scenes/portal.tscn")
var score := 0
var bullet_speed: float
var energy_CA: int

func _ready():
	bullet_speed = Modecontrol.modes[0]["bullet_speed"]
	$Player.start($PlayerStartPos.position)
	$UI.update_energy($Player.energy)
	Signalbus.new_enemy.connect(spawn_enemy)
	Signalbus.energy.connect(_on_energy)
	Signalbus.score.connect(_on_score)
	Signalbus.money.connect(_on_money)
	Signalbus.shot.connect(_on_shot)
	Signalbus.mine_dispense.connect(_on_mine_dispense)
	Signalbus.shot_RG.connect(_on_RGshot)
	Signalbus.spawn_energy.connect(_on_spawn_energy)
	Signalbus.next_wave.connect(_on_next_wave)
	Signalbus.energy_low.connect(_on_energy_low)
	Signalbus.player_death.connect(_death)
	Signalbus.dash.connect(_on_dash)
	Modecontrol.mode_changed.connect(_change_bp)

func _death() -> void:
	get_tree().paused = true

func _change_bp(mode) -> void:
	bullet_speed = Modecontrol.modes[mode]["bullet_speed"]

var energy_low = true

func _on_energy_low() -> void:
	if energy_low:
		energy_low = false
		$UI.update_energy_low($Player.energy)
		await get_tree().create_timer(3).timeout
		energy_low = true

func _on_money(reward_amount) -> void:
	Shopcontrol.shopmoney += reward_amount * Shopcontrol.money_multi
	@warning_ignore("narrowing_conversion")
	$UI.update_money(Shopcontrol.shopmoney)

func _on_energy() -> void:
	$UI.update_energy($Player.energy)

func _on_next_wave() -> void:
	$UI.update_wave(Wavecontrol.wave)
	spawn_energy()

func _on_score(score_type) -> void:
	score += score_type
	$UI.update_score(score)

func _on_RGshot(bulletRG) -> void:
	add_child(bulletRG)

func _on_mine_dispense(mine) -> void:
	add_child(mine)

func _on_dash() -> void:
	$UI.update_energy($Player.energy)

func _on_shot() -> void:
	$UI.update_energy($Player.energy)
	var bullet = bullet_scene.instantiate()
	bullet.configure_mode(Modecontrol.mode)
	var bullet_sl = get_node("Player/Muzzle")
	var direction = $Player.rotation
	if Modecontrol.mode == 0:
		direction += randf_range(-Shopcontrol.spread, Shopcontrol.spread)
	bullet.position = bullet_sl.global_position
	bullet.rotation = direction
	var velocity_bullet = Vector2(0, bullet_speed)
	bullet.linear_velocity = velocity_bullet.rotated(direction)
	add_child(bullet)

func spawn_energy() -> void:
	energy_CA = 1 + 2*(Wavecontrol.wave)
	for i in energy_CA:
		var portal = portal_scene.instantiate()
		var portal_sl: Vector2 = Vector2(randf_range(100, 1600), randf_range(100, 800))
		portal.position = portal_sl
		add_child(portal)
		await get_tree().create_timer(randf_range(7, 15)).timeout

func spawn_enemy(enemy_type: int) -> void:
	var enemy = enemy_scene.instantiate()
	enemy.configure_enemy(enemy_type)
	var enemy_sl = $%EnemySpawnLocation
	enemy_sl.progress_ratio = randf()
	enemy.position = enemy_sl.position
	add_child(enemy)

func _on_spawn_energy(energy) -> void:
	add_child(energy)
