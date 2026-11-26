extends Node

# Preserve the existing playable defaults; upgrades are optional.
var shop_open: bool = false
var shopmoney: float = 0.0
var money_multi: float = 1.0
var firerate_multi: float = 0.05
var spread: float = 0.05
var energy_multi: float = 1.0
var autofire: bool = true
var bought_mode1: bool = true
var bought_mode2: bool = true
var bought_shield: bool = true
var bought_dash: bool = false
var upgrade_levels: Dictionary = {}
const UPGRADES: Dictionary = {
	"energy": {"label": "Energy pickup", "cost": 25, "max": 3},
	"accuracy": {"label": "Default shot accuracy", "cost": 40, "max": 3},
	"reward": {"label": "Credit rewards", "cost": 60, "max": 3},
	"hull": {"label": "Hull capacity +10", "cost": 45, "max": 3},
	"shield": {"label": "Shield capacity +5", "cost": 50, "max": 3},
	"weapon": {"label": "Default shot damage +1", "cost": 100, "max": 2}
}

## Restore shop state, money, multipliers and purchased-mode defaults for a fresh run.
func reset_run() -> void:
	shop_open = false
	shopmoney = 0.0
	money_multi = 1.0
	firerate_multi = 0.05
	spread = 0.05
	energy_multi = 1.0
	autofire = true
	bought_mode1 = true
	bought_mode2 = true
	bought_shield = true
	bought_dash = false
	upgrade_levels.clear()

## Return the stored level for the upgrade ID, or zero if absent.
func upgrade_level(id: String) -> int:
	return int(upgrade_levels.get(id, 0))

## Return the next purchase cost using the registered base price and current level. Requires a known upgrade ID.
func upgrade_cost(id: String) -> int:
	return int(UPGRADES[id]["cost"]) * (upgrade_level(id) + 1)

## Return whether the shop is open, ID exists, maximum level has not been reached and funds cover the cost.
func can_buy(id: String) -> bool:
	return (
		shop_open
		and UPGRADES.has(id)
		and upgrade_level(id) < int(UPGRADES[id]["max"])
		and shopmoney >= upgrade_cost(id)
	)

## Purchase an eligible upgrade, deduct money, update its level/multiplier and emit shop money change. Returns false without purchase if ineligible.
func buy(id: String) -> bool:
	if not can_buy(id):
		return false
	shopmoney -= upgrade_cost(id)
	upgrade_levels[id] = upgrade_level(id) + 1
	match id:
		"energy": energy_multi += 0.25
		"accuracy": spread *= 0.8
		"reward": money_multi += 0.25
	Signalbus.shop_money_changed.emit()
	Signalbus.ship_upgraded.emit(id)
	return true
