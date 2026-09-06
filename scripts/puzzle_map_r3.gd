extends RefCounted
class_name PuzzleMapR3

## The first authored route-map manifest.  Its coordinate system is the exact
## 35 x 35 pixel grid in Artwork/puzzle_map.png, so this remains a direct and
## designer-readable transcription of R3 rather than a lossy conversion.

static func build() -> PuzzleMapGrid.MapPlan:
	var plan := PuzzleMapGrid.MapPlan.new(&"r3_grey_flame_a_flame_b")
	_add_many(plan, PuzzleMapGrid.MARKER_GATE_GREY, [
		Vector2i(10, 4), Vector2i(12, 4), Vector2i(16, 4),
		Vector2i(8, 6), Vector2i(16, 6),
		Vector2i(6, 8), Vector2i(10, 8), Vector2i(12, 8), Vector2i(16, 8),
		Vector2i(4, 10), Vector2i(18, 10),
		Vector2i(8, 12), Vector2i(18, 12), Vector2i(26, 12),
		Vector2i(14, 14), Vector2i(16, 14), Vector2i(20, 14), Vector2i(24, 14),
		Vector2i(10, 16), Vector2i(16, 16),
		Vector2i(8, 18), Vector2i(16, 18),
		Vector2i(8, 20), Vector2i(14, 20),
		Vector2i(10, 22), Vector2i(12, 22),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_GATE_FLAME_A, [
		Vector2i(18, 6), Vector2i(14, 8), Vector2i(8, 10), Vector2i(12, 12),
		Vector2i(22, 12), Vector2i(6, 14), Vector2i(8, 16), Vector2i(12, 20),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_GATE_FLAME_B, [
		Vector2i(14, 6), Vector2i(4, 12), Vector2i(14, 12), Vector2i(18, 16),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_TREASURE_ROOM, [
		Vector2i(11, 3), Vector2i(19, 7), Vector2i(3, 11), Vector2i(11, 11),
		Vector2i(15, 11), Vector2i(23, 11), Vector2i(7, 15), Vector2i(11, 19),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_GATE_ORB_GREY, [
		Vector2i(6, 12), Vector2i(10, 14), Vector2i(12, 14), Vector2i(22, 14),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_FLAME_B_ROOM, [Vector2i(11, 7), Vector2i(25, 13)])
	_add_many(plan, PuzzleMapGrid.MARKER_ORB_ROOM, [Vector2i(5, 13), Vector2i(21, 13)])
	_add_many(plan, PuzzleMapGrid.MARKER_CLOAKED_ROOM, [Vector2i(7, 7)])
	plan.add_marker(Vector2i(17, 17), PuzzleMapGrid.MARKER_HUB_ROOM)
	plan.add_marker(Vector2i(27, 11), PuzzleMapGrid.MARKER_BOSS_ROOM)
	return plan


static func build_validation_variants() -> Array[PuzzleMapGrid.MapPlan]:
	## These cover each swatch exchange without changing the authored R3 source.
	## Later procedural layout work can produce plans through the same renderer.
	var variants: Array[PuzzleMapGrid.MapPlan] = [build()]
	variants.append(_with_replaced_kind(build(), &"r3_flame_a_to_grey", PuzzleMapGrid.MARKER_GATE_FLAME_A, PuzzleMapGrid.MARKER_GATE_ORB_GREY))
	variants.append(_with_replaced_kind(build(), &"r3_flame_a_to_flame_b", PuzzleMapGrid.MARKER_GATE_FLAME_A, PuzzleMapGrid.MARKER_GATE_FLAME_B))
	variants.append(_with_replaced_kind(build(), &"r3_flame_b_to_flame_a", PuzzleMapGrid.MARKER_GATE_FLAME_B, PuzzleMapGrid.MARKER_GATE_FLAME_A))
	return variants


static func _add_many(plan: PuzzleMapGrid.MapPlan, kind: StringName, coordinates: Array[Vector2i]) -> void:
	for coordinate in coordinates:
		plan.add_marker(coordinate, kind)


static func _with_replaced_kind(plan: PuzzleMapGrid.MapPlan, next_id: StringName, source: StringName, replacement: StringName) -> PuzzleMapGrid.MapPlan:
	var variant := plan.duplicate_plan(next_id)
	for marker in variant.markers:
		if marker.kind == source:
			marker.kind = replacement
	return variant
