extends RefCounted
class_name RoomSpawnContext

## Typed runtime input for the initial enemy-spawn orchestration of one room.
## The lower-level placement solver remains owned by RoomController.

var runtime: GameplayState = null
var room_controller: RoomController = null
var room_id: StringName = &""
var room_type: StringName = &""
var state: Dictionary = {}
var slimes: Array[Sprite2D] = []


func _init(new_runtime: GameplayState, new_room_controller: RoomController) -> void:
	runtime = new_runtime
	room_controller = new_room_controller
	if runtime == null:
		return
	room_id = runtime.current_room_id
	room_type = runtime.current_room_type
	slimes = runtime.slimes
	if room_controller != null:
		state = room_controller.room_states.get(room_id, {}) as Dictionary


func is_valid() -> bool:
	return runtime != null and room_controller != null and not room_id.is_empty()
