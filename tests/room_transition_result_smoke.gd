extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var graph := DungeonGraph.new()
	var start := graph.initialize(44017)
	var connection := graph.ensure_connection(DungeonGraph.START_ROOM_ID, DungeonGraph.WALL_LEFT, DungeonGraph.ROOM_COMBAT)
	var rooms := RoomController.new()

	_expect(start != null, "transition fixture creates a start room", failures)
	_expect(connection != null, "transition fixture creates a connected destination", failures)
	if connection != null:
		var planned := rooms.plan_connection_transition(graph, connection)
		_expect(planned != null and planned.is_ready(), "connected room transition is ready", failures)
		_expect(planned.source_room_id == connection.source_room_id, "transition preserves its source room", failures)
		_expect(planned.destination_room_id == connection.destination_room_id, "transition preserves its destination room", failures)
		_expect(planned.departure_socket_id == connection.exit_socket, "transition preserves its departure socket", failures)
		_expect(planned.arrival_socket_id == connection.destination_entry, "transition preserves its arrival socket", failures)
		_expect(planned.destination_room_type == DungeonGraph.ROOM_COMBAT, "transition carries the destination room type", failures)

	var missing_destination := rooms.plan_connected_room_transition(
		graph, DungeonGraph.START_ROOM_ID, &"missing_room", DungeonGraph.BOTTOM_LEFT)
	_expect(not missing_destination.is_ready(), "missing destination is rejected before runtime mutation", failures)
	_expect(missing_destination.status == RoomTransitionResult.Status.MISSING_DESTINATION, "missing destination has a typed rejection status", failures)

	var missing_graph := rooms.plan_connected_room_transition(
		null, DungeonGraph.START_ROOM_ID, DungeonGraph.START_ROOM_ID, &"")
	_expect(not missing_graph.is_ready(), "missing graph is rejected before runtime mutation", failures)
	_expect(missing_graph.status == RoomTransitionResult.Status.INVALID_GRAPH, "missing graph has a typed rejection status", failures)

	var missing_connection := rooms.plan_connection_transition(graph, null)
	_expect(not missing_connection.is_ready(), "missing connection is rejected before runtime mutation", failures)
	_expect(missing_connection.status == RoomTransitionResult.Status.INVALID_CONNECTION, "missing connection has a typed rejection status", failures)

	var clear_events: Array[RoomClearResult] = []
	rooms.room_cleared.connect(func(result: RoomClearResult) -> void: clear_events.append(result))
	var clear_context := RoomClearContext.new(DungeonGraph.START_ROOM_ID, graph.get_room(DungeonGraph.START_ROOM_ID))
	var clear_result := rooms.mark_cleared_context(clear_context)
	_expect(clear_result.succeeded() and clear_result.is_new_clear(), "room clear applies through a typed context and result", failures)
	_expect(clear_result.room_id == DungeonGraph.START_ROOM_ID, "room clear result preserves the room identity", failures)
	_expect(clear_events.size() == 1 and clear_events[0] == clear_result, "room clear emits the typed result once", failures)
	var repeated_clear := rooms.mark_cleared_context(clear_context)
	_expect(repeated_clear.status == RoomClearResult.Status.ALREADY_CLEARED, "repeated room clear is reported without re-emitting", failures)
	_expect(clear_events.size() == 1, "repeated room clear does not duplicate the event", failures)

	var enemy := Sprite2D.new()
	var combat := SlimeCombatComponent.new()
	var health := HealthComponent.new()
	health.maximum_health = 10.0
	health.current_health = 7.0
	var enemy_slimes: Array[Sprite2D] = [enemy]
	var enemy_combats: Array[SlimeCombatComponent] = [combat]
	var enemy_health: Array[HealthComponent] = [health]
	rooms.room_states[&"runtime_room"] = {"enemy_variants": ["grey"]}
	var runtime_context := RoomEnemyRuntimeContext.new(&"runtime_room", ["grey"], enemy_slimes, enemy_combats, enemy_health)
	var runtime_result := rooms.save_enemy_runtime_state_context(runtime_context)
	var runtime_state := rooms.room_states[&"runtime_room"] as Dictionary
	_expect(runtime_result.succeeded() and runtime_result.saved_slots == 1, "enemy runtime saves through a typed context", failures)
	_expect(bool((runtime_state["enemy_runtime"] as Dictionary)["0"]["alive"]) and is_equal_approx(float((runtime_state["enemy_runtime"] as Dictionary)["0"]["health"]), 7.0), "enemy runtime result preserves live health state", failures)
	enemy.free()
	combat.free()
	health.free()

	rooms.free()
	if failures.is_empty():
		print("ROOM_TRANSITION_RESULT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
