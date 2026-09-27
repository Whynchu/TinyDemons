@tool
extends Resource
@export var id: StringName = &""
@export var collision_guide_rect := Rect2(Vector2(3.5, 7.5), Vector2(9.0, 4.0))
@export var collision_polygon := PackedVector2Array([
	Vector2(3, 7), Vector2(13, 7), Vector2(13, 10), Vector2(12, 10),
	Vector2(12, 11), Vector2(11, 11), Vector2(11, 12), Vector2(5, 12),
	Vector2(5, 11), Vector2(4, 11), Vector2(4, 10), Vector2(3, 10),
])
@export var body_hitbox_polygon := PackedVector2Array([
	Vector2(5, 3), Vector2(11, 3), Vector2(13, 5), Vector2(14, 8),
	Vector2(14, 11), Vector2(12, 13), Vector2(10, 14), Vector2(6, 14),
	Vector2(4, 13), Vector2(2, 11), Vector2(2, 8), Vector2(3, 5),
])
@export var attack_guide_left_rect := Rect2(Vector2(-1.0, 0.0), Vector2(8.5, 16.0))
@export var attack_guide_right_rect := Rect2(Vector2(8.5, 0.0), Vector2(8.5, 16.0))


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id.is_empty():
		problems.append("geometry profile id must not be empty")
	for field_name in ["collision_polygon", "body_hitbox_polygon"]:
		var points: PackedVector2Array = get(field_name)
		if not EnemyDefinition.polygon_is_valid(points):
			problems.append("%s must enclose a valid area" % field_name)
	for field_name in ["collision_guide_rect", "attack_guide_left_rect", "attack_guide_right_rect"]:
		var rect: Rect2 = get(field_name)
		if not rect.position.is_finite() or not rect.size.is_finite() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
			problems.append("%s must have finite values and positive size" % field_name)
	return problems


func geometry_record() -> Dictionary:
	return {
		"collision_guide_rect": collision_guide_rect,
		"collision_polygon": collision_polygon.duplicate(),
		"body_hitbox_polygon": body_hitbox_polygon.duplicate(),
		"attack_guide_left_rect": attack_guide_left_rect,
		"attack_guide_right_rect": attack_guide_right_rect,
	}


func apply_geometry_record(record: Dictionary) -> void:
	if record.has("collision_guide_rect"):
		collision_guide_rect = record["collision_guide_rect"]
	if record.has("collision_polygon"):
		collision_polygon = record["collision_polygon"].duplicate()
	if record.has("body_hitbox_polygon"):
		body_hitbox_polygon = record["body_hitbox_polygon"].duplicate()
	if record.has("attack_guide_left_rect"):
		attack_guide_left_rect = record["attack_guide_left_rect"]
	if record.has("attack_guide_right_rect"):
		attack_guide_right_rect = record["attack_guide_right_rect"]
	emit_changed()
