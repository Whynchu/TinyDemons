extends SceneTree

## Definition validator (Slice F, T2). Loads every authored definition resource
## and runs its validate() contract. Fails nonzero with a report when any
## definition is malformed, so CI preflight catches broken content before
## runtime. Run via tools/validate_definitions.ps1.

const DEFINITION_ROOT := "res://resources/definitions"

var _definition_paths: Array[String] = []


func _initialize() -> void:
	_definition_paths = _discover_definition_paths(DEFINITION_ROOT)
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var loaded := 0
	for path in _definition_paths:
		var resource := load(path)
		if resource == null:
			failures.append("DEFINITION_LOAD_FAILED: %s" % path)
			continue
		loaded += 1
		if resource.has_method("validate"):
			var problems := resource.call("validate") as Array
			for problem in problems:
				failures.append("%s: %s" % [path, str(problem)])
		else:
			failures.append_array(_structural_checks(path, resource, _kind_for_path(path)))
	print("DEFINITION_VALIDATOR loaded=%d/%d" % [loaded, _definition_paths.size()])
	if failures.is_empty():
		print("DEFINITION_VALIDATOR_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _discover_definition_paths(directory_path: String) -> Array[String]:
	var paths: Array[String] = []
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return paths
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			var entry_path := directory_path.path_join(entry)
			if directory.current_is_dir():
				paths.append_array(_discover_definition_paths(entry_path))
			elif entry.get_extension().to_lower() == "tres":
				paths.append(entry_path)
		entry = directory.get_next()
	directory.list_dir_end()
	paths.sort()
	return paths


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
