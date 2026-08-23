extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const MAP_CONTROLLER_SCRIPT = preload("res://scripts/dungeon_map_controller.gd")
const MINIMAP_SCRIPT = preload("res://scripts/dungeon_minimap_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var graph = GRAPH_SCRIPT.new()
	var map_controller = MAP_CONTROLLER_SCRIPT.new()
	var minimap = MINIMAP_SCRIPT.new()
	root.add_child(map_controller)
	root.add_child(minimap)
	map_controller.begin_run(graph, 8080, 0)
	minimap.configure(map_controller)
	var layout = map_controller.get("layout")
	for room in layout.rooms:
		map_controller.on_room_entered(room.id)
		map_controller.on_room_completed(room.id)
	var actual: Image = minimap.snapshot_image()
	var reference := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/minimap- rough draftR1.png"))
	_expect(reference != null and reference.get_size() == Vector2i(16, 23), "reference map is a 16x23 image", failures)
	if actual != null and reference != null and actual.get_size() == reference.get_size():
		var dynamic_door_requirements: Dictionary = {}
		for connection in layout.connections:
			if not connection.color_requirement.is_empty():
				dynamic_door_requirements[connection.minimap_coordinate] = connection.color_requirement
		for decorative_door in layout.decorative_door_pixels:
			var decorative_requirement: StringName = decorative_door.get("color_requirement", &"")
			if not decorative_requirement.is_empty():
				dynamic_door_requirements[decorative_door.get("coordinate", Vector2i.ZERO)] = decorative_requirement
		var mismatch_count := 0
		var dynamic_door_count := 0
		var first_mismatch := Vector2i.ZERO
		for y in actual.get_height():
			for x in actual.get_width():
				var reference_pixel := reference.get_pixel(x, y)
				var actual_pixel := actual.get_pixel(x, y)
				var coordinate := Vector2i(x, y)
				var authored_requirement: StringName = dynamic_door_requirements.get(coordinate, &"")
				var is_placeholder_door := not authored_requirement.is_empty() or reference_pixel == MINIMAP_SCRIPT.COLOR_PUZZLE_A_DOOR or reference_pixel == MINIMAP_SCRIPT.COLOR_PUZZLE_B_DOOR
				if is_placeholder_door:
					dynamic_door_count += 1
					var requirement: StringName = authored_requirement
					if requirement.is_empty():
						requirement = &"puzzle_a" if reference_pixel == MINIMAP_SCRIPT.COLOR_PUZZLE_A_DOOR else &"puzzle_b"
					if actual_pixel != map_controller.call("door_display_color", requirement):
						mismatch_count += 1
						if mismatch_count == 1:
							first_mismatch = Vector2i(x, y)
				elif actual_pixel != reference_pixel:
					mismatch_count += 1
					if mismatch_count == 1:
						first_mismatch = Vector2i(x, y)
		var actual_color := actual.get_pixelv(first_mismatch) if mismatch_count > 0 else Color.TRANSPARENT
		var reference_color := reference.get_pixelv(first_mismatch) if mismatch_count > 0 else Color.TRANSPARENT
		_expect(dynamic_door_count == 5, "reference map contains three blue primary swatches and two green/grey doors", failures)
		_expect(mismatch_count == 0, "authored Run 1 renders the reference map exactly apart from dynamic door swatches; first mismatch: %s actual %s reference %s (count %d)" % [first_mismatch, actual_color, reference_color, mismatch_count], failures)
	minimap.queue_free()
	map_controller.queue_free()
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN1_REFERENCE_MAP_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
