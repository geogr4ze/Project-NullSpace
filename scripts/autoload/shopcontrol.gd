extends Node

var main_scene := "res://scenes/main.tscn"
var click_scale := Vector2(0.005, 0.005)

# Shop Variables
var shop_open := false #Default false
var shopmoney := 0.0 #Default 0.0
var money_multi := 1.0 #Default 1.0

# Player Affecting Variables
var firerate_multi := 0.05 # Default 1.0
var spread := 0.05 #Default 0.05
var energy_multi := 1.0 #Default 1.0
var autofire := true #Default false
var bought_mode1 := true #Default false
var bought_mode2 := true #Default false
var bought_shield := true #Default false
var bought_dash := false #Default false

func _process(_delta):
	pass
	#var progress = []
	#status = ResourceLoader.load_threaded_get_status(main_scene, progress)


func _on_button_pressed():
	print("pressed")
	clicked($Exitbutton)

func clicked(button):
	for i in 10:
		button.scale -= click_scale
		await get_tree().create_timer(0.01).timeout
	for i in 10:
		button.scale += click_scale
		await get_tree().create_timer(0.01).timeout
