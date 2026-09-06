extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const MINIMAP_SCRIPT = preload("res://scripts/dungeon_minimap_controller.gd")
const VIEW_CENTER := Vector2i(11, 11)


func _initialize() -> void:
	var failures: Array[String] = []
	var graph = GRAPH_SCRIPT.new()
	var map_controller = MAP_CONTROLLER_SCRIPT.new()
	var minimap = MINIMAP_SCRIPT.new()
	root.add_child(map_controller)
	root.add_child(minimap)
	map_controller.begin_run(graph, 77, 0)
	minimap.configure(map_controller)
	map_controller.on_room_entered(graph.start_room_id)
	var marker := minimap.get_node_or_null("CurrentRoomMarker") as Sprite2D
	_expect(marker != null and marker.position.is_equal_approx(MINIMAP_SCRIPT.MAP_POSITION + Vector2(VIEW_CENTER) * MINIMAP_SCRIPT.DISPLAY_SCALE), "Run 1 marker stays centered on the Hub", failures)
	var image: Image = minimap.snapshot_image()
	var origin: Vector2i = Vector2i.ZERO
	_expect(image != null and image.get_size() == MINIMAP_SCRIPT.MINIMAP_VIEW_SIZE, "minimap uses the fixed 22x22 display window", failures)
	if image != null and image.get_size() == MINIMAP_SCRIPT.MINIMAP_VIEW_SIZE:
		origin = minimap.get("map_origin") as Vector2i
		_expect(image.get_pixelv(Vector2i(8, 21) - origin) == MINIMAP_SCRIPT.COLOR_HUB, "Hub pixel uses the reference white", failures)
		_expect(image.get_pixelv(Vector2i(7, 20) - origin) == MINIMAP_SCRIPT.COLOR_DOOR, "Hub-to-Orb entry remains an ordinary connector", failures)
		_expect(image.get_pixelv(Vector2i(6, 19) - origin) == MINIMAP_SCRIPT.COLOR_BACKGROUND, "undiscovered room remains hidden", failures)
	map_controller.on_room_entered(&"room_1_1")
	_expect(marker != null and marker.position.is_equal_approx(MINIMAP_SCRIPT.MAP_POSITION + Vector2(VIEW_CENTER) * MINIMAP_SCRIPT.DISPLAY_SCALE), "Run 1 marker stays centered on the occupied enemy room", failures)
	image = minimap.snapshot_image()
	origin = minimap.get("map_origin") as Vector2i
	_expect(image.get_pixelv(Vector2i(10, 19) - origin) == MINIMAP_SCRIPT.COLOR_ENEMY, "discovered enemy room uses mid grey", failures)
	map_controller.on_room_entered(&"room_-1_1")
	image = minimap.snapshot_image()
	origin = minimap.get("map_origin") as Vector2i
	_expect(image.get_pixelv(Vector2i(6, 19) - origin) == MINIMAP_SCRIPT.COLOR_ORB_MARKER, "first Orb Room uses the light-blue marker", failures)
	map_controller.on_room_entered(&"room_2_11")
	image = minimap.snapshot_image()
	origin = minimap.get("map_origin") as Vector2i
	_expect(image.get_pixelv(Vector2i(12, 5) - origin) == MINIMAP_SCRIPT.COLOR_ORB_MARKER, "second Orb Room uses the same light-blue marker", failures)
	minimap.queue_free()
	map_controller.queue_free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN1_MINIMAP_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
