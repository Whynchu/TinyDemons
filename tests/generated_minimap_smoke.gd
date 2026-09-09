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
	map.begin_run(graph, 864209, 6, &"fire")
	minimap.configure(map)
	var layout = map.get("layout")
	var flame_room = null
	for candidate in layout.rooms:
		if not candidate.fire_flame.is_empty():
			flame_room = candidate
			break
	if flame_room != null:
		var flame_origin: Vector2i = minimap.get("full_map_origin") as Vector2i
		var unvisited_image: Image = minimap.snapshot_full_image()
		_expect(unvisited_image.get_pixelv(flame_room.minimap_coordinate - flame_origin) == MINIMAP_SCRIPT.COLOR_UNVISITED_FLAME, "unvisited generated flame is grey on the full map", failures)
		map.on_room_entered(flame_room.id)
		var visited_image: Image = minimap.snapshot_full_image()
		_expect(visited_image.get_pixelv(flame_room.minimap_coordinate - flame_origin) == MINIMAP_SCRIPT.COLOR_FIRE, "visited generated flame returns to its fire color", failures)
	else:
		_expect(false, "generated layout exposes a flame room", failures)
	var flame_ids: Array[StringName] = map.flame_room_ids()
	_expect(not flame_ids.is_empty(), "generated map exposes flame destinations", failures)
	var teleport_ids: Array[StringName] = map.teleport_destination_room_ids()
	_expect(teleport_ids.has(graph.start_room_id), "teleport destinations include the Hub", failures)
	if not flame_ids.is_empty():
		var travel_state := map.get("state") as DungeonMapState
		map.on_room_entered(flame_ids[0])
		_expect(minimap.open_map(null), "minimap opens from the gameplay map state", failures)
		_expect(minimap.is_map_open() and minimap.get("map_overlay").visible, "open minimap displays its full-map overlay", failures)
		minimap.close_map()
		if flame_ids.size() >= 2:
			_expect(not map.can_fast_travel_to_flame(flame_ids[0], flame_ids[1]), "unvisited flame cannot be selected for fast travel", failures)
			travel_state.mark_flame_visited(flame_ids[1])
			_expect(map.can_fast_travel_to_flame(flame_ids[0], flame_ids[1]), "visited flame can be selected for fast travel from a flame room", failures)
		_expect(map.can_fast_travel_to_flame(flame_ids[0], graph.start_room_id), "Hub can be selected for fast travel from a flame room", failures)
		_expect(map.can_fast_travel_to_flame(graph.start_room_id, flame_ids[0]), "flame can be selected for fast travel from the Hub", failures)
		var non_flame_origin = null
		for candidate in layout.rooms:
			if candidate.id != graph.start_room_id and candidate.fire_flame.is_empty():
				non_flame_origin = candidate
				break
		_expect(non_flame_origin == null or not map.can_fast_travel_to_flame(non_flame_origin.id, flame_ids[0]), "fast travel rejects non-flame, non-Hub origins", failures)
	for room in layout.rooms:
		map.on_room_entered(room.id)
	var image: Image = minimap.snapshot_image()
	var full_image: Image = minimap.snapshot_full_image()
	_expect(minimap.visible, "generated run exposes a minimap", failures)
	_expect(image != null and image.get_size() == MINIMAP_SCRIPT.MINIMAP_VIEW_SIZE, "generated minimap uses the fixed 25x25 circular display window", failures)
	_expect(full_image != null and full_image.get_height() > MINIMAP_SCRIPT.MAP_SIZE.y, "generated Run 7 retains its expanded full-map geometry", failures)
	if full_image != null:
		var start = layout.room_by_id(graph.start_room_id)
		var boss = null
		for room in layout.rooms:
			if room.room_type == DungeonGraph.ROOM_BOSS:
				boss = room
				break
		var full_origin: Vector2i = minimap.get("full_map_origin") as Vector2i
		var start_pixel: Vector2i = start.minimap_coordinate - full_origin
		_expect(full_image.get_pixelv(start_pixel) == MINIMAP_SCRIPT.COLOR_HUB, "generated minimap renders the start room at its full-map coordinate", failures)
		_expect(boss != null and start.minimap_coordinate.y > boss.minimap_coordinate.y, "generated minimap presents the Hub below the boss", failures)
		_expect(_image_contains(full_image, MINIMAP_SCRIPT.COLOR_ORB_MARKER), "generated minimap keeps the shared Orb Room marker language", failures)
	var marker := minimap.get_node_or_null("CurrentRoomMarker") as Sprite2D
	_expect(marker != null and marker.scale.is_equal_approx(Vector2(2.0, 2.0)), "generated minimap installs a pixel-scaled player marker", failures)
	if marker != null:
		var map_state := map.get("state") as DungeonMapState
		var current_room = layout.room_by_id(map_state.current_room_id) if map_state != null else null
		var origin: Vector2i = minimap.get("map_origin") as Vector2i
		_expect(current_room != null and current_room.minimap_coordinate - origin == Vector2i(12, 12), "generated minimap centers the occupied room in the display window", failures)
		_expect(marker.position.is_equal_approx(MINIMAP_SCRIPT.MAP_POSITION + Vector2(12, 12) * MINIMAP_SCRIPT.DISPLAY_SCALE), "generated minimap marker stays at the display center", failures)
	var fusion_graph = GRAPH_SCRIPT.new()
	var fusion_map = MAP_CONTROLLER_SCRIPT.new()
	var fusion_minimap = MINIMAP_SCRIPT.new()
	root.add_child(fusion_map)
	root.add_child(fusion_minimap)
	fusion_map.begin_run(fusion_graph, 864210, 5, &"fire")
	fusion_minimap.configure(fusion_map)
	var fusion_layout = fusion_map.get("layout")
	var fusion_gate = null
	for room in fusion_layout.rooms:
		fusion_map.on_room_entered(room.id)
	for room_id in fusion_graph.get_room_ids():
		var room := fusion_graph.get_room(room_id)
		if room == null:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			if connection != null and connection.resolved_gate_type() == GRAPH_SCRIPT.GATE_ENTRANCE_ORB:
				fusion_gate = connection
				break
		if fusion_gate != null:
			break
	var fusion_image: Image = fusion_minimap.snapshot_full_image()
	var fusion_origin: Vector2i = fusion_minimap.get("full_map_origin") as Vector2i
	var fusion_requirement: StringName = fusion_gate.orb_element_requirement if fusion_gate != null else &""
	var fusion_expected_color := fusion_map.door_display_color(fusion_requirement)
	_expect(fusion_gate != null and fusion_image != null and fusion_image.get_pixelv(fusion_gate.minimap_coordinate - fusion_origin) == fusion_expected_color, "generated minimap colors the entrance-orb gate from its mixed element", failures)
	fusion_minimap.queue_free()
	fusion_map.queue_free()
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
