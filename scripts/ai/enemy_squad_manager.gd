extends Node

# One-to-one tank/support assignments, computed once for all enemies.
# This prevents several tanks from individually selecting the same support.
const TacticsScript = preload("res://scripts/ai/enemy_tactics.gd")
const ASSIGN_INTERVAL: float = 0.25
const MAX_SUPPORT_DISTANCE: float = 430.0
const REASSIGNMENT_BONUS: float = 0.8

# Launch coordinated left/right strikes when at least five Speed enemies
# are visible at once. The squad manager already runs at 4 Hz, so there
# is no extra per-enemy group scan for flanking.
const SPEED_PINCER_MIN_COUNT: int = 5
const SPEED_FLANK_READY_RADIUS: float = 135.0
const SPEED_PINCER_ATTACK_SECONDS: float = 3.75
const SPEED_PINCER_REFORM_SECONDS: float = 1.5

@onready var player: Node2D = $"../Player"
var pincer_attack_seconds: float = 0.0
var pincer_reform_seconds: float = 0.0

var time_until_assignment: float = 0.0

func _physics_process(delta: float) -> void:
	if pincer_attack_seconds > 0.0:
		pincer_attack_seconds = maxf(0.0, pincer_attack_seconds - delta)
		if pincer_attack_seconds == 0.0:
			pincer_reform_seconds = SPEED_PINCER_REFORM_SECONDS
	elif pincer_reform_seconds > 0.0:
		pincer_reform_seconds = maxf(0.0, pincer_reform_seconds - delta)
	time_until_assignment -= delta
	if time_until_assignment > 0.0:
		return
	time_until_assignment = ASSIGN_INTERVAL
	_assign_protectors()

func _assign_protectors() -> void:
	var tanks: Array[Area2D] = []
	var supports: Array[Area2D] = []
	var all_speeds: Array[Area2D] = []
	var visible_speeds: Array[Area2D] = []
	var screen_rect: Rect2 = get_viewport().get_visible_rect()
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
		elif int(enemy.get("type")) == Wavecontrol.SPEED:
			all_speeds.append(enemy)
			if screen_rect.has_point(
				enemy.get_global_transform_with_canvas().origin
			):
				visible_speeds.append(enemy)

	var candidates: Array[Dictionary] = []
	for tank: Area2D in tanks:
		# The previous support may have been freed during a combat tick.
		# Never cast a potentially freed Variant directly to Area2D.
		var previous_id: int = TacticsScript.valid_object_id(
			tank.get("protection_target")
		)
		for support: Area2D in supports:
			var distance: float = tank.global_position.distance_to(
				support.global_position)
			if distance > MAX_SUPPORT_DISTANCE:
				continue
			var score: float = distance
			# Prefer retaining an existing, eligible partner unless another
			# tank is materially closer to the same support.
			if previous_id == support.get_instance_id():
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

	_update_speed_pincer(all_speeds, visible_speeds)


func _reset_speed_pincer(speeds: Array[Area2D]) -> void:
	pincer_attack_seconds = 0.0
	pincer_reform_seconds = 0.0
	for speed_ship: Area2D in speeds:
		speed_ship.set("flank_state", 0)
		speed_ship.set("flank_side", 0)


func _update_speed_pincer(
		all_speeds: Array[Area2D],
		visible_speeds: Array[Area2D]
	) -> void:
	if visible_speeds.size() < SPEED_PINCER_MIN_COUNT or !is_instance_valid(player):
		_reset_speed_pincer(all_speeds)
		return

	# Off-screen enemies do not join or count toward a pincer until they
	# appear inside the viewport.
	for speed_ship: Area2D in all_speeds:
		if !visible_speeds.has(speed_ship):
			speed_ship.set("flank_state", 0)
			speed_ship.set("flank_side", 0)

	if pincer_reform_seconds > 0.0:
		for speed_ship: Area2D in visible_speeds:
			speed_ship.set("flank_state", 0)
		return

	visible_speeds.sort_custom(func(a: Area2D, b: Area2D) -> bool:
		return a.get_instance_id() < b.get_instance_id()
	)
	var ids: Array[int] = []
	var old_sides: Dictionary = {}
	for speed_ship: Area2D in visible_speeds:
		var ship_id: int = speed_ship.get_instance_id()
		ids.append(ship_id)
		old_sides[ship_id] = int(speed_ship.get("flank_side"))
	var sides: Dictionary = TacticsScript.assign_speed_flanks(ids, old_sides)

	var left_count: int = 0
	var right_count: int = 0
	for speed_ship: Area2D in visible_speeds:
		if int(sides[speed_ship.get_instance_id()]) < 0:
			left_count += 1
		else:
			right_count += 1

	var left_index: int = 0
	var right_index: int = 0
	var ready_left: int = 0
	var ready_right: int = 0
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	for speed_ship: Area2D in visible_speeds:
		var flank_side: int = int(sides[speed_ship.get_instance_id()])
		var lane: int = left_index if flank_side < 0 else right_index
		var lane_count: int = left_count if flank_side < 0 else right_count
		speed_ship.set("flank_side", flank_side)
		speed_ship.set("flank_lane", lane)
		speed_ship.set("flank_group_size", lane_count)
		if flank_side < 0:
			left_index += 1
		else:
			right_index += 1

		var flank_target: Vector2 = TacticsScript.speed_flank_target(
			player.global_position, screen_size, flank_side, lane, lane_count
		)
		if speed_ship.global_position.distance_to(flank_target) <= SPEED_FLANK_READY_RADIUS:
			if flank_side < 0:
				ready_left += 1
			else:
				ready_right += 1

	var attacking: bool = pincer_attack_seconds > 0.0
	if !attacking and (
		ready_left >= ceili(float(left_count) * 0.5)
		and ready_right >= ceili(float(right_count) * 0.5)
	):
		# Both wings are positioned. Launch them together toward the player.
		pincer_attack_seconds = SPEED_PINCER_ATTACK_SECONDS
		attacking = true
	for speed_ship: Area2D in visible_speeds:
		speed_ship.set("flank_state", 2 if attacking else 1)
