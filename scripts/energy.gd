extends RigidBody2D

const PlayerShipScript = preload("res://scripts/player.gd")

var dead: bool = false

## Start the lifetime timer and spawn animation; after the calculated delay, play decay if the pickup is still alive.
func _ready():
	$KillTimer.start()
	$AnimatedSprite2D.play("Spawn")
	var decay_delay: float = maxf(0.0, $KillTimer.wait_time - 10.0)
	await get_tree().create_timer(decay_delay).timeout
	if is_inside_tree() and !dead:
		$AnimatedSprite2D.play("Decay")


## Consume an uncollected pickup on player contact, emit energy and queue deletion.
func _on_pickup_area_body_entered(_body: Node2D) -> void:
	if !dead and _body is PlayerShipScript:
		dead = true
		Signalbus.energy.emit()
		queue_free()

## Mark pickup dead, play its death animation and queue deletion after five seconds.
func _on_kill_timer_timeout() -> void:
	dead = true
	$AnimatedSprite2D.play("Dead")
	await get_tree().create_timer(5).timeout
	queue_free()
