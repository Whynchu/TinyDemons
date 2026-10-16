extends RefCounted
class_name EnemyCatalog

## Mixed-family enemy-definition registry. Authored definitions remain in the
## historical catalog resource and standalone one-file resources; this class
## is the canonical lookup and authoring API for both actor families.
# Owner: enemy definition lookup, authored-file transactions, and manifest cache refresh.

const DATA := preload("res://resources/definitions/slime_variant_catalog.tres")
const CATALOG_RESOURCE_PATH := "res://resources/definitions/slime_variant_catalog.tres"
const CONTENT_MANIFEST_SERVICE_SCRIPT := preload("res://scripts/content/content_definition_manifest_service.gd")
const ENEMY_MANIFEST_EXPORT_DEPENDENCY: Resource = preload("res://resources/generated/enemy_definition_manifest.tres")
const GENERATED_MANIFEST_PATHS: Array[String] = [
	CONTENT_MANIFEST_SERVICE_SCRIPT.MANIFEST_PATH,
	CONTENT_MANIFEST_SERVICE_SCRIPT.ENEMY_MANIFEST_PATH,
	CONTENT_MANIFEST_SERVICE_SCRIPT.ITEM_MANIFEST_PATH,
]
const SLIME_GEOMETRY_PROFILE: Resource = preload("res://resources/definitions/geometry/slime.tres")
const SKELETON_GEOMETRY_PROFILE: Resource = preload("res://resources/definitions/geometry/skeleton.tres")
static var _enemy_manifest_dependency: Resource = ENEMY_MANIFEST_EXPORT_DEPENDENCY
static var _cache_loaded := false
static var _definition_cache: Dictionary = {}
static var _id_cache: Array[StringName] = []
static var _persisted_authored_definition_signatures: Dictionary = {}


static func _ensure_cache() -> void:
	if _cache_loaded:
		return
	for raw_definition: Resource in DATA.definitions:
		_append_definition_to_cache(raw_definition as EnemyDefinition)
	for raw_definition: Resource in CONTENT_MANIFEST_SERVICE_SCRIPT.load_kind_entries(
		&"enemy", _enemy_manifest_dependency
	):
		_append_definition_to_cache(raw_definition as EnemyDefinition)
	_cache_loaded = true


static func _append_definition_to_cache(enemy_definition: EnemyDefinition) -> void:
	if enemy_definition == null or _definition_cache.has(enemy_definition.variant_id):
		return
	_definition_cache[enemy_definition.variant_id] = enemy_definition
	_id_cache.append(enemy_definition.variant_id)


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
		save_error = ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
		if save_error != OK:
			return save_error
	if _is_canonical_authored_definition_path(enemy_definition.resource_path, enemy_definition.variant_id):
		_remember_authored_definition(enemy_definition, enemy_definition.resource_path)
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
	if manifest_error == OK:
		manifest_error = refresh_manifest_cache()
	if manifest_error != OK:
		DATA.definitions.erase(enemy_definition)
		var catalog_restore_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
		var manifest_restore_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
		if manifest_restore_error == OK:
			manifest_restore_error = refresh_manifest_cache()
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
	if not _is_canonical_authored_definition_path(resource_path, enemy_definition.variant_id):
		return ERR_INVALID_PARAMETER
	if _authored_definition_path_is_occupied(resource_path):
		return ERR_ALREADY_EXISTS
	if _authored_id_exists(enemy_definition.variant_id):
		return ERR_ALREADY_EXISTS
	if not enemy_definition.validate().is_empty():
		return ERR_INVALID_DATA

	var original_entries: Array[Resource] = DATA.definitions.duplicate()
	var original_resource_path := enemy_definition.resource_path
	var original_files := _snapshot_transaction_files(resource_path)
	var save_error := ResourceSaver.save(enemy_definition, resource_path, ResourceSaver.FLAG_CHANGE_PATH)
	if save_error != OK:
		_rollback_authored_definition_transaction(
			original_entries, original_files, enemy_definition, original_resource_path
		)
		return save_error
	enemy_definition.take_over_path(resource_path)
	DATA.definitions.append(enemy_definition)
	save_error = ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	if save_error != OK:
		_rollback_authored_definition_transaction(
			original_entries, original_files, enemy_definition, original_resource_path
		)
		return save_error

	var manifest_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
	if manifest_error == OK:
		manifest_error = refresh_manifest_cache()
	if manifest_error != OK:
		_rollback_authored_definition_transaction(
			original_entries, original_files, enemy_definition, original_resource_path
		)
		return manifest_error

	enemy_definition.emit_changed()
	DATA.emit_changed()
	_remember_authored_definition(enemy_definition, resource_path)
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
	if not _is_canonical_authored_definition_path(resource_path, enemy_definition.variant_id):
		return ERR_INVALID_PARAMETER
	if enemy_definition.resource_path != resource_path:
		return ERR_INVALID_PARAMETER
	if (
		not FileAccess.file_exists(resource_path)
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(resource_path))
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(resource_path + ".uid"))
	):
		return ERR_INVALID_DATA
	var on_disk := ResourceLoader.load(
		resource_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EnemyDefinition
	var expected_signature: Dictionary = _persisted_authored_definition_signatures.get(
		resource_path, _authored_definition_signature(enemy_definition)
	)
	if (
		on_disk == null
		or not _stored_authored_definition_matches_signature(on_disk, expected_signature)
	):
		return ERR_INVALID_DATA

	var entry_index := _catalog_entry_index(DATA, enemy_definition, resource_path)
	if entry_index < 0:
		return ERR_DOES_NOT_EXIST
	var original_entries: Array[Resource] = DATA.definitions.duplicate()
	var original_resource_path := enemy_definition.resource_path
	var original_files := _snapshot_transaction_files(resource_path)
	DATA.definitions.remove_at(entry_index)
	var save_error := ResourceSaver.save(DATA, CATALOG_RESOURCE_PATH)
	if save_error != OK:
		_rollback_authored_definition_transaction(
			original_entries, original_files, enemy_definition, original_resource_path
		)
		return save_error

	var delete_error := _remove_authored_definition_files(resource_path)
	if delete_error != OK:
		_rollback_authored_definition_transaction(
			original_entries, original_files, enemy_definition, original_resource_path
		)
		return delete_error

	var manifest_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
	if manifest_error == OK:
		manifest_error = refresh_manifest_cache()
	if manifest_error != OK:
		_rollback_authored_definition_transaction(
			original_entries, original_files, enemy_definition, original_resource_path
		)
		return manifest_error

	enemy_definition.take_over_path("")
	enemy_definition.emit_changed()
	DATA.emit_changed()
	_persisted_authored_definition_signatures.erase(resource_path)
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


static func _is_valid_authored_id(enemy_id: StringName) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	return pattern.search(String(enemy_id)) != null


static func _is_canonical_authored_definition_path(
	resource_path: String,
	enemy_id: StringName,
) -> bool:
	if resource_path.is_empty() or not _is_valid_authored_id(enemy_id):
		return false
	var expected_path := "res://resources/definitions/%s.tres" % String(enemy_id)
	return (
		resource_path == resource_path.simplify_path()
		and resource_path == expected_path
		and resource_path.get_extension().to_lower() == "tres"
	)


static func _authored_definition_path_is_occupied(resource_path: String) -> bool:
	return (
		FileAccess.file_exists(resource_path)
		or FileAccess.file_exists(resource_path + ".uid")
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(resource_path))
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(resource_path + ".uid"))
	)


static func _authored_id_exists(enemy_id: StringName) -> bool:
	for raw_definition: Resource in DATA.definitions:
		var catalog_definition := raw_definition as EnemyDefinition
		if catalog_definition != null and catalog_definition.variant_id == enemy_id:
			return true
	# Scan the current resource tree as well as the generated manifest. This
	# catches duplicates when a manifest is stale or preloaded in headless mode.
	for resource_path: String in CONTENT_MANIFEST_SERVICE_SCRIPT.discover_resource_paths():
		if not _resource_declares_enemy_definition(resource_path):
			continue
		var disk_definition := ResourceLoader.load(
			resource_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as EnemyDefinition
		if disk_definition != null and disk_definition.variant_id == enemy_id:
			return true
	return false


static func _resource_declares_enemy_definition(resource_path: String) -> bool:
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return false
	var header := file.get_line()
	file.close()
	return header.contains("script_class=\"EnemyDefinition\"")


static func _stored_authored_definition_matches_signature(
	on_disk: EnemyDefinition,
	expected_signature: Dictionary,
) -> bool:
	return _authored_definition_signature(on_disk) == expected_signature


static func _authored_definition_signature(enemy_definition: EnemyDefinition) -> Dictionary:
	return {
		"variant_id": enemy_definition.variant_id,
		"resource_name": enemy_definition.resource_name,
		"record": enemy_definition.to_record().duplicate(true),
	}


static func _remember_authored_definition(
	enemy_definition: EnemyDefinition,
	resource_path: String,
) -> void:
	_persisted_authored_definition_signatures[resource_path] = _authored_definition_signature(enemy_definition)


static func refresh_manifest_cache() -> Error:
	var manifest_path := CONTENT_MANIFEST_SERVICE_SCRIPT.ENEMY_MANIFEST_PATH
	if not FileAccess.file_exists(manifest_path):
		return ERR_FILE_NOT_FOUND
	var fresh_manifest := ResourceLoader.load(
		manifest_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ContentDefinitionManifestData
	if fresh_manifest == null or not _manifest_entries_match_file(fresh_manifest, manifest_path):
		return ERR_FILE_CANT_OPEN
	var manifest := ResourceLoader.load(
		manifest_path, "", ResourceLoader.CACHE_MODE_REPLACE
	) as ContentDefinitionManifestData
	if manifest == null or not _manifest_entries_match_file(manifest, manifest_path):
		return ERR_FILE_CANT_OPEN
	_enemy_manifest_dependency = manifest
	invalidate_cache()
	return OK


static func _manifest_entries_match_file(
	manifest: ContentDefinitionManifestData,
	manifest_path: String,
) -> bool:
	if not CONTENT_MANIFEST_SERVICE_SCRIPT.loaded_manifest_matches_file(manifest, manifest_path):
		return false
	for raw_entry: Variant in manifest.entries:
		var enemy_definition := raw_entry as EnemyDefinition
		if enemy_definition == null:
			return false
	return true


static func _snapshot_transaction_files(resource_path: String) -> Dictionary:
	var paths: Array[String] = [
		resource_path,
		resource_path + ".uid",
		CATALOG_RESOURCE_PATH,
		CATALOG_RESOURCE_PATH + ".uid",
	]
	for manifest_path: String in GENERATED_MANIFEST_PATHS:
		paths.append(manifest_path)
		paths.append(manifest_path + ".uid")
	var snapshot: Dictionary = {}
	for path: String in paths:
		var exists := FileAccess.file_exists(path)
		snapshot[path] = {
			"exists": exists,
			"bytes": FileAccess.get_file_as_bytes(path) if exists else PackedByteArray(),
		}
	return snapshot


static func _restore_transaction_files(snapshot: Dictionary) -> Error:
	var first_error := OK
	for path: String in snapshot:
		var state: Dictionary = snapshot[path]
		if bool(state.get("exists", false)):
			var bytes: PackedByteArray = state.get("bytes", PackedByteArray())
			var write_error := _write_file_bytes(path, bytes)
			if write_error == OK and FileAccess.get_file_as_bytes(path) != bytes:
				write_error = ERR_FILE_CANT_WRITE
			if first_error == OK and write_error != OK:
				first_error = write_error
		elif FileAccess.file_exists(path):
			var remove_error := _remove_resource_file(path)
			if first_error == OK and remove_error != OK:
				first_error = remove_error
	return first_error


static func _rollback_authored_definition_transaction(
	original_entries: Array[Resource],
	original_files: Dictionary,
	enemy_definition: EnemyDefinition,
	original_resource_path: String,
) -> void:
	_restore_definition_entries(original_entries)
	var file_restore_error := _restore_transaction_files(original_files)
	enemy_definition.take_over_path(original_resource_path)
	DATA.emit_changed()
	var manifest_cache_error := refresh_manifest_cache()
	invalidate_cache()
	_report_rollback_errors(file_restore_error, OK, manifest_cache_error)


static func _remove_authored_definition_files(resource_path: String) -> Error:
	var remove_error := _remove_resource_file(resource_path)
	if remove_error != OK:
		return remove_error
	return _remove_resource_file(resource_path + ".uid")


static func _write_file_bytes(resource_path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(resource_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error


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
