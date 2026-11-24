# Subtle Glow Adjustments — Visual QA

This is a **cosmetic-only change**. It does not modify character sprites,
animation frames, ship outlines, hitboxes, enemy behaviors, projectile damage,
weapon controls, shield rules or the laser's fixed beam geometry.

## Laser — lower intensity, same rigid beam

- Outer blue glow: alpha **0.19 → 0.12**, width **44 → 40 px**.
- Cyan-blue middle band: alpha **0.68 → 0.52**, width **25 → 24 px**.
- Blue sparks: **12 → 9** particles, ramp peak alpha **0.9 → 0.7**.
- White-blue rigid core and projectile collision shape are unchanged.

## Player and enemies — understated, art-matched halo

A small, softly faded radial `GradientTexture2D` is drawn **behind** each
existing ship skin. No new sprite designs or outlines are introduced.

- Player halo intensity: **0.24**; envelope about 141 × 118 px.
- Enemy halo intensity: **0.20**; envelope about 134 × 113 px.
- Larger tank, railgun and mine ship hulls use a wider faint glow envelope,
  about 211 × 134 px, with exactly the same low intensity.
- At the center, gradient alpha 0.32 multiplies halo intensity; therefore
  actual peak transparency-weighted alpha is at most ~0.077 for the player
  and ~0.064 for enemies, fading quickly to zero toward the edges.
- Colors are sampled from the dominant saturated hue of each **existing**
  animated sprite, with results cached per texture. This automatically keeps
  the glow consistent with basic, Speed, support, tank, railgun, mine ship and
  player weapon themes without assuming new character colors.
- The player halo tint refreshes when the player changes weapon modes.
  Enemy halo tint is selected once at enemy spawn. No per-frame image scan.

## Automated verification

From the Godot project root:

```sh
godot --headless --path . --script res://tests/subtle_ship_glow_test.gd
godot --headless --path . --script res://tests/laser_visual_test.gd
```

The new test uses synthetic warm, green and blue sprite frames to verify
automatic tint selection, plus scene checks for behind-the-sprite ordering,
subtle opacity and preservation of original animated skins.

## In-editor checks

1. Compare the laser before/after: the core stays sharp and straight, the
   glow is slightly softer, the blue sparks remain visible but less busy.
2. Inspect player at each of the three weapon modes: the halo must remain
   very faint and match the sprite's actual existing color, not repaint it.
3. Spawn all six enemy types: each should retain its original appearance,
   with only a gentle color-matched halo behind it.
4. Spawn a large wave: make sure the halos do not obscure neighboring ships,
   tank shields, support healing circles, hit flashes or health bars.
5. Verify the existing hitboxes and laser collision behavior are unchanged.
