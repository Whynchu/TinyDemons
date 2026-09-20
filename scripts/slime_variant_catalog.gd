extends RefCounted
class_name SlimeVariantCatalog

## Editor-inspectable slime variant registry. The authored data lives in
## resources/definitions/slime_variant_catalog.tres as typed EnemyDefinition
## sub-resources; this class is the narrow runtime lookup API over that data.

const DATA := preload("res://resources/definitions/slime_variant_catalog.tres") as SlimeVariantCatalogData

static func definitions() -> Dictionary:
	var result: Dictionary = {}
	for entry in DATA.definitions:
		var definition := entry as EnemyDefinition
		if definition != null:
			result[definition.id] = definition
	return result


static func variants() -> Array[StringName]:
	var result: Array[StringName] = []
	for entry in DATA.definitions:
		var definition := entry as EnemyDefinition
		if definition != null:
			result.append(definition.id)
	return result


static func is_variant(variant: StringName) -> bool:
	return definitions().has(variant)


static func definition_resource(variant: StringName) -> EnemyDefinition:
	var definition := definitions().get(variant) as EnemyDefinition
	return definition


static func definition(variant: StringName) -> Dictionary:
	var definition_resource_value := definition_resource(variant)
	if definition_resource_value == null:
		definition_resource_value = definition_resource(&"grey")
	return definition_resource_value.to_record() if definition_resource_value != null else {}


static func element_for_variant(variant: StringName) -> int:
	return int(definition(variant)["element"])


static func display_name_for_variant(variant: StringName) -> String:
	return str(definition(variant)["display_name"])


static func damage_contract_for_variant(variant: StringName) -> StringName:
	return StringName(str(definition(variant).get("damage_contract", "physical")))


static func is_elemental_variant(variant: StringName) -> bool:
	return damage_contract_for_variant(variant) == &"elemental_slime"
