extends RefCounted
class_name PuzzleMapR4

## Authored R4 route-map manifest from Artwork/R4(new)puzzle_map.png.

const GRID_SCRIPT = preload("res://scripts/puzzle_map_grid.gd")

static func build() -> PuzzleMapGrid.MapPlan:
	var plan := PuzzleMapGrid.MapPlan.new(&"r4_new")
	_add_many(plan, GRID_SCRIPT.MARKER_GATE_GREY, [
		Vector2i(16, 10), Vector2i(18, 10), Vector2i(16, 12), Vector2i(14, 14),
		Vector2i(18, 14), Vector2i(20, 14), Vector2i(22, 14), Vector2i(12, 16),
		Vector2i(16, 16), Vector2i(22, 16), Vector2i(12, 18), Vector2i(20, 18),
		Vector2i(12, 20), Vector2i(14, 20), Vector2i(16, 20), Vector2i(20, 20),
		Vector2i(14, 22), Vector2i(18, 22), Vector2i(20, 22), Vector2i(16, 24),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_GATE_ORB_GREY, [
		Vector2i(14, 12), Vector2i(24, 14), Vector2i(22, 22),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_GATE_FLAME_A, [
		Vector2i(22, 12), Vector2i(10, 14), Vector2i(12, 14), Vector2i(16, 14),
		Vector2i(24, 16), Vector2i(18, 18), Vector2i(22, 18), Vector2i(10, 20),
		Vector2i(18, 24),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_GATE_FLAME_B, [
		Vector2i(18, 8), Vector2i(12, 12), Vector2i(10, 16), Vector2i(16, 26),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_TREASURE_ROOM, [
		Vector2i(19, 7), Vector2i(11, 11), Vector2i(23, 11), Vector2i(9, 13),
		Vector2i(19, 15), Vector2i(25, 17), Vector2i(15, 19), Vector2i(23, 19), Vector2i(9, 21), Vector2i(23, 23),
		Vector2i(15, 27),
	])
	_add_many(plan, GRID_SCRIPT.MARKER_ORB_ROOM, [Vector2i(19, 11)])
	_add_many(plan, GRID_SCRIPT.MARKER_FLAME_B_ROOM, [Vector2i(25, 13)])
	plan.add_marker(Vector2i(17, 17), GRID_SCRIPT.MARKER_HUB_ROOM)
	plan.add_marker(Vector2i(9, 17), GRID_SCRIPT.MARKER_BOSS_ROOM)
	return plan


static func _add_many(plan: PuzzleMapGrid.MapPlan, kind: StringName, coordinates: Array[Vector2i]) -> void:
	for coordinate in coordinates:
		plan.add_marker(coordinate, kind)
