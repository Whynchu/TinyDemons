extends RefCounted
class_name RoomPrefabMountResult

enum Status {
	FAILED,
	MOUNTED,
	REUSED,
}

var status: Status = Status.FAILED
var room_id: StringName = &""
var prefab_id: StringName = &""
var room_instance: Node2D = null
var map_root: Node2D = null
var floor_tiles: Node2D = null
var sockets_root: Node2D = null
var errors: Array[String] = []


func succeeded() -> bool:
	return status != Status.FAILED and room_instance != null and map_root != null
