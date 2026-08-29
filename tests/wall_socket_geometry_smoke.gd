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
			var left_trigger := rooms.call("_socket_trigger_polygon", left_socket) as PackedVector2Array
			var right_trigger := rooms.call("_socket_trigger_polygon", right_socket) as PackedVector2Array
			_expect(_contains_polygon(blocks, left_trigger), "closed left doorway seam is physically blocked", failures)
			_expect(_contains_polygon(blocks, right_trigger), "closed right doorway seam is physically blocked", failures)
			if left_trigger.size() >= 4:
				var left_walk_point := left_trigger[2].lerp(left_trigger[3], 0.5)
				_expect(not bool(gameplay.call("_is_walkable", left_walk_point)), "closed left doorway cannot be entered through its seam", failures)
			if right_trigger.size() >= 4:
				var right_walk_point := right_trigger[2].lerp(right_trigger[3], 0.5)
				_expect(not bool(gameplay.call("_is_walkable", right_walk_point)), "closed right doorway cannot be entered through its seam", failures)

			# Completing the room opens its authored side exits. The same trigger
			# polygons must then stop blocking the matching visible doorway.
			var open_side_count := 0
			for socket_id in [DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT]:
				if not rooms.active_door_sockets.has(socket_id):
					continue
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
				if trigger.size() < 4:
					continue
				open_side_count += 1
			map.call("on_room_completed", TARGET_ROOM)
			gameplay.call("_on_dungeon_map_state_changed")
			blocks = gameplay.get("entrance_block_polygons") as Array
			for socket_id in [DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT]:
				if not rooms.active_door_sockets.has(socket_id):
					continue
				var socket := rooms.dungeon_sockets.get(socket_id) as DungeonSocket
				var trigger := rooms.call("_socket_trigger_polygon", socket) as PackedVector2Array
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
