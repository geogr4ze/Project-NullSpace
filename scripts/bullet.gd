extends RigidBody2D

const ShipGlowScript = preload("res://scripts/visuals/ship_glow.gd")

# Capture weapon properties on spawn, so switching modes does not change bullets
# already in flight. Each projectile damages each target at most once.
var weapon_mode: int = -1
var damage: int = 1
var pierce: int = 1
var hit_targets: Dictionary = {}
var previous_position: Vector2 = Vector2.ZERO
@onready var projectile_glow: ShipGlowScript = $ProjectileGlow
@onready var wave_trail: CPUParticles2D = $WaveTrail

func configure_mode(mode: int) -> void:
	weapon_mode = mode

func _ready() -> void:
	if weapon_mode < 0:
		weapon_mode = Modecontrol.mode
	var mode_data: Dictionary = Modecontrol.modes[weapon_mode]
	$Skin.animation = mode_data["bullet_skin"]
	pierce = mode_data["pierce"]
	# The one continuous laser visual is on Player. Keep moving laser
	# projectiles and all their collisions, damage and pierce, but hide their
	# individual sprites so the beam has no visible gaps or repeated tips.
	$Skin.visible = weapon_mode != Modecontrol.MODE2
	# Reuse the ship glow's cached sprite-color sampler, but keep the original
	# bullet artwork and its collision untouched.
	if weapon_mode == Modecontrol.DEFAULT or weapon_mode == Modecontrol.MODE1:
		projectile_glow.intensity = 0.62 if weapon_mode == Modecontrol.DEFAULT else 0.70
		projectile_glow.match_sprite($Skin)
		if weapon_mode == Modecontrol.DEFAULT:
			projectile_glow.scale = Vector2(0.24, 0.42)
			projectile_glow.position = Vector2.ZERO
		else:
			# Broad wave projectile is horizontally oriented ahead of its origin.
			projectile_glow.scale = Vector2(1.85, 1.20)
			projectile_glow.position = Vector2(0, 49.5)
			# Tint the particles to the wave's existing artwork and fade them
			# in world-space, leaving a wake rather than an attached cloud.
			var tint: Color = projectile_glow.self_modulate
			wave_trail.color = Color(tint.r, tint.g, tint.b, 0.86)
	wave_trail.emitting = weapon_mode == Modecontrol.MODE1
	var authored_shape: CollisionShape2D
	if weapon_mode == Modecontrol.DEFAULT:
		authored_shape = $BulletCollision
	elif weapon_mode == Modecontrol.MODE1:
		authored_shape = $WaveCollision
	elif weapon_mode == Modecontrol.MODE2:
		authored_shape = $LaserCollision
	else:
		push_error("Invalid projectile mode: " + str(weapon_mode))
		queue_free()
		return
	# The authored wave/laser hitboxes use their own offsets and rotations.
	# Copy the full local transform, not just the Shape2D resource.
	$CollisionShape2D.shape = authored_shape.shape
	$CollisionShape2D.transform = authored_shape.transform
	previous_position = global_position
	add_to_group("player_projectiles")
	$Visibility.screen_exited.connect(_on_screen_exited)

# Area2D enter events can miss a fast projectile that crosses an entire
# tank in one physics step. Sweep its travel segment against enemy areas
# as a fallback; the tank handles its own shield/hull precedence.
func _physics_process(_delta: float) -> void:
	if is_queued_for_deletion():
		return
	var current_position: Vector2 = global_position
	if (previous_position.distance_squared_to(current_position) < 0.01
		or get_tree().get_node_count_in_group("enemy_tanks") == 0):
		previous_position = current_position
		return
	var excluded: Array[RID] = [get_rid()]
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for i: int in 8:
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			previous_position, current_position, 18, excluded
		)
		ray.collide_with_areas = true
		ray.collide_with_bodies = false
		ray.hit_from_inside = true
		var contact: Dictionary = space.intersect_ray(ray)
		if contact.is_empty():
			break
		var hit_area: Area2D = contact["collider"] as Area2D
		if hit_area == null:
			break
		# The shield sensor uses its own layer and larger shape. Route a ray
		# hitting either that sensor or the hull to the same tank handler.
		var target: Area2D = hit_area
		if hit_area.name == "TankShield":
			target = hit_area.get_parent() as Area2D
		if target != null and target.has_method("intercept_projectile") and (
			int(target.get("type")) == Wavecontrol.TANK
		):
			target.call("intercept_projectile", self)
			if is_queued_for_deletion():
				break
		excluded.append(hit_area.get_rid())
	previous_position = current_position

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
