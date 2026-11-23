extends Node

var default_collision = PackedVector2Array([Vector2(-30, -21), Vector2(-30, 30), Vector2(-26, 30), Vector2(-26, 27), Vector2(-23, 27), Vector2(-23, 11), Vector2(-11, 11), Vector2(-11, 14), Vector2(-5, 14), Vector2(-5, 24), Vector2(-2, 24), Vector2(-2, 36), Vector2(2, 36), Vector2(2, 24), Vector2(5, 24), Vector2(5, 14), Vector2(11, 14), Vector2(11, 11), Vector2(23, 11), Vector2(23, 27), Vector2(26, 27), Vector2(26, 30), Vector2(30, 30), Vector2(30, -21), Vector2(27, -21), Vector2(27, -27), Vector2(24, -27), Vector2(24, -30), Vector2(21, -30), Vector2(21, -33), Vector2(17, -33), Vector2(17, -36), Vector2(10, -36), Vector2(10, -32), Vector2(23, -16), Vector2(23, -8), Vector2(20, -8), Vector2(20, -2), Vector2(11, -2), Vector2(5, 1), Vector2(5, -20), Vector2(0, -25), Vector2(-5, -20), Vector2(-5, 1), Vector2(-11, -2), Vector2(-20, -2), Vector2(-20, -8), Vector2(-23, -8), Vector2(-23, -17), Vector2(-10, -32), Vector2(-10, -36), Vector2(-17, -36), Vector2(-17, -33), Vector2(-21, -33), Vector2(-21, -30), Vector2(-24, -30), Vector2(-24, -27), Vector2(-27, -27), Vector2(-27, -21)])
var mode1_collision = PackedVector2Array([Vector2(-70, 17), Vector2(-70, 24), Vector2(-67, 24), Vector2(-67, 27), Vector2(-64, 27), Vector2(-64, 30), Vector2(-61, 30), Vector2(-61, 33), Vector2(-55, 33), Vector2(-55, 36), Vector2(-5.17707, 36), Vector2(-5, 39), Vector2(5, 39), Vector2(5, 36), Vector2(55, 36), Vector2(55, 33), Vector2(61, 33), Vector2(61, 30), Vector2(64, 30), Vector2(64, 27), Vector2(67, 27), Vector2(67, 24), Vector2(70, 24), Vector2(70, 17), Vector2(63, 17), Vector2(63, 20), Vector2(60, 20), Vector2(60, 23), Vector2(54, 23), Vector2(54, 26), Vector2(42, 26), Vector2(42, 23), Vector2(36, 23), Vector2(14, 1), Vector2(5, 1), Vector2(5, -20), Vector2(0, -24), Vector2(-5, -20), Vector2(-5, 1), Vector2(-14, 1), Vector2(-36, 23), Vector2(-42, 23), Vector2(-42, 26), Vector2(-54, 26), Vector2(-54, 23), Vector2(-60, 23), Vector2(-60, 20), Vector2(-63, 20), Vector2(-63, 17)])
var mode2_collision = PackedVector2Array([Vector2(-2, 33), Vector2(2, 33), Vector2(2, 21), Vector2(5, 21), Vector2(5, 11), Vector2(14, 27), Vector2(17, 30), Vector2(21, 30), Vector2(21, -20), Vector2(27, -20), Vector2(27, -36), Vector2(20, -52), Vector2(-20, -52), Vector2(-27, -36), Vector2(-27, -20), Vector2(-21, -20), Vector2(-21, 30), Vector2(-17, 30), Vector2(-14, 27), Vector2(-5, 11), Vector2(-5, 21), Vector2(-2, 21),])
var mode = DEFAULT
signal mode_changed(mode)

enum{DEFAULT = 0, MODE1, MODE2}
var modes = {
	DEFAULT: {"delay": 0.5,"bullet_speed": -1000,"energy": 3,"player_movement": 2, "pierce": 2, "skin": "default", "bullet_skin": "bullet"}, 
	MODE1: {"delay": 1.5,"bullet_speed": -750,"energy": 8,"player_movement": 1.5, "pierce": 10, "skin": "mode1", "bullet_skin": "wave"},
	MODE2: {"delay": 0.005,"bullet_speed": -8000,"energy": 15,"player_movement": 1.5, "pierce": 1000000, "skin": "mode2", "bullet_skin": "laser"}
}

func set_mode(mode_number) -> void:
	mode = mode_number
	mode_changed.emit(mode)
