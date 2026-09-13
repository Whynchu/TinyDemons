extends SceneTree

const ROUTE_GENERATOR = preload("res://scripts/puzzle_route_generator.gd")
const GRAPH = preload("res://scripts/dungeon_graph.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	for starter in [&"fire", &"water", &"electric"]:
		for seed_value in range(24):
			var dungeon_seed := 1200000 + seed_value * 7919
			var layout = ROUTE_GENERATOR.build(dungeon_seed, 6, starter)
			var errors: Array[String] = ROUTE_GENERATOR.validate(layout, 6, starter)
			_expect(errors.is_empty(), "R7 %s seed %d validates: %s" % [starter, dungeon_seed, "; ".join(errors)], failures)
			_expect(layout != null and ROUTE_GENERATOR.is_risk_reward_layout(6), "R7 uses the R6+ risk/reward route owner", failures)
			if layout == null:
				continue
			_expect(_primary_flame_count(layout) == 3, "R7 %s seed %d guarantees all primary flames" % [starter, dungeon_seed], failures)
			_expect(_vault_count(layout) >= 1 and _vault_count(layout) <= 2, "R7 %s seed %d has one or two optional vaults" % [starter, dungeon_seed], failures)
			_expect(_critical_connections_are_ungated(layout), "R7 %s seed %d keeps critical connections ungated" % [starter, dungeon_seed], failures)
			_expect(layout.safe_route_length > layout.risk_route_length + 1, "R7 %s seed %d has a materially shorter risk route" % [starter, dungeon_seed], failures)
			var repeat = ROUTE_GENERATOR.build(dungeon_seed, 6, starter)
			_expect(_layout_signature(layout) == _layout_signature(repeat), "R7 %s seed %d is deterministic" % [starter, dungeon_seed], failures)
	if failures.is_empty():
		print("R6_PLUS_GENERATOR_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _primary_flame_count(layout) -> int:
	var flames: Dictionary = {}
	for room in layout.rooms:
		if room.route_role == GRAPH.ROUTE_PRIMARY_FLAME and room.fire_flame in [&"fire", &"water", &"electric"]:
			flames[room.fire_flame] = true
	return flames.size()


func _vault_count(layout) -> int:
	var count := 0
	for connection in layout.connections:
		if connection.route_role == GRAPH.ROUTE_ELEMENTAL_VAULT:
			count += 1
	return count


func _critical_connections_are_ungated(layout) -> bool:
	for connection in layout.connections:
		if connection.route_role in [GRAPH.ROUTE_MAIN, &"key_progression"] and connection.resolved_gate_type() != GRAPH.GATE_NONE:
			return false
	return true


func _layout_signature(layout) -> String:
	var parts: Array[String] = []
	for room in layout.rooms:
		parts.append("%s:%s:%s:%s:%s:%s:%s" % [room.id, room.coordinate, room.room_type, room.route_role, room.encounter_tier, room.reward_tier, room.vault_id])
	for connection in layout.connections:
		parts.append("%s:%s:%s:%s:%s:%s" % [connection.source_room_id, connection.exit_socket, connection.destination_room_id, connection.route_role, connection.resolved_gate_type(), connection.orb_element_requirement])
	parts.sort()
	return "|".join(parts)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
