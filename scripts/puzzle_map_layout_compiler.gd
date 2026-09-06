extends RefCounted
class_name PuzzleMapLayoutCompiler

## Compiles a validated pixel plan into the authored dungeon-layout contract.
##
## The image remains the source of truth for minimap placement and gate
## location. Room IDs and runtime coordinates are generated from those points,
## while every connection keeps the paired socket contract used by normal room
## traversal.

const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")
const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const R3_SCRIPT = preload("res://scripts/puzzle_map_r3.gd")

const R3_MAP_SIZE := Vector2i(35, 35)
const R3_HUB_COORDINATE := Vector2i(17, 17)


static func build_r3(starter_flame: StringName, run_flame: StringName):
	var plan: PuzzleMapGrid.MapPlan = R3_SCRIPT.build()
	var layout: DungeonLayoutDefinition = LAYOUT_DEFINITION_SCRIPT.new(&"RUN3", R3_MAP_SIZE)
	var active_coordinates: Dictionary = GRID_SCRIPT.active_room_coordinates(plan)
	var marker_kinds: Dictionary = _room_marker_kinds(plan)
	var room_distances: Dictionary = _room_distances(plan)
	var room_ids: Dictionary = {}
	var used_runtime_coordinates: Dictionary = {}
	var room_index := 0
	var room_coordinates: Array[Vector2i] = _ordered_coordinates(active_coordinates)
	for map_coordinate in room_coordinates:
		var room_id: StringName = _room_id(map_coordinate)
		var room_type: StringName = _room_type_for_marker(StringName(marker_kinds.get(map_coordinate, &"")))
		var chest_count := 1 if room_type == DungeonGraph.ROOM_TREASURE else 0
		var fire_flame: StringName = run_flame if room_type == DungeonGraph.ROOM_FIRE else &""
		var runtime_coordinate: Vector2i = _runtime_coordinate(map_coordinate, room_index, used_runtime_coordinates)
		used_runtime_coordinates[runtime_coordinate] = true
		room_ids[map_coordinate] = room_id
		layout.add_room(layout.make_room_spec(
			room_id,
			runtime_coordinate,
			map_coordinate,
			room_type,
			chest_count,
			&"",
			room_index,
			fire_flame
		))
		room_index += 1

	for marker in plan.markers:
		if marker == null or not GRID_SCRIPT.is_gate_marker(marker.kind):
			continue
		var endpoints: Array[Vector2i] = GRID_SCRIPT.gate_endpoints(marker.coordinate)
		if endpoints.size() != 2:
			continue
		var source_coordinate: Vector2i = _source_coordinate(endpoints, room_distances)
		var destination_coordinate: Vector2i = endpoints[1] if source_coordinate == endpoints[0] else endpoints[0]
		var source_id: StringName = StringName(room_ids.get(source_coordinate, &""))
		var destination_id: StringName = StringName(room_ids.get(destination_coordinate, &""))
		if source_id.is_empty() or destination_id.is_empty():
			continue
		var source_socket: StringName
		if destination_coordinate.y < source_coordinate.y:
			source_socket = DungeonGraph.WALL_LEFT if destination_coordinate.x < source_coordinate.x else DungeonGraph.WALL_RIGHT
		else:
			source_socket = DungeonGraph.BOTTOM_LEFT if destination_coordinate.x < source_coordinate.x else DungeonGraph.BOTTOM_RIGHT
		var destination_entry: StringName = DungeonGraph.paired_socket(source_socket)
		var color_requirement: StringName = _color_requirement_for_gate(marker.kind)
		var connection: DungeonLayoutDefinition.ConnectionSpec = layout.make_connection_spec(
			source_id,
			source_socket,
			destination_id,
			destination_entry,
			color_requirement,
			false,
			&"",
			marker.coordinate
		)
		# R3's authored color doors are the puzzle's route unlocks. They must open
		# as soon as their Orb color requirement is satisfied, even when the room
		# on the source side still contains an unengaged encounter. Lower exits use
		# the same scoutable policy even when they are ordinary grey connections.
		var is_lower_exit: bool = source_socket == DungeonGraph.BOTTOM_LEFT or source_socket == DungeonGraph.BOTTOM_RIGHT
		if is_lower_exit or not color_requirement.is_empty():
			connection.requires_source_room_clear = false
			connection.locks_entry_on_destination_engagement = true
		connection.door_display_requirement = &"grey_orb" if marker.kind == GRID_SCRIPT.MARKER_GATE_ORB_GREY else &""
		layout.add_connection(connection)

	return layout


static func _room_marker_kinds(plan: PuzzleMapGrid.MapPlan) -> Dictionary:
	var marker_kinds: Dictionary = {}
	for marker in plan.markers:
		if marker == null or GRID_SCRIPT.is_gate_marker(marker.kind):
			continue
		marker_kinds[marker.coordinate] = marker.kind
	return marker_kinds


static func _room_distances(plan: PuzzleMapGrid.MapPlan) -> Dictionary:
	var distances: Dictionary = {R3_HUB_COORDINATE: 0}
	var pending: Array[Vector2i] = [R3_HUB_COORDINATE]
	while not pending.is_empty():
		var current: Vector2i = pending.pop_front()
		var next_distance: int = int(distances[current]) + 1
		for marker in plan.markers:
			if marker == null or not GRID_SCRIPT.is_gate_marker(marker.kind):
				continue
			var endpoints: Array[Vector2i] = GRID_SCRIPT.gate_endpoints(marker.coordinate)
			if not endpoints.has(current):
				continue
			var neighbor: Vector2i = endpoints[1] if endpoints[0] == current else endpoints[0]
			if distances.has(neighbor):
				continue
			distances[neighbor] = next_distance
			pending.append(neighbor)
	return distances


static func _source_coordinate(endpoints: Array[Vector2i], distances: Dictionary) -> Vector2i:
	var first_distance: int = int(distances.get(endpoints[0], 9999))
	var second_distance: int = int(distances.get(endpoints[1], 9999))
	if first_distance < second_distance:
		return endpoints[0]
	if second_distance < first_distance:
		return endpoints[1]
	# Same-depth cycle edges do not affect reachability. Keep their direction
	# deterministic and prefer the lower visual point so the normal wall-socket
	# pairing remains the default for these rare back-links.
	return endpoints[0] if endpoints[0].y > endpoints[1].y else endpoints[1]


static func _ordered_coordinates(active_coordinates: Dictionary) -> Array[Vector2i]:
	var ordered: Array[Vector2i] = []
	for y in range(R3_MAP_SIZE.y):
		for x in range(R3_MAP_SIZE.x):
			var coordinate := Vector2i(x, y)
			if active_coordinates.has(coordinate):
				ordered.append(coordinate)
	return ordered


static func _room_id(map_coordinate: Vector2i) -> StringName:
	return StringName("r3_room_%d_%d" % [map_coordinate.x, map_coordinate.y])


static func _runtime_coordinate(map_coordinate: Vector2i, room_index: int, used: Dictionary) -> Vector2i:
	if map_coordinate == R3_HUB_COORDINATE:
		return Vector2i.ZERO
	# The visual grid is a branching/cyclic puzzle lattice, not the runtime
	# generator's one-direction depth lattice. Keep the authored image's x-axis,
	# give every non-Hub room a positive depth, and repair the rare same-column
	# collision deterministically without changing minimap coordinates.
	var candidate := Vector2i(map_coordinate.x - R3_HUB_COORDINATE.x, map_coordinate.y + 1)
	if not used.has(candidate):
		return candidate
	var collision_index := room_index + 1
	while used.has(candidate):
		candidate = Vector2i(map_coordinate.x - R3_HUB_COORDINATE.x + collision_index * R3_MAP_SIZE.x, map_coordinate.y + 1)
		collision_index += 1
	return candidate


static func _room_type_for_marker(marker_kind: StringName) -> StringName:
	match marker_kind:
		GRID_SCRIPT.MARKER_HUB_ROOM:
			return DungeonGraph.ROOM_START
		GRID_SCRIPT.MARKER_BOSS_ROOM:
			return DungeonGraph.ROOM_BOSS
		GRID_SCRIPT.MARKER_CLOAKED_ROOM:
			return DungeonGraph.ROOM_CLOAKED
		GRID_SCRIPT.MARKER_ORB_ROOM:
			return DungeonGraph.ROOM_ORB
		GRID_SCRIPT.MARKER_TREASURE_ROOM:
			return DungeonGraph.ROOM_TREASURE
		GRID_SCRIPT.MARKER_FLAME_B_ROOM:
			return DungeonGraph.ROOM_FIRE
	return DungeonGraph.ROOM_COMBAT


static func _color_requirement_for_gate(marker_kind: StringName) -> StringName:
	match marker_kind:
		GRID_SCRIPT.MARKER_GATE_FLAME_A:
			return &"puzzle_a"
		GRID_SCRIPT.MARKER_GATE_ORB_GREY:
			return &"puzzle_b"
		GRID_SCRIPT.MARKER_GATE_FLAME_B:
			# Puzzle C is the first alternate primary flame in Run 3. The
			# selected starter is Puzzle A and grey is Puzzle B.
			return &"puzzle_c"
	return &""
