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
		map.call("begin_run", graph, 807001, 7, &"fire")
		map.call("set_starter_flame_attuned", true)
		var gate: DungeonGraph.ConnectionRecord = _first_orb_gate(graph)
		_expect(gate != null, "Run 8 scene graph contains a fusion entrance-orb gate", failures)
		if gate != null:
			var required_element := ELEMENT_CATALOG_SCRIPT.element_for_id(gate.orb_element_requirement)
			var required_palette := ELEMENT_CATALOG_SCRIPT.palette_key(required_element)
			_expect(required_element != ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL, "R8 gate has a valid non-neutral element", failures)
			map.call("set_current_element", ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL)
			_expect(map.call("connection_visual_state", gate, false) == &"orb_locked", "R8 entrance-orb gate is visibly locked before its orb is charged", failures)
			chroma.call("attune", required_element)
			gameplay.call("_sync_current_element_state")
			_expect(map.call("connection_visual_state", gate, false) == &"orb_locked", "active unbound fusion result does not bypass the R8 scene gate", failures)
			var orb_room_id: StringName = _prerequisite_orb_room(graph, gate)
			_expect(not orb_room_id.is_empty(), "R8 scene graph exposes a pre-gate prerequisite Orb", failures)
			if not orb_room_id.is_empty():
				map.call("on_room_entered", orb_room_id)
				_expect(map.call("change_orb_from_palette", orb_room_id, required_palette), "R8 scene Orb Room accepts the matching result", failures)
			_expect(map.call("connection_visual_state", gate, false) == &"open", "matching Orb charge opens the R8 scene gate", failures)
			_expect(map.call("is_connection_available", gate, false), "matching entrance-Orb gate can be traversed and latched", failures)
			chroma.call("spend_chroma", 100)
			gameplay.call("_sync_current_element_state")
			_expect(map.call("connection_visual_state", gate, false) == &"open", "entrance-orb gate remains open while its world state is unchanged", failures)
			map.call("change_orb_from_palette", orb_room_id, "green")
			_expect(map.call("connection_visual_state", gate, false) == &"open", "traversed entrance-orb gate stays solved when the world state changes", failures)
			_expect(map.call("is_connection_available", gate, true), "solved entrance-orb gate remains available for the required return trip", failures)
			map.call("change_orb_from_palette", orb_room_id, required_palette)
			_expect(map.call("connection_visual_state", gate, false) == &"open", "entrance-orb gate reopens when its required world state returns", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _first_orb_gate(graph: DungeonGraph) -> DungeonGraph.ConnectionRecord:
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room == null:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			if connection != null and connection.resolved_gate_type() == DungeonGraph.GATE_ENTRANCE_ORB:
				return connection
	return null


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
