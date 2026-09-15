extends RefCounted
class_name RoomEntryContext

## Typed runtime input for one room-entry execution.
##
## Transitional adapter only: this still stores the universal GameplayState
## root. Do not copy this shape for a completed slice; replace it with direct
## typed entry dependencies before counting room-entry ownership as migrated.

var runtime: GameplayState = null
var transition: RoomTransitionResult = null


func _init(new_runtime: GameplayState, new_transition: RoomTransitionResult) -> void:
	runtime = new_runtime
	transition = new_transition


func is_valid() -> bool:
	return runtime != null and transition != null and transition.is_ready()
