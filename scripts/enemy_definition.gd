@tool
extends Resource
class_name EnemyDefinition

const PALETTE_LIBRARY_SCRIPT = preload("res://scripts/palette_library.gd")

## Typed, editor-inspectable enemy content contract. Definitions may remain
## embedded in SlimeVariantCatalogData for compatibility or live in standalone
## .tres files discovered by the same catalog; runtime assembly reads this
## typed contract in either case.

## `id` is the stable ID for this concrete enemy variant. Keep the serialized
## property name for existing resources; use `variant_id` in new code.
@export var id: StringName = &""
## The actor family selected by EnemyFactory. Current catalog entries are slime
## variants, so they all use `slime` here.
@export var type_id: StringName = &"slime"
@export var display_name := ""
@export var element := 0
@export var damage_contract: StringName = &"physical"
@export var base_stats: Dictionary = {}
@export var growth_weights: Dictionary = {}
## Palette ID applied to the shared slime frame set. Variant identity and
## visual palette are independent, so recolor-only variants can share an ID's
## combat behavior while choosing a separate supported palette.
@export var visual_source := "green"
## Encounter metadata belongs to the enemy definition so adding a variant does
## not require a RoomController branch or a parallel allowlist.
@export var encounter_role: StringName = &"matchup"
@export var encounter_weight := 0.0
@export var encounter_min_rank := 1
@export var matchup_weight := 0.0
@export var preferred_weight := 0.0
@export var allow_preferred := false

## Actor-local combat geometry. EnemyFactory applies the same data to editor
## previews and live pooled actors so tuning here changes both consumers.
@export_group("Geometry")
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


var variant_id: StringName:
	get:
		return id


static func from_variant(variant_id: StringName) -> EnemyDefinition:
	# Use a runtime load here instead of a compile-time preload. The catalog
	# itself owns the authored .tres resource, so preloading it from this script
	# creates a cold-start cycle when the definition validator scans resources.
	var catalog = load("res://scripts/slime_variant_catalog.gd")
	var definition := catalog.definition_resource(variant_id) as EnemyDefinition
	if definition != null:
		return definition
	return catalog.definition_resource(&"grey")


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id.is_empty():
		problems.append("variant id must not be empty")
	if type_id.is_empty():
		problems.append("type_id must not be empty")
	if display_name.is_empty():
		problems.append("display_name must not be empty")
	if base_stats.is_empty():
		problems.append("base_stats must not be empty")
	if growth_weights.is_empty():
		problems.append("growth_weights must not be empty")
	if not PALETTE_LIBRARY_SCRIPT.PALETTE_NAMES.has(visual_source):
		problems.append("visual_source '%s' must match a palette ID" % visual_source)
	if encounter_weight < 0.0:
		problems.append("encounter_weight must be non-negative")
	if encounter_min_rank < 1:
		problems.append("encounter_min_rank must be >= 1")
	if matchup_weight < 0.0:
		problems.append("matchup_weight must be non-negative")
	if preferred_weight < 0.0:
		problems.append("preferred_weight must be non-negative")
	if encounter_role not in [&"baseline", &"matchup", &"late", &"shadow"]:
		problems.append("unknown encounter_role '%s'" % encounter_role)
	_validate_polygon(collision_polygon, "collision_polygon", problems)
	_validate_polygon(body_hitbox_polygon, "body_hitbox_polygon", problems)
	_validate_rect(collision_guide_rect, "collision_guide_rect", problems)
	_validate_rect(attack_guide_left_rect, "attack_guide_left_rect", problems)
	_validate_rect(attack_guide_right_rect, "attack_guide_right_rect", problems)
	return problems


func _validate_polygon(points: PackedVector2Array, field_name: String, problems: Array[String]) -> void:
	if points.size() < 3:
		problems.append("%s must have at least 3 points" % field_name)
		return
	for point in points:
		if not point.is_finite():
			problems.append("%s points must be finite" % field_name)
			return
	if not polygon_is_valid(points):
		problems.append("%s must enclose an area and must not self-intersect" % field_name)


static func polygon_is_valid(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	var doubled_area := 0.0
	for index in points.size():
		var point := points[index]
		var next_index := (index + 1) % points.size()
		var next := points[next_index]
		if not point.is_finite():
			return false
		doubled_area += point.cross(next)
		for other_index in range(index + 1, points.size()):
			if point.distance_squared_to(points[other_index]) <= 0.000001:
				return false
	if not is_finite(doubled_area) or is_zero_approx(doubled_area):
		return false
	for first_edge in points.size():
		var first_start := points[first_edge]
		var first_end := points[(first_edge + 1) % points.size()]
		for second_edge in range(first_edge + 1, points.size()):
			if second_edge == (first_edge + 1) % points.size() or (second_edge + 1) % points.size() == first_edge:
				continue
			if _segments_intersect(first_start, first_end, points[second_edge], points[(second_edge + 1) % points.size()]):
				return false
	return true


static func _segments_intersect(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> bool:
	var ab := b - a
	var cd := d - c
	var denominator := ab.cross(cd)
	if is_zero_approx(denominator):
		return false
	var t := (c - a).cross(cd) / denominator
	var u := (c - a).cross(ab) / denominator
	return t > 0.0001 and t < 0.9999 and u > 0.0001 and u < 0.9999


func _validate_rect(rect: Rect2, field_name: String, problems: Array[String]) -> void:
	if not rect.position.is_finite() or not rect.size.is_finite():
		problems.append("%s values must be finite" % field_name)
	elif rect.size.x <= 0.0 or rect.size.y <= 0.0:
		problems.append("%s size must be positive" % field_name)


func to_record() -> Dictionary:
	return {
		"variant": variant_id,
		"variant_id": variant_id,
		"type_id": type_id,
		"display_name": display_name,
		"element": element,
		"damage_contract": damage_contract,
		"base_stats": base_stats.duplicate(true),
		"growth_weights": growth_weights.duplicate(true),
		"visual_source": visual_source,
		"encounter_role": encounter_role,
		"encounter_weight": encounter_weight,
		"encounter_min_rank": encounter_min_rank,
		"matchup_weight": matchup_weight,
		"preferred_weight": preferred_weight,
		"allow_preferred": allow_preferred,
		"collision_guide_rect": collision_guide_rect,
		"collision_polygon": collision_polygon.duplicate(),
		"body_hitbox_polygon": body_hitbox_polygon.duplicate(),
		"attack_guide_left_rect": attack_guide_left_rect,
		"attack_guide_right_rect": attack_guide_right_rect,
	}


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
