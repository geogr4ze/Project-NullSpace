# Continuous Laser and Heavy Aim — Verification

The third weapon now draws **one continuous blue-white laser** anchored at the
player's original muzzle while it is firing successfully. Three aligned
straight Line2D layers form a faint wide blue aura, brighter cyan band and
solid white-blue core. The former repeated moving beam visuals and blue sparks
are removed from individual projectiles, eliminating visible bullet seams.

The fast invisible laser projectiles still handle the same damage, collision,
pierce, movement, energy cost, cooldown, heat, enemy shields and enemy dodges.
The long visible beam is a visual effect, not instantaneous hitscan damage.
Default and wave projectile artwork and combat are unchanged.

Laser aiming while holding Fire is now capped from **72 degrees/second** at
the start of charging down to **18 degrees/second** at full charge and during
firing. Normal and wave aiming remain immediate. Releasing Fire or
overheating now smoothly accelerates laser aim from 18°/s to 540°/s
over 0.42 seconds, with no sudden large-angle snap. Weapon switching still
restores immediate cursor aiming. The continuous beam hides
when firing stops, on overheat, mode changes or player death.

## Automated Godot tests

```sh
godot --headless --path . --script res://tests/player_controls_test.gd
godot --headless --path . --script res://tests/laser_visual_test.gd
godot --headless --path . --script res://tests/subtle_ship_glow_test.gd
godot --headless --path . --script res://tests/projectile_effects_test.gd
```

## Manual playtest

1. Equip weapon 3 without firing: no beam appears and mouse aim is immediate.
2. Hold Fire through charge: one stable continuous beam appears at the muzzle
   and reaches across the arena, with no visible moving bullet segments.
3. Sweep the mouse across the player: active firing turns at only 18°/s.
4. Release Fire: the ship eases back to the mouse without an instant snap,
   even if the cursor is behind it. Switching modes, overheating and dying
   still hide the beam.
5. Verify shield blocking, enemy hits, score, heat, energy and projectile
   prediction remain unchanged. Damage keeps its old projectile travel time.
6. Compare default and wave bullets and ship silhouettes at 30/60/120 FPS.
