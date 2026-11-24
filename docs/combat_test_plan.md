# Combat refactor – verification checklist

These gameplay changes are based on the folder-reorganization branch, **not** the original `main` branch. This checklist requires running the project in Godot; only static checks were possible when preparing the change.

## Movement (run at 30, 60, and 120+ rendered FPS)
- Hold W/S and rotate with A/D. The player should have the same travel speed at different frame rates.
- Press E in the default mode: one 0.5-second forward dash, costing 2 energy, then a 3-second cooldown.
- Verify the player does not move twice when a dash begins, and remains within the viewport.

## Shooting (1, 2, 3 select modes)
- Default weapon: automatic shooting works with the shop option enabled. Energy decreases once for each projectile.
- Wave weapon: charge-up takes roughly 0.7 seconds, then shoots; releasing Fire resets the charge.
- Laser weapon: 1.25-second charge, heat on successful shots, and cooling at 1 unit/second when not firing (including while overheated or in other modes). Maximum heat locks firing until fully cooled.
- Switching modes after firing must not change a projectile already in flight.
- At different render frame rates, shooting/cooldown behavior should remain consistent because combat updates run in physics ticks.

## Damage and collisions
- A default projectile affects a given enemy at most once and can pierce up to two *distinct* enemies; a wave projectile can pierce up to ten.
- The tank shield blocks default/wave bullets without losing HP. Only the large mode 3 laser reduces shield HP; hull damage resumes when it breaks.
- Multiple bullets hitting an enemy on the same physics tick must not award money/score/kill count more than once.
- Enemies stop at zero HP. Player shield and HP do not become negative. Player death pauses the scene exactly once.
- Enemy railgun bullets disappear after hitting the player once.
- Mines can be destroyed with projectiles; an explosion damages the player at most once; explosions finish and despawn.
- Check that health bars appear on hits, hold for about five seconds, then fade smoothly.
- Support-area healing must not hang the game when the target is already at full health.
- The support aura's radius and appearance are 1.3× larger, and transparency is increased to alpha 0.2.

## Spawning
- All enemy spawn positions should be on the right of the game screen (x = 1775), y = 0 through 904; no spawns on other sides.
- In wave mode, verify each type spawns the number specified in `data/waves/waveinfo.txt`; selection should never pick an already-exhausted type.
- With `Wavecontrol.test_enable = true` (the existing repository default), wave progression is disabled and test enemies spawn. Set to `false` when testing normal wave progression.
- Check test spawning does not mix enemy type, sprite, collision, HP, or speed.

## Notes
- Original experimental balance settings (including starter energy and shop unlocks) are deliberately unchanged.
- Projectile damage remains 1 per collision target; the new `register_hit(target)` method centralizes pierce tracking.
- CCD ray mode is enabled on player and enemy rigidbody projectiles, but high-speed Area2D intersections still need visual/runtime testing.
- The separately noted incomplete terminal addon in the reorganized branch is outside the combat refactor.
