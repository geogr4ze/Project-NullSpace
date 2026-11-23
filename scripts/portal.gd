extends Node2D

var energy_scene: PackedScene = preload("res://scenes/energy.tscn")

func _ready():
	$AnimatedSprite2D.play("Appearing")
	$EnergyTimer.start()

# Summon portal on timer timeout
func _on_energy_timer_timeout() -> void:
	$EnergyTimer.stop()
	var energy: RigidBody2D = energy_scene.instantiate() as RigidBody2D
	var energy_sl: Marker2D = get_node("Position") as Marker2D
	var direction: float = randf_range(0.0, TAU)
	energy.position = energy_sl.global_position
	energy.rotation = direction
	energy.angular_velocity = randf_range(-20, 20)
	var velocity_energy: Vector2 = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	energy.linear_velocity = velocity_energy.rotated(direction)
	Signalbus.spawn_energy.emit(energy)
	$AnimatedSprite2D.play("Disappearing")
	await get_tree().create_timer(0.8).timeout
	queue_free()
