extends Node

# A normal project scene initializes the autoloads before loading each test.
# Using --script with a custom SceneTree compiles scripts too early.
## Defer selection and startup of the requested test script.
func _ready() -> void:
	call_deferred("_start_test")

## Validate the single command-line test path, load and instantiate the test script; exit with failure for an invalid argument or script.
func _start_test() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1 or not args[0].begins_with("res://tests/") or not args[0].ends_with("_test.gd"):
		printerr("Usage: godot --headless --path . res://tests/test_runner.tscn -- res://tests/<name>_test.gd")
		get_tree().quit(1)
		return
	var test_script: Script = load(args[0]) as Script
	if test_script == null or not test_script.can_instantiate():
		printerr("FAIL: unable to load test " + args[0])
		get_tree().quit(1)
		return
	var test_node: Node = test_script.new() as Node
	if test_node == null:
		printerr("FAIL: test must extend Node")
		get_tree().quit(1)
		return
	add_child(test_node)
