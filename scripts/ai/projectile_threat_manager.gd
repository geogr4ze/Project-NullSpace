extends Node

# One central physics pass predicts collisions from real player projectiles.
# Enemies don't dodge the player's facing direction or Fire input alone.
const ProjectileScript = preload("res://scripts/bullet.gd")
const TacticsScript = preload("res://scripts/ai/enemy_tactics.gd")
const TIME_TO_IMPACT_LIMIT: float = 0.70
const COLLISION_SAFETY_MARGIN: float = 14.0

## Scan active enemy and projectile groups each physics tick and update enemy dodge requests. Skips invalid or dead enemies.
func _physics_process(_delta: float) -> void:
	var shots: Array[Node] = get_tree().get_nodes_in_group("player_projectiles")
	for node: Node in get_tree().get_nodes_in_group("enemy_ai"):
		var enemy: EnemyShip = node as EnemyShip
		if enemy == null or !is_instance_valid(enemy):
			continue
		if enemy.is_queued_for_deletion() or !enemy.alive:
			continue
		var best_dodge: Vector2 = Vector2.ZERO
		if !shots.is_empty():
			best_dodge = _find_incoming_threat(enemy, shots)
		enemy.incoming_dodge = best_dodge


## Evaluate the supplied projectile nodes against the enemy hitbox, velocity and weapon-evasion rules. Returns a dodge direction or zero.
func _find_incoming_threat(enemy: EnemyShip, shots: Array[Node]) -> Vector2:
	var enemy_hitbox: CollisionShape2D = (
		enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
	)
	if enemy_hitbox == null:
		return Vector2.ZERO
	var enemy_type: int = enemy.type
	var enemy_velocity: Vector2 = enemy.motion_velocity
	var preferred_side: float = enemy.strafe_direction
	var enemy_id: int = enemy.get_instance_id()
	var strongest: Vector2 = Vector2.ZERO

	for shot_node: Node in shots:
		var projectile: ProjectileScript = shot_node as ProjectileScript
		if projectile == null or !is_instance_valid(projectile):
			continue
		if projectile.is_queued_for_deletion() or projectile.hit_targets.has(enemy_id):
			continue
		# Tanks only dodge laser projectiles. Other modes are harmless to
		# their active shield, matching the existing tank combat design.
		if !TacticsScript.can_evade_weapon(enemy_type, projectile.weapon_mode):
			continue

		var projectile_velocity: Vector2 = projectile.linear_velocity
		var relative_velocity: Vector2 = projectile_velocity - enemy_velocity
		var speed_squared: float = relative_velocity.length_squared()
		if speed_squared < 1.0:
			continue
		var shot_hitbox: CollisionShape2D = (
			projectile.get_node_or_null("CollisionShape2D") as CollisionShape2D
		)
		if shot_hitbox == null or shot_hitbox.shape == null:
			continue
		var trajectory_normal: Vector2 = (
			Vector2(-relative_velocity.y, relative_velocity.x) / sqrt(speed_squared)
		)
		var target_hitbox: CollisionShape2D = enemy_hitbox
		if enemy_type == Wavecontrol.TANK and enemy.tank_shield_hp > 0:
			var shield_hitbox: CollisionShape2D = (
				enemy.get_node_or_null("TankShield/ShieldCollision") as CollisionShape2D
			)
			if shield_hitbox != null:
				target_hitbox = shield_hitbox
		var safe_distance: float = (
			TacticsScript.collision_half_width(shot_hitbox, trajectory_normal)
			+ TacticsScript.collision_half_width(target_hitbox, trajectory_normal)
			+ COLLISION_SAFETY_MARGIN
		)
		var evasion: Vector2 = TacticsScript.projectile_evasion(
			shot_hitbox.global_position, projectile_velocity,
			target_hitbox.global_position, enemy_velocity,
			safe_distance, TIME_TO_IMPACT_LIMIT, preferred_side
		)
		if evasion.length_squared() > strongest.length_squared():
			strongest = evasion
	return strongest
