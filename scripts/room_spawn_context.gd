extends RoomRuntimeContext
class_name RoomSpawnContext

## Typed runtime input for the initial enemy-spawn orchestration of one room.
## The lower-level placement solver remains owned by RoomController.

var state: Dictionary = {}


func _init(new_runtime: GameplayState, new_room_controller: RoomController) -> void:
	super(new_runtime, new_room_controller)
	if runtime == null or room_controller == null:
		return
	if room_controller != null:
		state = room_controller.room_states.get(room_id, {}) as Dictionary
