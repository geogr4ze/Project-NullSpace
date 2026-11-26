extends CharacterBody2D

# Use a local script type instead of a global class registration.
const WeaponCooldownScript = preload("res://scripts/combat/weapon_cooldown.gd")
const PlayerControlsScript = preload("res://scripts/combat/player_controls.gd")
const ShipGlowScript = preload("res://scripts/visuals/ship_glow.gd")

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
const LASER_COOL_PER_SECOND: float = 0.45
const MODE1_CHARGE_TIME: float = 1.3

# Mobility Variables
@export var acceleration: float = 1.5
@export var max_speed: float = 450.0

# Live health and shield values
var shield: int = 25
var health: int = 50
var health_vis_time: float = 5.0
var shield_vis_time: float = 5.0

# HP Variables
var healdelay: float = 1.5
var max_health: int = health
var max_shield: int = shield
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
@onready var ship_glow: ShipGlowScript = $GlowHalo
@onready var laser_beam: Node2D = $LaserBeam
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
# Keep accelerating after release until the aim almost catches the cursor.
var laser_aim_recovering: bool = false
var laser_release_elapsed: float = 0.0

## Connect damage, pickup, upgrade and weapon-mode signals; initialize the current mode and UI state.
func _ready():
	Signalbus.hit.connect(_on_hit)
	Signalbus.energy.connect(_on_energy)
	Signalbus.mine_hit.connect(_on_mine)
	Signalbus.player_shield.connect(_on_shield)
	Signalbus.ship_upgraded.connect(_on_ship_upgraded)
	Signalbus.enemy_bullet_hit.connect(_on_enemy_bullet_hit)
	Modecontrol.mode_changed.connect(_change_mode)
	_change_mode(Modecontrol.mode)
	health_bar.max_value = health
	health_bar.value = health
	shield_bar.max_value = shield
	shield_bar.value = shield
	_update_screen_size()
	get_viewport().size_changed.connect(_update_screen_size)
	healing_timer.wait_time = healdelay
	overheat_bar.max_value = maxoverheat
	overheat_bar.value = laser_heat
	wave_last_frame = maxi(0, player_skin.sprite_frames.get_frame_count(&"mode1") - 1)
	laser_last_frame = maxi(0, player_skin.sprite_frames.get_frame_count(&"mode2") - 1)
	_on_shield()

## Cache the current viewport size for movement bounds.
func _update_screen_size() -> void:
	screen_size = get_viewport_rect().size

## Place the ship at the supplied starting position and show it.
func start(pos: Vector2) -> void:
	position = pos
	show()

## Apply mode-specific energy cost, delay and visuals; clear charge state for weapons being unequipped.
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
	$Default.set_deferred("polygon", Modecontrol.modes[mode]["collision"])
	overheat_bar.visible = mode == Modecontrol.MODE2
	ship_glow.match_sprite(player_skin)
	if shield <= 0 or m2_kill or !shield_conf:
		shield_skin.frame = 7

## Update living player rotation, dash, movement, cooldown and weapon logic each physics tick.
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
	# Render one steady beam at the muzzle; moving projectiles still do damage.
	laser_beam.visible = (Modecontrol.mode == Modecontrol.MODE2
		and firing_m2 and laser_fired_this_tick and !m2_kill)

## Fade the living player's health and shield bars during rendering updates.
func _process(delta: float) -> void:
	if death:
		return
	health_vis_time = _fade_bar(health_bar, health_vis_time, delta)
	shield_vis_time = _fade_bar(shield_bar, shield_vis_time, delta)

## Decrease a bar's display timer by delta, then fade opacity when expired; returns the updated timer.
func _fade_bar(progress: ProgressBar, remaining: float, delta: float) -> float:
	if remaining > 0.0:
		return maxf(0.0, remaining - delta)
	if progress.modulate.a > 0.0:
		progress.modulate.a = maxf(0.0, progress.modulate.a - delta)
	return 0.0

var dash_cooldown: bool = false
var dashing: bool = false
var dash_time_remaining: float = 0.0
var dash_cooldown_remaining: float = 0.0

## Advance dash and cooldown timers; consume energy and start a dash when input, cooldown and default mode permit.
func dash_control(delta: float) -> void:
	dash_time_remaining = maxf(0.0, dash_time_remaining - delta)
	dash_cooldown_remaining = maxf(0.0, dash_cooldown_remaining - delta)
	dashing = dash_time_remaining > 0.0
	dash_cooldown = dash_cooldown_remaining > 0.0

	if Input.is_action_just_pressed("dash") and !dash_cooldown:
		if energy >= 2 and Modecontrol.mode == Modecontrol.DEFAULT:
			energy -= 2
			dashing = true
			dash_cooldown = true
			dash_time_remaining = DASH_DURATION
			dash_cooldown_remaining = DASH_COOLDOWN
			Signalbus.dash.emit()

## Apply the named ship upgrade to player stats and associated displays.
func _on_ship_upgraded(id: String) -> void:
	match id:
		"hull":
			max_health += 10
			health += 10
			health_bar.max_value = max_health
			_update_health_bar()
		"shield":
			max_shield += 5
			shield += 5
			shield_bar.max_value = max_shield
			_update_shield_bar()

## Activate the purchased shield configuration once when available.
func _on_shield() -> void:
	if Shopcontrol.bought_shield and !shield_conf:
		shield_conf = true
		_shield_act()

## Deactivate an active nonempty shield and play its animation.
func _shield_deact() -> void:
	if shield_act and shield > 0:
		shield_act = false
		shield_skin.play()

## Activate a nonempty inactive shield when the laser lockout permits; reverse the shield animation.
func _shield_act() -> void:
	if !shield_act and shield > 0 and !m2_kill:
		shield_act = true
		shield_skin.play_backwards()

## Add pickup energy scaled by the current shop energy multiplier.
func _on_energy() -> void:
	energy += int(25 * Shopcontrol.energy_multi)

## Apply the basic enemy contact damage type.
func _on_hit() -> void:
	damage_taken(BASIC)

## Apply railgun projectile damage.
func _on_enemy_bullet_hit() -> void:
	damage_taken(RAILGUN)

## Apply explosive mine damage.
func _on_mine() -> void:
	damage_taken(EXPLOSIVE)

## Apply damage for the registered type to shield or hull; update regeneration, visuals and health state. Ignore damage after death.
func damage_taken(type: int) -> void:
	if death:
		return
	var damage: int = rdtype[type]["damage"]
	if shield > 0 and shield_act:
		shield = maxi(0, shield - damage)
		shield_regen_timer.start()
		if shield == 0:
			shield_act = false
			shield_skin.play()
		_update_shield_bar()
	else:
		health = maxi(0, health - damage)
		hit_timer = maxf(hit_timer, float(rdtype[type]["recov"]))
		healing_timer.start()
		_update_health_bar()

## Show the updated hull health and emit player death once when health reaches zero.
func _update_health_bar() -> void:
	health_bar.modulate.a = 1.0
	health_vis_time = 5.0
	health_bar.value = health
	if health <= 0 and not death:
		death = true
		laser_beam.visible = false
		Signalbus.player_death.emit()

## Show updated shield points and attempt to activate the shield when nonempty.
func _update_shield_bar() -> void:
	shield_bar.modulate.a = 1.0
	shield_vis_time = 5.0
	shield_bar.value = shield
	if shield > 0:
		_shield_act()

## Advance the damage-delay timer or heal hull toward maximum; stop healing timer at full health and update the bar.
func _on_healing_timer_timeout() -> void:
	if hit_timer > 0:
		hit_timer -= 1
	elif health < max_health:
		health += healing_amount
	if health >= health_bar.max_value:
		health = int(health_bar.max_value)
		healing_timer.stop()
	_update_health_bar()

## Regenerate shield points toward the maximum, stop timer at full charge and update the display.
func _on_shield_regen_timeout() -> void:
	if shield < shield_bar.max_value:
		shield += 5
	if shield >= shield_bar.max_value:
		shield = int(shield_bar.max_value)
		shield_regen_timer.stop()
	_update_shield_bar()

# Mobility functions -------------------------------------------------------------------
## Aim toward the mouse, with mode-specific laser turn caps and recovery after release. delta is elapsed seconds.
func handle_rotation(delta: float) -> void:
	var cursor_heading: float = PlayerControlsScript.aim_rotation(
		global_position, get_global_mouse_position(), global_rotation
	)
	if Modecontrol.mode != Modecontrol.MODE2:
		# Default and wave weapons retain immediate cursor aiming.
		laser_aim_recovering = false
		laser_release_elapsed = 0.0
		global_rotation = cursor_heading
	elif Input.is_action_pressed("Fire") and !m2_kill:
		# Keep the laser's deliberately heavy turning during charge and fire.
		laser_aim_recovering = true
		laser_release_elapsed = 0.0
		var charge_fraction: float = charge_time_m2 / LASER_CHARGE_TIME
		var max_turn_rate: float = PlayerControlsScript.laser_turn_rate(
			charge_fraction
		)
		global_rotation = PlayerControlsScript.capped_aim_rotation(
			global_rotation, cursor_heading, max_turn_rate, delta
		)
	elif laser_aim_recovering:
		# Slowly accelerate out of the 18 degree/second firing limit rather
		# than instantly snapping to the cursor when Space is released.
		laser_release_elapsed += delta
		var return_rate: float = PlayerControlsScript.laser_release_turn_rate(
			laser_release_elapsed
		)
		global_rotation = PlayerControlsScript.capped_aim_rotation(
			global_rotation, cursor_heading, return_rate, delta
		)
		# Hand off to normal aiming only after closing the angle.
		if absf(wrapf(cursor_heading - global_rotation, -PI, PI)) <= deg_to_rad(1.0):
			global_rotation = cursor_heading
			laser_aim_recovering = false
	else:
		global_rotation = cursor_heading

## Convert WASD input from ship-local to world direction, apply movement/dash behavior and enforce playfield limits.
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
## Handle weapon-selection inputs only when not firing, dashing or playing the shield animation; respect unlocked modes.
func handle_fire_modes() -> void:
	if Input.is_action_pressed("Fire") or shield_skin.is_playing() or dashing:
		return
	if Input.is_action_just_pressed("default_shooting"):
		Modecontrol.set_mode(Modecontrol.DEFAULT)
	if Input.is_action_just_pressed("mode1_shooting") and Shopcontrol.bought_mode1:
		Modecontrol.set_mode(Modecontrol.MODE1)
	if Input.is_action_just_pressed("mode2_shooting") and Shopcontrol.bought_mode2:
		Modecontrol.set_mode(Modecontrol.MODE2)

var frameindex_m2: int = 0
var firing_m2: bool = false
var m2_kill: bool = false
var charge_time_m2: float = 0.0

## Hide the laser and reset firing, charge and animation-frame state.
func _reset_laser_charge() -> void:
	laser_beam.visible = false
	firing_m2 = false
	charge_time_m2 = 0.0
	frameindex_m2 = 0

# Heat and cooling run independently of the currently equipped weapon.
## Accumulate heat during laser firing and cool otherwise; enter overheat lockout at the limit and update cooldown visuals.
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

## Manage laser charging, firing and shield interactions, respecting overheat lockout. delta is elapsed seconds.
func mode2_control(delta: float) -> void:
	if m2_kill:
		if player_skin.animation != "CD_mode2":
			player_skin.play("CD_mode2")
		return
	if Input.is_action_pressed("Fire"):
		if shield > 0:
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

## Advance wave-shot charge using elapsed seconds, update its animation and fire when fully charged and allowed.
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

## Attempt a shot when cooldown and energy permit; returns false on either restriction, otherwise consumes energy, starts cooldown and signals a shot.
func fire() -> bool:
	if !shot_timer.is_ready():
		return false
	if energy < energy_cost:
		Signalbus.energy_low.emit()
		return false
	energy -= energy_cost
	var cooldown: float = delay
	if Modecontrol.mode != Modecontrol.MODE2:
		cooldown *= Shopcontrol.firerate_multi
	shot_timer.start(cooldown)
	Signalbus.shot.emit()
	return true
