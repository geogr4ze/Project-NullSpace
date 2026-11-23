# Optimization pass — manual verification

This change is a code-review refactor. **Godot has not been run automatically.** Test the branch before merging into `main`.

## Startup / errors

- Open `project.godot` and check the Godot Output/Debugger panels for script parse errors.
- Verify autoloads (especially `Wavecontrol`) initialize without errors.
- The removed Godot Terminal plugin should remain disabled and absent.

## Player / combat (keep the original balance)

- Test W/S thrust, A/D turning, dash on E, and shooting with all three modes.
- Verify the existing energy costs, charge durations, laser heat/cooling, and firing behavior are unchanged.
- Shoot enemies and mines; confirm no duplicate damage or kill rewards.
- With tanks, verify their shield blocks normal bullets but not laser shots.
- Check projectiles retain their weapon properties after a player mode switch.

## Wave spawning / support healing

- In test mode (`Wavecontrol.test_enable = true` by default), verify configured test enemies still spawn.
- In wave mode (`test_enable = false`), verify a wave completes when its last enemy dies, and the next wave button still works.
- Verify all enemy types have the expected sprite/HP/collision after spawning.
- Keep an enemy at full health inside a support aura for several seconds: the game must stay responsive.
- Move a damaged enemy into/out of a support aura: it should heal once per second only while overlapping.

## UI and scene loading

- Hover and unhover each menu tab; repeatedly press Play/Pause and AutoPlay to check for drifting or stuck animations.
- Open the shop. Verify it loads once, and that rapidly pressing the shop key does not start duplicate loads.
- Start the game from the start screen; the progress bar should reflect resource-loader progress rather than run on fixed delays.
- Verify wave text fades in/out and energy-warning text restores after three seconds.
- Verify energy pickups switch to decay animation and eventually disappear.

## Performance

- Compare Godot Debugger > Profiler and Monitors at similar enemy counts before/after the change; record FPS, frame time, and object count.
- Reuse/pool projectiles or enemies **only if profiling shows allocation/instantiation spikes**; physics bodies require careful reset and are not pooled in this pass.
- The larger splitting of default, wave, and laser scripts into separate weapon scenes is also deferred until gameplay behavior is verified.

## Scope

This pass preserves existing weapon balance, controls, shop unlock defaults, and the current testing-mode default.
It adds a reusable weapon cooldown component, typed projectile/enemy dispatch, and cached node references. It does not remove old Godot-generated `.godot/` files already tracked by earlier commits; that is separate repository cleanup.
