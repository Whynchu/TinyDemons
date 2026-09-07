extends RefCounted
class_name PuzzleRouteSolver

## Stateful route proofs for generated R7 layouts. The simulation uses the same
## curriculum transition model as the compatibility assembler until that model
## is fully independent of runtime layout construction.

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


static func _connection_key(connection) -> String:
	return "%s:%s" % [connection.source_room_id, connection.exit_socket]
