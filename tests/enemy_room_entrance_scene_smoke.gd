extends SceneTree

const TARGET_ROOM: StringName = &"room_1_1"
const ENTRY_SOCKET: StringName = &"BOTTOM_LEFT"
const TEST_SETTINGS_PATH := "res://.godot_user/enemy_room_entrance_scene_smoke.cfg"


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for enemy-room entrance locking", failures)
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
	var settings := gameplay.get("settings_service") as SettingsService
	_expect(graph != null and map != null and rooms != null and settings != null, "enemy-room lock owners are composed", failures)
	if graph != null and map != null and rooms != null and settings != null:
		settings.file_path = TEST_SETTINGS_PATH
		settings.reset_to_defaults()
		settings.set_setting(&"aspect", "16:9")
		await process_frame
		map.call("begin_run", graph, 99173, 0, &"fire")
		# Start directly in the enemy room after the hub-fire lesson; leave the
		# starter gate out of this entrance-lock regression.
		map.call("set_starter_flame_attuned", true)
		rooms.room_states.clear()
		gameplay.set("current_room_id", TARGET_ROOM)
		# Model the actual landing from the Hub so the map can record the
		# destination's BOTTOM_LEFT arrival seam. Directly setting the room without
		# an arrival socket leaves authored enemy-room exits intentionally closed.
		gameplay.call("_sync_current_room_metadata", ENTRY_SOCKET)
		rooms.set_current_room(TARGET_ROOM, gameplay.get("current_room_type"))
		gameplay.call("_collect_dungeon_sockets")
		gameplay.call("_ensure_current_room_layout")
		var activation := gameplay.call("_apply_room_state") as RoomActivationResult
		_expect(activation != null and activation.is_ready(), "enemy room activation returns a typed ready result", failures)
		var state: Dictionary = rooms.room_states.get(TARGET_ROOM, {}) as Dictionary
		var expected_enemy_count := (state.get("enemy_variants", []) as Array).size()
		var visible_enemy_count := 0
		for slime in gameplay.get("slimes") as Array[Sprite2D]:
			if slime.visible:
				visible_enemy_count += 1
		_expect(activation.configured_enemy_slots == expected_enemy_count, "typed activation reports the configured enemy slots", failures)
		_expect(activation.visible_enemy_slots == visible_enemy_count, "typed activation reports the visible enemy slots", failures)
		_expect(activation.spawn_result != null and activation.spawn_result.is_ready(), "typed activation includes a ready room spawn result", failures)
		if activation.spawn_result != null:
			_expect(activation.spawn_result.requested_slots == expected_enemy_count, "typed spawn result reports requested enemy slots", failures)
			_expect(activation.spawn_result.spawned_slots == visible_enemy_count and activation.spawn_result.failed_slots.is_empty(), "typed spawn result reports successful enemy slot placement", failures)
		_expect(expected_enemy_count > 0 and visible_enemy_count == expected_enemy_count, "R1 enemy room spawns every generated enemy slot on entry", failures)
		var spawn_positions := state.get("enemy_spawn_positions", {}) as Dictionary
		for slime_index in active_variants_size(state):
			var slime := (gameplay.get("slimes") as Array[Sprite2D])[slime_index]
			if not slime.visible:
				continue
			var saved_position: Vector2 = spawn_positions.get(slime_index, spawn_positions.get(str(slime_index), Vector2.INF))
			_expect(slime.global_position.distance_to(saved_position) < 0.01, "16:9 enemy spawn remains in world coordinates", failures)
			_expect(bool(gameplay.call("_is_slime_collision_rect_walkable_at", slime, gameplay.call("_actor_foot", slime))), "16:9 enemy spawn stays inside the walkable room", failures)
		var incoming := graph.get_connection_for_entry(TARGET_ROOM, ENTRY_SOCKET)
		var area := gameplay.get("walkable_area") as WalkableArea
		var entrance_socket := rooms.dungeon_sockets.get(ENTRY_SOCKET) as DungeonSocket
		var entrance_portal_before := _socket_has_walkable_portal(rooms, area, gameplay, entrance_socket)
		_expect(incoming != null and bool(map.call("is_connection_available", incoming, true)), "unengaged room entrance is traversable", failures)
		_expect(entrance_portal_before, "unengaged room entrance contributes a walkable portal", failures)
		gameplay.call("_mark_current_room_engaged")
		var entrance_portal_after_engagement := _socket_has_walkable_portal(rooms, area, gameplay, entrance_socket)
		_expect(incoming != null and not bool(map.call("is_connection_available", incoming, true)), "landed-hit engagement locks the room entrance", failures)
		_expect(not entrance_portal_after_engagement, "engagement removes the entrance walkable portal", failures)
		map.call("on_room_completed", TARGET_ROOM)
		var entrance_portal_after_clear := _socket_has_walkable_portal(rooms, area, gameplay, entrance_socket)
		_expect(incoming != null and bool(map.call("is_connection_available", incoming, true)), "clearing reopens the entrance", failures)
		_expect(entrance_portal_after_clear, "clearing restores the entrance walkable portal", failures)
	gameplay.queue_free()
	await process_frame
	var settings_absolute_path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(settings_absolute_path):
		DirAccess.remove_absolute(settings_absolute_path)
	_finish(failures)


func active_variants_size(state: Dictionary) -> int:
	return (state.get("enemy_variants", []) as Array).size()


func _socket_has_walkable_portal(rooms: RoomController, area: WalkableArea, gameplay: Node, socket: DungeonSocket) -> bool:
	if area == null or socket == null:
		return false
	var expected := rooms.call("_socket_portal_polygons", gameplay, socket) as Array
	for polygon_value in expected:
		var polygon := polygon_value as PackedVector2Array
		if polygon.size() != 0 and area.portal_regions.any(func(candidate: PackedVector2Array) -> bool: return candidate.size() == polygon.size() and _polygons_match(candidate, polygon)):
			return true
	return false


func _polygons_match(left: PackedVector2Array, right: PackedVector2Array) -> bool:
	for index in left.size():
		if not left[index].is_equal_approx(right[index]):
			return false
	return true


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENEMY_ROOM_ENTRANCE_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
