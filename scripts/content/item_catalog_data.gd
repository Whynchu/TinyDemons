@tool
extends Resource
class_name ItemCatalogData

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
	for resource: Resource in CONTENT_MANIFEST_SERVICE_SCRIPT.load_kind_entries(&"item", ITEM_MANIFEST_EXPORT_DEPENDENCY):
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
