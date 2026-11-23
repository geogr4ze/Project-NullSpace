extends RigidBody2D

# Capture weapon properties on spawn, so switching modes does not change bullets
# already in flight. Each projectile damages each target at most once.
var weapon_mode := -1
var damage := 1
var pierce := 1
var hit_targets: Dictionary = {}

func configure_mode(mode: int) -> void:
	weapon_mode = mode

func _ready() -> void:
	if weapon_mode < 0:
		weapon_mode = Modecontrol.mode
	var mode_data: Dictionary = Modecontrol.modes[weapon_mode]
	$Skin.animation = mode_data["bullet_skin"]
	pierce = mode_data["pierce"]
	var shapes: Array[Shape2D] = [
		$BulletCollision.shape,
		$WaveCollision.shape,
		$LaserCollision.shape
	]
	$CollisionShape2D.shape = shapes[weapon_mode]
	$Visibility.screen_exited.connect(_on_screen_exited)

func register_hit(target: Node2D) -> bool:
	if is_queued_for_deletion() or pierce <= 0:
		return false
	var target_id := target.get_instance_id()
	if hit_targets.has(target_id):
		return false
	hit_targets[target_id] = true
	pierce -= 1
	if pierce <= 0:
		queue_free()
	return true

func _on_screen_exited() -> void:
	queue_free()
