extends RefCounted
class_name EnemyCatalog

## Mixed-family enemy-definition registry. Authored definitions remain in the
## historical catalog resource and standalone one-file resources; this class
## is the canonical lookup and authoring API for both actor families.

const DATA := preload("res://resources/definitions/slime_variant_catalog.tres")
const CATALOG_RESOURCE_PATH := "res://resources/definitions/slime_variant_catalog.tres"
const SLIME_GEOMETRY_PROFILE: Resource = preload("res://resources/definitions/geometry/slime.tres")
const SKELETON_GEOMETRY_PROFILE: Resource = preload("res://resources/definitions/geometry/skeleton.tres")
static var _cache_loaded := false
static var _definition_cache: Dictionary = {}
static var _id_cache: Array[StringName] = []


static func _ensure_cache() -> void:
	if _cache_loaded:
		return
	for enemy_definition in DATA.authored_definitions():
		_definition_cache[enemy_definition.variant_id] = enemy_definition
		_id_cache.append(enemy_definition.variant_id)
	_cache_loaded = true


static func definitions() -> Dictionary:
	_ensure_cache()
	return _definition_cache


static func ids() -> Array[StringName]:
	_ensure_cache()
	return _id_cache


static func contains_id(enemy_id: StringName) -> bool:
	return definitions().has(enemy_id)


static func validate() -> Array[String]:
	return DATA.validate()


static func invalidate_cache() -> void:
	_cache_loaded = false
	_definition_cache.clear()
	_id_cache.clear()


static func save_definition(enemy_definition: EnemyDefinition) -> Error:
	if enemy_definition == null:
		return ERR_INVALID_PARAMETER
	if enemy_definition.resource_path.is_empty():
		return ERR_FILE_NOT_FOUND
	if enemy_definition.resource_path.contains("::"):
		return ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	var save_error := ResourceSaver.save(enemy_definition, enemy_definition.resource_path)
	if save_error != OK:
		return save_error
	if not DATA.definitions.has(enemy_definition):
		DATA.definitions.append(enemy_definition)
		return ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	return OK


static func register_definition(enemy_definition: EnemyDefinition) -> Error:
	if enemy_definition == null or enemy_definition.resource_path.is_empty():
		return ERR_INVALID_PARAMETER
	if DATA.definitions.has(enemy_definition):
		return OK
	if definition_resource(enemy_definition.variant_id) != null:
		return ERR_ALREADY_EXISTS
	DATA.definitions.append(enemy_definition)
	var save_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	if save_error != OK:
		DATA.definitions.erase(enemy_definition)
	return save_error


static func definition_source_path(enemy_definition: EnemyDefinition) -> String:
	if enemy_definition.resource_path.contains("::"):
		return CATALOG_RESOURCE_PATH
	return enemy_definition.resource_path


static func definition_resource(enemy_id: StringName) -> EnemyDefinition:
	return definitions().get(enemy_id) as EnemyDefinition


static func family_geometry_profile(type_id: StringName) -> Resource:
	match type_id:
		&"slime":
			return SLIME_GEOMETRY_PROFILE
		&"skeleton":
			return SKELETON_GEOMETRY_PROFILE
	return null


static func record_for_id(enemy_id: StringName) -> Dictionary:
	var enemy_definition := definition_resource(enemy_id)
	if enemy_definition == null:
		enemy_definition = definition_resource(&"grey")
	return enemy_definition.to_record() if enemy_definition != null else {}


static func element_for_id(enemy_id: StringName) -> int:
	return int(record_for_id(enemy_id)["element"])


static func display_name_for_id(enemy_id: StringName) -> String:
	return str(record_for_id(enemy_id)["display_name"])


static func damage_contract_for_id(enemy_id: StringName) -> StringName:
	return StringName(str(record_for_id(enemy_id).get("damage_contract", "physical")))


static func has_elemental_damage_contract(enemy_id: StringName) -> bool:
	return damage_contract_for_id(enemy_id) == &"elemental_slime"
