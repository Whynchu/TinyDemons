extends SceneTree

const ROOM_CONTROLLER_SCRIPT = preload("res://scripts/room_controller.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")


class FakeRoot extends Node:
	var current_room_type: StringName = &""
	var current_room_id: StringName = &""
	var player_profile = null
	var slimes: Array[Sprite2D] = []


func _initialize() -> void:
	var failures: Array[String] = []
	var controller := ROOM_CONTROLLER_SCRIPT.new()
	controller.player_level = 12
	var fake := FakeRoot.new()
	fake.slimes = [Sprite2D.new()]
	root.add_child(fake)

	var eligible_types: Array[StringName] = [
		GRAPH_SCRIPT.ROOM_START,
		GRAPH_SCRIPT.ROOM_COMBAT,
		GRAPH_SCRIPT.ROOM_TREASURE,
		GRAPH_SCRIPT.ROOM_DOWNSTAIRS,
		GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY,
	]
	for room_type in eligible_types:
		fake.current_room_type = room_type
		_expect(controller._is_popcorn_respawn_room(fake), "%s is eligible for backtracking popcorn" % room_type, failures)
	var excluded_types: Array[StringName] = [
		GRAPH_SCRIPT.ROOM_REST,
		GRAPH_SCRIPT.ROOM_NPC,
		GRAPH_SCRIPT.ROOM_ORB,
		GRAPH_SCRIPT.ROOM_TRADER,
	]
	for room_type in excluded_types:
		fake.current_room_type = room_type
		_expect(not controller._is_popcorn_respawn_room(fake), "%s is excluded from backtracking popcorn" % room_type, failures)
		fake.current_room_id = StringName("excluded_%s" % room_type)
		controller.room_states[fake.current_room_id] = {
			"room_type": room_type,
			"finished": true,
			"enemy_spawn_seed": 1,
			"enemy_variants": [],
			"enemy_levels": [],
			"enemy_scales": [],
			"enemy_popcorn": [],
		}
		controller._maybe_add_backtrack_popcorn(fake)
		_expect((controller.room_states[fake.current_room_id].get("enemy_variants", []) as Array).is_empty(), "%s never receives injected popcorn" % room_type, failures)

	var successful_room_id: StringName = &""
	var failed_room_id: StringName = &""
	for seed_value in range(128):
		var room_id := StringName("backtrack_%d" % seed_value)
		controller.room_states[room_id] = {
			"finished": true,
			"enemy_spawn_seed": seed_value,
			"enemy_variants": [],
			"enemy_levels": [],
			"enemy_scales": [],
			"enemy_popcorn": [],
		}
		fake.current_room_id = room_id
		fake.current_room_type = GRAPH_SCRIPT.ROOM_COMBAT
		controller._maybe_add_backtrack_popcorn(fake)
		var state: Dictionary = controller.room_states[room_id]
		if state.get("enemy_variants", []).size() == 1 and successful_room_id.is_empty():
			successful_room_id = room_id
		if state.get("enemy_variants", []).is_empty() and failed_room_id.is_empty():
			failed_room_id = room_id
	_expect(not successful_room_id.is_empty(), "a seeded revisit can inject one backtracking popcorn slot", failures)
	_expect(not failed_room_id.is_empty(), "a seeded revisit can decline the popcorn injection", failures)
	if not successful_room_id.is_empty():
		var success_state: Dictionary = controller.room_states[successful_room_id]
		_expect(bool(success_state.get("backtrack_popcorn_added", false)), "successful popcorn injection records its one-shot attempt", failures)
		_expect(bool(success_state.get("backtrack_popcorn_pending", false)), "successful popcorn injection waits for the room-entry spawn", failures)
		_expect(bool((success_state.get("enemy_popcorn", []) as Array)[0]), "backtracking injection is marked as popcorn", failures)
		fake.current_room_id = successful_room_id
		controller._maybe_add_backtrack_popcorn(fake)
		_expect((controller.room_states[successful_room_id].get("enemy_variants", []) as Array).size() == 1, "a successful room cannot duplicate popcorn on a second revisit", failures)
	if not failed_room_id.is_empty():
		_expect(bool((controller.room_states[failed_room_id] as Dictionary).get("backtrack_popcorn_added", false)), "a declined popcorn roll is recorded and cannot reroll", failures)

	var full_room_id: StringName = &"backtrack_full"
	controller.room_states[full_room_id] = {
		"finished": true,
		"enemy_spawn_seed": 17,
		"enemy_variants": ["blue"],
		"enemy_levels": [1],
		"enemy_scales": [1.0],
		"enemy_popcorn": [false],
	}
	fake.current_room_id = full_room_id
	controller._maybe_add_backtrack_popcorn(fake)
	_expect(bool((controller.room_states[full_room_id] as Dictionary).get("backtrack_popcorn_added", false)), "a full actor pool records the popcorn attempt", failures)

	for slime in fake.slimes:
		slime.free()
	fake.free()
	controller.free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("BACKTRACK_POPCORN_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
