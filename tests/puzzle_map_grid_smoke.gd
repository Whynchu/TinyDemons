extends SceneTree

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const R3_SCRIPT = preload("res://scripts/puzzle_map_r3_new.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var template := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/puzzle_map.png"))
	var reference := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/R3puzzle_map.png"))
	_expect(template != null and template.get_size() == Vector2i(35, 35), "Puzzle-map template is 35 x 35.", failures)
	_expect(reference != null and reference.get_size() == Vector2i(35, 35), "R3 preview reference is 35 x 35.", failures)
	if template != null and reference != null:
		var r3: PuzzleMapGrid.MapPlan = R3_SCRIPT.build()
		_expect(GRID_SCRIPT.validate(r3, template).is_empty(), "R3 manifest has valid, non-overlapping grid points.", failures)
		_expect(r3.markers.size() == 50, "R3 contains its 50 authored overlays.", failures)
		_expect(r3.marker_count(GRID_SCRIPT.MARKER_GATE_GREY) == 16, "R3 contains 16 normal grey entrances.", failures)
		_expect(r3.has_marker(Vector2i(20, 24), GRID_SCRIPT.MARKER_GATE_GREY), "R3 includes its lower normal entrance.", failures)
		_expect(r3.marker_count(GRID_SCRIPT.MARKER_GATE_ORB_GREY) == 14, "R3 contains 14 light-grey Orb doors.", failures)
		_expect(r3.marker_count(GRID_SCRIPT.MARKER_GATE_FLAME_A) == 8, "R3 contains 8 Flame A doors.", failures)
		_expect(r3.marker_count(GRID_SCRIPT.MARKER_GATE_FLAME_B) == 0, "R3 contains no Flame B doors.", failures)
		var preview := GRID_SCRIPT.render_preview(r3, template)
		_expect(_same_pixels(preview, reference), "R3 manifest reproduces the authored preview reference pixel-for-pixel.", failures)
		_expect(preview.get_pixelv(Vector2i(15, 23)) == GRID_SCRIPT.COLOR_ORB, "R3 retains its lower Orb room.", failures)
		_expect(preview.get_pixelv(Vector2i(20, 24)) == GRID_SCRIPT.COLOR_GATE_GREY, "Normal grey entrances retain their dark-grey swatch.", failures)
		_expect(preview.get_pixelv(Vector2i(28, 10)) == GRID_SCRIPT.COLOR_TRANSITION, "Light-grey Orb doors retain their Orb-door swatch.", failures)

		var parsed: PuzzleMapGrid.MapPlan = GRID_SCRIPT.parse(reference, template, &"parsed_r3")
		_expect(parsed != null and parsed.markers.size() == r3.markers.size(), "Reference parser recovers each authored R3 overlay.", failures)
		_expect(_same_pixels(GRID_SCRIPT.render_preview(parsed, template), reference), "Parsed R3 round-trips through the preview renderer exactly.", failures)

		var variants: Array[PuzzleMapGrid.MapPlan] = R3_SCRIPT.build_validation_variants()
		for variant in variants:
			_expect(GRID_SCRIPT.validate(variant, template).is_empty(), "%s is a valid generated grid plan." % variant.id, failures)
		_expect(variants[0].marker_count(GRID_SCRIPT.MARKER_GATE_GREY) == 16, "R3 validation preserves normal grey entrances.", failures)
		_expect(GRID_SCRIPT.gate_requirement(GRID_SCRIPT.MARKER_GATE_ORB_GREY) == &"orb_grey", "Grey doors carry the Orb requirement metadata.", failures)
		_expect(GRID_SCRIPT.gate_requirement(GRID_SCRIPT.MARKER_GATE_GREY).is_empty(), "Normal grey entrances do not carry an Orb requirement.", failures)
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
		print("PUZZLE_MAP_GRID_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
