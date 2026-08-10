extends Node
class_name WalkableArea

## World walkability boundary. Tile extraction remains in gameplay while the
## scene-specific geometry is migrated incrementally.

var polygons: Array[PackedVector2Array] = []
var outline := PackedVector2Array()
var points: Array[Vector2] = []
var entrance_block_polygons: Array[PackedVector2Array] = []
var edge_margin := 0.35
var slime_edge_padding := 3.0


func set_geometry(new_polygons: Array[PackedVector2Array], new_outline: PackedVector2Array) -> void:
	polygons = new_polygons
	outline = new_outline
	points.clear()
	for polygon in polygons:
		for point in polygon:
			points.append(point)


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
		if Geometry2D.is_point_in_polygon(point, polygon):
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
	var best := nearest_walkable_point(point)
	var best_distance := point.distance_squared_to(best)
	for candidate in points:
		if not is_slime_walkable(candidate):
			continue
		var distance := point.distance_squared_to(candidate)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


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
