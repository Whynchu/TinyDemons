extends RefCounted
class_name RunCheckpointResult

## Typed outcome for the safe-checkpoint durability sequence.

enum Status {
	INVALID_CONTEXT,
	NOT_AVAILABLE,
	ROOM_SAVE_FAILED,
	PROFILE_SAVE_FAILED,
	SNAPSHOT_INVALID,
	SNAPSHOT_SAVE_FAILED,
	SAVED,
}

var status := Status.INVALID_CONTEXT
var room_id: StringName = &""


func succeeded() -> bool:
	return status == Status.SAVED


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
