extends RefCounted
class_name StatAllocationPolicy

## Shared permanent-stat spread rule. Vectors contain the six final stat values
## in VIT/STR/DEF/AGI/INT/MND order, including base values and allocations.

const STAT_NAMES: Array[StringName] = [&"VIT", &"STR", &"DEF", &"AGI", &"INT", &"MND"]
const MAX_BAR_TICKS := 15


static func spread_cap_for_level(level: int) -> int:
	if level <= 10:
		return 10
	if level <= 20:
		return 12
	if level <= 35:
		return 14
	return 15


static func profile_uses_ratio(base_values: Array[int]) -> bool:
	if base_values.size() != STAT_NAMES.size():
		return false
	for value in base_values:
		if value <= 0:
			return false
	return true


static func evaluate_transition(
	previous: Array[int],
	proposed: Array[int],
	level: int,
	ratio_enabled: bool
) -> Dictionary:
	if not _is_valid_vector(previous) or not _is_valid_vector(proposed):
		return {"accepted": false, "reason": "INVALID ALLOCATION"}

	var cap := spread_cap_for_level(level)
	var old_metrics := _metrics(previous, cap, ratio_enabled)
	var new_metrics := _metrics(proposed, cap, ratio_enabled)
	if bool(new_metrics["legal"]):
		return {"accepted": true, "reason": "", "metrics": new_metrics}

	var is_legacy_over_limit := int(old_metrics["spread_excess"]) > 0 or int(old_metrics["ratio_excess"]) > 0
	if is_legacy_over_limit:
		var no_rule_worsened := int(new_metrics["spread_excess"]) <= int(old_metrics["spread_excess"]) and int(new_metrics["ratio_excess"]) <= int(old_metrics["ratio_excess"])
		var old_floor := int(old_metrics["repair_floor"])
		var repair_progress := _floor_deficit(proposed, old_floor) < _floor_deficit(previous, old_floor)
		if no_rule_worsened and repair_progress:
			return {"accepted": true, "reason": "REPAIRING LEGACY ALLOCATION", "metrics": new_metrics}

	var reason := "SPREAD LIMIT %d" % cap
	if int(new_metrics["ratio_excess"]) > 0:
		reason = "LOWEST STAT MUST RISE"
	return {"accepted": false, "reason": reason, "metrics": new_metrics}


static func current_ceiling(values: Array[int], level: int, ratio_enabled: bool) -> int:
	if not _is_valid_vector(values):
		return 0
	var minimum: int = int(values.min())
	var ceiling := minimum + spread_cap_for_level(level)
	if ratio_enabled:
		ceiling = mini(ceiling, minimum * 5)
	return ceiling


static func summarize(values: Array[int], level: int, ratio_enabled: bool) -> Dictionary:
	if not _is_valid_vector(values):
		return {"legal": false, "reason": "INVALID ALLOCATION"}
	var result := _metrics(values, spread_cap_for_level(level), ratio_enabled)
	result["minimum_indices"] = minimum_stat_indices(values)
	result["ratio_enabled"] = ratio_enabled
	return result


static func minimum_stat_indices(values: Array[int]) -> Array[int]:
	var indices: Array[int] = []
	if not _is_valid_vector(values):
		return indices
	var minimum: int = int(values.min())
	for index in values.size():
		if values[index] == minimum:
			indices.append(index)
	return indices


static func _metrics(values: Array[int], spread_cap: int, ratio_enabled: bool) -> Dictionary:
	var minimum: int = int(values.min())
	var maximum: int = int(values.max())
	var spread_excess := maxi(maximum - minimum - spread_cap, 0)
	var ratio_excess := maxi(maximum - 5 * minimum, 0) if ratio_enabled else 0
	var repair_floor := maxi(maximum - spread_cap, 1)
	if ratio_enabled:
		repair_floor = maxi(repair_floor, ceili(float(maximum) / 5.0))
	return {
		"minimum": minimum,
		"maximum": maximum,
		"spread_cap": spread_cap,
		"ceiling": mini(minimum + spread_cap, minimum * 5) if ratio_enabled else minimum + spread_cap,
		"spread_excess": spread_excess,
		"ratio_excess": ratio_excess,
		"repair_floor": repair_floor,
		"repair_deficit": _floor_deficit(values, repair_floor),
		"legal": spread_excess == 0 and ratio_excess == 0,
	}


static func _floor_deficit(values: Array[int], minimum_value: int) -> int:
	var deficit := 0
	for value in values:
		deficit += maxi(minimum_value - value, 0)
	return deficit


static func _is_valid_vector(values: Array[int]) -> bool:
	if values.size() != STAT_NAMES.size():
		return false
	for value in values:
		if value < 0:
			return false
	return true
