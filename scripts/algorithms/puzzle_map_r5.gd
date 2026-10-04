extends RefCounted
class_name PuzzleMapR5

## The fifth authored route-map manifest. Like R4 it uses the exact
## 35 x 35 pixel grid in Artwork/puzzle_map.png, so this is a direct and
## designer-readable transcription of Artwork/R5puzzle_map.png rather than a
## lossy conversion.
##
## The authored marker grid now lives in
## resources/definitions/puzzle_map_r5.tres (editor-inspectable); this builder
## loads it and assembles the runtime plan.

const DATA := preload("res://resources/definitions/puzzle_map_r5.tres") as PuzzlePlanData


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