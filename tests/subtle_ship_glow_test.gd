extends SceneTree
# Run with: godot --headless --path . --script res://tests/subtle_ship_glow_test.gd
const GlowScript = preload("res://scripts/visuals/ship_glow.gd")
var failures: int = 0

func _initialize() -> void:
	var halo: GlowScript = GlowScript.new()
	var skin: AnimatedSprite2D = AnimatedSprite2D.new()
	var frames: SpriteFrames = SpriteFrames.new()

	# Synthetic saturated colors make it possible to verify the glow follows
	# the sprite artwork rather than hard-coding one color for every ship.
	for theme: Dictionary in [
		{"name": "warm", "color": Color(1.0, 0.1, 0.05)},
		{"name": "green", "color": Color(0.05, 1.0, 0.1)},
		{"name": "blue", "color": Color(0.05, 0.1, 1.0)}
	]:
		var texture_image: Image = Image.create(
			16, 16, false, Image.FORMAT_RGBA8
		)
		texture_image.fill(theme["color"])
		var texture: ImageTexture = ImageTexture.create_from_image(texture_image)
		var name: StringName = StringName(theme["name"])
		frames.add_animation(name)
		frames.add_frame(name, texture)
	skin.sprite_frames = frames
	skin.animation = &"warm"
	halo.match_sprite(skin)
	var warm: Color = halo.self_modulate
	_check(halo.visible, "Halo is enabled once a valid skin is configured")
	_check(warm.r > warm.g and warm.r > warm.b,
		"Warm-colored sprite produces a subtle warm glow")

	skin.animation = &"green"
	halo.match_sprite(skin)
	var green: Color = halo.self_modulate
	_check(green.g > green.r and green.g > green.b,
		"Green sprite produces a matching green glow")

	skin.animation = &"blue"
	halo.match_sprite(skin)
	var blue: Color = halo.self_modulate
	_check(blue.b > blue.r and blue.b > blue.g,
		"Blue sprite produces a matching cool-blue glow")
	_check(is_equal_approx(blue.a, halo.intensity),
		"Glow opacity never exceeds its configured subtle intensity")

	# Existing scenes retain all ship sprites, only adding a cosmetic halo.
	for path: String in [
		"res://scenes/player.tscn", "res://scenes/enemy.tscn"
	]:
		var packed: PackedScene = load(path) as PackedScene
		_check(packed != null, "Original ship scene still loads: " + path)
		if packed == null:
			continue
		var ship: Node2D = packed.instantiate() as Node2D
		var new_halo: Sprite2D = ship.get_node_or_null("GlowHalo") as Sprite2D
		_check(new_halo != null, "Scene has a separate glow node: " + path)
		if new_halo != null:
			_check(new_halo.z_index < 0,
				"Glow stays behind original artwork: " + path)
			_check(new_halo.texture is GradientTexture2D,
				"Glow uses a soft procedural gradient: " + path)
			_check(float(new_halo.get("intensity")) <= 0.24,
				"Ships do not gain an excessively bright halo: " + path)
		var skin_name: String = "PlayerSkin" if path.contains("/player.") else "Skin"
		_check(ship.has_node(skin_name),
			"Original animated skin still exists: " + path)
		ship.free()

	halo.free()
	skin.free()
	if failures > 0:
		push_error(str(failures) + " ship glow checks failed")
	quit(1 if failures > 0 else 0)

func _check(ok: bool, description: String) -> void:
	if !ok:
		failures += 1
		printerr("FAIL: " + description)
