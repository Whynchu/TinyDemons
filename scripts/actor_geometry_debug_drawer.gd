extends Node2D
class_name ActorGeometryDebugDrawer

## Opt-in world-space diagnostic overlay for actor transform ownership.
## Disabled by default and refreshed by the existing frame schedule.

var enabled := false
var actors: Array[Sprite2D] = []
var foot_callable := Callable()
var collision_rect_callable := Callable()
var body_polygon_callable := Callable()


func configure(actor_list: Array[Sprite2D], foot: Callable, collision_rect: Callable, body_polygon: Callable) -> void:
	actors = actor_list
	foot_callable = foot
	collision_rect_callable = collision_rect
	body_polygon_callable = body_polygon
	visible = enabled


func refresh() -> void:
	if not enabled:
		visible = false
		return
	visible = true
	queue_redraw()


func _draw() -> void:
	if not enabled:
		return
	for actor in actors:
		if not is_instance_valid(actor) or not actor.visible:
			continue
		var foot := foot_callable.call(actor) as Vector2
		draw_circle(to_local(foot), 2.0, Color8(255, 226, 92, 230))
		var bounds := collision_rect_callable.call(actor) as Rect2
		draw_rect(Rect2(to_local(bounds.position), bounds.size), Color8(92, 205, 255, 210), false, 1.0)
		var polygon := body_polygon_callable.call(actor) as PackedVector2Array
		if polygon.size() >= 3:
			var points := PackedVector2Array()
			for point in polygon:
				points.append(to_local(point))
			points.append(points[0])
			draw_polyline(points, Color8(255, 112, 112, 230), 1.0)
