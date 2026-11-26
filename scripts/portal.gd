extends Node2D

var energy_scene: PackedScene = preload("res://scenes/energy.tscn")
@onready var spawn_marker: Marker2D = $Position
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

## Play the portal appearance animation and start its energy spawn timer.
func _ready():
	sprite.play("Appearing")
	$EnergyTimer.start()

# Summon portal on timer timeout
## Instantiate an energy pickup at the marker with randomized rotation and velocity, emit its spawn signal and complete portal behavior.
func _on_energy_timer_timeout() -> void:
	$EnergyTimer.stop()
	var energy: RigidBody2D = energy_scene.instantiate() as RigidBody2D
	var direction: float = randf_range(0.0, TAU)
	energy.position = spawn_marker.global_position
	energy.rotation = direction
	energy.angular_velocity = randf_range(-20, 20)
	var velocity_energy: Vector2 = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	energy.linear_velocity = velocity_energy.rotated(direction)
	Signalbus.spawn_energy.emit(energy)
	sprite.play("Disappearing")
	await get_tree().create_timer(0.8).timeout
	queue_free()
