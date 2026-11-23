extends Node2D

const MAIN_SCENE := "res://scenes/main.tscn"
var loading := false

@onready var loading_bar: ProgressBar = $"Loading Bar"
@onready var filler_text: Label = $%FillerText

func _on_button_pressed() -> void:
	if loading:
		return
	loading = true
	$Button.disabled = true
	loading_bar.visible = true
	loading_bar.value = 0.0
	filler_text.text = "Preparing ship..."

	var request_error := ResourceLoader.load_threaded_request(MAIN_SCENE)
	if request_error != OK:
		_fail_loading("Could not start loading the game.")
		return

	var progress: Array = []
	var load_status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)
	while load_status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if !progress.is_empty():
			loading_bar.value = clampf(float(progress[0]) * loading_bar.max_value, 0.0, loading_bar.max_value)
		await get_tree().process_frame
		load_status = ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)

	if load_status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene := ResourceLoader.load_threaded_get(MAIN_SCENE) as PackedScene
		if scene != null:
			loading_bar.value = loading_bar.max_value
			get_tree().change_scene_to_packed(scene)
			return

	_fail_loading("Unable to load the main game scene.")

func _fail_loading(message: String) -> void:
	push_error(message)
	filler_text.text = "Loading failed"
	$Button.disabled = false
	loading = false
