extends SceneTree

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const GENERATOR_SCRIPT = preload("res://scripts/dungeon_layout_generator.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")

const STARTERS: Array[StringName] = [&"fire", &"water", &"electric"]


func _initialize() -> void:
	var failures: Array[String] = []
	for starter_flame in STARTERS:
		for completed_runs in [1, 2]:
			_check_progression(starter_flame, completed_runs, failures)
	var first_detour_layout = GENERATOR_SCRIPT.build(910000, 1, &"fire")
	var second_detour_layout = GENERATOR_SCRIPT.build(910001, 1, &"fire")
	_expect(_detour_orb_depth(first_detour_layout) != _detour_orb_depth(second_detour_layout), "seed variation moves the Orb Room detour between route depths", failures)
	var blue_run_three_alternate_pair_found := false
	for sample_index in range(32):
		var sampled_layout = GENERATOR_SCRIPT.build(120000 + sample_index * 7919, 2, &"water")
		if _has_red_yellow_primary_pair(sampled_layout):
			blue_run_three_alternate_pair_found = true
	_expect(blue_run_three_alternate_pair_found, "blue-starter Run 3 can offer a red/yellow primary door pair", failures)
	_finish(failures)


func _check_progression(starter_flame: StringName, completed_runs: int, failures: Array[String]) -> void:
	var seed_value := 910000 + completed_runs * 100 + STARTERS.find(starter_flame)
	var available := ASPECT_CATALOG_SCRIPT.flames_available_for_run(completed_runs, starter_flame)
	var alternates := ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(completed_runs, starter_flame)
	_expect(available.size() == completed_runs + 1, "%s Run %d exposes the expected number of flames" % [starter_flame, completed_runs + 1], failures)
	_expect(alternates.size() == completed_runs, "%s Run %d exposes the expected number of alternate flames" % [starter_flame, completed_runs + 1], failures)

	var layout = GENERATOR_SCRIPT.build(seed_value, completed_runs, starter_flame)
	var validation_errors: Array[String] = GENERATOR_SCRIPT.validate(layout, completed_runs, starter_flame)
	_expect(validation_errors.is_empty(), "%s Run %d generated layout passes reachability validation" % [starter_flame, completed_runs + 1], failures)
	for sample_index in range(12):
		var sampled_layout = GENERATOR_SCRIPT.build(seed_value + sample_index * 7919, completed_runs, starter_flame)
		var sampled_errors: Array[String] = GENERATOR_SCRIPT.validate(sampled_layout, completed_runs, starter_flame)
		_expect(sampled_errors.is_empty(), "%s Run %d sampled seed %d has no color soft-lock" % [starter_flame, completed_runs + 1, sample_index], failures)
		var side_flame_errors: Array[String] = GENERATOR_SCRIPT._color_gate_side_flame_errors(sampled_layout, completed_runs, starter_flame)
		_expect(side_flame_errors.is_empty(), "%s Run %d sampled seed %d keeps each colored gate beside its required flame" % [starter_flame, completed_runs + 1, sample_index], failures)

	var detour_orb_count := 0
	var optional_treasure_count := 0
	var declared_fire_flames: Array[StringName] = []
	for room in layout.rooms:
		if room.room_type == GRAPH_SCRIPT.ROOM_FIRE and not room.fire_flame.is_empty():
			declared_fire_flames.append(room.fire_flame)
		for connection in layout.connections:
			if connection.destination_room_id != room.id:
				continue
			if room.room_type == GRAPH_SCRIPT.ROOM_ORB and connection.route_role == &"detour_orb":
				detour_orb_count += 1
			if room.room_type == GRAPH_SCRIPT.ROOM_TREASURE and connection.route_role == &"optional_treasure":
				optional_treasure_count += 1
	_expect(detour_orb_count == 1, "%s Run %d puts exactly one Orb Room on a side detour" % [starter_flame, completed_runs + 1], failures)
	_expect(optional_treasure_count >= 2, "%s Run %d preserves multiple off-spine Treasure branches" % [starter_flame, completed_runs + 1], failures)
	for flame in declared_fire_flames:
		_expect(flame in available, "%s Run %d declares only flames available in that run" % [starter_flame, completed_runs + 1], failures)
	for alternate_flame in alternates:
		_expect(declared_fire_flames.has(alternate_flame), "%s Run %d declares a reachable Fire Room for %s" % [starter_flame, completed_runs + 1, alternate_flame], failures)

	var graph = GRAPH_SCRIPT.new()
	var map = MAP_CONTROLLER_SCRIPT.new()
	map.begin_run(graph, seed_value, completed_runs, starter_flame)
	_expect(map.available_flames() == available, "%s Run %d map progression matches the catalog" % [starter_flame, completed_runs + 1], failures)
	_expect(map.current_color() == &"puzzle_b", "%s Run %d starts in the grey puzzle state" % [starter_flame, completed_runs + 1], failures)
	_expect(map.orb_display_palette() == &"grey", "%s Run %d starts with grey Orb Room presentation" % [starter_flame, completed_runs + 1], failures)
	_expect(map.available_puzzle_colors().has(&"puzzle_a") and map.available_puzzle_colors().has(&"puzzle_b"), "%s Run %d keeps starter and grey puzzle colors" % [starter_flame, completed_runs + 1], failures)
	_expect(map.palette_for_requirement(&"puzzle_a") == ASPECT_CATALOG_SCRIPT.palette_for_flame(starter_flame), "%s Run %d maps Puzzle A to its starter flame" % [starter_flame, completed_runs + 1], failures)

	var expected_alternate_index := 0
	for alternate_flame in alternates:
		var expected_color: StringName = &"puzzle_c" if expected_alternate_index == 0 else &"puzzle_d"
		var expected_palette := ASPECT_CATALOG_SCRIPT.palette_for_flame(alternate_flame)
		_expect(map.palette_for_requirement(expected_color) == expected_palette, "%s Run %d maps %s to %s" % [starter_flame, completed_runs + 1, expected_color, alternate_flame], failures)
		_expect(map.puzzle_color_for_palette(expected_palette) == expected_color, "%s Run %d maps %s back to %s" % [starter_flame, completed_runs + 1, expected_palette, expected_color], failures)
		_expect(map.fire_palette_available(expected_palette), "%s Run %d permits interaction with the %s Fire Room" % [starter_flame, completed_runs + 1, alternate_flame], failures)
		expected_alternate_index += 1
	if completed_runs == 1:
		_expect(not map.available_puzzle_colors().has(&"puzzle_d"), "%s Run 2 withholds the future third puzzle color" % starter_flame, failures)
		var unearned_flame: StringName = &""
		for candidate in ASPECT_CATALOG_SCRIPT.STARTER_FLAMES:
			if candidate not in available:
				unearned_flame = candidate
				break
		_expect(not unearned_flame.is_empty() and not map.fire_palette_available(ASPECT_CATALOG_SCRIPT.palette_for_flame(unearned_flame)), "%s Run 2 withholds the unearned third flame" % starter_flame, failures)
	else:
		_expect(map.available_puzzle_colors().has(&"puzzle_c") and map.available_puzzle_colors().has(&"puzzle_d"), "%s Run 3 exposes both alternate puzzle colors" % starter_flame, failures)

	var orb_room_id: StringName = &""
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room != null and room.room_type == GRAPH_SCRIPT.ROOM_ORB:
			orb_room_id = room_id
			break
	if not orb_room_id.is_empty():
		map.on_room_entered(orb_room_id)
		for alternate_index in alternates.size():
			var puzzle_color: StringName = &"puzzle_c" if alternate_index == 0 else &"puzzle_d"
			_expect(map.change_orb_from_room(orb_room_id, puzzle_color), "%s Run %d Orb Room accepts earned %s" % [starter_flame, completed_runs + 1, puzzle_color], failures)
	else:
		_expect(false, "%s Run %d exposes an Orb Room to the map controller" % [starter_flame, completed_runs + 1], failures)
	map.free()


func _has_red_yellow_primary_pair(layout) -> bool:
	for room in layout.rooms:
		if room.room_type != GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY:
			continue
		var requirements: Dictionary = {}
		for connection in layout.connections:
			if connection.source_room_id == room.id:
				requirements[connection.color_requirement] = true
		if requirements.has(&"puzzle_c") and requirements.has(&"puzzle_d") and not requirements.has(&"puzzle_a"):
			return true
	return false


func _detour_orb_depth(layout) -> int:
	for room in layout.rooms:
		if room.room_type != GRAPH_SCRIPT.ROOM_ORB:
			continue
		for connection in layout.connections:
			if connection.destination_room_id == room.id and connection.route_role == &"detour_orb":
				return room.coordinate.y
	return -1


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GENERATED_FLAME_PROGRESSION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
