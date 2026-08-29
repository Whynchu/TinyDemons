extends SceneTree
const RunGradeEvaluator = preload("res://scripts/run_grade.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var full_style := RunState.new()
	full_style.begin(123, 0, 40.0)
	full_style.start_timer()
	full_style.elapsed_time = 70.0
	for room_id in [&"room_0_1", &"room_1_2", &"room_1_3", &"room_2_4"]:
		full_style.record_map_room_entry(room_id)
		full_style.record_room_completion(room_id)
	full_style.set_map_room_count(4)
	full_style.set_run_room_count(4)
	for action in [&"attack1", &"attack2", &"spin", &"charged", &"dodge_roll", &"backflip", &"block", &"magic", &"imbued"]:
		full_style.record_style_action(action)
	for combo in 5:
		full_style.record_combo_hit(combo + 1)
	var full_grade: Dictionary = RunGradeEvaluator.evaluate(full_style, full_style.starting_health)
	_expect(int(full_grade["score"]) >= 90 and str(full_grade["grade"]) == "S", "full varied run earns S grade", failures)
	_expect(bool(full_grade["full_clear"]) and bool(full_grade["map_complete"]), "full run separates map and room completion", failures)
	_expect(int(full_grade["style_score"]) == 10 and int(full_grade["max_combo"]) == 5, "style and combo telemetry reach their caps", failures)

	var partial := RunState.new()
	partial.begin(456, 0, 40.0)
	partial.start_timer()
	partial.elapsed_time = 60.0
	for room_id in [&"room_0_1", &"room_1_2", &"room_1_3", &"room_2_4"]:
		partial.record_map_room_entry(room_id)
	partial.set_map_room_count(4)
	partial.set_run_room_count(4)
	partial.record_room_completion(&"room_0_1")
	partial.record_room_completion(&"room_1_2")
	partial.record_room_completion(&"room_1_3")
	for action in [&"attack1", &"attack2", &"spin", &"charged", &"dodge_roll", &"backflip", &"block", &"magic", &"imbued"]:
		partial.record_style_action(action)
	for combo in 5:
		partial.record_combo_hit(combo + 1)
	var partial_grade: Dictionary = RunGradeEvaluator.evaluate(partial, partial.starting_health)
	_expect(bool(partial_grade["map_complete"]) and not bool(partial_grade["full_clear"]), "map completion is independent from room completion", failures)
	_expect(str(partial_grade["grade"]) == "B", "incomplete room run is capped at B", failures)

	var slow := RunState.new()
	slow.begin(789, 0, 40.0)
	slow.start_timer()
	slow.elapsed_time = 600.0
	slow.set_map_room_count(4)
	slow.set_run_room_count(4)
	for room_id in [&"room_0_1", &"room_1_2", &"room_1_3", &"room_2_4"]:
		slow.record_room_completion(room_id)
	var slow_grade: Dictionary = RunGradeEvaluator.evaluate(slow, slow.starting_health)
	_expect(int(slow_grade["score"]) < int(full_grade["score"]), "slow full-clear run scores lower", failures)
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: run_grade smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN_GRADE_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
