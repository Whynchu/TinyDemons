extends SceneTree

const LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run2.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const MINIMAP_SCRIPT = preload("res://scripts/dungeon_minimap_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var layout = LAYOUT_SCRIPT.build(&"water")
	_expect(layout.layout_id == &"RUN2", "the promoted complex map identifies itself as Run 2", failures)
	_expect(layout.validate().is_empty(), "the promoted Run 2 layout validates", failures)
	var alternate_fire_found := false
	for room in layout.rooms:
		if room.room_type == GRAPH_SCRIPT.ROOM_FIRE and room.fire_flame == &"fire":
			alternate_fire_found = true
	_expect(alternate_fire_found, "Run 2 preserves a reachable source for the first unchosen flame", failures)

	var graph = GRAPH_SCRIPT.new()
	var map = MAP_CONTROLLER_SCRIPT.new()
	var minimap = MINIMAP_SCRIPT.new()
	root.add_child(map)
	root.add_child(minimap)
	map.begin_run(graph, 221144, 1, &"water")
	minimap.configure(map)
	_expect(bool(map.call("is_authored_run2")), "completed run count 1 selects the authored Run 2 map", failures)
	_expect(bool(map.call("is_authored_layout")), "Run 2 uses the fixed authored minimap geometry", failures)
	_expect(graph.get_room(&"room_0_10") != null, "Run 2 keeps the complex map's authored boss room", failures)
	_expect(minimap.snapshot_image() != null and minimap.snapshot_image().get_size() == Vector2i(16, 23), "Run 2 renders on the authored 16x23 canvas", failures)
	var rare_branch_entry: DungeonGraph.ConnectionRecord = graph.get_connection_for_entry(&"room_-1_9", GRAPH_SCRIPT.BOTTOM_RIGHT)
	var special_red_exit: DungeonGraph.ConnectionRecord = graph.get_connection(&"room_-1_9", GRAPH_SCRIPT.WALL_LEFT)
	_expect(rare_branch_entry != null and rare_branch_entry.source_room_id == &"room_0_8" and rare_branch_entry.allow_entry_before_source_clear, "Run 2 applies the rare down-right enemy entry exception", failures)
	_expect(map.is_connection_available(rare_branch_entry, true), "Run 2's rare down-right enemy entrance is open before clear", failures)
	_expect(not map.is_connection_available(rare_branch_entry, false), "Run 2 keeps that enemy room's top exit clear-gated", failures)
	var map_state := map.get("state") as DungeonMapState
	if map_state != null:
		map_state.set_puzzle_color(&"puzzle_a")
	_expect(not map.is_connection_available(special_red_exit, false), "Run 2's red door remains locked while the Special Room is uncleared", failures)
	map.call("on_room_completed", &"room_-1_9")
	_expect(map.is_connection_available(special_red_exit, false), "Run 2's red door opens after the Special Room is cleared", failures)
	minimap.queue_free()
	map.queue_free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN2_AUTHORED_LAYOUT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
