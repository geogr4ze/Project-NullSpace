extends RigidBody2D

var pierce
var collision_shapes = Array()

func _ready():
	var VisibleonSN2d = get_node("Visibility")
	VisibleonSN2d.screen_exited.connect(_on_screen_exited) 
	Signalbus.enemy_hit.connect(_on_enemy_hit)
	Signalbus.shield.connect(_on_shield)
	var shape_owners = get_shape_owners()
	for shape in shape_owners:
		var this_shape = shape_owner_get_shape(shape, 0)
		collision_shapes.append(this_shape)
	$Skin.animation = Modecontrol.modes[Modecontrol.mode]["bullet_skin"]
	$CollisionShape2D.shape = collision_shapes[Modecontrol.mode]
	pierce = Modecontrol.modes[Modecontrol.mode]["pierce"]

func _on_shield(body_hit):
	if body_hit.name == name:
		queue_free()

func _on_enemy_hit(body_hit):
	if body_hit.name == name:
		pierce -= 1
		if pierce <= 0:
			queue_free()

func _on_screen_exited():
	queue_free()
