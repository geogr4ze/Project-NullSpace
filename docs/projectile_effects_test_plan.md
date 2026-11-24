# Default and Wave Projectile Effects

This pass changes projectile visuals and the laser's post-firing aiming only.
No sprite replacement, damage, pierce, cooldown, projectile velocity, enemy AI,
tank shield collision, or weapon energy values have been changed.

## Projectile visuals

- **Default shots:** small soft halo behind the existing sprite.
- **Wave shots:** very faint, tight halo (intensity **0.20**, scale
  **1.82 × 1.20**, normal instead of additive blending) behind the original
  artwork, further reduced from intensity 0.48.
- **Wave trail:** 34 small, crisp **3 × 3** dark-blue pixel squares,
  rather than long glowing energy streaks. Their authored navy/blue palette
  visually matches the blue pixels in the game's starfield and existing wave
  projectile, and fades over **0.36 seconds** without cyan/white flashes.
  The emitter stays behind the wave with `local_coords = false`, leaving
  a short, understated wake in world space; emission starts on spawn.
- **Laser:** the same three seamless Line2D layers, with outer and inner
  band colors shifted slightly toward the existing blue palette. The core
  remains an opaque pale blue so the laser stays strong and readable.
- **Critical visibility fix:** `ProjectileGlow` and `WaveTrail` now use
  `z_index = 0`, just like the game's full-screen `TextureRect` backdrop.
  They were previously set to `-1`, which could render them underneath that
  opaque background. Both nodes precede the original `Skin` in the
  projectile scene, keeping the sprite on top within the correct layer.
- **Laser:** moving hit projectiles still have no visible sprites or
  particles; the single uninterrupted beam remains attached to the player.

Default and wave glow still inherit the existing sprite's sampled hue.
The wave particles instead use a fixed, muted dark-blue pixel palette chosen
to match the wave and starfield art, without hue-to-cyan recoloring. The
original artwork stays visible above its halo and particles.

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
3. Fire wave bullets. The halo should be barely visible and not obscure
   the original sprite; small dark-blue square pixels should briefly drift
   behind the wave, not resemble glowing streaks or particle orbs.
4. Fire the laser and confirm the clean solid beam is slightly more
   blue and less cyan, without changing the way it fires or aims.
5. Ensure no wave particles appear for default or laser shots.
6. Check performance with numerous simultaneous shots, and confirm enemy
   collision, score, shield behavior and charge/heat remain unchanged.

Godot runtime checks must be executed in a Godot environment.
