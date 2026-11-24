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

# Returns a sideways escape vector when the enemy lies in the forward firing
# lane of the player's ship. The distance check rejects threats behind
# the ship; the lateral threshold limits dodging to visibly aimed-at targets.
static func firing_lane_escape(
		player_position: Vector2,
		facing: Vector2,
		enemy_position: Vector2,
		half_width: float,
		maximum_range: float,
		preferred_side: float
	) -> Vector2:
	if facing.length_squared() < 0.0001:
		return Vector2.ZERO
	var forward: Vector2 = facing.normalized()
	var relative: Vector2 = enemy_position - player_position
	var forward_distance: float = relative.dot(forward)
	if forward_distance <= 0.0 or forward_distance > maximum_range:
		return Vector2.ZERO
	var tangent: Vector2 = Vector2(-forward.y, forward.x)
	var lateral_distance: float = relative.dot(tangent)
	var width: float = maxf(half_width, 1.0)
	if absf(lateral_distance) >= width:
		return Vector2.ZERO
	var side: float = preferred_side
	if absf(lateral_distance) > 8.0:
		side = signf(lateral_distance)
	if side == 0.0:
		side = 1.0
	var urgency: float = 1.0 - absf(lateral_distance) / width
	return tangent * side * urgency

# The tank shield absorbs default and wave shots without taking damage.
# Only the large laser warrants evasive movement for tanks. Other enemy
# roles continue to respond to all player weapons.
static func can_evade_weapon(enemy_type: int, player_weapon_mode: int) -> bool:
	return enemy_type != Wavecontrol.TANK or player_weapon_mode == Modecontrol.MODE2

# An Object can be queued/freed while a tank still holds a reference to it.
# Check validity before accessing or casting it.
static func valid_object_id(candidate: Variant) -> int:
	if !is_instance_valid(candidate):
		return 0
	return candidate.get_instance_id()

# Keep surviving flank assignments stable while distributing newly visible
# speed enemies across two balanced sides. A group never grows more than one
# ship larger than the other.
static func assign_speed_flanks(
		speed_ids: Array[int],
		previous_sides: Dictionary
	) -> Dictionary:
	var sorted_ids: Array[int] = speed_ids.duplicate()
	sorted_ids.sort()
	var capacity: int = ceili(float(sorted_ids.size()) * 0.5)
	var assignments: Dictionary = {}
	var left_count: int = 0
	var right_count: int = 0
	for ship_id: int in sorted_ids:
		var old_side: int = int(previous_sides.get(ship_id, 0))
		if old_side == -1 and left_count < capacity:
			assignments[ship_id] = -1
			left_count += 1
		elif old_side == 1 and right_count < capacity:
			assignments[ship_id] = 1
			right_count += 1
	for ship_id: int in sorted_ids:
		if assignments.has(ship_id):
			continue
		var side: int = -1 if left_count <= right_count else 1
		assignments[ship_id] = side
		if side < 0:
			left_count += 1
		else:
			right_count += 1
	return assignments

# Staging targets keep the flanks near opposite horizontal screen edges while
# spreading members into separate lanes. They approach from above/below the
# player's y-position before both groups turn toward the player.
static func speed_flank_target(
		player_position: Vector2,
		viewport_size: Vector2,
		side: int,
		lane_index: int,
		lane_count: int
	) -> Vector2:
	var edge_margin: float = minf(85.0, viewport_size.x * 0.15)
	var y_margin: float = minf(85.0, viewport_size.y * 0.15)
	var edge_x: float = edge_margin if side < 0 else viewport_size.x - edge_margin
	var y_offset: float = -190.0 if side < 0 else 190.0
	var lane_offset: float = (
		float(lane_index) - float(maxi(lane_count, 1) - 1) * 0.5
	) * 70.0
	var target_y: float = clampf(
		player_position.y + y_offset + lane_offset,
		y_margin, viewport_size.y - y_margin
	)
	return Vector2(edge_x, target_y)
