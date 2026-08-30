extends Node2D
class_name DungeonMinimapController

## Presentation-only renderer for complete dungeon layouts.
##
## Orb Room pixels remain light-blue markers. Door pixels resolve their display
## color from the same gate requirement data used by runtime traversal, so
## puzzle, elemental, and mixed entrance-orb doors stay visually consistent.

const MAP_SIZE := Vector2i(16, 23)
const DISPLAY_SCALE := 2.0
const MAP_POSITION := Vector2(8, 24)

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
const PLAYER_MARKER_BLINK_TIME := 0.24

var map_controller: Node = null
var map_sprite: Sprite2D = null
var map_texture: ImageTexture = null
var map_image: Image = null
var map_origin := Vector2i.ZERO
var player_marker: Sprite2D = null
var player_marker_texture: ImageTexture = null
var player_marker_timer := 0.0


func configure(new_map_controller: Node) -> void:
	map_controller = new_map_controller
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
	set_process(true)
	_rebuild()


func _on_map_state_changed() -> void:
	_rebuild()


func _on_room_discovered(_room_id: StringName) -> void:
	_rebuild()


func _process(delta: float) -> void:
	if player_marker == null:
		return
	player_marker_timer = fmod(player_marker_timer + maxf(delta, 0.0), PLAYER_MARKER_BLINK_TIME * 2.0)
	player_marker.visible = player_marker_timer < PLAYER_MARKER_BLINK_TIME
	_update_player_marker()


func _rebuild() -> void:
	if not _has_complete_layout():
		visible = false
		return
	var layout = map_controller.get("layout")
	if layout == null:
		visible = false
		return
	var geometry := _map_image_geometry(layout)
	map_origin = geometry["origin"] as Vector2i
	var image_size := geometry["size"] as Vector2i
	visible = true
	map_image = Image.create(image_size.x, image_size.y, false, Image.FORMAT_RGBA8)
	map_image.fill(COLOR_BACKGROUND)
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
	map_texture = ImageTexture.create_from_image(map_image)
	map_sprite.texture = map_texture
	_update_player_marker()


func _update_player_marker() -> void:
	if player_marker == null or map_controller == null or layout_is_empty():
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
		return {"origin": Vector2i.ZERO, "size": MAP_SIZE}
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
