extends Node
# Run: godot --headless --path . res://tests/test_runner.tscn -- res://tests/projectile_effects_test.gd
const WavePixelTrail = preload("res://scripts/visuals/wave_pixel_trail.gd")
var failures: int = 0

## Defer projectile tests until scene-tree initialization.
func _ready() -> void:
	call_deferred("_run")

## Instantiate projectile scenes for each weapon mode and verify effects and cleanup behavior; fail early if the scene cannot load.
func _run() -> void:
	var scene: PackedScene = load("res://scenes/bullet.tscn") as PackedScene
	_check(scene != null, "Projectile scene loads")
	if scene == null:
		get_tree().quit(1)
		return

	for mode: int in [Modecontrol.DEFAULT, Modecontrol.MODE1, Modecontrol.MODE2]:
		var bullet: RigidBody2D = scene.instantiate() as RigidBody2D
		_check(bullet != null, "Projectile can instantiate")
		if bullet == null:
			continue
		bullet.call("configure_mode", mode)
		get_tree().root.add_child(bullet)

		_check_offscreen_cleanup(bullet)
		_check(int(bullet.get("damage")) == int(Modecontrol.modes[mode]["damage"]),
			"Projectile snapshots configured damage")
		var glow: Sprite2D = bullet.get_node("ProjectileGlow") as Sprite2D
		var trail: WavePixelTrail = bullet.get_node("WaveTrail") as WavePixelTrail
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
		_check(trail.lifetime >= 0.42 and trail.lifetime <= 0.50 and
			trail.amount >= 72 and trail.amount <= 84,
			"Wave emits enough pixels to form a dispersed fading wake")
		_check(trail.emission_rect_extents.x >= 90.0 and
			trail.emission_rect_extents.y >= 24.0,
			"Wave source spans its full width and a substantial depth")
		_check(trail.emission_rect_extents.y < trail.emission_rect_extents.x,
			"Wave wake is spread across the crest rather than a column")
		_check(trail.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"Wave trail pixels retain sharp edges")
		_check(trail.material == null,
			"Wave pixels use normal blending rather than additive bloom")
		_check(not trail.pixels.is_empty() if mode == Modecontrol.MODE1 else trail.pixels.is_empty(),
			"Only wave mode creates visible particles")
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
			_check_pixel_motion_and_fade(trail)
		_check(hitbox.shape == authored.shape and
			hitbox.transform.is_equal_approx(authored.transform),
			"Every mode keeps its original collision geometry")
		bullet.free()

	var enemy_scene: PackedScene = load("res://scenes/enemy_bullet.tscn") as PackedScene
	var enemy_bullet: RigidBody2D = enemy_scene.instantiate() as RigidBody2D
	get_tree().root.add_child(enemy_bullet)
	_check_offscreen_cleanup(enemy_bullet)
	enemy_bullet.free()

	if failures > 0:
		push_error(str(failures) + " projectile effects tests failed")
	get_tree().quit(1 if failures > 0 else 0)

## Record and print a failed projectile assertion.
func _check(ok: bool, description: String) -> void:
	if !ok:
		failures += 1
		printerr("FAIL: " + description)

## Exercise the trail's actual color and motion logic over particle ages; record failures for missing pixels or incorrect opacity/movement.
func _check_pixel_motion_and_fade(trail: WavePixelTrail) -> void:
	if trail.pixels.is_empty():
		_check(false, "Wave creates fresh pixels immediately")
		return
	# Exercise the actual rendering color function over an entire lifetime.
	var previous_alpha: float = trail.pixel_color(0.0).a
	_check(is_equal_approx(previous_alpha, 0.94), "New pixels start at 94 percent opacity")
	_check(is_equal_approx(trail.pixel_color(trail.lifetime * 0.5).a, 0.47),
		"Half-life pixels have half their initial opacity")
	_check(is_equal_approx(trail.pixel_color(-1.0).a, 0.94), "Negative age clamps to birth")
	_check(is_zero_approx(trail.pixel_color(trail.lifetime * 2.0).a), "Expired age clamps to zero")
	for step: int in range(1, 21):
		var age: float = trail.lifetime * float(step) / 20.0
		var sample: Color = trail.pixel_color(age)
		var alpha: float = sample.a
		_check(alpha < previous_alpha, "Rendered alpha strictly decreases with age")
		_check(is_equal_approx(alpha, 0.94 * (1.0 - float(step) / 20.0)),
			"Opacity follows the intended age curve")
		_check(is_equal_approx(sample.r, 0.0) and
			is_equal_approx(sample.g, 115.0 / 255.0) and
			is_equal_approx(sample.b, 1.0),
			"Rendered pixels retain exact #0073FF at every age")
		previous_alpha = alpha
	_check(is_zero_approx(previous_alpha), "Old pixels fade completely")
	var pixel = trail.pixels[0]
	var initial_position: Vector2 = pixel.world_position
	var initial_velocity: Vector2 = pixel.velocity
	var initial_alpha: float = trail.pixel_color(pixel.age).a
	_check(pixel.size >= 2.85 and pixel.size <= 4.35, "Pixels remain small squares")
	# Move the emitter much farther than the pixel drift. Previously emitted
	# pixels must stay at their own world positions and get less opaque.
	trail.global_position += Vector2(0, -150)
	trail.advance(0.1)
	_check(pixel.world_position.is_equal_approx(initial_position + initial_velocity * 0.1),
		"Existing pixels remain in world space when the wave moves")
	_check(trail.pixel_color(pixel.age).a < initial_alpha, "Older pixel fades as wave moves away")
	var found_fresh: bool = false
	for candidate in trail.pixels:
		if candidate.age < 0.01 and trail.pixel_color(candidate.age).a > 0.9:
			found_fresh = true
	_check(found_fresh, "New pixels near the current wave are still opaque")
	trail.emitting = false
	trail.advance(trail.lifetime)
	_check(trail.pixels.is_empty(), "Expired pixels are removed")

## Exercise projectile cleanup near and beyond viewport edges using the projectile's actual radius and restore its test position.
func _check_offscreen_cleanup(bullet: RigidBody2D) -> void:
	var original: Vector2 = bullet.global_position
	var viewport: Rect2 = bullet.get_viewport_rect()
	var center: Vector2 = viewport.get_center()
	var radius: float = float(bullet.get("cleanup_radius"))
	var edges: Array[Vector2] = [
		Vector2(viewport.position.x - 1.0, center.y),
		Vector2(viewport.end.x + 1.0, center.y),
		Vector2(center.x, viewport.position.y - 1.0),
		Vector2(center.x, viewport.end.y + 1.0)
	]
	var directions: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	for i: int in edges.size():
		bullet.global_position = edges[i]
		_check(not bool(bullet.call("is_outside_playfield")),
			"Projectile survives just outside every viewport edge")
		bullet.global_position = edges[i] + directions[i] * (radius + 40.0)
		_check(bool(bullet.call("is_outside_playfield")),
			"Projectile is eligible for cleanup beyond its full visual extent")
	bullet.global_position = original
