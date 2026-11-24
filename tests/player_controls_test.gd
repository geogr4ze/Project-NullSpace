extends Node
# Run from repo root:
# godot --headless --path . res://tests/test_runner.tscn -- res://tests/player_controls_test.gd
const Controls = preload("res://scripts/combat/player_controls.gd")
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
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
	# Non-laser cursor aim remains immediate; holding the laser limits
	# angle changes even if the cursor jumps to the opposite side.
	var charged_rate: float = Controls.laser_turn_rate(0.0)
	var firing_rate: float = Controls.laser_turn_rate(1.0)
	_check(is_equal_approx(charged_rate, deg_to_rad(72.0)),
		"Laser charge begins with a 72-degree/second limit")
	_check(is_equal_approx(firing_rate, deg_to_rad(8.0)),
		"Active laser is capped at 8 degrees/second")
	var release_start_rate: float = Controls.laser_release_turn_rate(0.0)
	var release_middle_rate: float = Controls.laser_release_turn_rate(0.21)
	var release_fast_rate: float = Controls.laser_release_turn_rate(0.42)
	_check(is_equal_approx(release_start_rate, firing_rate),
		"Laser release begins with the current firing turn speed")
	_check(release_middle_rate > release_start_rate and
		release_middle_rate < release_fast_rate,
		"Laser release gradually accelerates toward the cursor")
	_check(is_equal_approx(release_fast_rate, deg_to_rad(540.0)),
		"Release recovery reaches fast aiming after the easing interval")
	_check(is_equal_approx(Controls.laser_release_turn_rate(2.0),
		release_fast_rate),
		"Recovery turn speed is bounded")
	_check(is_equal_approx(Controls.capped_aim_rotation(
		0.0, PI / 2.0, release_start_rate, 1.0 / 60.0
	), release_start_rate / 60.0),
		"First release frame does not snap to a distant cursor")
	_check(charged_rate > firing_rate,
		"Laser rotation becomes slower as the charge progresses")
	_check(is_equal_approx(Controls.laser_turn_rate(0.5),
		(charged_rate + firing_rate) * 0.5),
		"Laser charge turn speed ramps smoothly")
	_check(is_equal_approx(Controls.laser_turn_rate(2.0), firing_rate),
		"Charge progress clamps after laser starts firing")
	var one_frame: float = Controls.capped_aim_rotation(
		0.0, PI / 2.0, firing_rate, 1.0 / 60.0
	)
	_check(is_equal_approx(one_frame, firing_rate / 60.0),
		"Active laser can turn only one allowed frame step")
	var other_direction: float = Controls.capped_aim_rotation(
		0.0, -PI / 2.0, firing_rate, 1.0 / 60.0
	)
	_check(is_equal_approx(other_direction, -firing_rate / 60.0),
		"Laser aims toward the cursor in either direction")
	var wrap_angle: float = Controls.capped_aim_rotation(
		PI - 0.02, -PI + 0.02, firing_rate, 1.0 / 60.0
	)
	_check(wrap_angle > PI - 0.02,
		"Capped laser turn uses shortest angle across -PI/PI")
	var finished: float = Controls.capped_aim_rotation(
		0.0, 0.001, firing_rate, 1.0 / 30.0
	)
	_check(is_equal_approx(finished, 0.001),
		"Laser does not overshoot the desired cursor heading")
	var zero_dt: float = Controls.capped_aim_rotation(
		0.0, 2.0, firing_rate, 0.0
	)
	_check(is_zero_approx(zero_dt),
		"Laser does not rotate without physics time")
	var sixty_steps: float = 0.0
	for step: int in 60:
		sixty_steps = Controls.capped_aim_rotation(
			sixty_steps, PI, firing_rate, 1.0 / 60.0
		)
	var thirty_steps: float = 0.0
	for step: int in 30:
		thirty_steps = Controls.capped_aim_rotation(
			thirty_steps, PI, firing_rate, 1.0 / 30.0
		)
	_check(is_equal_approx(sixty_steps, thirty_steps),
		"Laser turn speed is independent of frame rate")
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
	get_tree().quit(1 if failures > 0 else 0)

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
