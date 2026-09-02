extends SceneTree

const GENERATOR_SCRIPT = preload("res://scripts/dungeon_layout_generator.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var starters: Array[StringName] = [&"fire", &"water", &"electric"]
	var bound_flames: Array[StringName] = [&"", &"fire", &"water", &"electric", &"grass", &"shadow", &"ground", &"ice"]
	for starter_index in starters.size():
		var starter := starters[starter_index]
		for bound_index in bound_flames.size():
			var bound := bound_flames[bound_index]
			var layout = GENERATOR_SCRIPT.build(910000 + starter_index * 100 + bound_index, 11, starter, bound)
			var errors: Array[String] = GENERATOR_SCRIPT.validate(layout, 11, starter, bound)
			var safety_errors := _progression_safety_errors(errors)
			_expect(safety_errors.is_empty(), "R12 generated layout keeps required doors reachable from starter %s / bound flame %s: %s" % [starter, "none" if bound.is_empty() else bound, "; ".join(safety_errors)], failures)

	# Exercise the continue/load repair entry point with an intentionally unsafe
	# critical gate. The topology remains seed-owned; recovery should only change
	# the requirement and leave the repaired layout free of reachability errors.
	var recovery_layout = GENERATOR_SCRIPT.build(910007, 11, &"fire", &"ice")
	var unsafe_gate = null
	for connection in recovery_layout.connections:
		if connection.route_role == &"key_progression" and not connection.color_requirement.is_empty():
			unsafe_gate = connection
			break
	if unsafe_gate != null:
		unsafe_gate.color_requirement = &"puzzle_d"
		var before_repair := _progression_safety_errors(GENERATOR_SCRIPT.validate(recovery_layout, 11, &"fire", &"ice"))
		var repairs: Array[String] = GENERATOR_SCRIPT.repair_progression(recovery_layout, 11, &"fire", &"ice")
		var after_repair := _progression_safety_errors(GENERATOR_SCRIPT.validate(recovery_layout, 11, &"fire", &"ice"))
		_expect(not before_repair.is_empty() and not repairs.is_empty() and after_repair.is_empty(), "continued ICE-bound layouts deterministically repair an unsafe critical gate", failures)
	else:
		_expect(false, "generated R12 fixture exposes a critical color gate for recovery coverage", failures)

	# The map controller receives the bound element at run construction and runs
	# the same repair/validation path before initializing the runtime graph.
	var recovery_graph := GRAPH_SCRIPT.new()
	var recovery_map := MAP_CONTROLLER_SCRIPT.new()
	recovery_map.begin_run(recovery_graph, 910007, 11, &"fire", &"ice")
	_expect(_progression_safety_errors(GENERATOR_SCRIPT.validate(recovery_map.layout, 11, &"fire", &"ice")).is_empty(), "map bootstrap validates the actual bound start state before play", failures)
	recovery_map.free()
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: bound reachability smoke exceeded its timeout")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("GENERATED_BOUND_REACHABILITY_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _progression_safety_errors(errors: Array[String]) -> Array[String]:
	var safety_errors: Array[String] = []
	for error: String in errors:
		if error.contains("impossible puzzle-color") or error.contains("color gate has no reachable") or error.contains("entrance-orb gate has no reachable"):
			safety_errors.append(error)
	return safety_errors
