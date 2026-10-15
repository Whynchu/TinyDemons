extends RefCounted
class_name EnemyCatalog

## Mixed-family enemy-definition registry. Authored definitions remain in the
## historical catalog resource and standalone one-file resources; this class
## is the canonical lookup and authoring API for both actor families.

const DATA := preload("res://resources/definitions/slime_variant_catalog.tres")
const CATALOG_RESOURCE_PATH := "res://resources/definitions/slime_variant_catalog.tres"
const CONTENT_MANIFEST_SERVICE_SCRIPT := preload("res://scripts/content/content_definition_manifest_service.gd")
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
	if _definition_in_catalog(DATA, enemy_definition.variant_id) != null:
		return ERR_ALREADY_EXISTS
	DATA.definitions.append(enemy_definition)
	var save_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	if save_error != OK:
		DATA.definitions.erase(enemy_definition)
		invalidate_cache()
		return save_error
	var manifest_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
	if manifest_error != OK:
		DATA.definitions.erase(enemy_definition)
		var catalog_restore_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
		var manifest_restore_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
		_report_rollback_errors(catalog_restore_error, OK, manifest_restore_error)
		invalidate_cache()
		return manifest_error
	invalidate_cache()
	return OK


static func create_authored_definition(
	enemy_definition: EnemyDefinition,
	resource_path: String,
) -> Error:
	if enemy_definition == null or resource_path.is_empty():
		return ERR_INVALID_PARAMETER
	if resource_path.get_extension().to_lower() != "tres":
		return ERR_INVALID_PARAMETER
	if not _is_authored_definition_path(resource_path):
		return ERR_INVALID_PARAMETER
	if FileAccess.file_exists(resource_path):
		return ERR_ALREADY_EXISTS
	if _definition_in_catalog(DATA, enemy_definition.variant_id) != null:
		return ERR_ALREADY_EXISTS
	if not enemy_definition.validate().is_empty():
		return ERR_INVALID_DATA

	var original_entries: Array[Resource] = DATA.definitions.duplicate()
	var original_resource_path := enemy_definition.resource_path
	var save_error := ResourceSaver.save(enemy_definition, resource_path, ResourceSaver.FLAG_CHANGE_PATH)
	if save_error != OK:
		enemy_definition.take_over_path(original_resource_path)
		return save_error
	enemy_definition.take_over_path(resource_path)
	DATA.definitions.append(enemy_definition)
	save_error = ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	if save_error != OK:
		_restore_definition_entries(original_entries)
		var catalog_restore_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
		var definition_remove_error := _remove_resource_file(resource_path)
		enemy_definition.take_over_path(original_resource_path)
		DATA.emit_changed()
		invalidate_cache()
		_report_rollback_errors(catalog_restore_error, definition_remove_error, OK)
		return save_error

	var manifest_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
	if manifest_error != OK:
		_restore_definition_entries(original_entries)
		var catalog_restore_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
		var definition_remove_error := _remove_resource_file(resource_path)
		var manifest_restore_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
		enemy_definition.take_over_path(original_resource_path)
		DATA.emit_changed()
		invalidate_cache()
		_report_rollback_errors(catalog_restore_error, definition_remove_error, manifest_restore_error)
		return manifest_error

	enemy_definition.emit_changed()
	DATA.emit_changed()
	invalidate_cache()
	return OK


static func remove_authored_definition(
	enemy_definition: EnemyDefinition,
	resource_path: String = "",
) -> Error:
	if enemy_definition == null:
		return ERR_INVALID_PARAMETER
	if resource_path.is_empty():
		resource_path = enemy_definition.resource_path
	if resource_path.is_empty() or resource_path.contains("::"):
		return ERR_INVALID_PARAMETER
	if resource_path.get_extension().to_lower() != "tres":
		return ERR_INVALID_PARAMETER
	if not _is_authored_definition_path(resource_path):
		return ERR_INVALID_PARAMETER

	var entry_index := _catalog_entry_index(DATA, enemy_definition, resource_path)
	if entry_index < 0:
		return ERR_DOES_NOT_EXIST
	var original_entries: Array[Resource] = DATA.definitions.duplicate()
	DATA.definitions.remove_at(entry_index)
	var save_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	if save_error != OK:
		_restore_definition_entries(original_entries)
		var catalog_restore_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
		DATA.emit_changed()
		invalidate_cache()
		_report_rollback_errors(catalog_restore_error, OK, OK)
		return save_error

	var delete_error := _remove_resource_file(resource_path)
	if delete_error != OK:
		_restore_definition_entries(original_entries)
		var restore_catalog_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
		DATA.emit_changed()
		invalidate_cache()
		_report_rollback_errors(restore_catalog_error, OK, OK)
		return delete_error

	var manifest_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
	if manifest_error != OK:
		var restore_definition_error := ResourceSaver.save(
			enemy_definition, resource_path, ResourceSaver.FLAG_CHANGE_PATH
		)
		if restore_definition_error == OK:
			enemy_definition.take_over_path(resource_path)
		_restore_definition_entries(original_entries)
		var restore_catalog_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
		var restore_manifest_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
		DATA.emit_changed()
		invalidate_cache()
		_report_rollback_errors(restore_catalog_error, restore_definition_error, restore_manifest_error)
		return manifest_error

	enemy_definition.take_over_path("")
	enemy_definition.emit_changed()
	DATA.emit_changed()
	invalidate_cache()
	return OK


func redo_authored_definition_action(
	enemy_definition: EnemyDefinition,
	resource_path: String,
	authored_id: StringName,
	source_variant_name: String,
	workbench_ref: WeakRef,
) -> void:
	var create_error := EnemyCatalog.create_authored_definition(enemy_definition, resource_path)
	if create_error != OK:
		push_error("EnemyCatalog: redo create failed (%d) for %s" % [create_error, authored_id])
		return
	_select_workbench_variant(workbench_ref, authored_id, "Redid variant creation from %s" % source_variant_name)


func undo_authored_definition_action(
	enemy_definition: EnemyDefinition,
	resource_path: String,
	previous_variant_id: StringName,
	workbench_ref: WeakRef,
) -> void:
	var remove_error := EnemyCatalog.remove_authored_definition(enemy_definition, resource_path)
	if remove_error != OK:
		push_error("EnemyCatalog: undo create failed (%d) for %s" % [remove_error, enemy_definition.variant_id])
		return
	_select_workbench_variant(workbench_ref, previous_variant_id, "Undid enemy variant creation")


func _select_workbench_variant(workbench_ref: WeakRef, variant_id: StringName, notice: String) -> void:
	var workbench := workbench_ref.get_ref() as Node
	if workbench == null or not is_instance_valid(workbench):
		return
	workbench.call("_select_variant_after_catalog_change", variant_id, notice)


static func _definition_in_catalog(
	catalog_data: SlimeVariantCatalogData,
	enemy_id: StringName,
) -> EnemyDefinition:
	for candidate in catalog_data.authored_definitions():
		if candidate.variant_id == enemy_id:
			return candidate
	return null


static func _catalog_entry_index(
	catalog_data: SlimeVariantCatalogData,
	enemy_definition: EnemyDefinition,
	resource_path: String,
) -> int:
	for index in catalog_data.definitions.size():
		var candidate := catalog_data.definitions[index] as EnemyDefinition
		if candidate == enemy_definition or (candidate != null and candidate.variant_id == enemy_definition.variant_id and candidate.resource_path == resource_path):
			return index
	return -1


static func _is_authored_definition_path(resource_path: String) -> bool:
	return (
		resource_path == resource_path.simplify_path()
		and resource_path.begins_with("res://resources/definitions/")
	)


static func _restore_definition_entries(entries: Array[Resource]) -> void:
	DATA.definitions.clear()
	DATA.definitions.append_array(entries)


static func _remove_resource_file(resource_path: String) -> Error:
	if not FileAccess.file_exists(resource_path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))


static func _report_rollback_errors(catalog_error: Error, resource_error: Error, manifest_error: Error) -> void:
	var rollback_errors := PackedStringArray()
	if catalog_error != OK:
		rollback_errors.append("catalog restore failed (%d)" % catalog_error)
	if resource_error != OK:
		rollback_errors.append("resource restore failed (%d)" % resource_error)
	if manifest_error != OK:
		rollback_errors.append("manifest restore failed (%d)" % manifest_error)
	if not rollback_errors.is_empty():
		push_error("EnemyCatalog: rollback incomplete: %s" % "; ".join(rollback_errors))


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
