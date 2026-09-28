extends Node2D
class_name EnemyTargetArc

const ARC_CORE := Color8(112, 255, 151, 176)
const ARC_HIGHLIGHT := Color8(210, 255, 216, 232)

const MIN_ARC_HEIGHT := 3.0
const MAX_ARC_HEIGHT := 8.0
const PIXEL_SAMPLES_PER_WORLD_PIXEL := 2.0
const CAST_WORLD_Z_LIMIT := 4088
const ACTOR_FOOT_OFFSET := Vector2(8.0, 13.0)

var source_anchor: Node2D
var target_anchor: Node2D
var occlusion_renderer: OcclusionRenderer
var target_highlight: Sprite2D
var source_offset := Vector2.ZERO
var target_offset := Vector2.ZERO
var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var target_outline_pixels := PackedVector2Array()
var elapsed := 0.0
var finishing := false
var fade_remaining := 0.0
var fade_duration := 0.0


func configure(source: Node2D, target: Node2D, source_world_point: Vector2, target_world_point: Vector2, renderer: OcclusionRenderer) -> void:
	source_anchor = source
	target_anchor = target
	occlusion_renderer = renderer
	source_offset = source_world_point - source.global_position
	target_offset = target_world_point - target.global_position
	_attach_target_highlight()
	_update_anchor_points()
	queue_redraw()


func finish(cancelled: bool = false) -> void:
	finishing = true
	fade_duration = 0.12 if cancelled else 0.20
	fade_remaining = fade_duration


func _process(delta: float) -> void:
	elapsed += maxf(delta, 0.0)
	_update_anchor_points()
	_sync_target_highlight()
	if finishing:
		fade_remaining = maxf(fade_remaining - maxf(delta, 0.0), 0.0)
		modulate.a = fade_remaining / maxf(fade_duration, 0.001)
		if target_highlight != null and is_instance_valid(target_highlight):
			target_highlight.modulate.a = modulate.a
		if fade_remaining <= 0.0:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var points := _build_arc_points()
	for point in points:
		draw_rect(Rect2(to_local(point), Vector2.ONE), ARC_CORE)
	_draw_traveling_sparks(points)
	_draw_target_glimmers()
	_draw_target_marker()


func _update_anchor_points() -> void:
	if source_anchor == null or not is_instance_valid(source_anchor) or target_anchor == null or not is_instance_valid(target_anchor):
		target_outline_pixels.clear()
		return
	var source_polygon := _actor_body_polygon(source_anchor)
	var target_polygon := _actor_body_polygon(target_anchor)
	var source_center := source_anchor.global_position + source_offset
	var target_center := target_anchor.global_position + target_offset
	if source_polygon.size() >= 3:
		source_center = ActorGeometry.polygon_center(source_polygon)
	if target_polygon.size() >= 3:
		target_center = ActorGeometry.polygon_center(target_polygon)
	target_outline_pixels = _rasterize_closed_polygon(target_polygon)
	var direction := target_center - source_center
	if direction.length_squared() <= 0.001:
		direction = Vector2.RIGHT
	else:
		direction = direction.normalized()
	if source_anchor == target_anchor:
		start_point = source_center.round()
		end_point = target_center.round()
	else:
		start_point = _polygon_edge_point(source_polygon, source_center, direction).round()
		end_point = _polygon_edge_point(target_polygon, target_center, -direction).round()
	z_index = mini(maxi(source_anchor.z_index, target_anchor.z_index) + 1, CAST_WORLD_Z_LIMIT)


func _attach_target_highlight() -> void:
	var target := target_anchor as Sprite2D
	if target == null or not is_instance_valid(target) or occlusion_renderer == null:
		return
	target_highlight = Sprite2D.new()
	target_highlight.name = "SupportTargetHighlight"
	target_highlight.centered = target.centered
	target_highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	target_highlight.show_behind_parent = true
	target_highlight.z_as_relative = true
	target_highlight.z_index = -1
	target_highlight.material = target.material
	target.add_child(target_highlight)
	_sync_target_highlight()


func _sync_target_highlight() -> void:
	var target := target_anchor as Sprite2D
	if target_highlight == null or not is_instance_valid(target_highlight) or target == null or not is_instance_valid(target):
		return
	target_highlight.texture = occlusion_renderer.highlighted_texture_for_actor(target) if occlusion_renderer != null else null
	target_highlight.centered = target.centered
	target_highlight.offset = target.offset
	target_highlight.flip_h = target.flip_h
	target_highlight.flip_v = target.flip_v
	target_highlight.texture_filter = target.texture_filter
	target_highlight.material = target.material
	target_highlight.self_modulate = target.self_modulate
	target_highlight.visible = target.visible and target_highlight.texture != null
	if not finishing:
		target_highlight.modulate.a = 1.0


func _exit_tree() -> void:
	if target_highlight != null and is_instance_valid(target_highlight):
		target_highlight.queue_free()


func _actor_body_polygon(actor: Node2D) -> PackedVector2Array:
	var sprite := actor as Sprite2D
	if sprite == null:
		return PackedVector2Array()
	var polygon := ActorGeometry.body_polygon(sprite, ACTOR_FOOT_OFFSET)
	if polygon.size() >= 3:
		return polygon
	var rect := sprite.get_rect()
	if not rect.has_area():
		return PackedVector2Array()
	var fallback := PackedVector2Array()
	for local_point in [rect.position, rect.position + Vector2(rect.size.x, 0.0), rect.end, rect.position + Vector2(0.0, rect.size.y)]:
		fallback.append(sprite.to_global(local_point))
	return fallback


func _polygon_edge_point(polygon: PackedVector2Array, origin: Vector2, direction: Vector2) -> Vector2:
	if polygon.size() < 3:
		return origin + direction * 8.0
	var nearest_distance := INF
	for index in polygon.size():
		var edge_start := polygon[index]
		var edge := polygon[(index + 1) % polygon.size()] - edge_start
		var denominator := direction.cross(edge)
		if absf(denominator) <= 0.0001:
			continue
		var start_delta := edge_start - origin
		var ray_distance := start_delta.cross(edge) / denominator
		var edge_progress := start_delta.cross(direction) / denominator
		if ray_distance < 0.0 or edge_progress < -0.0001 or edge_progress > 1.0001:
			continue
		nearest_distance = minf(nearest_distance, ray_distance)
	if is_finite(nearest_distance):
		return origin + direction * (nearest_distance + 0.5)
	return origin


func _rasterize_closed_polygon(polygon: PackedVector2Array) -> PackedVector2Array:
	var pixels := PackedVector2Array()
	if polygon.size() < 3:
		return pixels
	for index in polygon.size():
		var edge_start := polygon[index]
		var edge_end := polygon[(index + 1) % polygon.size()]
		var sample_count := maxi(ceili(edge_start.distance_to(edge_end) * PIXEL_SAMPLES_PER_WORLD_PIXEL), 1)
		for sample in range(sample_count + 1):
			var point := edge_start.lerp(edge_end, float(sample) / float(sample_count)).round()
			if pixels.is_empty() or pixels[pixels.size() - 1] != point:
				pixels.append(point)
	return pixels


func _build_arc_points() -> PackedVector2Array:
	var points := PackedVector2Array()
	if source_anchor == target_anchor:
		return points
	var distance := start_point.distance_to(end_point)
	if distance <= 0.5:
		return points
	var height := clampf(distance * 0.14, MIN_ARC_HEIGHT, MAX_ARC_HEIGHT)
	var control := (start_point + end_point) * 0.5 + Vector2(0.0, -height * 2.0)
	var sample_count := clampi(ceili(distance * PIXEL_SAMPLES_PER_WORLD_PIXEL), 12, 1024)
	for sample in range(sample_count + 1):
		var t := float(sample) / float(sample_count)
		var inverse_t := 1.0 - t
		var point := start_point * inverse_t * inverse_t + control * 2.0 * inverse_t * t + end_point * t * t
		var pixel_point := point.round()
		if points.is_empty() or points[points.size() - 1] != pixel_point:
			points.append(pixel_point)
	return points


func _draw_traveling_sparks(points: PackedVector2Array) -> void:
	if points.is_empty():
		return
	var phase := fposmod(elapsed * 0.52, 1.0)
	for spark_index in 2:
		var t := fposmod(phase + float(spark_index) * 0.5, 1.0)
		var point_index := clampi(roundi(t * float(points.size() - 1)), 0, points.size() - 1)
		draw_rect(Rect2(to_local(points[point_index]), Vector2.ONE), ARC_HIGHLIGHT)


func _draw_target_glimmers() -> void:
	if target_outline_pixels.is_empty():
		return
	var phase := fposmod(elapsed * 0.68, 1.0)
	for glimmer_index in 2:
		var t := fposmod(phase + float(glimmer_index) * 0.5, 1.0)
		var point_index := clampi(floori(t * float(target_outline_pixels.size())), 0, target_outline_pixels.size() - 1)
		draw_rect(Rect2(to_local(target_outline_pixels[point_index]), Vector2.ONE), ARC_HIGHLIGHT)


func _draw_target_marker() -> void:
	if source_anchor == target_anchor:
		return
	var center := end_point
	var marker := ARC_HIGHLIGHT
	var offsets := [Vector2(0.0, -2.0), Vector2(2.0, 0.0), Vector2(0.0, 2.0), Vector2(-2.0, 0.0)]
	for offset in offsets:
		draw_rect(Rect2(to_local((center + offset).round()), Vector2.ONE), marker)
	draw_rect(Rect2(to_local(center), Vector2.ONE), ARC_CORE)
