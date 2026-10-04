extends Node2D
class_name RoomPrefabHost

const FACTORY_SCRIPT = preload("res://scripts/content/room_prefab_factory.gd")

var active_room_id: StringName = &""
var active_prefab_id: StringName = &""
var active_room_instance: Node2D = null
var active_map_root: Node2D = null


func mount_room(room_id: StringName, prefab_id: StringName, room_type: StringName) -> RoomPrefabMountResult:
	var instance_is_live := active_room_instance != null and is_instance_valid(active_room_instance)
	var map_is_live := active_map_root != null and is_instance_valid(active_map_root)
	# The mounted scene is a pure function of the prefab, not of the room ID. Most
	# rooms share the generic shell, so keying reuse on the room ID re-instantiated
	# the same 11 KB scene on every single door crossing and freed the previous
	# one. Reusing by prefab keeps the walkable shell and every derived cache warm
	# across rooms of the same kind; only a genuine prefab change remounts.
	if instance_is_live and map_is_live and active_prefab_id == prefab_id:
		active_room_id = room_id
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


static func mount_runtime_room(
	runtime: GameplayState,
	room_id: StringName,
	geometry_rebind: Callable,
	dungeon_sockets: Dictionary,
	active_door_sockets: Dictionary,
	active_entrance_sockets: Dictionary,
	validate_sockets: Callable,
	hide_guides: Callable
) -> bool:
	if runtime == null or runtime.dungeon_graph == null:
		push_error("Room prefab mount requires an active graph.")
		return false
	var room := runtime.dungeon_graph.get_room(room_id)
	if room == null:
		push_error("Room prefab mount requested for missing room '%s'." % room_id)
		return false
	var prefab_id := FACTORY_SCRIPT.prefab_id_for_room(room)
	if prefab_id.is_empty():
		push_error("Room '%s' has no prefab assignment or compatibility mapping." % room_id)
		return false
	var host := runtime.map_root.get_node_or_null("RoomPrefabHost") as RoomPrefabHost if runtime.map_root != null else null
	if host == null:
		push_error("Room prefab host is unavailable; refusing to activate the room.")
		return false
	var mount := host.mount_room(room_id, prefab_id, room.room_type)
	if mount == null or not mount.succeeded():
		if mount != null:
			for error in mount.errors:
				push_error("Room '%s' prefab '%s': %s" % [room_id, prefab_id, error])
		else:
			push_error("Room '%s' prefab factory returned no mount result." % room_id)
		return false
	room.prefab_id = prefab_id
	# A reused shell is still bound, not assumed. The socket dictionaries, the
	# floor/socket node references and the accent-layer geometry root are all
	# room-instance state, so the rebind runs for every mount. Remounting only
	# skips the PackedScene.instantiate and the old instance's queue_free.
	if runtime.floor_tiles != mount.floor_tiles:
		runtime.floor_tiles = mount.floor_tiles
		runtime.sockets_root = mount.sockets_root
		for child_name in [&"FloorTiles", &"Walls", &"Sockets"]:
			var legacy_node := runtime.map_root.get_node_or_null(NodePath(String(child_name))) as CanvasItem
			if legacy_node != null:
				legacy_node.visible = false
		if runtime.hub_stone_accent_layer != null:
			runtime.hub_stone_accent_layer.set_room_geometry_root(mount.map_root)
		if geometry_rebind.is_valid():
			geometry_rebind.call(mount.map_root, mount.floor_tiles)
	dungeon_sockets.clear()
	active_door_sockets.clear()
	active_entrance_sockets.clear()
	runtime._collect_dungeon_sockets()
	validate_sockets.call()
	hide_guides.call(mount.floor_tiles)
	return true


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


static func chest_position_in_gameplay_root(runtime: GameplayState) -> Vector2:
	if runtime == null:
		return Vector2.ZERO
	var marker_position: Variant = marker_position_in_gameplay_root(runtime, &"TREASURE_CHEST")
	if marker_position is Vector2:
		return marker_position
	var graph := runtime.dungeon_graph
	var room := graph.get_room(runtime.current_room_id) if graph != null else null
	if room != null and room.chest_position != Vector2.ZERO:
		return room.chest_position
	return runtime.chest_start_position


func _hide_editor_preview_nodes(node: Node) -> void:
	if node.has_meta("room_preview_only") and node is CanvasItem:
		(node as CanvasItem).visible = false
	for child in node.get_children():
		_hide_editor_preview_nodes(child)
