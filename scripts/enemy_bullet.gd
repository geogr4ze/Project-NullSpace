extends RigidBody2D

var hit: bool = true

# Deletes bullet when it leaves the screen
func _on_visibility_screen_exited():
	queue_free()

# Player detection
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.name == "Player" and hit:
		hit = false
		Signalbus.enemy_bullet_hit.emit()
		queue_free()
