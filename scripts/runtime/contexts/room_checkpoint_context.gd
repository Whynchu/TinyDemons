extends RefCounted
class_name RoomCheckpointContext

## Snapshot of the runtime values needed to persist one room. RoomController
## owns the room-state dictionary; this context keeps gameplay presentation and
## transient pickup data out of that serialization method's root lookup path.

var room_id: StringName = &""
var room_type: StringName = &""
var room: DungeonGraph.RoomRecord = null
var room_controller: RoomController = null
var puzzle_finished := false
var room_is_cleared := false
var chest_claimed := false
var chest_evaporated := false
var world_item_drops: Array[Dictionary] = []
var chroma_pickup_controller: ChromaPickupController = null
var gold_pickups: Array = []


func _init(
	new_room_id: StringName,
	new_room_type: StringName,
	new_room: DungeonGraph.RoomRecord,
	new_room_controller: RoomController,
	new_puzzle_finished: bool,
	new_room_is_cleared: bool,
	new_chest_claimed: bool,
	new_chest_evaporated: bool,
	new_world_item_drops: Array[Dictionary],
	new_chroma_pickup_controller: ChromaPickupController,
	new_gold_pickup_controller: GoldPickupController
) -> void:
	room_id = new_room_id
	room_type = new_room_type
	room = new_room
	room_controller = new_room_controller
	puzzle_finished = new_puzzle_finished
	room_is_cleared = new_room_is_cleared
	chest_claimed = new_chest_claimed
	chest_evaporated = new_chest_evaporated
	world_item_drops = new_world_item_drops
	chroma_pickup_controller = new_chroma_pickup_controller
	gold_pickups = new_gold_pickup_controller.snapshot() if new_gold_pickup_controller != null else []


func is_valid() -> bool:
	return not room_id.is_empty() and room_controller != null
