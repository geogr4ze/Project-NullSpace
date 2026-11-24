extends CharacterBody2D

# Misc Variables
var death = false
var energy := 100000000000000
var energy_cost: int
var screen_size: Vector2
var delay: float
var maxoverheat = 3.0
const DASH_DURATION := 0.5
const DASH_COOLDOWN := 3.0
const DASH_SPEED := 600.0
const LASER_CHARGE_TIME := 1.25
const LASER_HEAT_PER_SECOND := 1.2
const LASER_COOL_PER_SECOND := 1.0

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
var modul := [hpbar, shieldbar] # Player Health = 0, Shield Health = 1
var vis_time := [5.0, 5.0]

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
	$%Overheatbar.value = laser_heat
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

func _physics_process(delta: float) -> void:
	if death:
		return
	handle_rotation(delta)
	dash_control(delta)
	handle_movement(delta)
	$Node2D.global_rotation = 0
	# Combat updates at the fixed physics tick, independent of render FPS.
	shot_cooldown_remaining = maxf(0.0, shot_cooldown_remaining - delta)
	bullet_cooldown = shot_cooldown_remaining <= 0.0
	handle_fire_modes()
	laser_fired_this_tick = false
	if Modecontrol.mode == Modecontrol.MODE2:
		mode2_control(delta)
	elif Modecontrol.mode == Modecontrol.MODE1:
		mode1_control(delta)
	else:
		if Input.is_action_pressed("Fire") and Shopcontrol.autofire:
			fire()
		elif Input.is_action_just_pressed("Fire"):
			fire()
	_update_laser_heat(delta)

func _process(delta: float) -> void:
	if death:
		return
	for i in modul.size():
		if vis_time[i] > 0.0:
			vis_time[i] = maxf(0.0, vis_time[i] - delta)
		elif modul[i].modulate.a > 0.0:
			modul[i].modulate.a = maxf(0.0, modul[i].modulate.a - delta)

var dash_cooldown := false
var dashing := false
var dash_time_remaining := 0.0
var dash_cooldown_remaining := 0.0

func dash_control(delta: float) -> void:
	dash_time_remaining = maxf(0.0, dash_time_remaining - delta)
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	dashing = dash_time_remaining > 0.0
	dash_cooldown = dash_cooldown_remaining > 0.0

	if Input.is_action_just_pressed("dash") and !dash_cooldown:
		if energy >= 2 and Modecontrol.mode == 0:
			energy -= 2
			dashing = true
			dash_cooldown = true
			dash_time_remaining = DASH_DURATION
			dash_cooldown_remaining = DASH_COOLDOWN
			Signalbus.dash.emit()

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

func damage_taken(type: int) -> void:
	if death:
		return
	var damage: int = rdtype[type]["damage"]
	if bar[1] > 0 and shield_act:
		bar[1] = maxi(0, bar[1] - damage)
		$ShieldRegen.start()
		if bar[1] == 0:
			shield_act = false
			$ShieldSkin.play()
		hp_update(1)
	else:
		bar[0] = maxi(0, bar[0] - damage)
		hit_timer = maxf(hit_timer, float(rdtype[type]["recov"]))
		$HealingTimer.start()
		hp_update(0)

func hp_update(bar_type: int) -> void:
	modul[bar_type].modulate.a = 1.0
	vis_time[bar_type] = 5.0
	modul[bar_type].value = bar[bar_type]
	if bar_type == 1 and bar[1] > 0:
		_shield_act()
	if bar[0] <= 0 and !death:
		death = true
		Signalbus.player_death.emit()

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

func handle_movement(delta: float) -> void:
	var thrust := Input.get_axis("move_backward", "move_forward")
	var direction := Vector2.UP.rotated(rotation)
	if dashing:
		velocity = direction * DASH_SPEED
	else:
		var target_velocity := direction * thrust * max_speed
		velocity = velocity.lerp(target_velocity, clampf(acceleration * delta, 0.0, 1.0))
	move_and_slide()
	position = position.clamp(Vector2.ZERO, screen_size)

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
var firing_m2 := false
var m2_kill := false
var charge_time_m2 := 0.0
var laser_heat := 0.0
var laser_fired_this_tick := false

func mode2_control(delta: float) -> void:
	if Input.is_action_pressed("Fire") and !m2_kill:
		if bar[1] > 0:
			_shield_deact()
		rotation_speed = maxf(0.1, rotation_speed - 6.0 * delta)
		charge_time_m2 = minf(LASER_CHARGE_TIME, charge_time_m2 + delta)
		frameindex_m2 = mini(25, int(charge_time_m2 / 0.05))
		if !firing_m2:
			$PlayerSkin.frame = frameindex_m2
		if charge_time_m2 >= LASER_CHARGE_TIME:
			if !firing_m2:
				$PlayerSkin.play("Stage2_mode2")
			firing_m2 = true
			laser_fired_this_tick = fire()
		return

	rotation_speed = Modecontrol.modes[Modecontrol.mode]["player_movement"]
	firing_m2 = false
	charge_time_m2 = 0.0
	frameindex_m2 = 0
	if m2_kill:
		if $PlayerSkin.animation != "CD_mode2":
			$PlayerSkin.play("CD_mode2")
	else:
		$PlayerSkin.animation = "mode2"
		$PlayerSkin.frame = 0
	if shield_conf and !m2_kill:
		_shield_act()

# Heat uses its own floating-point value instead of the ProgressBar's stepped
# display value, and cools even when mode 3 is no longer selected.
func _update_laser_heat(delta: float) -> void:
	if laser_fired_this_tick:
		laser_heat = minf(maxoverheat, laser_heat + LASER_HEAT_PER_SECOND * delta)
		if laser_heat >= maxoverheat:
			m2_kill = true
			firing_m2 = false
			charge_time_m2 = 0.0
			frameindex_m2 = 0
	else:
		laser_heat = maxf(0.0, laser_heat - LASER_COOL_PER_SECOND * delta)

	if m2_kill and laser_heat <= 0.0:
		m2_kill = false
		if shield_conf:
			_shield_act()
	$%Overheatbar.value = laser_heat

var frameindex_m1 := 0
var charge_time_m1 := 0.0

func mode1_control(delta: float) -> void:
	if Input.is_action_pressed("Fire"):
		charge_time_m1 = minf(0.7, charge_time_m1 + delta)
		frameindex_m1 = mini(14, int(charge_time_m1 / 0.05))
		$PlayerSkin.frame = frameindex_m1
		if frameindex_m1 >= 14 and fire():
			charge_time_m1 = 0.0
			frameindex_m1 = 0
			$PlayerSkin.frame = 0
	else:
		charge_time_m1 = 0.0
		frameindex_m1 = 0
		$PlayerSkin.frame = 0
		$PlayerSkin.animation = "mode1"

var bullet_cooldown := true
var shot_cooldown_remaining := 0.0

func fire() -> bool:
	if !bullet_cooldown:
		return false
	if energy < energy_cost:
		Signalbus.energy_low.emit()
		return false
	energy -= energy_cost
	bullet_cooldown = false
	var cooldown := delay
	if Modecontrol.mode != 2:
		cooldown *= Shopcontrol.firerate_multi
	shot_cooldown_remaining = maxf(cooldown, 0.01)
	Signalbus.shot.emit()
	return true
