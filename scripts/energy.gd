extends RigidBody2D

var dead = false

func _ready():
	$KillTimer.start()
	$AnimatedSprite2D.play("Spawn")

func _process(_delta):
	if $KillTimer.time_left <= 10:
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
