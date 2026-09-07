extends SceneTree

const ROUTE_GENERATOR = preload("res://scripts/puzzle_route_generator.gd")
const GRAPH = preload("res://scripts/dungeon_graph.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	for starter in [&"fire", &"water", &"electric"]:
		for seed_value in range(100):
			var dungeon_seed := 1200000 + seed_value * 7919
			var layout = ROUTE_GENERATOR.build(dungeon_seed, 6, starter)
			var errors: Array[String] = ROUTE_GENERATOR.validate(layout, 6, starter)
			_expect(errors.is_empty(), "R7 %s seed %d validates: %s" % [starter, dungeon_seed, "; ".join(errors)], failures)
			_expect(layout.rooms.size() >= 24 and layout.rooms.size() <= 30, "R7 %s seed %d stays in the room target" % [starter, dungeon_seed], failures)
			_expect(_entrance_orb_gate_count(layout) == 1, "R7 %s seed %d has one fusion gate" % [starter, dungeon_seed], failures)
			var compact_plan = ROUTE_GENERATOR.build_compact_plan(dungeon_seed, 6, starter)
			_expect(compact_plan.logical_edges.size() == layout.connections.size(), "R7 %s seed %d preserves logical edges" % [starter, dungeon_seed], failures)
			var repeat = ROUTE_GENERATOR.build(dungeon_seed, 6, starter)
			_expect(_layout_signature(layout) == _layout_signature(repeat), "R7 %s seed %d is deterministic" % [starter, dungeon_seed], failures)
	if failures.is_empty():
		print("R7_NATIVE_GENERATOR_SMOKE_OK")
	else:
		for failure in failures:
			push_error(failure)
		quit(1)

func _entrance_orb_gate_count(layout) -> int:
	var count := 0
	for connection in layout.connections:
		if connection.resolved_gate_type() == GRAPH.GATE_ENTRANCE_ORB:
			count += 1
	return count

func _layout_signature(layout) -> String:
	var parts: Array[String] = []
	for room in layout.rooms:
		parts.append("%s:%s:%s" % [room.id, room.coordinate, room.room_type])
	return "|".join(parts)

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
