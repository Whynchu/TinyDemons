extends SceneTree

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const CHROMA_SCRIPT = preload("res://scripts/player_chroma_component.gd")
const PROFILE_SCRIPT = preload("res://scripts/player_profile.gd")
const ELEMENT_CATALOG_SCRIPT = preload("res://scripts/element_catalog.gd")
const GENERATOR_SCRIPT = preload("res://scripts/dungeon_layout_generator.gd")
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
		if not connection.element_requirement.is_empty():
			gate_count += 1
			if gate_connection == null:
				gate_connection = connection
	_expect(gate_count >= 1, "Run 6 has a mandatory fusion-element gate", failures)
	_expect(5 in fire_depths and 6 in fire_depths, "Run 6 places both fusion input flames before its gate", failures)
	for completed_runs in [5, 6, 7, 8]:
		for starter in [&"fire", &"water", &"electric"]:
			var sampled_layout = GENERATOR_SCRIPT.build(607001 + completed_runs * 13 + String(starter).hash(), completed_runs, starter)
			var sampled_errors: Array[String] = GENERATOR_SCRIPT.validate(sampled_layout, completed_runs, starter)
			_expect(sampled_errors.is_empty(), "Run %d %s fusion curriculum validates" % [completed_runs + 1, starter], failures)
			var sampled_gate_count := 0
			for sampled_connection in sampled_layout.connections:
				if not sampled_connection.element_requirement.is_empty():
					sampled_gate_count += 1
			var expected_gate_count := 1 if completed_runs < 7 else 2
			_expect(sampled_gate_count == expected_gate_count, "Run %d %s has its expected fusion gate count" % [completed_runs + 1, starter], failures)

	var graph := GRAPH_SCRIPT.new()
	var map := MAP_CONTROLLER_SCRIPT.new()
	map.begin_run(graph, 607001, 5, &"fire")
	map.set_starter_flame_attuned(true)
	if gate_connection != null:
		var runtime_gate = graph.get_connection(gate_connection.source_room_id, gate_connection.exit_socket)
		var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(runtime_gate.element_requirement)
		map.set_current_element(required_element)
		_expect(map.is_connection_available(runtime_gate), "unbound fusion result opens the required door", failures)
		map.set_current_element(ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)
		_expect(map.is_connection_available(runtime_gate), "solved fusion door stays open after the element changes", failures)
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
