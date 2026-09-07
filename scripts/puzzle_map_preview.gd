extends Node2D

## Design-only viewer for grid-map manifests. Run the matching scene directly
## from Godot; this is intentionally not part of the gameplay scene tree.

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const R3_SCRIPT = preload("res://scripts/puzzle_map_r3_new.gd")
const R4_SCRIPT = preload("res://scripts/puzzle_map_r4.gd")
const R5_SCRIPT = preload("res://scripts/puzzle_map_r5.gd")
const TEMPLATE_PATH := "res://Artwork/puzzle_map.png"
const MAP_SCALE := 2.0
const MAP_SIZE := Vector2(35.0, 35.0) * MAP_SCALE

var map_textures: Array[Texture2D] = []


func _ready() -> void:
	var template := Image.load_from_file(ProjectSettings.globalize_path(TEMPLATE_PATH))
	if template == null:
		push_error("Puzzle-map preview could not load %s." % TEMPLATE_PATH)
		return
	var plans: Array[PuzzleMapGrid.MapPlan] = R3_SCRIPT.build_validation_variants()
	plans.append(R4_SCRIPT.build())
	plans.append(R5_SCRIPT.build())
	for plan in plans:
		var image := GRID_SCRIPT.render_preview(plan, template)
		if image != null:
			map_textures.append(ImageTexture.create_from_image(image))
	queue_redraw()


func _draw() -> void:
	var columns := 5
	var origin_x := 4.0
	var origin_y := 16.0
	var label_height := 8.0
	var spacing := 2.0
	var rows := ceili(float(map_textures.size()) / float(columns))
	draw_rect(Rect2(Vector2.ZERO, Vector2(origin_x * 2 + columns * MAP_SIZE.x + (columns - 1) * spacing, origin_y + rows * (label_height + MAP_SIZE.y + spacing) + 8.0)), PuzzleMapGrid.COLOR_BACKGROUND)
	draw_string(ThemeDB.fallback_font, Vector2(5.0, 7.0), "PUZZLE MAP GENERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, Color8(239, 242, 247))
	var labels: Array[String] = ["R3", "R4", "R5", "R6"]
	for index in map_textures.size():
		var column := index % columns
		var row := index / columns
		var origin := Vector2(origin_x + column * (MAP_SIZE.x + spacing), origin_y + row * (label_height + MAP_SIZE.y + spacing))
		draw_string(ThemeDB.fallback_font, origin + Vector2(0.0, -2.0), labels[index] if index < labels.size() else "MAP", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5, Color8(159, 169, 187))
		draw_texture_rect(map_textures[index], Rect2(origin, MAP_SIZE), false)
