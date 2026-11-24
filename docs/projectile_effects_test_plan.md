# Default and Wave Projectile Effects

This pass changes projectile visuals and the laser's post-firing aiming only.
No sprite replacement, damage, pierce, cooldown, projectile velocity, enemy AI,
tank shield collision, or weapon energy values have been changed.

## Projectile visuals

- **Default shots:** small soft halo behind the existing sprite.
- **Wave shots:** wider softly faded halo behind the existing artwork.
- **Wave trail:** 26 lightweight particles appear along the back of the
  projectile and gradually fade over 0.48 seconds. The emitter is a child
  of the moving projectile but uses `local_coords = false`, so emitted
  particles stay behind in world space as the wave travels forward.
- **Laser:** moving hit projectiles still have no visible sprites or
  particles; the single uninterrupted beam remains attached to the player.

Both default and wave glow/particle colors are derived from the projectile's
own sprite using the existing cached hue matcher. The original art stays
visible on top of its halo.

## Laser release

Holding Fire still limits aiming to the familiar heavy laser rate of 18°/s
at full charge. Releasing Space ramps turn speed up smoothly to 540°/s over
0.42 seconds and continues turning at that capped rate until the ship is
within one degree of the cursor. Default/wave remain instantly mouse-aimed.

## Automated checks

```sh
godot --headless --path . --script res://tests/player_controls_test.gd
godot --headless --path . --script res://tests/projectile_effects_test.gd
godot --headless --path . --script res://tests/laser_visual_test.gd
godot --headless --path . --script res://tests/subtle_ship_glow_test.gd
```

## In-game checks

1. Hold the laser while the cursor is behind the ship. Release Space and
   confirm it rotates back continuously rather than snapping.
2. Fire default bullets. Their original sprites and hitboxes must be visible,
   with a subtle surrounding glow.
3. Fire wave bullets. A colored glow surrounds the projectile while a short
   particle wake remains behind as it moves.
4. Ensure no wave particles appear for default or laser shots.
5. Check performance with numerous simultaneous shots, and confirm enemy
   collision, score, shield behavior and charge/heat remain unchanged.

Godot runtime checks must be executed in a Godot environment.
