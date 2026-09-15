extends RefCounted
class_name RoomActivationResult

## Typed report returned after the room controller applies a room's runtime
## state. The controller still owns the side effects; callers receive one
## explicit result instead of reconstructing activation state from root fields.

enum Status {
	READY,
	MISSING_ROOT,
	INVALID_GRAPH,
	MISSING_ROOM,
	MISSING_STATE,
}

var status := Status.READY
var room_id: StringName = &""
var room_type: StringName = &""
var state: Dictionary = {}
var configured_enemy_slots := 0
var visible_enemy_slots := 0


func is_ready() -> bool:
	return status == Status.READY


func reject(new_status: int) -> void:
	status = new_status


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
