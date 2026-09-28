extends SceneTree

## Definition validator (Slice F, T2). Loads every authored definition resource
## and runs its validate() contract. Fails nonzero with a report when any
## definition is malformed, so CI preflight catches broken content before
## runtime. Run via tools/validate_definitions.ps1.

const ENEMY_FACTORY_SCRIPT = preload("res://scripts/enemy_factory.gd")
const CONTENT_MANIFEST_SERVICE := preload("res://scripts/content_definition_manifest_service.gd")

var _definition_resources: Array[Resource] = []
var _manifest_problems: Array[String] = []


func _initialize() -> void:
	_manifest_problems = CONTENT_MANIFEST_SERVICE.check_freshness()
	var discovered_paths: PackedStringArray = CONTENT_MANIFEST_SERVICE.discover_resource_paths()
	_definition_resources = CONTENT_MANIFEST_SERVICE.load_entries()
	if _definition_resources.size() != discovered_paths.size():
		_manifest_problems.append("generated manifest references %d of %d discovered resources" % [
			_definition_resources.size(), discovered_paths.size(),
		])
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = _manifest_problems.duplicate()
	var loaded := 0
	for resource in _definition_resources:
		if resource == null:
			failures.append("DEFINITION_LOAD_FAILED: generated manifest contains a null resource")
			continue
		var path := resource.resource_path
		if path.is_empty():
			failures.append("DEFINITION_PATH_MISSING: manifest entry has no source path")
			continue
		loaded += 1
		if resource.has_method("validate"):
			var problems := resource.call("validate") as Array
			for problem in problems:
				failures.append("%s: %s" % [path, str(problem)])
		else:
			failures.append_array(_structural_checks(path, resource, _kind_for_path(path)))
	if ENEMY_FACTORY_SCRIPT.weighted_variants_for_type(&"skeleton").is_empty():
		failures.append("enemy catalog has no registered skeleton variants with encounter weight")
	print("DEFINITION_VALIDATOR loaded=%d/%d" % [loaded, CONTENT_MANIFEST_SERVICE.discover_resource_paths().size()])
	if failures.is_empty():
		print("DEFINITION_VALIDATOR_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _kind_for_path(path: String) -> String:
	match path.get_file().get_basename():
		"item_catalog":
			return "ItemCatalogData"
		"slime_variant_catalog":
			return "SlimeVariantCatalogData"
		"dungeon_layout_run1", "dungeon_layout_run2":
			return "DungeonRunDefinition"
		"puzzle_map_r3", "puzzle_map_r3_new", "puzzle_map_r4", "puzzle_map_r5":
			return "PuzzlePlanData"
		"element_catalog":
			return "ElementCatalogData"
		"palette_library":
			return "PaletteLibraryData"
		"touch_controls_layout":
			return "TouchControlsLayoutProfile"
	return ""


func _structural_checks(path: String, resource: Resource, kind: String) -> Array[String]:
	var problems: Array[String] = []
	match kind:
		"ItemCatalogData":
			if (resource.get("definitions") as Dictionary).is_empty():
				problems.append("%s: item definitions are empty" % path)
			if (resource.get("live_base_definitions") as Dictionary).is_empty():
				problems.append("%s: live base definitions are empty" % path)
		"SlimeVariantCatalogData":
			if (resource.get("definitions") as Dictionary).is_empty():
				problems.append("%s: slime variant definitions are empty" % path)
			var order := resource.get("order") as Array
			if order.is_empty():
				problems.append("%s: slime variant order is empty" % path)
		"ElementCatalogData":
			var element_ids := resource.get("ids") as Dictionary
			var display_names := resource.get("display_names") as Dictionary
			var palette_keys := resource.get("palette_keys") as Dictionary
			var matchup_table := resource.get("matchup_table") as Array
			var element_count := int(resource.get("element_count"))
			if element_ids.is_empty() or display_names.is_empty() or palette_keys.is_empty():
				problems.append("%s: element lookup tables are incomplete" % path)
			if element_count <= 0 or matchup_table.size() != element_count:
				problems.append("%s: element matchup table does not match element_count" % path)
		"PaletteLibraryData":
			var palette_names := resource.get("palette_names") as Array
			var shadow := resource.get("shadow") as Dictionary
			var normal := resource.get("normal") as Dictionary
			var accent := resource.get("accent") as Dictionary
			var highlights := resource.get("archetype_highlights") as Array
			if palette_names.is_empty() or shadow.is_empty() or normal.is_empty() or accent.is_empty():
				problems.append("%s: palette tables are incomplete" % path)
			if highlights.is_empty():
				problems.append("%s: palette highlight list is empty" % path)
		"TouchControlsLayoutProfile":
			if not resource.has_method("offsets") or (resource.call("offsets") as Dictionary).size() != 4:
				problems.append("%s: touch layout must expose four control offsets" % path)
		"DungeonRunDefinition":
			if (resource.get("rooms") as Array).is_empty():
				problems.append("%s: run has no rooms" % path)
			if (resource.get("layout_id") as StringName) == &"":
				problems.append("%s: run layout id is empty" % path)
		"PuzzlePlanData":
			if (resource.get("plan_id") as StringName) == &"":
				problems.append("%s: puzzle plan id is empty" % path)
			if (resource.get("markers") as Array).is_empty():
				problems.append("%s: puzzle plan has no markers" % path)
			if path.ends_with("puzzle_map_r5.tres") and (resource.get("plan_id") as StringName) != &"r5":
				problems.append("%s: R5 puzzle plan id must be r5" % path)
	return problems
