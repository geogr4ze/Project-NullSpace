extends Node
# Run with: godot --headless --path . res://tests/test_runner.tscn -- res://tests/enemy_tactics_test.gd
const Tactics = preload("res://scripts/ai/enemy_tactics.gd")
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var player: Vector2 = Vector2(0, 0)
	var tank: Vector2 = Vector2(120, 0)
	_check(Tactics.tank_is_in_front(player, tank, Vector2(270, 0)),
		"Enemy directly behind an on-screen tank should seek cover")
	_check(!Tactics.tank_is_in_front(player, tank, Vector2(70, 0)),
		"Enemy closer to player than tank must continue attacking")
	_check(!Tactics.tank_is_in_front(player, tank, Vector2(135, 0)),
		"Enemy alongside the tank must not treat it as cover")
	_check(!Tactics.tank_is_in_front(player, tank, Vector2(270, 240)),
		"Enemy far off to the side must not treat tank as cover")
	_check(!Tactics.tank_is_in_front(player, Vector2.ZERO, Vector2(270, 0)),
		"Tank at player position is invalid cover")
	_check(!Tactics.tank_is_in_front(player, Vector2(300, 0), Vector2(180, 0)),
		"Tank behind enemy is not cover")
	var center: Vector2 = Tactics.formation_target(player, tank, 0)
	var left: Vector2 = Tactics.formation_target(player, tank, -1)
	var right: Vector2 = Tactics.formation_target(player, tank, 1)
	_check(center.x > tank.x and is_equal_approx(center.y, tank.y),
		"Formation slots must stay behind the tank")
	_check(left.y < center.y and right.y > center.y,
		"Different lanes must spread enemies behind the tank")
	# Turning by interpolation must respect time rather than rendering FPS.
	var one_step: float = Tactics.smooth_heading(0.0, PI / 2.0, 5.0, 1.0 / 60.0)
	_check(one_step > 0.0 and one_step < PI / 2.0,
		"Smooth turning advances without snapping to the destination")
	var sixty_steps: float = 0.0
	for i: int in 60:
		sixty_steps = Tactics.smooth_heading(sixty_steps, PI / 2.0, 5.0, 1.0 / 60.0)
	var thirty_steps: float = 0.0
	for i: int in 30:
		thirty_steps = Tactics.smooth_heading(thirty_steps, PI / 2.0, 5.0, 1.0 / 30.0)
	_check(absf(sixty_steps - thirty_steps) < 0.001,
		"Turn smoothing is independent of rendering frame rate")
	var player_position: Vector2 = Vector2.ZERO
	var tank_position: Vector2 = Vector2(500.0, 0.0)
	var support_position: Vector2 = Vector2(900.0, 150.0)
	var guard_goal: Vector2 = Tactics.tank_defense_target(
		tank_position, player_position, support_position, 150.0, 0.7
	)
	_check((guard_goal - tank_position).dot(
		player_position - tank_position) > 0.0,
		"Protecting a support never makes a tank retreat from the player")
	# The tank evaluates each in-flight projectile's captured weapon mode.
	# Switching the player's active weapon cannot change an existing shot.
	_check(!Tactics.can_evade_weapon(Wavecontrol.TANK, Modecontrol.DEFAULT),
		"Tank ignores default fire")
	_check(!Tactics.can_evade_weapon(Wavecontrol.TANK, Modecontrol.MODE1),
		"Tank ignores wave fire")
	_check(Tactics.can_evade_weapon(Wavecontrol.TANK, Modecontrol.MODE2),
		"Tank evades the damaging laser")
	for non_tank: int in [
		Wavecontrol.BASIC, Wavecontrol.SPEED, Wavecontrol.SUPPORT,
		Wavecontrol.RAILGUN, Wavecontrol.MINESHIP
	]:
		_check(Tactics.can_evade_weapon(non_tank, Modecontrol.DEFAULT),
			"Non-tank enemies still evade default fire")
		_check(Tactics.can_evade_weapon(non_tank, Modecontrol.MODE1),
			"Non-tank enemies still evade wave fire")
		_check(Tactics.can_evade_weapon(non_tank, Modecontrol.MODE2),
			"Non-tank enemies still evade laser fire")
	# Only enemies inside the player's forward firing lane try to dodge.
	var center_dodge: Vector2 = Tactics.firing_lane_escape(
		player, Vector2.RIGHT, Vector2(250, 0), 100.0, 950.0, 1.0
	)
	_check(center_dodge.y > 0.9 and absf(center_dodge.x) < 0.01,
		"An enemy directly ahead should evade sideways")
	var side_dodge: Vector2 = Tactics.firing_lane_escape(
		player, Vector2.RIGHT, Vector2(250, -45), 100.0, 950.0, 1.0
	)
	_check(side_dodge.y < 0.0, "Evade toward the nearest edge of the firing lane")
	var outside_dodge: Vector2 = Tactics.firing_lane_escape(
		player, Vector2.RIGHT, Vector2(250, 130), 100.0, 950.0, 1.0
	)
	_check(outside_dodge == Vector2.ZERO, "Do not dodge if outside the firing lane")
	var behind_dodge: Vector2 = Tactics.firing_lane_escape(
		player, Vector2.RIGHT, Vector2(-200, 0), 100.0, 950.0, -1.0
	)
	_check(behind_dodge == Vector2.ZERO, "Do not dodge shots aimed away from enemies")
	var far_dodge: Vector2 = Tactics.firing_lane_escape(
		player, Vector2.RIGHT, Vector2(1200, 0), 100.0, 950.0, 1.0
	)
	_check(far_dodge == Vector2.ZERO, "Do not dodge outside the firing range")
	var quarter_dodge: Vector2 = Tactics.firing_lane_escape(
		player, Vector2.RIGHT, Vector2(250, 50), 100.0, 950.0, 1.0
	)
	_check(quarter_dodge.y > 0.0 and quarter_dodge.y < center_dodge.y,
		"Evade less aggressively near the edge of the lane")
	var predicted: Vector2 = Tactics.predicted_intercept(
		Vector2(400, 0), player, Vector2(200, 0), 200.0)
	_check(predicted.x > player.x, "Fast enemies should lead a moving player")
	var retreat: Vector2 = Tactics.ranged_target(Vector2(80, 0), player, 250.0, 450.0, 1.0)
	_check(retreat.x > 80.0, "Ranged enemies should retreat when too close")
	var approach: Vector2 = Tactics.ranged_target(Vector2(900, 0), player, 250.0, 450.0, 1.0)
	_check(approach.x < 900.0, "Ranged enemies should approach when too far away")
	if failures > 0:
		push_error(str(failures) + " enemy tactics tests failed")
	get_tree().quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if !condition:
		failures += 1
		printerr("FAIL: " + description)
