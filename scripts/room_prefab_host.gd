extends Node2D
class_name RoomPrefabHost

const FACTORY_SCRIPT = preload("res://scripts/room_prefab_factory.gd")

var active_room_id: StringName = &""
var active_prefab_id: StringName = &""
var active_room_instance: Node2D = null
var active_map_root: Node2D = null


func mount_room(room_id: StringName, prefab_id: StringName) -> RoomPrefabMountResult:
	if (active_room_instance != null
		and is_instance_valid(active_room_instance)
		and active_room_id == room_id
		and active_prefab_id == prefab_id
		and active_map_root != null
		and is_instance_valid(active_map_root)
	):
		var reused := RoomPrefabMountResult.new()
		reused.status = RoomPrefabMountResult.Status.REUSED
		reused.room_id = room_id
		reused.prefab_id = prefab_id
		reused.room_instance = active_room_instance
		reused.map_root = active_map_root
		reused.floor_tiles = active_map_root.get_node_or_null("FloorTiles") as Node2D
		reused.sockets_root = active_map_root.get_node_or_null("Sockets") as Node2D
		return reused
	var candidate := FACTORY_SCRIPT.create_mount(room_id, prefab_id) as RoomPrefabMountResult
	if candidate == null or not candidate.succeeded():
		return candidate
	candidate.room_instance.name = "ActiveRoom"
	add_child(candidate.room_instance)
	var old_instance := active_room_instance
	active_room_id = room_id
	active_prefab_id = prefab_id
	active_room_instance = candidate.room_instance
	active_map_root = candidate.map_root
	if old_instance != null and is_instance_valid(old_instance):
		old_instance.visible = false
		old_instance.queue_free()
	return candidate
