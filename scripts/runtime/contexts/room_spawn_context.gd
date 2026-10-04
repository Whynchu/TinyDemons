extends RoomEnemyContext
class_name RoomSpawnContext

## Typed runtime input for the initial enemy-spawn orchestration of one room.
## The lower-level placement solver remains owned by RoomController.

var state: Dictionary = {}


func _init(
	new_room_id: StringName,
	new_room_type: StringName,
	new_slimes: Array[Sprite2D],
	new_player: Sprite2D,
	new_chest: Sprite2D,
	new_player_foot: Vector2,
	new_chest_rect: Rect2,
	new_services: RoomEnemySpawnServices,
	new_state: Dictionary
) -> void:
	super(new_room_id, new_room_type, new_slimes, new_player, new_chest, new_player_foot, new_chest_rect, new_services)
	state = new_state
