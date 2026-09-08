extends SceneTree

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const R4_SCRIPT = preload("res://scripts/puzzle_map_r4.gd")
const R5_SCRIPT = preload("res://scripts/puzzle_map_r5.gd")


func _initialize() -> void:
	_report("R4", R4_SCRIPT.build(), "res://Artwork/R4(new)puzzle_map.png")
	_report("R5", R5_SCRIPT.build(), "res://Artwork/R5puzzle_map.png")
	quit(0)


func _report(label: String, plan, reference_path: String) -> void:
	var template := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/puzzle_map.png"))
	var reference := Image.load_from_file(ProjectSettings.globalize_path(reference_path))
	var rendered := GRID_SCRIPT.render_preview(plan, template)
	var parsed = GRID_SCRIPT.parse(reference, template, StringName(label.to_lower()))
	var unknown_colors: Dictionary = {}
	for y in reference.get_height():
		for x in reference.get_width():
			var reference_color := reference.get_pixel(x, y)
			if reference_color == template.get_pixel(x, y):
				continue
			if GRID_SCRIPT.marker_kind(reference_color).is_empty():
				var color_key := str(reference_color)
				unknown_colors[color_key] = int(unknown_colors.get(color_key, 0)) + 1
	var mismatch_count := 0
	var first_mismatches: Array[String] = []
	for y in reference.get_height():
		for x in reference.get_width():
			var expected := reference.get_pixel(x, y)
			var actual := rendered.get_pixel(x, y)
			if expected != actual:
				mismatch_count += 1
				if first_mismatches.size() < 12:
					first_mismatches.append("(%d,%d) expected=%s actual=%s" % [x, y, expected, actual])
	var marker_summary := []
	for kind in GRID_SCRIPT.MARKER_COLORS.keys():
		marker_summary.append("%s=%d/%d" % [kind, plan.marker_count(kind), parsed.marker_count(kind) if parsed != null else -1])
	print("%s_REFERENCE_DIFF mismatches=%d manifest_markers=%d parsed_markers=%d unknown_colors=%s markers=%s first=%s" % [label, mismatch_count, plan.markers.size(), parsed.markers.size() if parsed != null else -1, str(unknown_colors), ",".join(marker_summary), "; ".join(first_mismatches)])
