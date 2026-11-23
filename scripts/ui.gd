extends CanvasLayer

func _ready():
	pass

func _process(_delta):
	pass

func update_energy_low(energy) -> void:
	$EnergyCount.text = "Energy: " + str(energy) + " Not Enough Energy"
	await get_tree().create_timer(3).timeout
	energy = get_node("../Player").energy
	update_energy(energy)

func update_wave(wave) -> void:
	$NextWaveMessage.text = "Wave: " + str(wave)
	await get_tree().create_timer(1).timeout
	for i in 100:
		await get_tree().create_timer(0.01).timeout
		$NextWaveMessage.modulate.a += 0.01
	await get_tree().create_timer(2).timeout
	for i in 100:
		await get_tree().create_timer(0.01).timeout
		$NextWaveMessage.modulate.a -= 0.01

func update_money(money) -> void:
	$MoneyCount.text = "Money: $" + str(money)

func update_energy(energy) -> void:
	if energy == 0:
		$EnergyCount.text = "Energy: Out of Energy"
	elif energy > 0: 
		$EnergyCount.text = "Energy: " + str(energy)

func update_score(score) -> void:
	$ScoreCount.text = "Score: " + str(score)
