extends RefCounted
# Shared, deterministic steering geometry for enemy AI.
# The tank must actually lie between the player and the enemy; proximity alone
# is not sufficient to activate a formation.

const COVER_LATERAL_LIMIT: float = 130.0
const COVER_MIN_DEPTH: float = 18.0
const COVER_RANGE_MARGIN: float = 12.0
const COVER_TRAIL_DISTANCE: float = 135.0
const FORMATION_LANE_WIDTH: float = 55.0

static func tank_is_in_front(
		player_position: Vector2,
		tank_position: Vector2,
		enemy_position: Vector2
	) -> bool:
	var player_to_tank: Vector2 = tank_position - player_position
	var tank_distance: float = player_to_tank.length()
	if tank_distance < 1.0:
		return false
	# Enemies closer to the player than the tank always attack normally.
	var enemy_distance: float = enemy_position.distance_to(player_position)
	if enemy_distance <= tank_distance + COVER_RANGE_MARGIN:
		return false
	var forward: Vector2 = player_to_tank / tank_distance
	var tank_to_enemy: Vector2 = enemy_position - tank_position
	if tank_to_enemy.dot(forward) <= COVER_MIN_DEPTH:
		return false
	return absf(tank_to_enemy.cross(forward)) <= COVER_LATERAL_LIMIT

static func formation_target(
		player_position: Vector2,
		tank_position: Vector2,
		lane: int
	) -> Vector2:
	var forward: Vector2 = (tank_position - player_position).normalized()
	if forward == Vector2.ZERO:
		forward = Vector2.RIGHT
	var sideways: Vector2 = Vector2(-forward.y, forward.x)
	var lane_offset: float = float(clampi(lane, -2, 2)) * FORMATION_LANE_WIDTH
	return tank_position + forward * COVER_TRAIL_DISTANCE + sideways * lane_offset

static func predicted_intercept(
		enemy_position: Vector2,
		player_position: Vector2,
		player_velocity: Vector2,
		enemy_speed: float
	) -> Vector2:
	var distance: float = enemy_position.distance_to(player_position)
	var travel_time: float = clampf(distance / maxf(enemy_speed, 1.0) * 0.35, 0.0, 0.65)
	return player_position + player_velocity * travel_time

static func ranged_target(
		enemy_position: Vector2,
		player_position: Vector2,
		min_range: float,
		max_range: float,
		strafe_direction: float
	) -> Vector2:
	var away: Vector2 = enemy_position - player_position
	var distance: float = away.length()
	var direction: Vector2 = away.normalized() if distance >= 1.0 else Vector2.RIGHT
	if distance < min_range:
		return player_position + direction * (min_range + 45.0)
	if distance > max_range:
		return player_position + direction * ((min_range + max_range) * 0.5)
	# Orbit while at a safe firing range instead of sitting motionless.
	var tangent: Vector2 = Vector2(-direction.y, direction.x) * strafe_direction
	return enemy_position + tangent * 90.0

# Smooth interpolation is proportional to angular error, independent of frame
# rate. A larger responsiveness yields a faster turn without a single-frame snap.
static func smooth_heading(
		current_angle: float,
		desired_angle: float,
		responsiveness: float,
		delta: float
	) -> float:
	var weight: float = 1.0 - exp(-maxf(responsiveness, 0.0) * maxf(delta, 0.0))
	return lerp_angle(current_angle, desired_angle, weight)

# Greedy one-to-one matching. Every candidate has stable tank_id/support_id
# values, a score (lower is better), and optional tank/support node references.
# The same ordered inputs always produce identical assignments.
static func assign_unique_supports(
		candidates: Array[Dictionary]
	) -> Array[Dictionary]:
	var ranked: Array[Dictionary] = candidates.duplicate()
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: float = float(a["score"])
		var sb: float = float(b["score"])
		if !is_equal_approx(sa, sb):
			return sa < sb
		var ta: int = int(a["tank_id"])
		var tb: int = int(b["tank_id"])
		if ta != tb:
			return ta < tb
		return int(a["support_id"]) < int(b["support_id"])
	)
	var used_tanks: Dictionary = {}
	var used_supports: Dictionary = {}
	var matched: Array[Dictionary] = []
	for candidate: Dictionary in ranked:
		var tank_id: int = int(candidate["tank_id"])
		var support_id: int = int(candidate["support_id"])
		if used_tanks.has(tank_id) or used_supports.has(support_id):
			continue
		matched.append(candidate)
		used_tanks[tank_id] = true
		used_supports[support_id] = true
	return matched

# Pursuit is always the stronger component. Steering toward the ally's front
# screen position modifies the route, but cannot reverse its playerward motion.
static func tank_defense_target(
		tank_position: Vector2,
		player_position: Vector2,
		support_position: Vector2,
		screen_distance: float,
		pursuit_weight: float
	) -> Vector2:
	var toward_player: Vector2 = (player_position - tank_position).normalized()
	if toward_player == Vector2.ZERO:
		return tank_position
	var ally_to_player: Vector2 = (player_position - support_position).normalized()
	var screening_point: Vector2 = support_position + ally_to_player * screen_distance
	var toward_screen: Vector2 = (screening_point - tank_position).normalized()
	var chase_weight: float = clampf(pursuit_weight, 0.51, 1.0)
	var blended: Vector2 = (
		toward_player * chase_weight + toward_screen * (1.0 - chase_weight)
	).normalized()
	return tank_position + blended * 200.0

# Project an existing bullet and enemy's current velocities forward. Dodge
# only when their closest approach occurs in the future and would overlap
# their estimated combined collision widths. The chosen side is stable when
# a bullet is aimed directly at the center of the enemy.
static func projectile_evasion(
		bullet_position: Vector2,
		bullet_velocity: Vector2,
		enemy_position: Vector2,
		enemy_velocity: Vector2,
		hit_radius: float,
		time_horizon: float,
		preferred_side: float
	) -> Vector2:
	var relative_velocity: Vector2 = bullet_velocity - enemy_velocity
	var speed_squared: float = relative_velocity.length_squared()
	if speed_squared < 1.0 or time_horizon <= 0.0:
		return Vector2.ZERO
	var relative_position: Vector2 = enemy_position - bullet_position
	var closest_time: float = relative_position.dot(relative_velocity) / speed_squared
	if closest_time < 0.0 or closest_time > time_horizon:
		return Vector2.ZERO
	var miss_vector: Vector2 = relative_position - relative_velocity * closest_time
	var miss_distance: float = miss_vector.length()
	var radius: float = maxf(hit_radius, 1.0)
	if miss_distance > radius:
		return Vector2.ZERO
	var travel: Vector2 = relative_velocity / sqrt(speed_squared)
	var sideways: Vector2 = Vector2(-travel.y, travel.x)
	var cross_track: float = miss_vector.dot(sideways)
	var sign_direction: float = preferred_side
	if absf(cross_track) > 2.0:
		sign_direction = signf(cross_track)
	if sign_direction == 0.0:
		sign_direction = 1.0
	# Earlier, nearer direct impacts are more urgent; stay responsive even
	# at the horizon and near the edge of the estimated collision area.
	var urgency: float = 0.55 + 0.45 * (1.0 - closest_time / time_horizon)
	var overlap: float = 0.45 + 0.55 * (1.0 - minf(miss_distance / radius, 1.0))
	return sideways * sign_direction * urgency * overlap


# Conservative half-width of a collision shape perpendicular to a bullet's
# path. Supports the circle, rectangle and capsule shapes used by this game,
# including local rotations and scales of wave and laser projectiles.
static func collision_half_width(
		hitbox: CollisionShape2D,
		perpendicular: Vector2
	) -> float:
	if hitbox == null or hitbox.shape == null:
		return 0.0
	var axis_x: Vector2 = hitbox.global_transform.x
	var axis_y: Vector2 = hitbox.global_transform.y
	var shape: Shape2D = hitbox.shape
	if shape is RectangleShape2D:
		var rectangle: RectangleShape2D = shape as RectangleShape2D
		return (absf(perpendicular.dot(axis_x)) * rectangle.size.x
			+ absf(perpendicular.dot(axis_y)) * rectangle.size.y) * 0.5
	if shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = shape as CapsuleShape2D
		return (absf(perpendicular.dot(axis_x)) * capsule.radius
			+ absf(perpendicular.dot(axis_y)) * capsule.height * 0.5)
	if shape is CircleShape2D:
		var circle: CircleShape2D = shape as CircleShape2D
		return circle.radius * maxf(axis_x.length(), axis_y.length())
	return 0.0

# The tank shield absorbs default and wave shots without taking damage.
# Only an actual large laser projectile warrants evasive movement for tanks.
# Compare the in-flight projectile's captured mode, not the player's current
# selected mode (which may have changed after firing).
static func can_evade_weapon(enemy_type: int, projectile_weapon_mode: int) -> bool:
	return enemy_type != Wavecontrol.TANK or projectile_weapon_mode == Modecontrol.MODE2

# An Object can be queued/freed while a tank still holds a reference to it.
# Check validity before accessing or casting it.
static func valid_object_id(candidate: Variant) -> int:
	if !is_instance_valid(candidate):
		return 0
	return candidate.get_instance_id()

# Keep surviving flank assignments stable while distributing newly visible
# speed enemies across the top and bottom of the screen. Each wing differs
# by at most one ship.
static func assign_speed_flanks(
		speed_ids: Array[int],
		previous_sides: Dictionary
	) -> Dictionary:
	var sorted_ids: Array[int] = speed_ids.duplicate()
	sorted_ids.sort()
	var capacity: int = ceili(float(sorted_ids.size()) * 0.5)
	var assignments: Dictionary = {}
	var top_count: int = 0
	var bottom_count: int = 0
	for ship_id: int in sorted_ids:
		var old_side: int = int(previous_sides.get(ship_id, 0))
		if old_side == -1 and top_count < capacity:
			assignments[ship_id] = -1
			top_count += 1
		elif old_side == 1 and bottom_count < capacity:
			assignments[ship_id] = 1
			bottom_count += 1
	for ship_id: int in sorted_ids:
		if assignments.has(ship_id):
			continue
		var side: int = -1 if top_count <= bottom_count else 1
		assignments[ship_id] = side
		if side < 0:
			top_count += 1
		else:
			bottom_count += 1
	return assignments

# Stage at the TOP (-1) or BOTTOM (+1) edge of the arena, with
# distinct horizontal lanes centered on the player's current x position.
# Both groups then use their normal intercept targets during the attack.
static func speed_flank_target(
		player_position: Vector2,
		viewport_size: Vector2,
		side: int,
		lane_index: int,
		lane_count: int
	) -> Vector2:
	var x_margin: float = minf(85.0, viewport_size.x * 0.15)
	var y_margin: float = minf(85.0, viewport_size.y * 0.15)
	var edge_y: float = y_margin if side < 0 else viewport_size.y - y_margin
	var lane_offset: float = (
		float(lane_index) - float(maxi(lane_count, 1) - 1) * 0.5
	) * 70.0
	var target_x: float = clampf(
		player_position.x + lane_offset,
		x_margin, viewport_size.x - x_margin
	)
	return Vector2(target_x, edge_y)

# Long-range enemies enter the arena, then keep their distance rather than
# chasing. Retreat along the best available direction, including sideways
# along an edge when a direct escape would take them outside.
static func clamp_to_arena(position: Vector2, arena: Rect2) -> Vector2:
	return position.clamp(arena.position, arena.end)

static func railgun_target(position: Vector2, player_position: Vector2,
		arena: Rect2, minimum_range: float, strafe_side: float) -> Vector2:
	var inside: Vector2 = clamp_to_arena(position, arena)
	if not position.is_equal_approx(inside):
		return inside
	if position.distance_to(player_position) >= minimum_range:
		return position
	var away: Vector2 = (position - player_position).normalized()
	if away.is_zero_approx():
		away = Vector2.RIGHT
	var best: Vector2 = position
	var best_score: float = position.distance_to(player_position)
	for i: int in 8:
		var direction: Vector2 = away.rotated(float(i) * TAU / 8.0 * strafe_side)
		var candidate: Vector2 = clamp_to_arena(position + direction * 240.0, arena)
		var score: float = candidate.distance_to(player_position)
		if score > best_score + 0.01:
			best_score = score
			best = candidate
	return best
