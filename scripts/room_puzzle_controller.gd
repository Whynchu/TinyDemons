extends Node
class_name RoomPuzzleController

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const DEPTH_Z_SCALE := 10.0
const ENTRY_ORB_TEXTURE_PATH := "res://assets/artwork/entrance_orb.png"
const ENTRY_ORB_FRAME_SIZE := Vector2i(9, 9)
const ENTRY_ORB_FRAME_TIME := 0.12
const ENTRY_ORB_BOB_TIME := 2.8
const ENTRY_ORB_BOB_DISTANCE := 1.0
const STARTER_FLAME_SHUT_TEXTURE_PATH := "res://assets/artwork/DoorRightFlameshut.png"
const FIRST_ORB_TRIANGLE_PROMPT_PATH := "res://assets/artwork/triangle55.png"
const FIRST_ORB_SQUARE_PROMPT_PATH := "res://assets/artwork/square55.png"
const FIRST_ORB_PROMPT_OFFSET := Vector2(0, -12)
const AUTHORED_MAP_TINT_STRENGTH := 0.50
const AUTHORED_MAP_ART_LIGHTEN_STRENGTH := 0.20
const ORB_AUTHORING_CENTER := Vector2(120, 80)
const ORB_KNOCKBACK_DISTANCE := 5.0
const ORB_KNOCKBACK_DURATION := 0.14

var entry_orb_source_frames: Array[Texture2D] = []
var entry_orb_frames_by_palette: Dictionary = {}
var entry_orb_animation_timer := 0.0
var entry_orb_frame_timer := 0.0


func set_door_active(root: Object, is_active: bool) -> void:
	root.door_active = is_active
	root.call("_refresh_room_socket_visuals", is_active)
	# Door art and collision gates must be refreshed together. A room can expose
	# one color-matched authored socket while the legacy room-wide flag is false.
	root.call("_build_entrance_block_polygons")


func configure_room_sockets(root: Object, is_unlocked: bool) -> void:
	root.room_controller.configure_sockets(root.dungeon_graph, root.current_room_id, is_unlocked, Callable(root, "_build_entrance_block_polygons"))
	root.door_active = is_unlocked
	var room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(root.current_room_id) if root.dungeon_graph != null else null
	var is_boss_room := room != null and room.room_type == DungeonGraph.ROOM_DOWNSTAIRS
	var map_entry_open: bool = root.dungeon_map_controller != null and root.dungeon_map_controller.room_requires_open_entry(room)
	var has_active_entrance: bool = root.room_controller != null and not root.room_controller.active_entrance_sockets.is_empty()
	# Returning through an already-discovered entrance is always permitted by
	# room-clear state. The connection-level availability check still enforces
	# semantic color locks, so this cannot bypass an orb-locked route.
	# Boss rooms are the deliberate exception: the arrival route is sealed for
	# the encounter and only becomes traversable again after the boss is clear.
	root.entrance_open = is_unlocked if is_boss_room else has_active_entrance or is_unlocked or root.current_room_type == DungeonGraph.ROOM_PUZZLE or map_entry_open
	root.call("_build_entrance_block_polygons")
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
	apply_puzzle_environment_tint(root, _environment_tint(root))


func update_map_environment_tint(root: Object) -> void:
	# Puzzle Color A resolves to the selected starter palette; Puzzle Color B
	# resolves to grey. The blue/green reference pixels are placeholders only.
	apply_puzzle_environment_tint(root, _environment_tint(root))


func apply_chest_map_tint(root: Object) -> void:
	var chest := root.get("chest") as Sprite2D
	if chest == null:
		return
	var gray_texture := root.get("chest_gray_texture") as Texture2D
	var normal_texture := root.get("chest_normal_texture") as Texture2D
	var is_gray_chest := gray_texture != null and chest.texture == gray_texture
	if gray_texture == null:
		is_gray_chest = normal_texture == null or chest.texture != normal_texture
	# Grey chest art is intentionally the map-colored presentation; the Orb and
	# room surfaces use authored grey artwork without this extra tint.
	chest.self_modulate = _lightened_artwork_tint(_chest_environment_tint(root)) if is_gray_chest else Color.WHITE
	var unlock_overlay := root.get("chest_unlock_overlay") as Sprite2D
	if unlock_overlay != null:
		# The overlay is the saturated chest artwork, so its alpha may animate
		# independently without inheriting the grey chest's map tint.
		unlock_overlay.self_modulate = Color.WHITE


func _uses_global_orb_state(map_controller: Node) -> bool:
	if map_controller == null:
		return false
	if map_controller.has_method("uses_global_orb_state"):
		return bool(map_controller.call("uses_global_orb_state"))
	# Focused presentation tests provide a small fake map controller. Preserve
	# the Run 1 fallback while production maps use the explicit capability.
	return bool(map_controller.call("is_authored_run1")) if map_controller.has_method("is_authored_run1") else false


func _environment_tint(root: Object) -> Color:
	var map_controller := root.get("dungeon_map_controller") as Node
	if _uses_global_orb_state(map_controller):
		var map_palette := str(map_controller.call("active_environment_palette"))
		if not map_palette.is_empty():
			if map_palette == "grey":
				return Color.WHITE
			return _map_palette_tint(map_palette, AUTHORED_MAP_TINT_STRENGTH)
	var room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(root.current_room_id) if root.dungeon_graph != null else null
	if room == null or room.room_type != DungeonGraph.ROOM_PUZZLE:
		return Color.WHITE
	var required_aspect: StringName = root.call("_puzzle_required_aspect", room) as StringName
	var palette := puzzle_palette_for_aspect(required_aspect)
	return Color.WHITE if palette == "grey" else _map_palette_tint(palette, 0.38)


func _chest_environment_tint(root: Object) -> Color:
	var map_controller := root.get("dungeon_map_controller") as Node
	if _uses_global_orb_state(map_controller):
		var map_palette := str(map_controller.call("active_environment_palette"))
		if not map_palette.is_empty():
			return _map_palette_tint(map_palette, AUTHORED_MAP_TINT_STRENGTH)
	var room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(root.current_room_id) if root.dungeon_graph != null else null
	if room == null or room.room_type != DungeonGraph.ROOM_PUZZLE:
		return Color.WHITE
	var required_aspect: StringName = root.call("_puzzle_required_aspect", room) as StringName
	var palette := puzzle_palette_for_aspect(required_aspect)
	return _map_palette_tint(palette, 0.38)


func _map_palette_tint(palette_name: String, tint_strength: float) -> Color:
	return Color.WHITE.lerp(PaletteLibrary.normal(palette_name), tint_strength)


func _lightened_artwork_tint(tint: Color) -> Color:
	if tint == Color.WHITE:
		return Color.WHITE
	# self_modulate is multiplicative, so lifting the artwork before applying
	# the tint is represented by a uniform lift of the tint multiplier. Scaling
	# every RGB channel equally preserves the palette's original tone.
	var lift := 1.0 + AUTHORED_MAP_ART_LIGHTEN_STRENGTH
	return Color(tint.r * lift, tint.g * lift, tint.b * lift, tint.a)


func starter_flame_gate_locked(root: Object) -> bool:
	return root.get("current_room_type") == DungeonGraph.ROOM_START and not bool(root.get("starter_flame_attuned_this_run"))


func apply_puzzle_environment_tint(root: Object, tint: Color) -> void:
	var presentation_tint: Color = _lightened_artwork_tint(tint)
	if root.background_environment != null:
		root.background_environment.self_modulate = Color.WHITE
	# Reset every authored surface first so an unused entrance cannot retain a
	# tint from a previous room.
	var surface_paths: Array[NodePath] = [^"FloorTiles/FloorLayer", ^"FloorTiles/FloorLFaceLayer", ^"FloorTiles/FloorRFaceLayer", ^"FloorTiles/Entrance", ^"FloorTiles/EntranceRight", ^"Walls/WallLeftLayer", ^"Walls/WallRightLayer", ^"Walls/DoorLeft", ^"Walls/DoorRight"]
	for path in surface_paths:
		var surface: Node = root.map_root.get_node_or_null(path) if root.map_root != null else null
		set_puzzle_surface_tint(surface, Color.WHITE)
	if tint != Color.WHITE:
		for path in [^"FloorTiles/FloorLayer", ^"FloorTiles/FloorLFaceLayer", ^"FloorTiles/FloorRFaceLayer", ^"Walls/WallLeftLayer", ^"Walls/WallRightLayer"]:
			set_puzzle_surface_tint(root.map_root.get_node_or_null(path) if root.map_root != null else null, presentation_tint)
	var starter_gate_locked := starter_flame_gate_locked(root)
	for socket_value in root.room_controller.active_door_sockets.values():
		var door_socket := socket_value as DungeonSocket
		if not starter_gate_locked and tint != Color.WHITE and not _socket_is_color_locked(root, door_socket, false):
			set_puzzle_surface_tint(door_socket.visual() if door_socket != null else null, presentation_tint)
	for socket_value in root.room_controller.active_entrance_sockets.values():
		var entrance_socket := socket_value as DungeonSocket
		if entrance_socket == null:
			continue
		var entrance_visual := entrance_socket.visual()
		if entrance_visual == null:
			continue
		# Reapply the state after the global reset so both the authored entrance
		# tile and its Tile 2 child receive the same presentation color.
		var boss_entrance_closed: bool = root.current_room_type == DungeonGraph.ROOM_DOWNSTAIRS and not bool(root.get("entrance_open"))
		if not starter_gate_locked and not boss_entrance_closed and _socket_is_open(root, entrance_socket, true):
			set_puzzle_surface_tint(entrance_visual, presentation_tint)
		else:
			var connection: DungeonGraph.ConnectionRecord = root.dungeon_graph.get_connection_for_entry(root.current_room_id, entrance_socket.socket_id())
			var visual_state: StringName = root.call("_map_connection_visual_state", connection, true) as StringName
			set_puzzle_surface_tint(entrance_visual, _entrance_lock_modulate(root, connection, visual_state))
	apply_chest_map_tint(root)


func set_puzzle_surface_tint(node: Node, tint: Color) -> void:
	if node == null:
		return
	if node is CanvasItem:
		(node as CanvasItem).self_modulate = tint
	for child in node.get_children():
		set_puzzle_surface_tint(child, tint)


func _socket_is_color_locked(root: Object, socket: DungeonSocket, is_entrance: bool) -> bool:
	if socket == null or root.dungeon_graph == null:
		return false
	var connection: DungeonGraph.ConnectionRecord = root.dungeon_graph.get_connection_for_entry(root.current_room_id, socket.socket_id()) if is_entrance else root.dungeon_graph.get_connection(root.current_room_id, socket.socket_id())
	var visual_state: StringName = root.call("_map_connection_visual_state", connection, is_entrance) as StringName
	return visual_state == &"orb_locked" or visual_state == &"element_locked"


func _socket_is_open(root: Object, socket: DungeonSocket, is_entrance: bool) -> bool:
	if socket == null or root.dungeon_graph == null:
		return false
	var connection: DungeonGraph.ConnectionRecord = root.dungeon_graph.get_connection_for_entry(root.current_room_id, socket.socket_id()) if is_entrance else root.dungeon_graph.get_connection(root.current_room_id, socket.socket_id())
	var visual_state: StringName = root.call("_map_connection_visual_state", connection, is_entrance) as StringName
	return visual_state == &"open"


func build_puzzle_torches(root: Object, state: Dictionary) -> void:
	if root.walkable_outline.is_empty():
		clear_puzzle_torches(root)
		return
	var bounds := Rect2(root.walkable_outline[0], Vector2.ZERO)
	for point in root.walkable_outline: bounds = bounds.expand(point)
	var positions: Array[Vector2] = [Vector2(bounds.position.x + 18.0, bounds.position.y + 14.0), Vector2(bounds.end.x - 18.0, bounds.position.y + 14.0)]
	var saved_colors: Array = state.get("puzzle_torch_colors", ["grey", "grey"])
	_build_entry_orbs(root, state, positions, saved_colors, "puzzle_torch_colors")


func build_orb_room_orb(root: Object, state: Dictionary) -> void:
	if root.walkable_outline.is_empty():
		clear_puzzle_torches(root)
		return
	var center_position: Vector2 = ORB_AUTHORING_CENTER
	if root.map_root != null:
		# The prefab position is authored relative to Map. Resolve the fallback
		# through that same transform before adding the runtime orb to Main.
		center_position = root.map_root.to_global(ORB_AUTHORING_CENTER)
	var authored_center: Marker2D = null
	if root.map_root != null:
		authored_center = root.map_root.get_node_or_null("OrbCenterGuide") as Marker2D
	if authored_center != null:
		center_position = authored_center.global_position
	var positions: Array[Vector2] = [center_position]
	var default_palette: String = str(root.call("_map_orb_display_palette"))
	var saved_palette: String = default_palette
	# Any complete map layout owns the shared orb color. A stale room-local value
	# must never make a neutral new run render blue.
	var map_controller := root.get("dungeon_map_controller") as Node
	if not _uses_global_orb_state(map_controller):
		saved_palette = str(state.get("orb_display_palette", default_palette))
	if root.puzzle_torches.size() == 1:
		# A map-color change updates the existing orb. Keep the node alive so the
		# player's target lock and focus state remain attached to this orb.
		var existing_orb := root.puzzle_torches[0] as Sprite2D
		_apply_orb_visual(root, existing_orb, saved_palette)
		_update_first_orb_tutorial_prompt(root, existing_orb)
		state["orb_display_palette"] = saved_palette
		return
	_build_entry_orbs(root, state, positions, [saved_palette], "orb_display_palette", true)
	if not root.puzzle_torches.is_empty():
		_update_first_orb_tutorial_prompt(root, root.puzzle_torches[0])


func _build_entry_orbs(root: Object, state: Dictionary, positions: Array[Vector2], saved_colors: Array, state_key: String, preserve_world_positions: bool = false) -> void:
	clear_puzzle_torches(root)
	var colors: Array[String] = []
	for index in positions.size():
		var torch := Sprite2D.new()
		torch.name = "EntryOrb%d" % (index + 1)
		var palette: String = str(saved_colors[index]) if index < saved_colors.size() else "grey"
		var frames := entry_orb_frames(root, palette)
		torch.texture = frames[0] if not frames.is_empty() else root.call("_pixel_particle_texture", Color.WHITE, 6)
		torch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		torch.self_modulate = Color.WHITE
		# Each sheet frame is authored at its intended 1:1 display size.
		torch.scale = Vector2.ONE
		torch.set_meta("puzzle_torch_palette", palette)
		root.add_child(torch)
		torch.z_as_relative = false
		torch.global_position = positions[index] if preserve_world_positions else root.call("_nearest_slime_walkable_point", positions[index])
		torch.set_meta("puzzle_torch_base_position", torch.global_position)
		torch.z_index = int(round(torch.global_position.y * DEPTH_Z_SCALE)) + 1
		root.puzzle_torches.append(torch)
		if not root.depth_sprites.has(torch): root.depth_sprites.append(torch)
		colors.append(palette)
	state[state_key] = colors
	entry_orb_animation_timer = 0.0
	entry_orb_frame_timer = 0.0


func entry_orb_frames(root: Object, palette: String) -> Array[Texture2D]:
	if not entry_orb_frames_by_palette.has(palette):
		if entry_orb_source_frames.is_empty():
			var library := root.get("sprite_frame_library") as SpriteFrameLibrary
			if library != null:
				entry_orb_source_frames = library.slice_frames(ENTRY_ORB_TEXTURE_PATH, ENTRY_ORB_FRAME_SIZE)
		var recolored: Array[Texture2D] = []
		var frame_library := root.get("sprite_frame_library") as SpriteFrameLibrary
		if frame_library != null and not entry_orb_source_frames.is_empty():
			recolored = frame_library.recolor_orb_frames(entry_orb_source_frames, palette)
		entry_orb_frames_by_palette[palette] = recolored
	return entry_orb_frames_by_palette[palette] as Array[Texture2D]


func _apply_orb_visual(root: Object, orb: Sprite2D, palette: String) -> void:
	if orb == null or not is_instance_valid(orb):
		return
	orb.set_meta("orb_display_palette", palette)
	orb.set_meta("puzzle_torch_palette", palette)
	orb.self_modulate = Color.WHITE
	var frames := entry_orb_frames(root, palette)
	if not frames.is_empty():
		orb.texture = frames[0]
	var highlight := orb.get_node_or_null("TargetHighlight") as Sprite2D
	if highlight != null and highlight.visible:
		highlight.texture = (root.get("occlusion_renderer") as OcclusionRenderer).orb_highlighted_texture(orb.texture)


func _is_first_orb_tutorial(root: Object) -> bool:
	var map_controller := root.get("dungeon_map_controller") as Node
	if map_controller == null or not map_controller.has_method("is_authored_run1") or not bool(map_controller.call("is_authored_run1")):
		return false
	var graph := root.get("dungeon_graph") as DungeonGraph
	var room := graph.get_room(root.get("current_room_id")) if graph != null else null
	return room != null and room.room_type == DungeonGraph.ROOM_ORB and room.depth == 1


func _update_first_orb_tutorial_prompt(root: Object, orb: Sprite2D) -> void:
	if not _is_first_orb_tutorial(root) or orb == null or not is_instance_valid(orb):
		_clear_first_orb_tutorial_prompt(root)
		return
	var prompt := root.get("orb_tutorial_prompt") as Sprite2D
	if prompt == null or not is_instance_valid(prompt):
		prompt = Sprite2D.new()
		prompt.name = "FirstOrbTutorialPrompt"
		prompt.centered = true
		prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prompt.z_as_relative = false
		root.add_child(prompt)
		root.set("orb_tutorial_prompt", prompt)
		var outline := Sprite2D.new()
		outline.name = "FirstOrbTutorialPromptOutline"
		outline.centered = true
		outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		outline.z_as_relative = false
		outline.z_index = -1
		prompt.add_child(outline)
	var map_controller := root.get("dungeon_map_controller") as Node
	var active_color: StringName = StringName(map_controller.call("current_color")) if map_controller != null and map_controller.has_method("current_color") else &"puzzle_b"
	var prompt_path := FIRST_ORB_SQUARE_PROMPT_PATH if active_color == &"puzzle_a" else FIRST_ORB_TRIANGLE_PROMPT_PATH
	var prompt_texture := root.call("_load_texture_or_null", prompt_path) as Texture2D
	if prompt_texture != null:
		prompt.texture = prompt_texture
	var outline := prompt.get_node_or_null("FirstOrbTutorialPromptOutline") as Sprite2D
	if outline != null:
		outline.texture = _white_button_outline_texture(prompt.texture)
	prompt.global_position = orb.global_position + FIRST_ORB_PROMPT_OFFSET
	prompt.z_index = int(round(orb.global_position.y * DEPTH_Z_SCALE)) + 2
	if outline != null:
		outline.z_index = prompt.z_index - 1
	prompt.visible = true


func _white_button_outline_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var source_image := source.get_image()
	var image := Image.create(source_image.get_width() + 2, source_image.get_height() + 2, false, Image.FORMAT_RGBA8)
	for y in source_image.get_height():
		for x in source_image.get_width():
			if source_image.get_pixel(x, y).a <= 0.0:
				continue
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var sample_x: int = x + offset.x
				var sample_y: int = y + offset.y
				if sample_x < 0 or sample_y < 0 or sample_x >= source_image.get_width() or sample_y >= source_image.get_height() or source_image.get_pixel(sample_x, sample_y).a <= 0.0:
					image.set_pixel(x + 1 + offset.x, y + 1 + offset.y, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _clear_first_orb_tutorial_prompt(root: Object) -> void:
	var prompt := root.get("orb_tutorial_prompt") as Sprite2D
	if prompt != null and is_instance_valid(prompt):
		prompt.queue_free()
	root.set("orb_tutorial_prompt", null)


func update_entry_orb_animation(root: Object, delta: float) -> void:
	if (root.current_room_type != DungeonGraph.ROOM_PUZZLE and root.current_room_type != DungeonGraph.ROOM_ORB) or root.puzzle_torches.is_empty():
		return
	entry_orb_animation_timer = fmod(entry_orb_animation_timer + delta, ENTRY_ORB_BOB_TIME)
	entry_orb_frame_timer = fmod(entry_orb_frame_timer + delta, ENTRY_ORB_FRAME_TIME * maxi(entry_orb_source_frames.size(), 1))
	var bob := snappedf(sin((entry_orb_animation_timer / ENTRY_ORB_BOB_TIME) * TAU) * ENTRY_ORB_BOB_DISTANCE, 0.5)
	var frame_index := 0
	if not entry_orb_source_frames.is_empty():
		frame_index = posmod(floori(entry_orb_frame_timer / ENTRY_ORB_FRAME_TIME), entry_orb_source_frames.size())
	for torch in root.puzzle_torches:
		if torch == null or not is_instance_valid(torch):
			continue
		var base_position: Vector2 = torch.get_meta("puzzle_torch_base_position", torch.global_position)
		torch.global_position = base_position + Vector2(0, bob)
		torch.z_index = int(round(torch.global_position.y * DEPTH_Z_SCALE)) + 1
		var palette := str(torch.get_meta("puzzle_torch_palette", "grey"))
		var frames := entry_orb_frames(root, palette)
		if frame_index < frames.size():
			torch.texture = frames[frame_index]
		var highlight := torch.get_node_or_null("TargetHighlight") as Sprite2D
		if highlight != null and highlight.visible:
			highlight.texture = (root.get("occlusion_renderer") as OcclusionRenderer).orb_highlighted_texture(torch.texture)
	if root.current_room_type == DungeonGraph.ROOM_ORB and not root.puzzle_torches.is_empty():
		_update_first_orb_tutorial_prompt(root, root.puzzle_torches[0])


func clear_puzzle_torches(root: Object) -> void:
	var current_target: Variant = root.get("current_target")
	if current_target != null and root.puzzle_torches.has(current_target):
		root.call("_set_current_target", null, false)
	for torch in root.puzzle_torches:
		if torch != null and is_instance_valid(torch):
			root.depth_sprites.erase(torch)
			torch.queue_free()
	root.puzzle_torches.clear()
	_clear_first_orb_tutorial_prompt(root)


func puzzle_torches_solved(root: Object, required_palette: String) -> bool:
	if root.puzzle_torches.size() < 2 or required_palette.is_empty():
		return false
	for torch in root.puzzle_torches:
		if str(torch.get_meta("puzzle_torch_palette", "grey")) != required_palette:
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


func activate_puzzle_torch(root: Object, torch: Sprite2D, world_position: Vector2, palette: String, apply_player_reaction: bool = true) -> void:
	if torch == null or not is_instance_valid(torch):
		return
	if root.current_room_type == DungeonGraph.ROOM_ORB:
		activate_orb_room_orb(root, torch, world_position, palette, apply_player_reaction)
		return
	torch.set_meta("puzzle_torch_palette", palette)
	torch.self_modulate = Color.WHITE
	var frames := entry_orb_frames(root, palette)
	if not frames.is_empty():
		torch.texture = frames[0]
	var state: Dictionary = root.room_controller.room_states.get(root.current_room_id, {}) as Dictionary
	var colors: Array = state.get("puzzle_torch_colors", [])
	var torch_index: int = root.puzzle_torches.find(torch)
	if torch_index >= 0:
		while colors.size() < root.puzzle_torches.size(): colors.append("grey")
		colors[torch_index] = palette
		state["puzzle_torch_colors"] = colors
		root.room_controller.room_states[root.current_room_id] = state
	root.call("_spawn_magic_impact", world_position, palette)
	if apply_player_reaction:
		_apply_entry_orb_player_reaction(root, world_position)
	refresh_puzzle_torch_puzzle_state(root)


func activate_orb_room_orb(root: Object, orb: Sprite2D, world_position: Vector2, palette: String, apply_player_reaction: bool = true) -> void:
	# The Orb Room is a single shared-state object, not a local two-orb puzzle.
	# The player's starter palette resolves to Puzzle Color A; grey energy
	# resolves to Puzzle Color B. The map controller then synchronizes both
	# Orb Rooms and the room/environment presentation.
	var requested_color: StringName = root.call("_orb_puzzle_color_for_palette", palette) as StringName
	var changed_map_color := not requested_color.is_empty() and bool(root.call("_change_orb_color_from_room", requested_color))
	if changed_map_color:
		# Changing the shared map state rebuilds this orb immediately. Feedback
		# must happen before returning so the successful hit is still readable.
		root.call("_spawn_magic_impact", world_position, palette)
		if apply_player_reaction:
			_apply_entry_orb_player_reaction(root, world_position)
		return
	_apply_orb_visual(root, orb, palette)
	var state: Dictionary = root.room_controller.room_states.get(root.current_room_id, {}) as Dictionary
	state["orb_display_palette"] = palette
	root.room_controller.room_states[root.current_room_id] = state
	root.call("_spawn_magic_impact", world_position, palette)
	if apply_player_reaction:
		_apply_entry_orb_player_reaction(root, world_position)


func _apply_entry_orb_player_reaction(root: Object, orb_position: Vector2) -> void:
	var rng := root.get("rng") as RandomNumberGenerator
	var pitch := rng.randf_range(0.94, 1.06) if rng != null else 1.0
	root.call("_play_sound", "orb_hit", -6.0, pitch)
	var player := root.get("player") as Sprite2D
	var motor := root.get("player_motor") as ActorMotor
	if player == null or motor == null:
		return
	var attack := root.get("player_attack_component") as PlayerAttackComponent
	if attack != null:
		attack.cancel_lunge()
	var direction: Vector2 = (root.call("_actor_foot", player) as Vector2) - orb_position
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if player.flip_h else Vector2.RIGHT
	motor.start_knockback(root.call("_perspective_movement", direction.normalized() * (ORB_KNOCKBACK_DISTANCE / ORB_KNOCKBACK_DURATION)), ORB_KNOCKBACK_DURATION)
	if bool(root.get("player_is_attacking")):
		root.set("orb_knockback_animation_lock", true)
		# Let the attack's current hit frame render once before the reaction
		# rewinds to attack frame 1 on the next animation tick.
		root.set("orb_knockback_animation_grace", true)
		root.set("orb_knockback_attack_cancelled", true)
		root.set("player_attack_hit_done", true)


func update_entry_orb_player_reaction(root: Object) -> void:
	if not bool(root.get("orb_knockback_animation_lock")):
		return
	var motor := root.get("player_motor") as ActorMotor
	if motor == null or motor.is_in_knockback():
		return
	root.set("orb_knockback_animation_lock", false)
	root.set("orb_knockback_animation_grace", false)
	root.set("player_is_attacking", false)
	root.set("player_between_timer", 0.0)
	root.set("player_just_finished_attack2", false)
	var attack := root.get("player_attack_component") as PlayerAttackComponent
	if attack != null:
		attack.cancel()
	root.set("player_attack_hit_done", false)
	(root.get("player_attack_visual") as Sprite2D).visible = false
	(root.get("player") as Sprite2D).visible = true
	root.set("player_anim_name", "walk" if bool(root.get("player_is_moving")) else "idle")
	root.set("player_anim_frame", 0)
	root.set("player_anim_timer", 0.0)
	(root.get("player_animation_component") as PlayerAnimationComponent).apply_frame(root)
	var equipment_visual := root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if equipment_visual != null:
		equipment_visual.interrupt_attack(root)


func refresh_room_socket_visuals(root: Object, is_unlocked: bool) -> void:
	var shut_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorRightenemyshut.png")
	var starter_flame_shut_texture: Texture2D = root.call("_load_texture_or_null", STARTER_FLAME_SHUT_TEXTURE_PATH)
	var orb_shut_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorRightOrbshut.png")
	var open_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorRight.png")
	var stairs_down_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorStairsRight.png")
	var stairs_up_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/DoorStairsUPRight.png")
	var entrance_walkway_texture: Texture2D = root.call("_load_texture_or_null", "res://assets/artwork/Tile.png")
	var starter_gate_locked := starter_flame_gate_locked(root)
	var is_boss_room: bool = root.current_room_type == DungeonGraph.ROOM_DOWNSTAIRS
	for socket_value in root.room_controller.active_door_sockets.values():
		var socket := socket_value as DungeonSocket
		var visual := socket.visual() as Sprite2D
		if visual == null: continue
		var connection: DungeonGraph.ConnectionRecord = root.dungeon_graph.get_connection(root.current_room_id, socket.socket_id())
		var destination_room: DungeonGraph.RoomRecord = root.dungeon_graph.get_room(connection.destination_room_id) if connection != null else null
		var leads_downstairs: bool = destination_room != null and destination_room.room_type == DungeonGraph.ROOM_DOWNSTAIRS
		var visual_state: StringName = root.call("_map_connection_visual_state", connection, false) as StringName
		var authored_open: bool = root.dungeon_map_controller != null and root.dungeon_map_controller.is_authored_run1()
		visual.visible = true
		var is_orb_locked := visual_state == &"orb_locked"
		var is_element_locked := visual_state == &"element_locked"
		var is_starter_gate: bool = starter_gate_locked and root.current_room_type == DungeonGraph.ROOM_START
		# The map controller is the source of truth for authored/generated runs.
		# Do not let the legacy room-wide flag keep an effectively open connection
		# looking shut (or vice versa), especially after a shared orb recolors the
		# active puzzle state.
		var connection_is_open := visual_state == &"open" and (root.dungeon_map_controller != null or is_unlocked or authored_open)
		visual.texture = starter_flame_shut_texture if is_starter_gate and starter_flame_shut_texture != null else stairs_up_texture if root.current_room_type == DungeonGraph.ROOM_DOWNSTAIRS else stairs_down_texture if leads_downstairs and connection_is_open else _color_locked_door_texture(root, orb_shut_texture, connection) if is_orb_locked or is_element_locked else open_texture if connection_is_open else shut_texture
		if is_orb_locked or is_element_locked or is_starter_gate:
			# The locked texture already contains the complete semantic color. Do
			# not multiply it by the room's global environment tint.
			visual.self_modulate = Color.WHITE
		visual.flip_h = socket.socket_id() == DungeonGraph.WALL_LEFT
	for socket_value in root.room_controller.active_entrance_sockets.values():
		var socket := socket_value as DungeonSocket
		var visual := socket.visual() as Sprite2D
		if visual == null: continue
		var connection: DungeonGraph.ConnectionRecord = root.dungeon_graph.get_connection_for_entry(root.current_room_id, socket.socket_id())
		var visual_state: StringName = root.call("_map_connection_visual_state", connection, true) as StringName
		visual.visible = true
		if is_boss_room:
			# Boss arrivals use the same lower-room entrance treatment as every other
			# room. The fight closes the route with a gray walkway, not a back-wall
			# DoorRight* asset; victory then restores the same walkway at full color.
			visual.texture = entrance_walkway_texture
			visual.self_modulate = _entrance_lock_modulate(root, connection, visual_state)
			var extra_tile := visual.get_node_or_null("Tile 2") as CanvasItem
			if extra_tile != null:
				extra_tile.visible = true
			continue
		# DoorRight* art is authored for the back wall. Entrance sockets instead
		# use the authored walkway tile; its existing orientation is preserved.
		if entrance_walkway_texture != null:
			visual.texture = entrance_walkway_texture
		var extra_tile := visual.get_node_or_null("Tile 2") as CanvasItem
		if extra_tile != null:
			extra_tile.visible = true
		visual.self_modulate = _entrance_lock_modulate(root, connection, visual_state)
	# Socket refreshes can happen after the map color changes (for example when
	# an orb rebuilds the room). Reapply the recursive surface tint last so both
	# authored entrance tiles agree instead of leaving one tile white.
	apply_puzzle_environment_tint(root, _environment_tint(root))


func _color_locked_door_texture(root: Object, base_texture: Texture2D, connection: DungeonGraph.ConnectionRecord) -> Texture2D:
	if base_texture == null or connection == null:
		return base_texture
	var palette_name := ""
	var requirement := connection.element_requirement if not connection.element_requirement.is_empty() else connection.color_requirement
	var map_controller := root.get("dungeon_map_controller") as Node
	if map_controller != null:
		palette_name = str(map_controller.call("palette_for_requirement", requirement))
	if palette_name.is_empty():
		palette_name = "blue" if requirement == &"puzzle_a" else "grey" if requirement == &"puzzle_b" else ""
	if palette_name.is_empty():
		return base_texture
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary
	return library.recolor_door_texture(base_texture, palette_name) if library != null else base_texture


func _entrance_lock_modulate(root: Object, connection: DungeonGraph.ConnectionRecord, visual_state: StringName) -> Color:
	var boss_entrance_closed: bool = root.current_room_type == DungeonGraph.ROOM_DOWNSTAIRS and not bool(root.get("entrance_open"))
	if visual_state == &"open" and not boss_entrance_closed:
		return Color.WHITE
	if boss_entrance_closed:
		return Color(0.5, 0.5, 0.5, 1.0)
	if visual_state != &"orb_locked" and visual_state != &"element_locked":
		return Color(0.5, 0.5, 0.5, 1.0)
	var palette_name := "grey"
	var requirement := connection.element_requirement if connection != null and not connection.element_requirement.is_empty() else connection.color_requirement if connection != null else &""
	var map_controller := root.get("dungeon_map_controller") as Node
	if map_controller != null and connection != null:
		palette_name = str(map_controller.call("palette_for_requirement", requirement))
	if palette_name.is_empty():
		palette_name = "blue" if requirement == &"puzzle_a" else "grey"
	return PaletteLibrary.normal(palette_name) * Color(0.5, 0.5, 0.5, 1.0)
