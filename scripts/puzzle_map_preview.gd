extends Node2D

## Design-only viewer for grid-map manifests. Run the matching scene directly
## from Godot; this is intentionally not part of the gameplay scene tree.

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const R3_SCRIPT = preload("res://scripts/puzzle_map_r3.gd")
const TEMPLATE_PATH := "res://Artwork/puzzle_map.png"
const MAP_SCALE := 2.0
const MAP_SIZE := Vector2(35.0, 35.0) * MAP_SCALE
const MAP_ORIGINS := [Vector2(4.0, 16.0), Vector2(126.0, 16.0), Vector2(4.0, 90.0), Vector2(126.0, 90.0)]
const LABELS := ["R3", "A -> GREY", "A -> B", "B -> A"]

var map_textures: Array[Texture2D] = []


func _ready() -> void:
	var template := Image.load_from_file(ProjectSettings.globalize_path(TEMPLATE_PATH))
	if template == null:
		push_error("Puzzle-map preview could not load %s." % TEMPLATE_PATH)
		return
	var plans: Array[PuzzleMapGrid.MapPlan] = R3_SCRIPT.build_validation_variants()
	for plan in plans:
		var image := GRID_SCRIPT.render_preview(plan, template)
		if image != null:
			map_textures.append(ImageTexture.create_from_image(image))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(240.0, 160.0)), PuzzleMapGrid.COLOR_BACKGROUND)
	draw_string(ThemeDB.fallback_font, Vector2(5.0, 7.0), "PUZZLE MAP GENERATOR", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 6, Color8(239, 242, 247))
	for index in min(map_textures.size(), MAP_ORIGINS.size()):
		var origin: Vector2 = MAP_ORIGINS[index]
		draw_string(ThemeDB.fallback_font, origin + Vector2(0.0, -2.0), LABELS[index], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 5, Color8(159, 169, 187))
		draw_texture_rect(map_textures[index], Rect2(origin, MAP_SIZE), false)
