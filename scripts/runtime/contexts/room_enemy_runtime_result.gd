extends RefCounted
class_name RoomEnemyRuntimeResult

## Typed outcome of one enemy-runtime snapshot pass.

enum Status {
	INVALID_CONTEXT,
	EMPTY,
	SAVED,
}

var status := Status.INVALID_CONTEXT
var room_id: StringName = &""
var saved_slots := 0


func succeeded() -> bool:
	return status == Status.EMPTY or status == Status.SAVED


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
