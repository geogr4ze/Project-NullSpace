extends RigidBody2D

var health = 10
var primed = true
var hpbar
var hpvis_time := 0.0

func _ready():
	$Skin.play("default")
	hpbar = get_node("%Healthbar")
	hpbar.max_value = health
	hpbar.value = health

func _process(delta: float) -> void:
	$Node2D.global_rotation = 0
	if hpvis_time > 0.0:
		hpvis_time = maxf(0.0, hpvis_time - delta)
	elif hpbar.self_modulate.a > 0.0:
		hpbar.self_modulate.a = maxf(0.0, hpbar.self_modulate.a - delta)

func _show_health_bar() -> void:
	hpbar.self_modulate.a = 1.0
	hpvis_time = 5.0

func explosion() -> void:
	if !primed:
		return
	primed = false
	$Node2D.visible = false
	$%ExplisionCollision.set_deferred("disabled", false)
	$%MineCollision.set_deferred("disabled", true)
	$Skin.play("explosion")
	$Skin.self_modulate.a = 0.6
	$Skin.scale = Vector2(0.195, 0.195)
	angular_velocity = randi_range(-25, 25)

	# One tween replaces more than a hundred individual scene-tree timers.
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property($Skin, "scale", Vector2(0.001, 0.001), 0.97)
	tween.parallel().tween_property($%ExplisionCollision, "scale", Vector2(0.001, 0.001), 0.97)
	tween.tween_callback(fadeout)

func fadeout() -> void:
	$Skin.play("fadeout")
	$%ExplisionCollision.set_deferred("disabled", true)
	$Skin.self_modulate.a = 0.8
	var tween := create_tween()
	tween.tween_property($Skin, "scale", Vector2(0.041, 0.041), 0.2)
	tween.tween_property($Skin, "scale", Vector2(0.001, 0.001), 0.2)
	tween.tween_callback(queue_free)

var hitflag = true

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		if primed:
			explosion()
		if !hitflag:
			return
		hitflag = false
		Signalbus.mine_hit.emit()
	elif primed and body.has_method("register_hit"):
		if body.register_hit(self):
			health = maxi(0, health - int(body.get("damage")))
			_show_health_bar()
			hpbar.value = health
			if health == 0:
				explosion()
