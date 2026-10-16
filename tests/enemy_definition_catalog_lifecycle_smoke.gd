extends SceneTree

## Focused saved-resource lifecycle for the editor-created enemy definition action.

const ENEMY_CATALOG_SCRIPT := preload("res://scripts/content/enemy_catalog.gd")
const CONTENT_MANIFEST_SERVICE_SCRIPT := preload("res://scripts/content/content_definition_manifest_service.gd")
const GENERATED_MANIFEST_PATHS: Array[String] = [
	CONTENT_MANIFEST_SERVICE_SCRIPT.MANIFEST_PATH,
	CONTENT_MANIFEST_SERVICE_SCRIPT.ENEMY_MANIFEST_PATH,
	CONTENT_MANIFEST_SERVICE_SCRIPT.ITEM_MANIFEST_PATH,
]

var _finished := false
var _active_fixture: EnemyDefinition
var _active_fixture_path := ""
var _active_fixture_owned := false
var _active_fixture_uid_owned := false
var _baseline_initialized := false
var _baseline_catalog_entries: Array[Resource] = []
var _baseline_catalog_file: Dictionary = {}
var _baseline_catalog_uid_file: Dictionary = {}
var _baseline_manifest_files: Dictionary = {}
var _post_delete_fault_active := false
var _post_delete_fault_path := ""
var _post_delete_fault_reserved := false
var _post_delete_fault_state: Dictionary = {}


class WorkbenchProbe:
	extends Node

	var selected_variant_id: StringName = &""
	var last_notice := ""

	func _select_variant_after_catalog_change(variant_id: StringName, notice: String) -> void:
		selected_variant_id = variant_id
		last_notice = notice


func _initialize() -> void:
	create_timer(90.0).timeout.connect(_watchdog)
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	_capture_baseline_state()
	var source_definition := ENEMY_CATALOG_SCRIPT.definition_resource(&"guard_slime")
	_expect(source_definition != null, "catalog lifecycle fixture has a source definition", failures)
	if source_definition == null:
		_restore_baseline_state(failures)
		_finish(failures)
		return

	var fixture_id := StringName("codex_catalog_lifecycle_%d" % Time.get_ticks_usec())
	var definition_path := "res://resources/definitions/%s.tres" % fixture_id
	var traversal_path := "res://resources/definitions/../../addons/codex_traversal_fixture.tres"
	if ENEMY_CATALOG_SCRIPT.contains_id(fixture_id) or not _authored_path_is_unoccupied(definition_path):
		_expect(false, "generated fixture ID, path, and UID slot are reserved for this smoke", failures)
		_restore_baseline_state(failures)
		_finish(failures)
		return
	var fixture := source_definition.duplicate(true) as EnemyDefinition
	fixture.id = fixture_id
	fixture.display_name = "Catalog Lifecycle Fixture"
	fixture.resource_name = fixture.display_name
	_active_fixture = fixture
	_active_fixture_path = definition_path

	var traversal_error: Error = ENEMY_CATALOG_SCRIPT.create_authored_definition(fixture, traversal_path)
	_expect(traversal_error == ERR_INVALID_PARAMETER, "create rejects paths outside the definitions root", failures)
	_expect(not FileAccess.file_exists("res://addons/codex_traversal_fixture.tres"), "rejected traversal writes no file", failures)
	_characterize_create_boundaries(source_definition, fixture_id, definition_path, failures)

	var probe := WorkbenchProbe.new()
	root.add_child(probe)
	var adapter: RefCounted = ENEMY_CATALOG_SCRIPT.new()
	var workbench_ref: WeakRef = weakref(probe)
	var source_id: StringName = source_definition.variant_id

	_expect(not ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "catalog lifecycle ID is unused", failures)
	_expect(not FileAccess.file_exists(definition_path), "catalog lifecycle path is unused", failures)
	_expect(_authored_path_is_unoccupied(definition_path), "catalog lifecycle path and UID slot are unoccupied", failures)
	adapter.redo_authored_definition_action(
		fixture, definition_path, fixture_id, source_definition.display_name, workbench_ref
	)
	_active_fixture_owned = FileAccess.file_exists(definition_path) and ENEMY_CATALOG_SCRIPT.DATA.definitions.has(fixture)
	_active_fixture_uid_owned = FileAccess.file_exists(definition_path + ".uid")
	_expect(FileAccess.file_exists(definition_path), "create writes the standalone definition file", failures)
	_expect(fixture.resource_path == definition_path, "create assigns its saved resource path", failures)
	_expect(ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "create invalidates the catalog cache", failures)
	_expect(probe.selected_variant_id == fixture_id, "create selects the new variant", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "create refreshes generated manifests", failures)
	var created_catalog := ResourceLoader.load(
		ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as SlimeVariantCatalogData
	_expect(created_catalog != null and _catalog_contains_id(created_catalog, fixture_id), "saved catalog reload discovers the definition", failures)

	var saved_baseline_name := "Catalog Lifecycle Saved Baseline"
	fixture.display_name = saved_baseline_name
	fixture.resource_name = saved_baseline_name
	var save_error: Error = ENEMY_CATALOG_SCRIPT.save_definition(fixture)
	_expect(save_error == OK, "lifecycle saves an edited baseline through the catalog API", failures)
	var saved_fixture_record: Dictionary = fixture.to_record().duplicate(true)
	var saved_baseline_disk := ResourceLoader.load(
		definition_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EnemyDefinition
	_expect(
		saved_baseline_disk != null
			and saved_baseline_disk.to_record() == saved_fixture_record
			and saved_baseline_disk.resource_name == saved_baseline_name,
		"successful enemy save updates the persisted semantic baseline",
		failures
	)
	var unsaved_draft_name := "Catalog Lifecycle Unsaved Draft After Save"
	fixture.display_name = unsaved_draft_name
	fixture.resource_name = unsaved_draft_name
	_expect(fixture.to_record() != saved_fixture_record, "undo fixture holds a distinct unsaved in-memory draft", failures)
	var pre_undo_disk := ResourceLoader.load(
		definition_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EnemyDefinition
	_expect(
		pre_undo_disk != null
			and pre_undo_disk.to_record() == saved_fixture_record
			and pre_undo_disk.resource_name == saved_baseline_name,
		"unsaved draft leaves the newly saved enemy baseline unchanged before undo",
		failures
	)
	adapter.undo_authored_definition_action(fixture, definition_path, source_id, workbench_ref)
	_active_fixture_owned = FileAccess.file_exists(definition_path) and ENEMY_CATALOG_SCRIPT.DATA.definitions.has(fixture)
	_active_fixture_uid_owned = _active_fixture_uid_owned or FileAccess.file_exists(definition_path + ".uid")
	_expect(not FileAccess.file_exists(definition_path), "undo removes the standalone definition file", failures)
	_expect(fixture.resource_path.is_empty(), "undo clears the removed resource path", failures)
	_expect(
		fixture.display_name == unsaved_draft_name and fixture.resource_name == unsaved_draft_name,
		"undo preserves the unsaved draft in memory",
		failures
	)
	_expect(not ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "undo invalidates the catalog cache", failures)
	_expect(probe.selected_variant_id == source_id, "undo selects the source variant", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "undo refreshes generated manifests", failures)
	var removed_catalog := ResourceLoader.load(
		ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as SlimeVariantCatalogData
	_expect(removed_catalog != null and not _catalog_contains_id(removed_catalog, fixture_id), "saved catalog reload remains clear after undo", failures)

	adapter.redo_authored_definition_action(
		fixture, definition_path, fixture_id, source_definition.display_name, workbench_ref
	)
	_active_fixture_owned = FileAccess.file_exists(definition_path) and ENEMY_CATALOG_SCRIPT.DATA.definitions.has(fixture)
	_active_fixture_uid_owned = _active_fixture_uid_owned or FileAccess.file_exists(definition_path + ".uid")
	_expect(FileAccess.file_exists(definition_path), "redo recreates the definition file", failures)
	_expect(fixture.resource_path == definition_path, "redo restores the resource path", failures)
	_expect(ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "redo restores the catalog entry", failures)
	_expect(probe.selected_variant_id == fixture_id, "redo selects the recreated variant", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "redo refreshes generated manifests", failures)
	var redone_catalog := ResourceLoader.load(
		ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as SlimeVariantCatalogData
	_expect(redone_catalog != null and _catalog_contains_id(redone_catalog, fixture_id), "saved catalog reload discovers the redone definition", failures)
	var redone_definition := ResourceLoader.load(
		definition_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EnemyDefinition
	_expect(
		redone_definition != null
			and redone_definition.display_name == unsaved_draft_name
			and redone_definition.resource_name == unsaved_draft_name,
		"redo persists the unsaved draft after the explicit save",
		failures
	)
	_exercise_post_delete_manifest_failure(fixture, definition_path, fixture_id, failures)
	_characterize_remove_ownership(fixture, definition_path, fixture_id, failures)
	_characterize_uid_directory_boundaries(source_definition, fixture, definition_path, fixture_id, failures)

	_restore_post_delete_manifest_failure(failures)
	var cleanup_error := _cleanup_active_fixture()
	_expect(cleanup_error == OK, "test cleanup removes its definition", failures)
	_expect(not FileAccess.file_exists(definition_path), "test leaves no temporary definition file", failures)
	_expect(not FileAccess.file_exists(definition_path + ".uid"), "test leaves no temporary UID sidecar", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "test leaves generated manifests fresh", failures)
	_restore_baseline_state(failures)
	probe.queue_free()
	await process_frame
	_finished = true
	_finish(failures)


func _catalog_contains_id(catalog_data: SlimeVariantCatalogData, enemy_id: StringName) -> bool:
	for raw_definition: Resource in catalog_data.definitions:
		var definition := raw_definition as EnemyDefinition
		if definition != null and definition.variant_id == enemy_id:
			return true
	return false


func _catalog_has_authored_entry(enemy_id: StringName, resource_path: String) -> bool:
	for raw_definition: Resource in ENEMY_CATALOG_SCRIPT.DATA.definitions:
		var definition := raw_definition as EnemyDefinition
		if definition != null and definition.variant_id == enemy_id and definition.resource_path == resource_path:
			return true
	return false


func _exercise_post_delete_manifest_failure(
	fixture: EnemyDefinition,
	definition_path: String,
	fixture_id: StringName,
	failures: Array[String],
) -> void:
	var fault_stem := "codex_enemy_remove_manifest_fault_%d" % Time.get_ticks_usec()
	_post_delete_fault_path = "res://resources/definitions/%s.tres" % fault_stem
	var missing_script_path := "res://scripts/content/%s_missing.gd" % fault_stem
	_post_delete_fault_reserved = _authored_path_is_unoccupied(_post_delete_fault_path)
	_expect(_post_delete_fault_reserved, "post-delete failure resource path is unused", failures)
	var missing_script_reserved := (
		not FileAccess.file_exists(missing_script_path)
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(missing_script_path))
	)
	_expect(missing_script_reserved, "post-delete failure dependency path is unused", failures)
	if not _post_delete_fault_reserved or not missing_script_reserved or not FileAccess.file_exists(definition_path):
		return

	_post_delete_fault_state = {
		"fixture": _snapshot_file(definition_path),
		"fixture_uid": _snapshot_file(definition_path + ".uid"),
		"catalog": _snapshot_file(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH),
		"catalog_uid": _snapshot_file(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH + ".uid"),
		"manifests": _snapshot_generated_manifests(),
		"entries": ENEMY_CATALOG_SCRIPT.DATA.definitions.duplicate(),
		"resource_path": fixture.resource_path,
	}
	var unsaved_failure_draft := "Catalog Lifecycle Draft Across Manifest Failure"
	fixture.display_name = unsaved_failure_draft
	fixture.resource_name = unsaved_failure_draft
	var persisted_before_failure := ResourceLoader.load(
		definition_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EnemyDefinition
	_expect(
		persisted_before_failure != null
			and persisted_before_failure.display_name != unsaved_failure_draft
			and persisted_before_failure.to_record() != fixture.to_record(),
		"post-delete rollback probe has a persisted snapshot distinct from its dirty draft",
		failures
	)
	_post_delete_fault_active = true
	var invalid_resource_text := (
		'[gd_resource type="Resource" script_class="EnemyDefinition" load_steps=2 format=3]\n'
		+ '[ext_resource type="Script" path="%s" id="1"]\n' % missing_script_path
		+ '[resource]\nscript = ExtResource("1")\n'
	)
	var fault_write_error := _write_bytes(
		_post_delete_fault_path, invalid_resource_text.to_utf8_buffer()
	)
	_expect(fault_write_error == OK, "test writes its reserved malformed enemy manifest dependency", failures)
	var remove_error: Error = ERR_FILE_CANT_OPEN
	if fault_write_error == OK:
		remove_error = ENEMY_CATALOG_SCRIPT.remove_authored_definition(fixture, definition_path)
		_expect(
			remove_error == ERR_FILE_CANT_OPEN,
			"remove reaches manifest cache failure after deleting the fixture",
			failures
		)
		_expect(
			_file_snapshot_matches(definition_path, _post_delete_fault_state["fixture"]),
			"failed enemy remove restores exact definition bytes",
			failures
		)
		_expect(
			_file_snapshot_matches(definition_path + ".uid", _post_delete_fault_state["fixture_uid"]),
			"failed enemy remove restores exact UID-sidecar state",
			failures
		)
		_expect(
			_file_snapshot_matches(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, _post_delete_fault_state["catalog"]),
			"failed enemy remove restores exact catalog bytes",
			failures
		)
		_expect(
			_file_snapshot_matches(
				ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH + ".uid",
				_post_delete_fault_state["catalog_uid"]
			),
			"failed enemy remove preserves exact catalog UID-sidecar state",
			failures
		)
		_expect(
			_generated_manifests_match(_post_delete_fault_state["manifests"]),
			"failed enemy remove restores every generated manifest byte",
			failures
		)
		_expect(_catalog_has_authored_entry(fixture_id, definition_path), "failed enemy remove restores catalog ownership", failures)
		_expect(ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "failed enemy remove restores catalog discovery", failures)

	_restore_post_delete_manifest_failure(failures)
	if fault_write_error != OK or remove_error == OK:
		fixture.display_name = "Catalog Lifecycle Unsaved Draft After Save"
		fixture.resource_name = fixture.display_name
		return

	var retry_remove_error := ENEMY_CATALOG_SCRIPT.remove_authored_definition(fixture, definition_path)
	_expect(retry_remove_error == OK, "later dirty enemy removal succeeds with the persisted snapshot retained", failures)
	_expect(not FileAccess.file_exists(definition_path), "successful retry removes the enemy fixture", failures)
	_expect(
		fixture.display_name == unsaved_failure_draft and fixture.resource_name == unsaved_failure_draft,
		"successful retry preserves the unsaved enemy draft in memory",
		failures
	)
	_active_fixture_owned = false
	var recreate_error := ENEMY_CATALOG_SCRIPT.create_authored_definition(fixture, definition_path)
	_expect(recreate_error == OK, "test recreates the fixture for the remaining ownership probes", failures)
	_active_fixture_owned = FileAccess.file_exists(definition_path) and ENEMY_CATALOG_SCRIPT.DATA.definitions.has(fixture)
	_active_fixture_uid_owned = FileAccess.file_exists(definition_path + ".uid")
	_expect(_active_fixture_owned, "post-delete failure probe leaves the main fixture available", failures)


func _restore_post_delete_manifest_failure(failures: Array[String]) -> void:
	if not _post_delete_fault_active:
		return
	var restore_succeeded := true
	if _post_delete_fault_reserved:
		for path: String in [_post_delete_fault_path, _post_delete_fault_path + ".uid"]:
			if FileAccess.file_exists(path):
				var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
				if remove_error != OK:
					failures.append("enemy manifest fault fixture cleanup failed for %s (%d)" % [path, remove_error])
					restore_succeeded = false
		for pair: Array in [
			[_active_fixture_path, _post_delete_fault_state.get("fixture", {})],
			[_active_fixture_path + ".uid", _post_delete_fault_state.get("fixture_uid", {})],
			[ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, _post_delete_fault_state.get("catalog", {})],
			[ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH + ".uid", _post_delete_fault_state.get("catalog_uid", {})],
		]:
			var file_state: Dictionary = pair[1]
			_restore_file_snapshot(pair[0], file_state, failures)
			if not _file_snapshot_matches(pair[0], file_state):
				restore_succeeded = false
	ENEMY_CATALOG_SCRIPT.DATA.definitions.clear()
	var original_entries: Array[Resource] = _post_delete_fault_state.get("entries", [])
	ENEMY_CATALOG_SCRIPT.DATA.definitions.append_array(original_entries)
	ENEMY_CATALOG_SCRIPT.DATA.emit_changed()
	var manifest_state: Dictionary = _post_delete_fault_state.get("manifests", {})
	_restore_generated_manifests(manifest_state, failures)
	if ENEMY_CATALOG_SCRIPT.refresh_manifest_cache() != OK:
		failures.append("enemy manifest fault fixture could not reload the restored manifest cache")
		restore_succeeded = false
	ENEMY_CATALOG_SCRIPT.invalidate_cache()
	var original_resource_path := str(_post_delete_fault_state.get("resource_path", _active_fixture_path))
	if _active_fixture != null:
		_active_fixture.take_over_path(original_resource_path)
	if not _generated_manifests_match(manifest_state):
		restore_succeeded = false
	if not CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty():
		failures.append("enemy manifest fault fixture did not restore manifest freshness")
		restore_succeeded = false
	if restore_succeeded:
		_post_delete_fault_active = false
		_active_fixture_owned = FileAccess.file_exists(_active_fixture_path)
		_active_fixture_uid_owned = FileAccess.file_exists(_active_fixture_path + ".uid")


func _characterize_create_boundaries(
	source_definition: EnemyDefinition,
	fixture_id: StringName,
	definition_path: String,
	failures: Array[String],
) -> void:
	var duplicate_id := source_definition.duplicate(true) as EnemyDefinition
	var duplicate_path := "res://resources/definitions/%s.tres" % source_definition.variant_id
	duplicate_id.resource_name = "Duplicate ID Probe"
	if _authored_path_is_unoccupied(duplicate_path):
		_run_create_collision_probe(duplicate_id, duplicate_path, duplicate_path, ERR_ALREADY_EXISTS, "duplicate catalog ID", failures)
	else:
		_expect(false, "duplicate ID probe path is safely available", failures)
	_expect(not FileAccess.file_exists(duplicate_path), "duplicate ID rejection preserves its target path", failures)

	var mismatched_id := StringName("%s_path_mismatch" % fixture_id)
	var mismatched := source_definition.duplicate(true) as EnemyDefinition
	mismatched.id = mismatched_id
	mismatched.display_name = "Mismatched Path Probe"
	mismatched.resource_name = mismatched.display_name
	var mismatched_path := "res://resources/definitions/%s_wrong_name.tres" % mismatched_id
	if _authored_path_is_unoccupied(mismatched_path) and not ENEMY_CATALOG_SCRIPT.contains_id(mismatched_id):
		_run_create_collision_probe(mismatched, mismatched_path, mismatched_path, ERR_INVALID_PARAMETER, "ID/path mismatch", failures)
	else:
		_expect(false, "ID/path mismatch probe is safely available", failures)
	_expect(not FileAccess.file_exists(mismatched_path), "ID/path mismatch rejection leaves no target file", failures)
	_expect(not ENEMY_CATALOG_SCRIPT.contains_id(mismatched_id), "ID/path mismatch rejection leaves no catalog entry", failures)

	var noncanonical_id := StringName("%s_noncanonical" % fixture_id)
	var noncanonical := source_definition.duplicate(true) as EnemyDefinition
	noncanonical.id = noncanonical_id
	noncanonical.display_name = "Noncanonical Path Probe"
	noncanonical.resource_name = noncanonical.display_name
	var noncanonical_path := "res://resources/definitions/./%s.tres" % noncanonical_id
	var noncanonical_target := "res://resources/definitions/%s.tres" % noncanonical_id
	if _authored_path_is_unoccupied(noncanonical_target):
		_run_create_collision_probe(noncanonical, noncanonical_path, noncanonical_target, ERR_INVALID_PARAMETER, "noncanonical path", failures)
	else:
		_expect(false, "noncanonical path probe is safely available", failures)
	_expect(not FileAccess.file_exists("res://resources/definitions/%s.tres" % noncanonical_id), "noncanonical path rejection writes no file", failures)

	var uid_id := StringName("%s_uid_collision" % fixture_id)
	var uid_candidate := source_definition.duplicate(true) as EnemyDefinition
	uid_candidate.id = uid_id
	uid_candidate.display_name = "UID Collision Probe"
	uid_candidate.resource_name = uid_candidate.display_name
	var uid_target := "res://resources/definitions/%s.tres" % uid_id
	var uid_path := uid_target + ".uid"
	var uid_marker := "codex-reserved-uid-%s" % uid_id
	if _authored_path_is_unoccupied(uid_target) and not ENEMY_CATALOG_SCRIPT.contains_id(uid_id):
		var marker_error := _write_bytes(uid_path, uid_marker.to_utf8_buffer())
		_expect(marker_error == OK, "UID collision probe reserves only its unique sidecar", failures)
		if marker_error == OK:
			_run_create_collision_probe(uid_candidate, uid_target, uid_target, ERR_ALREADY_EXISTS, "occupied UID sidecar", failures)
			_expect(FileAccess.get_file_as_bytes(uid_path) == uid_marker.to_utf8_buffer(), "UID collision rejection preserves the sidecar bytes", failures)
			_remove_reserved_file(uid_path, failures)
	else:
		_expect(false, "UID collision probe path and catalog ID are safely available", failures)
	_expect(not FileAccess.file_exists(uid_target), "UID collision rejection leaves no resource file", failures)

	var directory_id := StringName("%s_directory_collision" % fixture_id)
	var directory_candidate := source_definition.duplicate(true) as EnemyDefinition
	directory_candidate.id = directory_id
	directory_candidate.display_name = "Directory Collision Probe"
	directory_candidate.resource_name = directory_candidate.display_name
	var directory_target := "res://resources/definitions/%s.tres" % directory_id
	if _authored_path_is_unoccupied(directory_target) and not ENEMY_CATALOG_SCRIPT.contains_id(directory_id):
		var absolute_target := ProjectSettings.globalize_path(directory_target)
		var directory_error := DirAccess.make_dir_absolute(absolute_target)
		_expect(directory_error == OK, "directory collision probe reserves an empty unique target", failures)
		if directory_error == OK:
			_run_create_collision_probe(directory_candidate, directory_target, directory_target, ERR_ALREADY_EXISTS, "occupied directory", failures)
			_expect(DirAccess.dir_exists_absolute(absolute_target), "directory collision rejection preserves the reserved directory", failures)
			var remove_directory_error := DirAccess.remove_absolute(absolute_target)
			_expect(remove_directory_error == OK, "test removes only its empty reserved directory", failures)
	else:
		_expect(false, "directory collision probe path and catalog ID are safely available", failures)
	_expect(not FileAccess.file_exists(directory_target), "directory collision rejection leaves no resource file", failures)

	_expect(_authored_path_is_unoccupied(definition_path), "main fixture remains untouched before creation", failures)
	_expect(not ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "main fixture ID remains unused after rejected probes", failures)


func _characterize_remove_ownership(
	fixture: EnemyDefinition,
	definition_path: String,
	fixture_id: StringName,
	failures: Array[String],
) -> void:
	var persisted_fixture := ResourceLoader.load(
		definition_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EnemyDefinition
	_expect(persisted_fixture != null, "replacement ownership probes freshly load the persisted fixture", failures)
	if persisted_fixture == null:
		return
	_run_remove_replacement_probe(persisted_fixture, definition_path, fixture_id, true, failures)
	_run_remove_replacement_probe(persisted_fixture, definition_path, fixture_id, false, failures)


func _characterize_uid_directory_boundaries(
	source_definition: EnemyDefinition,
	fixture: EnemyDefinition,
	definition_path: String,
	fixture_id: StringName,
	failures: Array[String],
) -> void:
	var probe_id := StringName("%s_uid_directory_create" % fixture_id)
	var probe := source_definition.duplicate(true) as EnemyDefinition
	probe.id = probe_id
	probe.display_name = "UID Directory Create Probe"
	probe.resource_name = probe.display_name
	var probe_path := "res://resources/definitions/%s.tres" % probe_id
	var probe_uid_path := probe_path + ".uid"
	if _authored_path_is_unoccupied(probe_path) and not ENEMY_CATALOG_SCRIPT.contains_id(probe_id):
		var create_directory_error := DirAccess.make_dir_absolute(ProjectSettings.globalize_path(probe_uid_path))
		_expect(create_directory_error == OK, "UID directory create probe reserves its sidecar path", failures)
		if create_directory_error == OK:
			_run_create_collision_probe(probe, probe_path, probe_path, ERR_ALREADY_EXISTS, "occupied UID sidecar directory", failures)
			_expect(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(probe_uid_path)), "rejected create preserves its UID sidecar directory", failures)
			var remove_directory_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(probe_uid_path))
			_expect(remove_directory_error == OK, "test removes only its empty create-probe UID directory", failures)
	else:
		_expect(false, "UID directory create path and ID are safely available", failures)
	_expect(not FileAccess.file_exists(probe_path), "UID directory create probe leaves no resource file", failures)

	var on_disk_fixture := ResourceLoader.load(
		definition_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EnemyDefinition
	_expect(on_disk_fixture != null, "UID directory remove probe starts from a fresh fixture resource", failures)
	if on_disk_fixture == null:
		return
	var resource_bytes := FileAccess.get_file_as_bytes(definition_path)
	var uid_path := definition_path + ".uid"
	var uid_exists := FileAccess.file_exists(uid_path)
	var uid_bytes := FileAccess.get_file_as_bytes(uid_path) if uid_exists else PackedByteArray()
	var catalog_bytes := FileAccess.get_file_as_bytes(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH)
	var manifest_snapshot := _snapshot_generated_manifests()
	var original_entries: Array[Resource] = ENEMY_CATALOG_SCRIPT.DATA.definitions.duplicate()
	var uid_absolute_path := ProjectSettings.globalize_path(uid_path)
	if DirAccess.dir_exists_absolute(uid_absolute_path):
		_expect(false, "fixture UID path has no pre-existing directory", failures)
		return
	if uid_exists:
		var remove_uid_error := DirAccess.remove_absolute(uid_absolute_path)
		_expect(remove_uid_error == OK, "test frees its own fixture UID path for a directory blocker", failures)
		if remove_uid_error != OK:
			return
	var directory_error := DirAccess.make_dir_absolute(uid_absolute_path)
	_expect(directory_error == OK, "remove probe reserves an empty fixture UID directory", failures)
	if directory_error != OK:
		if uid_exists:
			_expect(_write_bytes(uid_path, uid_bytes) == OK, "failed blocker setup restores original UID bytes", failures)
		return

	var remove_error: Error = ENEMY_CATALOG_SCRIPT.remove_authored_definition(on_disk_fixture, definition_path)
	_expect(remove_error != OK, "remove rejects a directory occupying the fixture UID sidecar path", failures)
	_expect(FileAccess.get_file_as_bytes(definition_path) == resource_bytes, "rejected UID directory removal preserves resource bytes", failures)
	_expect(_catalog_has_authored_entry(fixture_id, definition_path), "rejected UID directory removal preserves catalog ownership", failures)
	_expect(FileAccess.get_file_as_bytes(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH) == catalog_bytes, "rejected UID directory removal preserves catalog bytes", failures)
	_expect(ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "rejected UID directory removal preserves catalog lookup", failures)
	_expect(_generated_manifests_match(manifest_snapshot), "rejected UID directory removal preserves generated manifests", failures)
	var remove_directory_error := DirAccess.remove_absolute(uid_absolute_path)
	_expect(remove_directory_error == OK, "test removes only its empty remove-probe UID directory", failures)
	_restore_remove_probe_state(
		fixture,
		definition_path,
		resource_bytes,
		uid_path,
		uid_exists,
		uid_bytes,
		catalog_bytes,
		original_entries,
		manifest_snapshot,
		definition_path,
		failures
	)
	fixture.take_over_path(definition_path)
	_expect(not DirAccess.dir_exists_absolute(uid_absolute_path), "UID directory probe leaves no sidecar directory", failures)


func _run_remove_replacement_probe(
	fixture: EnemyDefinition,
	definition_path: String,
	fixture_id: StringName,
	change_id: bool,
	failures: Array[String],
) -> void:
	var label := "changed-ID" if change_id else "same-ID changed-content"
	var resource_bytes := FileAccess.get_file_as_bytes(definition_path)
	var uid_path := definition_path + ".uid"
	var uid_exists := FileAccess.file_exists(uid_path)
	var uid_bytes := FileAccess.get_file_as_bytes(uid_path) if uid_exists else PackedByteArray()
	var catalog_bytes := FileAccess.get_file_as_bytes(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH)
	var manifest_snapshot := _snapshot_generated_manifests()
	var original_entries: Array[Resource] = ENEMY_CATALOG_SCRIPT.DATA.definitions.duplicate()
	var original_path := fixture.resource_path
	_expect(not resource_bytes.is_empty() and not catalog_bytes.is_empty(), "%s ownership probe captures existing bytes" % label, failures)
	if resource_bytes.is_empty() or catalog_bytes.is_empty():
		return
	var disk_replacement := ResourceLoader.load(
		definition_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as EnemyDefinition
	_expect(disk_replacement != null, "%s ownership probe loads its reserved disk resource" % label, failures)
	if disk_replacement == null:
		return
	if change_id:
		disk_replacement.id = StringName("%s_external" % fixture_id)
	else:
		disk_replacement.display_name = "Externally Replaced Same ID"
		disk_replacement.resource_name = disk_replacement.display_name
	var replacement_save_error := ResourceSaver.save(disk_replacement, definition_path)
	_expect(replacement_save_error == OK, "%s ownership probe writes its reserved replacement" % label, failures)
	if replacement_save_error != OK:
		_restore_remove_probe_state(fixture, definition_path, resource_bytes, uid_path, uid_exists, uid_bytes, catalog_bytes, original_entries, manifest_snapshot, original_path, failures)
		return
	var replacement_bytes := FileAccess.get_file_as_bytes(definition_path)
	var replacement_uid_exists := FileAccess.file_exists(uid_path)
	var replacement_uid_bytes := FileAccess.get_file_as_bytes(uid_path) if replacement_uid_exists else PackedByteArray()
	var remove_error: Error = ENEMY_CATALOG_SCRIPT.remove_authored_definition(fixture, definition_path)
	_expect(remove_error == ERR_INVALID_DATA, "remove rejects a fresh %s resource replacement" % label, failures)
	_expect(FileAccess.get_file_as_bytes(definition_path) == replacement_bytes, "rejected %s removal leaves replacement bytes untouched" % label, failures)
	_expect(FileAccess.file_exists(uid_path) == replacement_uid_exists, "rejected %s removal leaves UID sidecar presence untouched" % label, failures)
	if replacement_uid_exists:
		_expect(FileAccess.get_file_as_bytes(uid_path) == replacement_uid_bytes, "rejected %s removal leaves UID sidecar bytes untouched" % label, failures)
	_expect(FileAccess.get_file_as_bytes(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH) == catalog_bytes, "rejected %s removal leaves catalog bytes untouched" % label, failures)
	_expect(_catalog_has_authored_entry(fixture_id, definition_path), "rejected %s removal leaves catalog ownership unchanged" % label, failures)
	_expect(ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "rejected %s removal leaves catalog lookup unchanged" % label, failures)
	_expect(_generated_manifests_match(manifest_snapshot), "rejected %s removal leaves generated manifests unchanged" % label, failures)
	_restore_remove_probe_state(fixture, definition_path, resource_bytes, uid_path, uid_exists, uid_bytes, catalog_bytes, original_entries, manifest_snapshot, original_path, failures)


func _restore_remove_probe_state(
	fixture: EnemyDefinition,
	definition_path: String,
	resource_bytes: PackedByteArray,
	uid_path: String,
	uid_exists: bool,
	uid_bytes: PackedByteArray,
	catalog_bytes: PackedByteArray,
	original_entries: Array[Resource],
	manifest_snapshot: Dictionary,
	original_path: String,
	failures: Array[String],
) -> void:
	_expect(_write_bytes(definition_path, resource_bytes) == OK, "replacement probe restores exact original definition bytes", failures)
	_expect(FileAccess.get_file_as_bytes(definition_path) == resource_bytes, "replacement probe verifies exact definition restoration", failures)
	if uid_exists:
		_expect(_write_bytes(uid_path, uid_bytes) == OK, "replacement probe restores exact UID bytes", failures)
		_expect(FileAccess.get_file_as_bytes(uid_path) == uid_bytes, "replacement probe verifies exact UID restoration", failures)
	else:
		_remove_reserved_file(uid_path, failures)
	_expect(_write_bytes(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, catalog_bytes) == OK, "replacement probe restores exact catalog bytes", failures)
	ENEMY_CATALOG_SCRIPT.DATA.definitions.clear()
	ENEMY_CATALOG_SCRIPT.DATA.definitions.append_array(original_entries)
	ENEMY_CATALOG_SCRIPT.DATA.emit_changed()
	ENEMY_CATALOG_SCRIPT.invalidate_cache()
	_restore_generated_manifests(manifest_snapshot, failures)
	_expect(ENEMY_CATALOG_SCRIPT.refresh_manifest_cache() == OK, "replacement probe restores the enemy manifest cache", failures)
	fixture.take_over_path(original_path)
	_expect(FileAccess.get_file_as_bytes(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH) == catalog_bytes, "replacement probe verifies exact catalog restoration", failures)
	_expect(_generated_manifests_match(manifest_snapshot), "replacement probe verifies exact manifest restoration", failures)


func _snapshot_generated_manifests() -> Dictionary:
	var snapshot: Dictionary = {}
	for manifest_path: String in GENERATED_MANIFEST_PATHS:
		var exists := FileAccess.file_exists(manifest_path)
		snapshot[manifest_path] = {
			"exists": exists,
			"bytes": FileAccess.get_file_as_bytes(manifest_path) if exists else PackedByteArray(),
		}
	return snapshot


func _capture_baseline_state() -> void:
	_baseline_catalog_entries = ENEMY_CATALOG_SCRIPT.DATA.definitions.duplicate()
	_baseline_catalog_file = _snapshot_file(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH)
	_baseline_catalog_uid_file = _snapshot_file(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH + ".uid")
	_baseline_manifest_files = _snapshot_generated_manifests()
	_baseline_initialized = true


func _restore_baseline_state(failures: Array[String]) -> void:
	if not _baseline_initialized:
		return
	ENEMY_CATALOG_SCRIPT.DATA.definitions.clear()
	ENEMY_CATALOG_SCRIPT.DATA.definitions.append_array(_baseline_catalog_entries)
	ENEMY_CATALOG_SCRIPT.DATA.emit_changed()
	_restore_file_snapshot(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, _baseline_catalog_file, failures)
	_restore_file_snapshot(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH + ".uid", _baseline_catalog_uid_file, failures)
	_restore_generated_manifests(_baseline_manifest_files, failures)
	var cache_error: Error = ENEMY_CATALOG_SCRIPT.refresh_manifest_cache()
	_expect(cache_error == OK, "test restores the enemy manifest resource cache", failures)
	ENEMY_CATALOG_SCRIPT.invalidate_cache()
	_expect(_file_snapshot_matches(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, _baseline_catalog_file), "test restores exact catalog bytes", failures)
	_expect(_file_snapshot_matches(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH + ".uid", _baseline_catalog_uid_file), "test restores exact catalog UID bytes", failures)
	_expect(_generated_manifests_match(_baseline_manifest_files), "test restores exact generated manifest bytes", failures)
	_baseline_initialized = false


func _snapshot_file(resource_path: String) -> Dictionary:
	var exists := FileAccess.file_exists(resource_path)
	return {
		"exists": exists,
		"bytes": FileAccess.get_file_as_bytes(resource_path) if exists else PackedByteArray(),
	}


func _restore_file_snapshot(resource_path: String, state: Dictionary, failures: Array[String]) -> void:
	if bool(state.get("exists", false)):
		var bytes: PackedByteArray = state.get("bytes", PackedByteArray())
		_expect(_write_bytes(resource_path, bytes) == OK, "test restores file %s" % resource_path, failures)
	elif FileAccess.file_exists(resource_path):
		_remove_reserved_file(resource_path, failures)


func _file_snapshot_matches(resource_path: String, state: Dictionary) -> bool:
	var exists := bool(state.get("exists", false))
	if FileAccess.file_exists(resource_path) != exists:
		return false
	return not exists or FileAccess.get_file_as_bytes(resource_path) == state.get("bytes", PackedByteArray())


func _restore_generated_manifests(snapshot: Dictionary, failures: Array[String]) -> void:
	for manifest_path: String in GENERATED_MANIFEST_PATHS:
		var state: Dictionary = snapshot.get(manifest_path, {})
		if bool(state.get("exists", false)):
			var bytes: PackedByteArray = state.get("bytes", PackedByteArray())
			_expect(_write_bytes(manifest_path, bytes) == OK, "replacement probe restores manifest %s" % manifest_path, failures)
		elif FileAccess.file_exists(manifest_path):
			_remove_reserved_file(manifest_path, failures)


func _generated_manifests_match(snapshot: Dictionary) -> bool:
	for manifest_path: String in GENERATED_MANIFEST_PATHS:
		var state: Dictionary = snapshot.get(manifest_path, {})
		var existed := bool(state.get("exists", false))
		if FileAccess.file_exists(manifest_path) != existed:
			return false
		if existed and FileAccess.get_file_as_bytes(manifest_path) != state.get("bytes", PackedByteArray()):
			return false
	return true


func _run_create_collision_probe(
	definition: EnemyDefinition,
	requested_path: String,
	physical_path: String,
	expected_error: Error,
	label: String,
	failures: Array[String],
) -> void:
	var original_path := definition.resource_path
	var original_entries: Array[Resource] = ENEMY_CATALOG_SCRIPT.DATA.definitions.duplicate()
	var catalog_bytes := FileAccess.get_file_as_bytes(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH)
	var manifest_snapshot := _snapshot_generated_manifests()
	var uid_path := physical_path + ".uid"
	var uid_exists := FileAccess.file_exists(uid_path)
	var uid_bytes := FileAccess.get_file_as_bytes(uid_path) if uid_exists else PackedByteArray()
	var create_error := ENEMY_CATALOG_SCRIPT.create_authored_definition(definition, requested_path)
	_expect(create_error == expected_error, "create rejects %s with the documented boundary error" % label, failures)
	if FileAccess.file_exists(physical_path):
		_remove_reserved_file(physical_path, failures)
	if uid_exists:
		_expect(_write_bytes(uid_path, uid_bytes) == OK, "probe restores reserved UID bytes", failures)
	elif FileAccess.file_exists(uid_path):
		_remove_reserved_file(uid_path, failures)
	ENEMY_CATALOG_SCRIPT.DATA.definitions.clear()
	ENEMY_CATALOG_SCRIPT.DATA.definitions.append_array(original_entries)
	ENEMY_CATALOG_SCRIPT.DATA.emit_changed()
	_expect(_write_bytes(ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, catalog_bytes) == OK, "probe restores exact catalog bytes", failures)
	ENEMY_CATALOG_SCRIPT.invalidate_cache()
	_restore_generated_manifests(manifest_snapshot, failures)
	_expect(ENEMY_CATALOG_SCRIPT.refresh_manifest_cache() == OK, "create probe restores the enemy manifest cache", failures)
	definition.take_over_path(original_path)
	_expect(not ENEMY_CATALOG_SCRIPT.DATA.definitions.has(definition), "rejected create leaves no probe object in the catalog", failures)
	_expect(not FileAccess.file_exists(physical_path), "rejected create probe leaves no resource file", failures)


func _authored_path_is_unoccupied(resource_path: String) -> bool:
	return (
		not FileAccess.file_exists(resource_path)
		and not FileAccess.file_exists(resource_path + ".uid")
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(resource_path))
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(resource_path + ".uid"))
	)


func _write_bytes(resource_path: String, bytes: PackedByteArray) -> Error:
	var file := FileAccess.open(resource_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var write_error := file.get_error()
	file.close()
	return write_error


func _remove_reserved_file(resource_path: String, failures: Array[String]) -> void:
	if not FileAccess.file_exists(resource_path):
		return
	var remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))
	_expect(remove_error == OK, "test removes only its reserved file %s" % resource_path, failures)


func _cleanup_active_fixture() -> Error:
	if _active_fixture_owned and _active_fixture != null:
		var cleanup_definition := ResourceLoader.load(
			_active_fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as EnemyDefinition
		if cleanup_definition == null:
			return ERR_FILE_CANT_OPEN
		var cleanup_error := ENEMY_CATALOG_SCRIPT.remove_authored_definition(cleanup_definition, _active_fixture_path)
		if cleanup_error != OK:
			return cleanup_error
		_active_fixture_owned = false
	if _active_fixture_uid_owned and FileAccess.file_exists(_active_fixture_path + ".uid"):
		var uid_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(_active_fixture_path + ".uid"))
		if uid_error != OK:
			return uid_error
		_active_fixture_uid_owned = false
	return OK


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENEMY_DEFINITION_CATALOG_LIFECYCLE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _watchdog() -> void:
	if _finished:
		return
	var failures: Array[String] = []
	_restore_post_delete_manifest_failure(failures)
	var cleanup_error := _cleanup_active_fixture()
	if cleanup_error != OK:
		failures.append("active fixture cleanup failed (%d)" % cleanup_error)
	_restore_baseline_state(failures)
	for failure: String in failures:
		push_error("TEST_CLEANUP_FAILED: %s" % failure)
	push_error("TEST_ABORTED: enemy definition catalog lifecycle smoke failed before completion")
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
