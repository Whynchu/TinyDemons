extends SceneTree

const LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run1.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var layout = LAYOUT_SCRIPT.build()
	var connection_spec = null
	for candidate in layout.connections:
		if candidate.source_room_id == &"room_0_3" and candidate.exit_socket == GRAPH_SCRIPT.WALL_RIGHT:
			connection_spec = candidate
			break
	_expect(connection_spec != null, "event smoke finds an authored connection to gate", failures)
	if connection_spec == null:
		_finish(failures)
		return

	var graph = GRAPH_SCRIPT.new()
	var controller = MAP_CONTROLLER_SCRIPT.new()
	controller.begin_run(graph, 314159, 0)
	var connection: DungeonGraph.ConnectionRecord = graph.get_connection(&"room_0_3", GRAPH_SCRIPT.WALL_RIGHT)
	connection.hidden_until_event = &"fire_branch_revealed"
	controller.on_room_completed(&"room_0_3")
	_expect(not controller.is_connection_available(connection), "event-gated connection remains unavailable before its event", failures)
	_expect(not controller.is_connection_revealed(connection), "event-gated connection remains hidden before its event", failures)
	_expect(controller.reveal_event(&"fire_branch_revealed"), "event reveal changes the map state once", failures)
	_expect(controller.is_event_revealed(&"fire_branch_revealed"), "map controller reports a revealed event", failures)
	_expect(controller.is_connection_available(connection), "event-gated connection opens after its event and source clear", failures)
	_expect(controller.is_connection_revealed(connection), "event reveal exposes the gated connection to presentation", failures)
	_expect(not controller.reveal_event(&"fire_branch_revealed"), "event reveal is idempotent", failures)
	var state_snapshot: Dictionary = controller.get("state").to_dictionary()
	_expect(bool((state_snapshot.get("revealed_events", {}) as Dictionary).get(&"fire_branch_revealed", false)), "revealed events are included in state serialization", failures)
	var flame_room_id: StringName = &""
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room != null and not room.fire_flame.is_empty():
			flame_room_id = room.id
			break
	if not flame_room_id.is_empty():
		_expect(not controller.is_flame_visited(flame_room_id), "flame starts unvisited in map state", failures)
		controller.on_room_entered(flame_room_id)
		_expect(controller.is_flame_visited(flame_room_id), "entering a flame marks it visited", failures)
		var flame_snapshot: Dictionary = controller.get("state").to_dictionary()
		_expect(bool((flame_snapshot.get("visited_flame_rooms", {}) as Dictionary).get(flame_room_id, false)), "visited flames are included in state serialization", failures)

	controller.free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("DUNGEON_MAP_EVENT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
