extends CanvasLayer

var restarting: bool = false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_result(won: bool) -> void:
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.015, 0.035, 0.09, 0.86)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	shade.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	center.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.custom_minimum_size = Vector2(320, 0)
	content.add_theme_constant_override("separation", 16)
	panel.add_child(content)
	var title: Label = Label.new()
	title.text = "Victory" if won else "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	content.add_child(title)
	var restart: Button = Button.new()
	restart.text = "Restart"
	restart.pressed.connect(_restart)
	content.add_child(restart)
	var quit_button: Button = Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(_quit)
	content.add_child(quit_button)
	restart.grab_focus()

func _restart() -> void:
	if restarting:
		return
	restarting = true
	# Restart is deferred out of the button's input callback.
	_reload.call_deferred()

func _reload() -> void:
	Wavecontrol.reset_run()
	Modecontrol.reset_run()
	Shopcontrol.reset_run()
	var tree: SceneTree = get_tree()
	var error: Error = tree.reload_current_scene()
	tree.paused = false
	if error != OK:
		push_error("Could not restart: " + str(error))
		tree.paused = true
		restarting = false

func _quit() -> void:
	get_tree().quit()
