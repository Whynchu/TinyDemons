extends SceneTree

const TARGET_ROOM: StringName = &"room_-1_1"

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for wall socket geometry coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	var rooms := gameplay.get("room_controller") as RoomController
	var map := gameplay.get("dungeon_map_controller") as Node
	_expect(graph != null and rooms != null and map != null, "wall socket geometry owners are composed", failures)
	if graph != null and rooms != null and map != null:
		var room := graph.get_room(TARGET_ROOM)
		_expect(room != null, "the authored normal-room geometry target exists", failures)
		if room != null:
			map.call("set_starter_flame_attuned", true)
			rooms.room_states.clear()
			gameplay.set("current_room_id", TARGET_ROOM)
			gameplay.call("_sync_current_room_metadata")
			rooms.set_current_room(TARGET_ROOM, gameplay.get("current_room_type"))
			gameplay.call("_collect_dungeon_sockets")
			gameplay.call("_ensure_current_room_layout")
			gameplay.call("_apply_room_state")
			var left_socket := rooms.dungeon_sockets.get(DungeonGraph.WALL_LEFT) as DungeonSocket
			var right_socket := rooms.dungeon_sockets.get(DungeonGraph.WALL_RIGHT) as DungeonSocket
			_expect(left_socket != null and left_socket.block_trigger_when_closed, "left wall socket declares a closed seam blocker", failures)
			_expect(right_socket != null and right_socket.block_trigger_when_closed, "right wall socket declares a closed seam blocker", failures)
			var blocks := gameplay.get("entrance_block_polygons") as Array
			var initially_closed_side_count := 0
			for socket_id in [DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT]:
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
				var connection := graph.get_connection(TARGET_ROOM, socket_id)
				var available := connection != null and bool(map.call("is_connection_available", connection, false))
				if available:
					continue
				initially_closed_side_count += 1
				_expect(_contains_polygon(blocks, trigger), "closed %s doorway seam is physically blocked" % String(socket_id), failures)
				_expect(_polygon_edge_samples_blocked(gameplay, trigger), "closed %s doorway cannot be entered through its seam" % String(socket_id), failures)
			_expect(initially_closed_side_count > 0, "normal combat room exposes a closed side doorway for the seam check", failures)

			# Lower entrances use hidden floor placeholders rather than a door sprite.
			# Their return trigger must still be part of the closed collision fence.
			var closed_bottom_count := 0
			for socket_id in [DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_RIGHT]:
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				_expect(socket != null and socket.block_trigger_when_closed, "closed %s entrance declares a seam blocker" % String(socket_id), failures)
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
				if not _contains_polygon(blocks, trigger):
					continue
				closed_bottom_count += 1
				_expect(_polygon_edge_samples_blocked(gameplay, trigger), "closed %s entrance seam is physically blocked" % String(socket_id), failures)
			_expect(closed_bottom_count > 0, "normal combat room exposes a closed lower entrance for the seam check", failures)

			# Exercise both authored lower sockets in isolation as closed entrances.
			# This catches asymmetry in the mirrored right-hand placeholder even when
			# the selected room currently has that side open.
			var saved_door_socket_ids := rooms.active_door_sockets.keys()
			var saved_entrance_socket_ids := rooms.active_entrance_sockets.keys()
			rooms.active_door_sockets.clear()
			rooms.active_entrance_sockets.clear()
			for socket_id in [DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_RIGHT]:
				rooms.active_door_sockets[socket_id] = rooms.dungeon_sockets.get(socket_id)
			gameplay.call("_build_entrance_block_polygons")
			var isolated_lower_blocks := gameplay.get("entrance_block_polygons") as Array
			var isolated_player := gameplay.get("player") as Sprite2D
			var isolated_player_position := isolated_player.position
			for socket_id in [DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_RIGHT]:
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
				_expect(_contains_polygon(isolated_lower_blocks, trigger), "isolated closed %s entrance includes its trigger fence" % String(socket_id), failures)
				_expect(_polygon_edge_samples_blocked(gameplay, trigger), "isolated closed %s entrance has no walkable seam" % String(socket_id), failures)
				var trigger_center := _polygon_center(trigger)
				isolated_player.position = trigger_center - gameplay.get("ACTOR_FOOT_OFFSET")
				_expect(not bool(gameplay.call("_can_actor_stand_at_current_position", isolated_player)), "isolated closed %s entrance rejects the actor body" % String(socket_id), failures)
			isolated_player.position = isolated_player_position
			rooms.active_door_sockets.clear()
			rooms.active_entrance_sockets.clear()
			for socket_id in saved_door_socket_ids:
				rooms.active_door_sockets[socket_id] = rooms.dungeon_sockets.get(socket_id)
			for socket_id in saved_entrance_socket_ids:
				rooms.active_entrance_sockets[socket_id] = rooms.dungeon_sockets.get(socket_id)
			gameplay.call("_build_entrance_block_polygons")
			blocks = gameplay.get("entrance_block_polygons") as Array

			var player := gameplay.get("player") as Sprite2D
			var saved_player_position := player.position
			for block_value in blocks:
				var block := block_value as PackedVector2Array
				if block.size() < 3:
					continue
				var block_center := Vector2.ZERO
				for point in block:
					block_center += point
				block_center /= float(block.size())
				player.position = block_center - gameplay.get("ACTOR_FOOT_OFFSET")
				_expect(not bool(gameplay.call("_can_actor_stand_at_current_position", player)), "actor body cannot straddle a closed doorway blocker", failures)
			player.position = saved_player_position

			# Completing the room opens its authored side exits. The same trigger
			# polygons must then stop blocking the matching visible doorway.
			map.call("on_room_completed", TARGET_ROOM)
			gameplay.call("_on_dungeon_map_state_changed")
			blocks = gameplay.get("entrance_block_polygons") as Array
			var open_side_count := 0
			for socket_id in [DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT]:
				if not rooms.active_door_sockets.has(socket_id):
					continue
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
				var connection := graph.get_connection(TARGET_ROOM, socket_id)
				if connection == null or not bool(map.call("is_connection_available", connection, false)):
					continue
				open_side_count += 1
				_expect(not _contains_polygon(blocks, trigger), "opened %s doorway no longer uses a seam blocker" % String(socket_id), failures)
			_expect(open_side_count > 0, "normal combat room exposes at least one side doorway for the open-state check", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _contains_polygon(polygons: Array, target: PackedVector2Array) -> bool:
	if target.size() < 3:
		return false
	for candidate_value in polygons:
		var candidate := candidate_value as PackedVector2Array
		if candidate.size() != target.size():
			continue
		var matches := true
		for index in target.size():
			if not candidate[index].is_equal_approx(target[index]):
				matches = false
				break
		if matches:
			return true
	return false


func _polygon_edge_samples_blocked(gameplay: Node, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	for index in polygon.size():
		var point := polygon[index].lerp(polygon[(index + 1) % polygon.size()], 0.5)
		if bool(gameplay.call("_is_walkable", point)):
			return false
	return true


func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	return center / float(polygon.size()) if not polygon.is_empty() else Vector2.ZERO


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: wall socket geometry smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("WALL_SOCKET_GEOMETRY_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
