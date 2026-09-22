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
	gameplay.set("debug_start_in_boss_room", true)
	root.add_child(gameplay)
	var boot_ready := false
	for _frame in 600:
		await process_frame
		var boot_slimes: Variant = gameplay.get("slimes")
		if not bool(gameplay.get("boot_active")) and boot_slimes is Array and (boot_slimes as Array).size() >= 13 and gameplay.get("chest_gray_texture") != null:
			boot_ready = true
			break
	_expect(boot_ready, "gameplay bootstrap materializes the factory enemy pool before room activation", failures)
	if not boot_ready:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return
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
		# Select a deterministic Run 1 seed whose rank-3 normal encounter
		# contains the newly authored guard_slime. This keeps the acceptance
		# proof independent of a lucky random draw while still exercising the
		# real map -> room -> activation -> factory configuration path.
		gameplay.player_profile.difficulty_rank = 3
		# This test enters the authored room directly instead of going through the
		# new-run flow, so preserve the starter-flame palette that the real flow
		# records before it resets the temporary player palette to Gray.
		gameplay.run_start_palette_name = "red"
		var guard_seed := _find_guard_run_seed(rooms)
		_expect(guard_seed >= 0, "rank-three normal encounters can select guard_slime", failures)
		if guard_seed < 0:
			gameplay.queue_free()
			await process_frame
			_finish(failures)
			return
		map.call("begin_run", graph, guard_seed, 0, &"fire")
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
		var active_slimes := gameplay.get("slimes") as Array[Sprite2D]
		var active_variants := state.get("enemy_variants", []) as Array
		var guard_index := active_variants.find("guard_slime")
		_expect(guard_index >= 0, "rank-three normal room state contains guard_slime", failures)
		for slime in active_slimes:
			_expect(slime.name.begins_with("EnemySlot"), "runtime enemy pool contains only factory-created EnemySlot actors", failures)
		_expect(not active_slimes.has(gameplay.get("slime_blue")) and not active_slimes.has(gameplay.get("slime_green")) and not active_slimes.has(gameplay.get("slime_red")), "scene-authored slime templates are not runtime roster slots", failures)
		if guard_index >= 0 and guard_index < active_slimes.size():
			var guard_actor := active_slimes[guard_index] as SlimeActor
			var guard_definition := EnemyFactory.definition(&"guard_slime")
			var guard_stats := guard_actor.get_node_or_null("Stats") as StatsComponent if guard_actor != null else null
			_expect(guard_actor != null and guard_actor.visible, "guard_slime is visible in the normal-room runtime pool", failures)
			_expect(guard_actor != null and guard_actor.variant == "guard_slime", "room activation configures the selected guard_slime identity", failures)
			_expect(guard_actor != null and String(guard_actor.get_meta("enemy_definition_id", "")) == "guard_slime", "room activation carries guard_slime's stable definition id", failures)
			_expect(guard_actor != null and bool(guard_actor.get_meta("content_materialized", false)), "room activation uses the factory materialization contract", failures)
			_expect(guard_definition != null and guard_stats != null and guard_stats.def >= int(guard_definition.base_stats.get("DEF", 0)) and guard_stats.vit >= int(guard_definition.base_stats.get("VIT", 0)), "room activation applies guard_slime's authored defensive stats", failures)
		var visible_enemy_count := 0
		for slime in active_slimes:
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
		_exercise_factory_enemy_hit(gameplay, active_slimes[0] if not active_slimes.is_empty() else null, failures)
	gameplay.queue_free()
	await process_frame
	var settings_absolute_path := ProjectSettings.globalize_path(TEST_SETTINGS_PATH)
	if FileAccess.file_exists(settings_absolute_path):
		DirAccess.remove_absolute(settings_absolute_path)
	_finish(failures)


func active_variants_size(state: Dictionary) -> int:
	return (state.get("enemy_variants", []) as Array).size()


func _find_guard_run_seed(rooms: RoomController) -> int:
	rooms.progression_run_rank = 3
	rooms.matchup_policy = "base_counter"
	rooms.preferred_enemy_variant = "blue"
	rooms.secondary_enemy_variant = "grey"
	rooms.encounter_definition = null
	for candidate in range(1, 4096):
		var room_seed := candidate ^ String(TARGET_ROOM).hash()
		var encounter := rooms._generate_enemy_encounter(room_seed, 1, false, true, DungeonGraph.ENCOUNTER_NORMAL)
		if (encounter.get("variants", []) as Array).has("guard_slime"):
			return candidate
	return -1


func _exercise_factory_enemy_hit(gameplay: Node, target: Sprite2D, failures: Array[String]) -> void:
	if target == null:
		_expect(false, "factory-created enemy pool exposes a sword-hit target", failures)
		return
	var player := gameplay.get("player") as Sprite2D
	var attack := gameplay.get("player_attack_component") as PlayerAttackComponent
	var health := target.get_node_or_null("Health") as HealthComponent
	var combat := target.get_node_or_null("Combat") as SlimeCombatComponent
	if player == null or attack == null or health == null or combat == null:
		_expect(false, "factory-created enemy exposes player-hit components", failures)
		return
	var original_player_position := player.global_position
	var original_player_flip := player.flip_h
	var original_target_position := target.global_position
	var original_visible := target.visible
	var original_health := health.current_health
	var hit_offset := Vector2.INF
	player.global_position = Vector2(120, 100)
	player.flip_h = false
	gameplay.set("player_attack_flip_h", false)
	target.visible = true
	target.cancel_spawn()
	combat.dead = false
	var foot_polygon := gameplay.call("_slime_collision_polygon", target) as PackedVector2Array
	var body_polygon := gameplay.call("_slime_body_polygon", target) as PackedVector2Array
	var foot_has_area := false
	for point in foot_polygon:
		if point.distance_squared_to(foot_polygon[0]) > 0.001:
			foot_has_area = true
			break
	var body_has_area := false
	for point in body_polygon:
		if point.distance_squared_to(body_polygon[0]) > 0.001:
			body_has_area = true
			break
	_expect(foot_polygon.size() >= 3 and foot_has_area, "factory-created enemy has a non-degenerate walkability polygon", failures)
	_expect(body_polygon.size() >= 3 and body_has_area, "factory-created enemy has a non-degenerate sword body polygon", failures)
	gameplay.set("player_anim_frame", 0)
	for offset_y in range(-12, 31):
		for offset_x in range(0, 46):
			target.global_position = player.global_position + Vector2(offset_x, offset_y)
			attack.begin(1, PlayerAttackComponent.AttackKind.ATTACK1)
			var candidate_attack := attack.attack_polygon(gameplay)
			var candidate_body := gameplay.call("_slime_body_polygon", target) as PackedVector2Array
			attack.finish()
			if candidate_attack.size() >= 3 and candidate_body.size() >= 3 and not Geometry2D.intersect_polygons(candidate_attack, candidate_body).is_empty():
				hit_offset = Vector2(offset_x, offset_y)
				break
		if hit_offset != Vector2.INF:
			break
	_expect(hit_offset != Vector2.INF, "factory-created enemy body polygon overlaps a real sword hitbox", failures)
	if hit_offset != Vector2.INF:
		target.global_position = player.global_position + hit_offset
		health.reset(original_health)
		attack.begin(1, PlayerAttackComponent.AttackKind.ATTACK1)
		attack.apply_hitbox(gameplay)
		_expect(health.current_health < original_health, "player sword damages a factory-created enemy", failures)
		attack.finish()
	player.global_position = original_player_position
	player.flip_h = original_player_flip
	target.global_position = original_target_position
	target.visible = original_visible
	health.reset(original_health)


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
