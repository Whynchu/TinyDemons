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
		gameplay.call("_sync_current_room_metadata")
		rooms.set_current_room(TARGET_ROOM, gameplay.get("current_room_type"))
		gameplay.call("_collect_dungeon_sockets")
		gameplay.call("_ensure_current_room_layout")
		gameplay.call("_apply_room_state")
		var state: Dictionary = rooms.room_states.get(TARGET_ROOM, {}) as Dictionary
		var expected_enemy_count := (state.get("enemy_variants", []) as Array).size()
		var visible_enemy_count := 0
		for slime in gameplay.get("slimes") as Array[Sprite2D]:
			if slime.visible:
				visible_enemy_count += 1
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
		var blocks_before: Array = gameplay.get("entrance_block_polygons") as Array
		var block_count_before := blocks_before.size()
		_expect(incoming != null and bool(map.call("is_connection_available", incoming, true)), "unengaged room entrance is traversable", failures)
		gameplay.call("_mark_current_room_engaged")
		var blocks_after: Array = gameplay.get("entrance_block_polygons") as Array
		_expect(incoming != null and not bool(map.call("is_connection_available", incoming, true)), "landed-hit engagement locks the room entrance", failures)
		_expect(blocks_after.size() > block_count_before, "engagement adds physical entrance blocking polygons", failures)
		map.call("on_room_completed", TARGET_ROOM)
		var blocks_cleared: Array = gameplay.get("entrance_block_polygons") as Array
		_expect(incoming != null and bool(map.call("is_connection_available", incoming, true)), "clearing reopens the entrance", failures)
		_expect(blocks_cleared.size() == block_count_before, "clearing removes the engagement entrance block", failures)
	gameplay.queue_free()
	await process_frame
	var settings_absolute_path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(settings_absolute_path):
		DirAccess.remove_absolute(settings_absolute_path)
	_finish(failures)


func active_variants_size(state: Dictionary) -> int:
	return (state.get("enemy_variants", []) as Array).size()


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
