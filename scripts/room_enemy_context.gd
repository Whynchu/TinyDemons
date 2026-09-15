extends RefCounted
class_name RoomEnemyContext

## Shared direct inputs for one room enemy operation.
##
## This is intentionally limited to room identity, active actors, placement
## anchors, and the explicit spawn services. It is not a GameplayState wrapper.

var room_id: StringName = &""
var room_type: StringName = &""
var slimes: Array[Sprite2D] = []
var player: Sprite2D = null
var chest: Sprite2D = null
var player_foot := Vector2.ZERO
var chest_rect := Rect2()
var services: RoomEnemySpawnServices = null


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
	room_id = new_room_id
	room_type = new_room_type
	slimes = new_slimes
	player = new_player
	chest = new_chest
	player_foot = new_player_foot
	chest_rect = new_chest_rect
	services = new_services


func is_valid() -> bool:
	return not room_id.is_empty() and services != null and services.is_valid()
