extends RefCounted

# The player's sprite and muzzle point along local UP (negative y), whereas
# Vector2.angle() measures from RIGHT. The quarter-turn matches those axes.
static func aim_rotation(
		ship_position: Vector2,
		cursor_position: Vector2,
		current_rotation: float
	) -> float:
	var to_cursor: Vector2 = cursor_position - ship_position
	if to_cursor.length_squared() < 0.0001:
		return current_rotation
	return to_cursor.angle() + PI * 0.5

# Input vector: W = (0,-1), S = (0,1), A = (-1,0), D = (1,0).
# Rotate that vector into ship-facing world space. Normalize first so
# pressing two movement keys never exceeds the normal maximum speed.
static func relative_move_direction(
		input_vector: Vector2,
		ship_rotation: float
	) -> Vector2:
	return input_vector.limit_length(1.0).rotated(ship_rotation)

# The laser should not sweep freely across the playfield. Turning is
# progressively constrained during charge and tightly capped while firing.
const LASER_CHARGE_TURN_RADIANS: float = PI * 90.0 / 180.0
const LASER_FIRE_TURN_RADIANS: float = PI * 32.0 / 180.0

static func laser_turn_rate(charge_fraction: float) -> float:
	return lerpf(
		LASER_CHARGE_TURN_RADIANS,
		LASER_FIRE_TURN_RADIANS,
		clampf(charge_fraction, 0.0, 1.0)
	)

# Move toward the shortest-angle cursor heading, but no further than the
# allowed angular rate this physics tick. Handles angles crossing +/- PI.
static func capped_aim_rotation(
		current_angle: float,
		target_angle: float,
		max_radians_per_second: float,
		delta: float
	) -> float:
	var max_step: float = maxf(max_radians_per_second, 0.0) * maxf(delta, 0.0)
	var difference: float = wrapf(target_angle - current_angle, -PI, PI)
	return current_angle + clampf(difference, -max_step, max_step)
