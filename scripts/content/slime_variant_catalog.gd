extends RefCounted
class_name SlimeVariantCatalog

## Historical API kept for saved scripts and older fixtures. New runtime and
## authoring code should use EnemyCatalog; both surfaces share one registry.

const ENEMY_CATALOG_SCRIPT := preload("res://scripts/content/enemy_catalog.gd")


static func definitions() -> Dictionary:
	return ENEMY_CATALOG_SCRIPT.definitions()


static func variants() -> Array[StringName]:
	return ENEMY_CATALOG_SCRIPT.ids()


static func validate() -> Array[String]:
	return ENEMY_CATALOG_SCRIPT.validate()


static func variant_ids() -> Array[StringName]:
	return ENEMY_CATALOG_SCRIPT.ids()


static func is_variant(variant_id: StringName) -> bool:
	return ENEMY_CATALOG_SCRIPT.contains_id(variant_id)


static func invalidate_cache() -> void:
	ENEMY_CATALOG_SCRIPT.invalidate_cache()


static func save_definition(enemy_definition: EnemyDefinition) -> Error:
	return ENEMY_CATALOG_SCRIPT.save_definition(enemy_definition)


static func register_definition(enemy_definition: EnemyDefinition) -> Error:
	return ENEMY_CATALOG_SCRIPT.register_definition(enemy_definition)


static func definition_source_path(enemy_definition: EnemyDefinition) -> String:
	return ENEMY_CATALOG_SCRIPT.definition_source_path(enemy_definition)


static func definition_resource(variant_id: StringName) -> EnemyDefinition:
	return ENEMY_CATALOG_SCRIPT.definition_resource(variant_id)


static func family_geometry_profile(type_id: StringName) -> Resource:
	return ENEMY_CATALOG_SCRIPT.family_geometry_profile(type_id)


static func definition(variant_id: StringName) -> Dictionary:
	return ENEMY_CATALOG_SCRIPT.record_for_id(variant_id)


static func element_for_variant(variant_id: StringName) -> int:
	return ENEMY_CATALOG_SCRIPT.element_for_id(variant_id)


static func display_name_for_variant(variant_id: StringName) -> String:
	return ENEMY_CATALOG_SCRIPT.display_name_for_id(variant_id)


static func damage_contract_for_variant(variant_id: StringName) -> StringName:
	return ENEMY_CATALOG_SCRIPT.damage_contract_for_id(variant_id)


static func is_elemental_variant(variant_id: StringName) -> bool:
	return ENEMY_CATALOG_SCRIPT.has_elemental_damage_contract(variant_id)
