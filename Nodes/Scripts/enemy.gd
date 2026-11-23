extends Area2D

var bullet_scene = preload("res://Nodes/enemy_bullet.tscn")
var mine_scene = preload("res://Nodes/enemy_mine.tscn")
var collision_shapes = Array()
var player
var hpbar
var hpvis_time: int

var health: int
var speed: float
var type: int
var score_amount: int
var reward_amount: int

var tank_shield_hp = 25
var max_tank_shield_hp = tank_shield_hp
var RGbullet_speed := -1000.0

func _ready():
	type = Wavecontrol.selection
	if type == 2:
		$%AoeSCollision.disabled = false
		$%AoeSkin.visible = true
	if type == 3:
		$%ShieldCollision.disabled = false
		$%Shield.self_modulate = Color(1.0, 1.0, 1.0, 0.3)
		$%Shield.visible = true
	if type == 4:
		$RGShootTimer.wait_time = randf_range(15.0, 30.0)
		$RGShootTimer.start()
	if type == 5:
		$RGShootTimer.wait_time = randf_range(5.0, 20.0)
		$MineTimer.start()
	hpbar = get_node("Node2D/ProgressBar")
	player = get_node("../Player")
	Wavecontrol.set_type(type)
	enemy_type(type)
	var shape_owners = get_shape_owners()
	for shape in shape_owners:
		var this_shape = shape_owner_get_shape(shape, 0)
		collision_shapes.append(this_shape)
	$Skin.animation = Wavecontrol.enemies[Wavecontrol.enemy]["enemy_skin"]
	$CollisionShape2D.shape = collision_shapes[Wavecontrol.enemy]
	if type != 5:
		$Skin.play()
	hpbar.self_modulate.a = 0

func enemy_type(enemy) -> void:
	score_amount = Wavecontrol.enemies[enemy]["score"]
	reward_amount = Wavecontrol.enemies[enemy]["reward"]
	health = Wavecontrol.enemies[enemy]["health"]
	hpbar.max_value = health
	hpbar.value = health
	speed = Wavecontrol.enemies[enemy]["enemy_speed"] + randf_range(0.01, 0.3)

func _process(_delta):
	if type == 4:
		warning_RG()
	look_at(player.position)
	var velocity = Vector2(speed, 0)
	velocity = velocity.rotated(rotation)
	position += velocity
	$Node2D.global_rotation = 0
	$%Warning_Sign.global_rotation = 0
	if hpbar.self_modulate.a == 1.0 and (health > int(hpbar.max_value/5)):
		hpbar.self_modulate.a = 0.99
		hpvis_time = 5
		health_bar()

func detect_support() -> void:
	while has_overlapping_areas():
		if health < hpbar.max_value:
			health += 1
			hpbar.self_modulate.a = 1.0
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

var hp_flag = true

func health_bar():
	if hp_flag:
		hp_flag = false
		while hpvis_time > 0:
			hpvis_time -= 1
			await get_tree().create_timer(1.0).timeout
		for i in 99:
			if hpvis_time == 0:
				await get_tree().create_timer(0.01).timeout
				hpbar.self_modulate.a -= 0.01
		hp_flag = true

var alive = true

func _on_body_entered(body):
	if body.name == "Player":
		detect_player()
	else:
		if type == 3 and tank_shield_hp > 0:
			$%Shield.self_modulate = Color(4.0, 4.0, 4.0, 0.3)
			tank_shield_hp -= 1
			if tank_shield_hp <= 0:
				$%ShieldCollision.disabled = true
				$%Shield.rotation_degrees = 90.0
				$%Shield.play("default")
				$%ShieldRegen.start()
			await get_tree().create_timer(0.1).timeout
			$%Shield.self_modulate = Color(1.0, 1.0, 1.0, 0.3)
		else:
			$Skin.self_modulate = Color(4.0, 4.0, 4.0)
			health -= 1
			hpbar.self_modulate.a = 1.0
			hpbar.value = health
			Signalbus.enemy_hit.emit(body)
			if health <= 0 and alive:
				alive = false
				queue_free()
				Signalbus.kc_point.emit()
				Signalbus.score.emit(score_amount)
				Signalbus.money.emit(reward_amount)
			await get_tree().create_timer(0.1).timeout
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

func _on_tank_shield_body_entered(body):
	if Modecontrol.mode != 2 and tank_shield_hp > 0:
		Signalbus.shield.emit(body)

func _on_shield_regen_timeout():
	tank_shield_hp = max_tank_shield_hp
	$%Shield.rotation_degrees = -90.0
	$%Shield.play_backwards("default")
	$%ShieldCollision.disabled = false

func _on_area_entered(area):
	if area.name == "AoeS" and type != 2:
		detect_support()
