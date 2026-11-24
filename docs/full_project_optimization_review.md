# Full-project review — Godot scenes and GDScript

This pass reviewed all 16 original scripts and 12 original scenes in the repository (plus a new shop scene controller). **The editor and runtime were not available here**, so all gameplay changes must be tested before merging.

## Changes made

- Fix signal declarations for emitted values (score, money, new enemies, wave completion, projectiles, and spawned items)
- Improve enemy spawning setup by selecting collision shapes explicitly and guarding unknown enemy types
- Guard against duplicate enemy contact-damage loops and support-healing loops; healing can continue across overlapping support auras
- Replace repeated damage/overshield flash timers and mine-deployment timer loops with Tweens
- Cache player, HUD, and frequently used nodes accessed during physics/combat updates
- Initialize projectile collision shapes directly rather than building a new array on every bullet
- Ignore energy pickup collisions from non-player bodies; recognize the player by type instead of name
- Make test-mode button hiding reference actual scene nodes
- Open the shop as a pause-state overlay **without destroying and recreating the running game**; closing it resumes the same wave/player
- Turn decorative portals into Node2D instead of RigidBody2D and remove their unnecessary collision shape
- Free primed mines when they leave the screen
- Remove an unused dummy Node and embedded script from the main scene
- Validate wave-data lengths and enemy type counts; avoid repeated mode-change signals for the selected mode
- Make the player viewport boundary track window resizes

## Required manual tests

1. Open `project.godot` in the target Godot version. Check the editor's **Output** and **Debugger** for parser/type or missing-resource errors.
2. Test Start → main game, with all three weapon modes and the original dash, overheat, shield, and energy behavior.
3. With `Wavecontrol.test_enable = true` (still the original default), verify test enemies spawn and the control tabs disappear without missing-node errors.
4. Temporarily set `test_enable = false` on a test copy: complete a wave, trigger next-wave/autoplay, and confirm exact enemy counts and correctly configured sprites, HP, and collisions.
5. Keep a full-health enemy inside a support aura. Ensure it does not hang. Check healing with **two overlapping support auras** and after leaving both.
6. Hold the player against an enemy for several seconds. Verify damage is applied at most once per second per overlapping enemy and stops after separating.
7. Test default, wave, and laser shots against basic enemies and tank shields. Switch modes while bullets are in flight.
8. Spawn railgun and mine-ship enemies. Verify warning animations, railgun bullet collisions, mine deployment, explosions, and score/reward events.
9. Open the shop via its button or shortcut, click Exit, and verify **the current wave, player, and economy remain intact** and the game resumes.
10. Send the player through energy pickups; confirm enemies/projectiles cannot collect energy.
11. Confirm portals appear/disappear in place and spawn energy; confirm off-screen primed mines are cleaned up.
12. Resize the window and verify player clamping. Check Wave Complete/Low Energy HUD messages and menu tab animations.
13. Run Debugger → Profiler at similar enemy counts before/after this pass. Compare CPU time, active physics bodies, memory, and hitching.

## Deferred work

Object pooling, a per-weapon scene architecture, art-atlas batching, and collision-layer redesign require gameplay-specific profiling and tests. They were not included: introducing those changes blindly could break the game's current balance or scene behavior.

## Repository notes

Only source/script/scene files are edited. Any `.godot/` cache objects already tracked by older commits are untouched in this PR. Do not merge the branch until Godot runtime tests pass.
