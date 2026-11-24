extends Node

var failures: int = 0

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	Wavecontrol.reset_run()
	Modecontrol.reset_run()
	Shopcontrol.reset_run()
	var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
	if scene == null:
		printerr("FAIL: main scene failed to load")
		get_tree().quit(1)
		return
	var main: Node2D = scene.instantiate() as Node2D
	get_tree().root.add_child(main)
	var original_scene_id: int = main.get_instance_id()
	get_tree().current_scene = main
	await get_tree().process_frame
	var player: CharacterBody2D = main.get_node("Player")
	var buttons: Node2D = main.get_node("UI/Buttons")
	_check(int(player.get("health")) == 50 and int(player.get("shield")) == 25, "initial player stats")
	buttons.call("play_pause_control")
	_check(Wavecontrol.wave_active, "manual Play starts a wave")
	buttons.call("shop_control")
	_check(not Shopcontrol.shop_open and not get_tree().paused, "shop cannot open during wave")
	await get_tree().create_timer(0.25).timeout
	_check(get_tree().get_node_count_in_group("enemy_ai") > 0, "wave spawns actual enemies")
	Signalbus.player_death.emit()
	_check(get_tree().paused and Wavecontrol.finished, "death stops run")
	var overlay: CanvasLayer
	for child: Node in main.get_children():
		if child is CanvasLayer and child.has_method("show_result"):
			overlay = child as CanvasLayer
	_check(overlay != null and overlay.process_mode == Node.PROCESS_MODE_ALWAYS, "game-over overlay can process while paused")
	if overlay != null:
		overlay.call("_restart")
		await get_tree().scene_changed
		_check(not get_tree().paused and Wavecontrol.wave == 1 and not Wavecontrol.finished, "restart resumes a clean run")
		_check(get_tree().current_scene != null and get_tree().current_scene.get_instance_id() != original_scene_id, "gameplay scene was reloaded")
	else:
		get_tree().paused = false
	get_tree().quit(1 if failures > 0 else 0)

func _check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + description)
