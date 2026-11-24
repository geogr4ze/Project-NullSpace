extends CharacterBody2D

# Use a local script type instead of a global class registration.
const WeaponCooldownScript = preload("res://scripts/combat/weapon_cooldown.gd")
const PlayerControlsScript = preload("res://scripts/combat/player_controls.gd")

# Misc Variables
var death: bool = false
var energy: int = 100000000000000
var energy_cost: int
var screen_size: Vector2
var delay: float
var maxoverheat: float = 3.0
const DASH_DURATION: float = 0.5
const DASH_COOLDOWN: float = 3.0
const DASH_SPEED: float = 600.0
const LASER_CHARGE_TIME: float = 1.25
const LASER_HEAT_PER_SECOND: float = 1.4
const LASER_COOL_PER_SECOND: float = 0.3
const MODE1_CHARGE_TIME: float = 1.3

# Mobility Variables
@export var acceleration: float = 1.5
@export var max_speed: float = 450.0

# Hit Point Arrays
var shield: int = 25
var health: int = 50
var hpbar: ProgressBar
var shieldbar: ProgressBar
var bar: Array[int] = [health, shield]
var modul: Array[ProgressBar] = [hpbar, shieldbar] # Player Health = 0, Shield Health = 1
var vis_time: Array[float] = [5.0, 5.0]

# HP Variables
var healdelay: float = 1.5
var max_health: int = health
var healing_amount: int = 1
var hit_timer: float = 0.0
enum{BASIC = 0, RAILGUN, EXPLOSIVE}
var rdtype: Dictionary = {
	BASIC: {"damage": 1, "recov": 10},
	RAILGUN: {"damage": 25, "recov": 25},
	EXPLOSIVE: {"damage": 40, "recov": 40}
}

# Shield Variables
var shield_act: bool = false
var shield_conf: bool = false

@onready var player_skin: AnimatedSprite2D = $PlayerSkin
@onready var shield_skin: AnimatedSprite2D = $ShieldSkin
@onready var overheat_bar: ProgressBar = $%Overheatbar
@onready var health_bar: ProgressBar = $%Healthbar
@onready var shield_bar: ProgressBar = $%Shieldbar
@onready var ui_anchor: Node2D = $Node2D
@onready var healing_timer: Timer = $HealingTimer
@onready var shield_regen_timer: Timer = $ShieldRegen
var wave_last_frame: int = 0
var laser_last_frame: int = 0
var laser_heat: float = 0.0
var laser_fired_this_tick: bool = false

func _ready():
	Signalbus.hit.connect(_on_hit)
	Signalbus.energy.connect(_on_energy)
	Signalbus.mine_hit.connect(_on_mine)
	Signalbus.player_shield.connect(_on_shield)
	Signalbus.enemy_bullet_hit.connect(_on_enemy_bullet_hit)
	Modecontrol.mode_changed.connect(_change_mode)
	energy_cost = Modecontrol.modes[0]["energy"]
	delay = Modecontrol.modes[0]["delay"]
	player_skin.animation = Modecontrol.modes[0]["skin"]
	shield_skin.animation = Modecontrol.modes[0]["skin"]
	modul[0] = health_bar
	modul[1] = shield_bar
	for i: int in 2:
		modul[i].max_value = bar[i]
		modul[i].value = bar[i]
	_update_screen_size()
	get_viewport().size_changed.connect(_update_screen_size)
	healing_timer.wait_time = healdelay
	overheat_bar.max_value = maxoverheat
	overheat_bar.value = laser_heat
	wave_last_frame = maxi(0, player_skin.sprite_frames.get_frame_count(&"mode1") - 1)
	laser_last_frame = maxi(0, player_skin.sprite_frames.get_frame_count(&"mode2") - 1)
	_on_shield()

func _update_screen_size() -> void:
	screen_size = get_viewport_rect().size

func start(pos: Vector2) -> void:
	position = pos
	show()

func _change_mode(mode: int) -> void:
	if mode != Modecontrol.MODE1:
		charge_time_m1 = 0.0
		frameindex_m1 = 0
	if mode != Modecontrol.MODE2:
		_reset_laser_charge()
	energy_cost = Modecontrol.modes[mode]["energy"]
	delay = Modecontrol.modes[mode]["delay"]
	player_skin.animation = Modecontrol.modes[mode]["skin"]
	shield_skin.animation = Modecontrol.modes[mode]["skin"]
	if bar[1] <= 0 or m2_kill or !shield_conf:
		shield_skin.frame = 7

func _physics_process(delta: float) -> void:
	if death:
		return
	handle_rotation(delta)
	dash_control(delta)
	handle_movement(delta)
	ui_anchor.global_rotation = 0
	shot_timer.advance(delta)
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
	for i: int in modul.size():
		if vis_time[i] > 0.0:
			vis_time[i] = maxf(0.0, vis_time[i] - delta)
		elif modul[i].modulate.a > 0.0:
			modul[i].modulate.a = maxf(0.0, modul[i].modulate.a - delta)

var dash_cooldown: bool = false
var dashing: bool = false
var dash_time_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0

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
		shield_skin.play()

func _shield_act() -> void:
	if !shield_act and bar[1] > 0 and !m2_kill:
		shield_act = true
		shield_skin.play_backwards()

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
		shield_regen_timer.start()
		if bar[1] == 0:
			shield_act = false
			shield_skin.play()
		hp_update(1)
	else:
		bar[0] = maxi(0, bar[0] - damage)
		hit_timer = maxf(hit_timer, float(rdtype[type]["recov"]))
		healing_timer.start()
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
		bar[0] = int(modul[0].max_value)
		healing_timer.stop()
	hp_update(0)

func _on_shield_regen_timeout() -> void:
	if bar[1] < modul[1].max_value:
		bar[1] += 5
	if bar[1] >= modul[1].max_value:
		bar[1] = int(modul[1].max_value)
		shield_regen_timer.stop()
	hp_update(1)

# Mobility functions -------------------------------------------------------------------
func handle_rotation(_delta: float) -> void:
	# Mouse aims the local-UP-facing sprite and its muzzle. Keyboard turning
	# is disabled; switching weapons and charging the laser never limit aim.
	global_rotation = PlayerControlsScript.aim_rotation(
		global_position, get_global_mouse_position(), global_rotation
	)

func handle_movement(delta: float) -> void:
	# W/S move forward/back relative to the cursor-facing ship; A/D strafe.
	var input_vector: Vector2 = Input.get_vector(
		"strafe_left", "strafe_right", "move_forward", "move_backward"
	)
	var movement_direction: Vector2 = PlayerControlsScript.relative_move_direction(
		input_vector, global_rotation
	)
	if dashing:
		# Preserve existing E dash: it boosts forward in the aim direction.
		velocity = Vector2.UP.rotated(global_rotation) * DASH_SPEED
	else:
		var target_velocity: Vector2 = movement_direction * max_speed
		velocity = velocity.lerp(
			target_velocity, clampf(acceleration * delta, 0.0, 1.0)
		)
	move_and_slide()
	position = position.clamp(Vector2.ZERO, screen_size)

# Mode functions -------------------------------------------------------------------
func handle_fire_modes() -> void:
	if !Input.is_action_pressed("Fire"): 
		if !shield_skin.is_playing() and !dashing:
			if Input.is_action_just_pressed("default_shooting"):
				Modecontrol.set_mode(0)
				$Default.polygon = Modecontrol.default_collision
				overheat_bar.visible = false
			if Input.is_action_just_pressed("mode1_shooting") and Shopcontrol.bought_mode1: 
				Modecontrol.set_mode(1)
				$Default.polygon = Modecontrol.mode1_collision
				overheat_bar.visible = false
			if Input.is_action_just_pressed("mode2_shooting") and Shopcontrol.bought_mode2:
				Modecontrol.set_mode(2)
				$Default.polygon = Modecontrol.mode2_collision
				overheat_bar.visible = true

var frameindex_m2: int = 0
var firing_m2: bool = false
var m2_kill: bool = false
var charge_time_m2: float = 0.0

func _reset_laser_charge() -> void:
	firing_m2 = false
	charge_time_m2 = 0.0
	frameindex_m2 = 0

# Heat and cooling run independently of the currently equipped weapon.
func _update_laser_heat(delta: float) -> void:
	if laser_fired_this_tick:
		laser_heat = minf(maxoverheat, laser_heat + LASER_HEAT_PER_SECOND * delta)
		if laser_heat >= maxoverheat:
			m2_kill = true
			_reset_laser_charge()
			if Modecontrol.mode == Modecontrol.MODE2:
				player_skin.play("CD_mode2")
	else:
		laser_heat = maxf(0.0, laser_heat - LASER_COOL_PER_SECOND * delta)
	if m2_kill and laser_heat <= 0.0:
		m2_kill = false
		_reset_laser_charge()
		if Modecontrol.mode == Modecontrol.MODE2:
			player_skin.animation = "mode2"
			player_skin.frame = 0
		if shield_conf:
			_shield_act()
	overheat_bar.value = laser_heat

func mode2_control(delta: float) -> void:
	if m2_kill:
		if player_skin.animation != "CD_mode2":
			player_skin.play("CD_mode2")
		return
	if Input.is_action_pressed("Fire"):
		if bar[1] > 0:
			_shield_deact()
		charge_time_m2 = minf(LASER_CHARGE_TIME, charge_time_m2 + delta)
		frameindex_m2 = mini(laser_last_frame,
			roundi(charge_time_m2 / LASER_CHARGE_TIME * float(laser_last_frame)))
		if !firing_m2:
			player_skin.frame = frameindex_m2
		if charge_time_m2 >= LASER_CHARGE_TIME:
			if !firing_m2:
				player_skin.play("Stage2_mode2")
			firing_m2 = true
			laser_fired_this_tick = fire()
		return
	_reset_laser_charge()
	player_skin.animation = "mode2"
	player_skin.frame = 0
	if shield_conf:
		_shield_act()

var frameindex_m1: int = 0
var charge_time_m1: float = 0.0

func mode1_control(delta: float) -> void:
	if Input.is_action_pressed("Fire"):
		charge_time_m1 = minf(MODE1_CHARGE_TIME, charge_time_m1 + delta)
		frameindex_m1 = mini(wave_last_frame,
			roundi(charge_time_m1 / MODE1_CHARGE_TIME * float(wave_last_frame)))
		player_skin.frame = frameindex_m1
		# Fire based on elapsed time, never on an animation frame index.
		if charge_time_m1 >= MODE1_CHARGE_TIME and fire():
			charge_time_m1 = 0.0
			frameindex_m1 = 0
			player_skin.frame = 0
	else:
		charge_time_m1 = 0.0
		frameindex_m1 = 0
		player_skin.frame = 0
		player_skin.animation = "mode1"

var shot_timer: WeaponCooldownScript = WeaponCooldownScript.new()

func fire() -> bool:
	if !shot_timer.is_ready():
		return false
	if energy < energy_cost:
		Signalbus.energy_low.emit()
		return false
	energy -= energy_cost
	var cooldown: float = delay
	if Modecontrol.mode != 2:
		cooldown *= Shopcontrol.firerate_multi
	shot_timer.start(cooldown)
	Signalbus.shot.emit()
	return true
