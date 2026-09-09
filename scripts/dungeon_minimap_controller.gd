extends Node2D
class_name DungeonMinimapController

const REVIEW_EXPORTER_SCRIPT = preload("res://tools/export_dungeon_maps.gd")
const MAP_FRAME_SCENE = preload("res://scenes/menu_panel_8_piece.tscn")
const CURSOR_TEXTURE = preload("res://assets/artwork/cursor.png")
const PAUSE_LAYOUT = preload("res://scripts/pause_menu_layout.gd")
const HUB_FRAME_TEXTURE = preload("res://assets/artwork/frame 16x16.png")
## The full-map overlay anchors a fixed map screen on the left of the content
## area and a destination list beside it. The dark backdrop is sized to exactly
## enclose the rendered map so no orphaned box floats around it.
const MAP_OVERLAY_BACKDROP := Rect2(6.0, 24.0, 146.0, 110.0)
const MAP_OVERLAY_DIVIDER_X := 153.0
const MAP_OVERLAY_LIST_X := 161.0
const MAP_OVERLAY_LIST_TOP := 29.0
const MAP_OVERLAY_ROW_PITCH := 9.0
## move_menu_cursor raises the target by CURSOR_VERTICAL_RAISE (2 px); pass the
## desired cursor resting point offset upward so the cursor lands on the flame.
const MENU_CURSOR_RAISE_COMPENSATION := 2.0

## Presentation-only renderer for complete dungeon layouts.
##
## Orb Room pixels remain light-blue markers. Door pixels resolve their display
## color from the same gate requirement data used by runtime traversal, so
## puzzle, elemental, and mixed entrance-orb doors stay visually consistent.

const MAP_SIZE := Vector2i(16, 23)
const MINIMAP_VIEW_SIZE := Vector2i(25, 25)
const DISPLAY_SCALE := 2.0
const RING_DISPLAY_SCALE := 1.0
const MAP_POSITION := Vector2(0, 14)
const MAP_RING_PATH := "res://assets/artwork/puzzle_map_ring.png"

const COLOR_BACKGROUND := Color8(17, 19, 24)
const COLOR_HUB := Color8(244, 244, 244)
const COLOR_DOOR := Color8(51, 60, 87)
const COLOR_ENEMY := Color8(86, 108, 134)
const COLOR_SPECIAL := Color8(148, 176, 194)
const COLOR_TREASURE := Color8(255, 205, 117)
const COLOR_FIRE := Color8(239, 125, 87)
const COLOR_CLOAKED := Color8(93, 39, 93)
const COLOR_BOSS := Color8(177, 62, 83)
const COLOR_ORB_MARKER := Color8(115, 239, 247)
const COLOR_PUZZLE_A_DOOR := Color8(59, 93, 201)
const COLOR_PUZZLE_B_DOOR := Color8(56, 183, 100)
const COLOR_UNVISITED_FLAME := Color8(86, 92, 102)
const COLOR_MAP_OVERLAY := Color(0.035, 0.043, 0.060, 0.97)
const COLOR_MAP_TITLE := Color8(244, 244, 244)
const COLOR_MAP_SELECTED := Color8(255, 205, 117)
const COLOR_MAP_CURRENT := Color8(167, 240, 112)
const COLOR_MAP_UNVISITED := Color8(112, 118, 130)
const PLAYER_MARKER_BLINK_TIME := 0.24

signal flame_travel_requested(room_id: StringName)

var map_controller: Node = null
var gameplay_root: Object = null
var map_sprite: Sprite2D = null
var map_texture: ImageTexture = null
var map_image: Image = null
var map_origin: Vector2i = Vector2i.ZERO
var full_map_image: Image = null
var full_map_origin: Vector2i = Vector2i.ZERO
var player_marker: Sprite2D = null
var player_marker_texture: ImageTexture = null
var player_marker_timer := 0.0
var ring_sprite: Sprite2D = null
var ring_texture: ImageTexture = null
var ring_bounds := Rect2i()
var ring_mask := PackedByteArray()
var map_open := false
var selected_flame_index := 0
var _flame_room_ids: Array[StringName] = []
var map_overlay: Control = null
var map_overlay_frame: Control = null
var map_overlay_hub_panels: Array[NinePatchRect] = []
var map_overlay_background: ColorRect = null
var map_overlay_divider: ColorRect = null
var map_overlay_title: Sprite2D = null
var map_overlay_texture: TextureRect = null
var map_overlay_help: Sprite2D = null
var map_overlay_flame_labels: Array[Sprite2D] = []
var map_overlay_list_pointer: Sprite2D = null
var map_overlay_cursor: Sprite2D = null
var map_overlay_select_glyph: Sprite2D = null
var map_overlay_back_glyph: Sprite2D = null
var map_overlay_select_text: Sprite2D = null
var map_overlay_back_text: Sprite2D = null
var map_overlay_back_button: Button = null


func configure(new_map_controller: Node) -> void:
	map_controller = new_map_controller
	gameplay_root = map_controller.get_parent() if map_controller != null else null
	if map_controller == null:
		visible = false
		return
	if not map_controller.is_connected(&"map_state_changed", Callable(self, "_on_map_state_changed")):
		map_controller.connect(&"map_state_changed", Callable(self, "_on_map_state_changed"))
	if not map_controller.is_connected(&"room_discovered", Callable(self, "_on_room_discovered")):
		map_controller.connect(&"room_discovered", Callable(self, "_on_room_discovered"))
	visible = _has_complete_layout()
	if map_sprite == null:
		map_sprite = Sprite2D.new()
		map_sprite.name = "DungeonMinimap"
		map_sprite.centered = false
		map_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		map_sprite.position = MAP_POSITION
		map_sprite.scale = Vector2.ONE * DISPLAY_SCALE
		map_sprite.z_index = 20
		add_child(map_sprite)
	if player_marker == null:
		var marker_image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		marker_image.set_pixel(0, 0, Color.WHITE)
		player_marker_texture = ImageTexture.create_from_image(marker_image)
		player_marker = Sprite2D.new()
		player_marker.name = "CurrentRoomMarker"
		player_marker.centered = false
		player_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		player_marker.texture = player_marker_texture
		player_marker.scale = Vector2.ONE * DISPLAY_SCALE
		player_marker.z_index = 21
		add_child(player_marker)
	_ensure_ring()
	set_process(true)
	_rebuild()


func _on_map_state_changed() -> void:
	_rebuild()
	_refresh_map_overlay(gameplay_root)


func _on_room_discovered(_room_id: StringName) -> void:
	_rebuild()
	_refresh_map_overlay(gameplay_root)


func _process(delta: float) -> void:
	if player_marker == null:
		return
	player_marker_timer = fmod(player_marker_timer + maxf(delta, 0.0), PLAYER_MARKER_BLINK_TIME * 2.0)
	player_marker.visible = not map_open and player_marker_timer < PLAYER_MARKER_BLINK_TIME
	_update_player_marker()


func can_open_map(root: Object) -> bool:
	if map_controller == null or not _has_complete_layout():
		return false
	var state := map_controller.get("state") as DungeonMapState
	if state == null or state.current_room_id.is_empty():
		return false
	if root == null:
		return true
	if bool(root.get("boot_active")) or bool(root.get("loading_screen_active")) or bool(root.get("scene_transition_active")) or bool(root.get("room_transition_locked")) or bool(root.get("player_dead")) or bool(root.get("player_death_pending")):
		return false
	var screen := root.get("screen_state_controller") as Node
	if screen != null:
		for overlay_name in [&"title_overlay", &"save_select_overlay", &"settings_overlay", &"name_entry_overlay", &"archetype_overlay", &"pause_overlay", &"hub_overlay", &"run_complete_overlay"]:
			var overlay := screen.get(overlay_name) as CanvasItem
			if overlay != null and overlay.visible:
				return false
	return true


func open_map(root: Object) -> bool:
	if map_open:
		return true
	if not can_open_map(root):
		return false
	gameplay_root = root
	_flame_room_ids = teleport_destination_room_ids()
	if _flame_room_ids.is_empty():
		return false
	var current_room_id: StringName = (map_controller.get("state") as DungeonMapState).current_room_id
	selected_flame_index = _flame_room_ids.find(current_room_id)
	if selected_flame_index < 0:
		selected_flame_index = _first_visited_flame_index()
		if selected_flame_index < 0:
			selected_flame_index = 0
	map_open = true
	_ensure_map_overlay()
	_set_small_map_visible(false)
	_refresh_map_overlay(root)
	return true


func close_map() -> void:
	if not map_open:
		return
	map_open = false
	if map_overlay != null:
		map_overlay.visible = false
	_set_small_map_visible(true)


func is_map_open() -> bool:
	return map_open


func handle_input(root: Object) -> void:
	if not map_open or root == null:
		return
	var input_router := root.get("input_router") as InputRouter
	if (input_router != null and input_router.just_pressed(&"open_minimap")) or bool(root.call("_is_menu_back_just_pressed")):
		close_map()
		return
	var direction := 0
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
		direction = -1
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
		direction = 1
	if direction != 0 and not _flame_room_ids.is_empty():
		selected_flame_index = posmod(selected_flame_index + direction, _flame_room_ids.size())
		_refresh_map_overlay(root, true)
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
		return
	if bool(root.call("_is_menu_confirm_just_pressed")) and not _flame_room_ids.is_empty():
		var target_room_id := _flame_room_ids[clampi(selected_flame_index, 0, _flame_room_ids.size() - 1)]
		if can_fast_travel_to_flame(root, target_room_id):
			flame_travel_requested.emit(target_room_id)
		else:
			root.call("_play_sound", "ui_no_input", 0.0, 1.0)


func refresh_layout() -> void:
	_refresh_map_overlay(gameplay_root)


func flame_room_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if map_controller == null:
		return result
	return map_controller.call("flame_room_ids") as Array[StringName] if map_controller.has_method("flame_room_ids") else result


func teleport_destination_room_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	if map_controller == null:
		return result
	return map_controller.call("teleport_destination_room_ids") as Array[StringName] if map_controller.has_method("teleport_destination_room_ids") else flame_room_ids()


func is_flame_visited(room_id: StringName) -> bool:
	if map_controller == null:
		return false
	return bool(map_controller.call("is_flame_visited", room_id)) if map_controller.has_method("is_flame_visited") else false


func can_fast_travel_to_flame(root: Object, target_room_id: StringName) -> bool:
	if map_controller == null or root == null:
		return false
	var state := map_controller.get("state") as DungeonMapState
	if state == null:
		return false
	return bool(map_controller.call("can_fast_travel_to_flame", state.current_room_id, target_room_id)) if map_controller.has_method("can_fast_travel_to_flame") else false


func _first_visited_flame_index() -> int:
	for index in _flame_room_ids.size():
		if is_flame_visited(_flame_room_ids[index]):
			return index
	return -1


func _ensure_map_overlay() -> void:
	if map_overlay != null:
		return
	map_overlay = Control.new()
	map_overlay.name = "DungeonMapOverlay"
	map_overlay.position = Vector2.ZERO
	map_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.z_index = 80
	add_child(map_overlay)
	map_overlay_frame = MAP_FRAME_SCENE.instantiate() as Control
	map_overlay_frame.name = "PauseStyleFrame"
	map_overlay_frame.visible = false
	map_overlay_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.add_child(map_overlay_frame)
	map_overlay_hub_panels.append(_add_hub_panel("HubTitlePanel"))
	map_overlay_hub_panels.append(_add_hub_panel("HubContentPanel"))
	map_overlay_hub_panels.append(_add_hub_panel("HubFooterPanel"))
	map_overlay_hub_panels.append(_add_hub_panel("HubResourcePanel"))
	map_overlay_background = ColorRect.new()
	map_overlay_background.name = "Background"
	map_overlay_background.color = COLOR_MAP_OVERLAY
	map_overlay_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.add_child(map_overlay_background)
	map_overlay_divider = ColorRect.new()
	map_overlay_divider.name = "DestinationDivider"
	map_overlay_divider.color = Color(0.36, 0.4, 0.52, 0.85)
	map_overlay_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.add_child(map_overlay_divider)
	map_overlay_title = Sprite2D.new()
	map_overlay_title.name = "Title"
	map_overlay_title.centered = false
	map_overlay.add_child(map_overlay_title)
	map_overlay_cursor = Sprite2D.new()
	map_overlay_cursor.name = "DestinationCursor"
	map_overlay_cursor.texture = CURSOR_TEXTURE
	map_overlay_cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_overlay_cursor.centered = false
	map_overlay_cursor.scale = Vector2(1.0, 1.0)
	map_overlay_cursor.z_index = 4095
	map_overlay_cursor.show_behind_parent = false
	map_overlay.add_child(map_overlay_cursor)
	map_overlay_texture = TextureRect.new()
	map_overlay_texture.name = "FullMap"
	map_overlay_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_overlay_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_overlay_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_overlay_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.add_child(map_overlay_texture)
	map_overlay_help = Sprite2D.new()
	map_overlay_help.name = "Help"
	map_overlay_help.centered = false
	map_overlay.add_child(map_overlay_help)
	map_overlay_select_glyph = _add_overlay_sprite("SelectGlyph", load("res://assets/artwork/circle55.png") as Texture2D)
	map_overlay_back_glyph = _add_overlay_sprite("BackGlyph", load("res://assets/artwork/x55.png") as Texture2D)
	map_overlay_select_text = _add_overlay_sprite("SelectText")
	map_overlay_back_text = _add_overlay_sprite("BackText")
	map_overlay_back_button = Button.new()
	map_overlay_back_button.name = "BackTouchTarget"
	map_overlay_back_button.focus_mode = Control.FOCUS_NONE
	map_overlay_back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent_style := StyleBoxFlat.new()
	transparent_style.bg_color = Color.TRANSPARENT
	transparent_style.set_border_width_all(0)
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		map_overlay_back_button.add_theme_stylebox_override(state_name, transparent_style)
	map_overlay_back_button.pressed.connect(close_map)
	map_overlay.add_child(map_overlay_back_button)
	for index in 12:
		var label := Sprite2D.new()
		label.name = "Flame%d" % index
		label.centered = false
		map_overlay.add_child(label)
		map_overlay_flame_labels.append(label)
	map_overlay_list_pointer = Sprite2D.new()
	map_overlay_list_pointer.name = "ListPointer"
	map_overlay_list_pointer.centered = false
	map_overlay.add_child(map_overlay_list_pointer)
	map_overlay.visible = false


func _refresh_map_overlay(root: Object, animate_cursor: bool = false) -> void:
	if not map_open:
		return
	_ensure_map_overlay()
	var view_size := _map_view_size(root)
	map_overlay.position = Vector2.ZERO
	map_overlay.size = view_size
	map_overlay_frame.size = view_size
	var resource_left := maxf(view_size.x - 63.0, 177.0)
	map_overlay_hub_panels[0].position = Vector2.ZERO
	map_overlay_hub_panels[0].size = Vector2(maxf(resource_left - 1.0, 1.0), 21.0)
	map_overlay_hub_panels[1].position = Vector2.ZERO
	map_overlay_hub_panels[1].size = Vector2(maxf(view_size.x, 1.0), 136.0)
	map_overlay_hub_panels[2].position = Vector2(0.0, 136.0)
	map_overlay_hub_panels[2].size = Vector2(maxf(resource_left - 2.0, 1.0), 24.0)
	map_overlay_hub_panels[3].position = Vector2(resource_left, 136.0)
	map_overlay_hub_panels[3].size = Vector2(maxf(view_size.x - resource_left, 1.0), 24.0)
	map_overlay_background.position = MAP_OVERLAY_BACKDROP.position
	map_overlay_background.size = MAP_OVERLAY_BACKDROP.size
	map_overlay_divider.position = Vector2(MAP_OVERLAY_DIVIDER_X, 23.0)
	map_overlay_divider.size = Vector2(1.0, 112.0)
	map_overlay_title.position = Vector2(13.0, 4.0)
	map_overlay_help.position = Vector2(view_size.x - 57.0, view_size.y - 18.0)
	_set_pixel_text(map_overlay_title, "MAP", COLOR_MAP_TITLE, root)
	map_overlay_help.visible = false
	map_overlay_select_glyph.position = Vector2(107.0, view_size.y - 14.0)
	map_overlay_back_glyph.position = Vector2(146.0, view_size.y - 14.0)
	map_overlay_select_text.position = Vector2(114.0, view_size.y - 14.0)
	map_overlay_back_text.position = Vector2(153.0, view_size.y - 14.0)
	map_overlay_back_button.position = PAUSE_LAYOUT.back_button_position(view_size)
	map_overlay_back_button.size = PAUSE_LAYOUT.BACK_BUTTON_SIZE
	map_overlay_select_glyph.visible = true
	map_overlay_back_glyph.visible = true
	map_overlay_back_text.visible = true
	_set_pixel_text(map_overlay_select_text, "SELECT", Color.WHITE, root)
	_set_pixel_text(map_overlay_back_text, "BACK", Color.WHITE, root)
	map_overlay_texture.position = MAP_OVERLAY_BACKDROP.position
	map_overlay_texture.size = MAP_OVERLAY_BACKDROP.size
	map_overlay_texture.texture = ImageTexture.create_from_image(full_map_image) if full_map_image != null else null
	if map_overlay_cursor != null:
		map_overlay_cursor.visible = false
	if map_overlay_list_pointer != null:
		map_overlay_list_pointer.visible = false
	for index in map_overlay_flame_labels.size():
		var label := map_overlay_flame_labels[index]
		if index >= _flame_room_ids.size():
			label.visible = false
			continue
		var room_id := _flame_room_ids[index]
		var room := (map_controller.get("graph") as DungeonGraph).get_room(room_id) if map_controller != null and map_controller.get("graph") != null else null
		var graph := map_controller.get("graph") as DungeonGraph
		var is_hub := graph != null and room_id == graph.start_room_id
		var flame_name := "HUB" if is_hub else String(room.fire_flame).to_upper() if room != null else "FLAME"
		var status := "HUB" if is_hub else "VISITED" if is_flame_visited(room_id) else "UNVISITED"
		if room_id == (map_controller.get("state") as DungeonMapState).current_room_id:
			status = "CURRENT"
		# The selected destination is always highlighted, even when it is not yet
		# eligible for travel, so the player can always tell which row is active.
		_set_pixel_text(label, flame_name, COLOR_MAP_CURRENT if status == "CURRENT" else COLOR_MAP_SELECTED if index == selected_flame_index else COLOR_MAP_UNVISITED if not is_hub and not is_flame_visited(room_id) else COLOR_MAP_TITLE, root)
		label.position = Vector2(MAP_OVERLAY_LIST_X, MAP_OVERLAY_LIST_TOP + index * MAP_OVERLAY_ROW_PITCH)
		label.visible = true
		if map_overlay_list_pointer != null:
			map_overlay_list_pointer.visible = index == selected_flame_index
			if index == selected_flame_index:
				_set_pixel_text(map_overlay_list_pointer, ">", COLOR_MAP_SELECTED, root)
				map_overlay_list_pointer.position = label.position + Vector2(-7.0, 3.0)
		if index == selected_flame_index and map_overlay_cursor != null:
			map_overlay_cursor.visible = true
			var screen := root.get("screen_state_controller") as Node if root != null else null
			# The finger sits over the selected destination's own map pixel, so the
			# map, list, and cursor all agree on the current target.
			var desired_position := _flame_overlay_position(room_id) - Vector2(8.0, 8.0)
			if screen != null and screen.has_method("move_menu_cursor"):
				screen.call("move_menu_cursor", map_overlay_cursor, desired_position + Vector2(0.0, MENU_CURSOR_RAISE_COMPENSATION), animate_cursor)
			else:
				map_overlay_cursor.position = desired_position
	if map_overlay_cursor != null and (selected_flame_index < 0 or selected_flame_index >= _flame_room_ids.size()):
		map_overlay_cursor.visible = false
	map_overlay.visible = true


func _flame_overlay_position(room_id: StringName) -> Vector2:
	## Map a destination room's logical minimap pixel to overlay-local screen
	## coordinates using the same aspect-fit used by the full-map TextureRect.
	if full_map_image == null or map_controller == null:
		return Vector2.ZERO
	var graph := map_controller.get("graph") as DungeonGraph
	var room := graph.get_room(room_id) if graph != null else null
	if room == null:
		return Vector2.ZERO
	var image_size := Vector2(full_map_image.get_width(), full_map_image.get_height())
	var scale := minf(MAP_OVERLAY_BACKDROP.size.x / image_size.x, MAP_OVERLAY_BACKDROP.size.y / image_size.y)
	var scaled := image_size * scale
	var offset := (MAP_OVERLAY_BACKDROP.size - scaled) * 0.5
	return MAP_OVERLAY_BACKDROP.position + offset + Vector2(room.minimap_coordinate - full_map_origin) * scale


func _set_pixel_text(sprite: Sprite2D, value: String, color: Color, root: Object) -> void:
	if sprite == null:
		return
	sprite.texture = root.call("_pixel_text_texture", value, color) as Texture2D if root != null and root.has_method("_pixel_text_texture") else null
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _add_overlay_sprite(sprite_name: String, texture: Texture2D = null) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.centered = false
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	map_overlay.add_child(sprite)
	return sprite


func _add_hub_panel(panel_name: String) -> NinePatchRect:
	var panel := NinePatchRect.new()
	panel.name = panel_name
	panel.texture = HUB_FRAME_TEXTURE
	panel.patch_margin_left = 3
	panel.patch_margin_top = 3
	panel.patch_margin_right = 3
	panel.patch_margin_bottom = 3
	panel.axis_stretch_horizontal = 1
	panel.axis_stretch_vertical = 1
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.add_child(panel)
	return panel


func _map_view_size(root: Object) -> Vector2:
	if root != null:
		var display := root.get("display_controller") as Node
		if display != null and display.has_method("view_size_value"):
			return Vector2(display.call("view_size_value"))
	return Vector2(240.0, 160.0)


func _set_small_map_visible(value: bool) -> void:
	if map_sprite != null:
		map_sprite.visible = value and not map_open
	if player_marker != null:
		player_marker.visible = value and not map_open
	if ring_sprite != null:
		ring_sprite.visible = value and not map_open


func _rebuild() -> void:
	if not _has_complete_layout():
		visible = false
		return
	var layout = map_controller.get("layout")
	if layout == null:
		visible = false
		return
	var geometry := _map_image_geometry(layout)
	var rendered_origin: Vector2i = geometry["origin"] as Vector2i
	var image_size := geometry["size"] as Vector2i
	visible = true
	map_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	map_image.fill(COLOR_BACKGROUND)
	full_map_origin = rendered_origin
	map_origin = rendered_origin
	var graph := map_controller.get("graph") as DungeonGraph
	for connection in layout.connections:
		var runtime_connection := graph.get_connection(connection.source_room_id, connection.exit_socket) if graph != null else null
		if runtime_connection == null or not bool(map_controller.call("is_connection_revealed", runtime_connection)):
			continue
		_draw_connection(connection)
	for room in layout.rooms:
		if bool(map_controller.call("is_room_discovered", room.id)):
			_draw_room(room)
	for decorative_door in layout.decorative_door_pixels:
		var source_room_id: StringName = decorative_door.get("source_room_id", &"")
		if source_room_id.is_empty() or bool(map_controller.call("is_room_discovered", source_room_id)):
			var door_color := _door_color(StringName(decorative_door.get("color_requirement", &"")))
			_set_map_pixel(decorative_door.get("coordinate", Vector2i.ZERO), door_color)
	full_map_image = map_image
	var viewport_origin: Vector2i = _viewport_origin(layout, rendered_origin, image_size)
	map_image = _crop_to_viewport(full_map_image, viewport_origin)
	map_origin = rendered_origin + viewport_origin
	map_texture = ImageTexture.create_from_image(map_image)
	map_sprite.texture = map_texture
	_update_player_marker()


func _viewport_origin(layout, rendered_origin: Vector2i, image_size: Vector2i) -> Vector2i:
	var focus_coordinate := Vector2i(floori(float(image_size.x) / 2.0), floori(float(image_size.y) / 2.0))
	var state := map_controller.get("state") as DungeonMapState
	var current_room_id: StringName = state.current_room_id if state != null else &""
	if not current_room_id.is_empty():
		var current_room = layout.room_by_id(current_room_id)
		if current_room != null:
			focus_coordinate = current_room.minimap_coordinate - rendered_origin
	return focus_coordinate - Vector2i(floori(float(MINIMAP_VIEW_SIZE.x) / 2.0), floori(float(MINIMAP_VIEW_SIZE.y) / 2.0))


func _crop_to_viewport(source_image: Image, viewport_origin: Vector2i) -> Image:
	var viewport := Image.create(MINIMAP_VIEW_SIZE.x, MINIMAP_VIEW_SIZE.y, false, Image.FORMAT_RGBA8)
	viewport.fill(COLOR_BACKGROUND)
	var source_bounds := Rect2i(Vector2i.ZERO, source_image.get_size())
	for y in range(MINIMAP_VIEW_SIZE.y):
		for x in range(MINIMAP_VIEW_SIZE.x):
			var source_coordinate := viewport_origin + Vector2i(x, y)
			if source_bounds.has_point(source_coordinate):
				viewport.set_pixelv(Vector2i(x, y), source_image.get_pixelv(source_coordinate))
	_apply_ring_mask(viewport)
	return viewport


func _ensure_ring() -> void:
	if ring_sprite != null:
		return
	var ring_source := load(MAP_RING_PATH) as Texture2D
	var ring_image := ring_source.get_image() if ring_source != null else null
	if ring_image == null:
		push_error("Dungeon minimap could not load %s." % MAP_RING_PATH)
		return
	ring_bounds = _opaque_bounds(ring_image)
	var map_pixel_size := MINIMAP_VIEW_SIZE * int(DISPLAY_SCALE)
	if ring_bounds.size.x > map_pixel_size.x or ring_bounds.size.y > map_pixel_size.y:
		push_error("Dungeon minimap ring must fit inside %s map pixels, got %s." % [map_pixel_size, ring_bounds.size])
		return
	var ring_offset := Vector2i(floori(float(map_pixel_size.x - ring_bounds.size.x) / 2.0), floori(float(map_pixel_size.y - ring_bounds.size.y) / 2.0))
	ring_mask = _build_ring_mask(ring_image, ring_bounds, int(DISPLAY_SCALE), ring_offset)
	ring_texture = ImageTexture.create_from_image(ring_image)
	ring_sprite = Sprite2D.new()
	ring_sprite.name = "DungeonMinimapRing"
	ring_sprite.centered = false
	ring_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ring_sprite.texture = ring_texture
	var ring_screen_offset := Vector2(map_pixel_size - ring_bounds.size) * 0.5
	ring_sprite.position = MAP_POSITION + ring_screen_offset - Vector2(ring_bounds.position) * RING_DISPLAY_SCALE
	ring_sprite.scale = Vector2.ONE * RING_DISPLAY_SCALE
	ring_sprite.z_index = 22
	add_child(ring_sprite)


func _opaque_bounds(image: Image) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			minimum = minimum.min(Vector2i(x, y))
			maximum = maximum.max(Vector2i(x, y))
	return Rect2i() if maximum.x < 0 else Rect2i(minimum, maximum - minimum + Vector2i.ONE)


func _build_ring_mask(image: Image, bounds: Rect2i, source_scale: int, ring_offset: Vector2i) -> PackedByteArray:
	var exterior := PackedByteArray()
	exterior.resize(bounds.size.x * bounds.size.y)
	var pending: Array[Vector2i] = []
	for y in bounds.size.y:
		for x in bounds.size.x:
			if x != 0 and y != 0 and x != bounds.size.x - 1 and y != bounds.size.y - 1:
				continue
			var coordinate := Vector2i(x, y)
			if image.get_pixelv(bounds.position + coordinate).a <= 0.0:
				pending.append(coordinate)
	while not pending.is_empty():
		var coordinate: Vector2i = pending.pop_back()
		var index := coordinate.y * bounds.size.x + coordinate.x
		if exterior[index] != 0 or image.get_pixelv(bounds.position + coordinate).a > 0.0:
			continue
		exterior[index] = 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = coordinate + offset
			if neighbor.x >= 0 and neighbor.y >= 0 and neighbor.x < bounds.size.x and neighbor.y < bounds.size.y:
				pending.append(neighbor)
	var mask := PackedByteArray()
	mask.resize(MINIMAP_VIEW_SIZE.x * MINIMAP_VIEW_SIZE.y)
	for y in MINIMAP_VIEW_SIZE.y:
		for x in MINIMAP_VIEW_SIZE.x:
			var sample := Vector2i(x * source_scale + floori(float(source_scale) / 2.0) - ring_offset.x, y * source_scale + floori(float(source_scale) / 2.0) - ring_offset.y)
			var inside := sample.x >= 0 and sample.y >= 0 and sample.x < bounds.size.x and sample.y < bounds.size.y and exterior[sample.y * bounds.size.x + sample.x] == 0
			mask[y * MINIMAP_VIEW_SIZE.x + x] = 1 if inside else 0
	return mask


func _apply_ring_mask(image: Image) -> void:
	if image == null or ring_mask.size() != image.get_width() * image.get_height():
		return
	for y in image.get_height():
		for x in image.get_width():
			if ring_mask[y * image.get_width() + x] == 0:
				image.set_pixel(x, y, Color.TRANSPARENT)


func _update_player_marker() -> void:
	if player_marker == null or map_controller == null or layout_is_empty() or map_open:
		if player_marker != null:
			player_marker.visible = false
		return
	var state := map_controller.get("state") as DungeonMapState
	var current_room_id: StringName = state.current_room_id if state != null else &""
	var room = map_controller.get("layout").room_by_id(current_room_id) if not current_room_id.is_empty() else null
	if room == null or map_image == null:
		player_marker.visible = false
		return
	var marker_coordinate: Vector2i = room.minimap_coordinate - map_origin
	player_marker.position = MAP_POSITION + Vector2(marker_coordinate) * DISPLAY_SCALE
	# Rebuilds should not cause a visible marker to remain on the prior room.
	player_marker.visible = player_marker_timer < PLAYER_MARKER_BLINK_TIME


func layout_is_empty() -> bool:
	var current_layout = map_controller.get("layout") if map_controller != null else null
	return current_layout == null or current_layout.rooms.is_empty()


func _draw_connection(connection) -> void:
	var color := COLOR_DOOR
	if map_controller != null:
		var requirement: StringName = map_controller.call("connection_display_requirement", connection) as StringName
		if not requirement.is_empty():
			color = _door_color(requirement)
	_set_map_pixel(connection.minimap_coordinate, color)


func _draw_room(room) -> void:
	var color := _room_color(room.room_type)
	if not room.fire_flame.is_empty() and not is_flame_visited(room.id):
		color = COLOR_UNVISITED_FLAME
	if room.room_type == DungeonGraph.ROOM_ORB:
		color = COLOR_ORB_MARKER
	_set_map_pixel(room.minimap_coordinate, color)


func _has_complete_layout() -> bool:
	if map_controller == null:
		return false
	if map_controller.has_method("has_complete_layout"):
		return bool(map_controller.call("has_complete_layout"))
	return bool(map_controller.call("is_authored_run1")) if map_controller.has_method("is_authored_run1") else false


func _map_image_geometry(layout) -> Dictionary:
	if map_controller != null and map_controller.has_method("is_authored_layout") and bool(map_controller.call("is_authored_layout")):
		return {"origin": Vector2i.ZERO, "size": layout.map_size if layout != null else MAP_SIZE}
	var has_coordinate := false
	var minimum := Vector2i.ZERO
	var maximum := Vector2i.ZERO
	for room in layout.rooms:
		var coordinate: Vector2i = room.minimap_coordinate
		if not has_coordinate:
			minimum = coordinate
			maximum = coordinate
			has_coordinate = true
		else:
			minimum = minimum.min(coordinate)
			maximum = maximum.max(coordinate)
	for connection in layout.connections:
		var coordinate: Vector2i = connection.minimap_coordinate
		if not has_coordinate:
			minimum = coordinate
			maximum = coordinate
			has_coordinate = true
		else:
			minimum = minimum.min(coordinate)
			maximum = maximum.max(coordinate)
	for decorative_door in layout.decorative_door_pixels:
		var coordinate: Vector2i = decorative_door.get("coordinate", Vector2i.ZERO)
		if not has_coordinate:
			minimum = coordinate
			maximum = coordinate
			has_coordinate = true
		else:
			minimum = minimum.min(coordinate)
			maximum = maximum.max(coordinate)
	var padding := Vector2i.ONE
	return {
		"origin": minimum - padding,
		"size": maximum - minimum + Vector2i.ONE + padding * 2,
	}


func _set_map_pixel(logical_coordinate: Vector2i, color: Color) -> void:
	if map_image == null:
		return
	var coordinate := logical_coordinate - map_origin
	var bounds := Rect2i(Vector2i.ZERO, map_image.get_size())
	if bounds.has_point(coordinate):
		map_image.set_pixelv(coordinate, color)


func _room_color(room_type: StringName) -> Color:
	if room_type == DungeonGraph.ROOM_START:
		return COLOR_HUB
	if room_type == DungeonGraph.ROOM_SPECIAL_ENEMY:
		return COLOR_SPECIAL
	if room_type == DungeonGraph.ROOM_TREASURE:
		return COLOR_TREASURE
	if room_type == DungeonGraph.ROOM_FIRE or room_type == DungeonGraph.ROOM_REST:
		return COLOR_FIRE
	if room_type == DungeonGraph.ROOM_CLOAKED or room_type == DungeonGraph.ROOM_NPC:
		return COLOR_CLOAKED
	if room_type == DungeonGraph.ROOM_BOSS or room_type == DungeonGraph.ROOM_DOWNSTAIRS:
		return COLOR_BOSS
	return COLOR_ENEMY


func _door_color(requirement: StringName) -> Color:
	if map_controller != null:
		var resolved: Variant = map_controller.call("door_display_color", requirement)
		if resolved is Color:
			return resolved as Color
	if requirement == &"puzzle_a":
		return COLOR_PUZZLE_A_DOOR
	if requirement == &"puzzle_b":
		return COLOR_PUZZLE_B_DOOR
	return COLOR_DOOR


func snapshot_image() -> Image:
	return map_image


func snapshot_full_image() -> Image:
	return full_map_image


func export_review_maps(output_directory: String = "res://screenshots/dungeon_maps") -> Dictionary:
	## Write complete authored and generated topology diagrams for design review.
	## This is deliberately separate from the discovered-room minimap display.
	var exporter = REVIEW_EXPORTER_SCRIPT.new()
	return exporter.export_all(output_directory)
