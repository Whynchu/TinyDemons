@tool
extends RefCounted
class_name ContentDefinitionManifestService

## Shared deterministic manifest writer used by the editor dock and CLI.
## Verification only compares the checked-in file; it never repairs it.

const MANIFEST_PATH := "res://resources/generated/content_definition_manifest.tres"
const MANIFEST_SCRIPT_PATH := "res://scripts/content/content_definition_manifest_data.gd"
const ENEMY_MANIFEST_PATH := "res://resources/generated/enemy_definition_manifest.tres"
const ITEM_MANIFEST_PATH := "res://resources/generated/item_definition_manifest.tres"
const ITEM_DEFINITION_ROOT := "res://resources/definitions/items/"
const KIND_MANIFEST_PATHS := {
	&"enemy": ENEMY_MANIFEST_PATH,
	&"item": ITEM_MANIFEST_PATH,
}
const SOURCE_ROOTS := [
	"res://resources/definitions",
	"res://resources/content",
]


static func discover_resource_paths() -> PackedStringArray:
	var paths: Array[String] = []
	for root in SOURCE_ROOTS:
		_append_resource_paths(root, paths)
	paths.sort()
	return PackedStringArray(paths)


static func refresh_manifest() -> Error:
	var paths := discover_resource_paths()
	if paths.is_empty():
		return ERR_DOES_NOT_EXIST
	var expected_manifests := _expected_manifests(paths)
	for manifest_path in [MANIFEST_PATH, ENEMY_MANIFEST_PATH, ITEM_MANIFEST_PATH]:
		if str(expected_manifests[manifest_path]).is_empty():
			return ERR_DOES_NOT_EXIST
	for manifest_path in [MANIFEST_PATH, ENEMY_MANIFEST_PATH, ITEM_MANIFEST_PATH]:
		var expected := str(expected_manifests[manifest_path])
		if FileAccess.file_exists(manifest_path) and FileAccess.get_file_as_string(manifest_path) == expected:
			continue
		var absolute_directory := ProjectSettings.globalize_path(manifest_path.get_base_dir())
		var directory_error := DirAccess.make_dir_recursive_absolute(absolute_directory)
		if directory_error != OK and not DirAccess.dir_exists_absolute(absolute_directory):
			return directory_error
		var file := FileAccess.open(manifest_path, FileAccess.WRITE)
		if file == null:
			return FileAccess.get_open_error()
		file.store_string(expected)
		file.flush()
		file.close()
	return OK


static func check_freshness() -> Array[String]:
	var problems: Array[String] = []
	var paths := discover_resource_paths()
	if paths.is_empty():
		problems.append("no authored .tres resources were found in the supported roots")
		return problems
	var expected_manifests := _expected_manifests(paths)
	for manifest_path in [MANIFEST_PATH, ENEMY_MANIFEST_PATH, ITEM_MANIFEST_PATH]:
		if not FileAccess.file_exists(manifest_path):
			problems.append("generated content manifest is missing: %s; run 'tools/dev.ps1 manifest refresh'" % manifest_path)
		elif FileAccess.get_file_as_string(manifest_path) != str(expected_manifests[manifest_path]):
			problems.append("generated content manifest is stale: %s; run 'tools/dev.ps1 manifest refresh'" % manifest_path)
	return problems


static func load_entries() -> Array[Resource]:
	var cache_mode := ResourceLoader.CACHE_MODE_REPLACE if Engine.is_editor_hint() else ResourceLoader.CACHE_MODE_REUSE
	var manifest := ResourceLoader.load(MANIFEST_PATH, "", cache_mode) as Resource
	return _entries_from_manifest(manifest)


static func load_kind_entries(kind: StringName, export_dependency: Resource) -> Array[Resource]:
	var manifest_path := str(KIND_MANIFEST_PATHS.get(kind, ""))
	if manifest_path.is_empty():
		return []
	var manifest := export_dependency
	if Engine.is_editor_hint():
		# Refresh can rewrite the file while the exported-build dependency remains
		# preloaded. Replace the editor copy so new paths are immediately visible.
		manifest = ResourceLoader.load(manifest_path, "", ResourceLoader.CACHE_MODE_REPLACE) as Resource
	elif manifest == null:
		manifest = ResourceLoader.load(manifest_path) as Resource
	return _entries_from_manifest(manifest)


static func _entries_from_manifest(manifest: Resource) -> Array[Resource]:
	var result: Array[Resource] = []
	if manifest == null:
		return result
	var raw_entries := manifest.get("entries") as Array
	for raw_entry: Variant in raw_entries:
		var entry := raw_entry as Resource
		if entry != null:
			result.append(entry)
	return result


static func _expected_manifests(paths: PackedStringArray) -> Dictionary:
	var enemy_paths: Array[String] = []
	var item_paths: Array[String] = []
	for path in paths:
		var script_class := _script_class_for(path)
		if script_class == "EnemyDefinition":
			enemy_paths.append(path)
		if script_class == "ItemDefinition" or path.begins_with(ITEM_DEFINITION_ROOT):
			item_paths.append(path)
	return {
		MANIFEST_PATH: _manifest_text(paths),
		ENEMY_MANIFEST_PATH: _manifest_text(PackedStringArray(enemy_paths)),
		ITEM_MANIFEST_PATH: _manifest_text(PackedStringArray(item_paths)),
	}


static func _script_class_for(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var header := file.get_line()
	file.close()
	var marker := "script_class=\""
	var marker_start := header.find(marker)
	if marker_start < 0:
		return ""
	var value_start := marker_start + marker.length()
	var value_end := header.find("\"", value_start)
	return header.substr(value_start, value_end - value_start) if value_end > value_start else ""


static func _manifest_text(source_paths: PackedStringArray) -> String:
	if source_paths.is_empty():
		return ""
	var lines := PackedStringArray()
	lines.append('[gd_resource type="Resource" script_class="ContentDefinitionManifestData" load_steps=%d format=3]' % (source_paths.size() + 2))
	lines.append("")
	lines.append('[ext_resource type="Script" path=%s id="manifest_script"]' % JSON.stringify(MANIFEST_SCRIPT_PATH))
	var references := PackedStringArray()
	for index in source_paths.size():
		var resource_id := "content_%04d" % index
		lines.append('[ext_resource type="Resource" path=%s id="%s"]' % [JSON.stringify(source_paths[index]), resource_id])
		references.append('ExtResource("%s")' % resource_id)
	lines.append("")
	lines.append("[resource]")
	lines.append('script = ExtResource("manifest_script")')
	lines.append("entries = Array[Resource]([%s])" % ", ".join(references))
	return "\n".join(lines) + "\n"


static func _append_resource_paths(directory_path: String, output: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		return
	var files := directory.get_files()
	files.sort()
	for file_name in files:
		if file_name.get_extension().to_lower() == "tres":
			output.append(directory_path.path_join(file_name))
	var directories := directory.get_directories()
	directories.sort()
	for child_directory in directories:
		if child_directory.begins_with("."):
			continue
		_append_resource_paths(directory_path.path_join(child_directory), output)
