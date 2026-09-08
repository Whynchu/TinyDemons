extends SceneTree

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const R5_SCRIPT = preload("res://scripts/puzzle_map_r5.gd")


func _initialize() -> void:
	var template := Image.load_from_file(ProjectSettings.globalize_path("res://Artwork/puzzle_map.png"))
	var plan = R5_SCRIPT.build()
	var rendered := GRID_SCRIPT.render_preview(plan, template)
	if rendered == null:
		push_error("Unable to render the R5 manifest reference.")
		quit(1)
		return
	var output_path := ProjectSettings.globalize_path("res://Artwork/R5puzzle_map.png")
	var error := rendered.save_png(output_path)
	if error != OK:
		push_error("Unable to write R5 reference: %s" % error)
		quit(1)
		return
	print("R5_REFERENCE_REBUILT: %s" % output_path)
	quit(0)
