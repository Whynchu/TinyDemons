extends Node2D
class_name EnemyTargetArc

const ARC_CORE := Color8(112, 255, 151, 245)
const ARC_HIGHLIGHT := Color8(210, 255, 216, 255)

const MIN_ARC_HEIGHT := 3.0
const MAX_ARC_HEIGHT := 8.0
const PIXEL_STEP := 0.5
const CAST_WORLD_Z_LIMIT := 4088

var source_anchor: Node2D
var target_anchor: Node2D
var source_offset := Vector2.ZERO
var target_offset := Vector2.ZERO
var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var elapsed := 0.0
var finishing := false
var fade_remaining := 0.0
var fade_duration := 0.0


func configure(source: Node2D, target: Node2D, source_world_point: Vector2, target_world_point: Vector2) -> void:
	source_anchor = source
	target_anchor = target
	source_offset = source_world_point - source.global_position
	target_offset = target_world_point - target.global_position
	_update_anchor_points()
	queue_redraw()


func finish(cancelled: bool = false) -> void:
	finishing = true
	fade_duration = 0.12 if cancelled else 0.20
	fade_remaining = fade_duration


func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	_update_anchor_points()
	if finishing:
		fade_remaining = maxf(fade_remaining - maxf(delta, 0.0), 0.0)
		modulate.a = fade_remaining / maxf(fade_duration, 0.001)
		if fade_remaining <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var points := _build_arc_points()
	if points.size() < 2:
		return
	draw_polyline(points, ARC_CORE, 1.0, false)
	_draw_traveling_sparks()
	_draw_target_marker()


func _update_anchor_points() -> void:
	if source_anchor != null and is_instance_valid(source_anchor):
		start_point = (source_anchor.global_position + source_offset).round()
	if target_anchor != null and is_instance_valid(target_anchor):
		end_point = (target_anchor.global_position + target_offset).round()
	if source_anchor != null and is_instance_valid(source_anchor) and target_anchor != null and is_instance_valid(target_anchor):
		z_index = mini(maxi(source_anchor.z_index, target_anchor.z_index) + 1, CAST_WORLD_Z_LIMIT)


func _build_arc_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	var distance := start_point.distance_to(end_point)
	if distance <= 0.5:
		return points
	var height := clampf(distance * 0.14, MIN_ARC_HEIGHT, MAX_ARC_HEIGHT)
	var control := (start_point + end_point) * 0.5 + Vector2(0.0, -height * 2.0)
	var sample_count := clampi(ceili(distance / PIXEL_STEP), 12, 128)
	for sample in range(sample_count + 1):
		var t := float(sample) / float(sample_count)
		var inverse_t := 1.0 - t
		var point := start_point * inverse_t * inverse_t + control * 2.0 * inverse_t * t + end_point * t * t
		var pixel_point := point.round()
		if points.is_empty() or points[points.size() - 1] != pixel_point:
			points.append(pixel_point)
	return points


func _point_on_arc(t: float) -> Vector2:
	var height := clampf(start_point.distance_to(end_point) * 0.14, MIN_ARC_HEIGHT, MAX_ARC_HEIGHT)
	var control := (start_point + end_point) * 0.5 + Vector2(0.0, -height * 2.0)
	var inverse_t := 1.0 - t
	return (start_point * inverse_t * inverse_t + control * 2.0 * inverse_t * t + end_point * t * t).round()


func _draw_traveling_sparks() -> void:
	var phase := fposmod(elapsed * 0.52, 1.0)
	for spark_index in 2:
		var t := fposmod(phase + float(spark_index) * 0.5, 1.0)
		var point := _point_on_arc(t)
		draw_rect(Rect2(point, Vector2.ONE), ARC_HIGHLIGHT)


func _draw_target_marker() -> void:
	var center := end_point
	var marker := ARC_HIGHLIGHT
	var offsets := [Vector2(0.0, -2.0), Vector2(2.0, 0.0), Vector2(0.0, 2.0), Vector2(-2.0, 0.0)]
	for offset in offsets:
		draw_rect(Rect2(center + offset, Vector2.ONE), marker)
	draw_rect(Rect2(center, Vector2.ONE), ARC_CORE)
