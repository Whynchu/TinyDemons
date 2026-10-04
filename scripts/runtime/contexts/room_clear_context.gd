extends RefCounted
class_name RoomClearContext

## Explicit input boundary for one room-clear mutation.
##
## RoomController remains the authority for the mutable room-state dictionary;
## callers provide the room identity and authored record needed to apply the
## clear policy without making the controller rediscover them through a root.

var room_id: StringName = &""
var room: DungeonGraph.RoomRecord = null


func _init(new_room_id: StringName, new_room: DungeonGraph.RoomRecord) -> void:
	room_id = new_room_id
	room = new_room


func is_valid() -> bool:
	return not room_id.is_empty()
