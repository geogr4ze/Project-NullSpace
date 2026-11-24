# Mouse Aim and Relative WASD Controls

Player movement is now relative to the ship's current mouse-facing direction.
The ship, weapon muzzle, collision shape, and its shield continue rotating
together, so attacks use the same mouse-aimed heading.

## Key bindings

| Input | Action |
|---|---|
| Move mouse | Aim toward the cursor (slower while charging or firing the laser) |
| W | Move forward in the direction the ship is facing |
| S | Move backward, away from its nose |
| A | Strafe left perpendicular to the ship's nose |
| D | Strafe right perpendicular to the ship's nose |
| Space | Fire the currently selected weapon (unchanged) |
| E | Dash forward in the direction the ship is currently facing (unchanged) |
| 1 / 2 / 3 | Switch weapons (unchanged) |

WASD may be combined diagonally, but its input is normalized so diagonals do
not exceed the configured `max_speed`. Existing movement acceleration,
screen-boundary clamping, dash cooldown and weapon firing rules remain.

Old A/D steering and the Shift slow-turn binding are removed. Mouse aiming
remains immediate with default and wave weapons. Holding Fire while the
large laser is selected now limits angular turn speed: it decreases from
90 degrees/second at the start of charge to 32 degrees/second when firing.
Laser overheat, releasing Fire and changing modes restore immediate aiming.

## Speed enemy speed

Speed enemy stat retains its existing base `enemy_speed = 1.8` and now has
`speed_multiplier = 1.5`. The multiplier is applied after the spawn's speed
randomization in `Enemy._apply_enemy_stats()`, so the final randomized
movement speed is exactly 1.5× the previous value. Other enemy types use
the default multiplier 1.0.

## Automated checks

From the Godot project root:

```sh
godot --headless --path . --script res://tests/player_controls_test.gd
```

The test covers four mouse directions, the cursor overlapping the ship,
forward/back/strafe mapping, rotated movement, normalized diagonal speed,
input bindings and retention of Fire/Dash.

## Manual checks

1. Move the mouse to each side and quadrant of the ship: the nose and muzzle
   should point at the cursor, independent of velocity.
2. Hold W while moving the mouse in a circle: the ship should move in the
   direction it faces. Hold S to reverse, and A or D to strafe without turning.
3. Hold W+A, W+D, S+A and S+D: diagonal movement should not be faster than W.
4. Fire all three weapon modes while moving and strafing: bullets should
   launch toward the cursor using the existing muzzle position.
5. Charge the wave: aiming responds immediately. Charge and fire the laser:
   aiming slows progressively to prevent instant screen-wide sweeps. Test
   immediate recovery after releasing Fire and during overheat.
6. Hold E dash while changing aim: the dash stays forward in the aim direction;
   confirm cooldown, energy drain and wall boundaries remain unchanged.
7. Check enemy bullets, mines, tank shield blocking and predictive projectile
   evasion after moving and firing with the new controls.
8. Spawn Speed enemies with existing game test mode and confirm their final
   randomized movement speeds are 50% higher than before.
