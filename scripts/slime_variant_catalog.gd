extends RefCounted
class_name SlimeVariantCatalog

## Editor-inspectable slime variant registry. The authored data lives in
## resources/definitions as typed EnemyDefinition resources: the historical
## catalog sub-resources plus standalone one-file definitions. This class is
## the narrow runtime lookup API over both forms.

const DATA := preload("res://resources/definitions/slime_variant_catalog.tres") as SlimeVariantCatalogData
const CATALOG_RESOURCE_PATH := "res://resources/definitions/slime_variant_catalog.tres"
static var _cache_loaded := false
static var _definition_cache: Dictionary = {}
static var _variant_cache: Array[StringName] = []


static func _ensure_cache() -> void:
	if _cache_loaded:
		return
	for definition in DATA.authored_definitions():
		_definition_cache[definition.variant_id] = definition
		_variant_cache.append(definition.variant_id)
	_cache_loaded = true

static func definitions() -> Dictionary:
	_ensure_cache()
	return _definition_cache


static func variants() -> Array[StringName]:
	_ensure_cache()
	return _variant_cache


static func variant_ids() -> Array[StringName]:
	return variants()


static func is_variant(variant_id: StringName) -> bool:
	return definitions().has(variant_id)


static func invalidate_cache() -> void:
	_cache_loaded = false
	_definition_cache.clear()
	_variant_cache.clear()


static func save_definition(definition: EnemyDefinition) -> Error:
	if definition == null:
		return ERR_INVALID_PARAMETER
	if definition.resource_path.is_empty():
		return ERR_FILE_NOT_FOUND
	if definition.resource_path.contains("::"):
		return ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	var save_error := ResourceSaver.save(definition, definition.resource_path)
	if save_error != OK:
		return save_error
	if not DATA.definitions.has(definition):
		DATA.definitions.append(definition)
		return ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	return OK


static func register_definition(definition: EnemyDefinition) -> Error:
	if definition == null or definition.resource_path.is_empty():
		return ERR_INVALID_PARAMETER
	if DATA.definitions.has(definition):
		return OK
	if definition_resource(definition.variant_id) != null:
		return ERR_ALREADY_EXISTS
	DATA.definitions.append(definition)
	var save_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	if save_error != OK:
		DATA.definitions.erase(definition)
	return save_error


static func definition_source_path(definition: EnemyDefinition) -> String:
	if definition.resource_path.contains("::"):
		return CATALOG_RESOURCE_PATH
	return definition.resource_path


static func definition_resource(variant_id: StringName) -> EnemyDefinition:
	var definition := definitions().get(variant_id) as EnemyDefinition
	return definition


static func definition(variant_id: StringName) -> Dictionary:
	var definition_resource_value := definition_resource(variant_id)
	if definition_resource_value == null:
		definition_resource_value = definition_resource(&"grey")
	return definition_resource_value.to_record() if definition_resource_value != null else {}


static func element_for_variant(variant_id: StringName) -> int:
	return int(definition(variant_id)["element"])


static func display_name_for_variant(variant_id: StringName) -> String:
	return str(definition(variant_id)["display_name"])


static func damage_contract_for_variant(variant_id: StringName) -> StringName:
	return StringName(str(definition(variant_id).get("damage_contract", "physical")))


static func is_elemental_variant(variant_id: StringName) -> bool:
	return damage_contract_for_variant(variant_id) == &"elemental_slime"
