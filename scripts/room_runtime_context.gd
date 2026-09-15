extends RefCounted
class_name RoomRuntimeContext

## Shared typed runtime inputs for room-owned enemy workflows.
## Specialized contexts add only the state needed by their operation.

var runtime: GameplayState = null
var room_controller: RoomController = null
var room_id: StringName = &""
var room_type: StringName = &""
var slimes: Array[Sprite2D] = []
var player: Sprite2D = null
var chest: Sprite2D = null


func _init(new_runtime: GameplayState, new_room_controller: RoomController) -> void:
	runtime = new_runtime
	room_controller = new_room_controller
	if runtime == null:
		return
	room_id = runtime.current_room_id
	room_type = runtime.current_room_type
	slimes = runtime.slimes
	player = runtime.player
	chest = runtime.chest


func is_valid() -> bool:
	return runtime != null and room_controller != null and not room_id.is_empty()
