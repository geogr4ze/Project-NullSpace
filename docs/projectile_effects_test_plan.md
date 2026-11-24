# Default and Wave Projectile Effects

This pass changes projectile visuals and the laser's post-firing aiming only.
No sprite replacement, damage, pierce, cooldown, projectile velocity, enemy AI,
tank shield collision, or weapon energy values have been changed.

## Projectile visuals

- **Default shots:** small soft halo behind the existing sprite.
- **Wave shots:** stronger, wider halo (intensity 0.94; scale
  2.40 × 1.55), behind the unchanged original artwork.
- **Wave trail:** 78 glowing particles with a real 24 × 24 radial-gradient
  texture, fading over 0.60 seconds. The emitter sits behind the wave and
  uses `local_coords = false`, so already emitted particles remain in
  world space while the projectile moves forward. Emission is explicitly
  restarted on wave spawn.
- **Critical visibility fix:** `ProjectileGlow` and `WaveTrail` now use
  `z_index = 0`, just like the game's full-screen `TextureRect` backdrop.
  They were previously set to `-1`, which could render them underneath that
  opaque background. Both nodes precede the original `Skin` in the
  projectile scene, keeping the sprite on top within the correct layer.
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
3. Fire wave bullets. The brightened halo should be clearly visible
   against the arena backdrop, and the broad colored particle wake should
   visibly remain behind the moving projectile.
4. Ensure no wave particles appear for default or laser shots.
5. Check performance with numerous simultaneous shots, and confirm enemy
   collision, score, shield behavior and charge/heat remain unchanged.

Godot runtime checks must be executed in a Godot environment.
