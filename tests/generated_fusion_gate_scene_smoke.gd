extends SceneTree

const ELEMENT_CATALOG_SCRIPT = preload("res://scripts/element_catalog.gd")
const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for the generated fusion gate flow", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame

	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	var map := gameplay.get("dungeon_map_controller") as Node
	var chroma := gameplay.get("player_chroma_component") as Node
	_expect(graph != null and map != null and chroma != null, "R6 scene composes map and Chroma owners", failures)
	if graph != null and map != null and chroma != null:
		map.call("begin_run", graph, 607001, 5, &"fire")
		var gate: DungeonGraph.ConnectionRecord = _first_element_gate(graph)
		_expect(gate != null, "Run 6 scene graph contains a fusion-element gate", failures)
		if gate != null:
			var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(gate.element_requirement)
			_expect(required_element != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL, "R6 gate has a valid non-neutral element", failures)
			map.call("set_current_element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)
			_expect(map.call("connection_visual_state", gate, false) == &"element_locked", "R6 fusion gate is visibly locked before its result is active", failures)
			chroma.call("attune", required_element)
			gameplay.call("_sync_current_element_state")
			_expect(map.call("connection_visual_state", gate, false) == &"open", "active unbound fusion result opens the R6 scene gate", failures)
			chroma.call("spend_chroma", 100)
			gameplay.call("_sync_current_element_state")
			_expect(map.call("connection_visual_state", gate, false) == &"open", "opened R6 fusion gate remains latched after Chroma depletion", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _first_element_gate(graph: DungeonGraph) -> DungeonGraph.ConnectionRecord:
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room == null:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			if connection != null and not connection.element_requirement.is_empty():
				return connection
	return null


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: generated fusion gate scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("GENERATED_FUSION_GATE_SCENE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error("FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
