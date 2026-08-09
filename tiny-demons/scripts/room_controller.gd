extends Node
class_name RoomController

signal room_entered(room_id: StringName, room_type: StringName)
signal room_cleared(room_id: StringName)

var current_room_id: StringName = &""
var arrival_socket_id: StringName = &""
var room_states: Dictionary = {}


func set_current_room(room_id: StringName, room_type: StringName) -> void:
	current_room_id = room_id
	room_entered.emit(room_id, room_type)


func enter_room(room_id: StringName, room_type: StringName, arrival_socket: StringName = &"") -> void:
	arrival_socket_id = arrival_socket
	set_current_room(room_id, room_type)


func mark_cleared(room_id: StringName) -> void:
	room_states[room_id] = true
	room_cleared.emit(room_id)


func is_cleared(room_id: StringName) -> bool:
	return bool(room_states.get(room_id, false))
