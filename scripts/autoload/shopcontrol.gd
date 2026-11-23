extends Node

var main_scene: String = "res://scenes/main.tscn"
var click_scale: Vector2 = Vector2(0.005, 0.005)

# Shop Variables
var shop_open: bool = false #Default false
var shopmoney: float = 0.0 #Default 0.0
var money_multi: float = 1.0 #Default 1.0

# Player Affecting Variables
var firerate_multi: float = 0.05 # Default 1.0
var spread: float = 0.05 #Default 0.05
var energy_multi: float = 1.0 #Default 1.0
var autofire: bool = true #Default false
var bought_mode1: bool = true #Default false
var bought_mode2: bool = true #Default false
var bought_shield: bool = true #Default false
var bought_dash: bool = false #Default false

func _on_button_pressed():
	print("pressed")
	clicked($Exitbutton)

func clicked(button: Control) -> void:
	var original_scale: Vector2 = button.scale
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", original_scale - click_scale * 10.0, 0.1)
	tween.tween_property(button, "scale", original_scale, 0.1)
