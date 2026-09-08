extends SceneTree

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const R4_SCRIPT = preload("res://scripts/puzzle_map_r4.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var template := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/puzzle_map.png"))
	var reference := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/R4(new)puzzle_map.png"))
	_expect(template != null and template.get_size() == Vector2i(35, 35), "Puzzle-map template is 35 x 35.", failures)
	_expect(reference != null and reference.get_size() == Vector2i(35, 35), "New R4 reference is 35 x 35.", failures)
	if template != null and reference != null:
		var r4: PuzzleMapGrid.MapPlan = R4_SCRIPT.build()
		_expect(GRID_SCRIPT.validate(r4, template).is_empty(), "New R4 manifest has valid grid points.", failures)
		_expect(r4.markers.size() == 51, "New R4 contains its 51 authored overlays.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_GATE_GREY) == 20, "New R4 contains 20 normal grey entrances.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_GATE_ORB_GREY) == 3, "New R4 contains 3 grey Orb doors.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_GATE_FLAME_A) == 9, "New R4 contains 9 Flame A doors.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_GATE_FLAME_B) == 4, "New R4 contains 4 Flame B doors.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_TREASURE_ROOM) == 11, "New R4 contains 11 Treasure Rooms.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_ORB_ROOM) == 1, "New R4 contains one Orb Room.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_FLAME_B_ROOM) == 1, "New R4 contains one Flame B room.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_HUB_ROOM) == 1, "New R4 contains one Hub.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_BOSS_ROOM) == 1, "New R4 contains one Boss room.", failures)
		_expect(r4.marker_count(GRID_SCRIPT.MARKER_CLOAKED_ROOM) == 0, "New R4 has no Cloaked room.", failures)
		_expect(r4.has_marker(Vector2i(17, 17), GRID_SCRIPT.MARKER_HUB_ROOM), "New R4 Hub is centered.", failures)
		_expect(r4.has_marker(Vector2i(9, 17), GRID_SCRIPT.MARKER_BOSS_ROOM), "New R4 Boss is at the authored location.", failures)
		_expect(_same_pixels(GRID_SCRIPT.render_preview(r4, template), reference), "New R4 reproduces its reference pixel-for-pixel.", failures)
	_finish(failures)

func _same_pixels(left: Image, right: Image) -> bool:
	if left == null or right == null or left.get_size() != right.get_size(): return false
	for y in left.get_height():
		for x in left.get_width():
			if left.get_pixel(x, y) != right.get_pixel(x, y): return false
	return true

func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition: failures.append(message)

func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PUZZLE_MAP_R4_NEW_GRID_SMOKE_OK")
		quit(0)
		return
	for failure in failures: push_error("FAILED: %s" % failure)
	quit(1)
