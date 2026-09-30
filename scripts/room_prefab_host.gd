extends Node2D
class_name RoomPrefabHost

const FACTORY_SCRIPT = preload("res://scripts/room_prefab_factory.gd")

var active_room_id: StringName = &""
var active_prefab_id: StringName = &""
var active_room_instance: Node2D = null
var active_map_root: Node2D = null


func mount_room(room_id: StringName, prefab_id: StringName, room_type: StringName) -> RoomPrefabMountResult:
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
	var candidate := FACTORY_SCRIPT.create_mount(room_id, prefab_id, room_type) as RoomPrefabMountResult
	if candidate == null or not candidate.succeeded():
		return candidate
	candidate.room_instance.name = "ActiveRoom"
	candidate.room_instance.set_meta("room_prefab_id", prefab_id)
	_hide_editor_preview_nodes(candidate.room_instance)
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


func resolve_marker(marker_id: StringName) -> Marker2D:
	if active_room_instance == null or not is_instance_valid(active_room_instance):
		return null
	var definition := FACTORY_SCRIPT.definition(active_prefab_id) as RoomPrefabDefinition
	return definition.resolve_marker(active_room_instance, marker_id) if definition != null else null


static func resolve_marker_in_map(map_root: Node2D, marker_id: StringName) -> Marker2D:
	if map_root == null:
		return null
	var host := map_root.get_node_or_null("RoomPrefabHost") as RoomPrefabHost
	return host.resolve_marker(marker_id) if host != null else null


static func marker_position_in_gameplay_root(runtime: GameplayState, marker_id: StringName) -> Variant:
	if runtime == null:
		return null
	var marker := resolve_marker_in_map(runtime.map_root, marker_id)
	if marker == null or not is_instance_valid(marker):
		return null
	return runtime.to_local(marker.global_position)


func _hide_editor_preview_nodes(node: Node) -> void:
	if node.has_meta("room_preview_only") and node is CanvasItem:
		(node as CanvasItem).visible = false
	for child in node.get_children():
		_hide_editor_preview_nodes(child)
