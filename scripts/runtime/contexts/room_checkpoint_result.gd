extends RefCounted
class_name RoomCheckpointResult

## Typed outcome for one room-state persistence pass.

enum Status {
	INVALID_CONTEXT,
	SAVED,
}

var status := Status.INVALID_CONTEXT
var room_id: StringName = &""
var finished := false


func succeeded() -> bool:
	return status == Status.SAVED


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
