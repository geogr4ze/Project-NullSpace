extends RigidBody2D

var dead = false

func _ready():
	$KillTimer.start()
	$AnimatedSprite2D.play("Spawn")
	var decay_delay := maxf(0.0, $KillTimer.wait_time - 10.0)
	await get_tree().create_timer(decay_delay).timeout
	if is_inside_tree() and !dead:
		$AnimatedSprite2D.play("Decay")


func _on_pickup_area_body_entered(_body) -> void:
	if !dead:
		Signalbus.energy.emit()
		queue_free()

func _on_kill_timer_timeout() -> void:
	dead = true
	$AnimatedSprite2D.play("Dead")
	await get_tree().create_timer(5).timeout
	queue_free()
