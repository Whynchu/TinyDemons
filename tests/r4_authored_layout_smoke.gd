extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const RUN3_LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run3.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var layout = RUN3_LAYOUT_SCRIPT.build(&"water")
	var validation: Array[String] = layout.validate()
	_expect(validation.is_empty(), "R3 compiles into a valid reachable authored layout: %s" % ("ok" if validation.is_empty() else str(validation)), failures)
	_expect(layout.layout_id == &"RUN3", "R3 layout is identified as RUN3", failures)
	_expect(layout.map_size == Vector2i(35, 35), "R3 keeps the 35x35 authoring canvas", failures)
	_expect(layout.rooms.size() == 39, "R3 compiles 39 active room points", failures)
	_expect(layout.connections.size() == 42, "R3 compiles every one of its 42 gate pixels", failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_START) == 1, "R3 has one Hub", failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_BOSS) == 1, "R3 has one Boss room", failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_CLOAKED) == 1, "R3 has one Cloaked room", failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_ORB) == 2, "R3 has two Orb Rooms", failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_TREASURE) == 8, "R3 has eight Treasure Rooms", failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_FIRE) == 2, "R3 has two Fire Rooms", failures)

	var puzzle_a_count := 0
	var puzzle_b_count := 0
	var puzzle_c_count := 0
	var normal_count := 0
	var grey_orb_display_count := 0
	var down_path_count := 0
	for connection in layout.connections:
		match connection.color_requirement:
			&"puzzle_a":
				puzzle_a_count += 1
			&"puzzle_b":
				puzzle_b_count += 1
			&"puzzle_c":
				puzzle_c_count += 1
			_:
				normal_count += 1
		if connection.door_display_requirement == &"grey_orb":
			grey_orb_display_count += 1
		if not connection.color_requirement.is_empty():
			_expect(not connection.requires_source_room_clear, "R3 color-gated paths do not add a combat-clear lock after the Orb unlocks them", failures)
		if connection.exit_socket == GRAPH_SCRIPT.BOTTOM_LEFT or connection.exit_socket == GRAPH_SCRIPT.BOTTOM_RIGHT:
			down_path_count += 1
			_expect(not connection.requires_source_room_clear, "R3 down paths do not require the source room to be cleared", failures)
			_expect(connection.locks_entry_on_destination_engagement, "R3 down paths retain the destination engagement lock", failures)
		_expect(DungeonGraph.paired_socket(connection.exit_socket) == connection.destination_entry, "R3 connection keeps paired socket semantics", failures)
	_expect(puzzle_a_count == 8, "R3 maps Flame A to Puzzle A", failures)
	_expect(puzzle_b_count == 4, "R3 maps light-grey Orb doors to Puzzle B", failures)
	_expect(puzzle_c_count == 4, "R3 maps Flame B to Puzzle C", failures)
	_expect(normal_count == 26, "R3 preserves 26 ordinary grey entrances", failures)
	_expect(grey_orb_display_count == 4, "R3 preserves four distinct light-grey Orb door visuals", failures)
	_expect(down_path_count > 0, "R3 contains authored lower paths", failures)
	_expect(_has_stateful_route(layout), "R3 has a valid grey-to-Orb-to-Flame-B route to the Boss", failures)

	var hub_spec = layout.room_by_minimap_coordinate(Vector2i(17, 17))
	var lower_left_hub_gate = _connection_at(layout, Vector2i(16, 18))
	var upper_left_hub_gate = _connection_at(layout, Vector2i(16, 16))
	_expect(hub_spec != null and lower_left_hub_gate != null and lower_left_hub_gate.source_room_id == hub_spec.id and lower_left_hub_gate.exit_socket == GRAPH_SCRIPT.BOTTOM_LEFT, "R3 keeps the Hub down-left route as an authored lower socket", failures)
	_expect(hub_spec != null and upper_left_hub_gate != null and upper_left_hub_gate.source_room_id == hub_spec.id and upper_left_hub_gate.exit_socket == GRAPH_SCRIPT.WALL_LEFT, "R3 keeps the Hub upper-left route as an authored wall socket", failures)

	var graph = GRAPH_SCRIPT.new()
	var map = MAP_CONTROLLER_SCRIPT.new()
	root.add_child(map)
	map.begin_run(graph, 30917, 2, &"water")
	map.set_starter_flame_attuned(true)
	_expect(map.is_authored_run3() and map.is_authored_layout(), "Run 3 selects the authored R3 layout", failures)
	_expect(graph.get_room_ids().size() == 39, "Runtime graph consumes all R3 rooms without lazy topology", failures)
	# Compiler source/destination orientation must not make top-down traversal
	# require the lower room to have already been cleared. The room above has
	# already been cleared, so its incoming socket can now enter the uncleared
	# compiler source below.
	for gate_coordinate in [Vector2i(8, 20), Vector2i(10, 8), Vector2i(12, 4)]:
		var top_down_connection = _connection_at_runtime(graph, gate_coordinate)
		if top_down_connection != null:
			map.on_room_completed(top_down_connection.destination_room_id)
			map.on_room_entered(top_down_connection.destination_room_id)
		_expect(top_down_connection != null and map.is_connection_available(top_down_connection, true), "R3 gate %s permits top-down entry into its uncleared room" % gate_coordinate, failures)
	var orb_room_id: StringName = &""
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room != null and room.room_type == GRAPH_SCRIPT.ROOM_ORB:
			orb_room_id = room.id
			break
	_expect(not orb_room_id.is_empty(), "Runtime R3 graph exposes an Orb Room", failures)
	if not orb_room_id.is_empty():
		map.on_room_entered(orb_room_id)
		_expect(map.change_orb_from_room(orb_room_id, &"puzzle_a"), "R3 Orb Room can switch to Flame A", failures)
		_expect(map.current_color() == &"puzzle_a", "R3 Orb Room updates the active puzzle color", failures)
		_expect(map.change_orb_from_room(orb_room_id, &"puzzle_c"), "R3 Orb Room can switch to Flame B", failures)
		_expect(map.current_color() == &"puzzle_c", "R3 Orb Room exposes the first alternate Flame B state", failures)

	var light_gate = _connection_at_runtime(graph, Vector2i(6, 12))
	_expect(light_gate != null and map.connection_display_requirement(light_gate) == &"grey_orb", "Runtime light-grey gate keeps its distinct display key", failures)
	if light_gate != null:
		_expect(map.door_display_color(&"grey_orb") == PaletteLibrary.normal("grey_orb"), "Runtime light-grey gate resolves to the light Orb palette", failures)
	var map_state := map.get("state") as DungeonMapState
	if map_state != null:
		map_state.set_puzzle_color(&"puzzle_b")
	var scoutable_down_path: DungeonGraph.ConnectionRecord = null
	var scoutable_source: DungeonGraph.RoomRecord = null
	for room_id in graph.get_room_ids():
		var candidate_room := graph.get_room(room_id)
		if candidate_room == null:
			continue
		for outgoing_value in candidate_room.outgoing_connections.values():
			var candidate := outgoing_value as DungeonGraph.ConnectionRecord
			if candidate == null or (candidate.exit_socket != GRAPH_SCRIPT.BOTTOM_LEFT and candidate.exit_socket != GRAPH_SCRIPT.BOTTOM_RIGHT):
				continue
			if candidate.color_requirement != &"" and candidate.color_requirement != &"puzzle_b":
				continue
			if not map.requires_room_clear(candidate_room):
				continue
			scoutable_down_path = candidate
			scoutable_source = candidate_room
			break
		if scoutable_down_path != null:
			break
	_expect(scoutable_down_path != null, "R3 has an unlocked-state down path leaving an enemy room", failures)
	if scoutable_down_path != null and scoutable_source != null:
		map.on_room_entered(scoutable_source.id)
		_expect(map.is_connection_revealed(scoutable_down_path), "an unlocked R3 down path is revealed before its source encounter starts", failures)
		_expect(not map.is_connection_available(scoutable_down_path, false), "an unrelated R3 down path stays locked in an uncleared room", failures)
		map.on_room_entered(scoutable_source.id, scoutable_down_path.exit_socket)
		_expect(map.is_connection_available(scoutable_down_path, false), "the same R3 down path opens when it is the current visit's arrival", failures)
	var engagement_path: DungeonGraph.ConnectionRecord = null
	var engagement_source: DungeonGraph.RoomRecord = null
	for room_id in graph.get_room_ids():
		var candidate_room := graph.get_room(room_id)
		if candidate_room == null or not map.requires_room_clear(candidate_room):
			continue
		for outgoing_value in candidate_room.outgoing_connections.values():
			var candidate := outgoing_value as DungeonGraph.ConnectionRecord
			if candidate == null or candidate.color_requirement.is_empty() or candidate.requires_source_room_clear:
				continue
			engagement_path = candidate
			engagement_source = candidate_room
			break
		if engagement_path != null:
			break
	_expect(engagement_path != null, "R3 has a scoutable color door leaving an enemy room", failures)
	if engagement_path != null and engagement_source != null and map_state != null:
		map_state.set_puzzle_color(engagement_path.color_requirement)
		map.on_room_entered(engagement_source.id, engagement_path.exit_socket)
		_expect(map.is_connection_available(engagement_path, false), "R3 color arrival remains open before the source encounter starts", failures)
		_expect(map.mark_room_engaged(engagement_source.id), "R3 source encounter can commit after scouting the color door", failures)
		_expect(not map.is_connection_available(engagement_path, false), "R3 color door locks after source combat begins", failures)
		map.on_room_completed(engagement_source.id)
		_expect(map.is_connection_available(engagement_path, false), "R3 color door reopens after source combat is cleared", failures)
	map.queue_free()
	_finish(failures)


func _connection_at(layout, coordinate: Vector2i):
	for connection in layout.connections:
		if connection.minimap_coordinate == coordinate:
			return connection
	return null


func _connection_at_runtime(graph: DungeonGraph, coordinate: Vector2i):
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room == null:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			if connection != null and connection.minimap_coordinate == coordinate:
				return connection
	return null


func _room_type_count(layout, room_type: StringName) -> int:
	var count := 0
	for room in layout.rooms:
		if room.room_type == room_type:
			count += 1
	return count


func _has_stateful_route(layout) -> bool:
	var start = null
	for room in layout.rooms:
		if room.room_type == GRAPH_SCRIPT.ROOM_START:
			start = room
			break
	if start == null:
		return false
	var pending: Array[String] = ["%s|puzzle_b" % start.id]
	var visited: Dictionary = {}
	var available_colors: Array[StringName] = [&"puzzle_a", &"puzzle_b", &"puzzle_c", &"puzzle_d"]
	while not pending.is_empty():
		var state_key: String = String(pending.pop_front())
		if visited.has(state_key):
			continue
		visited[state_key] = true
		var separator := state_key.find("|")
		if separator < 1:
			continue
		var room_id: StringName = StringName(state_key.substr(0, separator))
		var active_color: StringName = StringName(state_key.substr(separator + 1))
		var room = layout.room_by_id(room_id)
		if room == null:
			continue
		if room.room_type == GRAPH_SCRIPT.ROOM_BOSS:
			return true
		if room.room_type == GRAPH_SCRIPT.ROOM_ORB:
			for next_color in available_colors:
				pending.append("%s|%s" % [room_id, next_color])
		for connection in layout.connections:
			var neighbor_id: StringName = &""
			if connection.source_room_id == room_id:
				neighbor_id = connection.destination_room_id
			elif connection.destination_room_id == room_id:
				neighbor_id = connection.source_room_id
			if neighbor_id.is_empty():
				continue
			var requirement: StringName = connection.color_requirement
			if requirement.is_empty() or requirement == active_color:
				pending.append("%s|%s" % [neighbor_id, active_color])
	return false


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("R3_AUTHORED_LAYOUT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
