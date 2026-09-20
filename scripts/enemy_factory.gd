extends RefCounted
class_name EnemyFactory

## Assembles enemy actors from EnemyDefinition contracts. The factory is the
## single materialization point: given a definition it configures the actor's
## variant, combat element, damage contract, and stats profile, so a new enemy
## can be added through content (a catalog row + definition) rather than
## central-state branches. Runtime components are still ensured by SlimeActor.

const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/slime_variant_catalog.gd")
const EDITOR_COLLISION_GUIDE_SCRIPT = preload("res://scripts/editor_collision_guide.gd")


static func assemble(definition: EnemyDefinition) -> SlimeActor:
	var actor := SlimeActor.new()
	actor.centered = false
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	configure_actor(actor, definition)
	return actor


static func configure_actor(actor: SlimeActor, definition: EnemyDefinition) -> void:
	if actor == null or definition == null:
		return
	actor.ensure_components()
	_ensure_regular_geometry(actor)
	actor.variant = String(definition.id)
	actor.combat_element = definition.element
	actor.set_meta("element", definition.element)
	actor.set_meta("damage_contract", String(definition.damage_contract))
	actor.set_meta("enemy_definition_id", definition.id)
	var stats := actor.get_node_or_null("Stats") as StatsComponent
	if stats == null:
		stats = StatsComponent.new()
		stats.name = "Stats"
		actor.add_child(stats)
	stats.apply_enemy_variant_profile(definition.base_stats, definition.growth_weights, definition.id)
	actor.set_meta("content_materialized", true)


static func definition(variant: StringName) -> EnemyDefinition:
	return EnemyDefinition.from_variant(variant)


static func is_variant(variant: StringName) -> bool:
	return SLIME_VARIANT_CATALOG_SCRIPT.is_variant(variant)


static func _ensure_regular_geometry(actor: SlimeActor) -> void:
	var collision_guide := actor.get_node_or_null("CollisionGuide") as Node2D
	if collision_guide == null:
		collision_guide = EDITOR_COLLISION_GUIDE_SCRIPT.new() as Node2D
		collision_guide.name = "CollisionGuide"
		actor.add_child(collision_guide)
	collision_guide.set("rect_position", Vector2(3.5, 7.5))
	collision_guide.set("rect_size", Vector2(9, 4))
	collision_guide.set("draw_in_game", false)
	collision_guide.visible = false

	var collision_polygon := actor.get_node_or_null("CollisionPolygon") as Polygon2D
	if collision_polygon == null:
		collision_polygon = Polygon2D.new()
		collision_polygon.name = "CollisionPolygon"
		actor.add_child(collision_polygon)
	collision_polygon.polygon = PackedVector2Array([3, 7, 13, 7, 13, 10, 12, 10, 12, 11, 11, 11, 11, 12, 5, 12, 5, 11, 4, 11, 4, 10, 3, 10])
	collision_polygon.visible = false

	var body_hitbox := actor.get_node_or_null("BodyHitbox") as Polygon2D
	if body_hitbox == null:
		body_hitbox = Polygon2D.new()
		body_hitbox.name = "BodyHitbox"
		actor.add_child(body_hitbox)
	body_hitbox.polygon = PackedVector2Array([5, 3, 11, 3, 13, 5, 14, 8, 14, 11, 12, 13, 10, 14, 6, 14, 4, 13, 2, 11, 2, 8, 3, 5])
	body_hitbox.visible = false

	for guide_name: StringName in [&"AttackGuideL", &"AttackGuideR"]:
		var attack_guide := actor.get_node_or_null(NodePath(guide_name)) as Node2D
		if attack_guide == null:
			attack_guide = EDITOR_COLLISION_GUIDE_SCRIPT.new() as Node2D
			attack_guide.name = guide_name
			actor.add_child(attack_guide)
		attack_guide.set("rect_position", Vector2(5, 8) if guide_name == &"AttackGuideL" else Vector2(14.5, 8))
		attack_guide.set("rect_size", Vector2(8.5, 16))
		attack_guide.set("draw_in_game", false)
		attack_guide.visible = false
