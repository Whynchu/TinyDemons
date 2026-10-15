@tool
extends Resource
class_name ItemCatalogData
# Owner: ItemCatalogData owns item definition discovery and standalone lifecycle transactions.

## Editor-inspectable item catalog data. Explicit baseline/set ID order and
## legacy definition data live here; catalog-owned and standalone
## ItemDefinitions are loaded through the generated manifest.

@export var live_base_ids: Array[StringName] = []
@export var live_set_ids: Array[StringName] = []
@export var definitions: Dictionary = {}
@export var definition_metadata: Dictionary = {}
@export var transmutations: Dictionary = {}
## Explicit references keep special-acquisition definitions reachable even when
## they are not part of the generated authored-definition set.
@export var authored_definitions: Array[Resource] = []

const AUTHORED_ITEM_ROOT := "res://resources/definitions/items"
const DEFAULT_DATA_PATH := "res://resources/definitions/item_catalog.tres"
const CONTENT_MANIFEST_SERVICE_SCRIPT := preload("res://scripts/content/content_definition_manifest_service.gd")
const ITEM_MANIFEST_EXPORT_DEPENDENCY := preload("res://resources/generated/item_definition_manifest.tres")
const ITEM_MANIFEST_PATH := "res://resources/generated/item_definition_manifest.tres"
const GENERATED_MANIFEST_PATHS: Array[String] = [
	"res://resources/generated/content_definition_manifest.tres",
	"res://resources/generated/enemy_definition_manifest.tres",
	ITEM_MANIFEST_PATH,
]
var _item_manifest_dependency: Resource = ITEM_MANIFEST_EXPORT_DEPENDENCY
var _authored_definition_resources_cache: Array[Resource] = []
var _authored_definition_resources_loaded := false
var _authored_definition_data_cache: Dictionary = {}
var _authored_definition_data_loaded := false
var _authored_live_ids_cache: Array[StringName] = []
var _authored_live_ids_loaded := false


func authored_definition_resources() -> Array[Resource]:
	if _authored_definition_resources_loaded:
		return _authored_definition_resources_cache
	var resources: Array[Resource] = authored_definitions.duplicate()
	var seen_resource_ids: Dictionary = {}
	var seen_resource_paths: Dictionary = {}
	for resource: Resource in resources:
		if resource != null:
			seen_resource_ids[resource.get_instance_id()] = true
			if not resource.resource_path.is_empty():
				seen_resource_paths[resource.resource_path] = true
	for resource: Resource in CONTENT_MANIFEST_SERVICE_SCRIPT.load_kind_entries(&"item", item_manifest_resource()):
		if resource == null:
			continue
		var is_legacy_item_root_resource := resource.resource_path.begins_with(AUTHORED_ITEM_ROOT + "/")
		if resource as ItemDefinition == null and not is_legacy_item_root_resource:
			continue
		var instance_id := resource.get_instance_id()
		var source_path := resource.resource_path
		if seen_resource_ids.has(instance_id) or (not source_path.is_empty() and seen_resource_paths.has(source_path)):
			continue
		seen_resource_ids[instance_id] = true
		if not source_path.is_empty():
			seen_resource_paths[source_path] = true
		resources.append(resource)
	_authored_definition_resources_cache = resources
	_authored_definition_resources_loaded = true
	return _authored_definition_resources_cache


func invalidate_authored_definition_cache() -> void:
	_authored_definition_resources_cache.clear()
	_authored_definition_resources_loaded = false
	_authored_definition_data_cache.clear()
	_authored_definition_data_loaded = false
	_authored_live_ids_cache.clear()
	_authored_live_ids_loaded = false


func item_manifest_resource() -> Resource:
	return _item_manifest_dependency


static func invalidate_default_cache() -> void:
	var default_data := load(DEFAULT_DATA_PATH) as ItemCatalogData
	if default_data != null:
		default_data.invalidate_authored_definition_cache()


func authored_definition_resource(definition_id: StringName) -> ItemDefinition:
	for resource: Resource in authored_definition_resources():
		var definition := resource as ItemDefinition
		if definition != null and definition.id == definition_id:
			return definition
	return null


func save_authored_definition(definition: ItemDefinition) -> int:
	if definition == null:
		return ERR_INVALID_PARAMETER
	if definition.catalog_owned:
		return ERR_INVALID_PARAMETER
	var source_path := definition.resource_path
	if not source_path.begins_with(AUTHORED_ITEM_ROOT + "/") or source_path.get_extension().to_lower() != "tres":
		return ERR_INVALID_PARAMETER
	if not definition.validate().is_empty():
		return ERR_INVALID_DATA
	if definition.id in live_base_ids or definition.id in live_set_ids:
		return ERR_ALREADY_EXISTS
	for raw_id: Variant in definitions.keys():
		if StringName(str(raw_id)) == definition.id:
			return ERR_ALREADY_EXISTS
	var existing := authored_definition_resource(definition.id)
	if existing != null and existing != definition:
		if existing.catalog_owned or existing.resource_path != source_path:
			return ERR_ALREADY_EXISTS
	var save_error := ResourceSaver.save(definition, source_path)
	if save_error == OK:
		invalidate_authored_definition_cache()
	return save_error


func create_authored_definition(definition: ItemDefinition, resource_path: String) -> Error:
	if definition == null or definition.catalog_owned or definition.id.is_empty():
		return ERR_INVALID_PARAMETER
	if not _is_valid_authored_item_id(definition.id):
		return ERR_INVALID_PARAMETER
	if _authored_item_id_exists(definition.id):
		return ERR_ALREADY_EXISTS
	var normalized_path := _normalized_authored_item_path(resource_path, definition.id)
	if normalized_path.is_empty():
		return ERR_INVALID_PARAMETER
	if _authored_item_path_is_occupied(normalized_path):
		return ERR_ALREADY_EXISTS
	if not definition.validate().is_empty():
		return ERR_INVALID_DATA

	var original_resource_path := definition.resource_path
	var original_manifest_dependency := _copy_item_manifest_dependency()
	var original_manifests := _snapshot_generated_manifests()
	var save_error := ResourceSaver.save(
		definition, normalized_path, ResourceSaver.FLAG_CHANGE_PATH
	)
	if save_error != OK:
		var partial_file_error := _remove_authored_item_files(normalized_path)
		definition.take_over_path(original_resource_path)
		_report_item_rollback_errors(partial_file_error, OK)
		return save_error
	definition.take_over_path(normalized_path)

	var manifest_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
	if manifest_error == OK:
		manifest_error = _replace_item_manifest_dependency()
	if manifest_error != OK:
		var resource_rollback_error := _remove_authored_item_files(normalized_path)
		var manifest_rollback_error := _restore_generated_manifests(original_manifests)
		var manifest_cache_error := _restore_item_manifest_dependency(original_manifest_dependency)
		if manifest_rollback_error == OK:
			manifest_rollback_error = manifest_cache_error
		definition.take_over_path(original_resource_path)
		definition.emit_changed()
		_invalidate_all_authored_definition_caches()
		_report_item_rollback_errors(resource_rollback_error, manifest_rollback_error)
		return manifest_error

	definition.emit_changed()
	_invalidate_all_authored_definition_caches()
	return OK


func remove_authored_definition(definition: ItemDefinition, resource_path: String = "") -> Error:
	if definition == null or definition.catalog_owned:
		return ERR_INVALID_PARAMETER
	var requested_path := resource_path if not resource_path.is_empty() else definition.resource_path
	var normalized_path := _normalized_authored_item_path(requested_path, definition.id)
	if normalized_path.is_empty() or definition.resource_path != normalized_path:
		return ERR_INVALID_PARAMETER
	if not FileAccess.file_exists(normalized_path):
		return ERR_DOES_NOT_EXIST
	var on_disk := ResourceLoader.load(
		normalized_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	if on_disk == null or not _stored_authored_definition_matches(on_disk, definition):
		return ERR_INVALID_DATA

	var original_resource_bytes := FileAccess.get_file_as_bytes(normalized_path)
	var uid_path := normalized_path + ".uid"
	var original_uid_exists := FileAccess.file_exists(uid_path)
	var original_uid_bytes := FileAccess.get_file_as_bytes(uid_path) if original_uid_exists else PackedByteArray()
	var original_resource_path := definition.resource_path
	var original_manifest_dependency := _copy_item_manifest_dependency()
	var original_manifests := _snapshot_generated_manifests()
	var delete_error := _remove_authored_item_files(normalized_path)
	if delete_error != OK:
		var resource_restore_error := _restore_authored_item_files(
			normalized_path, original_resource_bytes, original_uid_exists, original_uid_bytes
		)
		_report_item_rollback_errors(resource_restore_error, OK)
		return delete_error

	var manifest_error := CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest()
	if manifest_error == OK:
		manifest_error = _replace_item_manifest_dependency()
	if manifest_error != OK:
		var resource_rollback_error := _restore_authored_item_files(
			normalized_path, original_resource_bytes, original_uid_exists, original_uid_bytes
		)
		var manifest_rollback_error := _restore_generated_manifests(original_manifests)
		var manifest_cache_error := _restore_item_manifest_dependency(original_manifest_dependency)
		if manifest_rollback_error == OK:
			manifest_rollback_error = manifest_cache_error
		definition.take_over_path(original_resource_path)
		definition.emit_changed()
		_invalidate_all_authored_definition_caches()
		_report_item_rollback_errors(resource_rollback_error, manifest_rollback_error)
		return manifest_error

	definition.take_over_path("")
	definition.emit_changed()
	_invalidate_all_authored_definition_caches()
	return OK


func _stored_authored_definition_matches(
	on_disk: ItemDefinition,
	expected: ItemDefinition,
) -> bool:
	return (
		on_disk.id == expected.id
		and on_disk.live == expected.live
		and on_disk.catalog_owned == expected.catalog_owned
		and on_disk.resource_name == expected.resource_name
		and on_disk.to_record() == expected.to_record()
	)


func _is_valid_authored_item_id(item_id: StringName) -> bool:
	var pattern := RegEx.new()
	pattern.compile("^[a-z][a-z0-9_]*$")
	return pattern.search(String(item_id)) != null


func _normalized_authored_item_path(resource_path: String, item_id: StringName) -> String:
	if resource_path.is_empty() or not _is_valid_authored_item_id(item_id):
		return ""
	var normalized_path := resource_path.simplify_path()
	var expected_path := AUTHORED_ITEM_ROOT.path_join("%s.tres" % String(item_id))
	if resource_path != normalized_path or normalized_path != expected_path:
		return ""
	if normalized_path.get_base_dir() != AUTHORED_ITEM_ROOT or normalized_path.get_extension() != "tres":
		return ""
	return normalized_path


func _authored_item_path_is_occupied(resource_path: String) -> bool:
	return (
		FileAccess.file_exists(resource_path)
		or FileAccess.file_exists(resource_path + ".uid")
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(resource_path))
	)


func _authored_item_id_exists(item_id: StringName) -> bool:
	if item_id in live_base_ids or item_id in live_set_ids:
		return true
	for raw_id: Variant in definitions.keys():
		if StringName(str(raw_id)) == item_id:
			return true
	for resource: Resource in authored_definition_resources():
		var definition := resource as ItemDefinition
		if definition != null and definition.id == item_id:
			return true
	# The manifest is the runtime registry, but checking item-root files here also
	# prevents a stale generated manifest from hiding a duplicate authored ID.
	for resource_path: String in CONTENT_MANIFEST_SERVICE_SCRIPT.discover_resource_paths():
		if not resource_path.begins_with(AUTHORED_ITEM_ROOT + "/"):
			continue
		if not _resource_declares_item_definition(resource_path):
			continue
		var definition := ResourceLoader.load(
			resource_path, "", ResourceLoader.CACHE_MODE_REUSE
		) as ItemDefinition
		if definition != null and definition.id == item_id:
			return true
	return false


func _resource_declares_item_definition(resource_path: String) -> bool:
	var file := FileAccess.open(resource_path, FileAccess.READ)
	if file == null:
		return false
	var header := file.get_line()
	file.close()
	return header.contains("script_class=\"ItemDefinition\"")


func _copy_item_manifest_dependency() -> Resource:
	if _item_manifest_dependency == null:
		return null
	return _item_manifest_dependency.duplicate(true) as Resource


func _restore_item_manifest_dependency(original_dependency: Resource) -> Error:
	if not FileAccess.file_exists(ITEM_MANIFEST_PATH):
		_item_manifest_dependency = original_dependency
		return OK
	var reload_error := _replace_item_manifest_dependency()
	if reload_error != OK:
		_item_manifest_dependency = original_dependency
	return reload_error


func _replace_item_manifest_dependency() -> Error:
	var refreshed_manifest := ResourceLoader.load(
		ITEM_MANIFEST_PATH, "", ResourceLoader.CACHE_MODE_REPLACE
	) as Resource
	if refreshed_manifest == null:
		return ERR_FILE_CANT_OPEN
	_item_manifest_dependency = refreshed_manifest
	return OK


func _snapshot_generated_manifests() -> Dictionary:
	var snapshot: Dictionary = {}
	for manifest_path: String in GENERATED_MANIFEST_PATHS:
		var exists := FileAccess.file_exists(manifest_path)
		snapshot[manifest_path] = {
			"exists": exists,
			"bytes": FileAccess.get_file_as_bytes(manifest_path) if exists else PackedByteArray(),
		}
	return snapshot


func _restore_generated_manifests(snapshot: Dictionary) -> Error:
	var first_error := OK
	for manifest_path: String in GENERATED_MANIFEST_PATHS:
		var state: Dictionary = snapshot.get(manifest_path, {})
		if bool(state.get("exists", false)):
			var original_bytes: PackedByteArray = state.get("bytes", PackedByteArray())
			var write_error := _write_file_bytes(manifest_path, original_bytes)
			if write_error == OK and FileAccess.get_file_as_bytes(manifest_path) != original_bytes:
				write_error = ERR_FILE_CANT_WRITE
			if first_error == OK and write_error != OK:
				first_error = write_error
		elif FileAccess.file_exists(manifest_path):
			var remove_error := _remove_authored_item_file(manifest_path)
			if first_error == OK and remove_error != OK:
				first_error = remove_error
	return first_error


func _restore_authored_item_files(
	resource_path: String,
	resource_bytes: PackedByteArray,
	uid_exists: bool,
	uid_bytes: PackedByteArray,
) -> Error:
	var first_error := _write_file_bytes(resource_path, resource_bytes)
	if first_error == OK and FileAccess.get_file_as_bytes(resource_path) != resource_bytes:
		first_error = ERR_FILE_CANT_WRITE
	var uid_path := resource_path + ".uid"
	var uid_error := _write_file_bytes(uid_path, uid_bytes) if uid_exists else _remove_authored_item_file(uid_path)
	if uid_exists and uid_error == OK and FileAccess.get_file_as_bytes(uid_path) != uid_bytes:
		uid_error = ERR_FILE_CANT_WRITE
	if first_error == OK and uid_error != OK:
		first_error = uid_error
	return first_error


func _remove_authored_item_files(resource_path: String) -> Error:
	var remove_error := _remove_authored_item_file(resource_path)
	if remove_error != OK:
		return remove_error
	return _remove_authored_item_file(resource_path + ".uid")


func _remove_authored_item_file(resource_path: String) -> Error:
	if not FileAccess.file_exists(resource_path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))


func _write_file_bytes(resource_path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(resource_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error


func _invalidate_all_authored_definition_caches() -> void:
	invalidate_authored_definition_cache()
	var default_data := load(DEFAULT_DATA_PATH) as ItemCatalogData
	if default_data != null:
		default_data._item_manifest_dependency = _item_manifest_dependency
		default_data.invalidate_authored_definition_cache()


func _report_item_rollback_errors(resource_error: Error, manifest_error: Error) -> void:
	var rollback_errors := PackedStringArray()
	if resource_error != OK:
		rollback_errors.append("resource rollback failed (%d)" % resource_error)
	if manifest_error != OK:
		rollback_errors.append("manifest rollback failed (%d)" % manifest_error)
	if not rollback_errors.is_empty():
		push_error("ItemCatalogData rollback failure: %s" % "; ".join(rollback_errors))


## Derived projections of the authored resource set. Each one is cached beside
## authored_definition_resources() because every ItemCatalog construction needs
## them, and pickups and chest opens construct a catalog per call.
func authored_definition_data() -> Dictionary:
	if _authored_definition_data_loaded:
		return _authored_definition_data_cache
	var result: Dictionary = {}
	for resource: Resource in authored_definition_resources():
		if not resource.has_method("to_record") or not resource.has_method("validate"):
			continue
		var definition_id := StringName(str(resource.get("id")))
		if definition_id.is_empty():
			continue
		result[definition_id] = resource.call("to_record")
	_authored_definition_data_cache = result
	_authored_definition_data_loaded = true
	return _authored_definition_data_cache


func authored_live_ids() -> Array[StringName]:
	if _authored_live_ids_loaded:
		return _authored_live_ids_cache
	var result: Array[StringName] = []
	for resource: Resource in authored_definition_resources():
		if not bool(resource.get("live")):
			continue
		var definition_id := StringName(str(resource.get("id")))
		if not definition_id.is_empty():
			result.append(definition_id)
	_authored_live_ids_cache = result
	_authored_live_ids_loaded = true
	return _authored_live_ids_cache


func validate() -> Array[String]:
	var problems: Array[String] = []
	if live_base_ids.is_empty():
		problems.append("live_base_ids must not be empty")
	if live_set_ids.is_empty():
		problems.append("live_set_ids must not be empty")
	var baseline_ids: Dictionary = {}
	for definition_id: StringName in live_base_ids:
		if definition_id.is_empty():
			problems.append("live_base_ids must not contain empty IDs")
		elif baseline_ids.has(definition_id):
			problems.append("live_base_ids contains duplicate ID '%s'" % definition_id)
		baseline_ids[definition_id] = true
	var set_item_ids: Dictionary = {}
	for definition_id: StringName in live_set_ids:
		if definition_id.is_empty():
			problems.append("live_set_ids must not contain empty IDs")
		elif set_item_ids.has(definition_id):
			problems.append("live_set_ids contains duplicate ID '%s'" % definition_id)
		elif baseline_ids.has(definition_id):
			problems.append("item ID '%s' appears in both live_base_ids and live_set_ids" % definition_id)
		set_item_ids[definition_id] = true
	var seen: Dictionary = {}
	for definition_id: Variant in definitions:
		seen[StringName(str(definition_id))] = "item_catalog.tres"
	var catalog_owned_ids: Dictionary = {}
	for resource: Resource in authored_definition_resources():
		var definition := resource as ItemDefinition
		if definition == null or not resource.has_method("to_record") or not resource.has_method("validate"):
			problems.append("%s: resource must use the ItemDefinition contract" % resource.resource_path)
			continue
		var definition_id := definition.id
		if definition_id in seen:
			problems.append("duplicate item definition id '%s' (already owned by %s)" % [definition_id, seen[definition_id]])
		else:
			seen[definition_id] = resource.resource_path
		if definition.catalog_owned:
			catalog_owned_ids[definition_id] = definition
			if not definition.live:
				problems.append("%s: catalog-owned definitions must be live" % resource.resource_path)
		var resource_problems := resource.call("validate") as Array
		for problem: Variant in resource_problems:
			problems.append("%s: %s" % [resource.resource_path, str(problem)])
	for definition_id: StringName in live_base_ids:
		var definition := catalog_owned_ids.get(definition_id) as ItemDefinition
		if definition == null:
			problems.append("live baseline '%s' is missing its catalog-owned ItemDefinition" % definition_id)
		elif not definition.live:
			problems.append("live baseline '%s' is not marked live" % definition_id)
		elif definition.gear_tier not in [&"plain", &"basic"]:
			problems.append("live baseline '%s' must use the plain or basic gear tier" % definition_id)
	for definition_id: StringName in live_set_ids:
		var definition := catalog_owned_ids.get(definition_id) as ItemDefinition
		if definition == null:
			problems.append("live set item '%s' is missing its catalog-owned ItemDefinition" % definition_id)
			continue
		if not definition.live:
			problems.append("live set item '%s' is not marked live" % definition_id)
		if definition.gear_tier != &"set":
			problems.append("live set item '%s' must use the set gear tier" % definition_id)
		if definition.set_id.is_empty() or definition.set_name != String(definition.set_id).to_upper():
			problems.append("live set item '%s' has an invalid set identity" % definition_id)
		if definition.id != StringName("%s_%s" % [String(definition.set_id), String(definition.slot)]):
			problems.append("live set item '%s' must match its set and slot identity" % definition_id)
	for definition_id: StringName in catalog_owned_ids:
		if not baseline_ids.has(definition_id) and not set_item_ids.has(definition_id):
			problems.append("catalog-owned definition '%s' is missing from the ordered live item IDs" % definition_id)
	for raw_id: Variant in definition_metadata:
		if baseline_ids.has(StringName(str(raw_id))):
			problems.append("live baseline '%s' still has a legacy metadata overlay" % str(raw_id))
		elif set_item_ids.has(StringName(str(raw_id))):
			problems.append("live set item '%s' still has a legacy metadata overlay" % str(raw_id))
	return problems
