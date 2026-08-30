extends Node
class_name WalkableArea

## World walkability boundary. Tile extraction remains in gameplay while the
## scene-specific geometry is migrated incrementally.

var polygons: Array[PackedVector2Array] = []
var outline := PackedVector2Array()
var points: Array[Vector2] = []
var entrance_block_polygons: Array[PackedVector2Array] = []
# A bounds box per entrance block (grown by the edge margin) plus a union box.
# The per-frame slime walkability path calls is_in_entrance_block for every
# polygon sample, so cheap rect rejects avoid looping every entrance block with
# per-edge checks for points nowhere near a doorway seam.
var entrance_block_bounds: Array[Rect2] = []
var entrance_block_union := Rect2()
var entrance_block_bounds_valid := false
# Prebaked convex floor test. When the outline is convex, these packed half-planes
# let a walkability sample reduce to a handful of dot products over C++-backed
# arrays instead of point-in-polygon plus a per-edge GDScript distance scan.
var outline_planes_ready := false
var outline_plane_normals := PackedVector2Array()
var outline_plane_offsets := PackedFloat32Array()
# Per-entrance-block convex half-planes (packed); a block is tested with dots when
# convex, else falls back to the polygon/edge scan.
var entrance_plane_normals: Array[PackedVector2Array] = []
var entrance_plane_offsets: Array[PackedFloat32Array] = []
var entrance_planes_convex: Array[bool] = []
# Closed doorway polygons are authored against low-resolution tile seams. Keep
# only the original half-pixel edge tolerance so the fence seals the seam
# without making the surrounding room edge feel wider than the art.
const ENTRANCE_BLOCK_EDGE_MARGIN := 0.5
var edge_margin := 0.35
var slime_edge_padding := 0.0


func set_geometry(new_polygons: Array[PackedVector2Array], new_outline: PackedVector2Array) -> void:
	polygons = new_polygons
	outline = new_outline
	points.clear()
	for polygon in polygons:
		for point in polygon:
			points.append(point)
	_prepare_floor_planes()


func collect_geometry(node: Node, tile_polygon: Callable) -> void:
	polygons.clear()
	points.clear()
	if collect_floor_collision_guide(node):
		return
	_collect_tiles(node, tile_polygon)


func _collect_tiles(node: Node, tile_polygon: Callable) -> void:
	for child in node.get_children():
		if child is Sprite2D and child.texture != null:
			var tile := child as Sprite2D
			points.append(tile.to_global(Vector2(8, 4)))
			polygons.append(tile_polygon.call(tile) as PackedVector2Array)
		_collect_tiles(child, tile_polygon)


func collect_floor_collision_guide(node: Node) -> bool:
	var guide := node.get_node_or_null("FloorCollisionGuide") as Node2D
	if guide == null:
		return false
	var local_points := PackedVector2Array()
	if guide is Polygon2D:
		local_points = (guide as Polygon2D).polygon
	elif guide.get("points") != null:
		local_points = guide.get("points")
	if local_points.size() < 3:
		return false
	var polygon := PackedVector2Array()
	var center := Vector2.ZERO
	for point in local_points:
		var global_point := guide.to_global(point)
		polygon.append(global_point)
		points.append(global_point)
		center += global_point
	center /= float(local_points.size())
	points.append(center)
	polygons.append(polygon)
	return true


func build_outline(use_polygon_direct: bool) -> void:
	if polygons.is_empty():
		outline = PackedVector2Array()
		_prepare_floor_planes()
		return
	if use_polygon_direct:
		outline = polygons[0]
		_prepare_floor_planes()
		return
	var all_points := PackedVector2Array()
	for polygon in polygons:
		for point in polygon:
			all_points.append(point)
	outline = Geometry2D.convex_hull(all_points)
	_prepare_floor_planes()


func set_entrance_blocks(new_blocks: Array[PackedVector2Array]) -> void:
	entrance_block_polygons = new_blocks.duplicate()
	entrance_block_bounds_valid = false
	_prepare_floor_planes()


func is_empty() -> bool:
	return polygons.is_empty()


func nearest_point(point: Vector2) -> Vector2:
	if outline.is_empty():
		return point
	var best := point
	var best_distance := INF
	for index in outline.size():
		var candidate := Geometry2D.get_closest_point_to_segment(point, outline[index], outline[(index + 1) % outline.size()])
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best


func is_walkable(point: Vector2) -> bool:
	if is_in_entrance_block(point):
		return false
	if outline.is_empty():
		return false
	return point_inside_outline_with_padding(point, -edge_margin)


func is_slime_walkable(point: Vector2) -> bool:
	if is_in_entrance_block(point) or outline.is_empty():
		return false
	return point_inside_outline_with_padding(point, slime_edge_padding)


func is_in_entrance_block(point: Vector2) -> bool:
	if entrance_block_polygons.is_empty():
		return false
	if not entrance_block_bounds_valid:
		_ensure_entrance_block_bounds()
	if not entrance_block_union.has_point(point):
		return false
	for index in entrance_block_polygons.size():
		if not (entrance_block_bounds[index] as Rect2).has_point(point):
			continue
		if _entrance_block_contains_with_margin(point, index):
			return true
	return false


func _entrance_block_contains_with_margin(point: Vector2, block_index: int) -> bool:
	if entrance_planes_convex[block_index]:
		var normals := entrance_plane_normals[block_index]
		var offsets := entrance_plane_offsets[block_index]
		for i in normals.size():
			if normals[i].dot(point) - offsets[i] < -ENTRANCE_BLOCK_EDGE_MARGIN:
				return false
		return true
	var polygon := entrance_block_polygons[block_index]
	return Geometry2D.is_point_in_polygon(point, polygon) or is_point_too_close_to_polygon_edge(point, polygon, ENTRANCE_BLOCK_EDGE_MARGIN)


func _ensure_entrance_block_bounds() -> void:
	entrance_block_bounds.clear()
	entrance_block_union = Rect2()
	for polygon in entrance_block_polygons:
		var block_bounds := Rect2()
		for point in polygon:
			block_bounds = block_bounds.expand(point)
			entrance_block_union = entrance_block_union.expand(point)
		entrance_block_bounds.append(block_bounds.grow(ENTRANCE_BLOCK_EDGE_MARGIN))
	entrance_block_union = entrance_block_union.grow(ENTRANCE_BLOCK_EDGE_MARGIN)
	entrance_block_bounds_valid = true


## True when `point` is inside the outline by at least `padding` (a negative
## padding allows points just outside, for the player edge tolerance).
func point_inside_outline_with_padding(point: Vector2, padding: float) -> bool:
	if outline_planes_ready:
		for i in outline_plane_offsets.size():
			if outline_plane_normals[i].dot(point) - outline_plane_offsets[i] < padding:
				return false
		return true
	if not Geometry2D.is_point_in_polygon(point, outline):
		return false
	return not is_point_too_close_to_polygon_edge(point, outline, padding)


func _prepare_floor_planes() -> void:
	outline_planes_ready = false
	outline_plane_normals = PackedVector2Array()
	outline_plane_offsets = PackedFloat32Array()
	if outline.size() >= 3 and _is_convex_polygon(outline):
		var outline_planes := _convex_planes_for(outline)
		outline_plane_normals = outline_planes[0] as PackedVector2Array
		outline_plane_offsets = outline_planes[1] as PackedFloat32Array
		outline_planes_ready = true
	entrance_plane_normals.clear()
	entrance_plane_offsets.clear()
	entrance_planes_convex.clear()
	for block in entrance_block_polygons:
		if block.size() >= 3 and _is_convex_polygon(block):
			var block_planes := _convex_planes_for(block)
			entrance_plane_normals.append(block_planes[0] as PackedVector2Array)
			entrance_plane_offsets.append(block_planes[1] as PackedFloat32Array)
			entrance_planes_convex.append(true)
		else:
			entrance_plane_normals.append(PackedVector2Array())
			entrance_plane_offsets.append(PackedFloat32Array())
			entrance_planes_convex.append(false)


func _is_convex_polygon(polygon: PackedVector2Array) -> bool:
	var sign_value := 0
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var c := polygon[(index + 2) % polygon.size()]
		var cross_value := (b - a).cross(c - b)
		if absf(cross_value) < 0.0001:
			continue
		var current_sign := 1 if cross_value > 0.0 else -1
		if sign_value == 0:
			sign_value = current_sign
		elif sign_value != current_sign:
			return false
	return true


func _convex_planes_for(polygon: PackedVector2Array) -> Array:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	center /= float(polygon.size())
	var normals := PackedVector2Array()
	var offsets := PackedFloat32Array()
	for index in polygon.size():
		var a := polygon[index]
		var b := polygon[(index + 1) % polygon.size()]
		var edge := b - a
		if edge.length_squared() < 0.0001:
			continue
		var normal := Vector2(-edge.y, edge.x).normalized()
		if normal.dot(center - a) < 0.0:
			normal = -normal
		normals.append(normal)
		offsets.append(normal.dot(a))
	return [normals, offsets]


func nearest_walkable_point(point: Vector2) -> Vector2:
	if is_walkable(point):
		return point
	var nearest := nearest_point(point)
	if is_walkable(nearest):
		return nearest
	var best := point
	var best_distance := INF
	for candidate in points:
		if not is_walkable(candidate):
			continue
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best if best_distance < INF else nearest


func nearest_slime_walkable_point(point: Vector2) -> Vector2:
	if is_slime_walkable(point):
		return point
	var best := point
	var best_distance := INF
	for candidate in points:
		if not is_slime_walkable(candidate):
			continue
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	if best_distance < INF:
		return best
	var nearest := nearest_walkable_point(point)
	if is_slime_walkable(nearest):
		return nearest
	var center := Vector2.ZERO
	for outline_point in outline:
		center += outline_point
	if not outline.is_empty():
		center /= float(outline.size())
	if is_slime_walkable(center):
		return center
	return nearest


func random_slime_walkable_point_near(point: Vector2, sample_count: int, ignored_slime: Sprite2D, random_source: RandomNumberGenerator, near_other: Callable) -> Vector2:
	var nearest := nearest_slime_walkable_point(point)
	var candidates: Array[Vector2] = []
	var radius := 8.0 * float(sample_count)
	var bounds := Rect2()
	for outline_point in outline: bounds = bounds.expand(outline_point)
	for index in 24:
		var candidate := point + Vector2(random_source.randf_range(-radius, radius), random_source.randf_range(-radius, radius))
		if bounds.has_point(candidate) and is_slime_walkable(candidate) and not near_other.call(candidate, ignored_slime): candidates.append(candidate)
	for walkable_point in points:
		if is_slime_walkable(walkable_point) and not near_other.call(walkable_point, ignored_slime) and walkable_point.distance_to(nearest) <= radius: candidates.append(walkable_point)
	return nearest if candidates.is_empty() else candidates[random_source.randi_range(0, candidates.size() - 1)]


func distance_to_polygon_edge(point: Vector2, polygon: PackedVector2Array) -> float:
	var nearest_distance := INF
	for index in polygon.size():
		var next_index := (index + 1) % polygon.size()
		var segment := polygon[next_index] - polygon[index]
		var length_squared := segment.length_squared()
		var candidate := polygon[index]
		if length_squared > 0.0:
			var amount := clampf((point - polygon[index]).dot(segment) / length_squared, 0.0, 1.0)
			candidate += segment * amount
		nearest_distance = minf(nearest_distance, point.distance_to(candidate))
	return nearest_distance


## Squared-distance edge check with early exit. The walkability padding checks
## only need to know whether a point is closer than `threshold` to any polygon
## edge, so they can avoid the per-edge sqrt and stop at the first close edge.
## This is the hot path for every slime movement frame, so it must stay cheap.
func is_point_too_close_to_polygon_edge(point: Vector2, polygon: PackedVector2Array, threshold: float) -> bool:
	if threshold <= 0.0:
		return false
	var threshold_squared := threshold * threshold
	for index in polygon.size():
		var next_index := (index + 1) % polygon.size()
		var segment := polygon[next_index] - polygon[index]
		var length_squared := segment.length_squared()
		var candidate := polygon[index]
		if length_squared > 0.0:
			var amount := clampf((point - polygon[index]).dot(segment) / length_squared, 0.0, 1.0)
			candidate += segment * amount
		if point.distance_squared_to(candidate) < threshold_squared:
			return true
	return false
