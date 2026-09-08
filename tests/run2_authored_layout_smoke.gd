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
	_expect(minimap.snapshot_image() != null and minimap.snapshot_image().get_size() == MINIMAP_SCRIPT.MINIMAP_VIEW_SIZE, "Run 2 renders through the fixed 25x25 circular minimap window", failures)
	var rare_branch_entry: DungeonGraph.ConnectionRecord = graph.get_connection_for_entry(&"room_-1_9", GRAPH_SCRIPT.BOTTOM_RIGHT)
	var special_red_exit: DungeonGraph.ConnectionRecord = graph.get_connection(&"room_-1_9", GRAPH_SCRIPT.WALL_LEFT)
	_expect(rare_branch_entry != null and rare_branch_entry.source_room_id == &"room_0_8" and rare_branch_entry.allow_entry_before_source_clear, "Run 2 applies the rare down-right enemy entry exception", failures)
	_expect(map.is_connection_available(rare_branch_entry, true), "Run 2's rare down-right enemy entrance is open before clear", failures)
	_expect(rare_branch_entry != null and rare_branch_entry.requires_source_room_clear, "Run 2 keeps the rare branch's source exit clear-gated", failures)
	var map_state := map.get("state") as DungeonMapState
	if map_state != null:
		map_state.set_puzzle_color(&"puzzle_a")
	_expect(special_red_exit != null and special_red_exit.color_requirement == &"puzzle_a", "Run 2's Special Room exit carries its red/puzzle-A requirement", failures)
	_expect(special_red_exit != null and special_red_exit.requires_source_room_clear, "Run 2's red door remains source-clear gated while the Special Room is uncleared", failures)
	_expect(not map.is_connection_color_locked(special_red_exit), "Run 2's active Puzzle A state matches the red door requirement", failures)
	map.call("on_room_completed", &"room_-1_9")
	_expect(map_state != null and map_state.is_room_completed(&"room_-1_9"), "Run 2 records the Special Room as completed", failures)
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
