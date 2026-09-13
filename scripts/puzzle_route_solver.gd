extends RefCounted
class_name PuzzleRouteSolver

## Stateful route proofs for generated layouts. The legacy fusion simulation is
## retained for compatibility fixtures; active R6+ routes use the simpler
## ungated-backbone and optional-vault proof below.

const LEGACY_MODEL = preload("res://scripts/dungeon_layout_generator.gd")
const ELEMENTS = preload("res://scripts/element_catalog.gd")

static func validate_ordered_fusion(layout, start_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"") -> Array[String]:
	var errors: Array[String] = []
	if layout == null:
		errors.append("R7 solver received no route layout")
		return errors
	for gate in layout.connections:
		if gate.resolved_gate_type() != DungeonGraph.GATE_ENTRANCE_ORB:
			continue
		if gate.route_role != &"main" and gate.route_role != &"key_progression":
			continue
		var required_element := ELEMENTS.element_for_id(gate.orb_element_requirement)
		var states: Array[Dictionary] = LEGACY_MODEL._curriculum_reachable_states(layout, start_id, completed_runs, starter_flame, bound_flame, {}, _connection_key(gate))
		var ordered_proof := false
		for state in states:
			if state.get("room_id", &"") != gate.source_room_id:
				continue
			if int(state.get("orb_element", ELEMENTS.Element.NEUTRAL)) == required_element:
				ordered_proof = true
				break
		if not ordered_proof:
			errors.append("R7 solver cannot prove ordered fusion state before %s:%s" % [gate.source_room_id, gate.exit_socket])
	return errors


static func validate_risk_reward(layout, start_id: StringName) -> Array[String]:
	var errors: Array[String] = []
	if layout == null:
		errors.append("R6+ solver received no route layout")
		return errors
	var reachable := LEGACY_MODEL._ungated_reachable_rooms(layout, start_id)
	var has_orb_utility := false
	for room in layout.rooms:
		if room.room_type == DungeonGraph.ROOM_ORB and reachable.has(room.id):
			has_orb_utility = true
		if room.route_role == DungeonGraph.ROUTE_PRIMARY_FLAME and room.fire_flame in [&"fire", &"water", &"electric"] and not reachable.has(room.id):
			errors.append("R6+ solver cannot reach primary flame %s" % room.fire_flame)
	for connection in layout.connections:
		if connection.route_role != DungeonGraph.ROUTE_ELEMENTAL_VAULT:
			continue
		if not has_orb_utility:
			errors.append("R6+ vault %s:%s has no ungated Orb utility" % [connection.source_room_id, connection.exit_socket])
		if not reachable.has(connection.source_room_id):
			errors.append("R6+ vault source is not reachable before its Orb door: %s:%s" % [connection.source_room_id, connection.exit_socket])
		if not ELEMENTS.is_valid_id(connection.orb_element_requirement):
			errors.append("R6+ vault requirement is not a supported element: %s" % connection.orb_element_requirement)
		var destination_incoming := 0
		for candidate in layout.connections:
			if candidate.destination_room_id == connection.destination_room_id:
				destination_incoming += 1
		if destination_incoming != 1:
			errors.append("R6+ vault destination can be bypassed: %s" % connection.destination_room_id)
	return errors


static func _connection_key(connection) -> String:
	return "%s:%s" % [connection.source_room_id, connection.exit_socket]
