extends Node2D

var pressed_button1 = true
var pressed_button2 = true
var auto_start = false 
var click_scale := Vector2(0.005, 0.005)
var shop_scene := "res://scenes/shop.tscn"
var shop_loading := false
var tab_targets: Dictionary = {}
var tab_tweens: Dictionary = {}
var click_tweens: Dictionary = {}
var play = preload("res://assets/ui/buttons/Play + autoplay Skins-1.png.png")
var pause = preload("res://assets/ui/buttons/Play + autoplay Skins-3.png.png")

func _ready():
	Signalbus.wave_complete.connect(on_wave_complete)
	Signalbus.test_mode.connect(on_test)

func _process(_delta):
	if Input.is_action_just_pressed("auto_next_wave") and pressed_button2:
		extend($AutoPlayTab, 1)
		autoplay_control()
		await get_tree().create_timer(0.5).timeout
		retract($AutoPlayTab, 1)
	if Input.is_action_just_pressed("next_wave") and pressed_button1:
		extend($Play_PauseTab, 1)
		play_pause_control()
		await get_tree().create_timer(0.5).timeout
		retract($Play_PauseTab, 1)
	if Input.is_action_just_pressed("shop") and !Shopcontrol.shop_open:
		extend($ShopTab, 0)
		shop_control()
		await get_tree().create_timer(0.5).timeout
		retract($ShopTab, 0)

#Button functions---------------------------------------------------------------
func play_pause_control() -> void:
	pressed_button1 = false
	if $%Button1.icon == play:
		clicked($%Button1)
		_next_wave()
		pressed_button2 = false
		autoplayhide()
		playhide()
		shophide()
	elif $%Button1.icon == pause:
		clicked($%Button1)
		auto_start = false
		pressed_button2 = true
		playhide()
		$%Button1.icon = play

func autoplay_control() -> void:
	pressed_button2 = false
	clicked($%Button2)
	auto_start = true
	_next_wave()
	$%Button1.icon = pause
	autoplayhide()
	shophide()

func shop_control() -> void:
	if shop_loading:
		return
	shop_loading = true
	clicked($%Button3)
	Shopcontrol.shop_open = true

	var request_error := ResourceLoader.load_threaded_request(shop_scene)
	if request_error != OK:
		push_error("Shop scene loading failed: " + str(request_error))
		Shopcontrol.shop_open = false
		shop_loading = false
		return

	var load_status := ResourceLoader.load_threaded_get_status(shop_scene)
	while load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		load_status = ResourceLoader.load_threaded_get_status(shop_scene)

	if load_status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene := ResourceLoader.load_threaded_get(shop_scene) as PackedScene
		if scene != null:
			get_tree().change_scene_to_packed(scene)
			return

	push_error("Shop scene could not be loaded.")
	Shopcontrol.shop_open = false
	shop_loading = false

#Play/Pause functions-----------------------------------------------------------
func _on_button_1_pressed() -> void:
	if pressed_button1 or auto_start:
		play_pause_control()

func playshow() -> void:
	_move_tab($Play_PauseTab, Vector2.UP * 50.0, 0.5)

func playhide() -> void:
	_move_tab($Play_PauseTab, Vector2.DOWN * 50.0, 0.5)

func _on_button_1_mouse_entered() -> void:
	extend($Play_PauseTab, 1)

func _on_button_1_mouse_exited() -> void:
	retract($Play_PauseTab, 1)

#Autoplay functions-------------------------------------------------------------
func _on_button_2_pressed() -> void:
	if pressed_button2:
		autoplay_control()

func autoplayshow() -> void:
	show_button($AutoPlayTab, 1)

func autoplayhide() -> void:
	hide_button($AutoPlayTab, 1)

func _on_button_2_mouse_entered() -> void:
	extend($AutoPlayTab, 1)

func _on_button_2_mouse_exited() -> void:
	retract($AutoPlayTab, 1)

#Shop functions-----------------------------------------------------------------
func _on_button_3_pressed() -> void:
	if !Shopcontrol.shop_open:
		shop_control()

func shopshow() -> void:
	show_button($ShopTab, 0)

func shophide() -> void:
	hide_button($ShopTab, 0)

func _on_button_3_mouse_entered() -> void:
	extend($ShopTab, 0)

func _on_button_3_mouse_exited() -> void:
	retract($ShopTab, 0)

# Helper functions — one tween per tab; no timer-per-pixel animation.
const HOVER_DISTANCE := 10.0
const TAB_DISTANCE := 100.0
const HOVER_DURATION := 0.1
const TAB_DURATION := 1.0
var vectors := [Vector2.RIGHT, Vector2.UP]

func _move_tab(tab: Control, offset: Vector2, duration: float) -> void:
	var key := tab.get_instance_id()
	var target: Vector2 = tab_targets.get(key, tab.position)
	target += offset
	tab_targets[key] = target
	if tab_tweens.has(key):
		var previous: Tween = tab_tweens[key]
		if previous.is_valid():
			previous.kill()
	var tween := create_tween()
	tween.tween_property(tab, "position", target, duration)
	tab_tweens[key] = tween

func extend(tab: Control, vector_type: int) -> void:
	_move_tab(tab, vectors[vector_type] * HOVER_DISTANCE, HOVER_DURATION)

func retract(tab: Control, vector_type: int) -> void:
	_move_tab(tab, -vectors[vector_type] * HOVER_DISTANCE, HOVER_DURATION)

func show_button(tab: Control, vector_type: int) -> void:
	_move_tab(tab, vectors[vector_type] * TAB_DISTANCE, TAB_DURATION)

func hide_button(tab: Control, vector_type: int) -> void:
	_move_tab(tab, -vectors[vector_type] * TAB_DISTANCE, TAB_DURATION)

func clicked(button: Control) -> void:
	var key := button.get_instance_id()
	if click_tweens.has(key):
		var previous: Tween = click_tweens[key]
		if previous.is_valid():
			previous.kill()
	var original_scale: Vector2 = button.scale
	var tween := create_tween()
	tween.tween_property(button, "scale", original_scale - click_scale * 10.0, 0.1)
	tween.tween_property(button, "scale", original_scale, 0.1)
	click_tweens[key] = tween

#Wave functions-----------------------------------------------------------------
func on_wave_complete(wave) -> void:
	if auto_start:
		await get_tree().create_timer(2).timeout
		_next_wave()
	else:
		if wave <= 25:
			pressed_button1 = true
			pressed_button2 = true
			autoplayshow()
			playshow()
			shopshow()

func _next_wave() -> void:
	Signalbus.next_wave.emit()
	await get_tree().create_timer(7).timeout
	Wavecontrol.spawn_enemy()

func on_test() -> void:
	pressed_button1 = false
	pressed_button2 = false
	for i in 100:
		$AutoPlayButton.position += Vector2(0, 1.0)
		$%AutoPlaySkin.position += Vector2(0, 1.0)
		$Play_PauseButton.position += Vector2(0, 1.0)
		$%Play_PauseSkin.position += Vector2(0, 1.0)
		await get_tree().create_timer(0.01).timeout
