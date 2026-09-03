extends SceneTree

const GENERATOR_SCRIPT = preload("res://scripts/dungeon_layout_generator.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const ROOM_CONTROLLER_SCRIPT = preload("res://scripts/room_controller.gd")
const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var first = GENERATOR_SCRIPT.build(24681357, 1, &"fire")
	var second = GENERATOR_SCRIPT.build(24681357, 1, &"fire")
	var different_seed = GENERATOR_SCRIPT.build(24681358, 1, &"fire")
	var first_validation: Array[String] = GENERATOR_SCRIPT.validate(first, 1, &"fire")
	_expect(first_validation.is_empty(), "generated Run 2 layout satisfies topology and color-route invariants", failures)
	var generated_hub = first.room_by_id(&"room_0_0")
	var lower_left_hub_connection = null
	var lower_right_hub_connection = null
	var hub_exit_sockets: Dictionary = {}
	for connection in first.connections:
		if connection.source_room_id != &"room_0_0":
			continue
		hub_exit_sockets[connection.exit_socket] = true
		if connection.exit_socket == GRAPH_SCRIPT.BOTTOM_LEFT:
			lower_left_hub_connection = connection
		elif connection.exit_socket == GRAPH_SCRIPT.BOTTOM_RIGHT:
			lower_right_hub_connection = connection
	_expect(generated_hub != null and hub_exit_sockets.has(GRAPH_SCRIPT.WALL_LEFT) and hub_exit_sockets.has(GRAPH_SCRIPT.WALL_RIGHT) and hub_exit_sockets.has(GRAPH_SCRIPT.BOTTOM_LEFT) and hub_exit_sockets.has(GRAPH_SCRIPT.BOTTOM_RIGHT), "generated Hub exposes all four directional exits", failures)
	_expect(lower_left_hub_connection != null and lower_left_hub_connection.destination_entry == GRAPH_SCRIPT.WALL_RIGHT and lower_left_hub_connection.route_role == &"dig" and not lower_left_hub_connection.requires_source_room_clear and lower_left_hub_connection.locks_entry_on_destination_engagement, "down-left Hub dig branch is scoutable and engagement-lockable", failures)
	_expect(lower_right_hub_connection != null and lower_right_hub_connection.destination_entry == GRAPH_SCRIPT.WALL_LEFT and lower_right_hub_connection.route_role == &"optional_treasure" and not lower_right_hub_connection.requires_source_room_clear and lower_right_hub_connection.locks_entry_on_destination_engagement, "down-right Hub branch is an optional scoutable Treasure route", failures)
	var generated_rare_exception_found := false
	var first_rare_result := [false]
	_expect(_rare_entry_exceptions_are_marked(first, first_rare_result), "generated layout marks rare lower-side enemy entrances without opening their top exits", failures)
	generated_rare_exception_found = bool(first_rare_result[0])
	_expect(_layout_signature(first) == _layout_signature(second), "same seed and run index generate the same complete layout", failures)
	_expect(_layout_signature(first) != _layout_signature(different_seed), "different seeds vary the generated layout", failures)

	var orb_count := 0
	var special_count := 0
	var treasure_count := 0
	var boss_depth := -1
	for room in first.rooms:
		if room.room_type == GRAPH_SCRIPT.ROOM_ORB:
			orb_count += 1
		elif room.room_type == GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY:
			special_count += 1
		elif room.room_type == GRAPH_SCRIPT.ROOM_TREASURE:
			treasure_count += 1
		elif room.room_type == GRAPH_SCRIPT.ROOM_BOSS:
			boss_depth = room.coordinate.y
		if room.room_type == GRAPH_SCRIPT.ROOM_TREASURE:
			_expect(room.chest_position == LAYOUT_DEFINITION_SCRIPT.TREASURE_CHEST_POSITION, "generated Treasure Rooms use the shared back-right chest position", failures)
	_expect(orb_count == 2, "generated layout contains two shared-state Orb Rooms", failures)
	_expect(special_count >= 2, "generated layout contains both Special Room route beats", failures)
	_expect(treasure_count >= 3, "generated layout contains optional Treasure branches", failures)
	_expect(boss_depth == 13, "Run 2 extends the boss depth beyond the authored Run 1 route", failures)
	_expect(_special_routes_have_progression_and_option_routes(first), "each generated Special Room has a progression route and a valid optional route", failures)
	var pacing_run_numbers: Array[int] = [3, 4, 5, 9, 10, 11, 12]
	var pacing_targets: Array[int] = [22, 23, 24, 24, 25, 25, 26]
	var pacing_boss_depths: Array[int] = [13, 14, 15, 15, 16, 16, 17]
	for pacing_index in pacing_run_numbers.size():
		var pacing_run_number := pacing_run_numbers[pacing_index]
		var pacing_layout = GENERATOR_SCRIPT.build(600000 + pacing_run_number, pacing_run_number - 1, &"fire")
		var pacing_boss_depth := -1
		for pacing_room in pacing_layout.rooms:
			if pacing_room.room_type == GRAPH_SCRIPT.ROOM_BOSS:
				pacing_boss_depth = pacing_room.coordinate.y
		_expect(GENERATOR_SCRIPT.generated_room_target_for_run(pacing_run_number) == pacing_targets[pacing_index], "generated room target stays on the approved soft curve at Run %d" % pacing_run_number, failures)
		_expect(pacing_boss_depth == pacing_boss_depths[pacing_index], "generated boss depth stays on the approved soft curve at Run %d" % pacing_run_number, failures)
		_expect(pacing_layout.rooms.size() >= pacing_targets[pacing_index], "generated route reaches its soft room target at Run %d" % pacing_run_number, failures)
		_expect(pacing_layout.rooms.size() <= pacing_targets[pacing_index] + 2, "generated optional branches do not run away from the room target at Run %d" % pacing_run_number, failures)
	var two_primary_special_found := false
	var detour_orb_count := 0
	var generated_fire_flames: Array[StringName] = []
	for room in first.rooms:
		if room.room_type == GRAPH_SCRIPT.ROOM_ORB:
			for connection in first.connections:
				if connection.destination_room_id == room.id and connection.route_role == &"detour_orb":
					detour_orb_count += 1
		if room.room_type == GRAPH_SCRIPT.ROOM_FIRE:
			generated_fire_flames.append(room.fire_flame)
	_expect(detour_orb_count == 1, "Run 2 places exactly one Orb Room on an exploratory detour", failures)
	_expect(generated_fire_flames.has(&"water") and not generated_fire_flames.has(&"electric"), "Run 2 exposes the first unchosen primary flame", failures)
	for run_index in range(1, 6):
		for seed_value in range(24):
			var sampled = GENERATOR_SCRIPT.build(500000 + seed_value, run_index)
			var sampled_validation: Array[String] = GENERATOR_SCRIPT.validate(sampled, run_index, &"fire")
			_expect(sampled_validation.is_empty(), "generated layout validates across sampled seeds and run depths", failures)
			var rare_result := [false]
			_expect(_rare_entry_exceptions_are_marked(sampled, rare_result), "generated rare lower-side enemy-branch entries remain directional across sampled seeds", failures)
			generated_rare_exception_found = generated_rare_exception_found or bool(rare_result[0])
			if _has_two_primary_special_room(sampled):
				two_primary_special_found = true
	for fusion_completed_runs in [5, 6, 7, 8]:
		for seed_value in range(8):
			var fusion_layout = GENERATOR_SCRIPT.build(700000 + seed_value * 7919, fusion_completed_runs, &"fire")
			var fusion_errors: Array[String] = GENERATOR_SCRIPT.validate(fusion_layout, fusion_completed_runs, &"fire")
			_expect(fusion_errors.is_empty(), "fusion Run %d validates across sampled seeds" % (fusion_completed_runs + 1), failures)
			var gate_count := _entrance_orb_gate_count(fusion_layout)
			var prerequisite_orb_count := _fusion_prerequisite_orb_count(fusion_layout)
			_expect(prerequisite_orb_count >= gate_count, "fusion Run %d gives every entrance-Orb gate a dedicated pre-gate Orb" % (fusion_completed_runs + 1), failures)
	_expect(generated_rare_exception_found, "seeded generated maps exercise the rare enemy-branch entry rule", failures)
	_expect(two_primary_special_found, "generated Special Rooms sometimes offer two distinct primary-color doors", failures)

	var graph = GRAPH_SCRIPT.new()
	graph.initialize_from_layout(24681357, first)
	var rooms_before := graph.get_room_ids().size()
	var rooms = ROOM_CONTROLLER_SCRIPT.new()
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		rooms.ensure_layout(graph, room_id, room, room.room_type, room.depth)
	_expect(graph.get_room_ids().size() == rooms_before, "generated room entry consumes the complete layout without lazily adding topology", failures)
	rooms.free()

	# Lower sockets are valid generated exits as well as authored arrival points.
	var four_way_graph = GRAPH_SCRIPT.new()
	four_way_graph.initialize(314159)
	var lower_left_connection = four_way_graph.ensure_connection(GRAPH_SCRIPT.START_ROOM_ID, GRAPH_SCRIPT.BOTTOM_LEFT, GRAPH_SCRIPT.ROOM_COMBAT)
	var lower_right_connection = four_way_graph.ensure_connection(GRAPH_SCRIPT.START_ROOM_ID, GRAPH_SCRIPT.BOTTOM_RIGHT, GRAPH_SCRIPT.ROOM_TREASURE)
	_expect(lower_left_connection != null and lower_left_connection.destination_entry == GRAPH_SCRIPT.WALL_RIGHT and four_way_graph.get_room(lower_left_connection.destination_room_id).coordinate == Vector2i(-1, -1), "runtime graph derives the down-left socket pair and offset", failures)
	_expect(lower_right_connection != null and lower_right_connection.destination_entry == GRAPH_SCRIPT.WALL_LEFT and four_way_graph.get_room(lower_right_connection.destination_room_id).coordinate == Vector2i(1, -1), "runtime graph derives the down-right socket pair and offset", failures)
	four_way_graph = null

	# A side branch can be inspected and abandoned before the first attack, then
	# becomes committed only after engagement and is escapable again when clear.
	var branch_graph = GRAPH_SCRIPT.new()
	var branch_map = MAP_CONTROLLER_SCRIPT.new()
	branch_map.begin_run(branch_graph, 24681357, 2, &"fire")
	branch_map.set_starter_flame_attuned(true)
	var branch_connection := branch_graph.get_connection(GRAPH_SCRIPT.START_ROOM_ID, GRAPH_SCRIPT.BOTTOM_LEFT)
	if branch_connection != null:
		var branch_room_id: StringName = branch_connection.destination_room_id
		_expect(branch_map.is_connection_available(branch_connection, false), "four-way Hub can enter its lower dig branch", failures)
		branch_map.on_room_entered(branch_room_id)
		_expect(branch_map.is_connection_available(branch_connection, true), "unengaged lower dig branch allows immediate retreat", failures)
		_expect(branch_map.mark_room_engaged(branch_room_id), "first attack engages the lower dig branch", failures)
		_expect(not branch_map.is_connection_available(branch_connection, true), "engaged lower dig branch locks its entrance", failures)
		branch_map.on_room_completed(branch_room_id)
		_expect(branch_map.is_connection_available(branch_connection, true), "cleared lower dig branch restores its return entrance", failures)
	else:
		_expect(false, "generated map exposes a lower dig branch for engagement testing", failures)
	branch_map.free()

	var run_graph = GRAPH_SCRIPT.new()
	var map = MAP_CONTROLLER_SCRIPT.new()
	map.begin_run(run_graph, 24681357, 2, &"water")
	_expect(not map.is_authored_layout() and map.has_complete_layout(), "Run 3 initializes from a generated complete layout after authored Run 2", failures)
	var first_orb_id: StringName = &""
	for room_id in run_graph.get_room_ids():
		var room := run_graph.get_room(room_id)
		if room != null and room.room_type == GRAPH_SCRIPT.ROOM_ORB:
			first_orb_id = room.id
			break
	if not first_orb_id.is_empty():
		map.on_room_entered(first_orb_id)
		_expect(map.change_orb_from_room(first_orb_id, &"puzzle_a"), "generated Orb Room changes the shared map puzzle color", failures)
		_expect(map.current_color() == &"puzzle_a", "generated map tracks the shared Orb Room color", failures)
		_expect(map.available_puzzle_colors().has(&"puzzle_c") and map.available_puzzle_colors().has(&"puzzle_d"), "Run 3 exposes both alternate puzzle colors", failures)
		_expect(map.puzzle_color_for_palette("red") == &"puzzle_c", "Run 3 maps the first alternate fire palette to Puzzle Color C", failures)
		_expect(map.change_orb_from_room(first_orb_id, &"puzzle_c"), "Run 3 Orb Room accepts the first alternate puzzle color", failures)
	else:
		_expect(false, "generated layout exposes an Orb Room to the map controller", failures)
	map.free()

	# Connection visuals and traversal use the same shared color state. A grey
	# route must become open when Puzzle B is active, even if the old room-wide
	# unlock flag is still false.
	var door_graph = GRAPH_SCRIPT.new()
	var door_map = MAP_CONTROLLER_SCRIPT.new()
	door_map.begin_run(door_graph, 24681357, 2, &"water")
	# The generated run exposes multiple Special Rooms with different door
	# colors; find the one that carries the puzzle_a/puzzle_b pair this section
	# asserts on rather than assuming the first special room is that room.
	var special_room: DungeonGraph.RoomRecord = null
	for room_id in door_graph.get_room_ids():
		var room := door_graph.get_room(room_id)
		if room == null or room.room_type != GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY:
			continue
		var has_puzzle_a := false
		var has_puzzle_b := false
		for connection in room.outgoing_connections.values():
			if connection.color_requirement == &"puzzle_a": has_puzzle_a = true
			if connection.color_requirement == &"puzzle_b": has_puzzle_b = true
		if has_puzzle_a and has_puzzle_b:
			special_room = room
			break
	if special_room != null:
		var special_a: DungeonGraph.ConnectionRecord = null
		var special_b: DungeonGraph.ConnectionRecord = null
		for connection in special_room.outgoing_connections.values():
			if connection.color_requirement == &"puzzle_a": special_a = connection
			if connection.color_requirement == &"puzzle_b": special_b = connection
		door_map.on_room_completed(special_room.id)
		var door_state := door_map.get("state") as DungeonMapState
		door_state.set_puzzle_color(&"puzzle_a")
		_expect(special_a != null and door_map.connection_visual_state(special_a) == &"open", "generated player-color door opens for the matching map state", failures)
		_expect(special_b != null and door_map.connection_visual_state(special_b) == &"orb_locked", "generated grey door remains color-locked for the other map state", failures)
		door_state.set_puzzle_color(&"puzzle_b")
		_expect(special_b != null and door_map.connection_visual_state(special_b) == &"open", "generated grey door opens when Puzzle B is active", failures)
	else:
		_expect(false, "generated layout exposes a Special Room with both door colors", failures)
	door_map.free()

	# The early fork rejoins at room_0_2. Its second incoming entrance must not
	# become a reverse-travel bypass into the uncleared sibling combat branch.
	var merge_graph = GRAPH_SCRIPT.new()
	var merge_map = MAP_CONTROLLER_SCRIPT.new()
	merge_map.begin_run(merge_graph, 24681357, 2, &"water")
	var left_merge_connection = merge_graph.get_connection(&"room_-1_1", GRAPH_SCRIPT.WALL_RIGHT)
	var right_merge_connection = merge_graph.get_connection(&"room_1_1", GRAPH_SCRIPT.WALL_LEFT)
	merge_map.on_room_completed(&"room_-1_1")
	merge_map.on_room_entered(&"room_0_2")
	_expect(merge_map.is_connection_available(left_merge_connection, true), "cleared fork branch keeps its merge entrance usable", failures)
	_expect(not merge_map.is_connection_available(right_merge_connection, true), "uncleared fork branch does not become reachable through the merge entrance", failures)
	merge_map.on_room_completed(&"room_1_1")
	_expect(merge_map.is_connection_available(right_merge_connection, true), "merge entrance opens once its source branch is cleared", failures)
	merge_map.free()
	_finish(failures)


func _special_routes_have_progression_and_option_routes(layout) -> bool:
	for room in layout.rooms:
		if room.room_type != GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY:
			continue
		var requirements: Dictionary = {}
		var primary_requirements: Dictionary = {}
		var route_roles: Dictionary = {}
		for connection in layout.connections:
			if connection.source_room_id == room.id:
				requirements[connection.color_requirement] = true
				route_roles[connection.route_role] = true
				if connection.color_requirement == &"puzzle_a" or connection.color_requirement == &"puzzle_c" or connection.color_requirement == &"puzzle_d":
					primary_requirements[connection.color_requirement] = true
		if requirements.has(&"puzzle_b"):
			if primary_requirements.size() < 1:
				return false
		elif primary_requirements.size() < 2:
			return false
		if not route_roles.has(&"key_progression") or not route_roles.has(&"optional_treasure"):
			return false
	return true


func _has_two_primary_special_room(layout) -> bool:
	for room in layout.rooms:
		if room.room_type != GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY:
			continue
		var primary_requirements: Dictionary = {}
		for connection in layout.connections:
			if connection.source_room_id != room.id:
				continue
			if connection.color_requirement == &"puzzle_a" or connection.color_requirement == &"puzzle_c" or connection.color_requirement == &"puzzle_d":
				primary_requirements[connection.color_requirement] = true
		if primary_requirements.size() >= 2:
			return true
	return false


func _entrance_orb_gate_count(layout) -> int:
	var count := 0
	for connection in layout.connections:
		if connection.resolved_gate_type() == GRAPH_SCRIPT.GATE_ENTRANCE_ORB:
			count += 1
	return count


func _fusion_prerequisite_orb_count(layout) -> int:
	var count := 0
	for connection in layout.connections:
		if connection.route_role != &"fusion_prerequisite_orb":
			continue
		for room in layout.rooms:
			if room.id == connection.destination_room_id and room.room_type == GRAPH_SCRIPT.ROOM_ORB:
				count += 1
				break
	return count


func _rare_entry_exceptions_are_marked(layout, found_out) -> bool:
	var found := false
	for connection in layout.connections:
		var source = layout.room_by_id(connection.source_room_id)
		var destination = layout.room_by_id(connection.destination_room_id)
		if source == null or destination == null:
			continue
		var source_delta: Vector2i = source.minimap_coordinate - destination.minimap_coordinate
		var is_lower_left_branch: bool = connection.destination_entry == GRAPH_SCRIPT.BOTTOM_LEFT and source_delta == Vector2i(-2, 2)
		var is_lower_right_branch: bool = connection.destination_entry == GRAPH_SCRIPT.BOTTOM_RIGHT and source_delta == Vector2i(2, 2)
		if not is_lower_left_branch and not is_lower_right_branch:
			continue
		if source.room_type != GRAPH_SCRIPT.ROOM_COMBAT and source.room_type != GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY and source.room_type != GRAPH_SCRIPT.ROOM_TREASURE:
			continue
		if destination.room_type != GRAPH_SCRIPT.ROOM_COMBAT and destination.room_type != GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY and destination.room_type != GRAPH_SCRIPT.ROOM_TREASURE:
			continue
		var destination_has_red_door := false
		for candidate in layout.connections:
			if candidate.source_room_id == destination.id and candidate.color_requirement == &"puzzle_a":
				destination_has_red_door = true
				break
		if not destination_has_red_door:
			continue
		found = true
		if not connection.allow_entry_before_source_clear or not connection.requires_source_room_clear:
			return false
	found_out[0] = found
	return true


func _layout_signature(layout) -> String:
	var parts: Array[String] = []
	for room in layout.rooms:
		parts.append("R:%s:%s:%s:%s:%s" % [room.id, room.coordinate, room.room_type, room.special_respawn_required_color, room.fire_flame])
	for connection in layout.connections:
		parts.append("C:%s:%s:%s:%s:%s" % [connection.source_room_id, connection.exit_socket, connection.destination_room_id, connection.color_requirement, connection.route_role])
	parts.sort()
	return "|".join(parts)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GENERATED_LAYOUT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
