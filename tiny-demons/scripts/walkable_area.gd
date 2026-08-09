extends Node
class_name WalkableArea

## World walkability boundary. Tile extraction remains in gameplay during M5.

var polygons: Array[PackedVector2Array] = []
var outline := PackedVector2Array()


func set_geometry(new_polygons: Array[PackedVector2Array], new_outline: PackedVector2Array) -> void:
	polygons = new_polygons
	outline = new_outline


func is_empty() -> bool:
	return polygons.is_empty()


func nearest_point(point: Vector2) -> Vector2:
	if polygons.is_empty():
		return point
	var best := point
	var best_distance := INF
	for polygon in polygons:
		for index in polygon.size():
			var candidate := Geometry2D.get_closest_point_to_segment(point, polygon[index], polygon[(index + 1) % polygon.size()])
			var distance := point.distance_squared_to(candidate)
			if distance < best_distance:
				best_distance = distance
				best = candidate
	return best
