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
	quit(1 if errors > 0 else 0)

func _check(description: String, ok: bool) -> void:
	if !ok:
		errors += 1
		printerr("FAIL: " + description)
