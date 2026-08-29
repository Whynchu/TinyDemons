extends RefCounted
class_name DungeonLayoutGenerator

## Deterministic Run 3+ topology generator.
##
## Run 1 is the hand-authored teaching map and Run 2 is its authored expansion.
## Run 3+ uses the same
## vocabulary (forks, combat gates, shared Orb Rooms, Special Room key routes,
## optional Treasure branches, utility rooms, and a boss approach), but emit a
## complete layout before the player enters the dungeon.

const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")
const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const ELEMENT_CATALOG_SCRIPT = preload("res://scripts/element_catalog.gd")

const GENERATED_LAYOUT_ID: StringName = &"RUN_GENERATED"
const BASE_BOSS_DEPTH := 12
const MAX_EXTRA_BOSS_DEPTH := 4
const FIRST_ORB_DEPTH := 3
const FIRST_SPECIAL_DEPTH := 4

const ROUTE_MAIN: StringName = &"main"
const ROUTE_FORK: StringName = &"fork"
const ROUTE_OPTIONAL_TREASURE: StringName = &"optional_treasure"
const ROUTE_KEY_PROGRESSION: StringName = &"key_progression"
const ROUTE_DETOUR_ORB: StringName = &"detour_orb"
const ROUTE_DETOUR_FIRE: StringName = &"detour_fire"


class LayoutBuilder extends RefCounted:
	var layout
	var dungeon_seed: int
	var room_ids_by_coordinate: Dictionary = {}
	var room_specs_by_id: Dictionary = {}
	var connection_keys: Dictionary = {}


	func _init(new_layout, new_dungeon_seed: int) -> void:
		layout = new_layout
		dungeon_seed = new_dungeon_seed


	func add_room(
		coordinate: Vector2i,
		room_type: StringName,
		chest_count: int = 0,
		special_respawn_color: StringName = &"",
		fire_flame: StringName = &""
	) -> StringName:
		if room_ids_by_coordinate.has(coordinate):
			return room_ids_by_coordinate[coordinate] as StringName
		var room_id := StringName("room_%d_%d" % [coordinate.x, coordinate.y])
		var seed_salt := ("%d:%d:%d" % [dungeon_seed, coordinate.x, coordinate.y]).hash()
		# Dungeon depth increases toward the boss, while the player-facing map
		# presents the boss at the top and the Hub at the bottom, like Run 1.
		# Keep the runtime lattice coordinate untouched and transform only the
		# presentation coordinate.
		var minimap_coordinate := Vector2i(coordinate.x * 2, -coordinate.y * 2)
		var spec = layout.make_room_spec(room_id, coordinate, minimap_coordinate, room_type, chest_count, special_respawn_color, seed_salt, fire_flame)
		layout.add_room(spec)
		room_ids_by_coordinate[coordinate] = room_id
		room_specs_by_id[room_id] = spec
		return room_id


	func room_spec(room_id: StringName):
		return room_specs_by_id.get(room_id)


	func link(
		source_room_id: StringName,
		exit_socket: StringName,
		destination_room_id: StringName,
		color_requirement: StringName = &"",
		route_role: StringName = ROUTE_MAIN,
		requires_source_room_clear: bool = true,
		locks_entry_on_destination_engagement: bool = true,
		element_requirement: StringName = &""
	) -> void:
		var key := "%s:%s" % [source_room_id, exit_socket]
		if connection_keys.has(key):
			push_error("Generated layout attempted to reuse exit socket %s." % key)
			return
		var source = room_spec(source_room_id)
		var destination = room_spec(destination_room_id)
		if source == null or destination == null:
			push_error("Generated layout attempted to link a missing room.")
			return
		var destination_entry := DungeonGraph.BOTTOM_RIGHT if exit_socket == DungeonGraph.WALL_LEFT else DungeonGraph.BOTTOM_LEFT
		var midpoint_sum: Vector2i = source.minimap_coordinate + destination.minimap_coordinate
		var midpoint: Vector2i = Vector2i(int(float(midpoint_sum.x) / 2.0), int(float(midpoint_sum.y) / 2.0))
		layout.add_connection(layout.make_connection_spec(
			source_room_id,
			exit_socket,
			destination_room_id,
			destination_entry,
			color_requirement,
			false,
			&"",
			midpoint,
			requires_source_room_clear,
			locks_entry_on_destination_engagement,
			route_role,
			false,
			element_requirement
		))
		connection_keys[key] = true


static func build(dungeon_seed: int, completed_runs: int, selected_starter_flame: StringName = &"fire"):
	var run_index := maxi(completed_runs, 1)
	var starter_flame := selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var alternate_flames: Array[StringName] = ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(completed_runs, starter_flame)
	var boss_depth := BASE_BOSS_DEPTH + mini(run_index, MAX_EXTRA_BOSS_DEPTH)
	var generator_rng := RandomNumberGenerator.new()
	generator_rng.seed = int(dungeon_seed) ^ (run_index * 104729) ^ 0x47E2
	var layout = LAYOUT_DEFINITION_SCRIPT.new(GENERATED_LAYOUT_ID, Vector2i(96, boss_depth + 3))
	var builder := LayoutBuilder.new(layout, dungeon_seed)

	# Every generated run begins with an intentional fork that rejoins before
	# the first Orb Room. This gives R2+ the same early choice-and-convergence
	# rhythm as Run 1 without allowing an unbounded tree to grow at runtime.
	var start_id := builder.add_room(Vector2i(0, 0), DungeonGraph.ROOM_START)
	var left_id := builder.add_room(Vector2i(-1, 1), DungeonGraph.ROOM_COMBAT)
	var right_id := builder.add_room(Vector2i(1, 1), DungeonGraph.ROOM_COMBAT)
	var merge_id := builder.add_room(Vector2i(0, 2), DungeonGraph.ROOM_COMBAT)
	builder.link(start_id, DungeonGraph.WALL_LEFT, left_id, &"", ROUTE_FORK, false)
	builder.link(start_id, DungeonGraph.WALL_RIGHT, right_id, &"", ROUTE_FORK, false)
	builder.link(left_id, DungeonGraph.WALL_RIGHT, merge_id, &"", ROUTE_FORK)
	builder.link(right_id, DungeonGraph.WALL_LEFT, merge_id, &"", ROUTE_FORK)

	var second_orb_depth := boss_depth - 4
	var second_special_depth := boss_depth - 2
	var cloaked_depth := clampi(int(float(boss_depth) / 2.0), 6, boss_depth - 5)
	var fire_depth := clampi(boss_depth - 6, 6, boss_depth - 5)
	var first_alternate_fire_depth := -1
	var fusion_plan := _fusion_plan_for_run(completed_runs, starter_flame)
	var fusion_fire_flames: Dictionary = fusion_plan.get("fire_flames", {}) as Dictionary
	var fusion_gate_requirements: Dictionary = fusion_plan.get("gate_requirements", {}) as Dictionary
	var off_route_orbs := _off_route_orb_depths(dungeon_seed, run_index, FIRST_ORB_DEPTH, second_orb_depth)
	if fire_depth == cloaked_depth:
		fire_depth = mini(fire_depth + 1, boss_depth - 5)
	if alternate_flames.size() >= 2:
		first_alternate_fire_depth = _choose_alternate_fire_depth(boss_depth, fire_depth, second_orb_depth, second_special_depth, cloaked_depth)
	var current_room_id := merge_id
	var current_coordinate := Vector2i(0, 2)
	for destination_depth in range(3, boss_depth + 1):
		var source_depth := current_coordinate.y
		var main_socket := DungeonGraph.WALL_LEFT if generator_rng.randi_range(0, 1) == 0 else DungeonGraph.WALL_RIGHT
		var destination_coordinate := current_coordinate + _exit_offset(main_socket)
		var room_type := _room_type_for_depth(destination_depth, boss_depth, second_orb_depth, second_special_depth, cloaked_depth, fire_depth, off_route_orbs)
		if fusion_fire_flames.has(destination_depth):
			room_type = DungeonGraph.ROOM_FIRE
		var respawn_color: StringName = &"puzzle_a" if destination_depth == FIRST_SPECIAL_DEPTH else _special_forward_requirement(second_special_depth, second_special_depth, completed_runs, starter_flame, alternate_flames) if destination_depth == second_special_depth else &""
		var fire_flame := StringName(fusion_fire_flames.get(destination_depth, _fire_flame_for_main_room(destination_depth, fire_depth, starter_flame, alternate_flames)))
		var destination_room_id := builder.add_room(destination_coordinate, room_type, 0, respawn_color, fire_flame)
		var forward_requirement := _special_forward_requirement(source_depth, second_special_depth, completed_runs, starter_flame, alternate_flames)
		var forward_role: StringName = ROUTE_KEY_PROGRESSION if not forward_requirement.is_empty() else ROUTE_MAIN
		var element_requirement := StringName(fusion_gate_requirements.get(source_depth, ""))
		builder.link(current_room_id, main_socket, destination_room_id, forward_requirement, forward_role, true, true, element_requirement)
		var detour_type: StringName = &""
		var detour_flame: StringName = &""
		if off_route_orbs.get(destination_depth, false):
			detour_type = ROUTE_DETOUR_ORB
		elif destination_depth == first_alternate_fire_depth:
			detour_type = ROUTE_DETOUR_FIRE
			detour_flame = alternate_flames[0] if not alternate_flames.is_empty() else starter_flame
		_add_side_route(builder, current_room_id, current_coordinate, source_depth, main_socket, generator_rng, boss_depth, second_special_depth, completed_runs, starter_flame, alternate_flames, detour_type, detour_flame, forward_requirement)
		current_room_id = destination_room_id
		current_coordinate = destination_coordinate
	_normalize_color_gate_requirements(layout, completed_runs, starter_flame)
	LAYOUT_DEFINITION_SCRIPT.apply_rare_enemy_branch_entry_exceptions(layout)
	return layout


static func validate(layout, completed_runs: int = 1, selected_starter_flame: StringName = &"fire") -> Array[String]:
	var errors: Array[String] = layout.validate()
	var start_id: StringName = &""
	var boss_id: StringName = &""
	var orb_count := 0
	var special_count := 0
	var treasure_count := 0
	var cloaked_count := 0
	var fire_count := 0
	var room_ids: Dictionary = {}
	var destination_entries: Dictionary = {}
	for room in layout.rooms:
		room_ids[room.id] = true
		if room.room_type == DungeonGraph.ROOM_START:
			start_id = room.id
		elif room.room_type == DungeonGraph.ROOM_BOSS:
			boss_id = room.id
		elif room.room_type == DungeonGraph.ROOM_ORB:
			orb_count += 1
		elif room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY:
			special_count += 1
		elif room.room_type == DungeonGraph.ROOM_TREASURE:
			treasure_count += 1
		elif room.room_type == DungeonGraph.ROOM_CLOAKED:
			cloaked_count += 1
		elif room.room_type == DungeonGraph.ROOM_FIRE:
			fire_count += 1
	for connection in layout.connections:
		var entry_key := "%s:%s" % [connection.destination_room_id, connection.destination_entry]
		if destination_entries.has(entry_key):
			errors.append("duplicate generated destination entry: %s" % entry_key)
		destination_entries[entry_key] = true
	if start_id.is_empty():
		errors.append("generated layout is missing a start room")
	if boss_id.is_empty():
		errors.append("generated layout is missing a boss room")
	if orb_count != 2:
		errors.append("generated layout requires exactly two Orb Rooms")
	if special_count < 2:
		errors.append("generated layout requires at least two Special Enemy Rooms")
	if treasure_count < 3:
		errors.append("generated layout requires at least three Treasure Rooms")
	if cloaked_count != 1:
		errors.append("generated layout requires exactly one Cloaked Room")
	if fire_count < 1:
		errors.append("generated layout requires at least one Fire Room")
	if not start_id.is_empty():
		var reachable := _reachable_rooms(layout, start_id)
		if reachable.size() != room_ids.size():
			errors.append("generated layout contains unreachable rooms")
		if not boss_id.is_empty() and not reachable.has(boss_id):
			errors.append("generated layout boss is unreachable")
		elif not boss_id.is_empty() and not _boss_is_color_reachable(layout, start_id, boss_id, completed_runs, selected_starter_flame):
			errors.append("generated layout boss requires an impossible puzzle-color state")
		var gated_route_errors := _color_gate_reachability_errors(layout, start_id, completed_runs, selected_starter_flame)
		errors.append_array(gated_route_errors)
		var side_flame_errors := _color_gate_side_flame_errors(layout, completed_runs, selected_starter_flame)
		errors.append_array(side_flame_errors)
		if completed_runs >= 5:
			var fusion_gate_errors := _fusion_gate_reachability_errors(layout, start_id, boss_id, completed_runs, selected_starter_flame)
			errors.append_array(fusion_gate_errors)
	return errors


static func _room_type_for_depth(
	depth: int,
	boss_depth: int,
	second_orb_depth: int,
	second_special_depth: int,
	cloaked_depth: int,
	fire_depth: int,
	off_route_orbs: Dictionary
) -> StringName:
	if depth == boss_depth:
		return DungeonGraph.ROOM_BOSS
	if (depth == FIRST_ORB_DEPTH or depth == second_orb_depth) and not bool(off_route_orbs.get(depth, false)):
		return DungeonGraph.ROOM_ORB
	if depth == FIRST_SPECIAL_DEPTH or depth == second_special_depth:
		return DungeonGraph.ROOM_SPECIAL_ENEMY
	if depth == cloaked_depth:
		return DungeonGraph.ROOM_CLOAKED
	if depth == fire_depth:
		return DungeonGraph.ROOM_FIRE
	return DungeonGraph.ROOM_COMBAT


static func _fusion_plan_for_run(completed_runs: int, _starter_flame: StringName) -> Dictionary:
	# Run 6 is the first run whose critical path asks for a fused element. The
	# first two fire rooms are deliberately placed before the gate so every
	# starter choice has a reachable input pair. Later runs teach the two-step
	# Grass -> Ice chain without putting a prerequisite behind its own gate.
	if completed_runs < 5:
		return {}
	if completed_runs < 7:
		var pairs: Array = [[&"fire", &"water"], [&"fire", &"electric"], [&"water", &"electric"]]
		var pair: Array = pairs[posmod(completed_runs - 5, pairs.size())] as Array
		var first_flame: StringName = pair[0] as StringName
		var second_flame: StringName = pair[1] as StringName
		var result_flame := ASPECT_CATALOG_SCRIPT.fusion_result(first_flame, second_flame)
		var result_element := ELEMENT_CATALOG_SCRIPT.element_for_palette(ASPECT_CATALOG_SCRIPT.palette_for_flame(result_flame))
		return {
			"fire_flames": {5: first_flame, 6: second_flame},
			"gate_requirements": {6: ELEMENT_CATALOG_SCRIPT.id(result_element)},
			"results": [result_flame],
		}
	# The Water + Electric -> Grass gate is followed by a Water fire and an Ice
	# gate. Depth 10 is already the generated utility fire slot, so reusing it
	# keeps the late spine compact and leaves the Cloaked Demon room untouched.
	var grass_element := ELEMENT_CATALOG_SCRIPT.element_for_palette("green")
	var ice_element := ELEMENT_CATALOG_SCRIPT.element_for_palette("aquamarine")
	return {
		"fire_flames": {5: &"water", 6: &"electric", 10: &"water"},
		"gate_requirements": {6: ELEMENT_CATALOG_SCRIPT.id(grass_element), 10: ELEMENT_CATALOG_SCRIPT.id(ice_element)},
		"results": [&"grass", &"ice"],
	}


static func _fire_flame_for_main_room(depth: int, fire_depth: int, starter_flame: StringName, alternate_flames: Array[StringName]) -> StringName:
	if depth != fire_depth:
		return &""
	return alternate_flames[alternate_flames.size() - 1] if not alternate_flames.is_empty() else starter_flame


static func _choose_alternate_fire_depth(
	boss_depth: int,
	main_fire_depth: int,
	second_orb_depth: int,
	second_special_depth: int,
	cloaked_depth: int
) -> int:
	var candidates: Array[int] = [main_fire_depth - 2, main_fire_depth - 3, main_fire_depth - 1, main_fire_depth - 4]
	for candidate in candidates:
		if candidate <= FIRST_SPECIAL_DEPTH or candidate >= second_special_depth:
			continue
		if candidate == main_fire_depth or candidate == second_orb_depth or candidate == cloaked_depth:
			continue
		if candidate == boss_depth:
			continue
		return candidate
	return -1


static func _off_route_orb_depths(dungeon_seed: int, run_index: int, first_orb_depth: int, second_orb_depth: int) -> Dictionary:
	# Exactly one Orb Room is deliberately placed off the spine. The seed decides
	# which one, preserving variety without ever making both progression anchors
	# detours in the same run.
	var first_is_detour := posmod(dungeon_seed ^ (run_index * 104729), 2) == 0
	return {first_orb_depth: first_is_detour, second_orb_depth: not first_is_detour}


static func _puzzle_color_for_flame(flame: StringName, starter_flame: StringName, alternate_flames: Array[StringName]) -> StringName:
	if flame == starter_flame:
		return &"puzzle_a"
	if alternate_flames.size() >= 1 and flame == alternate_flames[0]:
		return &"puzzle_c"
	if alternate_flames.size() >= 2 and flame == alternate_flames[1]:
		return &"puzzle_d"
	return &""


static func _special_forward_requirement(
	source_depth: int,
	second_special_depth: int,
	completed_runs: int,
	starter_flame: StringName,
	alternate_flames: Array[StringName]
) -> StringName:
	if source_depth == FIRST_SPECIAL_DEPTH:
		# First Special Room: player-color progression, grey optional Treasure.
		return &"puzzle_a"
	if source_depth == second_special_depth:
		# The late Special Room introduces the newest flame available in this run.
		# R1 keeps its original grey gate because it has no alternate flame yet.
		if completed_runs <= 0 or alternate_flames.is_empty():
			return &"puzzle_b"
		return _puzzle_color_for_flame(alternate_flames[alternate_flames.size() - 1], starter_flame, alternate_flames)
	return &""


static func _special_side_requirement(
	source_depth: int,
	second_special_depth: int,
	completed_runs: int,
	alternate_flames: Array[StringName],
	forward_requirement: StringName,
	generator_rng: RandomNumberGenerator
) -> StringName:
	# The first Special Room is the Run 1 teaching beat: its second door stays
	# grey-gated. Once a later run has a second flame, the late Special Room can
	# occasionally offer two primary choices instead. Puzzle A is always safe
	# here because the starter flame is available from the beginning of the run;
	# the forward gate is already using the newly earned alternate flame.
	if source_depth != second_special_depth or completed_runs <= 0 or alternate_flames.is_empty():
		return &"puzzle_b"
	if forward_requirement != &"puzzle_c" and forward_requirement != &"puzzle_d":
		return &"puzzle_b"
	var alternate_requirements: Array[StringName] = []
	for index in alternate_flames.size():
		var alternate_requirement: StringName = &"puzzle_c" if index == 0 else &"puzzle_d" if index == 1 else &""
		if alternate_requirement.is_empty() or alternate_requirement == forward_requirement:
			continue
		alternate_requirements.append(alternate_requirement)
	if alternate_requirements.is_empty() or generator_rng.randf() >= 0.50:
		return &"puzzle_b"
	return alternate_requirements[generator_rng.randi_range(0, alternate_requirements.size() - 1)]


static func _add_side_route(
	builder: LayoutBuilder,
	source_room_id: StringName,
	source_coordinate: Vector2i,
	source_depth: int,
	main_socket: StringName,
	generator_rng: RandomNumberGenerator,
	boss_depth: int,
	second_special_depth: int,
	completed_runs: int,
	starter_flame: StringName,
	alternate_flames: Array[StringName],
	detour_type: StringName = &"",
	detour_flame: StringName = &"",
	forward_requirement: StringName = &""
) -> void:
	var source = builder.room_spec(source_room_id)
	if source == null:
		return
	var side_socket := DungeonGraph.WALL_RIGHT if main_socket == DungeonGraph.WALL_LEFT else DungeonGraph.WALL_LEFT
	var side_coordinate := source_coordinate + _exit_offset(side_socket)
	if source.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY:
		# Every Special Room offers an optional side reward. The first beat and
		# most later seeds use a grey gate; some later seeds use the starter color
		# so the room can present two distinct primary choices.
		var requirement: StringName = _special_side_requirement(source_depth, second_special_depth, completed_runs, alternate_flames, forward_requirement, generator_rng)
		var treasure_id := builder.add_room(side_coordinate, DungeonGraph.ROOM_TREASURE, 1)
		builder.link(source_room_id, side_socket, treasure_id, requirement, ROUTE_OPTIONAL_TREASURE)
		return
	if detour_type == ROUTE_DETOUR_ORB:
		var orb_id := builder.add_room(side_coordinate, DungeonGraph.ROOM_ORB)
		builder.link(source_room_id, side_socket, orb_id, &"", ROUTE_DETOUR_ORB)
		return
	if detour_type == ROUTE_DETOUR_FIRE:
		var fire_id := builder.add_room(side_coordinate, DungeonGraph.ROOM_FIRE, 0, &"", detour_flame)
		builder.link(source_room_id, side_socket, fire_id, &"", ROUTE_DETOUR_FIRE)
		return
	# Guarantee a third optional reward branch, then add a small number of
	# deterministic side routes so higher runs feel broader without losing the
	# readable spine of Run 1.
	var guaranteed_treasure: bool = source_depth == boss_depth - 8 or source_depth == boss_depth - 5
	var random_side_route: bool = source.room_type == DungeonGraph.ROOM_COMBAT and source_depth >= 5 and source_depth < second_special_depth and generator_rng.randf() < 0.30
	if not guaranteed_treasure and not random_side_route:
		return
	var room_type: StringName = DungeonGraph.ROOM_TREASURE if guaranteed_treasure or generator_rng.randf() < 0.72 else DungeonGraph.ROOM_FIRE
	var chest_count: int = 1 if room_type == DungeonGraph.ROOM_TREASURE else 0
	var utility_flame := alternate_flames[0] if not alternate_flames.is_empty() else starter_flame
	var branch_id := builder.add_room(side_coordinate, room_type, chest_count, &"", utility_flame if room_type == DungeonGraph.ROOM_FIRE else &"")
	builder.link(source_room_id, side_socket, branch_id, &"", ROUTE_OPTIONAL_TREASURE if room_type == DungeonGraph.ROOM_TREASURE else &"optional_utility")


static func _exit_offset(socket_id: StringName) -> Vector2i:
	return Vector2i(-1, 1) if socket_id == DungeonGraph.WALL_LEFT else Vector2i(1, 1)


static func _reachable_rooms(layout, start_id: StringName) -> Dictionary:
	var reachable: Dictionary = {start_id: true}
	var pending: Array[StringName] = [start_id]
	while not pending.is_empty():
		var room_id: StringName = pending.pop_back() as StringName
		for connection in layout.connections:
			if connection.source_room_id != room_id or reachable.has(connection.destination_room_id):
				continue
			reachable[connection.destination_room_id] = true
			pending.append(connection.destination_room_id)
	return reachable


static func _normalize_color_gate_requirements(layout, completed_runs: int, starter_flame: StringName) -> void:
	# Color doors are impasses even when their requirement is grey. Keep the
	# original set of impasses fixed while repairing requirements so one repair
	# cannot make a later gate appear to be on a different side.
	var blocked_connections: Dictionary = {}
	for connection in layout.connections:
		if not connection.color_requirement.is_empty():
			blocked_connections[_layout_connection_key(connection)] = true
	for connection in layout.connections:
		if connection.color_requirement.is_empty() or connection.color_requirement == &"puzzle_b":
			continue
		var required_flame := _flame_for_puzzle_color(connection.color_requirement, starter_flame, completed_runs)
		var side_flames := _side_flames_for_connection(layout, connection.source_room_id, blocked_connections, completed_runs, starter_flame)
		if not required_flame.is_empty() and side_flames.has(required_flame):
			continue
		connection.color_requirement = _first_side_puzzle_requirement(side_flames, completed_runs, starter_flame)


static func _first_side_puzzle_requirement(side_flames: Array[StringName], completed_runs: int, starter_flame: StringName) -> StringName:
	var available := ASPECT_CATALOG_SCRIPT.flames_available_for_run(completed_runs, starter_flame)
	var alternates := ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(completed_runs, starter_flame)
	for flame in available:
		if not side_flames.has(flame):
			continue
		var requirement := _puzzle_color_for_flame(flame, starter_flame, alternates)
		if not requirement.is_empty():
			return requirement
	return &"puzzle_b"


static func _side_flames_for_connection(
	layout,
	source_room_id: StringName,
	blocked_connections: Dictionary,
	completed_runs: int,
	starter_flame: StringName
) -> Array[StringName]:
	var available := ASPECT_CATALOG_SCRIPT.flames_available_for_run(completed_runs, starter_flame)
	var visited: Dictionary = {}
	var pending: Array[StringName] = [source_room_id]
	while not pending.is_empty():
		var room_id: StringName = pending.pop_back() as StringName
		if visited.has(room_id):
			continue
		visited[room_id] = true
		for connection in layout.connections:
			if blocked_connections.has(_layout_connection_key(connection)):
				continue
			var next_room_id: StringName = &""
			if connection.source_room_id == room_id:
				next_room_id = connection.destination_room_id
			elif connection.destination_room_id == room_id:
				next_room_id = connection.source_room_id
			if not next_room_id.is_empty() and not visited.has(next_room_id):
				pending.append(next_room_id)
	var side_flames: Array[StringName] = []
	for room in layout.rooms:
		if not visited.has(room.id):
			continue
		if room.room_type == DungeonGraph.ROOM_START and not side_flames.has(starter_flame):
			side_flames.append(starter_flame)
		if room.room_type == DungeonGraph.ROOM_FIRE and not room.fire_flame.is_empty() and room.fire_flame in available and not side_flames.has(room.fire_flame):
			side_flames.append(room.fire_flame)
	return side_flames


static func _layout_connection_key(connection) -> String:
	return "%s:%s" % [connection.source_room_id, connection.exit_socket]


static func _fusion_gate_reachability_errors(layout, start_id: StringName, boss_id: StringName, completed_runs: int, starter_flame: StringName) -> Array[String]:
	var errors: Array[String] = []
	var states := _element_reachable_states(layout, start_id, completed_runs, starter_flame)
	var reachable_boss := false
	for state in states:
		if state.get("room_id", &"") == boss_id:
			reachable_boss = true
			break
	if not reachable_boss:
		errors.append("generated fusion curriculum leaves the boss unreachable")
	for connection in layout.connections:
		if connection.element_requirement.is_empty():
			continue
		var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(connection.element_requirement)
		var gate_reachable := false
		for state in states:
			if state.get("room_id", &"") != connection.source_room_id:
				continue
			var elements: Array = state.get("elements", []) as Array
			if elements.has(required_element):
				gate_reachable = true
				break
		if not gate_reachable:
			errors.append("generated fusion gate has no reachable matching result: %s:%s requires %s" % [connection.source_room_id, connection.exit_socket, connection.element_requirement])
	return errors


static func _element_reachable_states(layout, start_id: StringName, _completed_runs: int, starter_flame: StringName) -> Array[Dictionary]:
	var rooms_by_id: Dictionary = {}
	for room in layout.rooms:
		rooms_by_id[room.id] = room
	var starter_element := ELEMENT_CATALOG_SCRIPT.element_for_palette(ASPECT_CATALOG_SCRIPT.palette_for_flame(starter_flame))
	var pending: Array[Dictionary] = [{"room_id": start_id, "elements": [starter_element], "flames": [starter_flame]}]
	var visited: Dictionary = {}
	var reachable_states: Array[Dictionary] = []
	while not pending.is_empty():
		var state: Dictionary = pending.pop_back()
		var room_id: StringName = state.get("room_id", &"") as StringName
		var room = rooms_by_id.get(room_id)
		var flames: Array = (state.get("flames", []) as Array).duplicate()
		var elements: Array = (state.get("elements", []) as Array).duplicate()
		if room != null and room.room_type == DungeonGraph.ROOM_FIRE and not room.fire_flame.is_empty() and not flames.has(room.fire_flame):
			flames.append(room.fire_flame)
		# Every discovered flame can be revisited. This closure models a player
		# swapping to an input and then explicitly fusing it at a later fire.
		for flame in flames:
			var flame_element := ELEMENT_CATALOG_SCRIPT.element_for_palette(ASPECT_CATALOG_SCRIPT.palette_for_flame(flame as StringName))
			if flame_element != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL and not elements.has(flame_element):
				elements.append(flame_element)
		var element_inputs: Array = elements.duplicate()
		for first_element in element_inputs:
			var first_flame := ASPECT_CATALOG_SCRIPT.flame_for_palette(ELEMENT_CATALOG_SCRIPT.palette_key(int(first_element)))
			if first_flame.is_empty():
				continue
			for second_flame in flames:
				var result_flame := ASPECT_CATALOG_SCRIPT.fusion_result(first_flame, second_flame as StringName)
				if result_flame.is_empty():
					continue
				var result_element := ELEMENT_CATALOG_SCRIPT.element_for_palette(ASPECT_CATALOG_SCRIPT.palette_for_flame(result_flame))
				if result_element != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL and not elements.has(result_element):
					elements.append(result_element)
		var sorted_flames: Array[String] = []
		for flame in flames:
			sorted_flames.append(String(flame))
		sorted_flames.sort()
		var sorted_elements: Array[int] = []
		for element in elements:
			sorted_elements.append(int(element))
		sorted_elements.sort()
		var state_key := "%s:%s:%s" % [room_id, ",".join(sorted_flames), ",".join(sorted_elements.map(func(value: int) -> String: return str(value)))]
		if visited.has(state_key):
			continue
		visited[state_key] = true
		var normalized_state := {"room_id": room_id, "elements": elements, "flames": flames}
		reachable_states.append(normalized_state)
		for connection in layout.connections:
			if connection.source_room_id != room_id and connection.destination_room_id != room_id:
				continue
			if not connection.element_requirement.is_empty() and not elements.has(ELEMENT_CATALOG_SCRIPT.element_for_id(connection.element_requirement)):
				continue
			var next_room: StringName = connection.destination_room_id if connection.source_room_id == room_id else connection.source_room_id
			pending.append({"room_id": next_room, "elements": elements.duplicate(), "flames": flames.duplicate()})
	return reachable_states


static func _boss_is_color_reachable(layout, start_id: StringName, boss_id: StringName, completed_runs: int, starter_flame: StringName) -> bool:
	for state in _color_reachable_states(layout, start_id, completed_runs, starter_flame):
		if state.get("room_id", &"") == boss_id:
			return true
	return false


static func _color_gate_reachability_errors(layout, start_id: StringName, completed_runs: int, starter_flame: StringName) -> Array[String]:
	var errors: Array[String] = []
	var states := _color_reachable_states(layout, start_id, completed_runs, starter_flame)
	for connection in layout.connections:
		if connection.color_requirement.is_empty():
			continue
		var required_flame := _flame_for_puzzle_color(connection.color_requirement, starter_flame, completed_runs)
		if connection.color_requirement == &"puzzle_b":
			required_flame = &"grey"
		if required_flame.is_empty():
			errors.append("generated connection uses an unavailable puzzle color: %s:%s" % [connection.source_room_id, connection.exit_socket])
			continue
		var reachable_gate := false
		for state in states:
			if state.get("room_id", &"") != connection.source_room_id:
				continue
			if state.get("color", &"") != connection.color_requirement:
				continue
			var flames: Array = state.get("flames", []) as Array
			if required_flame == &"grey" or flames.has(required_flame):
				reachable_gate = true
				break
		if not reachable_gate:
			errors.append("generated color gate has no reachable matching fire: %s:%s requires %s" % [connection.source_room_id, connection.exit_socket, connection.color_requirement])
	return errors


static func _color_gate_side_flame_errors(layout, completed_runs: int, starter_flame: StringName) -> Array[String]:
	var errors: Array[String] = []
	var blocked_connections: Dictionary = {}
	for connection in layout.connections:
		if not connection.color_requirement.is_empty():
			blocked_connections[_layout_connection_key(connection)] = true
	for connection in layout.connections:
		if connection.color_requirement.is_empty() or connection.color_requirement == &"puzzle_b":
			continue
		var required_flame := _flame_for_puzzle_color(connection.color_requirement, starter_flame, completed_runs)
		if required_flame.is_empty():
			continue
		var side_flames := _side_flames_for_connection(layout, connection.source_room_id, blocked_connections, completed_runs, starter_flame)
		if not side_flames.has(required_flame):
			errors.append("generated color gate requires %s but its source side has no matching flame: %s:%s" % [connection.color_requirement, connection.source_room_id, connection.exit_socket])
	return errors


static func _flame_for_puzzle_color(color: StringName, starter_flame: StringName, completed_runs: int) -> StringName:
	if color == &"puzzle_b":
		return &""
	var available := ASPECT_CATALOG_SCRIPT.flames_available_for_run(completed_runs, starter_flame)
	if color == &"puzzle_a":
		return available[0] if not available.is_empty() else &""
	if color == &"puzzle_c":
		return available[1] if available.size() >= 2 else &""
	if color == &"puzzle_d":
		return available[2] if available.size() >= 3 else &""
	return &""


static func _color_reachable_states(layout, start_id: StringName, completed_runs: int, starter_flame: StringName) -> Array[Dictionary]:
	var rooms_by_id: Dictionary = {}
	for room in layout.rooms:
		rooms_by_id[room.id] = room
	var pending: Array[Dictionary] = [{"room_id": start_id, "color": &"puzzle_b", "flames": [starter_flame]}]
	var visited: Dictionary = {}
	var reachable_states: Array[Dictionary] = []
	while not pending.is_empty():
		var state: Dictionary = pending.pop_back()
		var room_id: StringName = state["room_id"] as StringName
		var color: StringName = state["color"] as StringName
		var flames: Array = (state.get("flames", []) as Array).duplicate()
		var room = rooms_by_id.get(room_id)
		if room != null and room.room_type == DungeonGraph.ROOM_FIRE and not room.fire_flame.is_empty() and not flames.has(room.fire_flame):
			var available := ASPECT_CATALOG_SCRIPT.flames_available_for_run(completed_runs, starter_flame)
			if room.fire_flame in available:
				flames.append(room.fire_flame)
		var flame_names: Array[String] = []
		for flame in flames:
			flame_names.append(String(flame))
		flame_names.sort()
		var state_key := "%s:%s:%s" % [room_id, color, ",".join(flame_names)]
		if visited.has(state_key):
			continue
		visited[state_key] = true
		var normalized_state := {"room_id": room_id, "color": color, "flames": flames}
		reachable_states.append(normalized_state)
		if room != null and room.room_type == DungeonGraph.ROOM_ORB:
			pending.append({"room_id": room_id, "color": &"puzzle_b", "flames": flames.duplicate()})
			for flame in flames:
				var puzzle_color := _puzzle_color_for_flame(flame, starter_flame, ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(completed_runs, starter_flame))
				if not puzzle_color.is_empty():
					pending.append({"room_id": room_id, "color": puzzle_color, "flames": flames.duplicate()})
		for connection in layout.connections:
			if connection.source_room_id == room_id or connection.destination_room_id == room_id:
				if not connection.color_requirement.is_empty() and connection.color_requirement != color:
					continue
				var next_room: StringName = connection.destination_room_id if connection.source_room_id == room_id else connection.source_room_id
				pending.append({"room_id": next_room, "color": color, "flames": flames.duplicate()})
	return reachable_states
