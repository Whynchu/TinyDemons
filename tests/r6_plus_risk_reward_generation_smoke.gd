extends SceneTree

const ROUTE_GENERATOR = preload("res://scripts/puzzle_route_generator.gd")
const LAYOUT_GENERATOR = preload("res://scripts/dungeon_layout_generator.gd")
const GRAPH = preload("res://scripts/dungeon_graph.gd")
const ROOM_CONTROLLER = preload("res://scripts/room_controller.gd")
const GRID = preload("res://scripts/puzzle_map_grid.gd")
const ELEMENTS = preload("res://scripts/element_catalog.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var sampled_runs: Array[int] = [5, 6, 9, 12]
	var sampled_starters: Array[StringName] = [&"fire", &"water", &"electric"]
	var sampled_seeds: Array[int] = [12001, 78123, 440917, 991337]
	for completed_runs in sampled_runs:
		for starter in sampled_starters:
			for dungeon_seed in sampled_seeds:
				_assert_risk_reward_layout(dungeon_seed, completed_runs, starter, failures)
	if failures.is_empty():
		print("R6_PLUS_RISK_REWARD_GENERATION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _assert_risk_reward_layout(dungeon_seed: int, completed_runs: int, starter: StringName, failures: Array[String]) -> void:
	var layout = ROUTE_GENERATOR.build(dungeon_seed, completed_runs, starter)
	_assert(layout != null, "R%d seed %d %s returns a layout" % [completed_runs + 1, dungeon_seed, starter], failures)
	if layout == null:
		return
	var errors: Array[String] = ROUTE_GENERATOR.validate(layout, completed_runs, starter)
	_assert(errors.is_empty(), "R%d seed %d %s validates: %s" % [completed_runs + 1, dungeon_seed, starter, "; ".join(errors)], failures)
	_assert(layout.generation_mode == LAYOUT_GENERATOR.RISK_REWARD_GENERATION_MODE, "R%d uses the risk/reward generation mode" % (completed_runs + 1), failures)
	_assert(layout.safe_route_length > layout.risk_route_length + 1, "R%d exposes a materially shorter risk route" % (completed_runs + 1), failures)

	var primary_flames: Dictionary = {}
	var vault_rooms: Dictionary = {}
	for room in layout.rooms:
		if room.route_role == GRAPH.ROUTE_PRIMARY_FLAME and room.fire_flame in [&"fire", &"water", &"electric"]:
			primary_flames[room.fire_flame] = room.id
		if room.route_role == GRAPH.ROUTE_ELITE_REWARD:
			vault_rooms[room.id] = true
	_assert(primary_flames.size() == 3, "R%d has Fire, Water, and Electric primary flame rooms" % (completed_runs + 1), failures)
	for flame in [&"fire", &"water", &"electric"]:
		_assert(primary_flames.has(flame), "R%d exposes the %s primary flame" % [completed_runs + 1, flame], failures)

	var vault_connections := 0
	var risk_room_count := 0
	var safe_room_count := 0
	for room in layout.rooms:
		if room.route_role == GRAPH.ROUTE_RISK_SHORTCUT:
			risk_room_count += 1
		if room.route_role == GRAPH.ROUTE_SAFE:
			safe_room_count += 1
	_assert(risk_room_count >= 1 and safe_room_count >= 1, "R%d emits both safe and dangerous route rooms" % (completed_runs + 1), failures)
	for connection in layout.connections:
		if connection.route_role == GRAPH.ROUTE_ELEMENTAL_VAULT:
			vault_connections += 1
			_assert(connection.resolved_gate_type() == GRAPH.GATE_ENTRANCE_ORB, "vault door uses the entrance Orb gate contract", failures)
			_assert(ELEMENTS.is_valid_id(connection.orb_element_requirement), "vault door uses a supported non-neutral Orb element", failures)
			_assert(vault_rooms.has(connection.destination_room_id), "vault door leads to an elite reward room", failures)
		else:
			_assert(connection.resolved_gate_type() == GRAPH.GATE_NONE, "non-vault R6+ connection stays ungated", failures)
	_assert(vault_connections >= 1 and vault_connections <= 2, "R%d emits one or two optional elemental vaults" % (completed_runs + 1), failures)

	var graph := GRAPH.new()
	graph.initialize_from_layout(dungeon_seed, layout)
	var rooms := ROOM_CONTROLLER.new()
	rooms.progression_run_rank = completed_runs + 1
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		var state: Dictionary = rooms.ensure_layout(graph, room_id, room, room.room_type, room.depth)
		_assert(state.get("route_role", &"") == room.route_role, "room state carries route role metadata", failures)
		_assert(state.get("reward_tier", &"") == room.reward_tier, "room state carries reward metadata", failures)
		if room.route_role == GRAPH.ROUTE_ELITE_REWARD:
			_assert(state.get("encounter_tier", &"") == GRAPH.ENCOUNTER_ELITE, "elite vault state uses the elite encounter tier", failures)
			_assert((state.get("enemy_variants", []) as Array).size() > 0, "elite vault state creates an encounter", failures)
			var elite_flags := state.get("enemy_elite", []) as Array
			var elite_levels := state.get("enemy_levels", []) as Array
			var elite_popcorn := state.get("enemy_popcorn", []) as Array
			var normal_encounter := rooms.call("_generate_enemy_encounter", room.generation_seed, room.depth, true, true, GRAPH.ENCOUNTER_NORMAL) as Dictionary
			var normal_max_level := 0
			for normal_level in normal_encounter.get("levels", []) as Array:
				normal_max_level = maxi(normal_max_level, int(normal_level))
			var elite_count := 0
			for slot in elite_flags.size():
				if bool(elite_flags[slot]):
					elite_count += 1
					_assert(slot < elite_levels.size() and int(elite_levels[slot]) > normal_max_level, "elite vault slime uses a level above the normal encounter band", failures)
					_assert(slot >= elite_popcorn.size() or not bool(elite_popcorn[slot]), "elite marker excludes low-level popcorn support", failures)
			_assert(elite_count >= 1, "elite vault state marks at least one slime as elite", failures)
	rooms.free()

	var plan := ROUTE_GENERATOR.build_compact_plan(dungeon_seed, completed_runs, starter)
	_assert(plan.generation_mode == LAYOUT_GENERATOR.RISK_REWARD_GENERATION_MODE, "compact plan preserves the R6+ generation mode", failures)
	_assert(plan.route_choice_source_room_id == layout.route_choice_source_room_id and plan.route_choice_rejoin_room_id == layout.route_choice_rejoin_room_id, "compact plan preserves safe/risk choice endpoints", failures)
	_assert(plan.safe_route_length == layout.safe_route_length and plan.risk_route_length == layout.risk_route_length, "compact plan preserves safe/risk route lengths", failures)
	_assert(plan.logical_edges.size() == layout.connections.size(), "compact plan preserves generated logical edges", failures)
	_assert(plan.marker_count(GRID.MARKER_FLAME_FIRE_ROOM) >= 1, "compact plan marks the Fire flame", failures)
	_assert(plan.marker_count(GRID.MARKER_FLAME_WATER_ROOM) >= 1, "compact plan marks the Water flame", failures)
	_assert(plan.marker_count(GRID.MARKER_FLAME_ELECTRIC_ROOM) >= 1, "compact plan marks the Electric flame", failures)
	_assert(plan.marker_count(GRID.MARKER_DANGER_ROOM) >= 1, "compact plan marks the dangerous shortcut", failures)
	_assert(plan.marker_count(GRID.MARKER_VAULT_ROOM) >= 1, "compact plan marks the elite vault", failures)
	_assert(plan.marker_count(GRID.MARKER_GATE_VAULT) == vault_connections, "compact plan marks every elemental vault door", failures)

	var repeat = ROUTE_GENERATOR.build(dungeon_seed, completed_runs, starter)
	_assert(_layout_signature(layout) == _layout_signature(repeat), "R%d generation remains deterministic" % (completed_runs + 1), failures)


func _layout_signature(layout) -> String:
	var rooms: Array[String] = []
	for room in layout.rooms:
		rooms.append("%s:%s:%s:%s:%s:%s:%s" % [room.id, room.coordinate, room.room_type, room.route_role, room.encounter_tier, room.reward_tier, room.vault_id])
	rooms.sort()
	var connections: Array[String] = []
	for connection in layout.connections:
		connections.append("%s:%s:%s:%s:%s:%s" % [connection.source_room_id, connection.exit_socket, connection.destination_room_id, connection.route_role, connection.resolved_gate_type(), connection.orb_element_requirement])
	connections.sort()
	return "%s||%s" % ["|".join(rooms), "|".join(connections)]


func _assert(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
