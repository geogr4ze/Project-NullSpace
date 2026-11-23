extends Node2D

var pressed_button1 = true
var pressed_button2 = true
var auto_start = false 
var click_scale := Vector2(0.005, 0.005)
var shop_scene := "res://Nodes/shop.tscn"
var status
var play = preload("res://Buttons/Play + autoplay Skins-1.png.png")
var pause = preload("res://Buttons/Play + autoplay Skins-3.png.png")

func _ready():
	Signalbus.wave_complete.connect(on_wave_complete)
	Signalbus.test_mode.connect(on_test)

func _process(_delta):
	var progress = []
	status = ResourceLoader.load_threaded_get_status(shop_scene, progress)
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
	clicked($%Button3)
	Shopcontrol.shop_open = true
	while true:
		await get_tree().create_timer(0.5).timeout
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene = ResourceLoader.load_threaded_get(shop_scene)
			get_tree().change_scene_to_packed(scene)

#Play/Pause functions-----------------------------------------------------------
func _on_button_1_pressed() -> void:
	if pressed_button1 or auto_start:
		play_pause_control()

func playshow() -> void:
	for i in 50:
		$Play_PauseTab.position -= Vector2(0, 1.0)
		await get_tree().create_timer(0.01).timeout

func playhide() -> void:
	for i in 50:
		$Play_PauseTab.position += Vector2(0, 1.0)
		await get_tree().create_timer(0.01).timeout

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

#Helper functions----------------------------------------------------------------
var vectors = [Vector2(1.0, 0), Vector2(0, -1.0)]

func extend(button, vector_type):
	for i in 10:
		button.position += vectors[vector_type]
		await get_tree().create_timer(0.01).timeout

func retract(button, vector_type):
	for i in 10:
		button.position -= vectors[vector_type]
		await get_tree().create_timer(0.01).timeout

func show_button(button, vector_type):
	for i in 100:
		button.position += vectors[vector_type]
		await get_tree().create_timer(0.01).timeout

func hide_button(button, vector_type):
	for i in 100:
		button.position -= vectors[vector_type]
		await get_tree().create_timer(0.01).timeout

func clicked(button):
	for i in 10:
		button.scale -= click_scale
		await get_tree().create_timer(0.01).timeout
	for i in 10:
		button.scale += click_scale
		await get_tree().create_timer(0.01).timeout

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
