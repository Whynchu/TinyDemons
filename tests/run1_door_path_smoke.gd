extends SceneTree

const TARGET_ROOM: StringName = &"room_-1_9"
const BLUE_EXIT_ROOM: StringName = &"room_-2_10"
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for the authored doorway regression", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 120:
		await process_frame

	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	var map := gameplay.get("dungeon_map_controller") as Node
	var room_controller := gameplay.get("room_controller") as RoomController
	_expect(graph != null and map != null and room_controller != null, "Run 1 map and room owners are composed", failures)
	if graph == null or map == null or room_controller == null:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return

	map.call("begin_run", graph, 741852, 1, &"water")
	room_controller.room_states.clear()
	gameplay.set("current_room_id", TARGET_ROOM)
	gameplay.call("_sync_current_room_metadata")
	room_controller.set_current_room(TARGET_ROOM, gameplay.get("current_room_type"))
	gameplay.call("_collect_dungeon_sockets")
	gameplay.call("_ensure_current_room_layout")
	gameplay.call("_apply_room_state")
	map.get("state").set_puzzle_color(&"puzzle_a")
	gameplay.call("_on_room_enemies_cleared")

	var connection := graph.get_connection(TARGET_ROOM, GRAPH_SCRIPT.WALL_LEFT)
	_expect(connection != null, "second special room has an authored blue exit", failures)
	if connection != null:
		_expect(connection.color_requirement == &"puzzle_a", "the tested exit requires Puzzle Color A", failures)
		_expect(bool(map.call("is_connection_available", connection, false)), "blue exit is available in the blue orb state", failures)
	var blue_socket := room_controller.dungeon_sockets.get(GRAPH_SCRIPT.WALL_LEFT) as DungeonSocket
	var blue_visual := blue_socket.visual() as Sprite2D if blue_socket != null else null
	_expect(blue_visual != null and blue_visual.texture != null and blue_visual.texture.resource_path.ends_with("DoorRight.png"), "available blue exit shows open-door art", failures)
	_expect(not bool(gameplay.get("door_active")), "regression reproduces the legacy room-wide lock", failures)

	if blue_socket != null:
		var trigger := blue_socket.trigger()
		var trigger_center := Vector2.ZERO
		for point in trigger.polygon:
			trigger_center += trigger.to_global(point)
		trigger_center /= float(trigger.polygon.size())
		var player := gameplay.get("player") as Sprite2D
		var feet: Rect2 = gameplay.call("_collision_guide_rect_by_name", player, "DoorFeetGuide")
		player.global_position += trigger_center - feet.get_center()
		var entered := room_controller.try_enter_active_socket(gameplay, bool(gameplay.get("door_active")), bool(gameplay.get("entrance_open")), false)
		_expect(entered, "available authored exit is enterable even when room-wide door_active is false", failures)
		_expect(StringName(gameplay.get("current_room_id")) == BLUE_EXIT_ROOM, "blue exit enters the authored treasure room", failures)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN1_DOOR_PATH_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
