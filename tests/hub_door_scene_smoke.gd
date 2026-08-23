extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for generated hub door coverage", failures)
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
	var profile := gameplay.get("player_profile") as PlayerProfile
	_expect(graph != null and map != null and rooms != null and profile != null, "hub door owners are composed", failures)
	if graph != null and map != null and rooms != null and profile != null:
		profile.set("completed_runs", 1)
		profile.set("starter_flame", &"water")
		profile.set("has_started", true)
		gameplay.set("starter_flame_attuned_this_run", false)
		gameplay.call("_begin_new_run")
		_expect(bool(map.call("is_authored_run2")), "R2 hub uses the promoted authored map path", failures)
		_expect(gameplay.get("current_room_type") == GRAPH_SCRIPT.ROOM_START, "R2 begins in the generated hub room", failures)
		_expect(not bool(gameplay.get("starter_flame_attuned_this_run")), "R2 begins with its starter flame gate closed", failures)
		var closed_door_count := 0
		for socket_value in rooms.active_door_sockets.values():
			var socket := socket_value as DungeonSocket
			var visual := socket.visual() as Sprite2D
			var connection := graph.get_connection(graph.start_room_id, socket.socket_id())
			if visual != null and visual.texture != null and visual.texture.resource_path.ends_with("DoorRightFlameshut.png") and not bool(gameplay.call("_map_connection_available", connection, false)):
				closed_door_count += 1
		_expect(closed_door_count == rooms.active_door_sockets.size() and closed_door_count > 0, "R2 hub exits remain visually and logically gated before attunement", failures)
		var player := gameplay.get("player") as Sprite2D
		player.global_position += (gameplay.call("_fire_anchor") as Vector2) - (gameplay.call("_actor_foot", player) as Vector2)
		_expect(bool(gameplay.call("_can_interact_with_fire")), "R2 hub fire can unlock the starter gate", failures)
		gameplay.call("_interact_with_fire")
		_expect(bool(gameplay.get("starter_flame_attuned_this_run")), "R2 records starter flame attunement", failures)
		var open_door_count := 0
		for socket_value in rooms.active_door_sockets.values():
			var socket := socket_value as DungeonSocket
			var visual := socket.visual() as Sprite2D
			if visual != null and visual.texture != null and visual.texture.resource_path.ends_with("DoorRight.png"):
				open_door_count += 1
		_expect(open_door_count == rooms.active_door_sockets.size() and open_door_count > 0, "R2 hub exits open after starter attunement", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("HUB_DOOR_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
