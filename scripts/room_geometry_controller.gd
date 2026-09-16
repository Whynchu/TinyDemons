extends RefCounted
class_name RoomGeometryController

## Owns room-boundary geometry and the camera used by the authored boss room.
##
## The geometry service receives the exact scene nodes it needs at composition
## time. It intentionally does not retain a GameplayState/root reference, so
## room transitions can apply and restore geometry without reflection through
## the coordinator.

const BOSS_ROOM_AUTHORING_SCENE := "res://scenes/boss_room_debug.tscn"
const ACTOR_FOOT_OFFSET := Vector2(8, 15)

var map_root: Node2D = null
var floor_tiles: Node2D = null
var player: Sprite2D = null
var display_controller: DisplayController = null
var scene_file_path := ""
var normal_room_geometry: Dictionary = {}
var boss_geometry_active := false
var boss_room_authoring_template: Node = null


func configure(
	new_map_root: Node2D,
	new_floor_tiles: Node2D,
	new_player: Sprite2D,
	new_display_controller: DisplayController,
	new_scene_file_path: String
) -> void:
	map_root = new_map_root
	floor_tiles = new_floor_tiles
	player = new_player
	display_controller = new_display_controller
	scene_file_path = new_scene_file_path


func dispose() -> void:
	if boss_room_authoring_template != null and is_instance_valid(boss_room_authoring_template):
		boss_room_authoring_template.free()
	boss_room_authoring_template = null


func prewarm_transition_assets(stone_layer: HubStoneAccentLayer, room_type: StringName) -> void:
	# Parse and instantiate the authored geometry while the loading screen is
	# visible. The first boss entry can then reuse the template instead of doing
	# this work on the visible transition frame.
	_get_boss_room_authoring_template()
	if stone_layer == null:
		return
	capture_normal_room_geometry()
	stone_layer.prewarm_current_constraint_candidates()
	if room_type == DungeonGraph.ROOM_DOWNSTAIRS:
		return
	# Boss rooms have a second static boundary/door profile. Apply it only behind
	# the loading screen, cache every legal accent candidate, then restore the
	# normal room before gameplay is exposed.
	apply_authored_boss_room_geometry()
	stone_layer.prewarm_current_constraint_candidates()
	restore_normal_room_geometry()
	var underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D if floor_tiles != null else null
	if underlay != null:
		underlay.visible = false
	stone_layer.prewarm_current_constraint_candidates()


func apply_room_geometry(room_type: StringName) -> void:
	if floor_tiles == null:
		return
	capture_normal_room_geometry()
	if room_type != DungeonGraph.ROOM_DOWNSTAIRS:
		if boss_geometry_active:
			restore_normal_room_geometry()
			boss_geometry_active = false
		var underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
		if underlay != null:
			underlay.visible = false
		configure_large_room_camera(false)
		return
	if not boss_geometry_active:
		apply_authored_boss_room_geometry()
		boss_geometry_active = true
	configure_large_room_camera(true)


func apply_authored_boss_room_geometry() -> void:
	if floor_tiles == null or map_root == null:
		return
	if scene_file_path == BOSS_ROOM_AUTHORING_SCENE:
		var existing_underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
		if existing_underlay != null:
			existing_underlay.visible = true
		_configure_boss_return_guides()
		return
	var template := _get_boss_room_authoring_template()
	if template == null:
		return
	for path in ["FloorTiles/FloorLayer", "FloorTiles/FloorLFaceLayer", "FloorTiles/FloorRFaceLayer", "Walls/WallLeftLayer", "Walls/WallRightLayer"]:
		copy_authored_tile_layer(
			template.get_node_or_null(NodePath("Map/" + path)) as TileMapLayer,
			map_root.get_node_or_null(path) as TileMapLayer)
	copy_authored_polygon(template, "FloorTiles/FloorCollisionGuide")
	copy_boss_floor_underlay(template)
	for path in ["FloorTiles/Entrance", "FloorTiles/EntranceRight", "Walls/DoorLeft", "Walls/DoorRight"]:
		copy_authored_room_sprite(template, path)
	for path in ["Sockets/WALL_LEFT/SpawnMarker", "Sockets/WALL_RIGHT/SpawnMarker", "Sockets/BOTTOM_LEFT/SpawnMarker", "Sockets/BOTTOM_RIGHT/SpawnMarker"]:
		copy_authored_marker(template, path)
	_configure_boss_return_guides()


func _get_boss_room_authoring_template() -> Node:
	if boss_room_authoring_template != null and is_instance_valid(boss_room_authoring_template):
		return boss_room_authoring_template
	var packed_scene := load(BOSS_ROOM_AUTHORING_SCENE) as PackedScene
	if packed_scene == null:
		push_error("Could not load the authored boss room scene.")
		return null
	boss_room_authoring_template = packed_scene.instantiate()
	return boss_room_authoring_template


func _configure_boss_return_guides() -> void:
	if floor_tiles == null:
		return
	var left_guide := floor_tiles.get_node_or_null("Entrance/EntranceReturnGuide") as Polygon2D
	var right_guide := floor_tiles.get_node_or_null("EntranceRight/EntranceReturnGuide") as Polygon2D
	# The normal room guides are authored against the compact floor diamond. The
	# boss floor is larger and its lower edges sit farther out, so those guides
	# land beyond the walkable polygon. Keep the entrance art where it is, but
	# move only the return triggers inward to the reachable floor edge.
	if left_guide != null:
		left_guide.position = Vector2(11.0, -7.0)
	if right_guide != null:
		right_guide.position = Vector2(5.0, -7.0)


func copy_authored_room_sprite(template: Node, path: NodePath) -> void:
	var source := template.get_node_or_null(NodePath("Map/" + String(path))) as Sprite2D
	var destination := map_root.get_node_or_null(path) as Sprite2D if map_root != null else null
	if source == null or destination == null:
		return
	destination.position = source.position
	destination.texture = source.texture
	destination.flip_h = source.flip_h
	destination.flip_v = source.flip_v
	destination.offset = source.offset
	destination.scale = source.scale


func copy_authored_marker(template: Node, path: NodePath) -> void:
	var source := template.get_node_or_null(NodePath("Map/" + String(path))) as Marker2D
	var destination := map_root.get_node_or_null(path) as Marker2D if map_root != null else null
	if source == null or destination == null:
		return
	destination.position = source.position


func copy_boss_floor_underlay(template: Node) -> void:
	var source := template.get_node_or_null("Map/FloorTiles/BossFloorUnderlay") as Polygon2D
	if source == null or floor_tiles == null:
		return
	var underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
	if underlay == null:
		underlay = Polygon2D.new()
		underlay.name = "BossFloorUnderlay"
		floor_tiles.add_child(underlay)
	underlay.position = source.position
	underlay.polygon = source.polygon.duplicate()
	underlay.color = source.color
	underlay.z_index = -1
	underlay.visible = true


func copy_authored_tile_layer(source: TileMapLayer, destination: TileMapLayer) -> void:
	if source == null or destination == null:
		return
	# The authored layers use the same TileSet as the live room. Copying the
	# serialized layer payload lets Godot rebuild it in one native operation;
	# setting every boss cell through GDScript was a visible transition hitch.
	destination.tile_map_data = source.tile_map_data
	destination.update_internals()


func copy_authored_polygon(template: Node, path: NodePath) -> void:
	var source := template.get_node_or_null(NodePath("Map/" + String(path))) as Polygon2D
	var destination := map_root.get_node_or_null(path) as Polygon2D if map_root != null else null
	if source == null or destination == null:
		return
	destination.position = source.position
	destination.polygon = source.polygon.duplicate()


func capture_normal_room_geometry() -> void:
	if not normal_room_geometry.is_empty() or map_root == null or floor_tiles == null:
		return
	for path in ["FloorTiles/FloorLayer", "FloorTiles/FloorLFaceLayer", "FloorTiles/FloorRFaceLayer", "Walls/WallLeftLayer", "Walls/WallRightLayer"]:
		var layer := map_root.get_node_or_null(path) as TileMapLayer
		if layer != null:
			normal_room_geometry[path] = layer.get_used_cells()
			normal_room_geometry["tile_map_data:%s" % path] = layer.tile_map_data
	var guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as Polygon2D
	if guide != null:
		normal_room_geometry["guide_position"] = guide.position
		normal_room_geometry["guide_polygon"] = guide.polygon.duplicate()
	for path in ["FloorTiles/Entrance/EntranceReturnGuide", "FloorTiles/EntranceRight/EntranceReturnGuide"]:
		var return_guide := map_root.get_node_or_null(path) as Polygon2D
		if return_guide != null:
			normal_room_geometry["position:%s" % path] = return_guide.position
	for path in ["FloorTiles/Entrance", "FloorTiles/EntranceRight", "Walls/DoorLeft", "Walls/DoorRight"]:
		var node := map_root.get_node_or_null(path) as Sprite2D
		if node != null:
			normal_room_geometry["position:%s" % path] = node.position
			normal_room_geometry["texture:%s" % path] = node.texture
			normal_room_geometry["flip_h:%s" % path] = node.flip_h
			normal_room_geometry["flip_v:%s" % path] = node.flip_v
			normal_room_geometry["offset:%s" % path] = node.offset
			normal_room_geometry["scale:%s" % path] = node.scale
	for path in ["Sockets/WALL_LEFT/SpawnMarker", "Sockets/WALL_RIGHT/SpawnMarker", "Sockets/BOTTOM_LEFT/SpawnMarker", "Sockets/BOTTOM_RIGHT/SpawnMarker"]:
		var marker := map_root.get_node_or_null(path) as Marker2D
		if marker != null:
			normal_room_geometry["position:%s" % path] = marker.position


func restore_normal_room_geometry() -> void:
	if normal_room_geometry.is_empty() or map_root == null or floor_tiles == null:
		return
	for path in ["FloorTiles/FloorLayer", "FloorTiles/FloorLFaceLayer", "FloorTiles/FloorRFaceLayer", "Walls/WallLeftLayer", "Walls/WallRightLayer"]:
		var layer := map_root.get_node_or_null(path) as TileMapLayer
		if layer == null:
			continue
		var tile_map_data_key := "tile_map_data:%s" % path
		if normal_room_geometry.has(tile_map_data_key):
			layer.tile_map_data = normal_room_geometry[tile_map_data_key]
		else:
			layer.clear()
			var saved_cells: Array = normal_room_geometry.get(path, []) as Array
			for cell_value in saved_cells:
				var cell: Vector2i = cell_value
				layer.set_cell(cell, 0, Vector2i.ZERO)
		layer.update_internals()
	var guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as Polygon2D
	if guide != null:
		guide.position = normal_room_geometry.get("guide_position", guide.position)
		guide.polygon = normal_room_geometry.get("guide_polygon", guide.polygon)
	for path in ["FloorTiles/Entrance", "FloorTiles/EntranceRight", "Walls/DoorLeft", "Walls/DoorRight"]:
		var node := map_root.get_node_or_null(path) as Sprite2D
		if node != null:
			node.position = normal_room_geometry.get("position:%s" % path, node.position)
			node.texture = normal_room_geometry.get("texture:%s" % path, node.texture)
			node.flip_h = bool(normal_room_geometry.get("flip_h:%s" % path, node.flip_h))
			node.flip_v = bool(normal_room_geometry.get("flip_v:%s" % path, node.flip_v))
			node.offset = normal_room_geometry.get("offset:%s" % path, node.offset)
			node.scale = normal_room_geometry.get("scale:%s" % path, node.scale)
	for path in ["FloorTiles/Entrance/EntranceReturnGuide", "FloorTiles/EntranceRight/EntranceReturnGuide"]:
		var return_guide := map_root.get_node_or_null(path) as Polygon2D
		if return_guide != null:
			return_guide.position = normal_room_geometry.get("position:%s" % path, return_guide.position)
	for path in ["Sockets/WALL_LEFT/SpawnMarker", "Sockets/WALL_RIGHT/SpawnMarker", "Sockets/BOTTOM_LEFT/SpawnMarker", "Sockets/BOTTOM_RIGHT/SpawnMarker"]:
		var marker := map_root.get_node_or_null(path) as Marker2D
		if marker != null:
			marker.position = normal_room_geometry.get("position:%s" % path, marker.position)


func configure_large_room_camera(enabled: bool) -> void:
	if display_controller != null:
		display_controller.set_large_room_camera_active(enabled)
	if player == null:
		return
	var camera := player.get_node_or_null("LargeRoomCamera") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "LargeRoomCamera"
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.5
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		player.add_child(camera)
		camera.top_level = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.5
	camera.enabled = enabled
	if enabled:
		update_large_room_camera()


func update_large_room_camera() -> void:
	if player == null:
		return
	var camera := player.get_node_or_null("LargeRoomCamera") as Camera2D
	if camera == null or not camera.enabled:
		return
	camera.global_position = ActorGeometry.foot(player, ACTOR_FOOT_OFFSET) + Vector2(0.0, -7.0)
