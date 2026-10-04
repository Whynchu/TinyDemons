extends RefCounted
class_name RoomClearResult

## Typed event emitted after RoomController applies a room-clear mutation.
##
## A result is emitted only for a newly-cleared room. Repeated calls still
## return a result so direct callers can inspect the stable room identity.

enum Status {
	INVALID_CONTEXT,
	ALREADY_CLEARED,
	CLEARED,
}

var status := Status.INVALID_CONTEXT
var room_id: StringName = &""
var room_type: StringName = &""
var was_finished := false
var became_finished := false
var popcorn_respawn_scheduled := false
var special_clear_earned := false


func succeeded() -> bool:
	return status == Status.CLEARED or status == Status.ALREADY_CLEARED


func is_new_clear() -> bool:
	return status == Status.CLEARED and became_finished


func status_name() -> StringName:
	return StringName(Status.keys()[status]) if status >= 0 and status < Status.size() else &"UNKNOWN"
