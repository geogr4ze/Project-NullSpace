extends Node
# Run with: godot --headless --path . res://tests/test_runner.tscn -- res://tests/subtle_ship_glow_test.gd
const GlowScript = preload("res://scripts/visuals/ship_glow.gd")
var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
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
			var expected_intensity: float = (
				0.32 if path.contains("/player.") else 0.27
			)
			_check(is_equal_approx(float(new_halo.get("intensity")),
				expected_intensity),
				"Modest theme-matched halo boost: " + path)
		var skin_name: String = "PlayerSkin" if path.contains("/player.") else "Skin"
		_check(ship.has_node(skin_name),
			"Original animated skin still exists: " + path)
		ship.free()

	var mine_scene: PackedScene = load("res://scenes/enemy_mine.tscn") as PackedScene
	_check(mine_scene != null, "Mine scene loads")
	if mine_scene != null:
		var mine: RigidBody2D = mine_scene.instantiate() as RigidBody2D
		get_tree().root.add_child(mine)
		var mine_halo: Sprite2D = mine.get_node("GlowHalo") as Sprite2D
		var mine_skin: AnimatedSprite2D = mine.get_node("Skin") as AnimatedSprite2D
		_check(mine_halo.visible and mine_halo.get_index() < mine_skin.get_index(),
			"Armed mines have a visible theme-matched halo behind the artwork")
		_check(mine_halo.z_index == 0 and is_equal_approx(float(mine_halo.get("intensity")), 0.27),
			"Mine glow is subtle and remains above the opaque arena background")
		mine.call("explosion")
		_check(not mine_halo.visible, "Mine glow disappears when it explodes")
		mine.free()

	halo.free()
	skin.free()
	if failures > 0:
		push_error(str(failures) + " ship glow checks failed")
	get_tree().quit(1 if failures > 0 else 0)

func _check(ok: bool, description: String) -> void:
	if !ok:
		failures += 1
		printerr("FAIL: " + description)
