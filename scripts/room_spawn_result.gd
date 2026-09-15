extends RefCounted
class_name RoomSpawnResult

## Typed report for the initial enemy spawn pass performed while activating a
## room. RoomController owns the spawn side effects; callers receive the
## outcome without reconstructing it from scene arrays and room state.

enum Status {
	READY,
	MISSING_ROOT,
}

var status := Status.READY
var room_id: StringName = &""
var room_type: StringName = &""
var requested_slots := 0
var spawned_slots := 0
var failed_slots: Array[int] = []
var first_entry := false
var animated_spawn_started := false


func is_ready() -> bool:
	return status == Status.READY


func reject(new_status: int) -> void:
	status = new_status


func record_spawn(slot: int, animated: bool) -> void:
	spawned_slots += 1
	if animated:
		animated_spawn_started = true


func record_failure(slot: int) -> void:
	failed_slots.append(slot)


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
