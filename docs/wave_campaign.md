# 50-wave campaign

The runtime source of truth is [waves.json](../data/waves/waves.json). All enemy counts are fixed; only their arrival order and existing spawn positions are randomized. Victory follows the last enemy in wave 50, not the last spawn.

## Difficulty and spawning

Threat weights: Basic 1, Speed 2, Support 4, Tank 7, Railgun 9, Mineship 6.
Target threat is round(10 * 1.065^(wave - 1)), with at least one point of growth each wave. The listed compositions match their exact threat budgets. This is a design estimate, not a guarantee of measured difficulty; enemy interactions, shop upgrades and spawn caps can change the actual experience. No enemy health, damage, weapon settings or AI are scaled by wave.

The first wave retains 10 Basic ships. Later rosters replace the previous 25-wave data and the very large draft wave 50 from the original design notes. The simultaneous cap counts living enemy ships, not mines or projectiles. If the cap is reached, spawning waits for a kill. The timer pauses with the game. New ships use the existing right-edge spawn path.

## Wave roster

| Wave | Basic | Speed | Support | Tank | Railgun | Mineship | Total | Threat | Max alive | Interval (s) |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | 10 | 0 | 0 | 0 | 0 | 0 | 10 | 10 | 10 | 0.12 |
| 2 | 11 | 0 | 0 | 0 | 0 | 0 | 11 | 11 | 11 | 0.12 |
| 3 | 12 | 0 | 0 | 0 | 0 | 0 | 12 | 12 | 12 | 0.12 |
| 4 | 13 | 0 | 0 | 0 | 0 | 0 | 13 | 13 | 13 | 0.12 |
| 5 | 14 | 0 | 0 | 0 | 0 | 0 | 14 | 14 | 13 | 0.12 |
| 6 | 9 | 3 | 0 | 0 | 0 | 0 | 12 | 15 | 12 | 0.12 |
| 7 | 8 | 4 | 0 | 0 | 0 | 0 | 12 | 16 | 12 | 0.12 |
| 8 | 9 | 4 | 0 | 0 | 0 | 0 | 13 | 17 | 13 | 0.12 |
| 9 | 10 | 4 | 0 | 0 | 0 | 0 | 14 | 18 | 14 | 0.12 |
| 10 | 11 | 4 | 0 | 0 | 0 | 0 | 15 | 19 | 15 | 0.12 |
| 11 | 8 | 4 | 1 | 0 | 0 | 0 | 13 | 20 | 13 | 0.16 |
| 12 | 9 | 4 | 1 | 0 | 0 | 0 | 14 | 21 | 14 | 0.16 |
| 13 | 10 | 4 | 1 | 0 | 0 | 0 | 15 | 22 | 15 | 0.16 |
| 14 | 11 | 4 | 1 | 0 | 0 | 0 | 16 | 23 | 16 | 0.16 |
| 15 | 8 | 4 | 2 | 0 | 0 | 0 | 14 | 24 | 14 | 0.16 |
| 16 | 9 | 3 | 1 | 1 | 0 | 0 | 14 | 26 | 14 | 0.16 |
| 17 | 10 | 3 | 1 | 1 | 0 | 0 | 15 | 27 | 15 | 0.16 |
| 18 | 10 | 4 | 1 | 1 | 0 | 0 | 16 | 29 | 16 | 0.16 |
| 19 | 12 | 4 | 1 | 1 | 0 | 0 | 18 | 31 | 18 | 0.16 |
| 20 | 14 | 4 | 1 | 1 | 0 | 0 | 20 | 33 | 20 | 0.16 |
| 21 | 5 | 4 | 2 | 2 | 0 | 0 | 13 | 35 | 13 | 0.16 |
| 22 | 6 | 5 | 2 | 2 | 0 | 0 | 15 | 38 | 15 | 0.16 |
| 23 | 8 | 5 | 2 | 2 | 0 | 0 | 17 | 40 | 17 | 0.16 |
| 24 | 11 | 5 | 2 | 2 | 0 | 0 | 20 | 43 | 20 | 0.16 |
| 25 | 11 | 6 | 2 | 2 | 0 | 0 | 21 | 45 | 21 | 0.16 |
| 26 | 7 | 5 | 2 | 2 | 1 | 0 | 17 | 48 | 17 | 0.20 |
| 27 | 8 | 6 | 2 | 2 | 1 | 0 | 19 | 51 | 19 | 0.20 |
| 28 | 12 | 6 | 2 | 2 | 1 | 0 | 23 | 55 | 23 | 0.20 |
| 29 | 15 | 6 | 2 | 2 | 1 | 0 | 26 | 58 | 24 | 0.20 |
| 30 | 17 | 7 | 2 | 2 | 1 | 0 | 29 | 62 | 25 | 0.20 |
| 31 | 15 | 7 | 2 | 2 | 1 | 1 | 28 | 66 | 25 | 0.20 |
| 32 | 13 | 7 | 2 | 2 | 1 | 2 | 27 | 70 | 25 | 0.20 |
| 33 | 12 | 8 | 3 | 2 | 1 | 2 | 28 | 75 | 26 | 0.20 |
| 34 | 17 | 8 | 3 | 2 | 1 | 2 | 33 | 80 | 26 | 0.20 |
| 35 | 11 | 9 | 3 | 2 | 2 | 2 | 29 | 85 | 27 | 0.20 |
| 36 | 13 | 11 | 3 | 2 | 2 | 2 | 33 | 91 | 27 | 0.20 |
| 37 | 10 | 12 | 3 | 3 | 2 | 2 | 32 | 97 | 28 | 0.20 |
| 38 | 16 | 12 | 3 | 3 | 2 | 2 | 38 | 103 | 28 | 0.20 |
| 39 | 16 | 13 | 4 | 3 | 2 | 2 | 40 | 109 | 29 | 0.20 |
| 40 | 16 | 14 | 4 | 3 | 2 | 3 | 42 | 117 | 29 | 0.20 |
| 41 | 14 | 16 | 5 | 4 | 2 | 2 | 43 | 124 | 30 | 0.22 |
| 42 | 14 | 17 | 5 | 4 | 2 | 3 | 45 | 132 | 30 | 0.22 |
| 43 | 21 | 18 | 5 | 4 | 2 | 3 | 53 | 141 | 30 | 0.22 |
| 44 | 15 | 19 | 6 | 4 | 3 | 3 | 50 | 150 | 31 | 0.22 |
| 45 | 16 | 20 | 6 | 5 | 3 | 3 | 53 | 160 | 31 | 0.22 |
| 46 | 29 | 19 | 6 | 4 | 3 | 4 | 65 | 170 | 32 | 0.22 |
| 47 | 27 | 20 | 7 | 5 | 3 | 4 | 66 | 181 | 32 | 0.22 |
| 48 | 28 | 21 | 7 | 5 | 4 | 4 | 69 | 193 | 33 | 0.22 |
| 49 | 32 | 23 | 8 | 5 | 4 | 4 | 76 | 205 | 33 | 0.22 |
| 50 | 31 | 24 | 8 | 6 | 4 | 5 | 78 | 219 | 34 | 0.22 |

## Editing the campaign

Each JSON entry specifies the wave number, threat, spawn_interval, max_alive and a map of enemy IDs to positive counts. Omitted enemy IDs mean zero. The loader validates all 50 entries, registered IDs, counts, cap and increasing threat at startup. When editing counts, update the threat and cap to match, and update this document and design_notes.txt.

To add an enemy, implement its gameplay/scene and register its unique id and threat in Wavecontrol.enemies alongside its existing stats. Then include that id only in the waves where it should appear. No new columns or placeholders are needed. Existing enemy scene/type wiring still needs to be updated for a genuinely new enemy type.

If exporting a standalone Godot build, include data/waves/*.json in the export preset's non-resource file filter because the loader uses FileAccess.

Run tests via the normal test runner:
```bash
godot --headless --path . res://tests/test_runner.tscn -- res://tests/wave_campaign_test.gd
```
