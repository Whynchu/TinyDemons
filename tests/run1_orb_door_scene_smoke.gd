extends SceneTree

const TARGET_ROOM: StringName = &"room_-1_1"


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for the first Orb doorway contract", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	var map := gameplay.get("dungeon_map_controller") as Node
	var rooms := gameplay.get("room_controller") as RoomController
	var orbs := gameplay.get("puzzle_torches") as Array[Sprite2D]
	_expect(graph != null and map != null and rooms != null and orbs != null and orbs.size() == 1, "first Orb doorway owners are composed", failures)
	if graph != null and map != null and rooms != null and orbs != null and orbs.size() == 1:
		map.call("begin_run", graph, 44017, 0, &"fire")
		rooms.room_states.clear()
		gameplay.set("current_room_id", TARGET_ROOM)
		gameplay.call("_sync_current_room_metadata")
		rooms.set_current_room(TARGET_ROOM, gameplay.get("current_room_type"))
		gameplay.call("_collect_dungeon_sockets")
		gameplay.call("_ensure_current_room_layout")
		gameplay.call("_apply_room_state")
		var left_connection := graph.get_connection(TARGET_ROOM, DungeonGraph.WALL_LEFT)
		var right_connection := graph.get_connection(TARGET_ROOM, DungeonGraph.WALL_RIGHT)
		_expect(map.call("current_color") == &"puzzle_b", "first Orb Room starts in the grey Puzzle B state", failures)
		_expect(left_connection != null and not bool(map.call("is_connection_available", left_connection, false)), "first Orb Puzzle A treasure door starts closed", failures)
		_expect(right_connection != null and bool(map.call("is_connection_available", right_connection, false)), "first Orb Puzzle B continuation door starts open", failures)
		_expect(gameplay.call("_map_connection_visual_state", left_connection, false) == &"orb_locked", "closed first Orb treasure door has the locked visual state", failures)
		_expect(gameplay.call("_map_connection_visual_state", right_connection, false) == &"open", "open first Orb continuation door has the open visual state", failures)
		var player := gameplay.get("player") as Sprite2D
		var left_socket := rooms.dungeon_sockets.get(DungeonGraph.WALL_LEFT) as DungeonSocket
		var right_socket := rooms.dungeon_sockets.get(DungeonGraph.WALL_RIGHT) as DungeonSocket
		_expect(player != null and left_socket != null and right_socket != null, "first Orb wall sockets expose player-test geometry", failures)
		if player != null and left_socket != null and right_socket != null:
			var left_center := _polygon_center(left_socket)
			player.global_position += left_center - (gameplay.call("_actor_foot", player) as Vector2)
			_expect(not bool(gameplay.call("_can_actor_stand_at_current_position", player)), "a closed first Orb doorway rejects the player body", failures)
			_expect(not bool(gameplay.call("_try_enter_any_active_socket")), "a closed first Orb doorway cannot transition", failures)

			# Recoloring the Orb closes the currently open continuation seam. The
			# player is deliberately standing in that seam to reproduce the stuck
			# casting case; the block rebuild must move them to usable floor.
			var right_center := _polygon_center(right_socket)
			player.global_position += right_center - (gameplay.call("_actor_foot", player) as Vector2)
			var before_recolor := player.global_position
			# Use the projectile-hit boundary so this covers the same magic path that
			# changes the live Orb state during normal play.
			gameplay.call("_resolve_magic_projectile_hit", orbs[0], orbs[0].global_position, "red", 0)
			_expect(map.call("current_color") == &"puzzle_a", "first Orb magic accepts the Puzzle A recolor", failures)
			_expect(player.global_position.distance_to(before_recolor) > 0.1, "closing a doorway ejects a player who is standing in its seam", failures)
			_expect(bool(gameplay.call("_can_actor_stand_at_current_position", player)), "ejected player lands on valid walkable floor", failures)
			_expect(bool(gameplay.call("_is_walkable", gameplay.call("_actor_foot", player))), "ejected player foot is outside the closed doorway fence", failures)
			_expect(gameplay.get("current_room_id") == TARGET_ROOM, "doorway ejection keeps the player in the Orb room", failures)
			_expect(not bool(map.call("is_connection_available", right_connection, false)) and bool(map.call("is_connection_available", left_connection, false)), "Orb recolor swaps the live doorway availability", failures)
			_expect(not bool(gameplay.get("chest").get("visible")), "Orb-room state keeps the treasure chest presentation hidden", failures)
			player.global_position += left_center - (gameplay.call("_actor_foot", player) as Vector2)
			_expect(bool(gameplay.call("_try_enter_any_active_socket")), "recolored first Orb opens the Puzzle A treasure doorway", failures)
			_expect(gameplay.get("current_room_id") == &"room_-2_2", "Puzzle A doorway lands in the authored Treasure room", failures)
			_expect(bool(gameplay.get("chest").get("visible")), "authored Treasure room presents its center-floor chest", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _polygon_center(socket: DungeonSocket) -> Vector2:
	var trigger := socket.trigger()
	if trigger == null or trigger.polygon.is_empty():
		return Vector2.ZERO
	var center := Vector2.ZERO
	for point in trigger.polygon:
		center += trigger.to_global(point)
	return center / float(trigger.polygon.size())


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN1_ORB_DOOR_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
