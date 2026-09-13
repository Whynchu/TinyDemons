extends RefCounted
class_name PuzzleRoutePlan

const PLAN_SCRIPT = preload("res://scripts/puzzle_route_plan.gd")

## Typed, topology-only view consumed by generated-route planning and validation.
## DungeonLayoutDefinition remains the runtime compilation format.

class Gate:
	var connection
	var mandatory := false
	var prerequisite_room_ids: Array[StringName] = []
	var source_region := ""
	var destination_region := ""

	func _init(new_connection) -> void:
		connection = new_connection
		mandatory = connection.route_role == &"main" or connection.route_role == &"key_progression"


var rooms: Array = []
var connections: Array = []
var gates: Array[Gate] = []
var generation_mode: StringName = &""
var route_choice_source_room_id: StringName = &""
var route_choice_rejoin_room_id: StringName = &""
var safe_route_length := 0
var risk_route_length := 0


static func from_layout(layout):
	var plan = PLAN_SCRIPT.new()
	if layout == null:
		return plan
	plan.rooms = layout.rooms.duplicate()
	plan.connections = layout.connections.duplicate()
	plan.generation_mode = layout.generation_mode
	plan.route_choice_source_room_id = layout.route_choice_source_room_id
	plan.route_choice_rejoin_room_id = layout.route_choice_rejoin_room_id
	plan.safe_route_length = layout.safe_route_length
	plan.risk_route_length = layout.risk_route_length
	for connection in plan.connections:
		if connection.resolved_gate_type() == DungeonGraph.GATE_NONE:
			continue
		var gate := Gate.new(connection)
		gate.source_region = _region_for_room(plan.rooms, connection.source_room_id)
		gate.destination_region = _region_for_room(plan.rooms, connection.destination_room_id)
		for candidate in plan.connections:
			if candidate.source_room_id == connection.source_room_id and candidate.route_role == &"fusion_prerequisite_orb":
				gate.prerequisite_room_ids.append(candidate.destination_room_id)
		plan.gates.append(gate)
	return plan


static func _region_for_room(room_specs: Array, room_id: StringName) -> String:
	for room in room_specs:
		if room.id != room_id:
			continue
		if room.room_type == DungeonGraph.ROOM_START:
			return "opening"
		if room.room_type == DungeonGraph.ROOM_BOSS:
			return "boss_approach"
		if room.coordinate.y <= 4:
			return "opening"
		if room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY and room.coordinate.y <= 8:
			return "first_state"
		if room.coordinate.y >= 10:
			return "boss_approach"
		return "alternate_flame"
	return "unknown"


func validate_structure(map_size: Vector2i = Vector2i(35, 35)) -> Array[String]:
	var errors: Array[String] = []
	var coordinates: Dictionary = {}
	var degrees: Dictionary = {}
	var room_ids: Dictionary = {}
	for room in rooms:
		var coordinate: Vector2i = room.minimap_coordinate
		room_ids[room.id] = true
		if coordinate.x < 0 or coordinate.y < 0 or coordinate.x >= map_size.x or coordinate.y >= map_size.y:
			errors.append("room %s lies outside compact map at %s" % [room.id, coordinate])
		if coordinates.has(coordinate):
			errors.append("rooms %s and %s overlap at %s" % [coordinates[coordinate], room.id, coordinate])
		coordinates[coordinate] = room.id
	for connection in connections:
		if not room_ids.has(connection.source_room_id) or not room_ids.has(connection.destination_room_id):
			errors.append("connection %s:%s references a missing room" % [connection.source_room_id, connection.exit_socket])
		if DungeonGraph.paired_socket(connection.exit_socket) != connection.destination_entry:
			errors.append("connection %s:%s has an invalid paired entry socket" % [connection.source_room_id, connection.exit_socket])
		if connection.minimap_coordinate.x < 0 or connection.minimap_coordinate.y < 0 or connection.minimap_coordinate.x >= map_size.x or connection.minimap_coordinate.y >= map_size.y:
			errors.append("connection %s:%s lies outside compact map at %s" % [connection.source_room_id, connection.exit_socket, connection.minimap_coordinate])
		degrees[connection.source_room_id] = int(degrees.get(connection.source_room_id, 0)) + 1
		degrees[connection.destination_room_id] = int(degrees.get(connection.destination_room_id, 0)) + 1
	for room_id in degrees:
		if int(degrees[room_id]) > 4:
			errors.append("room %s exceeds the four-connection compact route limit" % room_id)
	return errors
