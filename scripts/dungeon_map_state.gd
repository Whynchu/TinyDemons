extends RefCounted
class_name DungeonMapState

const ELEMENT_CATALOG_SCRIPT = preload("res://scripts/element_catalog.gd")

## Mutable run state for the authored map. Topology stays in the graph/layout;
## this object owns only what the player has changed or discovered.

signal changed

const MAP_COLOR_NEUTRAL: StringName = &"neutral"
const PUZZLE_COLOR_A: StringName = &"puzzle_a"
const PUZZLE_COLOR_B: StringName = &"puzzle_b"
const PUZZLE_COLOR_C: StringName = &"puzzle_c"
const PUZZLE_COLOR_D: StringName = &"puzzle_d"
const VALID_COLORS: Array[StringName] = [MAP_COLOR_NEUTRAL, PUZZLE_COLOR_A, PUZZLE_COLOR_B, PUZZLE_COLOR_C, PUZZLE_COLOR_D]
const DEFAULT_ORB_PALETTE := "grey"

var active_puzzle_color: StringName = MAP_COLOR_NEUTRAL
var shared_orb_puzzle_color: StringName = MAP_COLOR_NEUTRAL
var shared_orb_palette := DEFAULT_ORB_PALETTE
var current_room_id: StringName = &""
var discovered_rooms: Dictionary = {}
var completed_rooms: Dictionary = {}
var engaged_rooms: Dictionary = {}
var revealed_connections: Dictionary = {}
var solved_color_connections: Dictionary = {}
var solved_element_connections: Dictionary = {}
var solved_orb_connections: Dictionary = {}
var shared_orb_element: StringName = &""
var orb_change_count := 0


func begin(start_room_id: StringName) -> void:
	# Grey is the actual starting puzzle key. Keep the neutral constant for
	# legacy serialized states, but a fresh run must expose the grey route and
	# present both Orb Rooms in their authored grey state immediately.
	active_puzzle_color = PUZZLE_COLOR_B
	shared_orb_puzzle_color = PUZZLE_COLOR_B
	shared_orb_palette = DEFAULT_ORB_PALETTE
	current_room_id = &""
	discovered_rooms.clear()
	completed_rooms.clear()
	engaged_rooms.clear()
	revealed_connections.clear()
	solved_color_connections.clear()
	solved_element_connections.clear()
	solved_orb_connections.clear()
	shared_orb_element = &""
	orb_change_count = 0
	mark_room_discovered(start_room_id)


func set_puzzle_color(next_color: StringName, count_orb_change: bool = true) -> bool:
	if next_color not in VALID_COLORS:
		return false
	var changed_value := active_puzzle_color != next_color or shared_orb_puzzle_color != next_color
	active_puzzle_color = next_color
	shared_orb_puzzle_color = next_color
	if changed_value:
		if count_orb_change:
			orb_change_count += 1
		changed.emit()
	return true


func set_orb_palette(next_palette: String) -> bool:
	var normalized := next_palette.to_lower()
	if normalized == "gray":
		normalized = DEFAULT_ORB_PALETTE
	if normalized not in PaletteLibrary.PALETTE_NAMES:
		return false
	var element := ELEMENT_CATALOG_SCRIPT.element_for_palette(normalized)
	var next_element: StringName = &"" if element == ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL else ELEMENT_CATALOG_SCRIPT.id(element)
	set_shared_orb_state(normalized, next_element)
	return true


func set_shared_orb_state(next_palette: String, next_element: StringName, emit_state_change: bool = true) -> bool:
	var changed_value := shared_orb_palette != next_palette or shared_orb_element != next_element
	shared_orb_palette = next_palette
	shared_orb_element = next_element
	if changed_value:
		if emit_state_change:
			changed.emit()
	return changed_value


func mark_room_discovered(room_id: StringName) -> void:
	if room_id.is_empty() or discovered_rooms.has(room_id):
		current_room_id = room_id if not room_id.is_empty() else current_room_id
		return
	discovered_rooms[room_id] = true
	current_room_id = room_id
	changed.emit()


func mark_room_completed(room_id: StringName) -> void:
	if room_id.is_empty():
		return
	var changed_value := false
	if not completed_rooms.has(room_id):
		completed_rooms[room_id] = true
		changed_value = true
	if engaged_rooms.has(room_id):
		engaged_rooms.erase(room_id)
		changed_value = true
	if changed_value:
		changed.emit()


func mark_room_engaged(room_id: StringName) -> bool:
	if room_id.is_empty() or completed_rooms.has(room_id) or engaged_rooms.has(room_id):
		return false
	engaged_rooms[room_id] = true
	changed.emit()
	return true


func reveal_connection(connection: DungeonGraph.ConnectionRecord) -> void:
	if connection == null:
		return
	var key := connection_key(connection.source_room_id, connection.exit_socket)
	if revealed_connections.has(key):
		return
	revealed_connections[key] = true
	changed.emit()


func is_room_discovered(room_id: StringName) -> bool:
	return bool(discovered_rooms.get(room_id, false))


func is_room_completed(room_id: StringName) -> bool:
	return bool(completed_rooms.get(room_id, false))


func is_room_engaged(room_id: StringName) -> bool:
	return bool(engaged_rooms.get(room_id, false))


func is_connection_revealed(connection: DungeonGraph.ConnectionRecord) -> bool:
	return connection != null and bool(revealed_connections.get(connection_key(connection.source_room_id, connection.exit_socket), false))


func mark_element_connection_solved(connection: DungeonGraph.ConnectionRecord) -> bool:
	if connection == null:
		return false
	var key := connection_key(connection.source_room_id, connection.exit_socket)
	if solved_element_connections.has(key):
		return false
	solved_element_connections[key] = true
	changed.emit()
	return true


func is_element_connection_solved(connection: DungeonGraph.ConnectionRecord) -> bool:
	return connection != null and bool(solved_element_connections.get(connection_key(connection.source_room_id, connection.exit_socket), false))


func mark_color_connection_solved(connection: DungeonGraph.ConnectionRecord) -> bool:
	if connection == null:
		return false
	var key := connection_key(connection.source_room_id, connection.exit_socket)
	if solved_color_connections.has(key):
		return false
	solved_color_connections[key] = true
	changed.emit()
	return true


func is_color_connection_solved(connection: DungeonGraph.ConnectionRecord) -> bool:
	return connection != null and bool(solved_color_connections.get(connection_key(connection.source_room_id, connection.exit_socket), false))


func mark_orb_connection_solved(connection: DungeonGraph.ConnectionRecord, emit_state_change: bool = true) -> bool:
	if connection == null:
		return false
	var key := connection_key(connection.source_room_id, connection.exit_socket)
	if solved_orb_connections.has(key):
		return false
	solved_orb_connections[key] = true
	if emit_state_change:
		changed.emit()
	return true


func is_orb_connection_solved(connection: DungeonGraph.ConnectionRecord) -> bool:
	return connection != null and bool(solved_orb_connections.get(connection_key(connection.source_room_id, connection.exit_socket), false))


static func connection_key(source_room_id: StringName, exit_socket: StringName) -> String:
	return "%s:%s" % [source_room_id, exit_socket]


func to_dictionary() -> Dictionary:
	return {
		"active_puzzle_color": active_puzzle_color,
		"shared_orb_puzzle_color": shared_orb_puzzle_color,
		"shared_orb_palette": shared_orb_palette,
		"current_room_id": current_room_id,
		"discovered_rooms": discovered_rooms.duplicate(),
		"completed_rooms": completed_rooms.duplicate(),
		"engaged_rooms": engaged_rooms.duplicate(),
		"revealed_connections": revealed_connections.duplicate(),
		"solved_color_connections": solved_color_connections.duplicate(),
		"solved_element_connections": solved_element_connections.duplicate(),
		"solved_orb_connections": solved_orb_connections.duplicate(),
		"shared_orb_element": shared_orb_element,
		"orb_change_count": orb_change_count,
	}
