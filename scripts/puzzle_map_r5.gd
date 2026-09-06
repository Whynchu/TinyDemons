extends RefCounted
class_name PuzzleMapR5

## The fifth authored route-map manifest. Like R4 it uses the exact
## 35 x 35 pixel grid in Artwork/puzzle_map.png, so this is a direct and
## designer-readable transcription of Artwork/R5puzzle_map.png rather than a
## lossy conversion.

static func build() -> PuzzleMapGrid.MapPlan:
	var plan := PuzzleMapGrid.MapPlan.new(&"r4")
	_add_many(plan, PuzzleMapGrid.MARKER_GATE_GREY, [
		Vector2i(16, 2), Vector2i(18, 2), Vector2i(14, 4), Vector2i(20, 4),
		Vector2i(12, 6), Vector2i(22, 6), Vector2i(14, 8), Vector2i(16, 8),
		Vector2i(24, 8), Vector2i(10, 10), Vector2i(14, 10), Vector2i(18, 10),
		Vector2i(24, 10), Vector2i(26, 10), Vector2i(6, 12), Vector2i(8, 12),
		Vector2i(12, 12), Vector2i(28, 12), Vector2i(32, 12), Vector2i(4, 14),
		Vector2i(14, 14), Vector2i(20, 14), Vector2i(32, 14), Vector2i(2, 16),
		Vector2i(26, 16), Vector2i(32, 16), Vector2i(2, 18), Vector2i(12, 18),
		Vector2i(32, 18), Vector2i(4, 20), Vector2i(14, 20), Vector2i(20, 20),
		Vector2i(24, 20), Vector2i(30, 20), Vector2i(6, 22), Vector2i(12, 22),
		Vector2i(22, 22), Vector2i(24, 22), Vector2i(28, 22), Vector2i(8, 24),
		Vector2i(10, 24), Vector2i(24, 24), Vector2i(16, 26), Vector2i(18, 26),
		Vector2i(12, 28), Vector2i(14, 28), Vector2i(22, 28), Vector2i(26, 28),
		Vector2i(14, 30), Vector2i(20, 30), Vector2i(24, 30), Vector2i(16, 32),
		Vector2i(18, 32),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_GATE_ORB_GREY, [
		Vector2i(18, 4), Vector2i(10, 8), Vector2i(22, 12), Vector2i(10, 14),
		Vector2i(22, 14), Vector2i(30, 14), Vector2i(4, 16), Vector2i(16, 16),
		Vector2i(18, 18), Vector2i(18, 24), Vector2i(24, 26),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_TREASURE_ROOM, [
		Vector2i(17, 5), Vector2i(15, 11), Vector2i(11, 15), Vector2i(23, 15),
		Vector2i(5, 17), Vector2i(13, 17), Vector2i(21, 17), Vector2i(15, 23),
		Vector2i(19, 23), Vector2i(13, 25), Vector2i(27, 27), Vector2i(17, 29),
		Vector2i(23, 31),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_GATE_FLAME_A, [
		Vector2i(14, 6), Vector2i(8, 10), Vector2i(20, 12), Vector2i(28, 14),
		Vector2i(18, 16), Vector2i(16, 18), Vector2i(26, 24), Vector2i(10, 26),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_GATE_FLAME_B, [
		Vector2i(22, 8), Vector2i(20, 10), Vector2i(18, 12), Vector2i(30, 12),
		Vector2i(16, 14), Vector2i(14, 16), Vector2i(30, 16), Vector2i(22, 18),
		Vector2i(12, 20), Vector2i(14, 22), Vector2i(16, 24), Vector2i(12, 26),
		Vector2i(26, 26), Vector2i(20, 28), Vector2i(16, 30), Vector2i(22, 30),
	])
	_add_many(plan, PuzzleMapGrid.MARKER_ORB_ROOM, [Vector2i(9, 9), Vector2i(25, 25)])
	_add_many(plan, PuzzleMapGrid.MARKER_FLAME_B_ROOM, [Vector2i(25, 17)])
	plan.add_marker(Vector2i(17, 17), PuzzleMapGrid.MARKER_HUB_ROOM)
	plan.add_marker(Vector2i(29, 17), PuzzleMapGrid.MARKER_BOSS_ROOM)
	return plan


static func _add_many(plan: PuzzleMapGrid.MapPlan, kind: StringName, coordinates: Array[Vector2i]) -> void:
	for coordinate in coordinates:
		plan.add_marker(coordinate, kind)
