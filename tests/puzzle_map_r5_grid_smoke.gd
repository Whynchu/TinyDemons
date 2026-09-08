extends SceneTree

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const R5_SCRIPT = preload("res://scripts/puzzle_map_r5.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var template := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/puzzle_map.png"))
	var reference := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/R5puzzle_map.png"))
	_expect(template != null and template.get_size() == Vector2i(35, 35), "Puzzle-map template is 35 x 35.", failures)
	_expect(reference != null and reference.get_size() == Vector2i(35, 35), "R4 reference is 35 x 35.", failures)
	if template != null and reference != null:
		var r5: PuzzleMapGrid.MapPlan = R5_SCRIPT.build()
		_expect(GRID_SCRIPT.validate(r5, template).is_empty(), "R5 manifest has valid, non-overlapping grid points.", failures)
		_expect(r5.markers.size() == 106, "R5 contains its 106 authored overlays.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_GATE_GREY) == 53, "R5 contains 53 normal grey entrances.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_GATE_ORB_GREY) == 11, "R5 contains 11 light-grey Orb doors.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_GATE_FLAME_A) == 8, "R5 contains 8 Flame A doors.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_GATE_FLAME_B) == 16, "R5 contains 16 Flame B doors.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_TREASURE_ROOM) == 13, "R5 contains 13 Treasure Rooms.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_ORB_ROOM) == 2, "R5 contains two Orb Rooms.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_FLAME_B_ROOM) == 1, "R5 contains one Flame B room.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_HUB_ROOM) == 1, "R5 contains one Hub.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_BOSS_ROOM) == 1, "R5 contains one Boss room.", failures)
		_expect(r5.marker_count(GRID_SCRIPT.MARKER_CLOAKED_ROOM) == 0, "R5 is authored without a Cloaked room.", failures)
		_expect(r5.has_marker(Vector2i(17, 17), GRID_SCRIPT.MARKER_HUB_ROOM), "R5 Hub sits at the template center.", failures)
		_expect(r5.has_marker(Vector2i(29, 17), GRID_SCRIPT.MARKER_BOSS_ROOM), "R5 Boss sits to the right of the Hub.", failures)
		var preview := GRID_SCRIPT.render_preview(r5, template)
		_expect(_same_pixels(preview, reference), "R5 manifest reproduces the authored reference pixel-for-pixel.", failures)

		var parsed: PuzzleMapGrid.MapPlan = GRID_SCRIPT.parse(reference, template, &"parsed_r5")
		_expect(parsed != null and parsed.markers.size() == r5.markers.size(), "Reference parser recovers each authored R5 overlay.", failures)
		_expect(_same_pixels(GRID_SCRIPT.render_preview(parsed, template), reference), "Parsed R5 round-trips through the preview renderer exactly.", failures)

		_expect(GRID_SCRIPT.gate_requirement(GRID_SCRIPT.MARKER_GATE_ORB_GREY) == &"orb_grey", "Grey Orb doors carry the Orb requirement metadata.", failures)
		_expect(GRID_SCRIPT.gate_requirement(GRID_SCRIPT.MARKER_GATE_GREY).is_empty(), "Normal grey entrances do not carry an Orb requirement.", failures)
		_expect(GRID_SCRIPT.gate_requirement(GRID_SCRIPT.MARKER_GATE_FLAME_A) == &"flame_a", "Flame A doors carry the Flame A requirement.", failures)
		_expect(GRID_SCRIPT.gate_requirement(GRID_SCRIPT.MARKER_GATE_FLAME_B) == &"flame_b", "Flame B doors carry the Flame B requirement.", failures)
	_finish(failures)


func _same_pixels(left: Image, right: Image) -> bool:
	if left == null or right == null or left.get_size() != right.get_size():
		return false
	for y in left.get_height():
		for x in left.get_width():
			if left.get_pixel(x, y) != right.get_pixel(x, y):
				return false
	return true


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PUZZLE_MAP_R5_GRID_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
