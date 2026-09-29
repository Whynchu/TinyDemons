extends RefCounted
class_name RoomPrefabFactory

const BASIC_ROOM_DEFINITION: RoomPrefabDefinition = preload("res://resources/definitions/room_prefab_basic.tres")


static func definition(prefab_id: StringName) -> RoomPrefabDefinition:
	if prefab_id == BASIC_ROOM_DEFINITION.prefab_id:
		return BASIC_ROOM_DEFINITION
	return null


static func prefab_id_for_room(room: DungeonGraph.RoomRecord) -> StringName:
	if room == null:
		return &""
	if not room.prefab_id.is_empty():
		return room.prefab_id
	return compatibility_prefab_id(room.room_type)


static func compatibility_prefab_id(room_type: StringName) -> StringName:
	# Older authored/generated layouts have only gameplay room type. Preserve
	# those IDs with an explicit compatibility table while scenes migrate.
	match room_type:
		DungeonGraph.ROOM_START, DungeonGraph.ROOM_COMBAT, DungeonGraph.ROOM_PUZZLE, DungeonGraph.ROOM_REST, DungeonGraph.ROOM_TRADER, DungeonGraph.ROOM_NPC, DungeonGraph.ROOM_DOWNSTAIRS, DungeonGraph.ROOM_SPECIAL_ENEMY, DungeonGraph.ROOM_TREASURE, DungeonGraph.ROOM_ORB:
			return BASIC_ROOM_DEFINITION.prefab_id
		_:
			return &""


static func create_mount(room_id: StringName, prefab_id: StringName) -> RoomPrefabMountResult:
	var result := RoomPrefabMountResult.new()
	result.room_id = room_id
	result.prefab_id = prefab_id
	var resolved_definition := definition(prefab_id)
	if resolved_definition == null:
		result.errors.append("unknown room prefab ID '%s'" % prefab_id)
		return result
	if resolved_definition.room_scene == null:
		result.errors.append("room prefab '%s' has no PackedScene" % prefab_id)
		return result
	var room_node := resolved_definition.room_scene.instantiate()
	var room_instance := room_node as Node2D
	if room_instance == null:
		result.errors.append("room prefab '%s' did not instantiate as Node2D" % prefab_id)
		if room_node != null:
			room_node.free()
		return result
	result.errors.append_array(resolved_definition.validate_instance(room_instance))
	if not result.errors.is_empty():
		room_instance.free()
		return result
	result.room_instance = room_instance
	result.map_root = room_instance.get_node_or_null(resolved_definition.map_root_path) as Node2D
	result.floor_tiles = result.map_root.get_node_or_null("FloorTiles") as Node2D if result.map_root != null else null
	result.sockets_root = result.map_root.get_node_or_null("Sockets") as Node2D if result.map_root != null else null
	if result.map_root == null or result.floor_tiles == null or result.sockets_root == null:
		result.errors.append("room prefab '%s' could not bind its map, floor, and sockets" % prefab_id)
		room_instance.free()
		result.room_instance = null
		result.map_root = null
		return result
	result.status = RoomPrefabMountResult.Status.MOUNTED
	return result


static func snapshot_assignments(graph: DungeonGraph) -> Dictionary:
	var assignments: Dictionary = {}
	if graph == null:
		return assignments
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		var resolved_id := prefab_id_for_room(room)
		if not resolved_id.is_empty():
			assignments[String(room_id)] = String(resolved_id)
	return assignments


static func apply_snapshot_assignments(graph: DungeonGraph, value: Variant) -> bool:
	if graph == null or not value is Dictionary:
		return false
	var assignments := value as Dictionary
	for raw_room_id in assignments.keys():
		var room_id := StringName(str(raw_room_id))
		var room := graph.get_room(room_id)
		var prefab_id := StringName(str(assignments[raw_room_id]))
		if room == null or definition(prefab_id) == null:
			return false
	for raw_room_id in assignments.keys():
		var room_id := StringName(str(raw_room_id))
		var room := graph.get_room(room_id)
		var prefab_id := StringName(str(assignments[raw_room_id]))
		room.prefab_id = prefab_id
	return true
