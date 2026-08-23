extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/boss_room_debug.tscn") as PackedScene
	_expect(packed != null, "boss debug scene loads", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 90:
		await process_frame
	var slimes := gameplay.get("slimes") as Array[Sprite2D]
	var boss: Sprite2D = null
	for slime in slimes:
		if float(slime.get_meta("encounter_scale", 1.0)) > 1.0:
			boss = slime
			break
	_expect(boss != null, "boss room creates a scaled boss", failures)
	if boss != null:
		_expect(not bool(gameplay.get("debug_actor_geometry")), "boss scene keeps geometry debug opt-in", failures)
		var debug_player := gameplay.get("player") as Sprite2D
		var debug_rooms := gameplay.get("room_controller") as RoomController
		var debug_spawn := Vector2.INF
		if debug_rooms != null:
			for socket_value in debug_rooms.active_entrance_sockets.values():
				var marker := (socket_value as DungeonSocket).spawn_marker()
				if marker != null:
					debug_spawn = marker.global_position
					break
		_expect(debug_player != null and debug_spawn != Vector2.INF and debug_player.global_position.is_equal_approx(debug_spawn), "boss debug player starts at its authored arrival socket", failures)
		_expect(debug_player != null and debug_player.position.is_equal_approx(gameplay.get("player_start_position")), "boss debug start position is reusable for room reset", failures)
		var boss_door_left := gameplay.get_node_or_null("Map/Walls/DoorLeft") as Sprite2D
		var boss_door_right := gameplay.get_node_or_null("Map/Walls/DoorRight") as Sprite2D
		_expect(boss_door_left != null and boss_door_left.position.is_equal_approx(Vector2(58, 55)), "boss left wall door keeps authored placement", failures)
		_expect(boss_door_right != null and boss_door_right.position.is_equal_approx(Vector2(169, 56)), "boss right wall door keeps authored placement", failures)
		_expect(boss_door_left != null and not boss_door_left.visible and boss_door_right != null and not boss_door_right.visible, "boss starts without stray wall doors", failures)
		var visible_socket_count := 0
		if debug_rooms != null:
			for socket_value in debug_rooms.dungeon_sockets.values():
				var socket_visual := (socket_value as DungeonSocket).visual() as CanvasItem
				if socket_visual != null and socket_visual.visible:
					visible_socket_count += 1
		_expect(visible_socket_count == 1, "boss starts with only its arrival entrance visible", failures)
		for node_name in [&"CollisionGuide", &"CollisionPolygon", &"BodyHitbox", &"AttackGuideL", &"AttackGuideR"]:
			var guide := boss.get_node_or_null(NodePath(node_name)) as CanvasItem
			_expect(guide == null or not guide.visible, "boss runtime hides %s" % String(node_name), failures)
		var sprite_rect: Rect2 = gameplay.call("_sprite_source_global_rect", boss)
		var collision_rect: Rect2 = gameplay.call("_collision_rect", boss)
		var body := gameplay.call("_slime_body_polygon", boss) as PackedVector2Array
		var body_rect := _bounds(body)
		var foot_polygon := gameplay.call("_slime_collision_polygon", boss) as PackedVector2Array
		var foot_rect := _bounds(foot_polygon)
		_expect(sprite_rect.intersects(body_rect), "boss body overlaps rendered sprite", failures)
		_expect(sprite_rect.encloses(collision_rect), "boss collision guide stays inside rendered sprite", failures)
		_expect(collision_rect.position.is_equal_approx(body_rect.position) and collision_rect.size.is_equal_approx(body_rect.size), "boss runtime collision rect matches authored body", failures)
		_expect(foot_polygon.size() >= 3 and sprite_rect.encloses(foot_rect), "boss foot polygon stays on the rendered artwork", failures)
		_expect(foot_rect.position.x >= body_rect.position.x - 0.1 and foot_rect.end.x <= body_rect.end.x + 0.1 and absf(foot_rect.end.y - body_rect.end.y) < 0.1, "boss foot polygon is anchored to the body bottom", failures)
		var foot_node := boss.get_node_or_null("CollisionPolygon") as Node2D
		_expect(foot_node != null and foot_node.scale.is_equal_approx(Vector2.ONE), "boss foot polygon inherits the enlarged actor transform", failures)
		var body_node := boss.get_node_or_null("BodyHitbox") as Node2D
		_expect(body_node != null and body_node.position.is_equal_approx(boss.offset), "boss body node receives the same visual offset as its sprite", failures)
		var combat_target: Vector2 = gameplay.call("_magic_target_point", boss)
		_expect(Geometry2D.is_point_in_polygon(combat_target, body), "boss combat target stays inside authored body", failures)
		var player := gameplay.get("player") as Sprite2D
		var collision_system := gameplay.get("actor_collision_system") as ActorCollisionSystem
		if player != null and collision_system != null:
			var player_rect := gameplay.call("_collision_rect", player) as Rect2
			var below_center := Vector2(body_rect.get_center().x, body_rect.end.y + player_rect.size.y * 0.5 + 1.0)
			player.global_position += below_center - player_rect.get_center()
			_expect(collision_system.overlap_push_vector(gameplay, boss, player) == Vector2.ZERO, "boss has no contact wall below authored body", failures)
			player_rect = gameplay.call("_collision_rect", player) as Rect2
			player.global_position += body_rect.get_center() - player_rect.get_center()
			_expect(collision_system.overlap_push_vector(gameplay, boss, player) != Vector2.ZERO, "boss contact begins inside authored body", failures)
			player_rect = gameplay.call("_collision_rect", player) as Rect2
			var vertical_target_center := Vector2(ActorGeometry.polygon_center(body).x, body_rect.end.y + player_rect.size.y * 0.5 + 8.0)
			player.global_position += vertical_target_center - player_rect.get_center()
			var vertical_lunge := gameplay.call("_slime_attack_lunge_vector", boss) as Vector2
			_expect(absf(vertical_lunge.y) > 4.0, "boss attack lunges substantially toward a vertical target", failures)
			_expect(absf(vertical_lunge.x) < 0.1, "vertical boss attack does not drift horizontally", failures)
			var lunged_body := PackedVector2Array()
			for point in body:
				lunged_body.append(point + vertical_lunge)
			player_rect = gameplay.call("_collision_rect", player) as Rect2
			var player_body := PackedVector2Array([player_rect.position, Vector2(player_rect.end.x, player_rect.position.y), player_rect.end, Vector2(player_rect.position.x, player_rect.end.y)])
			_expect(not Geometry2D.intersect_polygons(lunged_body, player_body).is_empty(), "vertical boss lunge reaches the player body", failures)
		var regular_slime: Sprite2D = null
		for slime in slimes:
			if slime != boss and float(slime.get_meta("encounter_scale", 1.0)) <= 1.0:
				regular_slime = slime
				break
		_expect(regular_slime != null, "boss room includes a regular slime for displacement checks", failures)
		if regular_slime != null and collision_system != null:
			var boss_start := boss.position
			regular_slime.global_position = body_rect.get_center()
			var regular_start := regular_slime.position
			collision_system.resolve_slime_contacts([boss, regular_slime], gameplay, 1)
			_expect(boss.position.is_equal_approx(boss_start), "regular slime cannot displace the boss", failures)
			_expect(not regular_slime.position.is_equal_approx(regular_start), "boss pushes an overlapping regular slime aside", failures)
		var graph := gameplay.get("dungeon_graph") as DungeonGraph
		var map := gameplay.get("dungeon_map_controller") as Node
		var rooms := gameplay.get("room_controller") as RoomController
		var boss_room_id: StringName = gameplay.get("current_room_id")
		var boss_entry_socket: DungeonSocket = null
		var boss_entry_connection: DungeonGraph.ConnectionRecord = null
		for socket_value in rooms.active_entrance_sockets.values():
			var candidate_socket := socket_value as DungeonSocket
			var candidate_connection := graph.get_connection_for_entry(boss_room_id, candidate_socket.socket_id())
			if candidate_connection != null:
				boss_entry_socket = candidate_socket
				boss_entry_connection = candidate_connection
				break
		_expect(boss_entry_socket != null and boss_entry_connection != null, "boss room keeps its dungeon arrival connection", failures)
		_expect(not bool(gameplay.get("entrance_open")), "boss arrival entrance is sealed during the fight", failures)
		if boss_entry_socket != null:
			var closed_entrance := boss_entry_socket.visual() as Sprite2D
			_expect(closed_entrance != null and closed_entrance.texture != null and closed_entrance.texture.resource_path.ends_with("DoorRightenemyshut.png"), "boss arrival entrance uses closed dark doorway art", failures)
		if boss_entry_connection != null:
			# The debug scene starts inside the boss room, so establish the same
			# completed approach room that a real run has before testing the reverse
			# route. Authored and generated layouts may use different puzzle keys for
			# this connection; resolve the connection's own requirement instead of
			# assuming the Run 1 starter key.
			var map_state := map.get("state") as DungeonMapState
			if map_state != null:
				var required_color := boss_entry_connection.color_requirement
				map_state.set_puzzle_color(required_color if not required_color.is_empty() else &"puzzle_a")
			map.call("on_room_completed", boss_entry_connection.source_room_id)
			_expect(bool(gameplay.call("_map_connection_available", boss_entry_connection, true)), "completed boss approach exposes a return connection", failures)
		gameplay.call("_on_room_enemies_cleared")
		_expect(bool(gameplay.get("final_exit_open")), "boss victory opens the run-completion exit", failures)
		_expect(bool(gameplay.get("entrance_open")), "boss victory reopens the dungeon arrival entrance", failures)
		_expect(boss_door_right != null and boss_door_right.visible and boss_door_left != null and not boss_door_left.visible, "boss victory exposes only the authored final exit", failures)
		if boss_entry_socket != null:
			var open_entrance := boss_entry_socket.visual() as Sprite2D
			_expect(open_entrance != null and open_entrance.texture != null and open_entrance.texture.resource_path.ends_with("Tile.png"), "boss arrival entrance restores its open walkway art", failures)
		if boss_entry_socket != null and boss_entry_connection != null:
			var trigger := boss_entry_socket.trigger()
			var trigger_center := Vector2.ZERO
			for point in trigger.polygon:
				trigger_center += trigger.to_global(point)
			trigger_center /= float(trigger.polygon.size())
			var door_player := gameplay.get("player") as Sprite2D
			door_player.global_position += trigger_center - (gameplay.call("_actor_foot", door_player) as Vector2)
			gameplay.set("room_transition_locked", false)
			_expect(bool(gameplay.call("_try_enter_any_active_socket")), "boss room can traverse the reopened arrival entrance", failures)
			_expect(gameplay.get("current_room_id") == boss_entry_connection.source_room_id, "boss return route lands in the dungeon approach room", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _bounds(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var result := Rect2(points[0], Vector2.ZERO)
	for point in points:
		result = result.expand(point)
	return result


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("BOSS_GEOMETRY_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
