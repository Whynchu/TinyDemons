extends RefCounted
class_name RoomTransitionResult

## Typed handoff between a room-transition decision and its runtime executor.
##
## The room controller owns how a transition is selected. The composition root
## should only receive this result, not a loose collection of destination IDs
## whose meaning has to be reconstructed through reflection.

enum Status {
	READY,
	INVALID_GRAPH,
	MISSING_SOURCE,
	MISSING_DESTINATION,
	INVALID_CONNECTION,
}

var status := Status.READY
var source_room_id: StringName = &""
var destination_room_id: StringName = &""
var departure_socket_id: StringName = &""
var arrival_socket_id: StringName = &""
var destination_room_type: StringName = &""
var reason: StringName = &""


func is_ready() -> bool:
	return status == Status.READY


func reject(new_status: int, new_reason: StringName) -> void:
	status = new_status
	reason = new_reason


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
