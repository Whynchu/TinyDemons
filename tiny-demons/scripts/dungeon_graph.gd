extends RefCounted
class_name DungeonGraph

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
const ROOM_REST: StringName = &"REST"
const ROOM_TRADER: StringName = &"TRADER"
const ROOM_NPC: StringName = &"NPC"

const START_ROOM_ID: StringName = &"room_0_0"


class ConnectionRecord extends RefCounted:
	var source_room_id: StringName
	var exit_socket: StringName
	var destination_room_id: StringName
	var destination_entry: StringName


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
		}


var dungeon_seed: int = 0
var start_room_id: StringName = START_ROOM_ID

var _rooms: Dictionary = {}
var _connections: Dictionary = {}
var _milestone_rooms: Dictionary = {}


## Clears any previous graph and creates the root room.
func initialize(new_seed: int) -> RoomRecord:
	dungeon_seed = new_seed
	start_room_id = START_ROOM_ID
	_rooms.clear()
	_connections.clear()
	_milestone_rooms.clear()
	return _ensure_room(Vector2i.ZERO, ROOM_START)


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


## Returns the connected room, creating its deterministic connection if needed.
func get_destination(room_id: StringName, exit_socket: StringName) -> RoomRecord:
	var connection := ensure_connection(room_id, exit_socket)
	if connection == null:
		return null
	return get_room(connection.destination_room_id)


func get_connection(room_id: StringName, exit_socket: StringName) -> ConnectionRecord:
	return _connections.get(_connection_key(room_id, exit_socket)) as ConnectionRecord


func get_connection_for_entry(room_id: StringName, entry_socket: StringName) -> ConnectionRecord:
	var room := get_room(room_id)
	if room == null:
		return null
	return room.get_incoming_connection(entry_socket)


func get_room_depth(room_id: StringName) -> int:
	var room := get_room(room_id)
	return room.depth if room != null else -1


func get_room_display_number(room_id: StringName) -> int:
	var room := get_room(room_id)
	return room.display_number if room != null else 0


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
	var is_milestone := room_coordinate.y == 6 or room_coordinate.y == 11
	if is_milestone:
		if not _milestone_rooms.has(room_coordinate.y):
			_milestone_rooms[room_coordinate.y] = room_id
			room_type = ROOM_NPC
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


func _connection_key(room_id: StringName, exit_socket: StringName) -> String:
	return "%s:%s" % [room_id, exit_socket]


func _is_exit_socket(socket: StringName) -> bool:
	return socket == WALL_LEFT or socket == WALL_RIGHT


func _exit_offset(exit_socket: StringName) -> Vector2i:
	return Vector2i(-1, 1) if exit_socket == WALL_LEFT else Vector2i(1, 1)


func _entry_for_exit(exit_socket: StringName) -> StringName:
	return BOTTOM_RIGHT if exit_socket == WALL_LEFT else BOTTOM_LEFT
