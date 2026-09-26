extends RefCounted
class_name RoomActivationContext

## Typed runtime input for applying one room's persisted state.
##
var services: RoomActivationServices = null
var room_controller: Node = null
var room_id: StringName = &""
var room_type: StringName = &""
var room: DungeonGraph.RoomRecord = null
var state: Dictionary = {}


func _init(new_services: RoomActivationServices, new_room_controller: Node, new_room_id: StringName, new_room_type: StringName, new_room: DungeonGraph.RoomRecord, new_state: Dictionary) -> void:
	services = new_services
	room_controller = new_room_controller
	room_id = new_room_id
	room_type = new_room_type
	room = new_room
	state = new_state


func is_valid() -> bool:
	return services != null and services.is_valid() and room_controller != null and room != null and not state.is_empty()
