extends RigidBody2D

const PlayerShipScript = preload("res://scripts/player.gd")
const ProjectileBounds = preload("res://scripts/combat/projectile_bounds.gd")

var hit: bool = true

# Keep the entire railgun sprite on screen until it has actually cleared it.
var cleanup_radius: float = 32.0

## Derive a conservative cleanup radius from the projectile sprite.
func _ready() -> void:
	var sprite: Sprite2D = $Sprite2D
	cleanup_radius = maxf(cleanup_radius, ProjectileBounds.rect_radius(sprite.transform, sprite.get_rect()))

## Return whether this projectile is beyond the viewport cleanup margin.
func is_outside_playfield() -> bool:
	return ProjectileBounds.is_outside(self, cleanup_radius)

## Queue the projectile for deletion once outside the playfield.
func _physics_process(_delta: float) -> void:
	if is_outside_playfield():
		queue_free()

# Player detection
## Emit a single enemy bullet hit when contacting the player, then queue deletion.
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is PlayerShipScript and hit:
		hit = false
		Signalbus.enemy_bullet_hit.emit()
		queue_free()
