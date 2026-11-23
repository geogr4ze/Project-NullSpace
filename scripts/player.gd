extends CharacterBody2D

# Misc Variables
var death = false
var energy := 100000000000000
var energy_cost: int
var screen_size: Vector2
var delay: float
var maxoverheat = 3.0

# Mobility Variables
@export var acceleration := 1.5
@export var max_speed := 450.0
var rotation_speed: float
var rotation_direction := 0.0

# Hit Point Arrays
var shield := 25
var health := 50
var hpbar
var shieldbar
var bar := [health, shield]
var flag := [true, true]
var modul := [hpbar, shieldbar] # Player Health = 0, Shield Health = 1
var vis_time := [0, 0]

# HP Variables
var healdelay := 1.5
var max_health := health
var healing_amount := 1
var hit_timer := 0.0
enum{BASIC = 0, RAILGUN, EXPLOSIVE}
var rdtype = {
	BASIC: {"damage": 1, "recov": 10},
	RAILGUN: {"damage": 25, "recov": 25},
	EXPLOSIVE: {"damage": 40, "recov": 40}
}

# Shield Variables
var shield_act := false
var shield_conf := false

func _ready():
	Signalbus.hit.connect(_on_hit)
	Signalbus.energy.connect(_on_energy)
	Signalbus.mine_hit.connect(_on_mine)
	Signalbus.player_shield.connect(_on_shield)
	Signalbus.enemy_bullet_hit.connect(_on_enemy_bullet_hit)
	Modecontrol.mode_changed.connect(_change_mode)
	energy_cost = Modecontrol.modes[0]["energy"]
	delay = Modecontrol.modes[0]["delay"]
	$PlayerSkin.animation = Modecontrol.modes[0]["skin"]
	$ShieldSkin.animation = Modecontrol.modes[0]["skin"]
	rotation_speed = Modecontrol.modes[0]["player_movement"]
	modul[0] = $%Healthbar
	modul[1] = $%Shieldbar
	for i in 2:
		modul[i].max_value = bar[i]
		modul[i].value = bar[i]
	screen_size = get_viewport_rect().size
	rotation_degrees = 90
	$HealingTimer.wait_time = healdelay
	$%Overheatbar.max_value = maxoverheat
	_on_shield()

func start(pos) -> void:
	position = pos
	show()

func _change_mode(mode) -> void:
	energy_cost = Modecontrol.modes[mode]["energy"]
	delay = Modecontrol.modes[mode]["delay"]
	$PlayerSkin.animation = Modecontrol.modes[mode]["skin"]
	$ShieldSkin.animation = Modecontrol.modes[mode]["skin"]
	if bar[1] <= 0 or m2_kill or !shield_conf:
		$ShieldSkin.frame = 7
	rotation_speed = Modecontrol.modes[mode]["player_movement"]

func _process(delta):
	handle_rotation(delta)
	handle_movement(delta)
	$Node2D.global_rotation = 0
	handle_fire_modes()
	if Modecontrol.mode == 2:
		mode2_control()
	elif Modecontrol.mode == 1:
		mode1_control()
	else:
		if Input.is_action_pressed("Fire") and Shopcontrol.autofire:
			fire()
		elif Input.is_action_just_pressed("Fire"):
			fire()
	for i in 1:
		if modul[i].modulate.a == 1.0 and bar[i] > 10:
			modul[i].modulate.a = 0.99
			vis_time[i] = 5
			bar_vis(i)
	dash_control(delta)

var dash_cooldown := false
var dashing = false

func dash_control(delta):
	if Input.is_action_just_pressed("dash") and !dash_cooldown:
		if energy >= 2 and Modecontrol.mode == 0:
			dashing = true
			energy -= 2
			dash_cooldown = true
			Signalbus.dash.emit()
			dash(delta)
			await get_tree().create_timer(3).timeout
			dash_cooldown = false

func dash(delta):
	var direction = Vector2(0, -1).rotated(rotation)
	var target_velocity = direction * 600
	velocity = velocity.lerp(target_velocity, 150 * delta)
	position = position.clamp(Vector2.ZERO, screen_size)
	move_and_slide()
	await get_tree().create_timer(0.5).timeout
	dashing = false

func _on_shield() -> void:
	if Shopcontrol.bought_shield and !shield_conf:
		shield_conf = true
		_shield_act()

func _shield_deact() -> void:
	if shield_act and bar[1] > 0:
		shield_act = false
		$ShieldSkin.play()

func _shield_act() -> void:
	if !shield_act and bar[1] > 0 and !m2_kill:
		shield_act = true
		$ShieldSkin.play_backwards()

func _on_energy() -> void:
	energy += int(25 * Shopcontrol.energy_multi)

func _on_hit() -> void:
	damage_taken(BASIC)

func _on_enemy_bullet_hit() -> void:
	damage_taken(RAILGUN)

func _on_mine() -> void:
	damage_taken(EXPLOSIVE)

func damage_taken(type) -> void:
	if bar[1] > 0 and shield_act:
		bar[1] -= rdtype[type]["damage"]
		$ShieldRegen.start()
		if bar[1] <= 0:
			$ShieldSkin.play()
			bar[1] = 0
		hp_update(1)
	else:
		bar[0] -= rdtype[type]["damage"]
		if hit_timer <= rdtype[type]["recov"]:
			hit_timer = rdtype[type]["recov"]
			$HealingTimer.start()
		hp_update(0)

func hp_update(bar_type) -> void:
	if bar_type == 1:
		_shield_act()
	if bar[bar_type] >= 0:
		modul[bar_type].modulate.a = 1.0
		modul[bar_type].value = bar[bar_type]
	elif bar[0] <= 0 and !death:
		Signalbus.player_death.emit()
		death = true

func bar_vis(bar_type) -> void:
	if flag[bar_type]:
		flag[bar_type] = false
		while vis_time[bar_type] > 0:
			vis_time[bar_type] -= 1
			await get_tree().create_timer(1.0).timeout
		for i in 99:
			if vis_time[bar_type] == 0:
				await get_tree().create_timer(0.01).timeout
				modul[bar_type].modulate.a -= 0.01
		flag[bar_type] = true

func _on_healing_timer_timeout() -> void:
	if hit_timer > 0:
		hit_timer -= 1
	elif bar[0] < max_health:
		bar[0] += healing_amount
	if bar[0] >= modul[0].max_value:
		bar[0] = modul[0].max_value
		$HealingTimer.stop()
	hp_update(0)

func _on_shield_regen_timeout() -> void:
	if bar[1] < modul[1].max_value:
		bar[1] += 5
	if bar[1] >= modul[1].max_value:
		bar[1] = modul[1].max_value
		$ShieldRegen.stop()
	hp_update(1)

# Mobility functions -------------------------------------------------------------------
func handle_rotation(delta) -> void:
	rotation_direction = Input.get_axis("turn_left", "turn_right")
	if Input.is_action_pressed("slow_turn"):
		rotation += rotation_speed * rotation_direction * delta * 0.3
	else:
		rotation += rotation_speed * rotation_direction * delta

func handle_movement(delta) -> void:
	var move_forward = Input.is_action_pressed("move_forward")
	var move_backward = Input.is_action_pressed("move_backward")
	var movement_direction = 0
	if move_forward:
		movement_direction = 1
	elif move_backward:
		movement_direction = -1
	var direction = Vector2(0, -1).rotated(rotation)
	if movement_direction != 0:
		var target_velocity = direction * max_speed * movement_direction
		velocity = velocity.lerp(target_velocity, acceleration * delta)
	else:
		velocity = velocity.lerp(Vector2.ZERO, acceleration * delta)
	position = position.clamp(Vector2.ZERO, screen_size)
	move_and_slide()

# Mode functions -------------------------------------------------------------------
func handle_fire_modes() -> void:
	if !Input.is_action_pressed("Fire"): 
		if !$ShieldSkin.is_playing() and !dashing:
			if Input.is_action_just_pressed("default_shooting"):
				Modecontrol.set_mode(0)
				$Default.polygon = Modecontrol.default_collision
				$%Overheatbar.visible = false
			if Input.is_action_just_pressed("mode1_shooting") and Shopcontrol.bought_mode1: 
				Modecontrol.set_mode(1)
				$Default.polygon = Modecontrol.mode1_collision
				$%Overheatbar.visible = false
			if Input.is_action_just_pressed("mode2_shooting") and Shopcontrol.bought_mode2:
				Modecontrol.set_mode(2)
				$Default.polygon = Modecontrol.mode2_collision
				$%Overheatbar.visible = true

var frameindex_m2 := 0
var firedelay_m2 := false
var firing_m2 := false
var m2_kill := false

func mode2_control() -> void:
	if Input.is_action_pressed("Fire") and !m2_kill:
		if bar[1] > 0:
			_shield_deact()
		if rotation_speed > 0.1:
			rotation_speed -= 0.1
		if !firedelay_m2 and !firing_m2 and frameindex_m2 < 25:
			firedelay_m2 = true
			frameindex_m2 += 1
			$PlayerSkin.frame = frameindex_m2
			frameindexdelay_m2()
		if frameindex_m2 == 25:
			if !firing_m2:
				$PlayerSkin.play("Stage2_mode2")
			firing_m2 = true
			fire()
			cooldown_m2()
	else:
		rotation_speed = 1.5
		if firing_m2:
			cooldown_m2()
		if m2_kill:
			$PlayerSkin.play("CD_mode2")
		else:
			firing_m2 = false
			frameindex_m2 = 0
			$PlayerSkin.frame = frameindex_m2
			$PlayerSkin.animation = "mode2"
		if shield_conf:
			_shield_act()

func frameindexdelay_m2() -> void:
	await get_tree().create_timer(0.05).timeout
	firedelay_m2 = false
	cooldown_m2()

func cooldown_m2() -> void:
	$%Overheatbar.value += 0.01
	await get_tree().create_timer(0.01).timeout
	if $%Overheatbar.value == maxoverheat and !m2_kill:
		firing_m2 = false
		m2_kill = true
		frameindex_m2 = 0
	if !firing_m2:
		while $%Overheatbar.value > 0 and frameindex_m2 == 0:
			$%Overheatbar.value -= 0.01
			await get_tree().create_timer(0.05).timeout
			if $%Overheatbar.value == 0:
				m2_kill = false
				if shield_conf:
					_shield_act()

var frameindex_m1 := 0
var firedelay_m1 := false

func mode1_control() -> void:
	if Input.is_action_pressed("Fire"):
		if !firedelay_m1 and frameindex_m1 < 14:
			firedelay_m1 = true
			frameindex_m1 += 1
			$PlayerSkin.frame = frameindex_m1
			frameindexdelay_m1()
		if frameindex_m1 == 14 and bullet_cooldown:
			fire()
			frameindex_m1 = 0
			$PlayerSkin.frame = frameindex_m1
			
	else:
		frameindex_m1 = 0
		$PlayerSkin.frame = frameindex_m1
		$PlayerSkin.animation = "mode1"

func frameindexdelay_m1() -> void:
	await get_tree().create_timer(0.05).timeout
	firedelay_m1 = false

var bullet_cooldown := true

func fire() -> void:
	if bullet_cooldown and energy >= energy_cost:
		energy -= energy_cost
		Signalbus.shot.emit()
		bullet_cooldown = false
		fire_delay()
	elif energy > 0 and energy < energy_cost:
		Signalbus.energy_low.emit()

func fire_delay() -> void:
	if Modecontrol.mode != 2:
		await get_tree().create_timer(delay * Shopcontrol.firerate_multi).timeout
	else:
		await get_tree().create_timer(delay).timeout
	bullet_cooldown = true
