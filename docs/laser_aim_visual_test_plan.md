# Laser Aim Limiter and Beam Visuals — Test Plan

## Laser steering

Mouse aiming for default and wave weapons stays immediate. Laser aim is
limited **only while holding Fire to charge or fire the large laser**, provided
the weapon is not overheated. At the start of charging the maximum angle is
**90 degrees/second**, gradually declining to **32 degrees/second** at full
charge. During active firing it stays at **32 degrees/second**, so suddenly
moving the cursor across the arena cannot immediately sweep the beam.
Releasing Fire, changing modes or entering overheat removes the aim cap.
WASD-relative movement and normal dash movement are unchanged.

The aim limiter uses the shortest angular path and a real angular speed in
radians/second; it handles both sides of the -PI/PI seam without snapping.

## Beam appearance

The high-speed laser projectile retains the same **damage, pierce, velocity,
cooldown and collision shape**. It now uses three perfectly straight, overlapping
`Line2D` layers from local (0,0) to (0,-290): a faint wide blue glow, a bright
cyan-blue band and a narrower pale-blue/white core. The old laser sprite is
hidden only for laser projectiles. A small `CPUParticles2D` emitter creates
blue sparks around the beam, with a short lifespan and fade-out gradient.
The particles are cosmetic, do not influence collision or targeting, and
emit only on Mode 2 (third weapon slot).

## Automated tests

Run in Godot from the repository root:

```sh
godot --headless --path . --script res://tests/player_controls_test.gd
godot --headless --path . --script res://tests/laser_visual_test.gd
```

The control tests validate angle capping, seam handling and framerate
independence. The visual tests validate visibility for all three weapon modes,
a straight beam core, blue particle emission only for the laser and unchanged
collision shapes and transforms.

## In-game checks

1. Aim with default and wave while moving the mouse quickly: tracking should
   remain immediate; firing should still travel toward the cursor.
2. Equip the large laser without firing: mouse aim should remain immediate.
3. Hold Fire to charge: move the cursor sharply across the player; the ship
   should turn progressively more slowly as the charge completes.
4. Keep the laser firing: the ship should turn at approximately 32 degrees
   per second, even if the cursor is directly behind it. Check that releasing
   Fire restores normal mouse aim.
5. Trigger overheat and switch weapons: both should restore immediate aim.
6. Inspect laser shots: confirm the solid central beam is straight with soft
   blue glow and small blue spark particles, not an animated wavy texture.
7. Compare default/wave shots: their existing artwork and hitboxes should be
   unchanged. Laser hits should still use the existing 290-pixelish rectangle.
8. Fire continuously into enemy formations and tanks: verify shield damage
   rules, projectile prediction, score and target hit detection remain intact.
9. Check framerate/performance at 30/60/120 FPS with many laser projectiles.
   If particles become expensive, reduce the laser particle `amount`.
