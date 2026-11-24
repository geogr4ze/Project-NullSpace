extends Node2D

# This scene is an overlay. The gameplay scene stays loaded underneath it.
var closing: bool = false

func _on_button_pressed() -> void:
	if closing:
		return
	closing = true
	$Exitbutton.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property($Exitbutton, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property($Exitbutton, "scale", Vector2.ONE, 0.1)
	await tween.finished
	Shopcontrol.shop_open = false
	get_tree().paused = false
	queue_free()
