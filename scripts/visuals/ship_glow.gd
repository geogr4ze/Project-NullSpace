extends Sprite2D
# A very faint, cosmetic halo placed behind the unchanged ship sprite.
# Match the existing art's strongest saturated hue, so new weapons and
# different enemy types retain their own established color themes.
const HUE_BUCKETS: int = 12
const SAMPLE_GRID: int = 32

static var cached_hues: Dictionary = {}

@export_range(0.0, 1.0, 0.01) var intensity: float = 0.23

## Update glow to match the supplied animated sprite's current animation, using its first frame as the visual reference. Ignores missing sprite/frame data.
func match_sprite(skin: AnimatedSprite2D) -> void:
	if skin == null or skin.sprite_frames == null:
		return
	if skin.sprite_frames.get_frame_count(skin.animation) < 1:
		return
	var frame_texture: Texture2D = (
		skin.sprite_frames.get_frame_texture(skin.animation, 0)
	)
	if frame_texture == null:
		return
	var texture_id: int = frame_texture.get_instance_id()
	if !cached_hues.has(texture_id):
		cached_hues[texture_id] = _sample_dominant_hue(frame_texture)
	var hue: float = float(cached_hues[texture_id])
	# Soft, tinted white rather than bright new colors over the art.
	# Neutral skin artwork receives a neutral halo instead of new colors.
	if hue < 0.0:
		self_modulate = Color(0.88, 0.92, 0.97, intensity * 0.75)
	else:
		self_modulate = Color.from_hsv(hue, 0.48, 0.96, intensity)
	visible = true


## Sample a texture's image pixels to estimate dominant hue for glow coloring. Returns -1.0 if the image is unavailable or cannot be decompressed.
static func _sample_dominant_hue(source: Texture2D) -> float:
	var image: Image = source.get_image()
	if image == null or image.is_empty():
		return -1.0 # Neutral fallback for non-readable textures.
	# Imported sprite textures may contain compressed image pixels.
	if image.is_compressed() and image.decompress() != OK:
		return -1.0
	var scores: PackedFloat32Array = PackedFloat32Array()
	scores.resize(HUE_BUCKETS)
	var largest_dimension: int = maxi(image.get_width(), image.get_height())
	var step: int = maxi(1, roundi(float(largest_dimension) / SAMPLE_GRID))
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var sample: Color = image.get_pixel(x, y)
			# Ignore transparent borders and neutral parts of the artwork.
			if sample.a < 0.3 or sample.s < 0.18 or sample.v < 0.22:
				continue
			var bucket: int = mini(
				HUE_BUCKETS - 1, int(sample.h * float(HUE_BUCKETS))
			)
			scores[bucket] += sample.a * sample.s * sample.v
	var strongest_bucket: int = 0
	for index: int in range(1, HUE_BUCKETS):
		if scores[index] > scores[strongest_bucket]:
			strongest_bucket = index
	if scores[strongest_bucket] < 0.001:
		return -1.0
	return (float(strongest_bucket) + 0.5) / float(HUE_BUCKETS)
