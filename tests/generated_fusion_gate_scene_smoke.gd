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
	_expect(graph != null and map != null and chroma != null, "R8 scene composes map and Chroma owners", failures)
	if graph != null and map != null and chroma != null:
		map.call("begin_run", graph, 807001, 7, &"water")
		map.call("set_starter_flame_attuned", true)
		var gates := _orb_gates_by_depth(graph)
		_expect(gates.size() == 2, "Water-origin Run 8 scene graph contains two ordered fusion gates", failures)
		var gate: DungeonGraph.ConnectionRecord = gates[0] if not gates.is_empty() else null
		var late_gate: DungeonGraph.ConnectionRecord = gates[1] if gates.size() > 1 else null
		_expect(gate != null, "Run 8 scene graph contains a fusion entrance-orb gate", failures)
		_expect(late_gate != null, "Run 8 scene graph contains the second fusion entrance-orb gate", failures)
		if gate != null:
			_expect(_room_depth(graph, gate.source_room_id) == 6, "R8 first fusion gate is at the first curriculum tier", failures)
			if late_gate != null:
				_expect(_room_depth(graph, late_gate.source_room_id) == 10, "R8 second fusion gate is at the second curriculum tier", failures)
				_expect(_room_depth(graph, late_gate.destination_room_id) >= 11, "R8 second fusion gate leads beyond the second curriculum tier", failures)
				_expect(not _prerequisite_orb_room(graph, late_gate).is_empty(), "R8 second gate has its own pre-gate Orb", failures)
			var first_required := ELEMENT_CATALOG_SCRIPT.element_for_id(gate.orb_element_requirement)
			_expect(first_required != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL, "R8 first gate has a valid non-neutral element", failures)
			map.call("set_current_element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)
			_expect(map.call("connection_visual_state", gate, false) == &"orb_locked", "R8 first gate is locked before its Orb is charged", failures)
			chroma.call("attune", first_required)
			gameplay.call("_sync_current_element_state")
			_expect(map.call("connection_visual_state", gate, false) == &"orb_locked", "carried element alone does not bypass the R8 first gate", failures)
			var first_orb_id: StringName = _prerequisite_orb_room(graph, gate)
			_expect(not first_orb_id.is_empty(), "R8 first gate has a pre-gate prerequisite Orb", failures)
			if not first_orb_id.is_empty():
				map.call("on_room_entered", first_orb_id)
				var first_palette := ELEMENT_CATALOG_SCRIPT.palette_key(first_required)
				_expect(map.call("change_orb_from_palette", first_orb_id, first_palette), "R8 first prerequisite Orb accepts its matching result", failures)
			_expect(map.call("connection_visual_state", gate, false) == &"open", "first matching Orb charge opens the R8 first gate", failures)
			_expect(map.call("is_connection_available", gate, false), "R8 first gate can be traversed and latched", failures)
			if late_gate != null:
				var second_required := ELEMENT_CATALOG_SCRIPT.element_for_id(late_gate.orb_element_requirement)
				var second_orb_id: StringName = _prerequisite_orb_room(graph, late_gate)
				_expect(second_required != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL, "R8 second gate has a valid non-neutral element", failures)
				_expect(map.call("connection_visual_state", late_gate, false) == &"orb_locked", "R8 second gate stays locked until its own Orb is charged", failures)
				map.call("change_orb_from_palette", first_orb_id, "purple")
				_expect(map.call("connection_visual_state", gate, false) == &"open", "latched first gate stays open after the shared Orb changes", failures)
				_expect(map.call("connection_visual_state", late_gate, false) == &"orb_locked", "the first fusion result cannot bypass the second gate", failures)
				_expect(not second_orb_id.is_empty(), "R8 second gate has a pre-gate prerequisite Orb", failures)
				if not second_orb_id.is_empty():
					map.call("on_room_entered", second_orb_id)
					var second_palette := ELEMENT_CATALOG_SCRIPT.palette_key(second_required)
					_expect(map.call("change_orb_from_palette", second_orb_id, second_palette), "R8 second prerequisite Orb accepts its matching result", failures)
				_expect(map.call("connection_visual_state", late_gate, false) == &"open", "second matching Orb charge opens the R8 second gate", failures)
				_expect(map.call("is_connection_available", late_gate, false), "R8 second gate can be traversed and latched", failures)
				map.call("change_orb_from_palette", second_orb_id, "purple")
				_expect(map.call("connection_visual_state", gate, true) == &"open", "latched first gate remains available for return travel", failures)
				_expect(map.call("connection_visual_state", late_gate, true) == &"open", "latched second gate remains available for return travel", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _orb_gates_by_depth(graph: DungeonGraph) -> Array[DungeonGraph.ConnectionRecord]:
	var result: Array[DungeonGraph.ConnectionRecord] = []
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room == null:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			if connection != null and connection.resolved_gate_type() == DungeonGraph.GATE_ENTRANCE_ORB:
				result.append(connection)
	result.sort_custom(func(left, right):
		return _room_depth(graph, left.source_room_id) < _room_depth(graph, right.source_room_id)
	)
	return result


func _room_depth(graph: DungeonGraph, room_id: StringName) -> int:
	var room := graph.get_room(room_id)
	return room.depth if room != null else -1


func _prerequisite_orb_room(graph: DungeonGraph, gate: DungeonGraph.ConnectionRecord) -> StringName:
	if gate == null:
		return &""
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room == null or room.id != gate.source_room_id:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			var destination := graph.get_room(connection.destination_room_id) if connection != null else null
			if connection != null and destination != null and destination.room_type == DungeonGraph.ROOM_ORB and connection.route_role == &"fusion_prerequisite_orb":
				return destination.id
	return &""


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
