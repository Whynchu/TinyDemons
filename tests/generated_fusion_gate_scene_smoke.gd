extends SceneTree

const ELEMENT_CATALOG = preload("res://scripts/element_catalog.gd")
const GRAPH = preload("res://scripts/dungeon_graph.gd")

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for the generated vault gate flow", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame

	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	var map := gameplay.get("dungeon_map_controller") as Node
	_expect(graph != null and map != null, "R8 scene composes map and graph owners", failures)
	if graph != null and map != null:
		map.call("begin_run", graph, 807001, 7, &"water")
		map.call("set_starter_flame_attuned", true)
		var gates := _vault_gates(graph)
		_expect(gates.size() >= 1 and gates.size() <= 2, "Water-origin Run 8 scene graph contains one or two optional vault gates", failures)
		var gate: DungeonGraph.ConnectionRecord = gates[0] if not gates.is_empty() else null
		_expect(gate != null, "Run 8 scene graph contains an elemental vault gate", failures)
		if gate != null:
			var required_element := ELEMENT_CATALOG.element_for_id(gate.orb_element_requirement)
			_expect(required_element != ELEMENT_CATALOG.Element.NEUTRAL, "vault gate requires a non-neutral element", failures)
			map.call("on_room_completed", gate.source_room_id)
			_expect(map.call("connection_visual_state", gate, false) == &"orb_locked", "vault gate stays locked before its Orb charge", failures)
			var orb_room_id: StringName = _first_orb_room(graph)
			_expect(not orb_room_id.is_empty(), "Run 8 exposes an ungated Orb utility room", failures)
			if not orb_room_id.is_empty():
				map.call("on_room_entered", orb_room_id)
				var required_palette := ELEMENT_CATALOG.palette_key(required_element)
				_expect(map.call("change_orb_from_palette", orb_room_id, required_palette), "Orb utility accepts the vault element", failures)
				_expect(map.call("connection_visual_state", gate, false) == &"open", "matching Orb charge opens the vault gate", failures)
				_expect(map.call("is_connection_available", gate, false), "vault gate can be traversed after its requirement is met", failures)
				map.call("change_orb_from_palette", orb_room_id, "grey")
				_expect(map.call("connection_visual_state", gate, false) == &"open", "solved vault gate remains open after shared Orb changes", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _vault_gates(graph: DungeonGraph) -> Array[DungeonGraph.ConnectionRecord]:
	var result: Array[DungeonGraph.ConnectionRecord] = []
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room == null:
			continue
		for connection_value in room.outgoing_connections.values():
			var connection := connection_value as DungeonGraph.ConnectionRecord
			if connection != null and connection.route_role == GRAPH.ROUTE_ELEMENTAL_VAULT:
				result.append(connection)
	return result


func _first_orb_room(graph: DungeonGraph) -> StringName:
	for room_id in graph.get_room_ids():
		var room := graph.get_room(room_id)
		if room != null and room.room_type == GRAPH.ROOM_ORB:
			return room.id
	return &""


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: generated vault gate scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("GENERATED_VAULT_GATE_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)
