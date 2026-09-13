extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const RUN3_LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run3.gd")
const RUN4_LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run4.gd")
const RUN5_LAYOUT_SCRIPT = preload("res://scripts/dungeon_layout_run5.gd")

const CASES: Array[Dictionary] = [
	{
		"label": &"R3",
		"layout_script": RUN3_LAYOUT_SCRIPT,
		"layout_id": &"RUN3",
		"completed_runs": 2,
		"seed": 30917,
	},
	{
		"label": &"R4",
		"layout_script": RUN4_LAYOUT_SCRIPT,
		"layout_id": &"RUN4",
		"completed_runs": 3,
		"seed": 40917,
	},
	{
		"label": &"R5",
		"layout_script": RUN5_LAYOUT_SCRIPT,
		"layout_id": &"RUN5",
		"completed_runs": 4,
		"seed": 50917,
	},
]


func _initialize() -> void:
	var failures: Array[String] = []
	for test_case in CASES:
		_check_layout(test_case, failures)
	_finish(failures)


func _check_layout(test_case: Dictionary, failures: Array[String]) -> void:
	var label: String = String(test_case["label"])
	var layout = (test_case["layout_script"] as Script).call("build", &"water")
	_expect(layout != null, "%s layout builds" % label, failures)
	if layout == null:
		return
	_expect(layout.layout_id == test_case["layout_id"], "%s authored layout identity is correct" % label, failures)
	_expect(layout.validate().is_empty(), "%s authored layout validates" % label, failures)
	_expect(layout.map_size == Vector2i(35, 35), "%s uses the 35x35 map canvas" % label, failures)
	_expect(layout.rooms.size() > 0 and layout.connections.size() > 0, "%s contains authored rooms and connections" % label, failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_START) == 1, "%s has one Hub" % label, failures)
	_expect(_room_type_count(layout, GRAPH_SCRIPT.ROOM_BOSS) == 1, "%s has one Boss room" % label, failures)

	var graph = GRAPH_SCRIPT.new()
	var map = MAP_CONTROLLER_SCRIPT.new()
	root.add_child(map)
	map.begin_run(graph, int(test_case["seed"]), int(test_case["completed_runs"]), &"water")
	_expect(bool(map.call("is_authored_layout")), "%s selects an authored layout at runtime" % label, failures)
	_expect(map.layout != null and map.layout.layout_id == test_case["layout_id"], "%s runtime layout identity is correct" % label, failures)
	_expect(graph.get_room_ids().size() == layout.rooms.size(), "%s runtime graph uses the authored room count" % label, failures)
	map.queue_free()


func _room_type_count(layout, room_type: StringName) -> int:
	var count := 0
	for room in layout.rooms:
		if room.room_type == room_type:
			count += 1
	return count


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("AUTHORED_LAYOUTS_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
