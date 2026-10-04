extends RoomEnemyContext
class_name RoomRespawnContext

## Typed runtime input for one room-respawn tick.
## RoomController owns timers and the shared typed placement solver.


func _init(
	new_room_id: StringName,
	new_room_type: StringName,
	new_slimes: Array[Sprite2D],
	new_player: Sprite2D,
	new_chest: Sprite2D,
	new_player_foot: Vector2,
	new_chest_rect: Rect2,
	new_services: RoomEnemySpawnServices
) -> void:
	super(new_room_id, new_room_type, new_slimes, new_player, new_chest, new_player_foot, new_chest_rect, new_services)
