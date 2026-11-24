extends RefCounted
# Resolve stable text IDs once, and reject invalid campaign data before play.
static func load_campaign(path: String, enemy_stats: Dictionary, expected_count: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Cannot open campaign: " + path)
		return result
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error("Invalid campaign JSON: " + json.get_error_message())
		return result
	if not json.data is Array or json.data.size() != expected_count:
		push_error("Campaign must contain %d waves" % expected_count)
		return result
	var ids: Dictionary = {}
	for type: int in enemy_stats:
		var id: String = str(enemy_stats[type].get("id", ""))
		if id.is_empty() or ids.has(id) or int(enemy_stats[type].get("threat", 0)) <= 0:
			push_error("Invalid or duplicate enemy registration: " + id)
			return result
		ids[id] = type
	var previous_threat: int = 0
	for raw: Variant in json.data:
		if not raw is Dictionary:
			push_error("Wave must be an object")
			return []
		var wave: Dictionary = raw
		var number: int = result.size() + 1
		if not _whole(wave.get("wave")) or int(wave["wave"]) != number:
			push_error("Expected sequential wave %d" % number)
			return []
		var interval: Variant = wave.get("spawn_interval")
		var cap: Variant = wave.get("max_alive")
		var roster: Variant = wave.get("enemies")
		if not _numeric(interval) or float(interval) <= 0.0 or not _whole(cap) or int(cap) <= 0 or not roster is Dictionary:
			push_error("Invalid spawn settings for wave %d" % number)
			return []
		var counts: Dictionary = {}
		var total: int = 0
		var threat: int = 0
		for id: String in roster:
			var count: Variant = roster[id]
			if not ids.has(id) or not _whole(count) or int(count) <= 0:
				push_error("Invalid enemy '%s' in wave %d" % [id, number])
				return []
			var type: int = ids[id]
			counts[type] = int(count)
			total += int(count)
			threat += int(count) * int(enemy_stats[type]["threat"])
		if total == 0 or int(cap) > total or not _whole(wave.get("threat")) or int(wave["threat"]) != threat or threat <= previous_threat:
			push_error("Invalid total, cap or difficulty in wave %d" % number)
			return []
		result.append({"wave": number, "counts": counts, "total": total,
			"threat": threat, "spawn_interval": float(interval), "max_alive": int(cap)})
		previous_threat = threat
	return result

static func _numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _whole(value: Variant) -> bool:
	return _numeric(value) and floorf(float(value)) == float(value)
