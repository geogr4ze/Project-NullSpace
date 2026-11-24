extends SceneTree
# Run with:
# godot --headless --path . --script res://tests/laser_visual_test.gd
var failures: int = 0

func _initialize() -> void:
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
		var glow: Line2D = projectile.get_node("LaserOuterGlow") as Line2D
		var band: Line2D = projectile.get_node("LaserBlueBand") as Line2D
		var core: Line2D = projectile.get_node("LaserWhiteCore") as Line2D
		var sparks: CPUParticles2D = projectile.get_node("LaserBlueSparks") as CPUParticles2D
		var main_collision: CollisionShape2D = (
			projectile.get_node("CollisionShape2D") as CollisionShape2D
		)
		_check(sprite.visible == !laser,
			"Default and wave sprite stays visible; laser sprite is hidden")
		_check(glow.visible == laser and band.visible == laser
			and core.visible == laser, "Only large laser shows its rigid layers")
		_check(sparks.emitting == laser,
			"Blue sparks emit only on the laser projectile")
		_check(core.points.size() == 2
			and core.points[0].is_equal_approx(Vector2.ZERO)
			and core.points[1].is_equal_approx(Vector2(0, -290)),
			"Laser core is a straight 290-pixel line")
		var original_hitbox: CollisionShape2D
		if mode == Modecontrol.DEFAULT:
			original_hitbox = projectile.get_node("BulletCollision") as CollisionShape2D
		elif mode == Modecontrol.MODE1:
			original_hitbox = projectile.get_node("WaveCollision") as CollisionShape2D
		else:
			original_hitbox = projectile.get_node("LaserCollision") as CollisionShape2D
		_check(main_collision.shape == original_hitbox.shape,
			"Visual change preserves the original projectile shape")
		_check(main_collision.transform.is_equal_approx(original_hitbox.transform),
			"Visual change preserves the original collision transform")
		projectile.free()
	if failures > 0:
		push_error(str(failures) + " projectile visual tests failed")
	quit(1 if failures > 0 else 0)

func _check(ok: bool, description: String) -> void:
	if !ok:
		failures += 1
		printerr("FAIL: " + description)
