@tool
extends Node2D

## Small, deterministic preview host for the authored enemy contract. It uses
## EnemyFactory for the actor and shows the same body/attack geometry that the
## runtime consumes, so an author can inspect a definition without booting a
## run or opening a coordinator scene.

const BASE_TEXTURE := preload("res://assets/artwork/SlimeGreenRight.png")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const SlimeVisualComponentScript = preload("res://scripts/slime_visual_component.gd")

@export var enemy_id: StringName = &"guard_slime":
	set(value):
		enemy_id = value
		if is_node_ready():
			call_deferred("_build_preview")

var definition: EnemyDefinition
var preview_actor: SlimeActor
var preview_ready := false
var error_message := ""


func _ready() -> void:
	_build_preview()


func _build_preview() -> void:
	preview_ready = false
	error_message = ""
	definition = null
	if preview_actor != null and is_instance_valid(preview_actor):
		if preview_actor.get_parent() != null:
			preview_actor.get_parent().remove_child(preview_actor)
		preview_actor.free()
		preview_actor = null

	if not EnemyFactory.is_variant(enemy_id):
		error_message = "Unknown enemy id: %s" % enemy_id
		queue_redraw()
		return

	definition = EnemyFactory.definition(enemy_id)
	if definition == null:
		error_message = "Definition failed to load: %s" % enemy_id
		queue_redraw()
		return

	preview_actor = EnemyFactory.assemble(definition)
	preview_actor.name = "PreviewEnemy"
	preview_actor.position = Vector2(48, 84)
	preview_actor.scale = Vector2(4, 4)
	preview_actor.process_mode = Node.PROCESS_MODE_DISABLED
	preview_actor.texture = BASE_TEXTURE
	add_child(preview_actor)
	SlimeVisualComponentScript.apply_palette_material(preview_actor)
	_show_geometry()
	preview_ready = _geometry_is_valid()
	if not preview_ready:
		error_message = "Factory output has invalid collision geometry"
	queue_redraw()


func _show_geometry() -> void:
	var collision_polygon := preview_actor.get_node_or_null("CollisionPolygon") as Polygon2D
	if collision_polygon != null:
		collision_polygon.color = Color(0.2, 0.9, 1.0, 0.24)
		collision_polygon.visible = true
	var body_hitbox := preview_actor.get_node_or_null("BodyHitbox") as Polygon2D
	if body_hitbox != null:
		body_hitbox.color = Color(1.0, 0.25, 0.2, 0.28)
		body_hitbox.visible = true
	for guide_name: StringName in [&"CollisionGuide", &"AttackGuideL", &"AttackGuideR"]:
		var guide := preview_actor.get_node_or_null(NodePath(guide_name)) as Node2D
		if guide == null:
			continue
		guide.set("draw_in_game", true)
		guide.visible = true
		guide.queue_redraw()


func _geometry_is_valid() -> bool:
	if preview_actor == null:
		return false
	var collision_polygon := preview_actor.get_node_or_null("CollisionPolygon") as Polygon2D
	var body_hitbox := preview_actor.get_node_or_null("BodyHitbox") as Polygon2D
	return collision_polygon != null and body_hitbox != null and _has_area(collision_polygon.polygon) and _has_area(body_hitbox.polygon)


func _has_area(points: PackedVector2Array) -> bool:
	if points.size() < 3:
		return false
	var doubled_area := 0.0
	for index in points.size():
		var next := points[(index + 1) % points.size()]
		doubled_area += points[index].cross(next)
	return not is_zero_approx(doubled_area)


func get_preview_summary() -> Dictionary:
	if definition == null:
		return {"id": String(enemy_id), "ready": false, "error": error_message}
	return {
		"id": String(definition.id),
		"display_name": definition.display_name,
		"element": ElementCatalogScript.display_name(definition.element),
		"damage_contract": String(definition.damage_contract),
		"visual_source": definition.visual_source,
		"geometry_valid": _geometry_is_valid(),
		"ready": preview_ready,
	}


func _draw() -> void:
	var background := Color("101825")
	draw_rect(Rect2(0, 0, 320, 180), background, true)
	draw_rect(Rect2(8, 8, 304, 164), Color("1b2a3d"), true)
	draw_rect(Rect2(8, 8, 304, 164), Color("5a7890"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(18, 23), "ENEMY PREVIEW", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("b9e9ff"))

	if definition == null:
		draw_string(ThemeDB.fallback_font, Vector2(18, 48), error_message, HORIZONTAL_ALIGNMENT_LEFT, 280, 9, Color("ff8f8f"))
		return

	draw_string(ThemeDB.fallback_font, Vector2(18, 42), definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(18, 56), "id: %s" % definition.id, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 68), "element: %s" % ElementCatalogScript.display_name(definition.element), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 80), "damage: %s" % definition.damage_contract, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 92), "visual: %s" % definition.visual_source, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 110), "STR %d  DEF %d  VIT %d" % [int(definition.base_stats.get("STR", 0)), int(definition.base_stats.get("DEF", 0)), int(definition.base_stats.get("VIT", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("d8e7f0"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 122), "AGI %d  INT %d  MND %d" % [int(definition.base_stats.get("AGI", 0)), int(definition.base_stats.get("INT", 0)), int(definition.base_stats.get("MND", 0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("d8e7f0"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 148), "geometry: %s" % ("ready" if _geometry_is_valid() else "invalid"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("8dffb1") if _geometry_is_valid() else Color("ff8f8f"))
	draw_string(ThemeDB.fallback_font, Vector2(18, 160), "factory materialized: %s" % ("yes" if preview_actor != null else "no"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("8dffb1") if preview_actor != null else Color("ff8f8f"))
