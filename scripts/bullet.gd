extends RigidBody2D

const ShipGlowScript = preload("res://scripts/visuals/ship_glow.gd")

# Capture weapon properties on spawn, so switching modes does not change bullets
# already in flight. Each projectile damages each target at most once.
const ENEMY_LAYER: int = 1 << 1
const TANK_SHIELD_LAYER: int = 1 << 9
const TANK_SWEEP_MASK: int = ENEMY_LAYER | TANK_SHIELD_LAYER
const WavePixelTrail = preload("res://scripts/visuals/wave_pixel_trail.gd")
const ProjectileBounds = preload("res://scripts/combat/projectile_bounds.gd")

var weapon_mode: int = -1
var damage: int = 1
var pierce: int = 1
var hit_targets: Dictionary = {}
var previous_position: Vector2 = Vector2.ZERO
var cleanup_radius: float = 32.0
@onready var projectile_glow: ShipGlowScript = $ProjectileGlow
@onready var wave_trail: WavePixelTrail = $WaveTrail

## Store the projectile's weapon mode before initialization.
func configure_mode(mode: int) -> void:
	weapon_mode = mode

## Initialize damage, pierce count, skin and effects using the configured weapon mode; defaults to the current player mode.
func _ready() -> void:
	if weapon_mode < 0:
		weapon_mode = Modecontrol.mode
	var mode_data: Dictionary = Modecontrol.modes[weapon_mode]
	$Skin.animation = mode_data["bullet_skin"]
	pierce = mode_data["pierce"]
	damage = mode_data["damage"]
	if weapon_mode == Modecontrol.DEFAULT:
		damage += Shopcontrol.upgrade_level("weapon")
	# The one continuous laser visual is on Player. Keep moving laser
	# projectiles and all their collisions, damage and pierce, but hide their
	# individual sprites so the beam has no visible gaps or repeated tips.
	$Skin.visible = weapon_mode != Modecontrol.MODE2
	# Reuse the ship glow's cached sprite-color sampler, but keep the original
	# bullet artwork and its collision untouched.
	if weapon_mode == Modecontrol.DEFAULT or weapon_mode == Modecontrol.MODE1:
		projectile_glow.intensity = 0.32 if weapon_mode == Modecontrol.DEFAULT else 0.08
		projectile_glow.match_sprite($Skin)
		if weapon_mode == Modecontrol.DEFAULT:
			projectile_glow.scale = Vector2(0.24, 0.42)
			projectile_glow.position = Vector2.ZERO
			# The regular shot should have a soft tint, not additive bloom.
			projectile_glow.material = null
		else:
			# Keep just a faint blue edge around the original wave pixels.
			# Normal blending prevents additive bloom overpowering the sprite.
			projectile_glow.scale = Vector2(1.82, 1.20)
			projectile_glow.position = Vector2(0, 45.0)
			projectile_glow.material = null
			wave_trail.start_emitting()
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
	# Include the full hull hitbox and visible sprite/glow, not just its center.
	var hitbox: CollisionShape2D = $CollisionShape2D
	cleanup_radius = maxf(cleanup_radius, ProjectileBounds.rect_radius(
		hitbox.transform, hitbox.shape.get_rect()
	))
	var skin: AnimatedSprite2D = $Skin
	if skin.visible:
		var texture: Texture2D = skin.sprite_frames.get_frame_texture(skin.animation, skin.frame)
		if texture != null:
			var size: Vector2 = texture.get_size()
			var origin: Vector2 = skin.offset - size * 0.5 if skin.centered else skin.offset
			cleanup_radius = maxf(cleanup_radius, ProjectileBounds.rect_radius(
				skin.transform, Rect2(origin, size)
			))
	if projectile_glow.visible:
		cleanup_radius = maxf(cleanup_radius, ProjectileBounds.rect_radius(
			projectile_glow.transform, projectile_glow.get_rect()
		))
	if weapon_mode == Modecontrol.MODE1:
		# Older pixels stay in world space. Allow the entire trailing wake
		# to clear the viewport as well, including its maximum outward drift.
		var speed: float = maxf(linear_velocity.length(), absf(float(mode_data["bullet_speed"])))
		var wake_radius: float = wave_trail.position.length() + wave_trail.emission_rect_extents.length()
		wake_radius += (speed + 26.0) * wave_trail.lifetime + 5.0
		cleanup_radius = maxf(cleanup_radius, wake_radius)

## Return whether the entire projectile is beyond the viewport cleanup margin.
func is_outside_playfield() -> bool:
	return ProjectileBounds.is_outside(self, cleanup_radius)

# Area2D enter events can miss a fast projectile that crosses an entire
# tank in one physics step. Sweep its travel segment against enemy areas
# as a fallback; the tank handles its own shield/hull precedence.
## Remove off-screen shots and sweep the previous-to-current travel segment to catch missed fast collisions; updates position history and may damage enemies.
func _physics_process(_delta: float) -> void:
	if is_queued_for_deletion():
		return
	if is_outside_playfield():
		queue_free()
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
			previous_position, current_position, TANK_SWEEP_MASK, excluded
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
			target.is_in_group("enemy_tanks")
		):
			target.call("intercept_projectile", self)
			if is_queued_for_deletion():
				break
		excluded.append(hit_area.get_rid())
	previous_position = current_position

## Record a unique target hit and consume one pierce; return false for repeated targets, exhausted pierce or a queued projectile.
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

