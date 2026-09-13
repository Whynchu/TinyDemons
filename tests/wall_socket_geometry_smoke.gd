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
			var area := gameplay.get("walkable_area") as WalkableArea
			var player := gameplay.get("player") as Sprite2D
			_expect(area != null, "room exposes the shared walkable-area owner", failures)
			var left_socket := rooms.dungeon_sockets.get(DungeonGraph.WALL_LEFT) as DungeonSocket
			var right_socket := rooms.dungeon_sockets.get(DungeonGraph.WALL_RIGHT) as DungeonSocket
			_expect(left_socket != null and left_socket.block_trigger_when_closed, "left wall socket declares a closed seam blocker", failures)
			_expect(right_socket != null and right_socket.block_trigger_when_closed, "right wall socket declares a closed seam blocker", failures)
			var initially_closed_side_count := 0
			for socket_id in [DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT]:
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
				var connection := graph.get_connection(TARGET_ROOM, socket_id)
				var available := connection != null and bool(map.call("is_connection_available", connection, false))
				if available:
					continue
				initially_closed_side_count += 1
				_expect(not _socket_has_walkable_portal(rooms, area, gameplay, socket), "closed %s doorway contributes no walkable portal" % String(socket_id), failures)
				_expect(not _can_enter_socket_at_trigger(gameplay, player, trigger), "closed %s doorway cannot transition rooms" % String(socket_id), failures)
			_expect(initially_closed_side_count > 0, "normal combat room exposes a closed side doorway for the seam check", failures)

			# Lower entrances use hidden floor placeholders rather than a door sprite.
			# Closed entrances remain outside the open portal set; their trigger is
			# still the transition boundary used by the room controller.
			var closed_bottom_count := 0
			for socket_id in [DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_RIGHT]:
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				_expect(socket != null and socket.block_trigger_when_closed, "closed %s entrance declares a transition boundary" % String(socket_id), failures)
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
				if _socket_has_walkable_portal(rooms, area, gameplay, socket):
					continue
				closed_bottom_count += 1
				_expect(not _can_enter_socket_at_trigger(gameplay, player, trigger), "closed %s entrance cannot transition rooms" % String(socket_id), failures)
			_expect(closed_bottom_count > 0, "normal combat room exposes a closed lower entrance for the seam check", failures)

			# Exercise both authored lower sockets in isolation as closed entrances.
			# This catches asymmetry in the mirrored right-hand placeholder even when
			# the selected room currently has that side open. The current movement
			# model represents open seams as portals, so a closed isolated socket must
			# leave the shared portal set empty rather than add a blocker polygon.
			var saved_door_socket_ids := rooms.active_door_sockets.keys()
			var saved_entrance_socket_ids := rooms.active_entrance_sockets.keys()
			rooms.active_door_sockets.clear()
			rooms.active_entrance_sockets.clear()
			for socket_id in [DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_RIGHT]:
				rooms.active_door_sockets[socket_id] = rooms.dungeon_sockets.get(socket_id)
			gameplay.call("_build_entrance_block_polygons")
			_expect(area.portal_regions.is_empty(), "isolated closed lower entrances add no walkable portals", failures)
			for socket_id in [DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_RIGHT]:
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
				var trigger_center := _polygon_center(trigger)
				_expect(not area.is_walkable(trigger_center), "isolated closed %s entrance is outside walkable floor" % String(socket_id), failures)
				_expect(not _can_enter_socket_at_trigger(gameplay, player, trigger), "isolated closed %s entrance cannot transition rooms" % String(socket_id), failures)
			rooms.active_door_sockets.clear()
			rooms.active_entrance_sockets.clear()
			for socket_id in saved_door_socket_ids:
				rooms.active_door_sockets[socket_id] = rooms.dungeon_sockets.get(socket_id)
			for socket_id in saved_entrance_socket_ids:
				rooms.active_entrance_sockets[socket_id] = rooms.dungeon_sockets.get(socket_id)
			gameplay.call("_build_entrance_block_polygons")

			# Completing the room opens its authored side exits. The same trigger
			# polygons must then be represented by walkable portal regions.
			map.call("on_room_completed", TARGET_ROOM)
			gameplay.call("_on_dungeon_map_state_changed")
			area = gameplay.get("walkable_area") as WalkableArea
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
				_expect(_socket_has_walkable_portal(rooms, area, gameplay, socket), "opened %s doorway contributes a walkable portal" % String(socket_id), failures)
			_expect(open_side_count > 0, "normal combat room exposes at least one side doorway for the open-state check", failures)

			# The lower entrance is a diagonal floor edge, so a body-wide walkability
			# check can stop the player before the feet reach its open transition
			# trigger. Exercise the same axis movement used by gameplay to ensure an
			# available authored entrance remains reachable.
			var open_entrance := rooms.active_entrance_sockets.get(DungeonGraph.BOTTOM_RIGHT) as DungeonSocket
			var open_entrance_connection := graph.get_connection_for_entry(TARGET_ROOM, DungeonGraph.BOTTOM_RIGHT)
			if open_entrance != null and open_entrance_connection != null and bool(map.call("is_connection_available", open_entrance_connection, true)):
				var saved_open_player_position := player.position
				player.position = Vector2(167, 81)
				var entered_open_entrance := false
				for _step in 12:
					gameplay.call("_try_move_actor_axes", player, Vector2(0.0, 0.5))
					if StringName(gameplay.get("current_room_id")) != TARGET_ROOM:
						entered_open_entrance = true
						break
				_expect(entered_open_entrance, "open lower entrance remains reachable by normal movement", failures)
				player.position = saved_open_player_position
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


func _socket_has_walkable_portal(rooms: RoomController, area: WalkableArea, gameplay: Node, socket: DungeonSocket) -> bool:
	if area == null or socket == null:
		return false
	var expected := rooms.call("_socket_portal_polygons", gameplay, socket) as Array
	for polygon_value in expected:
		var polygon := polygon_value as PackedVector2Array
		if _contains_polygon(area.portal_regions, polygon):
			return true
	return false


func _can_enter_socket_at_trigger(gameplay: Node, player: Sprite2D, trigger: PackedVector2Array) -> bool:
	if player == null or trigger.size() < 3:
		return false
	var saved_position := player.global_position
	player.global_position = _polygon_center(trigger) - gameplay.get("ACTOR_FOOT_OFFSET")
	var entered := bool(gameplay.call("_try_enter_any_active_socket"))
	player.global_position = saved_position
	return entered


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
