extends SceneTree

const ACTIVE_RUN_SNAPSHOT_SCRIPT = preload("res://scripts/active_run_snapshot.gd")


func _initialize() -> void:
	var failures: Array[String] = []
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
	map_state.reveal_events[&"event_one"] = true
	var snapshot := {
		"format": ACTIVE_RUN_SNAPSHOT_SCRIPT.FORMAT,
		"schema_version": ACTIVE_RUN_SNAPSHOT_SCRIPT.SCHEMA_VERSION,
		"profile_slot": 1,
		"profile_identity": {"player_name": "Tester", "profile_schema": 7, "has_started": true},
		"created_at": 123.0,
		"run_state": run.to_dictionary(),
		"dungeon_seed": 424242,
		"run_rank": 2,
		"current_room_id": "room_start",
		"current_room_type": "combat",
		"current_room_depth": 1,
		"arrival_socket_id": "left",
		"room_states": {"room_start": {"finished": true, "world_item_drops": [{"position": Vector2(12, 24)}]}},
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
		_expect(ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(decoded, 1), "valid snapshot passes schema and slot validation", failures)
		var restored_run := RunState.new()
		_expect(restored_run.restore_from_dictionary(decoded["run_state"] as Dictionary), "run state restores from snapshot data", failures)
		_expect(restored_run.run_id == run.run_id and restored_run.shop_stock.size() == 1 and restored_run.gear_reward_telemetry.size() == 1, "run identity, shop state, and telemetry round-trip", failures)
		_expect(restored_run.map_discovered_rooms.has(&"room_start") and restored_run.completed_run_rooms.has(&"room_start") and restored_run.style_actions.has(&"block"), "StringName keyed run metrics remain queryable after JSON", failures)
		var restored_map := DungeonMapState.new()
		_expect(restored_map.restore_from_dictionary(decoded["map_state"] as Dictionary), "map state restores from snapshot data", failures)
		_expect(restored_map.is_room_completed(&"room_start") and restored_map.is_event_revealed(&"event_one"), "map completion and event discovery round-trip", failures)
		var malformed_room := decoded.duplicate(true)
		(malformed_room["room_states"] as Dictionary)["room_next"] = "not a dictionary"
		_expect(not ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(malformed_room, 1), "malformed room state is rejected", failures)
		var future := decoded.duplicate(true)
		future["schema_version"] = ACTIVE_RUN_SNAPSHOT_SCRIPT.SCHEMA_VERSION + 1
		_expect(not ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(future, 1), "future snapshot schema is rejected", failures)
		var wrong_slot := decoded.duplicate(true)
		_expect(not ACTIVE_RUN_SNAPSHOT_SCRIPT.validate(wrong_slot, 0), "snapshot cannot cross profile slots", failures)
	_finish(failures)


func _gear_fixture() -> ItemInstance:
	var item := ItemInstance.new()
	item.definition_id = &"basic_sword"
	item.rarity = &"common"
	item.quality = 1.0
	return item


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ACTIVE_RUN_RECOVERY_CONTRACT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
