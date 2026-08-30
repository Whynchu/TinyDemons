extends SceneTree

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const CHROMA_SCRIPT = preload("res://scripts/player_chroma_component.gd")
const PROFILE_SCRIPT = preload("res://scripts/player_profile.gd")
const ELEMENT_CATALOG_SCRIPT = preload("res://scripts/element_catalog.gd")
const GENERATOR_SCRIPT = preload("res://scripts/dungeon_layout_generator.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_STATE_SCRIPT = preload("res://scripts/dungeon_map_state.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var expected_recipes := {
		[&"fire", &"water"]: &"shadow",
		[&"fire", &"electric"]: &"ground",
		[&"water", &"electric"]: &"grass",
		[&"grass", &"water"]: &"ice",
	}
	for pair in expected_recipes:
		var first: StringName = pair[0] as StringName
		var second: StringName = pair[1] as StringName
		var expected: StringName = expected_recipes[pair] as StringName
		_expect(ASPECT_CATALOG_SCRIPT.fusion_result(first, second) == expected, "recipe %s + %s resolves" % [first, second], failures)
		_expect(ASPECT_CATALOG_SCRIPT.fusion_result(second, first) == expected, "recipe %s + %s is commutative" % [second, first], failures)
	_expect(ASPECT_CATALOG_SCRIPT.fusion_result(&"fire", &"grass").is_empty(), "unlisted fusion is rejected", failures)
	_expect(ASPECT_CATALOG_SCRIPT.fusion_result(&"gray", &"fire").is_empty(), "Gray is not a fusion input", failures)

	var profile := PROFILE_SCRIPT.new()
	profile.souls = 49
	_expect(not profile.bind_element(&"fire"), "insufficient Souls reject Binding", failures)
	_expect(profile.souls == 49 and not profile.has_bound_element, "failed Binding is atomic", failures)
	profile.souls = 50
	_expect(profile.bind_element(&"fire"), "first Binding costs 50 Souls", failures)
	_expect(profile.souls == 0 and profile.bound_element == &"fire" and profile.palette_name == "red", "Binding persists the file identity", failures)
	_expect(profile.bind_element(&"fire") and profile.souls == 0, "same-element Binding is a free no-op", failures)
	profile.souls = 50
	_expect(profile.bind_element(&"water"), "re-Binding costs the same flat 50 Souls", failures)
	_expect(profile.souls == 0 and profile.bound_element == &"water" and profile.palette_name == "blue", "re-Binding updates the durable identity", failures)
	var round_trip := PROFILE_SCRIPT.new()
	round_trip.load_dictionary(profile.to_dictionary())
	_expect(round_trip.has_bound_element and round_trip.bound_element == &"water", "bound element survives profile serialization", failures)

	var chroma := CHROMA_SCRIPT.new()
	root.add_child(chroma)
	chroma.set_bound_flame(&"water")
	chroma.attune(CHROMA_SCRIPT.Aspect.FIRE)
	_expect(chroma.current_aspect == CHROMA_SCRIPT.Aspect.FIRE and chroma.bound_aspect == CHROMA_SCRIPT.Aspect.WATER, "current and bound identities remain separate", failures)
	for _cast in 10:
		chroma.spend_elemental_ability()
	_expect(chroma.current_chroma == 0 and chroma.current_aspect == CHROMA_SCRIPT.Aspect.WATER, "zero Chroma falls back to the bound identity", failures)
	chroma.set_bound_aspect(CHROMA_SCRIPT.Aspect.NONE)
	chroma.attune(CHROMA_SCRIPT.Aspect.WATER)
	chroma.attune(CHROMA_SCRIPT.Aspect.GRASS)
	_expect(not chroma.has_bound_aspect() and chroma.current_aspect == CHROMA_SCRIPT.Aspect.GRASS, "an unbound fusion result stays temporary", failures)

	var layout = GENERATOR_SCRIPT.build(607001, 5, &"fire")
	var validation: Array[String] = GENERATOR_SCRIPT.validate(layout, 5, &"fire")
	_expect(validation.is_empty(), "Run 6 generated fusion layout validates", failures)
	var gate_count := 0
	var gate_connection = null
	var fire_depths: Array[int] = []
	for room in layout.rooms:
		if room.room_type == GRAPH_SCRIPT.ROOM_FIRE:
			fire_depths.append(room.coordinate.y)
	for connection in layout.connections:
		if connection.resolved_gate_type() == GRAPH_SCRIPT.GATE_ENTRANCE_ORB:
			gate_count += 1
			if gate_connection == null:
				gate_connection = connection
	_expect(gate_count >= 1, "Run 6 has a mandatory fusion entrance-orb gate", failures)
	_expect(5 in fire_depths and 6 in fire_depths, "Run 6 places both fusion input flames before its gate", failures)
	for completed_runs in [5, 6, 7, 8]:
		for starter in [&"fire", &"water", &"electric"]:
			var sampled_layout = GENERATOR_SCRIPT.build(607001 + completed_runs * 13 + String(starter).hash(), completed_runs, starter)
			var sampled_errors: Array[String] = GENERATOR_SCRIPT.validate(sampled_layout, completed_runs, starter)
			_expect(sampled_errors.is_empty(), "Run %d %s fusion curriculum validates" % [completed_runs + 1, starter], failures)
			var sampled_gate_count := 0
			for sampled_connection in sampled_layout.connections:
				if sampled_connection.resolved_gate_type() == GRAPH_SCRIPT.GATE_ENTRANCE_ORB:
					sampled_gate_count += 1
			var expected_gate_count := 1 if completed_runs < 7 else 2
			_expect(sampled_gate_count == expected_gate_count, "Run %d %s has its expected fusion gate count" % [completed_runs + 1, starter], failures)
			if completed_runs >= 7:
				var late_gate_source_id: StringName = &""
				for sampled_connection in sampled_layout.connections:
					if sampled_connection.resolved_gate_type() != GRAPH_SCRIPT.GATE_ENTRANCE_ORB:
						continue
					var sampled_source = sampled_layout.room_by_id(sampled_connection.source_room_id)
					if sampled_source != null and sampled_source.coordinate.y == 10:
						late_gate_source_id = sampled_connection.source_room_id
						break
				var late_gate_has_pre_gate_orb := false
				if not late_gate_source_id.is_empty():
					for side_connection in sampled_layout.connections:
						if side_connection.source_room_id != late_gate_source_id:
							continue
						var side_destination = sampled_layout.room_by_id(side_connection.destination_room_id)
						if side_destination != null and side_destination.room_type == GRAPH_SCRIPT.ROOM_ORB:
							late_gate_has_pre_gate_orb = true
							break
				_expect(late_gate_has_pre_gate_orb, "Run %d %s places its second Orb beside the room before the Ice gate" % [completed_runs + 1, starter], failures)

	var graph := GRAPH_SCRIPT.new()
	var map := MAP_CONTROLLER_SCRIPT.new()
	map.begin_run(graph, 607001, 5, &"fire")
	map.set_starter_flame_attuned(true)
	if gate_connection != null:
		var runtime_gate = graph.get_connection(gate_connection.source_room_id, gate_connection.exit_socket)
		var required_element_id: StringName = runtime_gate.orb_element_requirement
		var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(required_element_id)
		var required_palette := ELEMENT_CATALOG_SCRIPT.palette_key(required_element)
		var solved_color_gate := _find_color_connection(graph, &"puzzle_b")
		var unsolved_color_gate = null
		if solved_color_gate != null:
			map.on_room_completed(solved_color_gate.source_room_id)
			_expect(map.connection_visual_state(solved_color_gate) == &"open", "the active ordinary puzzle-color door opens before fusion", failures)
			unsolved_color_gate = _find_color_connection(graph, &"", "%s:%s" % [solved_color_gate.source_room_id, solved_color_gate.exit_socket])
		map.set_current_element(required_element)
		_expect(map.connection_visual_state(runtime_gate) == &"orb_locked", "matching current fusion result does not bypass the entrance orb", failures)
		map.set_current_element(ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)
		_expect(map.connection_visual_state(runtime_gate) == &"orb_locked", "R6 entrance-orb gate remains locked before its orb is charged", failures)
		var orb_room_id: StringName = &""
		for room_id in graph.get_room_ids():
			var room := graph.get_room(room_id)
			if room != null and room.room_type == GRAPH_SCRIPT.ROOM_ORB:
				orb_room_id = room.id
				break
		_expect(not orb_room_id.is_empty(), "R6 exposes an Orb Room for the fusion gate", failures)
		if not orb_room_id.is_empty():
			map.on_room_entered(orb_room_id)
			_expect(map.change_orb_from_palette(orb_room_id, "green"), "R6 Orb Room accepts a wrong elemental charge without opening Shadow", failures)
			_expect(map.connection_visual_state(runtime_gate) == &"orb_locked", "wrong mixed result does not open the Shadow entrance gate", failures)
			_expect(map.change_orb_from_palette(orb_room_id, required_palette), "R6 Orb Room accepts the matching mixed result", failures)
			_expect(map.shared_orb_element() == required_element_id, "shared Orb Room state records the mixed result element", failures)
			_expect(map.connection_visual_state(runtime_gate) == &"open", "matching Orb charge opens the R6 entrance gate", failures)
			_expect(map.current_color() == MAP_STATE_SCRIPT.MAP_COLOR_NEUTRAL and map.shared_orb_puzzle_color() == MAP_STATE_SCRIPT.MAP_COLOR_NEUTRAL, "mixed Orb charge clears the ordinary puzzle-color key", failures)
			if solved_color_gate != null:
				_expect(map.connection_visual_state(solved_color_gate) == &"open", "an ordinary door solved before fusion stays open", failures)
			if unsolved_color_gate != null:
				_expect(map.connection_visual_state(unsolved_color_gate) == &"orb_locked", "an unsolved ordinary door does not inherit the mixed result", failures)
			map.set_current_element(ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)
			_expect(map.is_connection_available(runtime_gate), "solved entrance-orb door stays open after the element changes", failures)
	for completed_runs in [5, 6, 7]:
		var curriculum_graph := GRAPH_SCRIPT.new()
		var curriculum_map := MAP_CONTROLLER_SCRIPT.new()
		curriculum_map.begin_run(curriculum_graph, 712000 + completed_runs, completed_runs, &"fire")
		curriculum_map.set_starter_flame_attuned(true)
		var orb_room_id: StringName = &""
		for room_id in curriculum_graph.get_room_ids():
			var room := curriculum_graph.get_room(room_id)
			if room != null and room.room_type == GRAPH_SCRIPT.ROOM_ORB:
				orb_room_id = room.id
				break
		if not orb_room_id.is_empty():
			curriculum_map.on_room_entered(orb_room_id)
		for room_id in curriculum_graph.get_room_ids():
			var room := curriculum_graph.get_room(room_id)
			if room == null:
				continue
			for connection_value in room.outgoing_connections.values():
				var connection := connection_value as DungeonGraph.ConnectionRecord
				if connection == null or connection.resolved_gate_type() != GRAPH_SCRIPT.GATE_ENTRANCE_ORB:
					continue
				var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(connection.orb_element_requirement)
				var required_palette := ELEMENT_CATALOG_SCRIPT.palette_key(required_element)
				curriculum_map.set_current_element(required_element)
				_expect(curriculum_map.connection_visual_state(connection) == &"orb_locked", "Run %d elemental form does not bypass its entrance orb" % (completed_runs + 1), failures)
				if not orb_room_id.is_empty():
					_expect(curriculum_map.change_orb_from_palette(orb_room_id, required_palette), "%s Orb Room accepts its Run %d mixed result" % [required_palette, completed_runs + 1], failures)
				_expect(curriculum_map.connection_visual_state(connection) == &"open", "%s entrance orb opens its Run %d door" % [required_palette, completed_runs + 1], failures)
				curriculum_map.set_current_element(ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)
				_expect(curriculum_map.is_connection_available(connection), "%s entrance door remains open after returning to neutral" % required_palette, failures)
		curriculum_map.free()
	map.free()
	chroma.free()
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ELEMENTAL_BINDING_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _find_color_connection(graph: DungeonGraph, requirement: StringName = &"", excluded_key: String = "") -> DungeonGraph.ConnectionRecord:
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room == null:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			if connection == null or connection.resolved_gate_type() != GRAPH_SCRIPT.GATE_PUZZLE_COLOR:
				continue
			if not requirement.is_empty() and connection.color_requirement != requirement:
				continue
			if not excluded_key.is_empty() and "%s:%s" % [connection.source_room_id, connection.exit_socket] == excluded_key:
				continue
			return connection
	return null
