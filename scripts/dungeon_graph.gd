extends RefCounted
class_name DungeonGraph

const LAYOUT_DEFINITION_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")

## Deterministic, in-memory dungeon topology.
##
## Rooms occupy a branching lattice. A left-wall exit leads down-left into the
## destination's bottom-right entrance; a right-wall exit leads down-right into
## its bottom-left entrance. Coordinate-derived room IDs make the result stable
## regardless of the order in which connections are discovered.

const WALL_LEFT: StringName = &"WALL_LEFT"
const WALL_RIGHT: StringName = &"WALL_RIGHT"
const BOTTOM_LEFT: StringName = &"BOTTOM_LEFT"
const BOTTOM_RIGHT: StringName = &"BOTTOM_RIGHT"

const ROOM_START: StringName = &"START"
const ROOM_COMBAT: StringName = &"COMBAT"
const ROOM_PUZZLE: StringName = &"PUZZLE"
const ROOM_REST: StringName = &"REST"
const ROOM_TRADER: StringName = &"TRADER"
const ROOM_NPC: StringName = &"NPC"
const ROOM_DOWNSTAIRS: StringName = &"DOWNSTAIRS"
const ROOM_SPECIAL_ENEMY: StringName = &"SPECIAL_ENEMY"
const ROOM_TREASURE: StringName = &"TREASURE"
# These authored names intentionally reuse the existing runtime room handlers
# until their content policies are split into dedicated components.
const ROOM_FIRE: StringName = ROOM_REST
const ROOM_CLOAKED: StringName = ROOM_NPC
const ROOM_BOSS: StringName = ROOM_DOWNSTAIRS
const ROOM_ORB: StringName = &"ORB"

const START_ROOM_ID: StringName = &"room_0_0"
const DUNGEON_NAME := "SLIMEY DEPTHS"


class ConnectionRecord extends RefCounted:
	var source_room_id: StringName
	var exit_socket: StringName
	var destination_room_id: StringName
	var destination_entry: StringName
	var color_requirement: StringName = &""
	var hidden_until_clear := false
	var hidden_until_event: StringName = &""
	var minimap_coordinate := Vector2i.ZERO
	var requires_source_room_clear := true
	var allow_entry_before_source_clear := false
	var locks_entry_on_destination_engagement := true
	var route_role: StringName = &"main"


	func _init(
		new_source_room_id: StringName,
		new_exit_socket: StringName,
		new_destination_room_id: StringName,
		new_destination_entry: StringName
	) -> void:
		source_room_id = new_source_room_id
		exit_socket = new_exit_socket
		destination_room_id = new_destination_room_id
		destination_entry = new_destination_entry


	func to_dictionary() -> Dictionary:
		return {
			"source_room_id": source_room_id,
			"exit_socket": exit_socket,
			"destination_room_id": destination_room_id,
			"destination_entry": destination_entry,
			"color_requirement": color_requirement,
			"hidden_until_clear": hidden_until_clear,
			"hidden_until_event": hidden_until_event,
			"minimap_coordinate": minimap_coordinate,
			"requires_source_room_clear": requires_source_room_clear,
			"allow_entry_before_source_clear": allow_entry_before_source_clear,
			"locks_entry_on_destination_engagement": locks_entry_on_destination_engagement,
			"route_role": route_role,
		}


class RoomRecord extends RefCounted:
	var id: StringName
	var coordinate: Vector2i
	var depth: int
	var display_number: int
	var generation_seed: int
	var room_type: StringName
	var outgoing_connections: Dictionary = {}
	var incoming_connections: Dictionary = {}
	var milestone_dead_end := false
	var minimap_coordinate := Vector2i.ZERO
	var chest_count := 0
	var special_respawn_required_color: StringName = &""
	var fire_flame: StringName = &""
	var authored := false


	func _init(new_id: StringName, new_coordinate: Vector2i, new_seed: int, new_room_type: StringName) -> void:
		id = new_id
		coordinate = new_coordinate
		depth = maxi(new_coordinate.y, 0)
		# The root is an unnumbered safe room; its children begin at Depth 1.
		display_number = depth
		generation_seed = new_seed
		room_type = new_room_type


	func get_connection(exit_socket: StringName) -> ConnectionRecord:
		return outgoing_connections.get(exit_socket) as ConnectionRecord


	func get_incoming_connection(entry_socket: StringName) -> ConnectionRecord:
		return incoming_connections.get(entry_socket) as ConnectionRecord


	func to_dictionary() -> Dictionary:
		var outgoing_data: Dictionary = {}
		for socket: StringName in outgoing_connections:
			var connection := outgoing_connections[socket] as ConnectionRecord
			outgoing_data[socket] = connection.to_dictionary()

		var incoming_data: Dictionary = {}
		for socket: StringName in incoming_connections:
			var connection := incoming_connections[socket] as ConnectionRecord
			incoming_data[socket] = connection.to_dictionary()

		return {
			"id": id,
			"coordinate": coordinate,
			"depth": depth,
			"display_number": display_number,
			"generation_seed": generation_seed,
			"room_type": room_type,
			"outgoing_connections": outgoing_data,
			"incoming_connections": incoming_data,
			"milestone_dead_end": milestone_dead_end,
			"minimap_coordinate": minimap_coordinate,
			"chest_count": chest_count,
			"special_respawn_required_color": special_respawn_required_color,
			"fire_flame": fire_flame,
			"authored": authored,
		}


var dungeon_seed: int = 0
var start_room_id: StringName = START_ROOM_ID
var completed_run_count := 0
var target_boss_depth := 12
var tutorial_starter_puzzle_depth := -1
var tutorial_gray_puzzle_depth := -1
var authored_run1 := false

var _rooms: Dictionary = {}
var _connections: Dictionary = {}
var _milestone_rooms: Dictionary = {}


## Clears any previous graph and creates the root room.
func initialize(new_seed: int) -> RoomRecord:
	dungeon_seed = new_seed
	authored_run1 = false
	_configure_tutorial_puzzle_depths()
	start_room_id = START_ROOM_ID
	_rooms.clear()
	_connections.clear()
	_milestone_rooms.clear()
	return _ensure_room(Vector2i.ZERO, ROOM_START)


func initialize_from_layout(new_seed: int, layout) -> RoomRecord:
	if layout == null:
		return initialize(new_seed)
	dungeon_seed = new_seed
	authored_run1 = layout.layout_id == &"RUN1"
	tutorial_starter_puzzle_depth = -1
	tutorial_gray_puzzle_depth = -1
	_rooms.clear()
	_connections.clear()
	_milestone_rooms.clear()
	for spec in layout.rooms:
		var room := RoomRecord.new(spec.id, spec.coordinate, _room_seed_for_spec(spec.id, spec.seed_salt), spec.room_type)
		room.depth = maxi(spec.coordinate.y, 0)
		room.display_number = room.depth
		room.minimap_coordinate = spec.minimap_coordinate
		room.chest_count = spec.chest_count
		room.special_respawn_required_color = spec.special_respawn_required_color
		room.fire_flame = spec.fire_flame
		room.authored = true
		_rooms[room.id] = room
		if room.room_type == ROOM_START:
			start_room_id = room.id
	for spec in layout.connections:
		if spec.destination_room_id.is_empty():
			continue
		var source_room := get_room(spec.source_room_id)
		var destination_room := get_room(spec.destination_room_id)
		if source_room == null or destination_room == null:
			push_error("DungeonGraph: authored connection references a missing room.")
			continue
		var connection := ConnectionRecord.new(spec.source_room_id, spec.exit_socket, spec.destination_room_id, spec.destination_entry)
		connection.color_requirement = spec.color_requirement
		connection.hidden_until_clear = spec.hidden_until_clear
		connection.hidden_until_event = spec.hidden_until_event
		connection.minimap_coordinate = spec.minimap_coordinate
		connection.requires_source_room_clear = spec.requires_source_room_clear
		connection.allow_entry_before_source_clear = spec.allow_entry_before_source_clear
		connection.locks_entry_on_destination_engagement = spec.locks_entry_on_destination_engagement
		connection.route_role = spec.route_role
		source_room.outgoing_connections[connection.exit_socket] = connection
		destination_room.incoming_connections[connection.destination_entry] = connection
		_connections[_connection_key(connection.source_room_id, connection.exit_socket)] = connection
	return get_room(start_room_id)


func is_authored_run1() -> bool:
	return authored_run1


func configure_progression(completed_runs: int) -> void:
	completed_run_count = maxi(completed_runs, 0)
	# Each clear adds a depth, up to a compact but meaningfully broader late run.
	target_boss_depth = 12 + mini(completed_run_count, 4)


func final_npc_depth() -> int:
	return target_boss_depth - 1


func is_tutorial_starter_puzzle_depth(depth: int) -> bool:
	return completed_run_count == 0 and depth == tutorial_starter_puzzle_depth


func is_tutorial_gray_puzzle_depth(depth: int) -> bool:
	return completed_run_count == 0 and depth == tutorial_gray_puzzle_depth


func _configure_tutorial_puzzle_depths() -> void:
	if completed_run_count != 0:
		tutorial_starter_puzzle_depth = -1
		tutorial_gray_puzzle_depth = -1
		return
	var tutorial_rng := RandomNumberGenerator.new()
	tutorial_rng.seed = dungeon_seed + 4409
	# Keep the starter lesson before the depth-6 NPC milestone and the Gray
	# lesson after it, guaranteeing separation and ordering on the required path.
	tutorial_starter_puzzle_depth = tutorial_rng.randi_range(2, 4)
	tutorial_gray_puzzle_depth = tutorial_rng.randi_range(7, 9)


func side_route_chance() -> float:
	return clampf(0.55 + float(completed_run_count) * 0.015, 0.55, 0.62)


func side_dead_end_chance() -> float:
	return clampf(0.28 + float(completed_run_count) * 0.025, 0.28, 0.40)


func get_room(room_id: StringName) -> RoomRecord:
	return _rooms.get(room_id) as RoomRecord


## Creates a stable connection once, then returns that same record on revisits.
func ensure_connection(
	room_id: StringName,
	exit_socket: StringName,
	destination_room_type: StringName = ROOM_COMBAT
) -> ConnectionRecord:
	var source_room := get_room(room_id)
	if source_room == null:
		push_error("DungeonGraph: unknown source room '%s'." % room_id)
		return null
	if not _is_exit_socket(exit_socket):
		push_error("DungeonGraph: unknown exit socket '%s'." % exit_socket)
		return null

	var existing_connection := source_room.get_connection(exit_socket)
	if existing_connection != null:
		return existing_connection

	var destination_coordinate := source_room.coordinate + _exit_offset(exit_socket)
	var destination_room := _ensure_room(destination_coordinate, destination_room_type)
	# Keep arrival on the paired lower entrance, matching normal room travel.
	var destination_entry := _entry_for_exit(exit_socket)
	var connection := ConnectionRecord.new(
		room_id,
		exit_socket,
		destination_room.id,
		destination_entry
	)

	source_room.outgoing_connections[exit_socket] = connection
	destination_room.incoming_connections[destination_entry] = connection
	_connections[_connection_key(room_id, exit_socket)] = connection
	return connection


func get_connection(room_id: StringName, exit_socket: StringName) -> ConnectionRecord:
	return _connections.get(_connection_key(room_id, exit_socket)) as ConnectionRecord


func get_connection_for_entry(room_id: StringName, entry_socket: StringName) -> ConnectionRecord:
	var room := get_room(room_id)
	if room == null:
		return null
	return room.get_incoming_connection(entry_socket)


func get_room_ids() -> Array[StringName]:
	var room_ids: Array[StringName] = []
	for room_id: StringName in _rooms:
		room_ids.append(room_id)
	return room_ids


func _ensure_room(room_coordinate: Vector2i, room_type: StringName = ROOM_COMBAT) -> RoomRecord:
	var room_id := _room_id_for_coordinate(room_coordinate)
	var existing_room := get_room(room_id)
	if existing_room != null:
		return existing_room
	var is_tutorial_puzzle := is_tutorial_starter_puzzle_depth(room_coordinate.y) or is_tutorial_gray_puzzle_depth(room_coordinate.y)
	var is_milestone := is_tutorial_puzzle or room_coordinate.y == 6 or room_coordinate.y == final_npc_depth()
	if is_milestone:
		if not _milestone_rooms.has(room_coordinate.y):
			_milestone_rooms[room_coordinate.y] = room_id
			room_type = ROOM_PUZZLE if is_tutorial_puzzle else ROOM_NPC
		else:
			room_type = ROOM_COMBAT

	var room := RoomRecord.new(
		room_id,
		room_coordinate,
		_room_seed_for_coordinate(room_coordinate),
		room_type
	)
	room.milestone_dead_end = is_milestone and _milestone_rooms[room_coordinate.y] != room_id
	_rooms[room_id] = room
	return room


func _room_id_for_coordinate(room_coordinate: Vector2i) -> StringName:
	return StringName("room_%d_%d" % [room_coordinate.x, room_coordinate.y])


func _room_seed_for_coordinate(room_coordinate: Vector2i) -> int:
	var seed_key := "%d:%d:%d" % [dungeon_seed, room_coordinate.x, room_coordinate.y]
	return seed_key.hash()


func _room_seed_for_spec(room_id: StringName, seed_salt: int) -> int:
	return int(dungeon_seed) ^ String(room_id).hash() ^ seed_salt


func _connection_key(room_id: StringName, exit_socket: StringName) -> String:
	return "%s:%s" % [room_id, exit_socket]


func _is_exit_socket(socket: StringName) -> bool:
	return socket == WALL_LEFT or socket == WALL_RIGHT


func _exit_offset(exit_socket: StringName) -> Vector2i:
	return Vector2i(-1, 1) if exit_socket == WALL_LEFT else Vector2i(1, 1)


func _entry_for_exit(exit_socket: StringName) -> StringName:
	return BOTTOM_RIGHT if exit_socket == WALL_LEFT else BOTTOM_LEFT
