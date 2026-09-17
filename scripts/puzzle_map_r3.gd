extends RefCounted
class_name PuzzleMapR3

## The first authored route-map manifest. Its coordinate system is the exact
## 35 x 35 pixel grid in Artwork/puzzle_map.png, so this remains a direct and
## designer-readable transcription of R3 rather than a lossy conversion.
##
## The authored marker grid now lives in
## resources/definitions/puzzle_map_r3.tres (editor-inspectable); this builder
## loads it and assembles the runtime plan. Validation variants remain runtime
## transforms in code.

const DATA := preload("res://resources/definitions/puzzle_map_r3.tres") as PuzzlePlanData


static func build() -> PuzzleMapGrid.MapPlan:
	var plan := _plan_from_data()
	return plan


static func build_validation_variants() -> Array[PuzzleMapGrid.MapPlan]:
	## These cover each swatch exchange without changing the authored R3 source.
	## Later procedural layout work can produce plans through the same renderer.
	var variants: Array[PuzzleMapGrid.MapPlan] = [build()]
	variants.append(_with_replaced_kind(build(), &"r3_flame_a_to_grey", PuzzleMapGrid.MARKER_GATE_FLAME_A, PuzzleMapGrid.MARKER_GATE_ORB_GREY))
	variants.append(_with_replaced_kind(build(), &"r3_flame_a_to_flame_b", PuzzleMapGrid.MARKER_GATE_FLAME_A, PuzzleMapGrid.MARKER_GATE_FLAME_B))
	variants.append(_with_replaced_kind(build(), &"r3_flame_b_to_flame_a", PuzzleMapGrid.MARKER_GATE_FLAME_B, PuzzleMapGrid.MARKER_GATE_FLAME_A))
	return variants


static func _plan_from_data() -> PuzzleMapGrid.MapPlan:
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


static func _with_replaced_kind(plan: PuzzleMapGrid.MapPlan, next_id: StringName, source: StringName, replacement: StringName) -> PuzzleMapGrid.MapPlan:
	var variant := plan.duplicate_plan(next_id)
	for marker in variant.markers:
		if marker.kind == source:
			marker.kind = replacement
	return variant