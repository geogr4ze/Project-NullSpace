extends RefCounted
# Weighted draw without replacement: the order varies, never the roster.
## Choose an enemy type weighted by remaining counts using the supplied RNG; returns -1 if none remain. Requires nonnegative integer counts.
static func choose_enemy(counts: Dictionary, rng: RandomNumberGenerator) -> int:
	var remaining: int = 0
	for count: int in counts.values():
		remaining += count
	if remaining <= 0:
		return -1
	var roll: int = rng.randi_range(0, remaining - 1)
	for type: int in counts:
		roll -= int(counts[type])
		if roll < 0:
			return type
	return -1

## Return whether spawned minus defeated is below the simultaneous-enemy cap.
static func has_capacity(spawned: int, defeated: int, max_alive: int) -> bool:
	return spawned - defeated < max_alive
