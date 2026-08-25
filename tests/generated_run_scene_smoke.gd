extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for the generated Run 3 flow", failures)
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
	var minimap := gameplay.get("dungeon_minimap_controller") as Node
	_expect(graph != null and map != null and rooms != null and minimap != null, "generated-run owners are composed", failures)
	if graph != null and map != null and rooms != null and minimap != null:
		map.call("begin_run", graph, 182736, 2, &"water")
		rooms.room_states.clear()
		# This test starts after the hub-fire lesson; hub gate behavior is covered
		# separately by hub_door_scene_smoke.
		gameplay.set("starter_flame_attuned_this_run", true)
		map.call("set_starter_flame_attuned", true)
		var start_id: StringName = graph.start_room_id
		gameplay.set("current_room_id", start_id)
		gameplay.call("_sync_current_room_metadata")
		rooms.set_current_room(start_id, gameplay.get("current_room_type"))
		gameplay.call("_collect_dungeon_sockets")
		gameplay.call("_ensure_current_room_layout")
		gameplay.call("_apply_room_state")
		minimap.call("configure", map)
		var room_count_before := graph.get_room_ids().size()
		_expect(not bool(map.call("is_authored_layout")) and bool(map.call("has_complete_layout")), "Run 3 uses the generated complete-layout path after authored Run 2", failures)
		_expect(bool(minimap.get("visible")), "generated Run 3 displays its generated minimap", failures)
		var connection := graph.get_connection(start_id, GRAPH_SCRIPT.WALL_LEFT)
		var socket := rooms.dungeon_sockets.get(GRAPH_SCRIPT.WALL_LEFT) as DungeonSocket
		_expect(connection != null and socket != null, "generated start contains a prebuilt left fork", failures)
		if connection != null and socket != null:
			var trigger := socket.trigger()
			var trigger_center := Vector2.ZERO
			for point in trigger.polygon:
				trigger_center += trigger.to_global(point)
			trigger_center /= float(trigger.polygon.size())
			var player := gameplay.get("player") as Sprite2D
			var feet: Rect2 = gameplay.call("_collision_guide_rect_by_name", player, "DoorFeetGuide")
			player.global_position += trigger_center - feet.get_center()
			var entered := rooms.try_enter_active_socket(gameplay, bool(gameplay.get("door_active")), bool(gameplay.get("entrance_open")), false)
			_expect(entered, "generated start fork enters its prebuilt combat room", failures)
			_expect(StringName(gameplay.get("current_room_id")) == connection.destination_room_id, "generated transition reaches the graph destination", failures)
			_expect(graph.get_room_ids().size() == room_count_before, "generated transition does not add topology lazily", failures)
			var combat_state: Dictionary = rooms.room_states.get(connection.destination_room_id, {}) as Dictionary
			var expected_enemy_count := (combat_state.get("enemy_variants", []) as Array).size()
			var visible_enemy_count := 0
			for slime in gameplay.get("slimes") as Array[Sprite2D]:
				if slime.visible:
					visible_enemy_count += 1
			_expect(expected_enemy_count > 0 and visible_enemy_count == expected_enemy_count, "generated combat room spawns every generated enemy slot on entry", failures)
			var incoming := graph.get_connection_for_entry(connection.destination_room_id, connection.destination_entry)
			_expect(incoming != null and bool(map.call("is_connection_available", incoming, true)), "generated combat arrival remains open before engagement", failures)
			gameplay.call("_mark_current_room_engaged")
			_expect(incoming != null and not bool(map.call("is_connection_available", incoming, true)), "generated combat arrival locks after engagement", failures)

		# Run 3's alternate Fire Room must be a real palette source, not just a
		# decorative room declaration. Use a water starter so the generated fire
		# room exercises the first unchosen flame.
		var alternate_fire_room: DungeonGraph.RoomRecord = null
		for room_id in graph.get_room_ids():
			var candidate := graph.get_room(room_id)
			if candidate != null and candidate.room_type == GRAPH_SCRIPT.ROOM_FIRE and candidate.fire_flame == &"fire":
				alternate_fire_room = candidate
				break
		_expect(alternate_fire_room != null, "generated Run 3 exposes a declared alternate Fire Room", failures)
		if alternate_fire_room != null:
			rooms.room_states.clear()
			gameplay.set("current_room_id", alternate_fire_room.id)
			gameplay.set("run_start_palette_name", "blue")
			gameplay.set("current_player_palette_name", "grey")
			(gameplay.get("player_profile") as PlayerProfile).souls = 10
			(gameplay.get("screen_state_controller") as Node).set("player_palette_name", "grey")
			(gameplay.get("player_chroma_component") as Node).call("begin_new_run")
			gameplay.call("_sync_current_room_metadata")
			rooms.set_current_room(alternate_fire_room.id, gameplay.get("current_room_type"))
			gameplay.call("_collect_dungeon_sockets")
			gameplay.call("_ensure_current_room_layout")
			gameplay.call("_apply_room_state")
			_expect(String(gameplay.get("current_fire_palette_name")) == "red", "generated Fire Room renders its declared alternate flame", failures)
			_expect(String(gameplay.call("_fire_target_palette")) == "red", "generated alternate flame is an interactable palette source", failures)
			var alternate_player := gameplay.get("player") as Sprite2D
			var fire_anchor: Vector2 = gameplay.call("_fire_anchor") as Vector2
			alternate_player.global_position += fire_anchor - (gameplay.call("_actor_foot", alternate_player) as Vector2)
			_expect(bool(gameplay.call("_can_interact_with_fire")), "player can interact with the reachable alternate Fire Room", failures)
			gameplay.call("_interact_with_fire")
			_expect(String((gameplay.get("screen_state_controller") as Node).get("player_palette_name")) == "red", "alternate Fire Room swaps the player palette", failures)
			var chroma := gameplay.get("player_chroma_component") as Node
			_expect(String(chroma.call("aspect_name")) == "fire", "alternate Fire Room attunes the matching player aspect", failures)
	var screen_state := gameplay.get("screen_state_controller") as Node
	var run_flow := gameplay.get("run_flow_controller") as Node
	if screen_state != null and run_flow != null:
		run_flow.call("show_run_complete", gameplay, Color.WHITE)
		var completion_overlay := screen_state.get("run_complete_overlay") as ColorRect
		_expect(completion_overlay != null and completion_overlay.visible, "run completion overlay opens after the boss flow", failures)
		_expect(bool(screen_state.get("menu_input_release_lock")), "run completion waits for the exit input to be released", failures)
		gameplay.call("_update_run_complete_input")
		_expect(completion_overlay != null and completion_overlay.visible, "run completion overlay is not skipped by the entry input", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GENERATED_RUN_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
