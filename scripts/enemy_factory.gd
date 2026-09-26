extends RefCounted
class_name EnemyFactory

## Assembles enemy actors from EnemyDefinition contracts. The factory is the
## single materialization point: type_id selects the actor family, while the
## definition's variant_id configures its identity, combat element, damage
## contract, stats profile, and geometry. Runtime components are still ensured
## by the selected actor implementation.

const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/slime_variant_catalog.gd")
const EDITOR_COLLISION_GUIDE_SCRIPT = preload("res://scripts/editor_collision_guide.gd")
const TYPE_SLIME: StringName = &"slime"
const TYPE_SKELETON: StringName = &"skeleton"


static func assemble(definition: EnemyDefinition) -> SlimeActor:
	if definition == null:
		return null
	var actor := _new_actor_for_type(definition.type_id)
	if actor == null:
		push_error("Cannot assemble variant '%s': unsupported enemy type_id '%s'." % [definition.variant_id, definition.type_id])
		return null
	actor.centered = false
	if actor is SkeletonActor:
		actor.offset = SkeletonActor.FRAME_OFFSET
	actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	configure_actor(actor, definition)
	return actor


static func _new_actor_for_type(type_id: StringName) -> SlimeActor:
	match type_id:
		TYPE_SLIME:
			return SlimeActor.new()
		TYPE_SKELETON:
			return SkeletonActor.new()
	return null


static func configure_actor(actor: SlimeActor, definition: EnemyDefinition) -> void:
	if actor == null or definition == null:
		return
	if definition.type_id not in [TYPE_SLIME, TYPE_SKELETON]:
		push_error("Cannot configure enemy actor for unsupported type_id '%s'." % definition.type_id)
		return
	actor.ensure_components()
	if actor is SkeletonActor:
		(actor as SkeletonActor).apply_authored_visuals()
	apply_geometry(actor, definition)
	actor.variant = String(definition.variant_id)
	actor.combat_element = definition.element
	actor.set_meta("element", definition.element)
	actor.set_meta("damage_contract", String(definition.damage_contract))
	actor.set_meta("enemy_definition_id", definition.variant_id)
	actor.set_meta("enemy_variant_id", definition.variant_id)
	actor.set_meta("enemy_type_id", definition.type_id)
	actor.set_meta("ranged_stationary_attack", definition.type_id == TYPE_SKELETON)
	if definition.type_id == TYPE_SKELETON:
		actor.set_meta("attack_hit_frame_override", SkeletonActor.BONE_THROW_ATTACK_FRAME_INDEX)
	actor.set_meta("visual_source", definition.visual_source)
	var stats := actor.get_node_or_null("Stats") as StatsComponent
	if stats == null:
		stats = StatsComponent.new()
		stats.name = "Stats"
		actor.add_child(stats)
	stats.apply_enemy_variant_profile(definition.base_stats, definition.growth_weights, definition.variant_id)
	actor.set_meta("content_materialized", true)


static func definition(variant_id: StringName) -> EnemyDefinition:
	return EnemyDefinition.from_variant(variant_id)


static func is_variant(variant_id: StringName) -> bool:
	return SLIME_VARIANT_CATALOG_SCRIPT.is_variant(variant_id)


static func variants_for_type(type_id: StringName) -> Array[StringName]:
	var matches: Array[StringName] = []
	for variant_id in SLIME_VARIANT_CATALOG_SCRIPT.variants():
		var enemy_definition := definition(variant_id)
		if enemy_definition != null and enemy_definition.type_id == type_id:
			matches.append(variant_id)
	return matches


static func variant_is_type(variant_id: StringName, type_id: StringName) -> bool:
	var enemy_definition := definition(variant_id)
	return enemy_definition != null and enemy_definition.type_id == type_id


static func weighted_variants_for_type(type_id: StringName) -> Array[Dictionary]:
	var weighted_variants: Array[Dictionary] = []
	for variant_id in variants_for_type(type_id):
		var enemy_definition := definition(variant_id)
		if enemy_definition.encounter_weight > 0.0:
			weighted_variants.append({"variant": String(variant_id), "weight": enemy_definition.encounter_weight})
	return weighted_variants


static func single_variant_encounter(variant_id: StringName, level: int) -> Dictionary:
	return {
		"variants": [String(variant_id)],
		"levels": [level],
		"scales": [1.0],
		"popcorn": [false],
		"popcorn_types": [""],
		"ambush": [false],
	}


static func resolve_variant_id(value: StringName) -> StringName:
	var trimmed := String(value).strip_edges()
	if trimmed.is_empty():
		return &""
	var normalized_id := StringName(trimmed.to_lower().replace(" ", "_"))
	if is_variant(normalized_id):
		return normalized_id
	var display_name := trimmed.to_lower()
	for variant_id in SLIME_VARIANT_CATALOG_SCRIPT.variants():
		var candidate := definition(variant_id)
		if candidate != null and candidate.display_name.strip_edges().to_lower() == display_name:
			return variant_id
	return &""


static func apply_geometry(actor: SlimeActor, definition: EnemyDefinition) -> void:
	if actor == null or definition == null:
		return
	var collision_guide := actor.get_node_or_null("CollisionGuide") as Node2D
	if collision_guide == null:
		collision_guide = EDITOR_COLLISION_GUIDE_SCRIPT.new() as Node2D
		collision_guide.name = "CollisionGuide"
		actor.add_child(collision_guide)
	collision_guide.position = Vector2.ZERO
	collision_guide.rotation = 0.0
	collision_guide.scale = Vector2.ONE
	collision_guide.set("rect_position", definition.collision_guide_rect.position)
	collision_guide.set("rect_size", definition.collision_guide_rect.size)
	collision_guide.set("draw_in_game", false)
	collision_guide.visible = false

	var collision_polygon := actor.get_node_or_null("CollisionPolygon") as Polygon2D
	if collision_polygon == null:
		collision_polygon = Polygon2D.new()
		collision_polygon.name = "CollisionPolygon"
		actor.add_child(collision_polygon)
	collision_polygon.position = Vector2.ZERO
	collision_polygon.rotation = 0.0
	collision_polygon.scale = Vector2.ONE
	collision_polygon.polygon = definition.collision_polygon.duplicate()
	collision_polygon.visible = false

	var body_hitbox := actor.get_node_or_null("BodyHitbox") as Polygon2D
	if body_hitbox == null:
		body_hitbox = Polygon2D.new()
		body_hitbox.name = "BodyHitbox"
		actor.add_child(body_hitbox)
	body_hitbox.position = Vector2.ZERO
	body_hitbox.rotation = 0.0
	body_hitbox.scale = Vector2.ONE
	body_hitbox.polygon = definition.body_hitbox_polygon.duplicate()
	body_hitbox.visible = false

	for guide_name: StringName in [&"AttackGuideL", &"AttackGuideR"]:
		var attack_guide := actor.get_node_or_null(NodePath(guide_name)) as Node2D
		if attack_guide == null:
			attack_guide = EDITOR_COLLISION_GUIDE_SCRIPT.new() as Node2D
			attack_guide.name = guide_name
			actor.add_child(attack_guide)
		attack_guide.position = Vector2.ZERO
		attack_guide.rotation = 0.0
		attack_guide.scale = Vector2.ONE
		var rect: Rect2 = definition.attack_guide_left_rect if guide_name == &"AttackGuideL" else definition.attack_guide_right_rect
		attack_guide.set("rect_position", rect.position)
		attack_guide.set("rect_size", rect.size)
		attack_guide.set("draw_in_game", false)
		attack_guide.visible = false
