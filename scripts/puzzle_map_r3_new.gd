extends RefCounted
class_name PuzzleMapR3New

## Simpler authored R3 map from Artwork/R3(new)puzzle_map.png.

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")

static func build() -> PuzzleMapGrid.MapPlan:
	var plan := PuzzleMapGrid.MapPlan.new(&"r3_simple")
	_add_many(plan, GRID_SCRIPT.MARKER_GATE_GREY, [
		Vector2i(28, 12), Vector2i(20, 14), Vector2i(22, 14), Vector2i(28, 14),
		Vector2i(30, 14), Vector2i(30, 16), Vector2i(28, 18), Vector2i(14, 20),
		Vector2i(16, 20), Vector2i(20, 20), Vector2i(14, 22), Vector2i(18, 22),
		Vector2i(20, 24), Vector2i(22, 24),
		# Recovery Fire Room branch: (12,18) links the added room at (11,19)
		# to the existing lower-left route, including every quarter-turn.
		Vector2i(12, 18),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_GATE_FLAME_A, [
		Vector2i(26, 10), Vector2i(26, 14), Vector2i(16, 18), Vector2i(18, 18),
		Vector2i(24, 18), Vector2i(22, 20), Vector2i(26, 20), Vector2i(24, 22),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_GATE_ORB_GREY, [
		Vector2i(28, 10), Vector2i(18, 16), Vector2i(24, 16), Vector2i(26, 16),
		Vector2i(32, 16), Vector2i(22, 18), Vector2i(26, 18), Vector2i(30, 18),
		Vector2i(24, 20), Vector2i(28, 20), Vector2i(26, 22), Vector2i(28, 22),
		Vector2i(20, 26), Vector2i(22, 26),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_TREASURE_ROOM, [
		Vector2i(29, 9), Vector2i(25, 13), Vector2i(21, 17), Vector2i(33, 17),
		Vector2i(15, 19), Vector2i(31, 19), Vector2i(19, 27), Vector2i(23, 27),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_ORB_ROOM, [Vector2i(25, 17), Vector2i(15, 23)])
	# The added Fire Room at the lower-left branch guarantees a mana recovery
	# option on the authored R3 route. Its marker is mirrored by the
	# R3(new)puzzle_map_ex.png reference image.
	plan.add_marker(Vector2i(11, 19), GRID_SCRIPT.MARKER_FLAME_B_ROOM)
	plan.add_marker(Vector2i(17, 17), GRID_SCRIPT.MARKER_HUB_ROOM)
	plan.add_marker(Vector2i(25, 9), GRID_SCRIPT.MARKER_BOSS_ROOM)
	return plan


static func _add_many(plan: PuzzleMapGrid.MapPlan, kind: StringName, coordinates: Array[Vector2i]) -> void:
	for coordinate in coordinates:
		plan.add_marker(coordinate, kind)


static func build_validation_variants() -> Array[PuzzleMapGrid.MapPlan]:
	return [build()]
