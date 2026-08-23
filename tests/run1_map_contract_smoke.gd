extends SceneTree

const LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run1.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_STATE_SCRIPT = preload("res://scripts/dungeon_map_state.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var layout = LAYOUT_SCRIPT.build()
	var layout_errors: Array[String] = layout.validate()
	_expect(layout_errors.is_empty(), "Run 1 authored layout validates: %s" % str(layout_errors), failures)
	_expect(layout.rooms.size() == 18, "Run 1 contains the 18 authored room locations from the updated sketch", failures)
	_expect(layout.decorative_door_pixels.is_empty(), "all reference-map doors are backed by authored connections", failures)
	var expected_door_pixels := {
		Vector2i(7, 20): true, Vector2i(9, 20): true,
		Vector2i(5, 18): true, Vector2i(7, 18): true,
		Vector2i(9, 16): true, Vector2i(9, 14): true, Vector2i(11, 14): true,
		Vector2i(7, 12): true, Vector2i(9, 12): true, Vector2i(11, 12): true,
		Vector2i(11, 10): true, Vector2i(11, 8): true,
		Vector2i(7, 8): true, Vector2i(9, 8): true,
		Vector2i(5, 6): true, Vector2i(5, 8): true,
		Vector2i(9, 6): true, Vector2i(11, 6): true,
	}
	var actual_door_pixels := {}
	for connection in layout.connections:
		actual_door_pixels[connection.minimap_coordinate] = true
	_expect(layout.connections.size() == expected_door_pixels.size(), "Run 1 has one authored connection for each visible door pixel", failures)
	_expect(actual_door_pixels == expected_door_pixels, "Run 1 connections use exactly the dark-grey and colored door pixels from the sketch: %s" % str(actual_door_pixels), failures)

	var orb_rooms: Array = []
	for room in layout.rooms:
		if room.room_type == GRAPH_SCRIPT.ROOM_ORB:
			orb_rooms.append(room)
	_expect(orb_rooms.size() == 2, "Run 1 has two Orb Room instances", failures)
	if orb_rooms.size() == 2:
		_expect(orb_rooms[0].room_type == orb_rooms[1].room_type, "Orb Room locations share one runtime room type", failures)

	var requirements: Dictionary = {}
	for connection in layout.connections:
		if not connection.color_requirement.is_empty():
			requirements[connection.color_requirement] = int(requirements.get(connection.color_requirement, 0)) + 1
	_expect(not requirements.has(&"blue") and not requirements.has(&"green"), "map topology does not use flame color names as door keys", failures)
	_expect(requirements.has(&"puzzle_a") and requirements.has(&"puzzle_b"), "map topology has both semantic puzzle-color keys", failures)
	_expect(requirements.get(&"puzzle_a", 0) == 3, "reference map has three Puzzle Color A doors", failures)
	_expect(requirements.get(&"puzzle_b", 0) == 2, "reference map has two green/grey Puzzle Color B doors", failures)
	var expected_d9_connections := {
		"room_0_7:WALL_RIGHT": {"destination": &"room_1_9", "entry": DungeonGraph.BOTTOM_LEFT},
		"room_-3_8:WALL_RIGHT": {"destination": &"room_-1_9", "entry": DungeonGraph.BOTTOM_LEFT},
		"room_1_9:WALL_LEFT": {"destination": &"room_0_11", "entry": DungeonGraph.BOTTOM_RIGHT},
		"room_1_9:WALL_RIGHT": {"destination": &"room_2_11", "entry": DungeonGraph.BOTTOM_LEFT},
	}
	for connection_key in expected_d9_connections:
		var key_parts := String(connection_key).split(":")
		var source_id := StringName(key_parts[0])
		var exit_socket := StringName(key_parts[1])
		var connection = authored_connection(layout, source_id, exit_socket)
		var expected = expected_d9_connections[connection_key]
		_expect(connection != null and connection.destination_room_id == expected["destination"], "D9-area connector keeps its authored destination: %s" % connection_key, failures)
		_expect(connection != null and connection.destination_entry == expected["entry"], "D9-area connector arrives on the authored lower entrance: %s" % connection_key, failures)
	var first_orb_grey_requirement: StringName = &""
	var first_orb_primary_requirement: StringName = &""
	for connection in layout.connections:
		if connection.source_room_id == &"room_-1_1" and connection.destination_room_id == &"room_0_3":
			first_orb_grey_requirement = connection.color_requirement
		elif connection.source_room_id == &"room_-1_1" and connection.destination_room_id == &"room_-2_2":
			first_orb_primary_requirement = connection.color_requirement
	_expect(first_orb_grey_requirement == &"puzzle_b", "first Orb Room continuation is the green/grey Orb door", failures)
	_expect(first_orb_primary_requirement == &"puzzle_a", "first Orb Room treasure branch uses the blue selected-primary door", failures)

	var graph = GRAPH_SCRIPT.new()
	var controller = MAP_CONTROLLER_SCRIPT.new()
	controller.begin_run(graph, 90210, 0)
	_expect(controller.current_color() == MAP_STATE_SCRIPT.PUZZLE_COLOR_B, "Run 1 begins in the grey puzzle state", failures)
	_expect(controller.shared_orb_puzzle_color() == MAP_STATE_SCRIPT.PUZZLE_COLOR_B, "both Orb Rooms begin with the grey shared state", failures)
	_expect(controller.orb_display_palette() == &"grey", "Orb Rooms begin with grey in-world orbs", failures)
	_expect(controller.starter_palette() == "red", "the default starter flame resolves to the red palette", failures)
	_expect(controller.palette_for_requirement(&"puzzle_a") == "red", "Puzzle Color A doors resolve to the selected starter palette", failures)
	_expect(controller.palette_for_requirement(&"puzzle_b") == "grey", "Puzzle Color B doors resolve to grey", failures)
	_expect(controller.active_environment_palette() == "grey", "the grey map environment begins without an added tint", failures)
	var d9_down_left_entry: DungeonGraph.ConnectionRecord = graph.get_connection_for_entry(&"room_-1_9", GRAPH_SCRIPT.BOTTOM_LEFT)
	var d9_red_exit: DungeonGraph.ConnectionRecord = graph.get_connection(&"room_-1_9", GRAPH_SCRIPT.WALL_LEFT)
	_expect(d9_down_left_entry != null and d9_down_left_entry.source_room_id == &"room_-3_8" and d9_down_left_entry.allow_entry_before_source_clear, "D9 marks its down-left enemy branch as an early-open entrance", failures)
	_expect(controller.is_connection_available(d9_down_left_entry, true), "D9's down-left entrance is open before the branch enemies are defeated", failures)
	_expect(not controller.is_connection_available(d9_down_left_entry, false), "the down-left enemy room's own top exit remains clear-gated", failures)
	var d9_state := controller.get("state") as DungeonMapState
	if d9_state != null:
		d9_state.set_puzzle_color(&"puzzle_a")
	_expect(not controller.is_connection_available(d9_red_exit, false), "D9's red top door remains locked until D9 enemies are defeated", failures)
	controller.on_room_completed(&"room_-1_9")
	_expect(controller.is_connection_available(d9_red_exit, false), "D9's red door opens after its enemies are defeated", failures)
	if orb_rooms.size() == 2:
		var first_orb_id: StringName = &"room_-1_1"
		controller.on_room_entered(first_orb_id)
		_expect(not controller.change_orb_from_room(first_orb_id, &"blue"), "orb rejects a flame palette name", failures)
		_expect(controller.change_orb_from_room(first_orb_id, &"puzzle_a"), "orb accepts Puzzle Color A", failures)
		_expect(controller.current_color() == &"puzzle_a", "Puzzle Color A becomes globally active", failures)
		_expect(controller.shared_orb_puzzle_color() == &"puzzle_a", "shared orb state follows Puzzle Color A", failures)
		_expect(controller.orb_display_palette() == &"red", "activating Puzzle Color A dyes both Orb Rooms to the starter palette", failures)
		_expect(controller.active_environment_palette() == "red", "Puzzle Color A dyes the environment red", failures)
		_expect(controller.change_orb_from_room(first_orb_id, &"puzzle_b"), "the same Orb Room accepts Puzzle Color B later", failures)
		_expect(controller.current_color() == &"puzzle_b", "Puzzle Color B replaces Puzzle Color A globally", failures)
		_expect(controller.orb_display_palette() == &"grey", "activating Puzzle Color B returns both Orb Rooms to grey", failures)
		_expect(controller.active_environment_palette() == "grey", "Puzzle Color B returns the environment to grey", failures)

	controller.set_starter_flame(&"water")
	_expect(controller.starter_palette() == "blue", "water starter flame resolves to the blue palette", failures)
	_expect(controller.palette_for_requirement(&"puzzle_a") == "blue", "Puzzle Color A follows a water starter", failures)
	_expect(controller.palette_for_requirement(&"puzzle_b") == "grey", "Puzzle Color B remains grey for every starter", failures)

	_finish(failures)


func authored_connection(layout, source_room_id: StringName, exit_socket: StringName):
	for spec in layout.connections:
		if spec.source_room_id == source_room_id and spec.exit_socket == exit_socket:
			return spec
	return null


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN1_MAP_CONTRACT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
