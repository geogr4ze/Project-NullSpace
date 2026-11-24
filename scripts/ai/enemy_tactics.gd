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
