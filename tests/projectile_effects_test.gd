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
		# Background and projectile both use z=0. A negative effect z-index
		# hides the glow and wake under the full-screen background TextureRect.
		_check(glow.z_index == 0 and trail.z_index == 0,
			"Both effects stay on top of the opaque arena background")
		_check(glow.get_index() < skin.get_index() and
			trail.get_index() < skin.get_index(),
			"Glow and wake draw before the original sprite at the same z-index")
		_check(glow.texture is GradientTexture2D,
			"Projectile glow uses a softly fading radial gradient")
		_check(trail.emitting == (mode == Modecontrol.MODE1),
			"Only moving wave projectiles emit a particle wake")
		_check(!trail.local_coords,
			"Wave particles remain in world space as the wave moves")
		_check(trail.texture is GradientTexture2D,
			"Wave trail has a visible particle texture instead of tiny points")
		_check(trail.lifetime >= 0.30 and trail.lifetime <= 0.42 and
			trail.amount >= 58 and trail.amount <= 66,
			"Wave emits enough pixels to fill the tip-to-tip wake")
		_check(trail.emission_rect_extents.x >= 90.0 and
			trail.emission_rect_extents.y <= 4.0,
			"Wave particle source spans tip to tip without a thick vertical band")
		_check(trail.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Wave trail pixels retain sharp nearest-neighbor edges")
		_check(trail.material == null,
			"Wave streaks use normal blending rather than additive bloom")
		if mode == Modecontrol.DEFAULT:
			_check(float(glow.get("intensity")) <= 0.34,
				"Default bullet glow is reduced")
			_check(glow.material == null,
				"Default bullet glow uses normal instead of additive blending")
		if mode == Modecontrol.MODE1:
			_check(float(glow.get("intensity")) <= 0.09 and
				float(glow.get("intensity")) >= 0.07,
				"Wave halo is barely visible instead of overpowering the pixels")
			_check(glow.material == null,
				"Wave halo uses normal blending instead of additive glow")
			_check(glow.scale.x <= 1.90 and glow.scale.y <= 1.25,
				"Wave halo stays tight around the unchanged artwork")
			_check(trail.position.y > glow.position.y,
				"Wave particles originate behind the wave in local +Y")
			var gradient_texture: GradientTexture2D = trail.texture as GradientTexture2D
			_check(gradient_texture.width == 3 and
				gradient_texture.height == 3,
				"Wave particles are square pixels, not streaks or soft discs")
			_check(trail.color == Color.WHITE,
				"Wave particles preserve the authored dark-blue color ramp")
			var ramp: Gradient = trail.color_ramp
			_check(ramp != null and ramp.colors.size() == 3,
				"Wave trail uses one blue color with three alpha levels")
			if ramp != null and ramp.colors.size() == 3:
				for sample: Color in ramp.colors:
					_check(is_equal_approx(sample.r, 0.0) and
						is_equal_approx(sample.g, 115.0 / 255.0) and
						is_equal_approx(sample.b, 1.0),
						"Wave pixels use exact player darkest blue #0073FF")
				_check(ramp.colors[0].a > ramp.colors[1].a and
					is_zero_approx(ramp.colors[2].a),
					"Wave pixels fade out without a color change")
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
