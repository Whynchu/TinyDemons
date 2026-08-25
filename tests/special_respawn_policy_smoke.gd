extends SceneTree

const ROOM_CONTROLLER_SCRIPT = preload("res://scripts/room_controller.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")

class FakeRoot extends Node:
	var current_room_type: StringName = &""
	var current_room_id: StringName = &""
	var slimes: Array[Sprite2D] = []


func _initialize() -> void:
	var failures: Array[String] = []
	var controller = ROOM_CONTROLLER_SCRIPT.new()
	controller.progression_run_rank = 1
	for seed_value in range(64):
		var encounter: Dictionary = controller._generate_enemy_encounter(seed_value, 8, false, false)
		for variant in encounter.get("variants", []) as Array:
			_expect(String(variant) != "purple", "special-room policy does not force Shadow Slimes", failures)
	var fake := FakeRoot.new()
	var room_id: StringName = &"special_test"
	fake.current_room_type = GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY
	fake.current_room_id = room_id
	fake.slimes = [Sprite2D.new(), Sprite2D.new(), Sprite2D.new()]
	controller.room_states[room_id] = {"enemy_variants": ["blue", "red", "green"]}
	controller.schedule_special_enemy_respawns(fake)
	var state: Dictionary = controller.room_states[room_id]
	var timers: Dictionary = state.get("special_respawn_timers", {}) as Dictionary
	_expect(timers.size() == 3, "every special-room enemy slot receives a respawn timer", failures)
	for timer in timers.values():
		_expect(is_equal_approx(float(timer), 45.0), "special-room respawn timers start at 45 seconds", failures)
	timers["0"] = 12.0
	state["special_respawn_timers"] = timers
	controller.room_states[room_id] = state
	controller.schedule_special_enemy_respawns(fake)
	_expect(is_equal_approx(float((controller.room_states[room_id] as Dictionary)["special_respawn_timers"]["0"]), 12.0), "rescheduling preserves an existing slot's death time", failures)
	fake.current_room_type = GRAPH_SCRIPT.ROOM_COMBAT
	controller.room_states[room_id] = {
		"room_type": GRAPH_SCRIPT.ROOM_SPECIAL_ENEMY,
		"special_clear_earned": true,
		"finished": false,
		"enemy_variants": ["blue"],
		"special_respawn_timers": {"0": 30.0},
	}
	controller.update_special_enemy_respawns(fake, 17.0)
	_expect(is_equal_approx(float((controller.room_states[room_id] as Dictionary)["special_respawn_timers"]["0"]), 13.0), "special-room timers continue while the room is away from the player", failures)
	controller.update_special_enemy_respawns(fake, 20.0)
	_expect(is_zero_approx(float((controller.room_states[room_id] as Dictionary)["special_respawn_timers"]["0"])), "away-room respawn timers become ready after 45 seconds", failures)
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
		print("SPECIAL_RESPAWN_POLICY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
