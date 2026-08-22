extends SceneTree

var _finished := false


func _initialize() -> void:
	var failures: Array[String] = []
	var foot_offset := Vector2(8, 15)
	_expect(ActorGeometry.foot_position(Vector2(100, 100), foot_offset).is_equal_approx(Vector2(108, 115)), "normal actor foot uses shared anchor", failures)
	_expect(ActorGeometry.encounter_visual_offset(1.0, foot_offset).is_equal_approx(Vector2.ZERO), "normal actor has no encounter compensation", failures)

	var boss_offset := ActorGeometry.encounter_visual_offset(2.0, foot_offset)
	_expect(boss_offset.is_equal_approx(Vector2(-4, -7.5)), "boss render offset is derived from encounter scale", failures)
	var nonuniform_body := _transform_polygon(PackedVector2Array([Vector2(-4, -2), Vector2(4, -2), Vector2(4, 2), Vector2(-4, 2)]), Vector2(2.0, 1.5), boss_offset)
	_expect(_bounds(nonuniform_body).size.is_equal_approx(Vector2(16, 6)), "nonuniform boss scale reaches combat polygon", failures)
	_expect(_bounds(nonuniform_body).position.is_equal_approx(Vector2(-16, -14.25)), "boss body includes the same visual compensation", failures)

	_finished = true
	if failures.is_empty():
		print("ACTOR_GEOMETRY_SMOKE_OK")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)


func _transform_polygon(polygon: PackedVector2Array, scale: Vector2, offset: Vector2) -> PackedVector2Array:
	var transformed := PackedVector2Array()
	for point in polygon:
		transformed.append(point * scale + offset * scale)
	return transformed


func _bounds(polygon: PackedVector2Array) -> Rect2:
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		bounds = bounds.expand(point)
	return bounds


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
