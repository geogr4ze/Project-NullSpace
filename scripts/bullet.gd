class_name PlayerProjectile
extends RigidBody2D

# Capture weapon properties on spawn, so switching modes does not change bullets
# already in flight. Each projectile damages each target at most once.
var weapon_mode: int = -1
var damage: int = 1
var pierce: int = 1
var hit_targets: Dictionary = {}

func configure_mode(mode: int) -> void:
	weapon_mode = mode

func _ready() -> void:
	if weapon_mode < 0:
		weapon_mode = Modecontrol.mode
	var mode_data: Dictionary = Modecontrol.modes[weapon_mode]
	$Skin.animation = mode_data["bullet_skin"]
	pierce = mode_data["pierce"]
	if weapon_mode == Modecontrol.DEFAULT:
		$CollisionShape2D.shape = $BulletCollision.shape
	elif weapon_mode == Modecontrol.MODE1:
		$CollisionShape2D.shape = $WaveCollision.shape
	elif weapon_mode == Modecontrol.MODE2:
		$CollisionShape2D.shape = $LaserCollision.shape
	else:
		push_error("Invalid projectile mode: " + str(weapon_mode))
		queue_free()
		return
	$Visibility.screen_exited.connect(_on_screen_exited)

func register_hit(target: Node2D) -> bool:
	if is_queued_for_deletion() or pierce <= 0:
		return false
	var target_id: int = target.get_instance_id()
	if hit_targets.has(target_id):
		return false
	hit_targets[target_id] = true
	pierce -= 1
	if pierce <= 0:
		queue_free()
	return true

func _on_screen_exited() -> void:
	queue_free()
