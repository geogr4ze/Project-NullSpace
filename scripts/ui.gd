extends CanvasLayer

const PlayerShipScript = preload("res://scripts/player.gd")

var wave_tween: Tween
var energy_warning_tween: Tween

@onready var player: PlayerShipScript = $"../Player"
@onready var wave_label: Label = $NextWaveMessage

## Show a temporary insufficient-energy message and replace any previous warning tween.
func update_energy_low(energy: int) -> void:
	$EnergyCount.text = "Energy: " + str(energy) + " Not Enough Energy"
	if energy_warning_tween != null and energy_warning_tween.is_valid():
		energy_warning_tween.kill()
	energy_warning_tween = create_tween()
	energy_warning_tween.tween_interval(3.0)
	energy_warning_tween.tween_callback(_restore_energy_label)

## Restore normal energy text from the live player when available.
func _restore_energy_label() -> void:
	if is_instance_valid(player):
		update_energy(player.energy)

## Display the current wave out of the campaign maximum, replacing the previous fade animation.
func update_wave(wave: int) -> void:
	wave_label.text = "Wave: %d / %d" % [wave, Wavecontrol.max_wave]
	if wave_tween != null and wave_tween.is_valid():
		wave_tween.kill()
	wave_label.modulate.a = 0.0
	wave_tween = create_tween()
	wave_tween.tween_property(wave_label, "modulate:a", 1.0, 1.0)
	wave_tween.tween_interval(2.0)
	wave_tween.tween_property(wave_label, "modulate:a", 0.0, 1.0)

## Format the supplied balance as whole-dollar HUD text.
func update_money(money: float) -> void:
	$MoneyCount.text = "Money: $%d" % int(money)

## Display energy remaining, or an out-of-energy message for nonpositive values.
func update_energy(energy: int) -> void:
	if energy <= 0:
		$EnergyCount.text = "Energy: Out of Energy"
	else:
		$EnergyCount.text = "Energy: " + str(energy)

## Replace HUD score text with the supplied total.
func update_score(score: int) -> void:
	$ScoreCount.text = "Score: " + str(score)
