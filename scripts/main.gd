extends Node2D

const PlayerShipScript = preload("res://scripts/player.gd")
const EnemyShipScript = preload("res://scripts/enemy.gd")
const PlayerProjectileScript = preload("res://scripts/bullet.gd")
const GameHUDScript = preload("res://scripts/ui.gd")

var enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")
var bullet_scene: PackedScene = preload("res://scenes/bullet.tscn") 
var portal_scene: PackedScene = preload("res://scenes/portal.tscn")
var score: int = 0
var bullet_speed: float
var energy_CA: int

@onready var ship: PlayerShipScript = $Player
@onready var hud: GameHUDScript = $UI
@onready var muzzle: Marker2D = $Player/Muzzle
@onready var enemy_spawn_location: PathFollow2D = $%EnemySpawnLocation

func _ready():
	bullet_speed = Modecontrol.modes[0]["bullet_speed"]
	ship.start($PlayerStartPos.position)
	hud.update_energy(ship.energy)
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
	if Wavecontrol.test_enable:
		# Autoloads initialize before the start screen. Start test enemies
		# only after Main and the UI have connected to Signalbus.
		Signalbus.test_mode.emit()
		Wavecontrol.test_spawn()

func _death() -> void:
	get_tree().paused = true

func _change_bp(mode: int) -> void:
	bullet_speed = Modecontrol.modes[mode]["bullet_speed"]

var energy_low: bool = true

func _on_energy_low() -> void:
	if energy_low:
		energy_low = false
		hud.update_energy_low(ship.energy)
		await get_tree().create_timer(3).timeout
		energy_low = true

func _on_money(reward_amount: int) -> void:
	Shopcontrol.shopmoney += reward_amount * Shopcontrol.money_multi
	@warning_ignore("narrowing_conversion")
	hud.update_money(Shopcontrol.shopmoney)

func _on_energy() -> void:
	hud.update_energy(ship.energy)

func _on_next_wave() -> void:
	hud.update_wave(Wavecontrol.wave)
	spawn_energy()

func _on_score(score_type: int) -> void:
	score += score_type
	hud.update_score(score)

func _on_RGshot(bulletRG: RigidBody2D) -> void:
	add_child(bulletRG)

func _on_mine_dispense(mine: RigidBody2D) -> void:
	add_child(mine)

func _on_dash() -> void:
	hud.update_energy(ship.energy)

func _on_shot() -> void:
	hud.update_energy(ship.energy)
	var bullet: PlayerProjectileScript = bullet_scene.instantiate() as PlayerProjectileScript
	if bullet == null:
		push_error("Bullet scene did not instantiate a projectile. Check bullet.gd.")
		return
	bullet.configure_mode(Modecontrol.mode)
	var direction: float = ship.rotation
	if Modecontrol.mode == 0:
		direction += randf_range(-Shopcontrol.spread, Shopcontrol.spread)
	bullet.position = muzzle.global_position
	bullet.rotation = direction
	var velocity_bullet: Vector2 = Vector2(0, bullet_speed)
	bullet.linear_velocity = velocity_bullet.rotated(direction)
	add_child(bullet)

func spawn_energy() -> void:
	energy_CA = 1 + 2*(Wavecontrol.wave)
	for i: int in energy_CA:
		var portal: Node2D = portal_scene.instantiate() as Node2D
		var portal_sl: Vector2 = Vector2(randf_range(100, 1600), randf_range(100, 800))
		portal.position = portal_sl
		add_child(portal)
		await get_tree().create_timer(randf_range(7, 15)).timeout

func spawn_enemy(enemy_type: int) -> void:
	var enemy: EnemyShipScript = enemy_scene.instantiate() as EnemyShipScript
	if enemy == null:
		push_error("Enemy scene did not instantiate an enemy. Check enemy.gd.")
		return
	enemy.configure_enemy(enemy_type)
	enemy_spawn_location.progress_ratio = randf()
	enemy.position = enemy_spawn_location.position
	add_child(enemy)

func _on_spawn_energy(energy: RigidBody2D) -> void:
	add_child(energy)
