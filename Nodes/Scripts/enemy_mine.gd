extends RigidBody2D

var health = 10
var primed = true
var hpbar
var hpvis_time: int

func _ready():
	$Skin.play("default")
	hpbar = get_node("%Healthbar")

func _process(_delta):
	$Node2D.global_rotation = 0
	if hpbar.self_modulate.a == 1.0:
		hpbar.self_modulate.a = 0.99
		hpvis_time = 5
		health_bar()

func explosion() -> void:
		primed = false
		$Node2D.visible = false
		$%ExplisionCollision.disabled = false
		$%MineCollision.disabled = true
		$Skin.play("explosion")
		$Skin.self_modulate.a = 0.6
		$Skin.scale = Vector2(0.195, 0.195)
		angular_velocity = randi_range(-25, 25)
		await get_tree().create_timer(1).timeout
		for i in 97:
			$Skin.scale -= Vector2(0.002, 0.002)
			$%ExplisionCollision.scale -= Vector2(0.002, 0.002)
			await get_tree().create_timer(0.01).timeout
		fadeout()

func fadeout() -> void:
	$Skin.play("fadeout")
	$%ExplisionCollision.disabled = true
	$Skin.self_modulate.a = 0.8
	for i in 20:
		$Skin.scale += Vector2(0.002, 0.002)
		await get_tree().create_timer(0.01).timeout
	for i in 20:
		$Skin.scale -= Vector2(0.002, 0.002)
		await get_tree().create_timer(0.01).timeout
	queue_free()

var hp_flag = true

func health_bar() -> void:
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

var hitflag = true

func _on_area_2d_body_entered(body) -> void:
	if body.name == "Player" and primed:
		explosion()
	else:
		if primed:
			health -= 1
			hpbar.self_modulate.a = 1.0
			hpbar.value = health
			if health == 0:
				explosion()
	if !primed and body.name == "Player" and hitflag:
		hitflag = false
		Signalbus.mine_hit.emit()
