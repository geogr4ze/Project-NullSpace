extends Node2D
# Draw each pixel in world space with an explicit age-based opacity.
# This avoids renderer-dependent particle color interpolation and preserves
# the original blue, square pixels and random full-width emission.
class Pixel:
	var world_position: Vector2
	var velocity: Vector2
	var age: float = 0.0
	var size: float

@export var amount: int = 78
@export var lifetime: float = 0.46
@export var emission_rect_extents: Vector2 = Vector2(92.0, 26.0)
@export var color_ramp: Gradient

var emitting: bool = false
var pixels: Array[Pixel] = []
var _previous_origin: Vector2
var _emission_clock: float = 0.0

func _ready() -> void:
	set_process(false)

func start_emitting() -> void:
	pixels.clear()
	_emission_clock = 0.0
	_previous_origin = global_position
	emitting = true
	# A few fully visible pixels immediately, rather than an empty wake.
	for i: int in 4:
		_spawn_pixel(_previous_origin, 0.0)
	set_process(true)
	queue_redraw()

func pixel_color(age: float) -> Color:
	# Gradient starts at 94% alpha and ends at zero. Age never goes backward.
	return color_ramp.sample(clampf(age / lifetime, 0.0, 1.0))

func _process(delta: float) -> void:
	advance(delta)
	queue_redraw()

func advance(delta: float) -> void:
	if delta <= 0.0:
		return
	for i: int in range(pixels.size() - 1, -1, -1):
		var pixel: Pixel = pixels[i]
		pixel.age += delta
		pixel.world_position += pixel.velocity * delta
		if pixel.age >= lifetime:
			pixels.remove_at(i)
	var origin: Vector2 = global_position
	if emitting:
		var interval: float = lifetime / float(amount)
		_emission_clock += delta
		while _emission_clock >= interval:
			_emission_clock -= interval
			var age: float = _emission_clock
			if age < lifetime:
				var fraction: float = clampf(1.0 - age / delta, 0.0, 1.0)
				_spawn_pixel(_previous_origin.lerp(origin, fraction), age)
	_previous_origin = origin

func _spawn_pixel(origin: Vector2, age: float) -> void:
	var pixel: Pixel = Pixel.new()
	var offset: Vector2 = Vector2(
		randf_range(-emission_rect_extents.x, emission_rect_extents.x),
		randf_range(-emission_rect_extents.y, emission_rect_extents.y)
	).rotated(global_rotation)
	pixel.velocity = Vector2.DOWN.rotated(
		global_rotation + deg_to_rad(randf_range(-25.0, 25.0))
	) * randf_range(8.0, 26.0)
	pixel.world_position = origin + offset + pixel.velocity * age
	pixel.age = age
	pixel.size = 3.0 * randf_range(0.95, 1.45)
	pixels.append(pixel)

func _draw() -> void:
	for pixel: Pixel in pixels:
		var center: Vector2 = to_local(pixel.world_position)
		var size: Vector2 = Vector2.ONE * pixel.size
		draw_rect(Rect2(center - size * 0.5, size), pixel_color(pixel.age))
