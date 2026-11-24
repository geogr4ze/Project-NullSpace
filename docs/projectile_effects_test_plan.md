# Default and Wave Projectile Effects

This pass changes projectile visuals and the laser's post-firing aiming only.
No sprite replacement, damage, pierce, cooldown, projectile velocity, enemy AI,
tank shield collision, or weapon energy values have been changed.

## Projectile visuals

- **Default shots:** original soft halo reduced from intensity **0.62 → 0.32**,
  and changed to normal blending to avoid a strong additive bloom.
- **Wave shots:** very faint blue halo reduced from **0.20 → 0.08** at the
  original tight 1.82 × 1.20 scale and normal blending, preserving its sprite.
- **Wave trail:** **62** crisp 3 × 3 pixels emitted across a tip-to-tip
  span of **184 game units** (emission rectangle ±92 horizontally), rather
  than 34 pixels across only 100 units. The color is exactly **#0073FF**
  (RGB 0, 115, 255), the darkest blue sampled from the project's own
  `Player Mode2 Animation-1.png.png` art. The only color change over
  the 0.36-second life is a reduction in alpha, not a shift toward cyan.
  `local_coords = false` keeps already emitted pixels behind the wave.
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

Default and wave glows still inherit their sprite's sampled hue. Wave
particles use one exact blue from the player's existing pixel art, rather
than approximate or mixed blues. The original artwork stays visible
above its halo and particles.

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
2. Fire default bullets. Their original sprites and hitboxes must be
   visible, with a much dimmer non-additive glow.
3. Fire wave bullets. The halo should be barely visible, and the pixel
   wake should span from the wave's left tip to its right tip, not emit
   from one narrow edge. The wake should use the exact player blue #0073FF.
4. Fire the laser and confirm the clean solid beam is slightly more
   blue and less cyan, without changing the way it fires or aims.
5. Ensure no wave particles appear for default or laser shots.
6. Check performance with numerous simultaneous shots, and confirm enemy
   collision, score, shield behavior and charge/heat remain unchanged.

Godot runtime checks must be executed in a Godot environment.
