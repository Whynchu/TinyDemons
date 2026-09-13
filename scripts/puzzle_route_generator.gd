extends RefCounted
class_name PuzzleRouteGenerator

## Generated route boundary. Runs 6 and later use the bounded risk/reward
## program; authored Runs 1-5 remain on their established layout scripts.

const LEGACY_GENERATOR = preload("res://scripts/dungeon_layout_generator.gd")
const LAYOUT_DEFINITION = preload("res://scripts/dungeon_layout_definition.gd")
const GRID = preload("res://scripts/puzzle_map_grid.gd")
const PROGRESSION_PLANNER = preload("res://scripts/puzzle_progression_planner.gd")
const ROUTE_SOLVER = preload("res://scripts/puzzle_route_solver.gd")
const ROUTE_PLAN = preload("res://scripts/puzzle_route_plan.gd")
const MAP_SIZE := Vector2i(35, 35)
const GENERATION_BUDGET_USEC := 50000
const RISK_REWARD_GENERATION_MODE: StringName = &"risk_reward_r6_plus"

static var last_generation_usec := 0
static var last_generation_repairs: Array[String] = []

static func build(dungeon_seed: int, completed_runs: int, starter_flame: StringName = &"fire", bound_flame: StringName = &""):
	var started_usec := Time.get_ticks_usec()
	last_generation_repairs.clear()
	# Own the runtime pipeline here. The compatibility assembler contributes only
	# its lower-level route construction primitive; the active R6+ policy is
	# applied by the typed risk/reward pass.
	var layout = LEGACY_GENERATOR.build_risk_reward(dungeon_seed, completed_runs, starter_flame, bound_flame) if completed_runs >= 5 else LEGACY_GENERATOR._build_candidate(int(dungeon_seed) ^ 0x524F5554, completed_runs, starter_flame, bound_flame)
	last_generation_repairs = LEGACY_GENERATOR.last_progression_repairs.duplicate()
	last_generation_usec = Time.get_ticks_usec() - started_usec
	var errors := validate(layout, completed_runs, starter_flame, bound_flame)
	if not last_generation_repairs.is_empty():
		errors.append("generated route required %d post-build progression repair(s)" % last_generation_repairs.size())
	for error in errors:
		push_error("generated route generation: %s" % error)
	return layout


static func _build_native_r7(dungeon_seed: int, starter_flame: StringName, bound_flame: StringName):
	var layout = LAYOUT_DEFINITION.new(&"RUN_GENERATED", MAP_SIZE)
	var route_rng := RandomNumberGenerator.new()
	route_rng.seed = int(dungeon_seed) ^ 0x5237
	var fusion_plan: Dictionary = LEGACY_GENERATOR._fusion_plan_for_run(6, starter_flame, bound_flame, dungeon_seed)
	var fusion_flames: Dictionary = fusion_plan.get("fire_flames", {}) as Dictionary
	var fusion_requirement: StringName = StringName((fusion_plan.get("entrance_orb_requirements", {}) as Dictionary).get(6, "ground"))
	var rooms: Dictionary = {}
	var used_coordinates: Dictionary = {}
	var serial_box: Array[int] = [0]
	var add_room: Callable = func(coordinate: Vector2i, room_type: StringName, chest_count: int = 0, fire_flame: StringName = &"") -> StringName:
		if used_coordinates.has(coordinate):
			return used_coordinates[coordinate]
		var room_id := StringName("room_%d_%d" % [coordinate.x, coordinate.y])
		var spec = layout.make_room_spec(room_id, coordinate, Vector2i(17, 32) + Vector2i(coordinate.x * 2, -coordinate.y * 2), room_type, chest_count, &"", dungeon_seed + serial_box[0], fire_flame)
		layout.add_room(spec)
		used_coordinates[coordinate] = room_id
		rooms[room_id] = spec
		serial_box[0] += 1
		return room_id
	var link: Callable = func(source_id: StringName, socket: StringName, destination_id: StringName, color: StringName = &"", gate_type: StringName = DungeonGraph.GATE_NONE, orb_requirement: StringName = &"", role: StringName = &"main") -> void:
		var source = rooms[source_id]
		var destination = rooms[destination_id]
		var midpoint := Vector2i((source.minimap_coordinate.x + destination.minimap_coordinate.x) / 2, (source.minimap_coordinate.y + destination.minimap_coordinate.y) / 2)
		layout.add_connection(layout.make_connection_spec(source_id, socket, destination_id, DungeonGraph.paired_socket(socket), color, false, &"", midpoint, true, true, role, false, &"", gate_type, orb_requirement))
	var current_id = add_room.call(Vector2i.ZERO, DungeonGraph.ROOM_START)
	var current_coordinate := Vector2i.ZERO
	var left_id = add_room.call(Vector2i(-1, 1), DungeonGraph.ROOM_COMBAT)
	var right_id = add_room.call(Vector2i(1, 1), DungeonGraph.ROOM_COMBAT)
	var merge_id = add_room.call(Vector2i(0, 2), DungeonGraph.ROOM_COMBAT)
	link.call(current_id, DungeonGraph.WALL_LEFT, left_id, &"", DungeonGraph.GATE_NONE, &"", &"fork")
	link.call(current_id, DungeonGraph.WALL_RIGHT, right_id, &"", DungeonGraph.GATE_NONE, &"", &"fork")
	link.call(left_id, DungeonGraph.WALL_RIGHT, merge_id, &"", DungeonGraph.GATE_NONE, &"", &"fork")
	link.call(right_id, DungeonGraph.WALL_LEFT, merge_id, &"", DungeonGraph.GATE_NONE, &"", &"fork")
	current_id = merge_id
	current_coordinate = Vector2i.ZERO + Vector2i(0, 2)
	var spine: Dictionary = {0: add_room.call(Vector2i.ZERO, DungeonGraph.ROOM_START), 2: merge_id}
	var direction := 1 if posmod(dungeon_seed, 2) == 0 else -1
	for depth in range(3, 14):
		var next_coordinate := current_coordinate + Vector2i(direction, 1)
		if depth == 13:
			next_coordinate = current_coordinate + Vector2i(-direction, 1)
		var room_type := DungeonGraph.ROOM_COMBAT
		var flame: StringName = &""
		if depth == 4:
			room_type = DungeonGraph.ROOM_SPECIAL_ENEMY
		elif depth == 11:
			room_type = DungeonGraph.ROOM_CLOAKED
		elif depth == 12:
			room_type = DungeonGraph.ROOM_SPECIAL_ENEMY
		elif depth == 3:
			room_type = DungeonGraph.ROOM_ORB
		elif depth == 5:
			room_type = DungeonGraph.ROOM_FIRE
			flame = StringName(fusion_flames.get(5, &"fire"))
		elif depth == 6:
			room_type = DungeonGraph.ROOM_FIRE
			flame = StringName(fusion_flames.get(6, &"electric"))
		elif depth == 13:
			room_type = DungeonGraph.ROOM_BOSS
		var destination_id = add_room.call(next_coordinate, room_type, 0, flame)
		var socket: StringName = DungeonGraph.WALL_RIGHT if next_coordinate.x > current_coordinate.x else DungeonGraph.WALL_LEFT
		var color: StringName = &"puzzle_a" if depth == 4 else &""
		var gate_type := DungeonGraph.GATE_NONE
		var orb_requirement: StringName = &""
		if depth == 7:
			gate_type = DungeonGraph.GATE_ENTRANCE_ORB
			orb_requirement = fusion_requirement
		link.call(current_id, socket, destination_id, color, gate_type, orb_requirement, &"key_progression" if depth == 4 or depth == 7 else &"main")
		spine[depth] = destination_id
		current_id = destination_id
		current_coordinate = next_coordinate
		if depth % 2 == 0 and route_rng.randf() < 0.78:
			direction = -direction
	# The R7 fusion Orb is deliberately attached to the room before the gate.
	# The gate itself is the depth-6 entrance into the next state, so the Orb
	# must be reachable while that entrance edge is blocked.
	var gate_source: StringName = spine[6]
	var gate_spec = rooms[gate_source]
	var orb_socket: StringName = DungeonGraph.WALL_LEFT
	for candidate_socket in [DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT]:
		var socket_used := false
		for existing_connection in layout.connections:
			if existing_connection.source_room_id == gate_source and existing_connection.exit_socket == candidate_socket:
				socket_used = true
				break
		if not socket_used:
			orb_socket = candidate_socket
			break
	var orb_coordinate: Vector2i = gate_spec.coordinate + DungeonGraph.exit_offset(orb_socket)
	var fusion_orb = add_room.call(orb_coordinate, DungeonGraph.ROOM_ORB)
	link.call(gate_source, orb_socket, fusion_orb, &"", DungeonGraph.GATE_NONE, &"", &"fusion_prerequisite_orb")
	# Add deterministic reward pockets to reach the compact R7 density target.
	for depth in [2, 3, 4, 5, 7, 8, 9, 10, 11, 12]:
		var source = rooms[spine[depth]]
		var side_socket: StringName = DungeonGraph.WALL_LEFT if route_rng.randi_range(0, 1) == 0 else DungeonGraph.WALL_RIGHT
		if depth == 4:
			# Keep the authored-looking first Special Room readable: its optional
			# grey door is always on the first available side, while later pockets
			# can vary freely with the seed.
			side_socket = DungeonGraph.WALL_RIGHT if source.coordinate.x <= 0 else DungeonGraph.WALL_LEFT
		var side_coordinate: Vector2i = source.coordinate + DungeonGraph.exit_offset(side_socket)
		if used_coordinates.has(side_coordinate):
			side_socket = DungeonGraph.WALL_RIGHT if side_socket == DungeonGraph.WALL_LEFT else DungeonGraph.WALL_LEFT
			side_coordinate = source.coordinate + DungeonGraph.exit_offset(side_socket)
		var side_id = add_room.call(side_coordinate, DungeonGraph.ROOM_TREASURE, 1)
		if side_id != spine[depth]:
			var side_color: StringName = &"puzzle_b" if depth == 4 else &""
			var destination_entry := DungeonGraph.paired_socket(side_socket)
			var destination_entry_used := false
			for existing in layout.connections:
				if existing.destination_room_id == side_id and existing.destination_entry == destination_entry:
					destination_entry_used = true
					break
			if not destination_entry_used:
				link.call(spine[depth], side_socket, side_id, side_color, DungeonGraph.GATE_NONE, &"", &"optional_treasure")
	return layout


static func generation_within_budget() -> bool:
	return last_generation_usec <= GENERATION_BUDGET_USEC


static func generation_is_repair_free() -> bool:
	return last_generation_repairs.is_empty()


static func validate(layout, completed_runs: int, starter_flame: StringName = &"fire", bound_flame: StringName = &"") -> Array[String]:
	if layout == null:
		return ["generated route layout is missing"]
	var is_risk_reward_layout: bool = layout.generation_mode == RISK_REWARD_GENERATION_MODE
	var errors: Array[String] = LEGACY_GENERATOR.validate_risk_reward(layout, completed_runs, starter_flame, bound_flame) if is_risk_reward_layout else LEGACY_GENERATOR.validate(layout, completed_runs, starter_flame, bound_flame)
	for room in layout.rooms:
		if not _in_compact_bounds(room.minimap_coordinate):
			errors.append("generated room %s falls outside the compact 35x35 map at %s" % [room.id, room.minimap_coordinate])
	for connection in layout.connections:
		if not _in_compact_bounds(connection.minimap_coordinate):
			errors.append("generated connection %s:%s falls outside the compact 35x35 map at %s" % [connection.source_room_id, connection.exit_socket, connection.minimap_coordinate])
	var route_plan = ROUTE_PLAN.from_layout(layout)
	errors.append_array(route_plan.validate_structure(MAP_SIZE))
	if completed_runs == 6 and not is_risk_reward_layout and (layout.rooms.size() < 24 or layout.rooms.size() > 30):
		errors.append("legacy generated R7 route must contain 24-30 rooms, got %d" % layout.rooms.size())
	if is_risk_reward_layout:
		errors.append_array(PROGRESSION_PLANNER.validate_risk_reward(route_plan))
		var risk_start_id: StringName = &""
		for room in layout.rooms:
			if room.room_type == DungeonGraph.ROOM_START:
				risk_start_id = room.id
				break
		errors.append_array(ROUTE_SOLVER.validate_risk_reward(layout, risk_start_id))
	elif completed_runs >= 6:
		errors.append_array(PROGRESSION_PLANNER.validate(route_plan))
		var start_id: StringName = &""
		for room in layout.rooms:
			if room.room_type == DungeonGraph.ROOM_START:
				start_id = room.id
				break
		errors.append_array(ROUTE_SOLVER.validate_ordered_fusion(layout, start_id, completed_runs, starter_flame, bound_flame))
	return errors


static func _in_compact_bounds(coordinate: Vector2i) -> bool:
	return coordinate.x >= 0 and coordinate.y >= 0 and coordinate.x < MAP_SIZE.x and coordinate.y < MAP_SIZE.y


static func repair_progression(layout, completed_runs: int, starter_flame: StringName = &"fire", bound_flame: StringName = &"") -> Array[String]:
	if layout != null and layout.generation_mode == RISK_REWARD_GENERATION_MODE:
		# The risk/reward program is validated after all optional vault metadata is
		# assigned. Recovery must not reintroduce the legacy mandatory gate loop.
		var no_repairs: Array[String] = []
		return no_repairs
	if completed_runs == 6:
		# Native R7 is a hard-validated route. It must never be mutated by the
		# legacy recovery repair pass.
		var no_repairs: Array[String] = []
		return no_repairs
	return LEGACY_GENERATOR.repair_progression(layout, completed_runs, starter_flame, bound_flame)


static func is_native_r7(completed_runs: int) -> bool:
	return false


static func is_risk_reward_layout(completed_runs: int) -> bool:
	return completed_runs >= 5


static func build_compact_plan(dungeon_seed: int, completed_runs: int, starter_flame: StringName = &"fire", bound_flame: StringName = &"") -> PuzzleMapGrid.MapPlan:
	## Produce the presentation plan from the exact selected runtime candidate.
	## This keeps preview and gameplay anchored to one deterministic result while
	## the typed topology metadata is being moved into the compact planner.
	var layout = build(dungeon_seed, completed_runs, starter_flame, bound_flame)
	var plan := GRID.MapPlan.new(StringName("R6_PLUS_%d" % dungeon_seed))
	if layout == null:
		return plan
	plan.generation_mode = layout.generation_mode
	plan.route_choice_source_room_id = layout.route_choice_source_room_id
	plan.route_choice_rejoin_room_id = layout.route_choice_rejoin_room_id
	plan.safe_route_length = layout.safe_route_length
	plan.risk_route_length = layout.risk_route_length
	for room in layout.rooms:
		var coordinate: Vector2i = room.minimap_coordinate
		if coordinate.x < 0 or coordinate.y < 0 or coordinate.x >= MAP_SIZE.x or coordinate.y >= MAP_SIZE.y:
			continue
		var room_marker := _marker_for_room(room)
		if room_marker.is_empty():
			plan.add_active_tile(coordinate)
		else:
			plan.add_marker(coordinate, room_marker)
	for connection in layout.connections:
		var source_region := ROUTE_PLAN._region_for_room(layout.rooms, connection.source_room_id)
		var destination_region := ROUTE_PLAN._region_for_room(layout.rooms, connection.destination_room_id)
		plan.add_logical_edge({
			"source_room_id": connection.source_room_id,
			"destination_room_id": connection.destination_room_id,
			"source_socket": connection.exit_socket,
			"destination_socket": connection.destination_entry,
			"coordinate": connection.minimap_coordinate,
			"route_role": connection.route_role,
			"source_region": source_region,
			"destination_region": destination_region,
			"gate_type": connection.resolved_gate_type(),
			"color_requirement": connection.color_requirement,
			"element_requirement": connection.element_requirement,
			"orb_element_requirement": connection.orb_element_requirement,
			"source_room_role": layout.room_by_id(connection.source_room_id).route_role if layout.room_by_id(connection.source_room_id) != null else &"",
			"destination_room_role": layout.room_by_id(connection.destination_room_id).route_role if layout.room_by_id(connection.destination_room_id) != null else &"",
			"prerequisite_identity": connection.route_role == &"fusion_prerequisite_orb" or connection.resolved_gate_type() == DungeonGraph.GATE_ENTRANCE_ORB,
		})
		var marker_kind := _marker_for_connection(connection)
		if marker_kind.is_empty():
			continue
		var coordinate: Vector2i = connection.minimap_coordinate
		if coordinate.x >= 0 and coordinate.y >= 0 and coordinate.x < MAP_SIZE.x and coordinate.y < MAP_SIZE.y:
			plan.add_marker(coordinate, marker_kind)
	return plan


static func _marker_for_room(room) -> StringName:
	if room == null:
		return &""
	if room.route_role == DungeonGraph.ROUTE_ELITE_REWARD:
		return GRID.MARKER_VAULT_ROOM
	if room.route_role == DungeonGraph.ROUTE_RISK_SHORTCUT:
		return GRID.MARKER_DANGER_ROOM
	if room.route_role == DungeonGraph.ROUTE_PRIMARY_FLAME:
		match room.fire_flame:
			&"fire": return GRID.MARKER_FLAME_FIRE_ROOM
			&"water": return GRID.MARKER_FLAME_WATER_ROOM
			&"electric": return GRID.MARKER_FLAME_ELECTRIC_ROOM
	match room.room_type:
		DungeonGraph.ROOM_START: return GRID.MARKER_HUB_ROOM
		DungeonGraph.ROOM_BOSS: return GRID.MARKER_BOSS_ROOM
		DungeonGraph.ROOM_ORB: return GRID.MARKER_ORB_ROOM
		DungeonGraph.ROOM_FIRE: return GRID.MARKER_FLAME_B_ROOM
		DungeonGraph.ROOM_TREASURE: return GRID.MARKER_TREASURE_ROOM
		DungeonGraph.ROOM_CLOAKED: return GRID.MARKER_CLOAKED_ROOM
	return &""


static func _marker_for_connection(connection) -> StringName:
	if connection.route_role == DungeonGraph.ROUTE_ELEMENTAL_VAULT:
		return GRID.MARKER_GATE_VAULT
	if connection.resolved_gate_type() == DungeonGraph.GATE_ENTRANCE_ORB:
		return GRID.MARKER_GATE_ORB_GREY
	if connection.color_requirement == &"puzzle_a":
		return GRID.MARKER_GATE_FLAME_A
	if connection.color_requirement == &"puzzle_b":
		return GRID.MARKER_GATE_GREY
	if connection.color_requirement == &"puzzle_c" or connection.color_requirement == &"puzzle_d":
		return GRID.MARKER_GATE_FLAME_B
	return &""
