# Theme-Matched Ship Glow — Current Visual QA

Original animated sprites, colors, outlines, hitboxes and enemy behavior
remain unchanged. The same radial gradient is drawn behind the existing
ship art with its cached dominant color from the original sprite.

- Player halo intensity **0.32** (previously 0.24).
- Enemy halo intensity **0.27** (previously 0.20) for all enemy types.
- Large tank, railgun and mine hulls retain their original broader halo size.
- With center gradient alpha 0.32, effective peak alpha is about 0.102 for
  the player and 0.086 for enemies, fading softly to zero at the edges.
- The laser draws one steady beam from the player instead of separate visible
  projectiles. See `docs/laser_aim_visual_test_plan.md`.

## Checks

```sh
godot --headless --path . --script res://tests/subtle_ship_glow_test.gd
godot --headless --path . --script res://tests/laser_visual_test.gd
```

Check all three player modes and all six enemies. The existing colored
halos should be a little more visible but never wash out ship sprites,
tank shields, health bars or other effects.
