extends RefCounted
class_name SlimeVariantCatalog

## Editor-inspectable slime variant registry. The authored data lives in
## resources/definitions as typed EnemyDefinition resources: the historical
## catalog sub-resources plus standalone one-file definitions. This class is
## the narrow runtime lookup API over both forms.

const DATA := preload("res://resources/definitions/slime_variant_catalog.tres") as SlimeVariantCatalogData
static var _cache_loaded := false
static var _definition_cache: Dictionary = {}
static var _variant_cache: Array[StringName] = []


static func _ensure_cache() -> void:
	if _cache_loaded:
		return
	for definition in DATA.authored_definitions():
		_definition_cache[definition.id] = definition
		_variant_cache.append(definition.id)
	_cache_loaded = true

static func definitions() -> Dictionary:
	_ensure_cache()
	return _definition_cache


static func variants() -> Array[StringName]:
	_ensure_cache()
	return _variant_cache


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
