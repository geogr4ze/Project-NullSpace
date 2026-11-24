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
