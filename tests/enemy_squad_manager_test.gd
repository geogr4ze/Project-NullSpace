extends SceneTree
const Tactics = preload("res://scripts/ai/enemy_tactics.gd")
var errors: int = 0

func _initialize() -> void:
	var single_support: Array[Dictionary] = [
		{"tank_id": 1, "support_id": 10, "score": 70.0},
		{"tank_id": 2, "support_id": 10, "score": 80.0}
	]
	_check("one tank per support",
		Tactics.assign_unique_supports(single_support).size() == 1)
	var candidates: Array[Dictionary] = [
		{"tank_id": 1, "support_id": 10, "score": 70.0},
		{"tank_id": 2, "support_id": 10, "score": 80.0},
		{"tank_id": 2, "support_id": 11, "score": 60.0},
		{"tank_id": 1, "support_id": 11, "score": 90.0},
		{"tank_id": 3, "support_id": 11, "score": 100.0}
	]
	var assigned: Array[Dictionary] = Tactics.assign_unique_supports(candidates)
	_check("two distinct tank/support pairs", assigned.size() == 2)
	var used_tanks: Dictionary = {}
	var used_supports: Dictionary = {}
	for pair: Dictionary in assigned:
		var tank_id: int = int(pair["tank_id"])
		var support_id: int = int(pair["support_id"])
		_check("tank not repeated", !used_tanks.has(tank_id))
		_check("support not repeated", !used_supports.has(support_id))
		used_tanks[tank_id] = true
		used_supports[support_id] = true
	_check("closest pair assigned first",
		int(assigned[0]["tank_id"]) == 2 and
		int(assigned[0]["support_id"]) == 11)
	_check("remaining support has remaining tank",
		int(assigned[1]["tank_id"]) == 1 and
		int(assigned[1]["support_id"]) == 10)
	# Equal scores must be deterministically broken by instance IDs.
	var tied_candidates: Array[Dictionary] = [
		{"tank_id": 8, "support_id": 2, "score": 100.0},
		{"tank_id": 7, "support_id": 2, "score": 100.0}
	]
	var equal_pairs: Array[Dictionary] = Tactics.assign_unique_supports(tied_candidates)
	_check("stable equal-score tie breaking",
		int(equal_pairs[0]["tank_id"]) == 7)
	# Regression for the freed-reference cast at the former line 35.
	var old_support: Node2D = Node2D.new()
	var stale_reference: Variant = old_support
	var support_id: int = old_support.get_instance_id()
	_check("living support gets an ID", Tactics.valid_object_id(stale_reference) == support_id)
	old_support.free()
	_check("freed support does not get cast or accessed",
		Tactics.valid_object_id(stale_reference) == 0)
	_check("null support is safe", Tactics.valid_object_id(null) == 0)

	# A fifth visible speed triggers two balanced, stable flanks.
	var ids: Array[int] = [10, 11, 12, 13, 14]
	var flanks: Dictionary = Tactics.assign_speed_flanks(ids, {})
	var top_count: int = 0
	var bottom_count: int = 0
	for speed_id: int in ids:
		if int(flanks[speed_id]) == -1:
			top_count += 1
		elif int(flanks[speed_id]) == 1:
			bottom_count += 1
	_check("five Speed enemies split 3-2",
		top_count == 3 and bottom_count == 2)
	_check("flank assignment remains stable without deaths",
		Tactics.assign_speed_flanks(ids, flanks) == flanks)
	var crowded_previous: Dictionary = {
		10: -1, 11: -1, 12: -1, 13: -1, 14: 1
	}
	var balanced: Dictionary = Tactics.assign_speed_flanks(ids, crowded_previous)
	var top_rebalanced: int = 0
	var bottom_rebalanced: int = 0
	for side: Variant in balanced.values():
		if int(side) < 0:
			top_rebalanced += 1
		else:
			bottom_rebalanced += 1
	_check("existing flanks rebalance when heavily uneven",
		top_rebalanced == 3 and bottom_rebalanced == 2)

	var arena: Vector2 = Vector2(1700.0, 900.0)
	var center: Vector2 = Vector2(850.0, 450.0)
	var top: Vector2 = Tactics.speed_flank_target(center, arena, -1, 0, 3)
	var top_next: Vector2 = Tactics.speed_flank_target(center, arena, -1, 1, 3)
	var bottom: Vector2 = Tactics.speed_flank_target(center, arena, 1, 0, 2)
	_check("top group stages at top edge", top.y < arena.y * 0.15)
	_check("bottom group stages at bottom edge", bottom.y > arena.y * 0.85)
	_check("pincer staging lanes spread horizontally", top.x != top_next.x)
	_check("top and bottom wings align horizontally with player",
		absf(top.x - center.x) < 100.0
		and absf(bottom.x - center.x) < 100.0)
	_check("all flank staging positions remain inside viewport",
		Rect2(Vector2.ZERO, arena).has_point(top)
		and Rect2(Vector2.ZERO, arena).has_point(bottom))
	var player_near_right: Vector2 = Vector2(1680, 420)
	var constrained_top: Vector2 = Tactics.speed_flank_target(
		player_near_right, arena, -1, 2, 3
	)
	_check("staging stays on screen when player nears an edge",
		Rect2(Vector2.ZERO, arena).has_point(constrained_top))
	quit(1 if errors > 0 else 0)

func _check(description: String, ok: bool) -> void:
	if !ok:
		errors += 1
		printerr("FAIL: " + description)
