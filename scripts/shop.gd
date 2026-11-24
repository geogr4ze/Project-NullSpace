extends Node2D

var closing: bool = false
var balance_label: Label
var upgrade_buttons: Dictionary = {}

func _ready() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)
	var center: CenterContainer = CenterContainer.new()
	canvas.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.custom_minimum_size = Vector2(440, 0)
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	var title: Label = Label.new()
	title.text = "Ship Upgrades"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	content.add_child(title)
	balance_label = Label.new()
	content.add_child(balance_label)
	for id: String in Shopcontrol.UPGRADES:
		var button: Button = Button.new()
		button.pressed.connect(_purchase.bind(id))
		content.add_child(button)
		upgrade_buttons[id] = button
	_refresh()
	var leave: Button = Button.new()
	leave.text = "Return to game"
	leave.pressed.connect(_on_button_pressed)
	content.add_child(leave)

func _purchase(id: String) -> void:
	if closing:
		return
	Shopcontrol.buy(id)
	_refresh()

func _refresh() -> void:
	balance_label.text = "Credits: $%d" % int(Shopcontrol.shopmoney)
	for id: String in upgrade_buttons:
		var button: Button = upgrade_buttons[id]
		var level: int = Shopcontrol.upgrade_level(id)
		var maximum: int = int(Shopcontrol.UPGRADES[id]["max"])
		var label: String = str(Shopcontrol.UPGRADES[id]["label"])
		if level >= maximum:
			button.text = "%s - MAX" % label
		else:
			button.text = "%s [%d/%d] - $%d" % [label, level, maximum, Shopcontrol.upgrade_cost(id)]
		button.disabled = not Shopcontrol.can_buy(id)

func _on_button_pressed() -> void:
	if closing:
		return
	closing = true
	$Exitbutton.disabled = true
	for button: Button in upgrade_buttons.values():
		button.disabled = true
	var tween: Tween = create_tween()
	tween.tween_property($Exitbutton, "scale", Vector2(0.95, 0.95), 0.1)
	tween.tween_property($Exitbutton, "scale", Vector2.ONE, 0.1)
	await tween.finished
	Shopcontrol.shop_open = false
	get_tree().paused = false
	queue_free()
