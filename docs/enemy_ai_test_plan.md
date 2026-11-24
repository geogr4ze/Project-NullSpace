# Enemy AI Rework – Design and Test Plan

This feature branch starts from current `main`; it does not depend on older refactor branches.

## Behavior table

| Enemy | Movement/decision behavior |
|---|---|
| Basic | Pursues player; avoids stacking with nearby ships |
| Speed | Steers toward predicted player interception, physically turns toward its actual flight direction, and uses tank cover only when behind an eligible tank |
| Support | Prioritizes damaged non-support allies inside 420 px search radius, follows them from a safer side; otherwise orbits at 290–425 px |
| Tank | Keeps advancing on the player, while biasing its route to defend an assigned nearby support (one-to-one protection) |
| Railgun | Tries to stay 340–535 px away, strafes within that band, leads shots using estimated flight time |
| Mine ship | Tries to stay 275–435 px away, strafes, and deploys mines toward the player's predicted path with small random spread |

Enemy movement remains frame-rate independent; existing attack timers, projectile interactions, health, score, shield, and wave data are unchanged.

## Shared rules

- A shared `EnemySquadManager` assigns tank/support pairs every 0.25 seconds. It pairs each support with **at most one tank**, and each tank with **at most one support**, favoring nearby combinations and preserving existing assignments when sensible.
- Defending a support alters the tank's chase direction rather than making it stop pursuing or reverse course. Tanks without a partner simply chase the player.
- Ships use smooth, delta-time-independent angular steering instead of `look_at()` snapping. Turn responsiveness rises as ships approach the player; actual turn amount is proportional to angular error. Speed enemies face their current movement direction so intercept paths look natural.

- The `enemy_ai` group contains spawned enemies. Each enemy considers other ships on a staggered ~0.20–0.26 second decision interval rather than checking all others at 60 FPS.
- **Tank cover is positional, not attraction.** For an eligible tank, its center must be closer to the player than the enemy is, it must lie ahead along the player-to-enemy direction, and the enemy must be within 130 px laterally behind it.
- Only living, on-screen tanks with remaining shield HP can provide cover. If the tank dies, loses its shield, moves behind the enemy, or no longer aligns with the player, cover is dropped **immediately**.
- Ships use one of five stable formation lanes, 135 px behind their tank. A 0.5-second commitment prevents switching between valid tanks too rapidly, and a 0.5-second reacquisition delay prevents oscillation after cover is lost. **Neither delay overrides the closer-to-player rule**.
- Small repulsion keeps enemies from occupying exactly the same position. Enemy spacing is sampled only when their AI decision updates.
- If no valid tank is in front, each enemy immediately uses its own role's movement logic.

## Automated geometry tests

Run in Godot from the repository root:

```sh
godot --headless --path . --script res://tests/enemy_tactics_test.gd
```

The test script checks front/back position, closer-than-tank rejection, lateral rejection, zero-distance guards, stable formation lanes, pursuit prediction, ranged approach/retreat geometry, smooth frame-rate-independent rotation, and tank pursuit while defending.

Run the one-to-one assignment tests as well:

```sh
godot --headless --path . --script res://tests/enemy_squad_manager_test.gd
```

## In-game checks

1. Spawn one tank ahead of a basic enemy and line them up with the player. The basic should follow behind the tank, with other basic enemies in different lanes.
2. Move the player around or dash past the basic so the basic is closer than the tank. It should immediately chase the player rather than backtracking to the tank.
3. Put a tank far to one side. Enemies outside the shield lane should ignore it and continue their normal behavior.
4. Spawn two tanks and one nearby support. Exactly one tank should protect that support; the other keeps chasing the player. Add a second support and verify both tanks can take one distinct partner each. Confirm they do not continuously swap assignments.
5. Destroy the covering tank or break its shield with the large laser. Dependents should immediately return to normal behavior.
6. Add a wounded tank near a support ship. The support should move into healing distance, without repeatedly circling the player in melee range.
7. Move in a straight line across a speed enemy's view: it should lead your movement, physically face its new travel direction, and curve around smoothly. Compare turning at close and far distances and at 30/60/120 FPS.
8. Approach a railgun ship and then retreat. It should try to back away when close, advance when far, and lead its projectile shots.
9. Approach a mine ship: it should retreat and deploy mines roughly toward your projected path.
10. Test tank defense: the tank must keep progressing toward the player while biasing toward its assigned support. Test with high enemy counts and at 30/60/120 FPS. Verify no stuttering or new crashes and that damage, waves, projectiles, tank shields, and support auras still work.

## Limits

The AI is deterministic steering, not a navigation-mesh/pathfinding system. It doesn't route around arbitrary static obstacles and doesn't change projectile damage. The values are initial gameplay tuning parameters; validate visually before merging.
