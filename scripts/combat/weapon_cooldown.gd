extends RefCounted

# Standalone cooldown timer shared by the player's weapon modes.
# All timing is in seconds, independent of rendering frame rate.
var remaining: float = 0.0

## Decrease remaining cooldown by elapsed seconds, clamped at zero; requires nonnegative delta.
func advance(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)

## Return true when no cooldown remains.
func is_ready() -> bool:
	return remaining <= 0.0

## Set remaining cooldown to the supplied duration, with a minimum of 0.01 seconds.
func start(duration: float) -> void:
	remaining = maxf(0.01, duration)
