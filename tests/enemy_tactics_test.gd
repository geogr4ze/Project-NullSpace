extends SceneTree
# Run with: godot --headless --path . --script res://tests/enemy_tactics_test.gd
const Tactics = preload("res://scripts/ai/enemy_tactics.gd")
var failures: int = 0

func _initialize() -> void:
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
	var predicted: Vector2 = Tactics.predicted_intercept(
		Vector2(400, 0), player, Vector2(200, 0), 200.0)
	_check(predicted.x > player.x, "Fast enemies should lead a moving player")
	var retreat: Vector2 = Tactics.ranged_target(Vector2(80, 0), player, 250.0, 450.0, 1.0)
	_check(retreat.x > 80.0, "Ranged enemies should retreat when too close")
	var approach: Vector2 = Tactics.ranged_target(Vector2(900, 0), player, 250.0, 450.0, 1.0)
	_check(approach.x < 900.0, "Ranged enemies should approach when too far away")
	if failures > 0:
		push_error(str(failures) + " enemy tactics tests failed")
	quit(1 if failures > 0 else 0)

func _check(condition: bool, description: String) -> void:
	if !condition:
		failures += 1
		printerr("FAIL: " + description)
