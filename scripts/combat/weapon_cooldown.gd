class_name WeaponCooldown
extends RefCounted

# Standalone cooldown timer shared by the player's weapon modes.
# All timing is in seconds, independent of rendering frame rate.
var remaining := 0.0

func advance(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)

func is_ready() -> bool:
	return remaining <= 0.0

func start(duration: float) -> void:
	remaining = maxf(0.01, duration)
