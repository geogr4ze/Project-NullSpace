extends Node

var failures: int = 0
var observed: Dictionary = {}

## Defer campaign tests until the scene tree is ready.
func _ready() -> void:
	call_deferred("_run")

## Validate the 50-wave campaign, enemy rosters, difficulty progression and observed spawning behavior using the wave controller.
func _run() -> void:
	Wavecontrol.reset_run()
	_check(Wavecontrol.campaign.size() == 50, "All 50 validated waves loaded")
	var previous_threat: int = 0
	var introductions: Dictionary = {}
	for number: int in range(1, 51):
		Wavecontrol.wave = number
		Wavecontrol.new_enemy_totals()
		var total: int = 0
		var threat: int = 0
		for type: int in Wavecontrol.enemy_per_round:
			var count: int = Wavecontrol.enemy_per_round[type]
			total += count
			threat += count * int(Wavecontrol.enemies[type]["threat"])
			if not introductions.has(type):
				introductions[type] = number
		_check(total > 0 and total == Wavecontrol.total_enemy_count, "Wave %d total" % number)
		_check(threat > previous_threat and threat == Wavecontrol.wave_threat, "Wave %d increasing threat" % number)
		_check(
			threat == maxi(previous_threat + 1, roundi(10.0 * pow(1.065, number - 1))),
			"Wave %d follows budget curve" % number
		)
		_check(Wavecontrol.max_alive > 0 and Wavecontrol.max_alive <= total, "Wave %d valid cap" % number)
		previous_threat = threat
		var roster: Dictionary = Wavecontrol.enemy_per_round.duplicate()
		var drawn: Dictionary = {}
		for k: int in total:
			var selected: int = Wavecontrol.get_next_wave_enemy()
			_check(roster.has(selected), "Draw only from configured roster")
			if not roster.has(selected):
				break
			drawn[selected] = int(drawn.get(selected, 0)) + 1
			Wavecontrol.enemy_per_round[selected] -= 1
		_check(drawn == roster and Wavecontrol.get_next_wave_enemy() == -1, "Exact roster exhausted")
	_check(
		introductions.get(Wavecontrol.SPEED) == 6
		and introductions.get(Wavecontrol.SUPPORT) == 11
		and introductions.get(Wavecontrol.TANK) == 16
		and introductions.get(Wavecontrol.RAILGUN) == 26
		and introductions.get(Wavecontrol.MINESHIP) == 31,
		"Enemy introductions are staged"
	)
	_check(previous_threat == 219, "Final wave budget")
	# Exercise the actual asynchronous scheduler with a small test cap.
	Wavecontrol.reset_run()
	Wavecontrol.max_alive = 2
	Wavecontrol.spawnrate = 0.01
	Signalbus.new_enemy.connect(_on_spawn)
	Wavecontrol.spawn_enemy()
	await get_tree().create_timer(0.15).timeout
	_check(Wavecontrol.spawned_enemy_count == 2, "Spawner waits at simultaneous cap")
	Wavecontrol.kill_count()
	await get_tree().create_timer(0.12).timeout
	_check(Wavecontrol.spawned_enemy_count == 3, "A kill releases one spawn slot")
	Wavecontrol.stop_run()
	var stopped_count: int = Wavecontrol.spawned_enemy_count
	await get_tree().create_timer(0.08).timeout
	_check(Wavecontrol.spawned_enemy_count == stopped_count, "Stopping cancels queued reinforcement")
	Wavecontrol.reset_run()
	_check(
		Wavecontrol.spawned_enemy_count == 0
		and Wavecontrol.total_enemy_count == 10
		and Wavecontrol.max_alive == 10,
		"Restart restores campaign settings"
	)
	get_tree().quit(1 if failures > 0 else 0)

## Increment the observed spawn count for the given enemy type.
func _on_spawn(type: int) -> void:
	observed[type] = int(observed.get(type, 0)) + 1

## Record and print a failed campaign assertion.
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
