extends SceneTree
const RunGradeEvaluator = preload("res://scripts/run_grade.gd")

func _init() -> void:
	var failures: Array[String] = []
	var full_style := RunState.new()
	full_style.begin(123, 0, 40.0)
	full_style.start_timer()
	full_style.elapsed_time = 20.0
	full_style.damage_taken = 4.0
	full_style.combat_movement_time = 20.0
	full_style.attack_count = 12
	full_style.attack2_count = 4
	full_style.encountered_enemy_count = 4
	full_style.attack_hit_count = 8
	full_style.attack2_hit_count = 3
	full_style.attack_swing_hit_count = 10
	full_style.enemy_attack_attempts = 4
	full_style.dodge_count = 1
	full_style.block_count = 2
	full_style.record_room_visited(&"room_0_1")
	full_style.record_room_visited(&"room_1_2")
	full_style.record_room_visited(&"room_1_3")
	full_style.record_room_visited(&"room_2_4")
	full_style.set_explorable_room_count(4)
	var full_grade: Dictionary = RunGradeEvaluator.evaluate(full_style, full_style.starting_health)
	_expect(int(full_grade["score"]) >= 90 and str(full_grade["grade"]) == "S", "varied clean run earns S grade", failures)
	var basic_style := RunState.new()
	basic_style.begin(456, 0, 40.0)
	basic_style.start_timer()
	basic_style.elapsed_time = 600.0
	basic_style.damage_taken = 75.0
	basic_style.attack_count = 2
	basic_style.record_room_visited(&"room_0_1")
	basic_style.set_explorable_room_count(4)
	var basic_grade: Dictionary = RunGradeEvaluator.evaluate(basic_style, basic_style.starting_health)
	_expect(int(basic_grade["score"]) < int(full_grade["score"]), "slow one-note run scores lower", failures)
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
