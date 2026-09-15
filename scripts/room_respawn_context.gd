extends RoomRuntimeContext
class_name RoomRespawnContext

## Typed runtime input for one room-respawn tick.
## RoomController owns timers and the shared typed placement solver.


func _init(new_runtime: GameplayState, new_room_controller: RoomController) -> void:
	super(new_runtime, new_room_controller)
