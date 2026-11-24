extends SceneTree
# Run: godot --headless --path . --script res://tests/projectile_effects_test.gd
var failures: int = 0

func _initialize() -> void:
	var scene: PackedScene = load("res://scenes/bullet.tscn") as PackedScene
	_check(scene != null, "Projectile scene loads")
	if scene == null:
		quit(1)
		return

	for mode: int in [Modecontrol.DEFAULT, Modecontrol.MODE1, Modecontrol.MODE2]:
		var bullet: RigidBody2D = scene.instantiate() as RigidBody2D
		_check(bullet != null, "Projectile can instantiate")
		if bullet == null:
			continue
		bullet.call("configure_mode", mode)
		root.add_child(bullet)

		var glow: Sprite2D = bullet.get_node("ProjectileGlow") as Sprite2D
		var trail: CPUParticles2D = bullet.get_node("WaveTrail") as CPUParticles2D
		var skin: AnimatedSprite2D = bullet.get_node("Skin") as AnimatedSprite2D
		var hitbox: CollisionShape2D = bullet.get_node("CollisionShape2D") as CollisionShape2D
		var authored: CollisionShape2D
		if mode == Modecontrol.DEFAULT:
			authored = bullet.get_node("BulletCollision") as CollisionShape2D
		elif mode == Modecontrol.MODE1:
			authored = bullet.get_node("WaveCollision") as CollisionShape2D
		else:
			authored = bullet.get_node("LaserCollision") as CollisionShape2D

		_check(glow.visible == (mode != Modecontrol.MODE2),
			"Default and wave glow while invisible laser shots do not")
		_check(glow.z_index < skin.z_index,
			"Projectile glow stays behind its original sprite")
		_check(glow.texture is GradientTexture2D,
			"Projectile glow uses a softly fading radial gradient")
		_check(trail.emitting == (mode == Modecontrol.MODE1),
			"Only moving wave projectiles emit a particle wake")
		_check(!trail.local_coords,
			"Wave particles remain in world space as the wave moves")
		_check(trail.lifetime > 0.0 and trail.amount > 0,
			"Wave trail uses nonzero fading particles")
		_check(hitbox.shape == authored.shape and
			hitbox.transform.is_equal_approx(authored.transform),
			"Every mode keeps its original collision geometry")
		bullet.free()

	if failures > 0:
		push_error(str(failures) + " projectile effects tests failed")
	quit(1 if failures > 0 else 0)

func _check(ok: bool, description: String) -> void:
	if !ok:
		failures += 1
		printerr("FAIL: " + description)
