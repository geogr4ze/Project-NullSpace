extends RefCounted

# Conservative local radius, including the corners of rotated/offset artwork.
static func rect_radius(transform: Transform2D, rect: Rect2) -> float:
	var radius: float = 0.0
	for corner: Vector2 in [
		rect.position, Vector2(rect.end.x, rect.position.y),
		Vector2(rect.position.x, rect.end.y), rect.end
	]:
		radius = maxf(radius, (transform * corner).length())
	return radius

# Test the padded viewport rather than a tiny visibility notifier at the
# projectile's origin. Canvas coordinates also support viewport stretching.
static func is_outside(node: Node2D, local_radius: float) -> bool:
	var canvas_transform: Transform2D = node.get_global_transform_with_canvas()
	var canvas_scale: float = maxf(canvas_transform.x.length(), canvas_transform.y.length())
	var margin: float = (local_radius + 16.0) * canvas_scale
	return not node.get_viewport_rect().grow(margin).has_point(canvas_transform.origin)
