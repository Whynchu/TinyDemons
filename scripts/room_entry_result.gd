extends RefCounted
class_name RoomEntryResult

## Typed outcome of room-entry execution.

enum Status {
	INVALID_CONTEXT,
	MISSING_PLAYER,
	ENTERED,
}

var status := Status.INVALID_CONTEXT
var room_id: StringName = &""
var room_type: StringName = &""
var transition: RoomTransitionResult = null


func succeeded() -> bool:
	return status == Status.ENTERED


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
