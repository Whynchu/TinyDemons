extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/boss_room_debug.tscn") as PackedScene
	_expect(packed != null, "boss debug scene loads for exit-path smoke", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 90:
		await process_frame
	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	var map := gameplay.get("dungeon_map_controller") as Node
	var rooms := gameplay.get("room_controller") as RoomController
	var boss_room_id: StringName = gameplay.get("current_room_id")
	var entry_socket: DungeonSocket = null
	var entry_connection: DungeonGraph.ConnectionRecord = null
	if graph != null and rooms != null:
		for socket_value in rooms.active_entrance_sockets.values():
			var candidate_socket := socket_value as DungeonSocket
			var candidate_connection := graph.get_connection_for_entry(boss_room_id, candidate_socket.socket_id())
			if candidate_connection != null:
				entry_socket = candidate_socket
				entry_connection = candidate_connection
				break
	_expect(entry_socket != null and entry_connection != null, "boss room exposes a return socket", failures)
	if entry_connection != null and map != null:
		var map_state := map.get("state") as DungeonMapState
		if map_state != null:
			var required_color := entry_connection.color_requirement
			map_state.set_puzzle_color(required_color if not required_color.is_empty() else &"puzzle_a")
		map.call("on_room_completed", entry_connection.source_room_id)
		_expect(bool(gameplay.call("_map_connection_available", entry_connection, true)), "boss return connection is available after its approach is clear", failures)
	gameplay.call("_on_room_enemies_cleared")
	_expect(bool(gameplay.get("entrance_open")), "boss victory opens the return entrance", failures)
	if entry_socket != null and entry_connection != null:
		var trigger_center := _polygon_center(entry_socket.trigger())
		var player := gameplay.get("player") as Sprite2D
		player.global_position = entry_socket.spawn_marker().global_position
		gameplay.set("room_transition_locked", false)
		for slime in gameplay.get("slimes") as Array[Sprite2D]:
			slime.visible = false
		var entered := false
		for _step in 120:
			if gameplay.get("current_room_id") != boss_room_id:
				entered = true
				break
			var toward_exit := (trigger_center - (gameplay.call("_actor_foot", player) as Vector2)).normalized() * 2.0
			var movement := gameplay.call("_perspective_movement", toward_exit) as Vector2
			gameplay.call("_try_move_actor", player, movement)
		_expect(entered, "player can walk from the boss arrival marker to the reopened entrance", failures)
		_expect(gameplay.get("current_room_id") == entry_connection.source_room_id, "walking through the boss entrance returns to the approach room", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _polygon_center(guide: Polygon2D) -> Vector2:
	if guide == null or guide.polygon.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in guide.polygon:
		center += guide.to_global(point)
	return center / float(guide.polygon.size())


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("BOSS_EXIT_PATH_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
