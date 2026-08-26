extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var main_scene := load("res://scenes/main.tscn") as PackedScene
	var basic_scene := load("res://scenes/basic_room.tscn") as PackedScene
	_expect(main_scene != null, "main scene loads for the floor presentation check", failures)
	var orb_scene := load("res://scenes/orb_room.tscn") as PackedScene
	_expect(basic_scene != null, "basic room authoring prefab loads", failures)
	_expect(orb_scene != null, "orb room authoring prefab loads", failures)
	if main_scene != null:
		var main := main_scene.instantiate()
		_expect(main.get_node_or_null("Map/FloorTiles/FloorUnderlay") != null, "main scene includes a seamless floor underlay", failures)
		main.free()
	if basic_scene != null:
		var basic := basic_scene.instantiate()
		_expect(basic.get_node_or_null("Map/FloorTiles/FloorLayer") != null, "basic prefab contains the floor layer", failures)
		var floor_underlay := basic.get_node_or_null("Map/FloorTiles/FloorUnderlay") as Polygon2D
		_expect(floor_underlay != null, "basic prefab includes a seamless floor underlay", failures)
		if floor_underlay != null:
			_expect(floor_underlay.z_index < 0 and floor_underlay.color.is_equal_approx(Color(148.0 / 255.0, 176.0 / 255.0, 194.0 / 255.0, 1.0)), "floor underlay matches the floor palette and sits behind the tile artwork", failures)
		_expect(basic.get_node_or_null("Map/FloorTiles/Entrance") != null and basic.get_node_or_null("Map/FloorTiles/EntranceRight") != null, "basic prefab contains both lower entrances", failures)
		_expect(basic.get_node_or_null("Map/Walls/DoorLeft") != null and basic.get_node_or_null("Map/Walls/DoorRight") != null, "basic prefab contains both wall doors", failures)
		basic.free()
	if orb_scene != null:
		var orb_room := orb_scene.instantiate()
		_expect(orb_room.get_node_or_null("Map/FloorTiles/FloorLayer") != null, "orb prefab inherits the corrected basic-room floor", failures)
		_expect(orb_room.get_node_or_null("Map/Walls/DoorLeft") != null and orb_room.get_node_or_null("Map/Walls/DoorRight") != null, "orb prefab inherits both basic-room doors", failures)
		_expect(orb_room.get_node_or_null("Map/Sockets/BOTTOM_LEFT") != null and orb_room.get_node_or_null("Map/Sockets/BOTTOM_RIGHT") != null, "orb prefab inherits both lower socket assemblies", failures)
		var orb := orb_room.get_node_or_null("Map/EntryOrb") as Sprite2D
		var orb_center := orb_room.get_node_or_null("Map/OrbCenterGuide") as Marker2D
		_expect(orb != null, "orb prefab contains one centered EntryOrb", failures)
		if orb != null:
			_expect(orb.hframes == 6 and orb.texture != null, "EntryOrb uses the six-frame artwork", failures)
			_expect(String(orb.get_meta("initial_palette", "")) == "grey", "EntryOrb begins with grey authoring metadata", failures)
		if orb != null and orb_center != null:
			_expect(orb.position == orb_center.position, "EntryOrb shares the authored center marker", failures)
		orb_room.free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN1_ROOM_PREFAB_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
