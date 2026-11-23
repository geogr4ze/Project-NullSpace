extends Node2D

var main_scene = "res://scenes/main.tscn"
var status

func _process(_delta):
	var progress = []
	status = ResourceLoader.load_threaded_get_status(main_scene, progress)


func _on_button_pressed(): #Implement saves loading during this period
	$"Loading Bar".visible = true
	_filler()
	ResourceLoader.load_threaded_request(main_scene)
	for i in 30:
		$"Loading Bar".value += 0.1
		await get_tree().create_timer(0.1).timeout
	for i in 60:
		$"Loading Bar".value += 0.1
		await get_tree().create_timer(0.05).timeout
	for i in 10:
		$"Loading Bar".value += 0.1
		await get_tree().create_timer(0.3).timeout
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		var scene = ResourceLoader.load_threaded_get(main_scene)
		get_tree().change_scene_to_packed(scene)

var text := [
	"Replenishing Energy", 
	"Repairing Fleet", 
	"Activating Crystals",
	"Cooling Hyperdrive"
	]

func _filler():
	for i in 4:
		$%FillerText.text = text[i]
		await get_tree().create_timer(1).timeout
		for j in 3:
			$%FillerText.text += "."
			await get_tree().create_timer(1).timeout
	$%FillerText.text = "Ready...?"
