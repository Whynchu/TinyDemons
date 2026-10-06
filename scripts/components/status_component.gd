extends Node
class_name StatusComponent

const StatusTickResultScript = preload("res://scripts/content/status_tick_result.gd")
const StatusRecordScript = preload("res://scripts/content/status_record.gd")

signal status_changed
signal suppression_changed(innate_id: StringName, suppressor_id: StringName, is_suppressed: bool)
signal transmission_received(status_id: StringName, from_actor: Node)

@export var status_immunities: Array[StringName] = []
@export var health_component: HealthComponent

var _active: Dictionary[StringName, StatusRecord] = {}
var innate_status_id: StringName = &""
var _innate_definition: StatusEffectDefinition
var movement_lock_resistance_check: Callable = Callable()


func configure_innate(status_id: StringName) -> void:
	if not innate_status_id.is_empty():
		_active.erase(innate_status_id)
	innate_status_id = status_id
	_innate_definition = ElementCatalog.status_effect_for_id(status_id) if not status_id.is_empty() else null
	_install_innate_record()
	_recompute_suppression(false)
	status_changed.emit()


func set_movement_lock_resistance_check(check: Callable) -> void:
	movement_lock_resistance_check = check


func reset_for_spawn() -> void:
	_active.clear()
	_install_innate_record()
	_recompute_suppression(false)
	status_changed.emit()


func _install_innate_record() -> void:
	if innate_status_id.is_empty() or _innate_definition == null or status_immunities.has(innate_status_id):
		return
	var record := StatusRecordScript.new() as StatusRecord
	record.configure(_innate_definition, StatusRecord.Origin.INNATE, INF, 1, _innate_definition.element)
	_active[innate_status_id] = record


func apply_effect(definition: StatusEffectDefinition, source_element: int, arrived_by_transmission := false, transmission_source: Node = null) -> bool:
	if definition == null or status_immunities.has(definition.id):
		return false
	if definition.id == innate_status_id:
		return false
	var record := _active.get(definition.id) as StatusRecord
	if record == null or record.origin != StatusRecord.Origin.APPLIED:
		record = StatusRecordScript.new() as StatusRecord
		record.configure(definition, StatusRecord.Origin.APPLIED, definition.duration, 1, source_element, arrived_by_transmission)
	else:
		record.definition = definition
		record.remaining = definition.duration
		record.stacks = mini(record.stacks + 1, definition.maximum_stacks)
		record.source_element = source_element
		record.arrived_by_transmission = record.arrived_by_transmission or arrived_by_transmission
	_active[definition.id] = record
	if not definition.extinguishes.is_empty():
		_strip_statuses_without_notify(definition.extinguishes, definition.extinguish_stacks_per_application)
	_refresh_stun_cadences()
	_recompute_suppression()
	status_changed.emit()
	if arrived_by_transmission:
		transmission_received.emit(definition.id, transmission_source)
	return true


func advance(delta: float) -> Array[StatusTickResult]:
	var results: Array[StatusTickResult] = []
	var step := maxf(delta, 0.0)
	if step <= 0.0:
		return results
	var changed := false
	var status_ids: Array[StringName] = []
	for status_id: Variant in _active.keys():
		status_ids.append(status_id as StringName)
	status_ids.sort()
	var expired_ids: Array[StringName] = []
	for status_id: StringName in status_ids:
		var record := _active.get(status_id) as StatusRecord
		if record == null or record.definition == null:
			expired_ids.append(status_id)
			changed = true
			continue
		if record.origin == StatusRecord.Origin.INNATE:
			continue
		var definition := record.definition
		var elapsed := minf(step, maxf(record.remaining, 0.0))
		if definition.family == StatusEffectDefinition.Family.DAMAGE_OVER_TIME:
			record.tick_timer -= elapsed
			var interval := definition.tick_interval_for(record.stacks)
			while record.tick_timer <= 0.0 and elapsed > 0.0:
				var tick_result := StatusTickResultScript.new() as StatusTickResult
				tick_result.configure(StatusTickResultScript.Kind.DAMAGE, status_id, record.source_element, record.stacks, _max_health_tick_amount(definition.damage_percent_max_health_per_stack, record.stacks))
				results.append(tick_result)
				record.tick_timer += interval
				changed = true
		elif definition.family == StatusEffectDefinition.Family.PERIODIC_STUN:
			record.cadence_timer -= elapsed
			if definition.periodic_damage_percent_max_health_per_stack > 0.0:
				record.damage_tick_timer -= elapsed
				while record.damage_tick_timer <= 0.0 and elapsed > 0.0:
					var damage_result := StatusTickResultScript.new() as StatusTickResult
					damage_result.configure(StatusTickResultScript.Kind.DAMAGE, status_id, definition.element, record.stacks, _max_health_tick_amount(definition.periodic_damage_percent_max_health_per_stack, record.stacks))
					results.append(damage_result)
					record.damage_tick_timer += definition.periodic_damage_interval
					changed = true
			while record.cadence_timer <= 0.0 and elapsed > 0.0:
				var tick_result := StatusTickResultScript.new() as StatusTickResult
				tick_result.configure(StatusTickResultScript.Kind.STUN_PULSE, status_id, record.source_element, record.stacks, 0.0, definition.stun_lock_duration)
				tick_result.is_initial_stun_pulse = record.initial_stun_pulse_pending
				record.initial_stun_pulse_pending = false
				results.append(tick_result)
				record.cadence_interval = _effective_stun_interval(definition, record.stacks)
				record.cadence_timer += record.cadence_interval
				changed = true
		record.remaining -= step
		if record.remaining <= 0.0:
			expired_ids.append(status_id)
			changed = true
		else:
			_active[status_id] = record
	for status_id in expired_ids:
		_active.erase(status_id)
	if not expired_ids.is_empty():
		_refresh_stun_cadences()
	if changed:
		_recompute_suppression()
		status_changed.emit()
	return results


func clear_all() -> void:
	var had_records := not _active.is_empty()
	_active.clear()
	if had_records:
		status_changed.emit()


func active_definitions() -> Array[StatusEffectDefinition]:
	return presentation_definitions()


func presentation_records() -> Array[StatusRecord]:
	var records: Array[StatusRecord] = []
	for record_value: Variant in _active.values():
		var record := record_value as StatusRecord
		if record == null or record.definition == null:
			continue
		if record.origin == StatusRecord.Origin.INNATE and not record.suppressed_by.is_empty():
			continue
		records.append(record)
	records.sort_custom(_presentation_record_before)
	return records


func presentation_definitions() -> Array[StatusEffectDefinition]:
	var definitions: Array[StatusEffectDefinition] = []
	for record in presentation_records():
		definitions.append(record.definition)
	return definitions


func _presentation_record_before(a: StatusRecord, b: StatusRecord) -> bool:
	if a.origin != b.origin:
		return a.origin == StatusRecord.Origin.APPLIED
	if a.stacks != b.stacks:
		return a.stacks > b.stacks
	return String(a.definition.id) < String(b.definition.id)


func strongest_active_definition() -> StatusEffectDefinition:
	var definitions := presentation_definitions()
	return definitions[0] if not definitions.is_empty() else null


func record_for(status_id: StringName) -> StatusRecord:
	return _active.get(status_id) as StatusRecord


func _max_health_tick_amount(percent_per_stack: float, stacks: int) -> float:
	if health_component == null:
		return 0.0
	var raw_amount := maxf(health_component.maximum_health, 0.0) * maxf(percent_per_stack, 0.0) * float(maxi(stacks, 0)) / 100.0
	return maxf(1.0, roundf(raw_amount)) if raw_amount > 0.0 else 0.0


func stacks_for(status_id: StringName) -> int:
	var record := record_for(status_id)
	return record.stacks if record != null else 0


func is_suppressed(status_id: StringName) -> bool:
	var record := record_for(status_id)
	return record != null and record.origin == StatusRecord.Origin.INNATE and not record.suppressed_by.is_empty()


func _recompute_suppression(emit_transition := true) -> void:
	if innate_status_id.is_empty():
		return
	var innate := record_for(innate_status_id)
	if innate == null or innate.origin != StatusRecord.Origin.INNATE:
		return
	var old_suppressor := innate.suppressed_by
	var candidate_records: Array[StatusRecord] = []
	for id: StringName in _active.keys():
		var record := _active.get(id) as StatusRecord
		if record != null and record.origin == StatusRecord.Origin.APPLIED and id != innate_status_id:
			candidate_records.append(record)
	candidate_records.sort_custom(_presentation_record_before)
	innate.suppressed_by = candidate_records[0].definition.id if not candidate_records.is_empty() else &""
	if emit_transition and old_suppressor.is_empty() != innate.suppressed_by.is_empty():
		var suppressor := innate.suppressed_by if not innate.suppressed_by.is_empty() else old_suppressor
		suppression_changed.emit(innate_status_id, suppressor, not innate.suppressed_by.is_empty())


func transmissible_records() -> Array[StatusRecord]:
	var result: Array[StatusRecord] = []
	for record_value: Variant in _active.values():
		var record := record_value as StatusRecord
		if record == null or record.definition == null or not record.definition.transmissible:
			continue
		if record.origin == StatusRecord.Origin.INNATE and not record.suppressed_by.is_empty():
			continue
		result.append(record)
	result.sort_custom(_presentation_record_before)
	return result


func strip_statuses(ids: Array[StringName], stacks_per_application: int = 999) -> int:
	var removed := _strip_statuses_without_notify(ids, stacks_per_application)
	if removed > 0:
		_refresh_stun_cadences()
		_recompute_suppression()
		status_changed.emit()
	return removed


func _strip_statuses_without_notify(ids: Array[StringName], stacks_per_application: int) -> int:
	var remaining_to_strip := maxi(stacks_per_application, 0)
	var removed := 0
	for status_id in ids:
		if remaining_to_strip <= 0:
			break
		var record := record_for(status_id)
		if record == null or record.origin != StatusRecord.Origin.APPLIED:
			continue
		var stripped := mini(record.stacks, remaining_to_strip)
		removed += stripped
		remaining_to_strip -= stripped
		record.stacks -= stripped
		if record.stacks <= 0:
			_active.erase(status_id)
	return removed


func movement_speed_multiplier() -> float:
	return _slow_speed_multiplier(true)


func is_movement_locked() -> bool:
	return _has_applied_movement_lock()


func is_attack_locked() -> bool:
	return _has_applied_movement_lock()


func _has_applied_movement_lock() -> bool:
	for record_value: Variant in _active.values():
		var record := record_value as StatusRecord
		if record == null or record.origin != StatusRecord.Origin.APPLIED or record.definition == null:
			continue
		if record.definition.family == StatusEffectDefinition.Family.MOVEMENT_LOCK and not _movement_lock_is_resisted():
			return true
	return false


func attack_speed_multiplier() -> float:
	return _slow_speed_multiplier(false)


func _slow_speed_multiplier(include_movement_lock: bool) -> float:
	var result := 1.0
	for record_value: Variant in _active.values():
		var record := record_value as StatusRecord
		if record == null or record.origin != StatusRecord.Origin.APPLIED or record.definition == null:
			continue
		if include_movement_lock and record.definition.family == StatusEffectDefinition.Family.MOVEMENT_LOCK:
			if not _movement_lock_is_resisted():
				return 0.0
			continue
		if record.definition.family != StatusEffectDefinition.Family.MOVEMENT_SLOW:
			continue
		var slow_fraction := record.definition.magnitude_per_stack * float(record.stacks)
		result = minf(result, maxf(record.definition.movement_multiplier_floor, 1.0 - slow_fraction))
	return result


func _movement_lock_is_resisted() -> bool:
	return movement_lock_resistance_check.is_valid() and bool(movement_lock_resistance_check.call())


func damage_taken_multiplier() -> float:
	var result := 1.0
	for record_value: Variant in _active.values():
		var record := record_value as StatusRecord
		if record == null or record.origin != StatusRecord.Origin.APPLIED or record.definition == null or record.definition.family != StatusEffectDefinition.Family.DAMAGE_AMPLIFICATION:
			continue
		result = maxf(result, 1.0 + record.definition.magnitude_per_stack * float(maxi(record.stacks, 1)))
	return result


func incoming_damage_multiplier_for(element: int, include_vulnerability: bool = true) -> float:
	var result := 1.0
	for record_value: Variant in _active.values():
		var record := record_value as StatusRecord
		if record == null or record.origin != StatusRecord.Origin.APPLIED or record.definition == null:
			continue
		var definition := record.definition
		if definition.family == StatusEffectDefinition.Family.AMBIENT_MODIFIER and definition.conducts_element == element:
			result *= 1.0 + definition.conduct_damage_bonus_per_stack * float(record.stacks)
		elif include_vulnerability and definition.applies_damage_vulnerability():
			result *= 1.0 + definition.vulnerability_per_stack * float(record.stacks)
	return result


func conduct_stun_cadence_divisor() -> float:
	var result := 1.0
	for record_value: Variant in _active.values():
		var record := record_value as StatusRecord
		if record == null or record.origin != StatusRecord.Origin.APPLIED or record.definition == null or record.definition.family != StatusEffectDefinition.Family.AMBIENT_MODIFIER or record.definition.conducts_element != ElementCatalog.Element.ELECTRIC:
			continue
		result *= pow(record.definition.conduct_stun_cadence_divisor, float(record.stacks))
	return result


func _effective_stun_interval(definition: StatusEffectDefinition, stacks: int) -> float:
	return maxf(definition.stun_interval_floor, definition.stun_interval_for(stacks) / conduct_stun_cadence_divisor())


func _refresh_stun_cadences() -> void:
	for record_value: Variant in _active.values():
		var record := record_value as StatusRecord
		if record == null or record.origin != StatusRecord.Origin.APPLIED or record.definition == null or record.definition.family != StatusEffectDefinition.Family.PERIODIC_STUN:
			continue
		var next_interval := _effective_stun_interval(record.definition, record.stacks)
		if record.cadence_interval > 0.0 and record.cadence_timer > 0.0:
			record.cadence_timer *= next_interval / record.cadence_interval
		record.cadence_interval = next_interval
