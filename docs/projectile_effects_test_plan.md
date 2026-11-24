# Default and Wave Projectile Effects

This pass changes projectile visuals and the laser's post-firing aiming only.
No sprite replacement, damage, pierce, cooldown, projectile velocity, enemy AI,
tank shield collision, or weapon energy values have been changed.

## Projectile visuals

- **Default shots:** small soft halo behind the existing sprite.
- **Wave shots:** toned-down, tighter halo (intensity **0.48**, scale
  **1.95 × 1.30**), behind the unchanged original artwork. Previous settings
  were 0.94 and 2.40 × 1.55, which made the effect overwhelm the wave.
- **Wave trail:** **34** thin **3 × 12** energy streaks rather than 78 large
  24 × 24 glowing orbs. They use normal (not additive) blending, a color
  matching the sprite's sampled hue, and a short **0.36-second** fade.
  The emitter stays behind the wave with `local_coords = false`, leaving
  a brief, understated wake in world space. Emission still starts on spawn.
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
3. Fire wave bullets. The halo should be visible without overpowering
   the sprite; narrow tinted streaks should briefly trail behind the wave,
   not resemble round magical sparkles or floating smoke.
4. Ensure no wave particles appear for default or laser shots.
5. Check performance with numerous simultaneous shots, and confirm enemy
   collision, score, shield behavior and charge/heat remain unchanged.

Godot runtime checks must be executed in a Godot environment.
