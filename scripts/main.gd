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
var energy_generation: int = 0
var run_finished: bool = false
const GameOverOverlay = preload("res://scripts/game_over_overlay.gd")

@onready var ship: PlayerShipScript = $Player
@onready var hud: GameHUDScript = $UI
@onready var muzzle: Marker2D = $Player/Muzzle
@onready var enemy_spawn_location: PathFollow2D = $%EnemySpawnLocation

## Initialize player and HUD, load weapon speed and connect gameplay signals.
func _ready():
	bullet_speed = Modecontrol.modes[Modecontrol.mode]["bullet_speed"]
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
	Signalbus.game_over.connect(_on_game_over)
	Signalbus.shop_money_changed.connect(_refresh_money)
	_refresh_money()
	Signalbus.dash.connect(_on_dash)
	Modecontrol.mode_changed.connect(_change_bp)
	if Wavecontrol.test_enable:
		# Autoloads initialize before the start screen. Start test enemies
		# only after Main and the UI have connected to Signalbus.
		Signalbus.test_mode.emit()
		Wavecontrol.test_spawn()

## Emit a loss result if the run has not finished.
func _death() -> void:
	if not run_finished:
		Signalbus.game_over.emit(false)

## Finish the run once, cancel outstanding energy spawns, stop waves, pause the tree and show the result overlay.
func _on_game_over(won: bool) -> void:
	if run_finished:
		return
	run_finished = true
	energy_generation += 1
	Wavecontrol.stop_run()
	get_tree().paused = true
	var overlay: CanvasLayer = GameOverOverlay.new()
	add_child(overlay)
	overlay.call("show_result", won)


## Set projectile speed from the registered weapon mode.
func _change_bp(mode: int) -> void:
	bullet_speed = Modecontrol.modes[mode]["bullet_speed"]

## Show the low-energy warning with the player's current energy.
func _on_energy_low() -> void:
	hud.update_energy_low(ship.energy)

## Apply the reward multiplier, increase shared shop money and refresh HUD.
func _on_money(reward_amount: int) -> void:
	Shopcontrol.shopmoney += reward_amount * Shopcontrol.money_multi
	_refresh_money()

## Synchronize the HUD money label with shared shop balance.
func _refresh_money() -> void:
	hud.update_money(Shopcontrol.shopmoney)

## Refresh the HUD energy count after a pickup.
func _on_energy() -> void:
	hud.update_energy(ship.energy)

## Update wave HUD and initiate energy spawns for the wave.
func _on_next_wave() -> void:
	hud.update_wave(Wavecontrol.wave)
	spawn_energy()

## Add the supplied score increment and update HUD.
func _on_score(score_type: int) -> void:
	score += score_type
	hud.update_score(score)

## Add a prepared railgun projectile to the main scene.
func _on_RGshot(bulletRG: RigidBody2D) -> void:
	add_child(bulletRG)

## Add a prepared enemy mine to the main scene.
func _on_mine_dispense(mine: RigidBody2D) -> void:
	add_child(mine)

## Refresh the HUD energy display after dashing.
func _on_dash() -> void:
	hud.update_energy(ship.energy)

## Instantiate and configure the player projectile for the current mode, update energy HUD and apply weapon-specific direction and motion.
func _on_shot() -> void:
	hud.update_energy(ship.energy)
	var bullet: PlayerProjectileScript = bullet_scene.instantiate() as PlayerProjectileScript
	if bullet == null:
		push_error("Bullet scene did not instantiate a projectile. Check bullet.gd.")
		return
	bullet.configure_mode(Modecontrol.mode)
	var direction: float = ship.rotation
	if Modecontrol.mode == Modecontrol.DEFAULT:
		direction += randf_range(-Shopcontrol.spread, Shopcontrol.spread)
	bullet.position = muzzle.global_position
	bullet.rotation = direction
	var velocity_bullet: Vector2 = Vector2(0, bullet_speed)
	bullet.linear_velocity = velocity_bullet.rotated(direction)
	add_child(bullet)

## Asynchronously create wave-scaled energy portals; generation changes or run completion cancel the sequence.
func spawn_energy() -> void:
	energy_generation += 1
	var generation: int = energy_generation
	var count: int = 1 + 2 * Wavecontrol.wave
	for i: int in count:
		if generation != energy_generation or run_finished:
			return
		var portal: Node2D = portal_scene.instantiate() as Node2D
		portal.position = Vector2(randf_range(100, 1600), randf_range(100, 800))
		add_child(portal)
		await get_tree().create_timer(randf_range(7, 15), false).timeout

## Instantiate a registered enemy type at a randomized point on the configured spawn path; report invalid scenes.
func spawn_enemy(enemy_type: int) -> void:
	var enemy: EnemyShipScript = enemy_scene.instantiate() as EnemyShipScript
	if enemy == null:
		push_error("Enemy scene did not instantiate an enemy. Check enemy.gd.")
		return
	enemy.configure_enemy(enemy_type)
	enemy_spawn_location.progress_ratio = randf()
	enemy.position = enemy_spawn_location.position
	add_child(enemy)

## Add a prepared energy pickup to the main scene.
func _on_spawn_energy(energy: RigidBody2D) -> void:
	add_child(energy)
