extends SceneTree
# Run: godot --headless --path . --script res://tests/laser_visual_test.gd
var failures: int = 0

func _initialize() -> void:
	var player_scene: PackedScene = load("res://scenes/player.tscn") as PackedScene
	_check(player_scene != null, "Player scene loads")
	if player_scene != null:
		var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
		var beam: Node2D = player.get_node_or_null("LaserBeam") as Node2D
		_check(beam != null, "Player owns the continuous laser effect")
		if beam != null:
			_check(!beam.visible, "Laser starts hidden")
			var muzzle: Marker2D = player.get_node("Muzzle") as Marker2D
			_check(beam.position.is_equal_approx(muzzle.position),
				"Continuous beam starts at the original muzzle")
			for part_name: String in ["OuterGlow", "BlueBand", "Core"]:
				var part: Line2D = beam.get_node_or_null(part_name) as Line2D
				_check(part != null, "Beam contains " + part_name)
				if part != null:
					_check(part.points.size() == 2 and
						part.points[0].is_equal_approx(Vector2.ZERO) and
						part.points[1].is_equal_approx(Vector2(0, -2200)),
						"Single straight line for " + part_name)
			var outer: Line2D = beam.get_node("OuterGlow") as Line2D
			var core: Line2D = beam.get_node("Core") as Line2D
			_check(outer.width > core.width, "Glow envelops the solid core")
		player.free()

	var bullet_scene: PackedScene = load("res://scenes/bullet.tscn") as PackedScene
	_check(bullet_scene != null, "Projectile scene loads")
	if bullet_scene == null:
		quit(1)
		return
	for mode: int in [Modecontrol.DEFAULT, Modecontrol.MODE1, Modecontrol.MODE2]:
		var projectile: RigidBody2D = bullet_scene.instantiate() as RigidBody2D
		_check(projectile != null, "Projectile spawns")
		if projectile == null:
			continue
		projectile.call("configure_mode", mode)
		root.add_child(projectile)
		var laser: bool = mode == Modecontrol.MODE2
		var sprite: AnimatedSprite2D = projectile.get_node("Skin") as AnimatedSprite2D
		var collision: CollisionShape2D = (
			projectile.get_node("CollisionShape2D") as CollisionShape2D
		)
		_check(sprite.visible == !laser,
			"Default and wave shots remain visible, laser shots are hidden")
		_check(projectile.get_node_or_null("LaserOuterGlow") == null and
			projectile.get_node_or_null("LaserBlueSparks") == null,
			"Individual laser projectiles do not have beam overlays")
		var authored: CollisionShape2D
		if mode == Modecontrol.DEFAULT:
			authored = projectile.get_node("BulletCollision") as CollisionShape2D
		elif mode == Modecontrol.MODE1:
			authored = projectile.get_node("WaveCollision") as CollisionShape2D
		else:
			authored = projectile.get_node("LaserCollision") as CollisionShape2D
		_check(collision.shape == authored.shape,
			"Original projectile collision shape is unchanged")
		_check(collision.transform.is_equal_approx(authored.transform),
			"Original collision transform is unchanged")
		projectile.free()
	if failures > 0:
		push_error(str(failures) + " laser visual tests failed")
	quit(1 if failures > 0 else 0)

func _check(ok: bool, description: String) -> void:
	if !ok:
		failures += 1
		printerr("FAIL: " + description)
