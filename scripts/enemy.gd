extends Area2D

const PlayerShipScript = preload("res://scripts/player.gd")
const PlayerProjectileScript = preload("res://scripts/bullet.gd")

var bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")
var mine_scene: PackedScene = preload("res://scenes/enemy_mine.tscn")
@onready var player: PlayerShipScript = $"../Player"
@onready var hpbar: ProgressBar = $Node2D/ProgressBar
@onready var skin: AnimatedSprite2D = $Skin
@onready var warning_sign: AnimatedSprite2D = $%Warning_Sign
@onready var railgun_muzzle: Marker2D = $RGMuzzle
@onready var mine_spawn: Marker2D = $MineSpawn
var hpvis_time: float = 0.0

var health: int
var speed: float
var type: int = -1
var score_amount: int
var reward_amount: int

var tank_shield_hp: int = 25
var max_tank_shield_hp: int = tank_shield_hp
var RGbullet_speed: float = -1000.0

func configure_enemy(enemy_type: int) -> void:
	type = enemy_type

func _ready():
	if type < 0:
		type = Wavecontrol.selection
	if type == Wavecontrol.SUPPORT:
		$%AoeSCollision.disabled = false
		$%AoeSkin.visible = true
	if type == Wavecontrol.TANK:
		$%ShieldCollision.set_deferred("disabled", false)
		$%Shield.self_modulate = Color(1.0, 1.0, 1.0, 0.3)
		$%Shield.visible = true
	if type == Wavecontrol.RAILGUN:
		$RGShootTimer.wait_time = randf_range(15.0, 30.0)
		$RGShootTimer.start()
	if type == Wavecontrol.MINESHIP:
		$MineTimer.wait_time = randf_range(5.0, 20.0)
		$MineTimer.start()
	if !Wavecontrol.enemies.has(type):
		push_error("Unknown enemy type: " + str(type))
		queue_free()
		return
	_apply_enemy_stats(type)
	var shapes: Array[Shape2D] = [
		$BasicCollision.shape,
		$SpeedCollision.shape,
		$SupportCollision.shape,
		$TankCollision.shape,
		$RailgunCollision.shape,
		$MineShipCollision.shape
	]
	skin.animation = Wavecontrol.enemies[type]["enemy_skin"]
	$CollisionShape2D.shape = shapes[type]
	if type != Wavecontrol.MINESHIP:
		skin.play()
	hpbar.self_modulate.a = 0

# Convert original per-frame speed values into pixels/second (at 60 FPS).
func _apply_enemy_stats(enemy: int) -> void:
	score_amount = Wavecontrol.enemies[enemy]["score"]
	reward_amount = Wavecontrol.enemies[enemy]["reward"]
	health = Wavecontrol.enemies[enemy]["health"]
	hpbar.max_value = health
	hpbar.value = health
	speed = (Wavecontrol.enemies[enemy]["enemy_speed"] + randf_range(0.01, 0.3)) * 60.0

func _physics_process(delta: float) -> void:
	if !alive or !is_instance_valid(player):
		return
	if type == Wavecontrol.RAILGUN:
		warning_RG()
	look_at(player.global_position)
	var velocity: Vector2 = Vector2.RIGHT.rotated(rotation) * speed
	position += velocity * delta
	$Node2D.global_rotation = 0
	if type == Wavecontrol.RAILGUN:
		warning_sign.global_rotation = 0

func _process(delta: float) -> void:
	if hpvis_time > 0.0:
		hpvis_time = maxf(0.0, hpvis_time - delta)
	elif hpbar.self_modulate.a > 0.0:
		hpbar.self_modulate.a = maxf(0.0, hpbar.self_modulate.a - delta)

func _show_health_bar() -> void:
	hpbar.self_modulate.a = 1.0
	hpvis_time = 5.0

var support_healing_active: bool = false

func detect_support() -> void:
	if support_healing_active:
		return
	support_healing_active = true
	while alive and _is_supported():
		if health < int(hpbar.max_value):
			health += 1
			_show_health_bar()
			hpbar.value = health
		await get_tree().create_timer(1.0).timeout
	support_healing_active = false

func _is_supported() -> bool:
	for area: Area2D in get_overlapping_areas():
		if is_instance_valid(area) and area.name == "AoeS":
			return true
	return false

var contact_damage_active: bool = false

func detect_player() -> void:
	if contact_damage_active:
		return
	contact_damage_active = true
	while alive and is_instance_valid(player) and overlaps_body(player):
		Signalbus.hit.emit()
		await get_tree().create_timer(1.0).timeout
	contact_damage_active = false

func warning_RG() -> void:
	if $RGShootTimer.time_left <= 3.0:
		if !warning_sign.visible:
			warning_sign.visible = true
			warning_sign.play()
	elif warning_sign.visible:
		warning_sign.hide()
		warning_sign.stop()
		warning_sign.frame = 0

var alive: bool = true
var hit_flash: Tween
var shield_flash: Tween
var mine_attack_active: bool = false
const MINE_SLOW_FACTOR: float = 0.59049

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		detect_player()
	elif alive and body is PlayerProjectileScript:
		var projectile: PlayerProjectileScript = body as PlayerProjectileScript
		if type == Wavecontrol.TANK and tank_shield_hp > 0:
			_absorb_shield_hit(projectile)
		elif projectile.register_hit(self):
			_take_damage(projectile.damage)

func _absorb_shield_hit(bullet: PlayerProjectileScript) -> void:
	if !alive or tank_shield_hp <= 0 or !bullet.register_hit(self):
		return
	# Default and wave projectiles are blocked but do not damage the shield.
	if bullet.weapon_mode != Modecontrol.MODE2:
		return
	tank_shield_hp = maxi(0, tank_shield_hp - bullet.damage)
	if shield_flash != null and shield_flash.is_valid():
		shield_flash.kill()
	$%Shield.self_modulate = Color(4.0, 4.0, 4.0, 0.3)
	if tank_shield_hp == 0:
		$%ShieldCollision.set_deferred("disabled", true)
		$%Shield.rotation_degrees = 90.0
		$%Shield.play("default")
		$%ShieldRegen.start()
	shield_flash = create_tween()
	shield_flash.tween_property($%Shield, "self_modulate", Color(1.0, 1.0, 1.0, 0.3), 0.1)

func _take_damage(amount: int) -> void:
	if !alive:
		return
	health = maxi(0, health - maxi(0, amount))
	_show_health_bar()
	hpbar.value = health
	if hit_flash != null and hit_flash.is_valid():
		hit_flash.kill()
	skin.self_modulate = Color(4.0, 4.0, 4.0)
	if health == 0:
		alive = false
		Signalbus.kc_point.emit()
		Signalbus.score.emit(score_amount)
		Signalbus.money.emit(reward_amount)
		queue_free()
		return
	hit_flash = create_tween()
	hit_flash.tween_property(skin, "self_modulate", Color.WHITE, 0.1)

func _on_mine_timer_timeout() -> void:
	if mine_attack_active or !alive:
		return
	mine_attack_active = true
	skin.play()
	var initial_speed: float = speed
	var slowdown: Tween = create_tween()
	slowdown.tween_property(self, "speed", initial_speed * MINE_SLOW_FACTOR, 0.05)
	await slowdown.finished
	await get_tree().create_timer(2.0).timeout
	if !alive or !is_inside_tree():
		return
	var mine: RigidBody2D = mine_scene.instantiate() as RigidBody2D
	var direction: float = randf_range(0.0, TAU)
	mine.position = mine_spawn.global_position
	mine.rotation = direction
	mine.linear_velocity = Vector2(0, 25).rotated(direction)
	Signalbus.mine_dispense.emit(mine)
	skin.play_backwards()
	var recovery: Tween = create_tween()
	recovery.tween_property(self, "speed", initial_speed, 0.05)
	await recovery.finished
	mine_attack_active = false

func _on_shoot_timer_timeout():
	var bullet: RigidBody2D = bullet_scene.instantiate() as RigidBody2D
	var direction: float = $Position.global_rotation
	bullet.position = railgun_muzzle.global_position
	bullet.rotation = direction
	var velocity_bullet: Vector2 = Vector2(0, RGbullet_speed)
	bullet.linear_velocity = velocity_bullet.rotated(direction)
	Signalbus.shot_RG.emit(bullet)

func _on_tank_shield_body_entered(body: Node2D) -> void:
	if type == Wavecontrol.TANK and tank_shield_hp > 0 and body is PlayerProjectileScript:
		var projectile: PlayerProjectileScript = body as PlayerProjectileScript
		_absorb_shield_hit(projectile)

func _on_shield_regen_timeout():
	tank_shield_hp = max_tank_shield_hp
	$%Shield.rotation_degrees = -90.0
	$%Shield.play_backwards("default")
	$%ShieldCollision.set_deferred("disabled", false)

func _on_area_entered(area: Area2D):
	if area.name == "AoeS" and type != Wavecontrol.SUPPORT:
		detect_support()
