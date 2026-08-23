extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_definition.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var graph = GRAPH_SCRIPT.new()
	var layout = LAYOUT_SCRIPT.new(&"ENGAGEMENT_TEST", Vector2i(8, 8))
	layout.add_room(layout.make_room_spec(&"room_0_0", Vector2i(0, 0), Vector2i(4, 6), GRAPH_SCRIPT.ROOM_START))
	layout.add_room(layout.make_room_spec(&"room_-1_1", Vector2i(-1, 1), Vector2i(3, 5), GRAPH_SCRIPT.ROOM_COMBAT))
	layout.add_room(layout.make_room_spec(&"room_-2_2", Vector2i(-2, 2), Vector2i(2, 4), GRAPH_SCRIPT.ROOM_COMBAT))
	layout.add_connection(layout.make_connection_spec(&"room_0_0", GRAPH_SCRIPT.WALL_LEFT, &"room_-1_1", GRAPH_SCRIPT.BOTTOM_RIGHT))
	layout.add_connection(layout.make_connection_spec(&"room_-1_1", GRAPH_SCRIPT.WALL_LEFT, &"room_-2_2", GRAPH_SCRIPT.BOTTOM_RIGHT))
	graph.initialize_from_layout(13579, layout)

	var map = MAP_CONTROLLER_SCRIPT.new()
	map.graph = graph
	map.state.begin(graph.start_room_id)
	# This fixture starts after the hub-fire lesson; the test covers enemy-room
	# engagement, not the starter flame gate itself.
	map.set_starter_flame_attuned(true)
	map.on_room_entered(&"room_0_0")
	map.on_room_entered(&"room_-1_1")
	var incoming := graph.get_connection_for_entry(&"room_-1_1", GRAPH_SCRIPT.BOTTOM_RIGHT)
	var outgoing := graph.get_connection(&"room_-1_1", GRAPH_SCRIPT.WALL_LEFT)
	_expect(incoming != null and map.is_connection_available(incoming, true), "unengaged enemy room leaves its arrival entrance open", failures)
	_expect(outgoing != null and not map.is_connection_available(outgoing, false), "unengaged enemy room keeps forward exits locked", failures)
	_expect(map.mark_room_engaged(&"room_-1_1"), "first landed player hit engages the enemy room", failures)
	_expect(map.is_room_engaged(&"room_-1_1"), "engagement is tracked by map state", failures)
	_expect(incoming != null and not map.is_connection_available(incoming, true), "engagement locks the arrival entrance", failures)
	_expect(incoming != null and map.connection_visual_state(incoming, true) == &"room_locked", "engagement produces the locked entrance visual state", failures)
	map.on_room_completed(&"room_-1_1")
	_expect(not map.is_room_engaged(&"room_-1_1"), "clearing the room releases engagement state", failures)
	_expect(incoming != null and map.is_connection_available(incoming, true), "clearing the room reopens the arrival entrance", failures)
	_expect(outgoing != null and map.is_connection_available(outgoing, false), "clearing the room opens forward exits", failures)
	_expect(not map.mark_room_engaged(&"room_0_0"), "safe rooms cannot enter enemy engagement state", failures)
	map.free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENEMY_ROOM_ENGAGEMENT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
