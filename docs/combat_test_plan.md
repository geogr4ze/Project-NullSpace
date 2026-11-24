# Combat refactor – verification checklist

These gameplay changes are based on the folder-reorganization branch, **not** the original `main` branch. This checklist requires running the project in Godot; only static checks were possible when preparing the change.

## Movement (run at 30, 60, and 120+ rendered FPS)
- Hold W/S and rotate with A/D. The player should have the same travel speed at different frame rates.
- Press E in the default mode: one 0.5-second forward dash, costing 2 energy, then a 3-second cooldown.
- Verify the player does not move twice when a dash begins, and remains within the viewport.

## Shooting (1, 2, 3 select modes)
- Default weapon: automatic shooting works with the shop option enabled. Energy decreases once for each projectile.
- Wave weapon: charge-up takes roughly 0.7 seconds, then shoots; releasing Fire resets the charge.
- Laser weapon: charge-up takes about 1.25 seconds. Heat accumulates only on successful shots and visibly cools at 1 heat unit/second whenever it is not firing, even if Fire stays held during overheat or the player switches weapons. At maximum heat, laser firing is locked until fully cooled.
- Switching modes after firing must not change a projectile already in flight.
- At different render frame rates, shooting/cooldown behavior should remain consistent because combat updates run in physics ticks.

## Damage and collisions
- A default projectile affects a given enemy at most once and can pierce up to two *distinct* enemies; a wave projectile can pierce up to ten.
- While a tank shield has HP, default and wave projectiles are blocked without reducing shield HP. Only the large mode 3 laser reduces its 25 shield HP. The tank hull starts taking normal damage only after the shield is depleted; shield regeneration still works.
- Multiple bullets hitting an enemy on the same physics tick must not award money/score/kill count more than once.
- Enemies stop at zero HP. Player shield and HP do not become negative. Player death pauses the scene exactly once.
- Enemy railgun bullets disappear after hitting the player once.
- Mines can be destroyed with projectiles; an explosion damages the player at most once; explosions finish and despawn.
- Check that health bars appear on hits, hold for about five seconds, then fade smoothly.
- Support-area healing must not hang the game when the target is already at full health.
- The support field's radius and visual effect are both 1.3× the original size, and the field is slightly more transparent (alpha 0.2 instead of 0.3). Check that healing begins at the enlarged boundary.

## Spawning
- Every enemy spawn must appear along the right side, approximately 75 pixels beyond the 1700-pixel-wide viewport (x = 1775), with randomized y from 0 to 904. No enemies should spawn on the top, left, or bottom edges.
- In wave mode, verify each type spawns the number specified in `data/waves/waveinfo.txt`; selection should never pick an already-exhausted type.
- With `Wavecontrol.test_enable = true` (the existing repository default), wave progression is disabled and test enemies spawn. Set to `false` when testing normal wave progression.
- Check test spawning does not mix enemy type, sprite, collision, HP, or speed.

## Notes
- Original experimental balance settings (including starter energy and shop unlocks) are deliberately unchanged.
- Projectile damage remains 1 per collision target; the new `register_hit(target)` method centralizes pierce tracking.
- CCD ray mode is enabled on player and enemy rigidbody projectiles, but high-speed Area2D intersections still need visual/runtime testing.
- The separately noted incomplete terminal addon in the reorganized branch is outside the combat refactor.
