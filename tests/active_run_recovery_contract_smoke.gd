extends SceneTree

const ACTIVE_RUN_SNAPSHOT_SCRIPT = preload("res://scripts/content/active_run_snapshot.gd")
const ACTIVE_RUN_SNAPSHOT_CONTEXT_SCRIPT = preload("res://scripts/content/active_run_snapshot_context.gd")
const ACTIVE_RUN_SAVE_SERVICE_SCRIPT = preload("res://scripts/runtime/services/active_run_save_service.gd")
const ROOM_CHECKPOINT_CONTEXT_SCRIPT = preload("res://scripts/runtime/contexts/room_checkpoint_context.gd")
const RUN_CHECKPOINT_CONTEXT_SCRIPT = preload("res://scripts/runtime/contexts/run_checkpoint_context.gd")
const RUN_CHECKPOINT_RESULT_SCRIPT = preload("res://scripts/runtime/contexts/run_checkpoint_result.gd")
const RUN_CHECKPOINT_SERVICE_SCRIPT = preload("res://scripts/runtime/services/run_checkpoint_service.gd")
var _original_project_name := ""
var _isolated_user_data_path := ""


func _initialize() -> void:
	var failures: Array[String] = []
	_original_project_name = str(ProjectSettings.get_setting("application/config/name", "TinyDemons"))
	ProjectSettings.set_setting("application/config/name", "TinyDemonsP1RecoveryContract")
	_isolated_user_data_path = ProjectSettings.globalize_path("user://")
	if not DirAccess.dir_exists_absolute(_isolated_user_data_path):
		_expect(DirAccess.make_dir_recursive_absolute(_isolated_user_data_path) == OK, "isolated user data directory can be created", failures)
	var mcp_runtime := root.get_node_or_null("MCPRuntimeServer")
	if mcp_runtime != null:
		root.remove_child(mcp_runtime)
		mcp_runtime.free()
	var profile_slot := ProfileSaveService.current_slot()
	var other_profile_slot := posmod(profile_slot + 1, ProfileSaveService.SLOT_COUNT)
	var isolated_storage_slot := _find_unused_storage_slot(profile_slot)
	_expect(isolated_storage_slot >= 0, "an unused profile slot is available for isolated file-backed recovery", failures)
	var run := RunState.new()
	run.begin(424242, 3, 48.0)
	run.start_timer()
	run.elapsed_time = 91.5
	run.damage_taken = 7.0
	run.shop_stock = [{"item": {"definition_id": "basic_sword"}, "sold": false}]
	run.record_map_room_entry(&"room_start")
	run.record_room_completion(&"room_start")
	run.record_style_action(&"block")
	run.record_gear_reward(&"chest", _gear_fixture(), 2, 4, 80, "A", false, false, &"dropped")
	var map_state := DungeonMapState.new()
	map_state.begin(&"room_start")
	map_state.mark_room_discovered(&"room_next")
	map_state.mark_room_completed(&"room_start")
	map_state.revealed_events[&"event_one"] = true
	var map_controller := DungeonMapController.new()
	map_controller.state = map_state
	map_controller.layout_bound_flame = &"water"
	var room_controller := RoomController.new()
	room_controller.arrival_socket_id = &"left"
	room_controller.room_states = {&"room_start": {"finished": true}}
	var profile := PlayerProfile.new()
	profile.has_started = true
	var health := HealthComponent.new()
	var chroma := PlayerChromaComponent.new()
	var typed_context := ACTIVE_RUN_SNAPSHOT_CONTEXT_SCRIPT.new(profile, run, map_controller, room_controller, health, chroma, 424242, &"room_next", &"combat", 1, 0, true, true)
	var typed_snapshot := ACTIVE_RUN_SNAPSHOT_SCRIPT.create(typed_context)
	_expect(ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(typed_snapshot, profile_slot), "typed checkpoint context produces a valid recovery snapshot", failures)
	var no_drops: Array[Dictionary] = []
	var room_context := ROOM_CHECKPOINT_CONTEXT_SCRIPT.new(&"room_next", &"combat", null, room_controller, false, false, false, false, no_drops, null, null)
	var checkpoint_context := RUN_CHECKPOINT_CONTEXT_SCRIPT.new(profile, run, room_context, typed_context, 0)
	_expect(checkpoint_context.is_valid(), "typed safe-checkpoint context exposes durable dependencies", failures)
	var unavailable_checkpoint := RUN_CHECKPOINT_SERVICE_SCRIPT.save_safe_state(checkpoint_context)
	_expect(unavailable_checkpoint.status == RUN_CHECKPOINT_RESULT_SCRIPT.Status.NOT_AVAILABLE, "desktop checkpoint service reports web-only persistence without mutating state", failures)
	var snapshot := {
		"format": ACTIVE_RUN_SNAPSHOT_SCRIPT.FORMAT,
		"schema_version": ACTIVE_RUN_SNAPSHOT_SCRIPT.SCHEMA_VERSION,
		"profile_slot": profile_slot,
		"profile_identity": {"player_name": "Tester", "profile_schema": 7, "has_started": true},
		"created_at": 123.0,
		"run_state": run.to_dictionary(),
		"dungeon_seed": 424242,
		"layout_bound_flame": "water",
		"run_rank": 2,
		"current_room_id": "room_next",
		"current_room_type": "combat",
		"current_room_depth": 1,
		"arrival_socket_id": "left",
		"room_states": {
			"room_start": {
				"finished": true,
				"enemy_variants": ["grey", "skeleton"],
				"enemy_runtime": {
					"0": {"alive": true, "position": Vector2(12, 24), "health": 3.5},
					"1": {"alive": false, "position": Vector2(22, 34), "health": 0.0},
				},
				"world_item_drops": [{"position": Vector2(12, 24)}],
			}
		},
		"map_state": map_state.to_dictionary(),
		"player_health": 41.0,
		"player_chroma_state": {"current_aspect": 1, "current_chroma": 60, "bound_aspect": 1},
		"player_facing_left": true,
		"starter_flame_attuned_this_run": true,
	}
	var parsed: Variant = JSON.parse_string(JSON.stringify(ACTIVE_RUN_SNAPSHOT_SCRIPT.normalize(snapshot)))
	_expect(parsed is Dictionary, "active-run snapshot survives JSON encoding", failures)
	if parsed is Dictionary:
		var decoded := parsed as Dictionary
		_expect(ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(decoded, profile_slot), "valid snapshot passes schema and slot validation", failures)
		_expect(String(decoded.get("layout_bound_flame", "")) == "water", "active-run recovery preserves the generated layout origin", failures)
		var restored_run := RunState.new()
		_expect(restored_run.restore_from_dictionary(decoded["run_state"] as Dictionary), "run state restores from snapshot data", failures)
		_expect(restored_run.run_id == run.run_id and restored_run.shop_stock.size() == 1 and restored_run.gear_reward_telemetry.size() == 1, "run identity, shop state, and telemetry round-trip", failures)
		_expect(restored_run.map_discovered_rooms.has(&"room_start") and restored_run.completed_run_rooms.has(&"room_start") and restored_run.style_actions.has(&"block"), "StringName keyed run metrics remain queryable after JSON", failures)
		var restored_map := DungeonMapState.new()
		_expect(restored_map.restore_from_dictionary(decoded["map_state"] as Dictionary), "map state restores from snapshot data", failures)
		_expect(restored_map.is_room_completed(&"room_start") and restored_map.is_event_revealed(&"event_one"), "map completion and event discovery round-trip", failures)
		var malformed_room := decoded.duplicate(true)
		(malformed_room["room_states"] as Dictionary)["room_next"] = "not a dictionary"
		_expect(not ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(malformed_room, profile_slot), "malformed room state is rejected", failures)
		var future := decoded.duplicate(true)
		future["schema_version"] = ACTIVE_RUN_SNAPSHOT_SCRIPT.SCHEMA_VERSION + 1
		_expect(not ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(future, profile_slot), "future snapshot schema is rejected", failures)
		var wrong_slot := decoded.duplicate(true)
		_expect(not ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(wrong_slot, other_profile_slot), "snapshot cannot cross profile slots", failures)
		var disk_snapshot := decoded.duplicate(true)
		disk_snapshot["profile_slot"] = isolated_storage_slot
		disk_snapshot["created_at"] = 124.0
		if isolated_storage_slot >= 0:
			_expect(ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(disk_snapshot, isolated_storage_slot), "disk fixture remains valid after binding to an isolated profile slot", failures)
		var storage_probe_path := "user://tiny_demons_p1_storage_probe.tmp"
		var storage_probe := FileAccess.open(storage_probe_path, FileAccess.WRITE)
		_expect(storage_probe != null, "Godot user:// accepts file writes in this smoke environment", failures)
		if storage_probe != null:
			storage_probe.store_string("p1")
			storage_probe.close()
			DirAccess.remove_absolute(ProjectSettings.globalize_path(storage_probe_path))
		print("ACTIVE_RUN_USER_DATA_PATH %s" % ProjectSettings.globalize_path("user://"))
		var disk_loaded: Dictionary = {}
		if isolated_storage_slot >= 0:
			var disk_save_ok: bool = ACTIVE_RUN_SAVE_SERVICE_SCRIPT.save_snapshot(disk_snapshot, isolated_storage_slot)
			_expect(disk_save_ok, "validated active-run snapshot writes through the file-backed save service", failures)
			disk_loaded = ACTIVE_RUN_SAVE_SERVICE_SCRIPT.load_snapshot(isolated_storage_slot)
			_expect(not disk_loaded.is_empty() and ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(disk_loaded, isolated_storage_slot), "active-run file loads and remains bound to its profile slot", failures)
		if not disk_loaded.is_empty():
			var restored_room_states: Dictionary = ACTIVE_RUN_SNAPSHOT_SCRIPT.room_states_from_snapshot(disk_loaded.get("room_states", {}))
			var restored_room: Dictionary = restored_room_states.get(&"room_start", {}) as Dictionary
			var restored_variants: Array = restored_room.get("enemy_variants", []) as Array
			var restored_enemy_runtime: Dictionary = restored_room.get("enemy_runtime", {}) as Dictionary
			var restored_slot_zero: Dictionary = restored_enemy_runtime.get("0", {}) as Dictionary
			var restored_slot_one: Dictionary = restored_enemy_runtime.get("1", {}) as Dictionary
			var restored_position: Variant = restored_slot_zero.get("position")
			_expect(restored_variants == ["grey", "skeleton"], "file-backed room restore keeps enemy variant IDs in stable slot order", failures)
			_expect(bool(restored_slot_zero.get("alive", false)) and is_equal_approx(float(restored_slot_zero.get("health", 0.0)), 3.5) and restored_position is Vector2 and restored_position == Vector2(12, 24), "file-backed room restore denormalizes alive state, health, and position for slot zero", failures)
			_expect(not bool(restored_slot_one.get("alive", true)) and is_equal_approx(float(restored_slot_one.get("health", -1.0)), 0.0), "file-backed room restore preserves the defeated second slot", failures)
			var restored_drops: Array = restored_room.get("world_item_drops", []) as Array
			var restored_drop: Dictionary = restored_drops[0] as Dictionary if not restored_drops.is_empty() else {}
			var restored_drop_position: Variant = restored_drop.get("position")
			_expect(restored_drop_position is Vector2 and restored_drop_position == Vector2(12, 24), "file-backed room restore denormalizes world-drop position", failures)
		if isolated_storage_slot >= 0:
			ACTIVE_RUN_SAVE_SERVICE_SCRIPT.clear_snapshot(isolated_storage_slot)
	map_controller.free()
	room_controller.free()
	health.free()
	chroma.free()
	await _verify_live_file_restore(isolated_storage_slot, failures)
	_finish(failures)


func _gear_fixture() -> ItemInstance:
	var item := ItemInstance.new()
	item.definition_id = &"basic_sword"
	item.rarity = &"common"
	item.quality = 1.0
	return item


func _find_unused_storage_slot(current_slot: int) -> int:
	for slot in range(ProfileSaveService.SLOT_COUNT):
		if slot == current_slot:
			continue
		var profile_paths: Array[String] = [
			ProfileSaveService._save_path(slot),
			ProfileSaveService._backup_path(slot),
			ProfileSaveService._temp_path(slot),
		]
		var active_run_paths: Array[String] = [
			"user://tiny_demons_active_run_%d.json" % slot,
			"user://tiny_demons_active_run_backup_%d.json" % slot,
			"user://tiny_demons_active_run_tmp_%d.json" % slot,
		]
		var occupied := false
		for path in profile_paths + active_run_paths:
			if FileAccess.file_exists(path):
				occupied = true
				break
		if not occupied and not ProfileSaveService.slot_has_profile(slot):
			return slot
	return -1


func _verify_live_file_restore(storage_slot: int, failures: Array[String]) -> void:
	if storage_slot < 0:
		return
	var gameplay_scene := load("res://scenes/main.tscn") as PackedScene
	_expect(gameplay_scene != null, "main gameplay scene is available for the live recovery proof", failures)
	if gameplay_scene == null:
		return
	var original_slot := ProfileSaveService.current_slot()
	ProfileSaveService.active_slot = storage_slot
	ACTIVE_RUN_SAVE_SERVICE_SCRIPT.clear_snapshot(storage_slot)
	var profile := PlayerProfile.new()
	profile.player_name = "P1 Runtime Recovery"
	profile.has_started = true
	var profile_saved: bool = ProfileSaveService.save_profile(profile)
	_expect(profile_saved, "isolated profile fixture saves to its file-backed slot", failures)
	if not profile_saved:
		ProfileSaveService.clear_slot(storage_slot)
		ProfileSaveService.active_slot = original_slot
		return
	var gameplay := gameplay_scene.instantiate() as GameplayState
	_expect(gameplay != null, "main scene instantiates as GameplayState", failures)
	if gameplay == null:
		ProfileSaveService.clear_slot(storage_slot)
		ProfileSaveService.active_slot = original_slot
		return
	gameplay.debug_start_in_boss_room = true
	root.add_child(gameplay)
	var boot_ready := false
	for frame in range(900):
		await process_frame
		if not gameplay.boot_active and gameplay.run_flow_controller != null and gameplay.room_controller != null and gameplay.dungeon_graph != null:
			boot_ready = true
			break
	_expect(boot_ready, "full gameplay bootstrap completes for active-run recovery", failures)
	if boot_ready:
		_expect(gameplay.player_profile != null and gameplay.player_profile.player_name == PlayerProfile.normalize_player_name("P1 Runtime Recovery") and gameplay.player_profile.has_started, "GameplayBootstrap loads the isolated profile from disk", failures)
		var room_state: Dictionary = gameplay.room_controller.room_states.get(gameplay.current_room_id, {}) as Dictionary
		var variants: Array = room_state.get("enemy_variants", []) as Array
		_expect(not variants.is_empty() and not gameplay.slimes.is_empty(), "debug room has ordered enemy slots to checkpoint", failures)
		if not variants.is_empty() and not gameplay.slimes.is_empty():
			var enemy := gameplay.slimes[0]
			var enemy_health := enemy.get_node_or_null("Health") as HealthComponent
			_expect(enemy_health != null, "first restored room slot exposes its health component", failures)
			if enemy_health != null:
				var expected_health := maxf(1.0, enemy_health.maximum_health * 0.5)
				var expected_position := enemy.global_position + Vector2(1.0, 0.0)
				enemy_health.reset(expected_health)
				enemy.global_position = expected_position
				gameplay.room_controller.save_enemy_runtime_state_context(gameplay._room_enemy_runtime_context())
				var snapshot := ACTIVE_RUN_SNAPSHOT_SCRIPT.create(gameplay._active_run_snapshot_context())
				_expect(ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(snapshot, storage_slot), "live gameplay state produces a valid active-run snapshot", failures)
				if ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(snapshot, storage_slot):
					var expected_run_id := str((snapshot.get("run_state", {}) as Dictionary).get("run_id", ""))
					var expected_room_id := StringName(str(snapshot.get("current_room_id", "")))
					var expected_variants := (gameplay.room_controller.room_states.get(expected_room_id, {}) as Dictionary).get("enemy_variants", []) as Array
					var wrote_snapshot: bool = ACTIVE_RUN_SAVE_SERVICE_SCRIPT.save_snapshot(snapshot, storage_slot)
					var file_snapshot: Dictionary = ACTIVE_RUN_SAVE_SERVICE_SCRIPT.load_snapshot(storage_slot)
					_expect(wrote_snapshot and not file_snapshot.is_empty(), "live gameplay snapshot survives a file-backed save and reload", failures)
					var restored := not file_snapshot.is_empty() and bool(gameplay.run_flow_controller.call("restore_active_run", gameplay, file_snapshot))
					_expect(restored, "RunFlowController applies the file-backed snapshot to live gameplay", failures)
					if restored:
						_expect(gameplay.run_state.run_id == expected_run_id and gameplay.current_room_id == expected_room_id, "live restore rebinds run identity and current room", failures)
						var restored_state: Dictionary = gameplay.room_controller.room_states.get(expected_room_id, {}) as Dictionary
						_expect((restored_state.get("enemy_variants", []) as Array) == expected_variants, "live restore preserves enemy variant IDs in ordered room slots", failures)
						var restored_enemy := gameplay.slimes[0]
						var restored_health := restored_enemy.get_node_or_null("Health") as HealthComponent
						_expect(StringName(str(restored_enemy.get_meta("enemy_variant_id", ""))) == StringName(str(expected_variants[0])), "live restore assembles the saved family in slot zero", failures)
						_expect(restored_health != null and is_equal_approx(restored_health.current_health, expected_health), "live restore applies saved enemy health", failures)
						_expect(restored_enemy.global_position.distance_to(expected_position) < 0.1, "live restore applies saved enemy world position", failures)
						_expect(is_equal_approx(gameplay.player_health_component.current_health, float(file_snapshot.get("player_health", 0.0))), "live restore applies saved player health", failures)
	ACTIVE_RUN_SAVE_SERVICE_SCRIPT.clear_snapshot(storage_slot)
	ProfileSaveService.clear_slot(storage_slot)
	var settings_path := ProjectSettings.globalize_path("user://settings.cfg")
	if FileAccess.file_exists(settings_path):
		DirAccess.remove_absolute(settings_path)
	ProfileSaveService.active_slot = original_slot
	gameplay.queue_free()
	await process_frame


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if DirAccess.dir_exists_absolute(_isolated_user_data_path) and DirAccess.get_files_at(_isolated_user_data_path).is_empty() and DirAccess.get_directories_at(_isolated_user_data_path).is_empty():
		DirAccess.remove_absolute(_isolated_user_data_path)
	ProjectSettings.set_setting("application/config/name", _original_project_name)
	if failures.is_empty():
		print("ACTIVE_RUN_RECOVERY_CONTRACT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
