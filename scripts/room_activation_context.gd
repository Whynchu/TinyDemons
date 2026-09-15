extends RefCounted
class_name RoomActivationContext

## Typed runtime input for applying one room's persisted state.

var runtime: GameplayState = null
var room_controller: RoomController = null
var room_id: StringName = &""
var room_type: StringName = &""
var room: DungeonGraph.RoomRecord = null
var state: Dictionary = {}


func _init(new_runtime: GameplayState, new_room_controller: RoomController) -> void:
	runtime = new_runtime
	room_controller = new_room_controller
	if runtime == null:
		return
	room_id = runtime.current_room_id
	room_type = runtime.current_room_type
	if runtime.dungeon_graph != null:
		room = runtime.dungeon_graph.get_room(room_id)
	if room_controller != null:
		state = room_controller.room_states.get(room_id, {}) as Dictionary


func is_valid() -> bool:
	return runtime != null and room_controller != null and room != null and not state.is_empty()
