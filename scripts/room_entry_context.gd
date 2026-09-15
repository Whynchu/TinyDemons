extends RefCounted
class_name RoomEntryContext

## Typed runtime input for one room-entry execution.

var runtime: GameplayState = null
var transition: RoomTransitionResult = null


func _init(new_runtime: GameplayState, new_transition: RoomTransitionResult) -> void:
	runtime = new_runtime
	transition = new_transition


func is_valid() -> bool:
	return runtime != null and transition != null and transition.is_ready()
