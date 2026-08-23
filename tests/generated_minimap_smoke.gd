extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const MINIMAP_SCRIPT = preload("res://scripts/dungeon_minimap_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var graph = GRAPH_SCRIPT.new()
	var map = MAP_CONTROLLER_SCRIPT.new()
	var minimap = MINIMAP_SCRIPT.new()
	root.add_child(map)
	root.add_child(minimap)
	map.begin_run(graph, 864209, 2, &"fire")
	minimap.configure(map)
	var layout = map.get("layout")
	for room in layout.rooms:
		map.on_room_entered(room.id)
	var image := minimap.snapshot_image()
	_expect(minimap.visible, "generated run exposes a minimap", failures)
	_expect(image != null and image.get_height() > MINIMAP_SCRIPT.MAP_SIZE.y, "generated Run 3 minimap expands beyond the authored Run 2 canvas", failures)
	if image != null:
		var start = layout.room_by_id(graph.start_room_id)
		var boss = null
		for room in layout.rooms:
			if room.room_type == DungeonGraph.ROOM_BOSS:
				boss = room
				break
		var origin: Vector2i = minimap.get("map_origin") as Vector2i
		var start_pixel: Vector2i = start.minimap_coordinate - origin
		_expect(image.get_pixelv(start_pixel) == MINIMAP_SCRIPT.COLOR_HUB, "generated minimap renders the start room at its translated logical coordinate", failures)
		_expect(boss != null and start.minimap_coordinate.y > boss.minimap_coordinate.y, "generated minimap presents the Hub below the boss", failures)
		_expect(_image_contains(image, MINIMAP_SCRIPT.COLOR_ORB_MARKER), "generated minimap keeps the shared Orb Room marker language", failures)
	var marker := minimap.get_node_or_null("CurrentRoomMarker") as Sprite2D
	_expect(marker != null and marker.scale.is_equal_approx(Vector2(2.0, 2.0)), "generated minimap installs a pixel-scaled player marker", failures)
	if marker != null:
		var map_state := map.get("state") as DungeonMapState
		var current_room = layout.room_by_id(map_state.current_room_id) if map_state != null else null
		var origin: Vector2i = minimap.get("map_origin") as Vector2i
		_expect(current_room != null and marker.position.is_equal_approx(MINIMAP_SCRIPT.MAP_POSITION + Vector2(current_room.minimap_coordinate - origin) * MINIMAP_SCRIPT.DISPLAY_SCALE), "generated minimap marker tracks the occupied room", failures)
	minimap.queue_free()
	map.queue_free()
	_finish(failures)


func _image_contains(image: Image, expected: Color) -> bool:
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y) == expected:
				return true
	return false


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GENERATED_MINIMAP_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
