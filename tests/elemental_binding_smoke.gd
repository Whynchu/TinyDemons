extends SceneTree

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const CHROMA_SCRIPT = preload("res://scripts/player_chroma_component.gd")
const PROFILE_SCRIPT = preload("res://scripts/player_profile.gd")
const ELEMENT_CATALOG_SCRIPT = preload("res://scripts/element_catalog.gd")
const ROUTE_GENERATOR_SCRIPT = preload("res://scripts/puzzle_route_generator.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
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
	var bound_r3_graph := GRAPH_SCRIPT.new()
	var bound_r3_map := MAP_CONTROLLER_SCRIPT.new()
	bound_r3_map.begin_run(bound_r3_graph, 607002, 2, &"fire", &"shadow")
	var bound_r3_fire = null
	for bound_r3_room in bound_r3_map.layout.rooms:
		if bound_r3_room.room_type == GRAPH_SCRIPT.ROOM_FIRE:
			bound_r3_fire = bound_r3_room
			break
	_expect(bound_r3_fire != null and bound_r3_fire.fire_flame == &"shadow", "bound R3 uses the flame selected at run start", failures)
	_expect(bound_r3_map.palette_for_requirement(&"puzzle_a") == "purple", "bound R3 primary doors use the bound flame palette", failures)

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

	var layout = ROUTE_GENERATOR_SCRIPT.build(607001, 5, &"fire")
	var validation: Array[String] = ROUTE_GENERATOR_SCRIPT.validate(layout, 5, &"fire")
	_expect(validation.is_empty(), "Run 6 risk/reward layout validates", failures)
	_expect(_primary_flame_count(layout) == 3, "Run 6 keeps Fire, Water, and Electric flame rooms available", failures)
	_expect(_vault_gate_count(layout) >= 1 and _vault_gate_count(layout) <= 2, "Run 6 exposes one or two optional elemental vaults", failures)
	for completed_runs in [5, 6, 7, 8]:
		for starter in [&"fire", &"water", &"electric"]:
			var sampled_layout = ROUTE_GENERATOR_SCRIPT.build(607001 + completed_runs * 13 + String(starter).hash(), completed_runs, starter)
			var sampled_errors: Array[String] = ROUTE_GENERATOR_SCRIPT.validate(sampled_layout, completed_runs, starter)
			_expect(sampled_errors.is_empty(), "Run %d %s risk/reward layout validates: %s" % [completed_runs + 1, starter, "; ".join(sampled_errors)], failures)
			_expect(_primary_flame_count(sampled_layout) == 3, "Run %d %s keeps every primary flame available" % [completed_runs + 1, starter], failures)
			_expect(_vault_gate_count(sampled_layout) >= 1 and _vault_gate_count(sampled_layout) <= 2, "Run %d %s exposes one or two optional elemental vaults" % [completed_runs + 1, starter], failures)

	var graph := GRAPH_SCRIPT.new()
	var map := MAP_CONTROLLER_SCRIPT.new()
	map.begin_run(graph, 607001, 5, &"fire")
	map.set_starter_flame_attuned(true)
	var runtime_gate: DungeonGraph.ConnectionRecord = _first_vault_gate(graph)
	_expect(runtime_gate != null, "Run 6 exposes an optional elemental vault door", failures)
	if runtime_gate != null:
		var required_element_id: StringName = runtime_gate.orb_element_requirement
		var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(required_element_id)
		var required_palette := ELEMENT_CATALOG_SCRIPT.palette_key(required_element)
		map.on_room_completed(runtime_gate.source_room_id)
		_expect(map.connection_visual_state(runtime_gate) == &"orb_locked", "vault door remains locked before its Orb charge", failures)
		var orb_room_id: StringName = _first_orb_room(graph)
		_expect(not orb_room_id.is_empty(), "Run 6 exposes an ungated Orb utility room", failures)
		if not orb_room_id.is_empty():
			map.on_room_entered(orb_room_id)
			_expect(map.change_orb_from_palette(orb_room_id, required_palette), "Orb utility accepts the vault element", failures)
			_expect(map.shared_orb_element() == required_element_id, "shared Orb state records the vault element", failures)
			_expect(map.connection_visual_state(runtime_gate) == &"open", "matching Orb charge opens the optional vault door", failures)
			_expect(map.is_connection_available(runtime_gate), "vault door can be traversed after its requirement is met", failures)
			map.change_orb_from_palette(orb_room_id, "grey")
			_expect(map.connection_visual_state(runtime_gate) == &"open", "solved vault door remains open after the Orb resets", failures)
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
				curriculum_map.on_room_completed(connection.source_room_id)
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


func _primary_flame_count(layout) -> int:
	var flames: Dictionary = {}
	if layout == null:
		return 0
	for room in layout.rooms:
		if room.route_role == GRAPH_SCRIPT.ROUTE_PRIMARY_FLAME and room.fire_flame in [&"fire", &"water", &"electric"]:
			flames[room.fire_flame] = true
	return flames.size()


func _vault_gate_count(layout) -> int:
	var count := 0
	if layout == null:
		return count
	for connection in layout.connections:
		if connection.route_role == GRAPH_SCRIPT.ROUTE_ELEMENTAL_VAULT:
			count += 1
	return count


func _first_vault_gate(graph: DungeonGraph) -> DungeonGraph.ConnectionRecord:
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room == null:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			if connection != null and connection.route_role == GRAPH_SCRIPT.ROUTE_ELEMENTAL_VAULT:
				return connection
	return null


func _first_orb_room(graph: DungeonGraph) -> StringName:
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room != null and room.room_type == GRAPH_SCRIPT.ROOM_ORB:
			return room.id
	return &""
