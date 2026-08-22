extends Node
class_name RoomPuzzleController

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const DEPTH_Z_SCALE := 10.0


func set_door_active(root: Object, is_active: bool) -> void:
	root.door_active = is_active
	root.call("_refresh_room_socket_visuals", is_active)


func configure_room_sockets(root: Object, is_unlocked: bool) -> void:
	root.room_controller.configure_sockets(root.dungeon_graph, root.current_room_id, is_unlocked, Callable(root, "_build_entrance_block_polygons"))
	root.door_active = is_unlocked
	root.entrance_open = is_unlocked or root.current_room_type == DungeonGraph.ROOM_PUZZLE
	root.call("_refresh_room_socket_visuals", is_unlocked)


func current_run_puzzle_flame(root: Object) -> StringName:
	return root.player_profile.starter_flame if root.player_profile != null and AspectCatalogScript.is_starter_flame(root.player_profile.starter_flame) else &"fire"


func puzzle_required_aspect(root: Object, room: DungeonGraph.RoomRecord) -> StringName:
	return &"gray" if root.dungeon_graph != null and room != null and root.dungeon_graph.is_tutorial_gray_puzzle_depth(room.depth) else current_run_puzzle_flame(root)


func puzzle_palette_for_aspect(aspect: StringName) -> String:
	return "grey" if aspect == &"gray" else AspectCatalogScript.palette_for_flame(aspect)


func update_puzzle_room_tint(root: Object, room: DungeonGraph.RoomRecord, required_flame: StringName) -> void:
	if room == null or room.room_type != DungeonGraph.ROOM_PUZZLE:
		apply_puzzle_environment_tint(root, Color.WHITE)
		return
	var palette: String = puzzle_palette_for_aspect(required_flame)
	if palette == "grey":
		apply_puzzle_environment_tint(root, Color.WHITE)
		return
	var environment_tint := Color.WHITE.lerp(PaletteLibrary.normal(palette), 0.38)
	apply_puzzle_environment_tint(root, environment_tint)


func apply_puzzle_environment_tint(root: Object, tint: Color) -> void:
	if root.background_environment != null:
		root.background_environment.self_modulate = Color.WHITE
	# Reset every authored surface first so an unused entrance cannot retain a
	# tint from a previous room.
	var surface_paths: Array[NodePath] = [^"FloorTiles/FloorLayer", ^"FloorTiles/FloorLFaceLayer", ^"FloorTiles/FloorRFaceLayer", ^"FloorTiles/Entrance", ^"FloorTiles/EntranceRight", ^"Walls/WallLeftLayer", ^"Walls/WallRightLayer", ^"Walls/DoorLeft", ^"Walls/DoorRight"]
	for path in surface_paths:
		var surface: Node = root.map_root.get_node_or_null(path) if root.map_root != null else null
		set_puzzle_surface_tint(surface, Color.WHITE)
	if tint == Color.WHITE:
		return
	for path in [^"FloorTiles/FloorLayer", ^"FloorTiles/FloorLFaceLayer", ^"FloorTiles/FloorRFaceLayer", ^"Walls/WallLeftLayer", ^"Walls/WallRightLayer"]:
		set_puzzle_surface_tint(root.map_root.get_node_or_null(path) if root.map_root != null else null, tint)
	for socket_value in root.room_controller.active_door_sockets.values():
		var door_socket := socket_value as DungeonSocket
		set_puzzle_surface_tint(door_socket.visual() if door_socket != null else null, tint)
	for socket_value in root.room_controller.active_entrance_sockets.values():
		var entrance_socket := socket_value as DungeonSocket
		set_puzzle_surface_tint(entrance_socket.visual() if entrance_socket != null else null, tint)


func set_puzzle_surface_tint(node: Node, tint: Color) -> void:
	if node == null:
		return
	if node is CanvasItem:
		(node as CanvasItem).self_modulate = tint
	for child in node.get_children():
		set_puzzle_surface_tint(child, tint)


func build_puzzle_torches(root: Object, state: Dictionary) -> void:
	clear_puzzle_torches(root)
	if root.walkable_outline.is_empty():
		return
	var bounds := Rect2(root.walkable_outline[0], Vector2.ZERO)
	for point in root.walkable_outline: bounds = bounds.expand(point)
	var positions: Array[Vector2] = [Vector2(bounds.position.x + 18.0, bounds.position.y + 14.0), Vector2(bounds.end.x - 18.0, bounds.position.y + 14.0)]
	var saved_colors: Array = state.get("puzzle_torch_colors", ["grey", "grey"])
	var colors: Array[String] = []
	for index in positions.size():
		var torch := Sprite2D.new()
		torch.name = "PuzzleTorch%d" % (index + 1)
		torch.texture = root.call("_pixel_particle_texture", Color.WHITE, 6)
		torch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		torch.z_as_relative = false
		torch.global_position = root.call("_nearest_slime_walkable_point", positions[index])
		torch.z_index = int(round(torch.global_position.y * DEPTH_Z_SCALE)) + 1
		var palette: String = String(saved_colors[index]) if index < saved_colors.size() else "grey"
		torch.set_meta("puzzle_torch_palette", palette)
		torch.self_modulate = PaletteLibrary.normal(palette)
		root.add_child(torch)
		root.puzzle_torches.append(torch)
		if not root.depth_sprites.has(torch): root.depth_sprites.append(torch)
		colors.append(palette)
	state["puzzle_torch_colors"] = colors


func clear_puzzle_torches(root: Object) -> void:
	for torch in root.puzzle_torches:
		if torch != null and is_instance_valid(torch):
			root.depth_sprites.erase(torch)
			torch.queue_free()
	root.puzzle_torches.clear()


func puzzle_torches_solved(root: Object, required_palette: String) -> bool:
	if root.puzzle_torches.size() < 2 or required_palette.is_empty():
		return false
	for torch in root.puzzle_torches:
		if String(torch.get_meta("puzzle_torch_palette", "grey")) != required_palette:
			return false
	return true


func refresh_puzzle_torch_puzzle_state(root: Object) -> void:
	if root.current_room_type != DungeonGraph.ROOM_PUZZLE or root.room_controller == null:
		return
	var state: Dictionary = root.room_controller.room_states.get(root.current_room_id, {}) as Dictionary
	var room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(root.current_room_id) if root.dungeon_graph != null else null
	var required_aspect: StringName = StringName(state.get("puzzle_required_flame", puzzle_required_aspect(root, room)))
	var required_palette: String = puzzle_palette_for_aspect(required_aspect)
	var solved: bool = puzzle_torches_solved(root, required_palette)
	state["finished"] = solved
	root.room_controller.room_states[root.current_room_id] = state
	set_door_active(root, solved)
	configure_room_sockets(root, solved)


func activate_puzzle_torch(root: Object, torch: Sprite2D, world_position: Vector2, palette: String) -> void:
	if torch == null or not is_instance_valid(torch):
		return
	torch.set_meta("puzzle_torch_palette", palette)
	torch.self_modulate = PaletteLibrary.normal(palette)
	var state: Dictionary = root.room_controller.room_states.get(root.current_room_id, {}) as Dictionary
	var colors: Array = state.get("puzzle_torch_colors", [])
	var torch_index: int = root.puzzle_torches.find(torch)
	if torch_index >= 0:
		while colors.size() < root.puzzle_torches.size(): colors.append("grey")
		colors[torch_index] = palette
		state["puzzle_torch_colors"] = colors
		root.room_controller.room_states[root.current_room_id] = state
	root.call("_play_sound", "magic_hit", -8.0, 1.0)
	root.call("_spawn_magic_impact", world_position, palette)
	refresh_puzzle_torch_puzzle_state(root)


func refresh_room_socket_visuals(root: Object, is_unlocked: bool) -> void:
	var shut_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorRightenemyshut.png")
	var open_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorRight.png")
	var stairs_down_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorStairsRight.png")
	var stairs_up_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorStairsUPRight.png")
	for socket_value in root.room_controller.active_door_sockets.values():
		var socket := socket_value as DungeonSocket
		var visual := socket.visual() as Sprite2D
		if visual == null: continue
		var connection: DungeonGraph.ConnectionRecord = root.dungeon_graph.get_connection(root.current_room_id, socket.socket_id())
		var destination_room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(connection.destination_room_id) if connection != null else null
		var leads_downstairs: bool = destination_room != null and destination_room.room_type == DungeonGraph.ROOM_DOWNSTAIRS
		visual.visible = true
		visual.texture = stairs_up_texture if root.current_room_type == DungeonGraph.ROOM_DOWNSTAIRS else stairs_down_texture if leads_downstairs else open_texture if is_unlocked else shut_texture
		visual.flip_h = socket.socket_id() == DungeonGraph.WALL_LEFT
	for socket_value in root.room_controller.active_entrance_sockets.values():
		var socket := socket_value as DungeonSocket
		var visual := socket.visual() as Sprite2D
		if visual == null: continue
		if socket.socket_id() == DungeonGraph.BOTTOM_LEFT or socket.socket_id() == DungeonGraph.BOTTOM_RIGHT:
			visual.visible = true
			continue
		visual.visible = true
		visual.texture = open_texture
		visual.flip_h = socket.socket_id() == DungeonGraph.WALL_LEFT
