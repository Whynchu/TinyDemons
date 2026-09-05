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
const FIRST_ORB_DEPTH := 3
const FIRST_SPECIAL_DEPTH := 4

const ROUTE_MAIN: StringName = &"main"
const ROUTE_FORK: StringName = &"fork"
const ROUTE_OPTIONAL_TREASURE: StringName = &"optional_treasure"
const ROUTE_KEY_PROGRESSION: StringName = &"key_progression"
const ROUTE_DETOUR_ORB: StringName = &"detour_orb"
const ROUTE_DETOUR_FIRE: StringName = &"detour_fire"
const ROUTE_FUSION_PREREQUISITE_ORB: StringName = &"fusion_prerequisite_orb"
const ROUTE_DIG: StringName = &"dig"
const ROUTE_REJOIN: StringName = &"rejoin"


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
		element_requirement: StringName = &"",
		gate_type: StringName = DungeonGraph.GATE_NONE,
		orb_element_requirement: StringName = &"",
		allow_entry_before_source_clear: bool = false,
		hidden_until_clear: bool = false,
		hidden_until_event: StringName = &""
	) -> void:
		var key := "%s:%s" % [source_room_id, exit_socket]
		if connection_keys.has(key):
			push_error("Generated layout attempted to reuse exit socket %s." % key)
			return
		if allow_entry_before_source_clear and hidden_until_clear:
			push_error("Generated layout combined a pre-clear entrant with a clear-gated shortcut.")
			return
		var source = room_spec(source_room_id)
		var destination = room_spec(destination_room_id)
		if source == null or destination == null:
			push_error("Generated layout attempted to link a missing room.")
			return
		var destination_entry := DungeonGraph.paired_socket(exit_socket)
		var midpoint_sum: Vector2i = source.minimap_coordinate + destination.minimap_coordinate
		var midpoint: Vector2i = Vector2i(int(float(midpoint_sum.x) / 2.0), int(float(midpoint_sum.y) / 2.0))
		layout.add_connection(layout.make_connection_spec(
			source_room_id,
			exit_socket,
			destination_room_id,
			destination_entry,
			color_requirement,
			hidden_until_clear,
			hidden_until_event,
			midpoint,
			requires_source_room_clear,
			locks_entry_on_destination_engagement,
			route_role,
			allow_entry_before_source_clear,
			element_requirement,
			gate_type,
			orb_element_requirement
		))
		connection_keys[key] = true


static func build(dungeon_seed: int, completed_runs: int, selected_starter_flame: StringName = &"fire", selected_bound_flame: StringName = &""):
	var run_number := maxi(completed_runs + 1, 1)
	var run_index := maxi(completed_runs, 1)
	var starter_flame := selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var bound_flame := selected_bound_flame if ASPECT_CATALOG_SCRIPT.is_elemental_flame(selected_bound_flame) else &""
	var alternate_flames: Array[StringName] = ASPECT_CATALOG_SCRIPT.alternate_flames_for_run(completed_runs, starter_flame)
	var boss_depth := generated_boss_depth_for_run(run_number)
	var room_target := generated_room_target_for_run(run_number)
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

	# The Hub degree is seed-chosen, not a fixed four-way. Two progression forks
	# are always present, but the number of lower scoutable dig branches varies:
	# a degree-2 Hub is a clean linear opening, degree-3 adds one dig, and
	# degree-4 exposes both. Lower branches are scoutable: their entrance is
	# available immediately, while the normal engagement lock commits the player
	# after the first attack.
	var hub_degree := _hub_degree(generator_rng)
	var first_dig_side := -1 if generator_rng.randi_range(0, 1) == 0 else 1
	var hub_dig_routes: Array[Dictionary] = []
	if hub_degree >= 3:
		hub_dig_routes.append(_append_hub_dig_branch(builder, start_id, first_dig_side, alternate_flames, starter_flame, generator_rng))
	if hub_degree >= 4:
		hub_dig_routes.append(_append_hub_dig_branch(builder, start_id, -first_dig_side, alternate_flames, starter_flame, generator_rng))

	var second_special_depth := boss_depth - 2
	var cloaked_depth := clampi(int(float(boss_depth) / 2.0), 6, boss_depth - 5)
	var fire_depth := clampi(boss_depth - 6, 6, boss_depth - 5)
	var first_alternate_fire_depth := -1
	var fusion_plan := _fusion_plan_for_run(completed_runs, starter_flame, dungeon_seed)
	# The chained Ice gate is placed at source depth 10. Its Orb must be a side
	# room reached from that same depth-10 Water fire room; the old depth-12
	# placement put the only Ice charge behind its own mandatory gate.
	var second_orb_depth: int = int(fusion_plan.get("second_orb_depth", boss_depth - 4))
	var fusion_fire_flames: Dictionary = fusion_plan.get("fire_flames", {}) as Dictionary
	var fusion_gate_requirements: Dictionary = fusion_plan.get("entrance_orb_requirements", {}) as Dictionary
	var fusion_gate_types: Dictionary = fusion_plan.get("gate_types", {}) as Dictionary
	var fusion_gate_colors: Dictionary = fusion_plan.get("gate_colors", {}) as Dictionary
	var off_route_orbs := _off_route_orb_depths(dungeon_seed, run_index, FIRST_ORB_DEPTH, second_orb_depth, fusion_plan.has("second_orb_depth"))
	if fire_depth == cloaked_depth:
		fire_depth = mini(fire_depth + 1, boss_depth - 5)
	if alternate_flames.size() >= 2:
		first_alternate_fire_depth = _choose_alternate_fire_depth(boss_depth, fire_depth, second_orb_depth, second_special_depth, cloaked_depth)
	var current_room_id := merge_id
	var current_coordinate := Vector2i(0, 2)
	var spine_rooms_by_depth: Dictionary = {2: merge_id}
	# The critical path wanders laterally instead of climbing a straight column.
	# A momentum-dominated walk keeps the spine readable while letting the boss
	# arrive at a varied free lateral position; the boss is always approached
	# through a wall socket so its door still reads as a "northern" stairs-up.
	var walk_direction := -1 if generator_rng.randi_range(0, 1) == 0 else 1
	var wander_bound := 4
	for destination_depth in range(3, boss_depth + 1):
		var source_depth := current_coordinate.y
		# Steer the walk: reverse with a fixed probability, and force a turn back
		# toward the spine once the path drifts past its lateral bounds.
		if generator_rng.randf() < 0.28:
			walk_direction = -walk_direction
		var current_x: int = current_coordinate.x
		if current_x >= wander_bound:
			walk_direction = -1
		elif current_x <= -wander_bound:
			walk_direction = 1
		var main_socket := DungeonGraph.WALL_LEFT if walk_direction == -1 else DungeonGraph.WALL_RIGHT
		var destination_coordinate := current_coordinate + _exit_offset(main_socket)
		var room_type := _room_type_for_depth(destination_depth, boss_depth, second_orb_depth, second_special_depth, cloaked_depth, fire_depth, off_route_orbs)
		if fusion_fire_flames.has(destination_depth):
			room_type = DungeonGraph.ROOM_FIRE
		# Run 3's first alternate flame is reached immediately after the first
		# Special Room. Keep that Special Room's grey alternate door intact while
		# making the flame a real, reachable main-route Fire Room; later seeds can
		# still place the same curriculum beat as a side detour.
		var source_spec = builder.room_spec(current_room_id)
		var alternate_fire_on_main: bool = destination_depth == first_alternate_fire_depth and not alternate_flames.is_empty() and source_spec != null and source_spec.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY
		if alternate_fire_on_main:
			room_type = DungeonGraph.ROOM_FIRE
		var respawn_color: StringName = &"puzzle_a" if destination_depth == FIRST_SPECIAL_DEPTH else _special_forward_requirement(second_special_depth, second_special_depth, completed_runs, starter_flame, alternate_flames) if destination_depth == second_special_depth else &""
		var fire_flame := StringName(fusion_fire_flames.get(destination_depth, _fire_flame_for_main_room(destination_depth, fire_depth, starter_flame, alternate_flames)))
		if alternate_fire_on_main:
			fire_flame = alternate_flames[0]
		var destination_room_id := builder.add_room(destination_coordinate, room_type, 0, respawn_color, fire_flame)
		var forward_requirement := _special_forward_requirement(source_depth, second_special_depth, completed_runs, starter_flame, alternate_flames)
		var forward_role: StringName = ROUTE_KEY_PROGRESSION if not forward_requirement.is_empty() else ROUTE_MAIN
		var orb_element_requirement := StringName(fusion_gate_requirements.get(source_depth, ""))
		var planned_gate_type: StringName = StringName(fusion_gate_types.get(source_depth, ""))
		var gate_type: StringName = planned_gate_type if not planned_gate_type.is_empty() else DungeonGraph.GATE_ENTRANCE_ORB if not orb_element_requirement.is_empty() else DungeonGraph.GATE_NONE
		var planned_gate_color: StringName = StringName(fusion_gate_colors.get(source_depth, ""))
		var connection_color_requirement: StringName = planned_gate_color if not planned_gate_color.is_empty() else &"" if gate_type == DungeonGraph.GATE_ENTRANCE_ORB else forward_requirement
		builder.link(current_room_id, main_socket, destination_room_id, connection_color_requirement, forward_role, true, true, &"", gate_type, orb_element_requirement)
		var detour_type: StringName = &""
		var detour_flame: StringName = &""
		if off_route_orbs.get(destination_depth, false):
			detour_type = ROUTE_DETOUR_ORB
		elif destination_depth == first_alternate_fire_depth and not alternate_fire_on_main:
			detour_type = ROUTE_DETOUR_FIRE
			detour_flame = alternate_flames[0] if not alternate_flames.is_empty() else starter_flame
		if fusion_gate_requirements.has(source_depth):
			# Reserve the side socket for the prerequisite Orb before optional
			# rewards are considered.  Late chained-fusion gates often share the
			# guaranteed treasure depth; adding the reward first can consume both
			# available sockets and leave the mandatory Orb without a route.
			_add_fusion_prerequisite_orb(builder, current_room_id, current_coordinate, main_socket)
		_add_side_route(builder, current_room_id, current_coordinate, source_depth, main_socket, generator_rng, boss_depth, second_special_depth, completed_runs, starter_flame, alternate_flames, detour_type, detour_flame, forward_requirement, room_target)
		current_room_id = destination_room_id
		current_coordinate = destination_coordinate
		spine_rooms_by_depth[destination_depth] = destination_room_id
	_connect_hub_dig_routes(builder, hub_dig_routes, spine_rooms_by_depth, generator_rng)
	_fill_room_target(builder, room_target, boss_depth)
	_add_safe_cross_links(builder, generator_rng)
	var progression_repairs := repair_progression(layout, completed_runs, starter_flame, bound_flame)
	for repair in progression_repairs:
		push_warning("Generated progression repair (run %d seed %d starter=%s bound=%s): %s" % [run_number, dungeon_seed, starter_flame, bound_flame if not bound_flame.is_empty() else "none", repair])
	LAYOUT_DEFINITION_SCRIPT.apply_rare_enemy_branch_entry_exceptions(layout)
	return layout


static func generated_room_target_for_run(run_number: int) -> int:
	var normalized_run := maxi(run_number, 1)
	if normalized_run == 1:
		return 18
	if normalized_run == 2:
		return 24
	if normalized_run == 3:
		return 26
	if normalized_run == 4:
		return 27
	if normalized_run <= 9:
		return 28
	return 29 + floori(float(normalized_run - 10) / 2.0)


static func generated_boss_depth_for_run(run_number: int) -> int:
	var normalized_run := maxi(run_number, 1)
	if normalized_run <= 3:
		return 13
	if normalized_run == 4:
		return 14
	if normalized_run <= 9:
		return 15
	return 16 + floori(float(normalized_run - 10) / 2.0)


static func _fill_room_target(builder: LayoutBuilder, room_target: int, boss_depth: int) -> void:
	if room_target <= 0:
		return
	# The target is a soft floor for the route, not a permanent hard cap. If a
	# variable Hub degree or seeded optional branches leave the layout short, add
	# deterministic reward branches from spare exits. Upper wall sockets host
	# treasure detours; lower sockets host scoutable dig branches so a thin Hub
	# still reaches the approved pacing curve without a run-away tree.
	var made_progress := true
	while made_progress and builder.layout.rooms.size() < room_target:
		made_progress = false
		for source in builder.layout.rooms:
			if builder.layout.rooms.size() >= room_target:
				break
			var source_id: StringName = source.id
			var source_coordinate: Vector2i = source.coordinate
			var source_room_type: StringName = source.room_type
			if source_room_type != DungeonGraph.ROOM_COMBAT or source_coordinate.y < 3 or source_coordinate.y >= boss_depth:
				continue
			for side_socket_id: StringName in [DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT, DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_RIGHT]:
				var connection_key := "%s:%s" % [source_id, side_socket_id]
				if builder.connection_keys.has(connection_key):
					continue
				var side_coordinate: Vector2i = source_coordinate + _exit_offset(side_socket_id)
				if builder.room_ids_by_coordinate.has(side_coordinate):
					continue
				var is_dig := side_socket_id == DungeonGraph.BOTTOM_LEFT or side_socket_id == DungeonGraph.BOTTOM_RIGHT
				var branch_id := builder.add_room(side_coordinate, DungeonGraph.ROOM_TREASURE, 1)
				builder.link(source_id, side_socket_id, branch_id, &"", ROUTE_DIG if is_dig else ROUTE_OPTIONAL_TREASURE, true, true)
				made_progress = true
				break


static func validate(layout, completed_runs: int = 1, selected_starter_flame: StringName = &"fire", selected_bound_flame: StringName = &"") -> Array[String]:
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
	if orb_count < 2:
		errors.append("generated layout requires at least two Orb Rooms")
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
		elif not boss_id.is_empty() and not _boss_is_color_reachable(layout, start_id, boss_id, completed_runs, selected_starter_flame, selected_bound_flame):
			errors.append("generated layout boss requires an impossible puzzle-color state")
		var gated_route_errors := _color_gate_reachability_errors(layout, start_id, completed_runs, selected_starter_flame, selected_bound_flame)
		errors.append_array(gated_route_errors)
		var side_flame_errors := _color_gate_side_flame_errors(layout, completed_runs, selected_starter_flame, selected_bound_flame)
		errors.append_array(side_flame_errors)
		if completed_runs >= 5:
			var fusion_gate_errors := _fusion_gate_reachability_errors(layout, start_id, boss_id, completed_runs, selected_starter_flame, selected_bound_flame)
			errors.append_array(fusion_gate_errors)
			var fusion_softlock_errors := _fusion_orb_softlock_errors(layout, start_id, boss_id, completed_runs, selected_starter_flame, selected_bound_flame)
			errors.append_array(fusion_softlock_errors)
			var fusion_orb_route_errors := _fusion_orb_route_errors(layout)
			errors.append_array(fusion_orb_route_errors)
	return errors


static func repair_progression(layout, completed_runs: int, selected_starter_flame: StringName = &"fire", selected_bound_flame: StringName = &"") -> Array[String]:
	## Repair only progression requirements; topology and room pacing remain
	## seed-owned.  This is intentionally callable by continue/load recovery as
	## well as by build(), so an already-created generated layout gets the same
	## safety treatment before the player is restored to it.
	var repairs: Array[String] = []
	if layout == null:
		return repairs
	var starter_flame := selected_starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(selected_starter_flame) else &"fire"
	var bound_flame := selected_bound_flame if ASPECT_CATALOG_SCRIPT.is_elemental_flame(selected_bound_flame) else &""
	var before_color_requirements: Dictionary = {}
	for connection in layout.connections:
		before_color_requirements[_layout_connection_key(connection)] = connection.color_requirement
	_normalize_color_gate_requirements(layout, completed_runs, starter_flame, bound_flame)
	for connection in layout.connections:
		var key := _layout_connection_key(connection)
		var previous: StringName = before_color_requirements.get(key, &"") as StringName
		if previous != connection.color_requirement:
			repairs.append("color gate %s:%s changed %s -> %s" % [connection.source_room_id, connection.exit_socket, previous, connection.color_requirement])
	var start_id := _layout_start_room_id(layout)
	if start_id.is_empty():
		return repairs
	var color_repairs := _repair_unreachable_color_gates(layout, start_id, completed_runs, starter_flame, bound_flame)
	repairs.append_array(color_repairs)
	var orb_repairs := _repair_unreachable_entrance_orb_gates(layout, start_id, completed_runs, starter_flame, bound_flame)
	repairs.append_array(orb_repairs)
	return repairs


static func _layout_start_room_id(layout) -> StringName:
	if layout == null:
		return &""
	for room in layout.rooms:
		if room.room_type == DungeonGraph.ROOM_START:
			return room.id
	return &""


static func _repair_unreachable_color_gates(layout, start_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName) -> Array[String]:
	var repairs: Array[String] = []
	for connection in layout.connections:
		if connection.color_requirement.is_empty():
			continue
		# Optional treasure/detour doors are allowed to be restrictive. Only
		# repair gates that form the critical route; changing an optional branch
		# would unnecessarily alter the seed's intended variety.
		if connection.route_role != ROUTE_MAIN and connection.route_role != ROUTE_KEY_PROGRESSION:
			continue
		var states := _color_reachable_states(layout, start_id, completed_runs, starter_flame, bound_flame)
		if _color_gate_has_reachable_state(states, connection, starter_flame, completed_runs):
			continue
		var previous: StringName = connection.color_requirement
		var replacement: StringName = _first_reachable_color_requirement(states, connection.source_room_id, starter_flame, completed_runs)
		connection.color_requirement = replacement
		repairs.append("color gate %s:%s changed %s -> %s for the bound start state" % [connection.source_room_id, connection.exit_socket, previous, replacement])
	return repairs


static func _color_gate_has_reachable_state(states: Array[Dictionary], connection, starter_flame: StringName, completed_runs: int) -> bool:
	var required_flame := _flame_for_puzzle_color(connection.color_requirement, starter_flame, completed_runs)
	if connection.color_requirement == &"puzzle_b":
		required_flame = &"grey"
	for state in states:
		if state.get("room_id", &"") != connection.source_room_id or state.get("color", &"") != connection.color_requirement:
			continue
		if required_flame == &"grey" or (state.get("flames", []) as Array).has(required_flame):
			return true
	return false


static func _first_reachable_color_requirement(states: Array[Dictionary], source_room_id: StringName, starter_flame: StringName, completed_runs: int) -> StringName:
	var candidates: Array[StringName] = [&"puzzle_b", &"puzzle_a", &"puzzle_c", &"puzzle_d"]
	for candidate in candidates:
		var required_flame := _flame_for_puzzle_color(candidate, starter_flame, completed_runs)
		if candidate == &"puzzle_b":
			required_flame = &"grey"
		for state in states:
			if state.get("room_id", &"") != source_room_id or state.get("color", &"") != candidate:
				continue
			if required_flame == &"grey" or (state.get("flames", []) as Array).has(required_flame):
				return candidate
	return &"puzzle_b"


static func _repair_unreachable_entrance_orb_gates(layout, start_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName) -> Array[String]:
	var repairs: Array[String] = []
	for connection in layout.connections:
		if connection.resolved_gate_type() != DungeonGraph.GATE_ENTRANCE_ORB:
			continue
		var states := _element_reachable_states(layout, start_id, completed_runs, starter_flame, bound_flame)
		var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(connection.orb_element_requirement)
		var matching := false
		for state in states:
			if state.get("room_id", &"") != connection.source_room_id:
				continue
			if int(state.get("orb_element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)) == required_element:
				matching = true
				break
		if matching:
			continue
		var replacement: int = _first_reachable_orb_element(states, connection.source_room_id, starter_flame, bound_flame)
		if replacement == ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL:
			# The generated curriculum should never need this fallback, but keeping
			# the gate on the initial element is safer than leaving an impossible
			# opaque requirement in a continued save.
			replacement = _initial_run_element(starter_flame, bound_flame)
		if replacement == ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL:
			continue
		var previous: StringName = connection.orb_element_requirement
		connection.orb_element_requirement = ELEMENT_CATALOG_SCRIPT.id(replacement)
		repairs.append("entrance Orb gate %s:%s changed %s -> %s for the bound start state" % [connection.source_room_id, connection.exit_socket, previous, connection.orb_element_requirement])
	return repairs


static func _first_reachable_orb_element(states: Array[Dictionary], source_room_id: StringName, _starter_flame: StringName, _bound_flame: StringName) -> int:
	var candidates: Array[int] = []
	for state in states:
		if state.get("room_id", &"") != source_room_id:
			continue
		var normalized := ELEMENT_CATALOG_SCRIPT.normalize(int(state.get("orb_element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)))
		if normalized != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL and normalized not in candidates:
			candidates.append(normalized)
	if candidates.is_empty():
		for state in states:
			if state.get("room_id", &"") != source_room_id:
				continue
			var normalized := ELEMENT_CATALOG_SCRIPT.normalize(int(state.get("element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)))
			if normalized != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL and normalized not in candidates:
				candidates.append(normalized)
	candidates.sort()
	return candidates[0] if not candidates.is_empty() else ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL


static func _initial_run_element(starter_flame: StringName, bound_flame: StringName) -> int:
	var initial_flame := _initial_run_flame(starter_flame, bound_flame)
	return ELEMENT_CATALOG_SCRIPT.element_for_palette(ASPECT_CATALOG_SCRIPT.palette_for_flame(initial_flame))


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


static func _fusion_plan_for_run(completed_runs: int, _starter_flame: StringName, dungeon_seed: int = 0) -> Dictionary:
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
			"entrance_orb_requirements": {6: ELEMENT_CATALOG_SCRIPT.id(result_element)},
			"results": [result_flame],
		}
	# Later runs provide the ingredients for one valid fusion recipe and let the
	# dungeon seed choose which result gates the route. The gate never dictates
	# an unsolvable element: its matching ingredient flames are placed first.
	var fusion_options: Array[Dictionary] = [
		{"result": &"normal", "gate_type": DungeonGraph.GATE_PUZZLE_COLOR, "gate_color": &"puzzle_b", "fire_flames": {5: &"fire", 6: &"water"}},
		{"first": &"fire", "second": &"water", "result": &"shadow"},
		{"first": &"fire", "second": &"electric", "result": &"ground"},
		{"first": &"water", "second": &"electric", "result": &"grass"},
		{"first": &"grass", "second": &"water", "result": &"ice"},
	]
	var selected_fusion: Dictionary = fusion_options[posmod(dungeon_seed, fusion_options.size())]
	if selected_fusion.get("result", &"") == &"normal":
		return {
			"fire_flames": selected_fusion["fire_flames"],
			"gate_types": {10: selected_fusion["gate_type"]},
			"gate_colors": {10: selected_fusion["gate_color"]},
			"second_orb_depth": 11,
			"results": [&"normal"],
		}
	var gate_flame: StringName = selected_fusion["result"] as StringName
	var gate_element := ELEMENT_CATALOG_SCRIPT.element_for_palette(ASPECT_CATALOG_SCRIPT.palette_for_flame(gate_flame))
	var fusion_fire_flames: Dictionary = {
		5: selected_fusion["first"] as StringName,
		6: selected_fusion["second"] as StringName,
	}
	if gate_flame == &"ice":
		# Grass is produced by the first Orb from Water + Electric, then Water is
		# supplied again for the second fusion at the gate approach.
		fusion_fire_flames = {5: &"water", 6: &"electric", 10: &"water"}
	return {
		"fire_flames": fusion_fire_flames,
		"entrance_orb_requirements": {10: ELEMENT_CATALOG_SCRIPT.id(gate_element)},
		"second_orb_depth": 11,
		"results": [gate_flame],
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


static func _off_route_orb_depths(dungeon_seed: int, run_index: int, first_orb_depth: int, second_orb_depth: int, force_second_detour: bool = false) -> Dictionary:
	if force_second_detour:
		# Keep the first Orb on the spine and put the second Orb beside the fire
		# room immediately before the chained fusion gate.
		return {first_orb_depth: false, second_orb_depth: true}
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


static func _hub_degree(generator_rng: RandomNumberGenerator) -> int:
	# Seed-chosen Hub openness: 2 = clean linear opening, 3 = one lower dig,
	# 4 = both lower dig branches. Four-way is fully supported but no longer a
	# mandate; the assembler chooses based on the routes it wants to emit.
	var roll := generator_rng.randf()
	if roll < 0.34:
		return 2
	if roll < 0.72:
		return 3
	return 4


static func _append_hub_dig_branch(
	builder: LayoutBuilder,
	start_id: StringName,
	side: int,
	alternate_flames: Array[StringName],
	starter_flame: StringName,
	generator_rng: RandomNumberGenerator
) -> Dictionary:
	# Dig routes are seeded walks rather than fixed three-room diagonals. They can
	# bend toward or away from the Hub, vary from two to four rooms, and end in a
	# Treasure or utility Fire room. The first edge remains freely scoutable;
	# later enemy-room exits use the ordinary clear contract.
	var route_role: StringName = ROUTE_DIG if side <= 0 else ROUTE_OPTIONAL_TREASURE
	var current_id := start_id
	var current_coordinate := Vector2i.ZERO
	var next_side := -1 if side <= 0 else 1
	var branch_length := generator_rng.randi_range(2, 4)
	for branch_index in branch_length:
		var candidate_sides: Array[int] = [next_side, -next_side]
		if generator_rng.randf() < 0.42:
			candidate_sides.reverse()
		var socket_id: StringName = &""
		var destination_coordinate := Vector2i.ZERO
		for candidate_side in candidate_sides:
			var candidate_socket := DungeonGraph.BOTTOM_LEFT if candidate_side < 0 else DungeonGraph.BOTTOM_RIGHT
			var candidate_coordinate := current_coordinate + _exit_offset(candidate_socket)
			var key := "%s:%s" % [current_id, candidate_socket]
			if builder.connection_keys.has(key) or builder.room_ids_by_coordinate.has(candidate_coordinate):
				continue
			socket_id = candidate_socket
			destination_coordinate = candidate_coordinate
			next_side = candidate_side
			break
		if socket_id.is_empty():
			break
		var is_terminal := branch_index == branch_length - 1
		var room_type: StringName = DungeonGraph.ROOM_COMBAT
		var chest_count := 0
		var fire_flame: StringName = &""
		if is_terminal:
			if generator_rng.randf() < 0.68:
				room_type = DungeonGraph.ROOM_TREASURE
				chest_count = 1
			else:
				room_type = DungeonGraph.ROOM_FIRE
				fire_flame = alternate_flames[generator_rng.randi_range(0, alternate_flames.size() - 1)] if not alternate_flames.is_empty() else starter_flame
		elif branch_index > 0 and generator_rng.randf() < 0.24:
			room_type = DungeonGraph.ROOM_TREASURE
			chest_count = 1
		var destination_id := builder.add_room(destination_coordinate, room_type, chest_count, &"", fire_flame)
		builder.link(current_id, socket_id, destination_id, &"", route_role, branch_index > 0, true)
		current_id = destination_id
		current_coordinate = destination_coordinate
		if generator_rng.randf() < 0.38:
			next_side = -next_side
	return {"room_id": current_id, "coordinate": current_coordinate, "side": side}


static func _connect_hub_dig_routes(
	builder: LayoutBuilder,
	dig_routes: Array[Dictionary],
	spine_rooms_by_depth: Dictionary,
	generator_rng: RandomNumberGenerator
) -> void:
	if dig_routes.is_empty() or not spine_rooms_by_depth.has(FIRST_ORB_DEPTH):
		return
	# Always rejoin one lower route; a four-way Hub may rejoin both. The join lands
	# at the first pre-gate spine room, so it creates a genuine alternate boss
	# approach without bypassing the first Special Room's progression door.
	var target_id: StringName = spine_rooms_by_depth[FIRST_ORB_DEPTH] as StringName
	for route_index in dig_routes.size():
		if route_index > 0 and generator_rng.randf() >= 0.55:
			continue
		var route: Dictionary = dig_routes[route_index]
		_append_rejoin_path(builder, route.get("room_id", &"") as StringName, route.get("coordinate", Vector2i.ZERO) as Vector2i, target_id, generator_rng)


static func _append_rejoin_path(
	builder: LayoutBuilder,
	source_id: StringName,
	source_coordinate: Vector2i,
	target_id: StringName,
	generator_rng: RandomNumberGenerator
) -> bool:
	var target = builder.room_spec(target_id)
	if source_id.is_empty() or target == null:
		return false
	var target_sockets: Array[StringName] = [DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_RIGHT]
	if generator_rng.randi_range(0, 1) == 1:
		target_sockets.reverse()
	for target_entry in target_sockets:
		if _destination_entry_used(builder, target_id, target_entry):
			continue
		var final_exit := DungeonGraph.WALL_RIGHT if target_entry == DungeonGraph.BOTTOM_LEFT else DungeonGraph.WALL_LEFT
		var approach_coordinate: Vector2i = target.coordinate - _exit_offset(final_exit)
		var path := _upward_path(builder, source_coordinate, approach_coordinate, generator_rng)
		if path.is_empty() and source_coordinate != approach_coordinate:
			continue
		var current_id := source_id
		var current_coordinate := source_coordinate
		for path_coordinate in path:
			var step_x: int = path_coordinate.x - current_coordinate.x
			var socket_id := DungeonGraph.WALL_LEFT if step_x < 0 else DungeonGraph.WALL_RIGHT
			var next_id := builder.add_room(path_coordinate, DungeonGraph.ROOM_COMBAT)
			builder.link(current_id, socket_id, next_id, &"", ROUTE_DIG)
			current_id = next_id
			current_coordinate = path_coordinate
		builder.link(current_id, final_exit, target_id, &"", ROUTE_DIG)
		return true
	return false


static func _upward_path(
	builder: LayoutBuilder,
	start: Vector2i,
	goal: Vector2i,
	generator_rng: RandomNumberGenerator
) -> Array[Vector2i]:
	if goal.y < start.y:
		return []
	var pending: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		if current == goal:
			break
		if current.y >= goal.y:
			continue
		var directions: Array[int] = [-1, 1]
		if generator_rng.randi_range(0, 1) == 1:
			directions.reverse()
		for direction in directions:
			var candidate := current + Vector2i(direction, 1)
			var steps_left: int = goal.y - candidate.y
			if abs(goal.x - candidate.x) > steps_left or posmod(abs(goal.x - candidate.x), 2) != posmod(steps_left, 2):
				continue
			if previous.has(candidate) or (candidate != goal and builder.room_ids_by_coordinate.has(candidate)):
				continue
			previous[candidate] = current
			pending.append(candidate)
	if not previous.has(goal):
		return []
	var reversed_path: Array[Vector2i] = []
	var cursor := goal
	while cursor != start:
		reversed_path.append(cursor)
		cursor = previous[cursor] as Vector2i
	reversed_path.reverse()
	return reversed_path


static func _destination_entry_used(builder: LayoutBuilder, room_id: StringName, entry_socket: StringName) -> bool:
	for connection in builder.layout.connections:
		if connection.destination_room_id == room_id and connection.destination_entry == entry_socket:
			return true
	return false


static func _add_safe_cross_links(builder: LayoutBuilder, generator_rng: RandomNumberGenerator) -> void:
	# Cross-link only layers without a progression gate. The result creates loops
	# throughout naturally adjacent branches without routing around a color,
	# element, or entrance-Orb requirement.
	var gated_source_depths: Dictionary = {}
	for connection in builder.layout.connections:
		if connection.resolved_gate_type() == DungeonGraph.GATE_NONE:
			continue
		var gated_source = builder.room_spec(connection.source_room_id)
		if gated_source != null:
			gated_source_depths[gated_source.coordinate.y] = true
	var candidates: Array[Dictionary] = []
	for source in builder.layout.rooms:
		if source.room_type == DungeonGraph.ROOM_START or source.room_type == DungeonGraph.ROOM_BOSS or gated_source_depths.has(source.coordinate.y):
			continue
		for direction in [-1, 1]:
			var destination_coordinate: Vector2i = source.coordinate + Vector2i(direction, 1)
			var destination_id: StringName = builder.room_ids_by_coordinate.get(destination_coordinate, &"") as StringName
			if destination_id.is_empty():
				continue
			var destination = builder.room_spec(destination_id)
			if destination == null or destination.room_type == DungeonGraph.ROOM_BOSS:
				continue
			var exit_socket := DungeonGraph.WALL_LEFT if direction < 0 else DungeonGraph.WALL_RIGHT
			var entry_socket := DungeonGraph.paired_socket(exit_socket)
			if builder.connection_keys.has("%s:%s" % [source.id, exit_socket]) or _destination_entry_used(builder, destination_id, entry_socket):
				continue
			if _rooms_are_connected(builder, source.id, destination_id):
				continue
			candidates.append({"source": source.id, "socket": exit_socket, "destination": destination_id})
	for candidate in candidates:
		if generator_rng.randf() >= 0.45:
			continue
		var source_id: StringName = candidate["source"] as StringName
		var socket_id: StringName = candidate["socket"] as StringName
		var destination_id: StringName = candidate["destination"] as StringName
		if builder.connection_keys.has("%s:%s" % [source_id, socket_id]) or _destination_entry_used(builder, destination_id, DungeonGraph.paired_socket(socket_id)):
			continue
		builder.link(source_id, socket_id, destination_id, &"", ROUTE_REJOIN)


static func _rooms_are_connected(builder: LayoutBuilder, first_id: StringName, second_id: StringName) -> bool:
	for connection in builder.layout.connections:
		if (connection.source_room_id == first_id and connection.destination_room_id == second_id) or (connection.source_room_id == second_id and connection.destination_room_id == first_id):
			return true
	return false


static func _add_fusion_prerequisite_orb(
	builder: LayoutBuilder,
	source_room_id: StringName,
	source_coordinate: Vector2i,
	main_socket: StringName
) -> void:
	# The opposite wall is the preferred visual placement, but a generated
	# route can legitimately occupy that coordinate. Curriculum-critical Orbs
	# must still get a connected branch, so fall back to lower exits rather than
	# silently producing a gate with no way to charge it.
	var candidate_sockets: Array[StringName] = [
		DungeonGraph.WALL_RIGHT if main_socket == DungeonGraph.WALL_LEFT else DungeonGraph.WALL_LEFT,
		DungeonGraph.BOTTOM_LEFT,
		DungeonGraph.BOTTOM_RIGHT,
	]
	for candidate_socket in candidate_sockets:
		var connection_key := "%s:%s" % [source_room_id, candidate_socket]
		var candidate_coordinate := source_coordinate + _exit_offset(candidate_socket)
		if builder.connection_keys.has(connection_key) or builder.room_ids_by_coordinate.has(candidate_coordinate):
			continue
		var orb_id := builder.add_room(candidate_coordinate, DungeonGraph.ROOM_ORB)
		builder.link(source_room_id, candidate_socket, orb_id, &"", ROUTE_FUSION_PREREQUISITE_ORB)
		return
	push_error("Generated fusion tier has no free Orb branch at %s." % source_room_id)


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
	forward_requirement: StringName = &"",
	room_target: int = -1
) -> void:
	var source = builder.room_spec(source_room_id)
	if source == null:
		return
	# Four-way Hubs add two intentional lower dig rooms before the normal
	# progression branches are filled. Reserve one additional slot for a
	# mandatory prerequisite Orb that may be added immediately before this
	# optional route, keeping the final layout within the target + 2 ceiling.
	if room_target >= 0 and builder.layout.rooms.size() >= room_target + 1:
		return
	var side_socket := DungeonGraph.WALL_RIGHT if main_socket == DungeonGraph.WALL_LEFT else DungeonGraph.WALL_LEFT
	var side_connection_key := "%s:%s" % [source_room_id, side_socket]
	var side_coordinate := source_coordinate + _exit_offset(side_socket)
	# A mandatory prerequisite (or an earlier deterministic branch) may already
	# own this socket.  Optional rewards must yield instead of asking
	# LayoutBuilder to reuse an exit and emitting a malformed duplicate edge.
	# Reusing an existing room coordinate is still valid: LayoutBuilder returns
	# that room's stable id and the authored graph can have two doors converge on
	# it, which preserves the seeded Special Room choice on crossing layouts.
	if builder.connection_keys.has(side_connection_key):
		return
	# A deterministic detour takes precedence over the generic Special Room
	# reward.  The first alternate flame is intentionally staged from a Special
	# Room, so handling Special first would silently replace the required Fire
	# Room with a treasure branch and make the flame progression disappear.
	if detour_type == ROUTE_DETOUR_ORB:
		var orb_id := builder.add_room(side_coordinate, DungeonGraph.ROOM_ORB)
		builder.link(source_room_id, side_socket, orb_id, &"", ROUTE_DETOUR_ORB)
		return
	if detour_type == ROUTE_DETOUR_FIRE:
		var fire_id := builder.add_room(side_coordinate, DungeonGraph.ROOM_FIRE, 0, &"", detour_flame)
		builder.link(source_room_id, side_socket, fire_id, &"", ROUTE_DETOUR_FIRE)
		return
	if source.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY:
		# Every Special Room offers an optional side reward. The first beat and
		# most later seeds use a grey gate; some later seeds use the starter color
		# so the room can present two distinct primary choices.
		var requirement: StringName = _special_side_requirement(source_depth, second_special_depth, completed_runs, alternate_flames, forward_requirement, generator_rng)
		var treasure_id := builder.add_room(side_coordinate, DungeonGraph.ROOM_TREASURE, 1)
		builder.link(source_room_id, side_socket, treasure_id, requirement, ROUTE_OPTIONAL_TREASURE)
		return
	# Guarantee a third optional reward branch, then add a small number of
	# deterministic side routes so higher runs feel broader without losing the
	# readable spine of Run 1.
	var guaranteed_treasure: bool = source_depth == boss_depth - 8 or source_depth == boss_depth - 5
	var random_side_route: bool = source.room_type == DungeonGraph.ROOM_COMBAT and source_depth >= 5 and source_depth < second_special_depth and (room_target < 0 or builder.layout.rooms.size() < room_target) and generator_rng.randf() < 0.30
	if not guaranteed_treasure and not random_side_route:
		return
	var room_type: StringName = DungeonGraph.ROOM_TREASURE if guaranteed_treasure or generator_rng.randf() < 0.72 else DungeonGraph.ROOM_FIRE
	var chest_count: int = 1 if room_type == DungeonGraph.ROOM_TREASURE else 0
	var utility_flame := alternate_flames[0] if not alternate_flames.is_empty() else starter_flame
	var branch_id := builder.add_room(side_coordinate, room_type, chest_count, &"", utility_flame if room_type == DungeonGraph.ROOM_FIRE else &"")
	builder.link(source_room_id, side_socket, branch_id, &"", ROUTE_OPTIONAL_TREASURE if room_type == DungeonGraph.ROOM_TREASURE else &"optional_utility")


static func _exit_offset(socket_id: StringName) -> Vector2i:
	return DungeonGraph.exit_offset(socket_id)


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


static func _initial_run_flame(starter_flame: StringName, bound_flame: StringName) -> StringName:
	if ASPECT_CATALOG_SCRIPT.is_elemental_flame(bound_flame):
		return bound_flame
	return starter_flame if ASPECT_CATALOG_SCRIPT.is_starter_flame(starter_flame) else &"fire"


static func _normalize_color_gate_requirements(layout, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"") -> void:
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
		# Optional Treasure doors are authored as alternate choices. Their
		# restriction should remain seed-owned so a late Special Room can expose
		# the intended puzzle_c/puzzle_d pair; only the critical route is repaired
		# for reachability below.
		if connection.route_role != ROUTE_MAIN and connection.route_role != ROUTE_KEY_PROGRESSION:
			continue
		var required_flame := _flame_for_puzzle_color(connection.color_requirement, starter_flame, completed_runs)
		var side_flames := _side_flames_for_connection(layout, connection.source_room_id, blocked_connections, completed_runs, starter_flame, bound_flame)
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
	starter_flame: StringName,
	bound_flame: StringName = &""
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
		if room.room_type == DungeonGraph.ROOM_START:
			var starting_flame := _initial_run_flame(starter_flame, bound_flame)
			if not side_flames.has(starting_flame):
				side_flames.append(starting_flame)
		if room.room_type == DungeonGraph.ROOM_FIRE and not room.fire_flame.is_empty() and (room.fire_flame in available or room.fire_flame == bound_flame) and not side_flames.has(room.fire_flame):
			side_flames.append(room.fire_flame)
	return side_flames


static func _layout_connection_key(connection) -> String:
	return "%s:%s" % [connection.source_room_id, connection.exit_socket]


static func _fusion_gate_reachability_errors(layout, start_id: StringName, boss_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"") -> Array[String]:
	var errors: Array[String] = []
	var states := _element_reachable_states(layout, start_id, completed_runs, starter_flame, bound_flame)
	var reachable_boss := false
	for state in states:
		if state.get("room_id", &"") == boss_id:
			reachable_boss = true
			break
	if not reachable_boss:
		errors.append("generated fusion curriculum leaves the boss unreachable")
	for connection in layout.connections:
		if connection.resolved_gate_type() != DungeonGraph.GATE_ENTRANCE_ORB:
			continue
		var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(connection.orb_element_requirement)
		var gate_reachable := false
		for state in states:
			if state.get("room_id", &"") != connection.source_room_id:
				continue
			if int(state.get("orb_element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)) == required_element:
				gate_reachable = true
				break
		if not gate_reachable:
			errors.append("generated entrance-orb gate has no reachable matching result: %s:%s requires %s" % [connection.source_room_id, connection.exit_socket, connection.orb_element_requirement])
	return errors


static func _fusion_orb_route_errors(layout) -> Array[String]:
	var errors: Array[String] = []
	for gate in layout.connections:
		if gate.resolved_gate_type() != DungeonGraph.GATE_ENTRANCE_ORB:
			continue
		var prerequisite_orb_found := false
		for candidate in layout.connections:
			if candidate.source_room_id != gate.source_room_id:
				continue
			var destination = null
			for room in layout.rooms:
				if room.id == candidate.destination_room_id:
					destination = room
					break
			if destination != null and destination.room_type == DungeonGraph.ROOM_ORB and candidate.route_role == ROUTE_FUSION_PREREQUISITE_ORB:
				prerequisite_orb_found = true
				break
		if not prerequisite_orb_found:
			errors.append("generated entrance-orb gate lacks a pre-gate prerequisite Orb branch: %s:%s" % [gate.source_room_id, gate.exit_socket])
	return errors


static func _fusion_orb_softlock_errors(layout, start_id: StringName, boss_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"") -> Array[String]:
	var errors: Array[String] = []
	var reachable_states := _element_reachable_states(layout, start_id, completed_runs, starter_flame, bound_flame)
	var required_by_orb: Dictionary = {}
	for orb_connection in layout.connections:
		if orb_connection.route_role != ROUTE_FUSION_PREREQUISITE_ORB:
			continue
		var requirements: Array = required_by_orb.get(orb_connection.destination_room_id, []) as Array
		for gate in layout.connections:
			if gate.source_room_id != orb_connection.source_room_id or gate.resolved_gate_type() != DungeonGraph.GATE_ENTRANCE_ORB:
				continue
			var requirement := ELEMENT_CATALOG_SCRIPT.element_for_id(gate.orb_element_requirement)
			if requirement != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL and requirement not in requirements:
				requirements.append(requirement)
		required_by_orb[orb_connection.destination_room_id] = requirements
	var checked: Dictionary = {}
	for state in reachable_states:
		var room_id: StringName = state.get("room_id", &"") as StringName
		var orb_element := int(state.get("orb_element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL))
		var current_element := int(state.get("element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL))
		var requirements: Array = required_by_orb.get(room_id, []) as Array
		# The mandatory action is charging a gate's dedicated Orb with that gate's
		# exact element. Validate each such post-activation state once. This catches
		# nested-lock traps without repeatedly exploring unrelated optional colors.
		if orb_element != current_element or orb_element not in requirements:
			continue
		var state_key := "%s:%s:%d" % [room_id, state.get("flame", &""), orb_element]
		if checked.has(state_key):
			continue
		checked[state_key] = true
		var continuation := _element_reachable_states(layout, room_id, completed_runs, starter_flame, bound_flame, state)
		var reaches_boss := false
		for next_state in continuation:
			if next_state.get("room_id", &"") == boss_id:
				reaches_boss = true
				break
		if not reaches_boss:
			errors.append("activating Orb %s as %s creates an unrecoverable world state" % [room_id, ELEMENT_CATALOG_SCRIPT.id(orb_element)])
	return errors


static func _element_reachable_states(layout, start_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"", starting_state: Dictionary = {}) -> Array[Dictionary]:
	var rooms_by_id: Dictionary = {}
	for room in layout.rooms:
		rooms_by_id[room.id] = room
	var initial_flame := _initial_run_flame(starter_flame, bound_flame)
	var available := ASPECT_CATALOG_SCRIPT.flames_available_for_run(completed_runs, starter_flame)
	var pending: Array[Dictionary] = [starting_state.duplicate() if not starting_state.is_empty() else {"room_id": start_id, "flame": initial_flame, "orb_element": ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL}]
	var visited: Dictionary = {}
	var reachable_states: Array[Dictionary] = []
	while not pending.is_empty():
		var state: Dictionary = pending.pop_back()
		var room_id: StringName = state.get("room_id", &"") as StringName
		var room = rooms_by_id.get(room_id)
		var current_flame: StringName = state.get("flame", initial_flame) as StringName
		var orb_element := ELEMENT_CATALOG_SCRIPT.normalize(int(state.get("orb_element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)))
		var state_key := "%s:%s:%d" % [room_id, current_flame, orb_element]
		if visited.has(state_key):
			continue
		visited[state_key] = true
		var current_element := ELEMENT_CATALOG_SCRIPT.element_for_palette(ASPECT_CATALOG_SCRIPT.palette_for_flame(current_flame))
		var normalized_state := {"room_id": room_id, "flame": current_flame, "element": current_element, "orb_element": orb_element}
		reachable_states.append(normalized_state)
		# A Fire Room is the only place the carried element can change. Model the
		# real swap and fusion actions as explicit states at this exact room.
		if room != null and room.room_type == DungeonGraph.ROOM_FIRE and not room.fire_flame.is_empty() and (room.fire_flame in available or room.fire_flame == bound_flame):
			if room.fire_flame != current_flame:
				pending.append({"room_id": room_id, "flame": room.fire_flame, "orb_element": orb_element})
			var fusion_flame := ASPECT_CATALOG_SCRIPT.fusion_result(current_flame, room.fire_flame)
			if not fusion_flame.is_empty() and fusion_flame != current_flame:
				pending.append({"room_id": room_id, "flame": fusion_flame, "orb_element": orb_element})
		# An Orb Room accepts only the element the player physically carried there.
		# Historical flames and fusion ingredients are not remotely selectable.
		if room != null and room.room_type == DungeonGraph.ROOM_ORB:
			if current_element != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL and current_element != orb_element:
				pending.append({"room_id": room_id, "flame": current_flame, "orb_element": current_element})
		for connection in layout.connections:
			if connection.source_room_id != room_id and connection.destination_room_id != room_id:
				continue
			var gate_type: StringName = connection.resolved_gate_type()
			if gate_type == DungeonGraph.GATE_ELEMENT and current_element != ELEMENT_CATALOG_SCRIPT.element_for_id(connection.element_requirement):
				continue
			if gate_type == DungeonGraph.GATE_ENTRANCE_ORB and orb_element != ELEMENT_CATALOG_SCRIPT.element_for_id(connection.orb_element_requirement):
				continue
			var next_room: StringName = connection.destination_room_id if connection.source_room_id == room_id else connection.source_room_id
			pending.append({"room_id": next_room, "flame": current_flame, "orb_element": orb_element})
	return reachable_states


static func _boss_is_color_reachable(layout, start_id: StringName, boss_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"") -> bool:
	for state in _color_reachable_states(layout, start_id, completed_runs, starter_flame, bound_flame):
		if state.get("room_id", &"") == boss_id:
			return true
	return false


static func _color_gate_reachability_errors(layout, start_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"") -> Array[String]:
	var errors: Array[String] = []
	var states := _color_reachable_states(layout, start_id, completed_runs, starter_flame, bound_flame)
	for connection in layout.connections:
		if connection.color_requirement.is_empty():
			continue
		# Optional Treasure doors are alternate rewards, not progression gates.
		# They may intentionally remain locked until a later flame is earned; the
		# safety contract applies to the main/key route only.
		if connection.route_role != ROUTE_MAIN and connection.route_role != ROUTE_KEY_PROGRESSION:
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


static func _color_gate_side_flame_errors(layout, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"") -> Array[String]:
	var errors: Array[String] = []
	var blocked_connections: Dictionary = {}
	for connection in layout.connections:
		if not connection.color_requirement.is_empty():
			blocked_connections[_layout_connection_key(connection)] = true
	for connection in layout.connections:
		if connection.color_requirement.is_empty() or connection.color_requirement == &"puzzle_b":
			continue
		# See _color_gate_reachability_errors: an optional reward can be
		# unavailable from the current side without making the run unsolvable.
		if connection.route_role != ROUTE_MAIN and connection.route_role != ROUTE_KEY_PROGRESSION:
			continue
		var required_flame := _flame_for_puzzle_color(connection.color_requirement, starter_flame, completed_runs)
		if required_flame.is_empty():
			continue
		var side_flames := _side_flames_for_connection(layout, connection.source_room_id, blocked_connections, completed_runs, starter_flame, bound_flame)
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


static func _color_reachable_states(layout, start_id: StringName, completed_runs: int, starter_flame: StringName, bound_flame: StringName = &"") -> Array[Dictionary]:
	var rooms_by_id: Dictionary = {}
	for room in layout.rooms:
		rooms_by_id[room.id] = room
	var initial_flame := _initial_run_flame(starter_flame, bound_flame)
	var pending: Array[Dictionary] = [{"room_id": start_id, "color": &"puzzle_b", "flames": [initial_flame]}]
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
			# A bound fusion flame is the player's real persistent identity even
			# when it is not one of the starter curriculum flames.  Treat its Fire
			# Room exactly like an available starter room for the color solver; the
			# element solver below already follows this same rule.
			if room.fire_flame in available or room.fire_flame == bound_flame:
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
