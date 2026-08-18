@tool
extends Node2D

@export var points: PackedVector2Array = PackedVector2Array():
	set(value):
		points = value
		queue_redraw()

@export var fill_color := Color(0.1, 0.8, 0.35, 0.14):
	set(value):
		fill_color = value
		queue_redraw()

@export var outline_color := Color(0.1, 0.95, 0.35, 0.85):
	set(value):
		outline_color = value
		queue_redraw()

@export var handle_radius := 2.0:
	set(value):
		handle_radius = value
		queue_redraw()


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false


func _draw() -> void:
	if not Engine.is_editor_hint() or points.size() < 3:
		return

	draw_colored_polygon(points, fill_color)
	draw_polyline(_closed_points(), outline_color, 2.0)
	for point in points:
		draw_circle(point, handle_radius, outline_color)
	draw_line(Vector2(-4, 0), Vector2(4, 0), outline_color, 1.0)
	draw_line(Vector2(0, -4), Vector2(0, 4), outline_color, 1.0)


func _closed_points() -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed
