extends SceneTree

var failures: int = 0
var victory_count: int = 0
var completion_count: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Wavecontrol.reset_run()
	Shopcontrol.reset_run()
	Modecontrol.reset_run()
	Signalbus.game_over.connect(_on_game_over)
	Signalbus.wave_complete.connect(_on_wave_complete)
	_check(Wavecontrol.wave == 1 and Wavecontrol.total_enemy_count == 10, "first wave loads")
	_check(Wavecontrol.enemy_per_round.size() == 6, "six typed counts")
	Wavecontrol.wave = Wavecontrol.max_wave - 1
	Wavecontrol.new_enemy_totals()
	Wavecontrol.wave_active = true
	Wavecontrol.enemy_kc = Wavecontrol.total_enemy_count - 1
	Wavecontrol.kill_count()
	_check(completion_count == 1 and Wavecontrol.wave == Wavecontrol.max_wave, "next wave prepared before completion")
	Wavecontrol.wave_active = true
	Wavecontrol.enemy_kc = Wavecontrol.total_enemy_count - 1
	Wavecontrol.kill_count()
	Wavecontrol.kill_count()
	_check(victory_count == 1 and completion_count == 1 and Wavecontrol.finished, "victory emitted once without extra wave")
	_check(not Wavecontrol.can_start_wave(), "cannot start wave 26")
	Wavecontrol.reset_run()
	_check(Wavecontrol.can_start_wave() and Wavecontrol.wave == 1, "restart clears wave state")
	Shopcontrol.shopmoney = 100
	_check(not Shopcontrol.buy("energy"), "cannot buy outside shop")
	Shopcontrol.shop_open = true
	_check(Shopcontrol.buy("energy") and Shopcontrol.shopmoney == 75.0 and Shopcontrol.energy_multi == 1.25, "upgrade costs credits and changes stat")
	Shopcontrol.reset_run()
	_check(not Shopcontrol.shop_open and Shopcontrol.shopmoney == 0.0 and Shopcontrol.energy_multi == 1.0, "shop state reset")
	_check(Shopcontrol.autofire and Shopcontrol.bought_mode1 and Shopcontrol.bought_mode2 and Shopcontrol.bought_shield, "original unlocks preserved")
	Modecontrol.set_mode(Modecontrol.MODE2)
	Modecontrol.reset_run()
	_check(Modecontrol.mode == Modecontrol.DEFAULT, "weapon resets")
	quit(1 if failures > 0 else 0)

func _on_game_over(won: bool) -> void:
	if won:
		victory_count += 1

func _on_wave_complete(_wave: int) -> void:
	completion_count += 1

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + description)
