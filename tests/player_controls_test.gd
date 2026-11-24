extends SceneTree
# Run from repo root:
# godot --headless --path . --script res://tests/player_controls_test.gd
const Controls = preload("res://scripts/combat/player_controls.gd")
var failures: int = 0

func _initialize() -> void:
	var center: Vector2 = Vector2(500.0, 400.0)
	_check(_same_angle(
		Controls.aim_rotation(center, center + Vector2.UP * 100.0, 1.0), 0.0
	), "Mouse above ship aims forward/up")
	_check(_same_angle(
		Controls.aim_rotation(center, center + Vector2.RIGHT * 100.0, 0.0), PI / 2.0
	), "Mouse right of ship aims right")
	_check(_same_angle(
		Controls.aim_rotation(center, center + Vector2.DOWN * 100.0, 0.0), PI
	), "Mouse below ship aims down")
	_check(_same_angle(
		Controls.aim_rotation(center, center + Vector2.LEFT * 100.0, 0.0), -PI / 2.0
	), "Mouse left of ship aims left")
	_check(is_equal_approx(Controls.aim_rotation(center, center, 1.2), 1.2),
		"Coincident cursor does not trigger erratic rotation")
	_check(Controls.relative_move_direction(Vector2.UP, 0.0).is_equal_approx(
		Vector2.UP), "W goes forward with ship facing up")
	_check(Controls.relative_move_direction(Vector2.DOWN, 0.0).is_equal_approx(
		Vector2.DOWN), "S goes backward with ship facing up")
	_check(Controls.relative_move_direction(Vector2.LEFT, 0.0).is_equal_approx(
		Vector2.LEFT), "A strafes left with ship facing up")
	_check(Controls.relative_move_direction(Vector2.RIGHT, 0.0).is_equal_approx(
		Vector2.RIGHT), "D strafes right with ship facing up")
	_check(Controls.relative_move_direction(Vector2.UP, PI / 2.0).is_equal_approx(
		Vector2.RIGHT), "W follows the mouse when aiming right")
	_check(Controls.relative_move_direction(Vector2.LEFT, PI / 2.0).is_equal_approx(
		Vector2.UP), "A strafes left relative to the mouse-facing ship")
	var diagonal: Vector2 = Controls.relative_move_direction(
		Vector2(-1, -1), PI / 3.0
	)
	_check(is_equal_approx(diagonal.length(), 1.0),
		"Diagonal WASD does not increase movement speed")
	_check(Controls.relative_move_direction(Vector2.ZERO, PI).is_zero_approx(),
		"No keypress results in no commanded movement")
	_check(_mapped_to_key("strafe_left", KEY_A), "A is mapped to strafe_left")
	_check(_mapped_to_key("strafe_right", KEY_D), "D is mapped to strafe_right")
	_check(_mapped_to_key("move_forward", KEY_W), "W remains forward")
	_check(_mapped_to_key("move_backward", KEY_S), "S remains backward")
	_check(InputMap.has_action("Fire") and InputMap.has_action("dash"),
		"Existing Fire and E dash actions are present")
	_check(is_equal_approx(1.8 * 1.5, 2.7),
		"Speed multiplier scales the base Speed enemy stat to 2.7")
	if failures > 0:
		push_error(str(failures) + " player controls tests failed")
	quit(1 if failures > 0 else 0)

func _mapped_to_key(action_name: String, expected: Key) -> bool:
	if !InputMap.has_action(action_name):
		return false
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == expected:
			return true
	return false

func _same_angle(first: float, second: float) -> bool:
	return absf(wrapf(first - second, -PI, PI)) < 0.0001

func _check(ok: bool, label: String) -> void:
	if !ok:
		failures += 1
		printerr("FAIL: " + label)
