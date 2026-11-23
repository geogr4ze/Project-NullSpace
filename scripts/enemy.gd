extends Area2D

var bullet_scene = preload("res://scenes/enemy_bullet.tscn")
var mine_scene = preload("res://scenes/enemy_mine.tscn")
var collision_shapes = Array()
var player
var hpbar
var hpvis_time := 0.0

var health: int
var speed: float
var type: int = -1
var score_amount: int
var reward_amount: int

var tank_shield_hp = 25
var max_tank_shield_hp = tank_shield_hp
var RGbullet_speed := -1000.0

func configure_enemy(enemy_type: int) -> void:
	type = enemy_type

func _ready():
	if type < 0:
		type = Wavecontrol.selection
	if type == 2:
		$%AoeSCollision.disabled = false
		$%AoeSkin.visible = true
	if type == 3:
		$%ShieldCollision.set_deferred("disabled", false)
		$%Shield.self_modulate = Color(1.0, 1.0, 1.0, 0.3)
		$%Shield.visible = true
	if type == 4:
		$RGShootTimer.wait_time = randf_range(15.0, 30.0)
		$RGShootTimer.start()
	if type == 5:
		$MineTimer.wait_time = randf_range(5.0, 20.0)
		$MineTimer.start()
	hpbar = get_node("Node2D/ProgressBar")
	player = get_node("../Player")
	enemy_type(type)
	var shape_owners = get_shape_owners()
	for shape in shape_owners:
		var this_shape = shape_owner_get_shape(shape, 0)
		collision_shapes.append(this_shape)
	$Skin.animation = Wavecontrol.enemies[type]["enemy_skin"]
	$CollisionShape2D.shape = collision_shapes[type]
	if type != 5:
		$Skin.play()
	hpbar.self_modulate.a = 0

# Convert original per-frame speed values into pixels/second (at 60 FPS).
func enemy_type(enemy) -> void:
	score_amount = Wavecontrol.enemies[enemy]["score"]
	reward_amount = Wavecontrol.enemies[enemy]["reward"]
	health = Wavecontrol.enemies[enemy]["health"]
	hpbar.max_value = health
	hpbar.value = health
	speed = (Wavecontrol.enemies[enemy]["enemy_speed"] + randf_range(0.01, 0.3)) * 60.0

func _physics_process(delta: float) -> void:
	if !alive or !is_instance_valid(player):
		return
	if type == 4:
		warning_RG()
	look_at(player.global_position)
	var velocity = Vector2.RIGHT.rotated(rotation) * speed
	position += velocity * delta
	$Node2D.global_rotation = 0
	$%Warning_Sign.global_rotation = 0

func _process(delta: float) -> void:
	if hpvis_time > 0.0:
		hpvis_time = maxf(0.0, hpvis_time - delta)
	elif hpbar.self_modulate.a > 0.0:
		hpbar.self_modulate.a = maxf(0.0, hpbar.self_modulate.a - delta)

func _show_health_bar() -> void:
	hpbar.self_modulate.a = 1.0
	hpvis_time = 5.0

func detect_support() -> void:
	while alive and has_overlapping_areas():
		if health < hpbar.max_value:
			health += 1
			_show_health_bar()
			hpbar.value = health
		await get_tree().create_timer(1.0).timeout

func detect_player() -> void:
	while overlaps_body(player):
		Signalbus.hit.emit()
		await get_tree().create_timer(1.0).timeout

func warning_RG() -> void:
	if $RGShootTimer.time_left <= 3:
		$%Warning_Sign.visible = true
		$%Warning_Sign.play()
	else:
		$%Warning_Sign.visible = false
		$%Warning_Sign.stop()
		$%Warning_Sign.frame = 0

var alive = true

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		detect_player()
	elif alive and body.has_method("register_hit"):
		if type == Wavecontrol.TANK and tank_shield_hp > 0 and int(body.get("weapon_mode")) != Modecontrol.MODE2:
			_absorb_shield_hit(body)
		elif body.register_hit(self):
			_take_damage(int(body.get("damage")))

func _absorb_shield_hit(bullet: Node2D) -> void:
	if !alive or tank_shield_hp <= 0 or !bullet.register_hit(self):
		return
	tank_shield_hp = maxi(0, tank_shield_hp - int(bullet.get("damage")))
	$%Shield.self_modulate = Color(4.0, 4.0, 4.0, 0.3)
	if tank_shield_hp == 0:
		$%ShieldCollision.set_deferred("disabled", true)
		$%Shield.rotation_degrees = 90.0
		$%Shield.play("default")
		$%ShieldRegen.start()
	await get_tree().create_timer(0.1).timeout
	if is_inside_tree():
		$%Shield.self_modulate = Color(1.0, 1.0, 1.0, 0.3)

func _take_damage(amount: int) -> void:
	if !alive:
		return
	health = maxi(0, health - maxi(0, amount))
	_show_health_bar()
	hpbar.value = health
	$Skin.self_modulate = Color(4.0, 4.0, 4.0)
	if health == 0:
		alive = false
		Signalbus.kc_point.emit()
		Signalbus.score.emit(score_amount)
		Signalbus.money.emit(reward_amount)
		queue_free()
		return
	await get_tree().create_timer(0.1).timeout
	if is_inside_tree():
		$Skin.self_modulate = Color(1.0, 1.0, 1.0)

func _on_mine_timer_timeout():
	$Skin.play()
	for i in 5:
		speed = speed * 0.9
		await get_tree().create_timer(0.01).timeout
	await get_tree().create_timer(2.0).timeout
	var mine = mine_scene.instantiate()
	var mine_sl = get_node("MineSpawn")
	var direction = randf_range(0, 180)
	mine.position = mine_sl.global_position
	mine.rotation = direction
	var velocity_bullet = Vector2(0, 25)
	mine.linear_velocity = velocity_bullet.rotated(direction)
	Signalbus.mine_dispense.emit(mine)
	$Skin.play_backwards()
	await get_tree().create_timer(1.2).timeout
	for i in 5:
		speed = speed / 0.9
		await get_tree().create_timer(0.01).timeout

func _on_shoot_timer_timeout():
	var bullet = bullet_scene.instantiate()
	var bullet_sl = get_node("RGMuzzle")
	var direction = $Position.global_rotation
	bullet.position = bullet_sl.global_position
	bullet.rotation = direction
	var velocity_bullet = Vector2(0, RGbullet_speed)
	bullet.linear_velocity = velocity_bullet.rotated(direction)
	Signalbus.shot_RG.emit(bullet)

func _on_tank_shield_body_entered(body: Node2D) -> void:
	if type == Wavecontrol.TANK and tank_shield_hp > 0 and body.has_method("register_hit"):
		if int(body.get("weapon_mode")) != Modecontrol.MODE2:
			_absorb_shield_hit(body)

func _on_shield_regen_timeout():
	tank_shield_hp = max_tank_shield_hp
	$%Shield.rotation_degrees = -90.0
	$%Shield.play_backwards("default")
	$%ShieldCollision.set_deferred("disabled", false)

func _on_area_entered(area):
	if area.name == "AoeS" and type != 2:
		detect_support()
