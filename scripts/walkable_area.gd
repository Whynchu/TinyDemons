extends Node
class_name WalkableArea

## World walkability boundary. Tile extraction remains in gameplay while the
## scene-specific geometry is migrated incrementally.

var polygons: Array[PackedVector2Array] = []
var outline := PackedVector2Array()
var points: Array[Vector2] = []
var entrance_block_polygons: Array[PackedVector2Array] = []
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
		return
	if use_polygon_direct:
		outline = polygons[0]
		return
	var all_points := PackedVector2Array()
	for polygon in polygons:
		for point in polygon:
			all_points.append(point)
	outline = Geometry2D.convex_hull(all_points)


func set_entrance_blocks(new_blocks: Array[PackedVector2Array]) -> void:
	entrance_block_polygons = new_blocks.duplicate()


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
	return Geometry2D.is_point_in_polygon(point, outline) or distance_to_polygon_edge(point, outline) <= edge_margin


func is_slime_walkable(point: Vector2) -> bool:
	if is_in_entrance_block(point) or outline.is_empty():
		return false
	return Geometry2D.is_point_in_polygon(point, outline) and distance_to_polygon_edge(point, outline) >= slime_edge_padding


func is_in_entrance_block(point: Vector2) -> bool:
	for polygon in entrance_block_polygons:
		if Geometry2D.is_point_in_polygon(point, polygon) or distance_to_polygon_edge(point, polygon) <= ENTRANCE_BLOCK_EDGE_MARGIN:
			return true
	return false


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
