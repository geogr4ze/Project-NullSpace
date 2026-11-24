extends Area2D

const PlayerShipScript = preload("res://scripts/player.gd")
const PlayerProjectileScript = preload("res://scripts/bullet.gd")
const TacticsScript = preload("res://scripts/ai/enemy_tactics.gd")

var bullet_scene: PackedScene = preload("res://scenes/enemy_bullet.tscn")
var mine_scene: PackedScene = preload("res://scenes/enemy_mine.tscn")
@onready var player: PlayerShipScript = $"../Player"
@onready var hpbar: ProgressBar = $Node2D/ProgressBar
@onready var skin: AnimatedSprite2D = $Skin
@onready var warning_sign: AnimatedSprite2D = $%Warning_Sign
@onready var railgun_muzzle: Marker2D = $RGMuzzle
@onready var mine_spawn: Marker2D = $MineSpawn
var hpvis_time: float = 0.0

var health: int
var speed: float
var type: int = -1
var score_amount: int
var reward_amount: int

var tank_shield_hp: int = 25
var max_tank_shield_hp: int = tank_shield_hp
var RGbullet_speed: float = -1000.0

# Decision-making is intentionally slower than physics movement: nearby enemies
# are sampled five times per second, with a small stagger between ships.
const AI_DECISION_INTERVAL: float = 0.2
const AI_COMMITMENT: float = 0.5
const SUPPORT_TARGET_DISTANCE: float = 420.0
const AVOIDANCE_WEIGHT: float = 0.75
const FIRING_LANE_HALF_WIDTH: float = 100.0
const FIRING_LANE_RANGE: float = 950.0
const FIRING_LANE_DODGE_WEIGHT: float = 2.3
const FIRING_LANE_REACTION_TIME: float = 0.6
const TURN_RESPONSE_NEAR: float = 8.0
const TURN_RESPONSE_FAR: float = 4.0
const TURN_DISTANCE_REFERENCE: float = 750.0
const SPEED_TURN_MULTIPLIER: float = 1.25
const STEERING_ACCELERATION_MULTIPLIER: float = 5.0
const STEERING_ACCELERATION_MINIMUM: float = 200.0
const TANK_PURSUIT_WEIGHT: float = 0.70
const TANK_SCREENING_DISTANCE: float = 150.0

var ai_elapsed: float = 0.0
var decision_timer: float = 0.0
var cover_commit_until: float = 0.0
var cover_reacquire_after: float = 0.0
var cover_tank: Area2D
var healing_target: Area2D
var protection_target: Area2D
var separation: Vector2 = Vector2.ZERO
var cover_lane: int = 0
var strafe_direction: float = 1.0
var motion_velocity: Vector2 = Vector2.ZERO
var firing_lane_dodge_time: float = 0.0

# Controlled by EnemySquadManager when five or more Speed enemies are visible.
# State 0: individual intercept, 1: move to assigned edge, 2: pincer strike.
var flank_state: int = 0
var flank_side: int = 0
var flank_lane: int = 0
var flank_group_size: int = 1

func configure_enemy(enemy_type: int) -> void:
	type = enemy_type

func _ready():
	if type < 0:
		type = Wavecontrol.selection
	if type == Wavecontrol.SUPPORT:
		$%AoeSCollision.disabled = false
		$%AoeSkin.visible = true
	if type == Wavecontrol.TANK:
		$%ShieldCollision.set_deferred("disabled", false)
		$%Shield.self_modulate = Color(1.0, 1.0, 1.0, 0.3)
		$%Shield.visible = true
	if type == Wavecontrol.RAILGUN:
		$RGShootTimer.wait_time = randf_range(15.0, 30.0)
		$RGShootTimer.start()
	if type == Wavecontrol.MINESHIP:
		$MineTimer.wait_time = randf_range(5.0, 20.0)
		$MineTimer.start()
	if !Wavecontrol.enemies.has(type):
		push_error("Unknown enemy type: " + str(type))
		queue_free()
		return
	_apply_enemy_stats(type)
	var shapes: Array[Shape2D] = [
		$BasicCollision.shape,
		$SpeedCollision.shape,
		$SupportCollision.shape,
		$TankCollision.shape,
		$RailgunCollision.shape,
		$MineShipCollision.shape
	]
	skin.animation = Wavecontrol.enemies[type]["enemy_skin"]
	$CollisionShape2D.shape = shapes[type]
	if type != Wavecontrol.MINESHIP:
		skin.play()
	hpbar.self_modulate.a = 0
	cover_lane = int(get_instance_id() % 5) - 2
	strafe_direction = -1.0 if randf() < 0.5 else 1.0
	decision_timer = randf_range(0.0, AI_DECISION_INTERVAL)
	add_to_group("enemy_ai")
	if type == Wavecontrol.TANK:
		add_to_group("enemy_tanks")

# Convert original per-frame speed values into pixels/second (at 60 FPS).
func _apply_enemy_stats(enemy: int) -> void:
	score_amount = Wavecontrol.enemies[enemy]["score"]
	reward_amount = Wavecontrol.enemies[enemy]["reward"]
	health = Wavecontrol.enemies[enemy]["health"]
	hpbar.max_value = health
	hpbar.value = health
	speed = (Wavecontrol.enemies[enemy]["enemy_speed"] + randf_range(0.01, 0.3)) * 60.0

func _physics_process(delta: float) -> void:
	if !alive or !is_instance_valid(player):
		return
	ai_elapsed += delta
	decision_timer -= delta
	if decision_timer <= 0.0:
		_update_ai_decision()
		decision_timer = AI_DECISION_INTERVAL + randf_range(0.0, 0.06)

	# Even during the 0.5 s formation commitment, an enemy that overtakes its
	# tank immediately returns to its own attack behavior.
	var goal: Vector2 = _movement_goal()
	var direction_to_goal: Vector2 = goal - global_position
	var preferred_velocity: Vector2 = Vector2.ZERO
	if direction_to_goal.length() > 12.0:
		preferred_velocity = direction_to_goal.normalized() * speed
		preferred_velocity *= clampf(direction_to_goal.length() / 65.0, 0.0, 1.0)
	# Tanks ignore default and wave fire: their shields already absorb those
	# projectiles. All other enemies evade every weapon, while tanks only
	# evade the large laser (including its charge-up). Clear a tank's dodge
	# memory immediately when the player switches away from the laser.
	var can_evade_weapon: bool = TacticsScript.can_evade_weapon(type, Modecontrol.mode)
	if !can_evade_weapon:
		firing_lane_dodge_time = 0.0
	elif Input.is_action_pressed("Fire"):
		firing_lane_dodge_time = FIRING_LANE_REACTION_TIME
	else:
		firing_lane_dodge_time = maxf(0.0, firing_lane_dodge_time - delta)
	var evasion: Vector2 = Vector2.ZERO
	if firing_lane_dodge_time > 0.0:
		var player_forward: Vector2 = Vector2.UP.rotated(player.global_rotation)
		evasion = TacticsScript.firing_lane_escape(
			player.global_position, player_forward, global_position,
			FIRING_LANE_HALF_WIDTH, FIRING_LANE_RANGE, strafe_direction
		)
	var desired_velocity: Vector2 = (
		preferred_velocity + separation * speed * AVOIDANCE_WEIGHT
		+ evasion * speed * FIRING_LANE_DODGE_WEIGHT
	).limit_length(speed)
	# Steering acceleration prevents sudden sideways movement when an intercept
	# point changes; turning and movement follow the same physics delta.
	var acceleration: float = maxf(
		STEERING_ACCELERATION_MINIMUM, speed * STEERING_ACCELERATION_MULTIPLIER
	)
	motion_velocity = motion_velocity.move_toward(desired_velocity, acceleration * delta)
	global_position += motion_velocity * delta

	# Speed ships point where they are actually flying, not straight toward
	# the player's old position. Other ships preserve player-facing attacks.
	var desired_heading: float = (player.global_position - global_position).angle()
	if type == Wavecontrol.SPEED and motion_velocity.length_squared() > 4.0:
		desired_heading = motion_velocity.angle()
	var distance_to_player: float = global_position.distance_to(player.global_position)
	var distance_ratio: float = clampf(
		distance_to_player / TURN_DISTANCE_REFERENCE, 0.0, 1.0
	)
	var response: float = lerpf(
		TURN_RESPONSE_NEAR, TURN_RESPONSE_FAR, distance_ratio
	)
	if type == Wavecontrol.SPEED:
		response *= SPEED_TURN_MULTIPLIER
	rotation = TacticsScript.smooth_heading(rotation, desired_heading, response, delta)
	$Node2D.global_rotation = 0
	if type == Wavecontrol.RAILGUN:
		warning_RG()
		warning_sign.global_rotation = 0

func _tank_in_front(candidate: Area2D) -> bool:
	if candidate == null or !is_instance_valid(candidate):
		return false
	if !candidate.is_inside_tree() or candidate.is_queued_for_deletion():
		return false
	if !candidate.is_in_group("enemy_ai"):
		return false
	if !bool(candidate.get("alive")) or int(candidate.get("type")) != Wavecontrol.TANK:
		return false
	# An unshielded tank no longer provides reliable cover.
	if int(candidate.get("tank_shield_hp")) <= 0:
		return false
	if !get_viewport().get_visible_rect().has_point(
		candidate.get_global_transform_with_canvas().origin
	):
		return false
	return TacticsScript.tank_is_in_front(
		player.global_position, candidate.global_position, global_position
	)

func _update_ai_decision() -> void:
	var new_tank: Area2D
	var closest_tank_distance: float = INF
	var new_healing_target: Area2D
	var most_urgent_heal: float = INF
	var avoidance: Vector2 = Vector2.ZERO

	for node: Node in get_tree().get_nodes_in_group("enemy_ai"):
		if node == self or !is_instance_valid(node):
			continue
		var ally: Area2D = node as Area2D
		if ally == null or !ally.is_inside_tree() or ally.is_queued_for_deletion():
			continue
		if !bool(ally.get("alive")):
			continue
		var ally_type: int = int(ally.get("type"))
		var offset: Vector2 = global_position - ally.global_position
		var distance: float = offset.length()

		# Sample neighboring ships for collision-free spacing. This runs once
		# per AI decision instead of scanning all enemies every physics tick.
		var minimum_spacing: float = 75.0
		if type == Wavecontrol.TANK or ally_type == Wavecontrol.TANK:
			minimum_spacing = 115.0
		if distance > 0.1 and distance < minimum_spacing:
			avoidance += offset / distance * (1.0 - distance / minimum_spacing)

		if type != Wavecontrol.TANK and ally_type == Wavecontrol.TANK:
			if distance < closest_tank_distance and _tank_in_front(ally):
				new_tank = ally
				closest_tank_distance = distance

		if type == Wavecontrol.SUPPORT and ally_type != Wavecontrol.SUPPORT:
			var max_ally_health: int = int(Wavecontrol.enemies[ally_type]["health"])
			var ally_health: int = int(ally.get("health"))
			var missing_health: int = max_ally_health - ally_health
			if missing_health > 0 and distance < SUPPORT_TARGET_DISTANCE:
				# Missing health outweighs slight differences in distance.
				var urgency: float = distance - float(missing_health) * 4.0
				if urgency < most_urgent_heal:
					new_healing_target = ally
					most_urgent_heal = urgency

	separation = avoidance.limit_length(1.0)
	healing_target = new_healing_target

	# Losing positional cover always cancels the formation immediately.
	# A short re-entry delay prevents border oscillation without forcing
	# enemies that have overtaken the tank to backtrack to it.
	if cover_tank != null and !_tank_in_front(cover_tank):
		cover_tank = null
		cover_reacquire_after = ai_elapsed + AI_COMMITMENT
	if new_tank != null:
		if cover_tank == null and ai_elapsed >= cover_reacquire_after:
			cover_tank = new_tank
			cover_commit_until = ai_elapsed + AI_COMMITMENT
		elif cover_tank != null and cover_tank != new_tank:
			if ai_elapsed >= cover_commit_until:
				cover_tank = new_tank
				cover_commit_until = ai_elapsed + AI_COMMITMENT

func _movement_goal() -> Vector2:
	# Formation is prioritized only if the tank is currently *in front* of
	# this enemy from the player's perspective. Enemies closer than the tank
	# always pursue their normal role, even inside the commitment window.
	if type != Wavecontrol.TANK and _tank_in_front(cover_tank):
		return TacticsScript.formation_target(
			player.global_position, cover_tank.global_position, cover_lane
		)

	# Group staging overrides the ordinary Speed intercept, but the tank
	# cover rule above still wins when a protected tank is in front.
	if type == Wavecontrol.SPEED and flank_state == 1 and flank_side != 0:
		return TacticsScript.speed_flank_target(
			player.global_position,
			get_viewport().get_visible_rect().size,
			flank_side,
			flank_lane,
			flank_group_size
		)

	match type:
		Wavecontrol.SPEED:
			return TacticsScript.predicted_intercept(
				global_position, player.global_position, player.velocity, speed
			)
		Wavecontrol.SUPPORT:
			if is_instance_valid(healing_target):
				var ally_position: Vector2 = healing_target.global_position
				var away_from_player: Vector2 = (
					ally_position - player.global_position
				).normalized()
				return ally_position + away_from_player * 90.0
			return TacticsScript.ranged_target(
				global_position, player.global_position, 290.0, 425.0, strafe_direction
			)
		Wavecontrol.TANK:
			# Protection steers the pursuit path without cancelling player chase.
			if is_instance_valid(protection_target):
				return TacticsScript.tank_defense_target(
					global_position,
					player.global_position,
					protection_target.global_position,
					TANK_SCREENING_DISTANCE,
					TANK_PURSUIT_WEIGHT
				)
			return player.global_position
		Wavecontrol.RAILGUN:
			return TacticsScript.ranged_target(
				global_position, player.global_position, 340.0, 535.0, strafe_direction
			)
		Wavecontrol.MINESHIP:
			return TacticsScript.ranged_target(
				global_position, player.global_position, 275.0, 435.0, strafe_direction
			)
		_:
			return player.global_position

func _process(delta: float) -> void:
	if hpvis_time > 0.0:
		hpvis_time = maxf(0.0, hpvis_time - delta)
	elif hpbar.self_modulate.a > 0.0:
		hpbar.self_modulate.a = maxf(0.0, hpbar.self_modulate.a - delta)

func _show_health_bar() -> void:
	hpbar.self_modulate.a = 1.0
	hpvis_time = 5.0

var support_healing_active: bool = false

func detect_support() -> void:
	if support_healing_active:
		return
	support_healing_active = true
	while alive and _is_supported():
		if health < int(hpbar.max_value):
			health += 1
			_show_health_bar()
			hpbar.value = health
		await get_tree().create_timer(1.0).timeout
	support_healing_active = false

func _is_supported() -> bool:
	for area: Area2D in get_overlapping_areas():
		if is_instance_valid(area) and area.name == "AoeS":
			return true
	return false

var contact_damage_active: bool = false

func detect_player() -> void:
	if contact_damage_active:
		return
	contact_damage_active = true
	while alive and is_instance_valid(player) and overlaps_body(player):
		Signalbus.hit.emit()
		await get_tree().create_timer(1.0).timeout
	contact_damage_active = false

func warning_RG() -> void:
	if $RGShootTimer.time_left <= 3.0:
		if !warning_sign.visible:
			warning_sign.visible = true
			warning_sign.play()
	elif warning_sign.visible:
		warning_sign.hide()
		warning_sign.stop()
		warning_sign.frame = 0

var alive: bool = true
var hit_flash: Tween
var shield_flash: Tween
var mine_attack_active: bool = false
const MINE_SLOW_FACTOR: float = 0.59049

func _on_body_entered(body: Node2D) -> void:
	if body == player:
		detect_player()
	elif body is PlayerProjectileScript:
		intercept_projectile(body as PlayerProjectileScript)

# Both the tank hull and shield area report here. One shared entry point
# prevents callback ordering from changing the result of a projectile hit.
# Player bullets also use this for high-speed swept collision checks.
func intercept_projectile(projectile: PlayerProjectileScript) -> void:
	if !alive or !is_instance_valid(projectile) or projectile.is_queued_for_deletion():
		return
	if type == Wavecontrol.TANK and tank_shield_hp > 0:
		_absorb_shield_hit(projectile)
	elif projectile.register_hit(self):
		_take_damage(projectile.damage)

func _absorb_shield_hit(bullet: PlayerProjectileScript) -> void:
	if !alive or tank_shield_hp <= 0 or !bullet.register_hit(self):
		return
	if bullet.weapon_mode == Modecontrol.MODE2:
		# Only the large laser reduces shield HP.
		tank_shield_hp = maxi(0, tank_shield_hp - bullet.damage)
	else:
		# Default and wave shots are fully consumed rather than retaining
		# pierce and appearing to pass through the shield.
		bullet.queue_free()
	if shield_flash != null and shield_flash.is_valid():
		shield_flash.kill()
	$%Shield.self_modulate = Color(4.0, 4.0, 4.0, 0.3)
	if tank_shield_hp == 0:
		$%ShieldCollision.set_deferred("disabled", true)
		$%Shield.rotation_degrees = 90.0
		$%Shield.play("default")
		$%ShieldRegen.start()
	shield_flash = create_tween()
	shield_flash.tween_property($%Shield, "self_modulate", Color(1.0, 1.0, 1.0, 0.3), 0.1)

func _take_damage(amount: int) -> void:
	if !alive:
		return
	health = maxi(0, health - maxi(0, amount))
	_show_health_bar()
	hpbar.value = health
	if hit_flash != null and hit_flash.is_valid():
		hit_flash.kill()
	skin.self_modulate = Color(4.0, 4.0, 4.0)
	if health == 0:
		alive = false
		Signalbus.kc_point.emit()
		Signalbus.score.emit(score_amount)
		Signalbus.money.emit(reward_amount)
		queue_free()
		return
	hit_flash = create_tween()
	hit_flash.tween_property(skin, "self_modulate", Color.WHITE, 0.1)

func _on_mine_timer_timeout() -> void:
	if mine_attack_active or !alive:
		return
	mine_attack_active = true
	skin.play()
	var initial_speed: float = speed
	var slowdown: Tween = create_tween()
	slowdown.tween_property(self, "speed", initial_speed * MINE_SLOW_FACTOR, 0.05)
	await slowdown.finished
	await get_tree().create_timer(2.0).timeout
	if !alive or !is_inside_tree():
		return
	var mine: RigidBody2D = mine_scene.instantiate() as RigidBody2D
	# Scatter mines toward the player's predicted approach rather than
	# dispensing them in a completely random direction.
	var aimed_position: Vector2 = TacticsScript.predicted_intercept(
		global_position, player.global_position, player.velocity, 180.0
	)
	var to_target: Vector2 = aimed_position - mine_spawn.global_position
	var direction: float = to_target.angle() - PI * 0.5 + randf_range(-0.25, 0.25)
	mine.position = mine_spawn.global_position
	mine.rotation = direction
	mine.linear_velocity = Vector2(0, 25).rotated(direction)
	Signalbus.mine_dispense.emit(mine)
	skin.play_backwards()
	var recovery: Tween = create_tween()
	recovery.tween_property(self, "speed", initial_speed, 0.05)
	await recovery.finished
	mine_attack_active = false

func _on_shoot_timer_timeout():
	var bullet: RigidBody2D = bullet_scene.instantiate() as RigidBody2D
	# Lead the player's current velocity by estimated projectile travel time.
	var travel_seconds: float = railgun_muzzle.global_position.distance_to(
		player.global_position) / absf(RGbullet_speed)
	var lead: Vector2 = player.global_position + player.velocity * minf(travel_seconds, 0.8)
	var direction: float = (
		lead - railgun_muzzle.global_position
	).angle() + PI * 0.5
	bullet.position = railgun_muzzle.global_position
	bullet.rotation = direction
	var velocity_bullet: Vector2 = Vector2(0, RGbullet_speed)
	bullet.linear_velocity = velocity_bullet.rotated(direction)
	Signalbus.shot_RG.emit(bullet)

func _on_tank_shield_body_entered(body: Node2D) -> void:
	if type == Wavecontrol.TANK and body is PlayerProjectileScript:
		intercept_projectile(body as PlayerProjectileScript)

func _on_shield_regen_timeout():
	tank_shield_hp = max_tank_shield_hp
	$%Shield.rotation_degrees = -90.0
	$%Shield.play_backwards("default")
	$%ShieldCollision.set_deferred("disabled", false)

func _on_area_entered(area: Area2D):
	if area.name == "AoeS" and type != Wavecontrol.SUPPORT:
		detect_support()
