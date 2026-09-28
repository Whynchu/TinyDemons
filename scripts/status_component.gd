extends Node
class_name StatusComponent

const StatusTickResultScript = preload("res://scripts/status_tick_result.gd")

signal status_changed

@export var status_immunities: Array[StringName] = []

var _active: Dictionary = {}


func apply_effect(definition: StatusEffectDefinition, source_element: int) -> bool:
	if definition == null or status_immunities.has(definition.id):
		return false
	var record: Dictionary = _active.get(definition.id, {})
	if record.is_empty():
		record = {
			"definition": definition,
			"remaining": definition.duration,
			"stacks": 1,
			"source_element": source_element,
			"tick_timer": definition.tick_interval_for(1),
			"cadence_timer": definition.stun_interval_for(1),
		}
	else:
		record["definition"] = definition
		record["remaining"] = definition.duration
		record["stacks"] = mini(int(record.get("stacks", 1)) + 1, definition.maximum_stacks)
		record["source_element"] = source_element
	_active[definition.id] = record
	status_changed.emit()
	return true


func advance(delta: float) -> Array[StatusTickResult]:
	var results: Array[StatusTickResult] = []
	var step := maxf(delta, 0.0)
	if step <= 0.0:
		return results
	var changed := false
	for status_id: StringName in _active.keys():
		var record: Dictionary = _active[status_id]
		var definition := record.get("definition") as StatusEffectDefinition
		if definition == null:
			_active.erase(status_id)
			changed = true
			continue
		var elapsed := minf(step, maxf(float(record.get("remaining", 0.0)), 0.0))
		var stacks := maxi(int(record.get("stacks", 1)), 1)
		if definition.family == StatusEffectDefinition.Family.DAMAGE_OVER_TIME:
			var tick_timer := float(record.get("tick_timer", definition.tick_interval_for(stacks))) - elapsed
			var interval := definition.tick_interval_for(stacks)
			while tick_timer <= 0.0:
				var tick_result := StatusTickResultScript.new() as StatusTickResult
				tick_result.configure(
					StatusTickResultScript.Kind.DAMAGE,
					status_id,
					int(record.get("source_element", definition.element)),
					stacks,
					definition.magnitude_per_stack * float(stacks)
				)
				results.append(tick_result)
				tick_timer += interval
				changed = true
			record["tick_timer"] = tick_timer
		elif definition.family == StatusEffectDefinition.Family.PERIODIC_STUN:
			var cadence_timer := float(record.get("cadence_timer", definition.stun_interval_for(stacks))) - elapsed
			while cadence_timer <= 0.0:
				var tick_result := StatusTickResultScript.new() as StatusTickResult
				tick_result.configure(
					StatusTickResultScript.Kind.STUN_PULSE,
					status_id,
					int(record.get("source_element", definition.element)),
					stacks,
					0.0,
					definition.stun_lock_duration
				)
				results.append(tick_result)
				cadence_timer += definition.stun_interval_for(stacks)
				changed = true
			record["cadence_timer"] = cadence_timer
		var remaining := float(record.get("remaining", 0.0)) - step
		if remaining <= 0.0:
			_active.erase(status_id)
			changed = true
		else:
			record["remaining"] = remaining
			_active[status_id] = record
	if changed:
		status_changed.emit()
	return results


func clear_all() -> void:
	if _active.is_empty():
		return
	_active.clear()
	status_changed.emit()


func active_definitions() -> Array[StatusEffectDefinition]:
	var result: Array[StatusEffectDefinition] = []
	for record_value in _active.values():
		var record := record_value as Dictionary
		var definition := record.get("definition") as StatusEffectDefinition
		if definition != null:
			result.append(definition)
	return result


func strongest_active_definition() -> StatusEffectDefinition:
	var strongest: StatusEffectDefinition = null
	var strongest_stacks := -1
	for record_value in _active.values():
		var record := record_value as Dictionary
		var definition := record.get("definition") as StatusEffectDefinition
		if definition == null:
			continue
		var stacks := int(record.get("stacks", 1))
		if stacks > strongest_stacks:
			strongest = definition
			strongest_stacks = stacks
	return strongest


func stacks_for(status_id: StringName) -> int:
	var record_value: Variant = _active.get(status_id)
	if record_value == null:
		return 0
	return int((record_value as Dictionary).get("stacks", 0))


func movement_speed_multiplier() -> float:
	var result := 1.0
	for record_value in _active.values():
		var record := record_value as Dictionary
		var definition := record.get("definition") as StatusEffectDefinition
		if definition == null or definition.family != StatusEffectDefinition.Family.MOVEMENT_SLOW:
			continue
		var slow_fraction := definition.magnitude_per_stack * float(int(record.get("stacks", 1)))
		result = minf(result, maxf(definition.movement_multiplier_floor, 1.0 - slow_fraction))
	return result
