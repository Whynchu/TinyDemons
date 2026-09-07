extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run4.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var layout = LAYOUT_SCRIPT.build(&"water")
	_expect(layout.layout_id == &"RUN4", "R4 layout identity is RUN4", failures)
	_expect(layout.validate().is_empty(), "R4 authored layout validates", failures)
	_expect(layout.map_size == Vector2i(35, 35), "R4 uses the 35x35 map canvas", failures)
	_expect(layout.rooms.size() > 0 and layout.connections.size() > 0, "R4 contains authored rooms and connections", failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_START) == 1, "R4 has one Hub", failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_BOSS) == 1, "R4 has one Boss room", failures)
	var graph = GRAPH_SCRIPT.new()
	var map = MAP_CONTROLLER_SCRIPT.new()
	root.add_child(map)
	map.begin_run(graph, 40917, 3, &"water")
	_expect(bool(map.call("is_authored_run4")), "Run 4 selects the authored R4 layout", failures)
	_expect(graph.get_room_ids().size() == layout.rooms.size(), "Runtime R4 graph uses the authored room count", failures)
	map.queue_free()
	_finish(failures)


func _room_type_count(layout, room_type: StringName) -> int:
	var count := 0
	for room in layout.rooms:
		if room.room_type == room_type:
			count += 1
	return count


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("R4_AUTHORED_LAYOUT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
