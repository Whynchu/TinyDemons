extends RefCounted
class_name EnemyFactory

## Assembles enemy actors from EnemyDefinition contracts. The factory is the
## single materialization point: given a definition it configures the actor's
## variant, combat element, damage contract, and stats profile, so a new enemy
## can be added through content (a catalog row + definition) rather than
## central-state branches. Runtime components are still ensured by SlimeActor.

const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/slime_variant_catalog.gd")


static func assemble(definition: EnemyDefinition) -> SlimeActor:
	var actor := SlimeActor.new()
	configure_actor(actor, definition)
	return actor


static func configure_actor(actor: SlimeActor, definition: EnemyDefinition) -> void:
	if actor == null or definition == null:
		return
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


static func definition(variant: StringName) -> EnemyDefinition:
	return EnemyDefinition.from_variant(variant)


static func is_variant(variant: StringName) -> bool:
	return SLIME_VARIANT_CATALOG_SCRIPT.is_variant(variant)