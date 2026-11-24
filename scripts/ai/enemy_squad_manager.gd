extends Node

# One-to-one tank/support assignments, computed once for all enemies.
# This prevents several tanks from individually selecting the same support.
const TacticsScript = preload("res://scripts/ai/enemy_tactics.gd")
const ASSIGN_INTERVAL: float = 0.25
const MAX_SUPPORT_DISTANCE: float = 430.0
const REASSIGNMENT_BONUS: float = 0.8

var time_until_assignment: float = 0.0

func _physics_process(delta: float) -> void:
	time_until_assignment -= delta
	if time_until_assignment > 0.0:
		return
	time_until_assignment = ASSIGN_INTERVAL
	_assign_protectors()

func _assign_protectors() -> void:
	var tanks: Array[Area2D] = []
	var supports: Array[Area2D] = []
	for node: Node in get_tree().get_nodes_in_group("enemy_ai"):
		var enemy: Area2D = node as Area2D
		if enemy == null or !is_instance_valid(enemy):
			continue
		if !bool(enemy.get("alive")) or enemy.is_queued_for_deletion():
			continue
		if int(enemy.get("type")) == Wavecontrol.TANK:
			tanks.append(enemy)
		elif int(enemy.get("type")) == Wavecontrol.SUPPORT:
			supports.append(enemy)

	var candidates: Array[Dictionary] = []
	for tank: Area2D in tanks:
		var previous: Area2D = tank.get("protection_target") as Area2D
		for support: Area2D in supports:
			var distance: float = tank.global_position.distance_to(
				support.global_position)
			if distance > MAX_SUPPORT_DISTANCE:
				continue
			var score: float = distance
			# Prefer retaining an existing, eligible partner unless another
			# tank is materially closer to the same support.
			if previous == support:
				score *= REASSIGNMENT_BONUS
			candidates.append({
				"tank": tank,
				"support": support,
				"tank_id": tank.get_instance_id(),
				"support_id": support.get_instance_id(),
				"score": score
			})

	# Clear stale assignments first. A tank not paired this cycle chases
	# the player instead, and never targets someone else's assigned support.
	for tank: Area2D in tanks:
		tank.set("protection_target", null)

	for pair: Dictionary in TacticsScript.assign_unique_supports(candidates):
		var defender: Area2D = pair["tank"] as Area2D
		var protected_ally: Area2D = pair["support"] as Area2D
		if is_instance_valid(defender) and is_instance_valid(protected_ally):
			defender.set("protection_target", protected_ally)
