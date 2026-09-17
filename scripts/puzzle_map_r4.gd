extends RefCounted
class_name PuzzleMapR4

## Authored R4 route-map manifest from Artwork/R4(new)puzzle_map.png.
##
## The authored marker grid now lives in
## resources/definitions/puzzle_map_r4.tres (editor-inspectable); this builder
## loads it and assembles the runtime plan.

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")
const DATA := preload("res://resources/definitions/puzzle_map_r4.tres") as PuzzlePlanData


static func build() -> PuzzleMapGrid.MapPlan:
	var plan := PuzzleMapGrid.MapPlan.new(DATA.plan_id)
	for entry in DATA.markers:
		var marker := entry as Dictionary
		plan.add_marker(marker["coordinate"] as Vector2i, marker["kind"] as StringName)
	for tile in DATA.active_tiles:
		plan.add_active_tile(tile)
	plan.generation_mode = DATA.generation_mode
	if not DATA.logical_edges.is_empty():
		plan.logical_edges = DATA.logical_edges
	return plan