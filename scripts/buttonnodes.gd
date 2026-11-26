extends Node2D

var auto_start: bool = false
var autoplay_generation: int = 0
var shop_available: bool = true
var ended: bool = false
var click_scale: Vector2 = Vector2(0.005, 0.005)
const SHOP_SCENE: PackedScene = preload("res://scenes/shop.tscn")
const HOVER_DISTANCE: float = 10.0
const HOVER_DURATION: float = 0.1
var tab_bases: Dictionary = {}
var tab_shown: Dictionary = {}
var tab_hovered: Dictionary = {}
var tab_tweens: Dictionary = {}
var click_tweens: Dictionary = {}
var click_bases: Dictionary = {}
var play: Texture2D = preload("res://assets/ui/buttons/Play + autoplay Skins-1.png.png")
var pause: Texture2D = preload("res://assets/ui/buttons/Play + autoplay Skins-3.png.png")

## Connect wave/test/game-over signals and initialize tab/button animation state.
func _ready() -> void:
	Signalbus.wave_complete.connect(on_wave_complete)
	Signalbus.test_mode.connect(on_test)
	Signalbus.game_over.connect(_on_game_over)
	for tab: Control in [$Play_PauseTab, $AutoPlayTab, $ShopTab]:
		tab_bases[tab] = tab.position
		tab_shown[tab] = true
		tab_hovered[tab] = false
	for button: Button in [$%Button1, $%Button2, $%Button3]:
		click_bases[button] = button.scale

## Handle keyboard commands for wave, autoplay and shop controls while the run is active and shop closed.
func _process(_delta: float) -> void:
	if ended or Shopcontrol.shop_open:
		return
	if Input.is_action_just_pressed("auto_next_wave"):
		autoplay_control()
	if Input.is_action_just_pressed("next_wave"):
		play_pause_control()
	if Input.is_action_just_pressed("shop"):
		shop_control()

## Return whether controls may start the next wave.
func _can_start() -> bool:
	return not ended and not Shopcontrol.shop_open and Wavecontrol.can_start_wave()

## Toggle manual play/autoplay state and start a wave when permitted; updates controls and cancellation generation.
func play_pause_control() -> void:
	if ended or Shopcontrol.shop_open:
		return
	if auto_start:
		clicked($%Button1)
		auto_start = false
		autoplay_generation += 1
		$%Button1.icon = play
		if Wavecontrol.wave_active:
			_set_controls(false, false, false)
		else:
			_set_controls(true, true, true)
	elif _can_start():
		clicked($%Button1)
		_set_controls(false, false, false)
		Wavecontrol.spawn_enemy()

## Enable autoplay and start an eligible wave; ignores repeated or unavailable requests.
func autoplay_control() -> void:
	if auto_start or not _can_start():
		return
	clicked($%Button2)
	auto_start = true
	$%Button1.icon = pause
	_set_controls(true, false, false)
	Wavecontrol.spawn_enemy()

## Open the upgrade shop only between eligible waves; instantiate the shop scene and update shared state.
func shop_control() -> void:
	if ended or not shop_available or Shopcontrol.shop_open or Wavecontrol.wave_active:
		return
	var shop: Node2D = SHOP_SCENE.instantiate() as Node2D
	if shop == null:
		push_error("Shop scene could not be instantiated.")
		return
	Shopcontrol.shop_open = true
	clicked($%Button3)
	get_parent().add_child(shop)
	get_tree().paused = true

## Update visibility, shop availability and disabled states of the three controls.
func _set_controls(show_play: bool, show_auto: bool, show_shop: bool) -> void:
	shop_available = show_shop
	_set_shown($Play_PauseTab, show_play)
	_set_shown($AutoPlayTab, show_auto)
	_set_shown($ShopTab, show_shop)
	$%Button1.disabled = not show_play
	$%Button2.disabled = not show_auto
	$%Button3.disabled = not show_shop

## Set the tab's intended visibility and animate toward its corresponding position.
func _set_shown(tab: Control, shown: bool) -> void:
	tab_shown[tab] = shown
	if not shown:
		tab_hovered[tab] = false
	_move_tab(tab, 0.5 if tab == $Play_PauseTab else 1.0)

## Update hover state for a shown tab and animate its position.
func _set_hovered(tab: Control, hovered: bool) -> void:
	tab_hovered[tab] = hovered and bool(tab_shown.get(tab, false))
	_move_tab(tab, HOVER_DURATION)

## Animate an initialized tab toward its hidden, base or hovered position using the given duration.
func _move_tab(tab: Control, duration: float) -> void:
	var direction: Vector2 = Vector2.RIGHT if tab == $ShopTab else Vector2.UP
	var distance: float = 50.0 if tab == $Play_PauseTab else 100.0
	var target: Vector2 = tab_bases[tab]
	if not bool(tab_shown[tab]):
		target -= direction * distance
	elif bool(tab_hovered[tab]):
		target += direction * HOVER_DISTANCE
	if tab_tweens.has(tab):
		var previous: Tween = tab_tweens[tab]
		if previous.is_valid():
			previous.kill()
	var tween: Tween = create_tween()
	tween.tween_property(tab, "position", target, duration)
	tab_tweens[tab] = tween

## Animate button scale on click, replacing any existing click tween.
func clicked(button: Control) -> void:
	if click_tweens.has(button):
		var previous: Tween = click_tweens[button]
		if previous.is_valid():
			previous.kill()
	var original: Vector2 = click_bases[button]
	var tween: Tween = create_tween()
	tween.tween_property(button, "scale", original - click_scale * 10.0, 0.1)
	tween.tween_property(button, "scale", original, 0.1)
	click_tweens[button] = tween

## Route play/pause button presses to the corresponding control action.
func _on_button_1_pressed() -> void:
	play_pause_control()
## Route autoplay button presses to the corresponding control action.
func _on_button_2_pressed() -> void:
	autoplay_control()
## Route shop button presses to the corresponding control action.
func _on_button_3_pressed() -> void:
	shop_control()
## Enable play/pause tab hover animation.
func _on_button_1_mouse_entered() -> void:
	_set_hovered($Play_PauseTab, true)
## Clear play/pause tab hover animation.
func _on_button_1_mouse_exited() -> void:
	_set_hovered($Play_PauseTab, false)
## Enable autoplay tab hover animation.
func _on_button_2_mouse_entered() -> void:
	_set_hovered($AutoPlayTab, true)
## Clear autoplay tab hover animation.
func _on_button_2_mouse_exited() -> void:
	_set_hovered($AutoPlayTab, false)
## Enable shop tab hover animation.
func _on_button_3_mouse_entered() -> void:
	_set_hovered($ShopTab, true)
## Clear shop tab hover animation.
func _on_button_3_mouse_exited() -> void:
	_set_hovered($ShopTab, false)

## Handle completion of a nonfinal wave; in autoplay, wait two seconds and start only if the generation and state remain valid.
func on_wave_complete(completed_wave: int) -> void:
	if ended or completed_wave >= Wavecontrol.max_wave:
		return
	if auto_start:
		var generation: int = autoplay_generation
		await get_tree().create_timer(2.0, false).timeout
		if generation == autoplay_generation and auto_start and _can_start():
			Wavecontrol.spawn_enemy()
	else:
		_set_controls(true, true, true)

## Mark controls ended, cancel autoplay and hide controls.
func _on_game_over(_won: bool) -> void:
	ended = true
	auto_start = false
	autoplay_generation += 1
	shop_available = false
	hide()

## Hide controls and disable normal wave/shop interaction for test mode.
func on_test() -> void:
	ended = true
	shop_available = false
	hide()
