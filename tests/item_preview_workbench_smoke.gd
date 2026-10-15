extends SceneTree

const ITEM_CATALOG_SCRIPT: Script = preload("res://scripts/content/item_catalog.gd")
const ITEM_CATALOG_DATA_SCRIPT: Script = preload("res://scripts/content/item_catalog_data.gd")
const ITEM_INSTANCE_SCRIPT: Script = preload("res://scripts/content/item_instance.gd")
const CONTENT_MANIFEST_SERVICE_SCRIPT: Script = preload("res://scripts/content/content_definition_manifest_service.gd")
const PREVIEW_SCENE: PackedScene = preload("res://scenes/authoring/previews/item_preview_workbench.tscn")
const ITEM_RESOURCE_ROOT := "res://resources/definitions/items"
const ITEM_MANIFEST_PATH := "res://resources/generated/item_definition_manifest.tres"
const GENERATED_MANIFEST_PATHS: Array[String] = [
	"res://resources/generated/content_definition_manifest.tres",
	"res://resources/generated/enemy_definition_manifest.tres",
	ITEM_MANIFEST_PATH,
]

var _finished := false
var _fixture_id: StringName = &""
var _fixture_path := ""
var _fixture_file_created := false
var _fixture_uid_path := ""
var _fixture_path_reserved := false
var _escape_path := ""
var _escape_path_reserved := false
var _outside_catalog_path := ""
var _outside_catalog_path_reserved := false
var _blocked_path := ""
var _blocked_path_reserved := false
var _blocked_directory_created := false
var _workbench: Node2D
var _preview: Node2D
var _replacement_probe_active := false
var _replacement_original_bytes := PackedByteArray()
var _replacement_backup_path := ""
var _replacement_backup_reserved := false
var _manifest_failure_path := ""
var _manifest_failure_path_reserved := false
var _manifest_failure_backup_path := ""
var _manifest_failure_backup_reserved := false
var _manifest_failure_directory_created := false
var _manifest_failure_fixture_active := false
var _manifest_failure_original_manifests: Dictionary = {}


func _initialize() -> void:
	call_deferred("_watchdog")
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var initial_manifest_problems: Array[String] = CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness()
	_expect(initial_manifest_problems.is_empty(), "item lifecycle starts with fresh generated manifests", failures)

	var catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	var definition_ids: Array[StringName] = catalog.playable_definition_ids()
	_expect(not definition_ids.is_empty(), "ItemCatalog exposes current playable definition IDs", failures)
	_expect(&"cinder_blade" in definition_ids, "cinder_blade remains the standalone ItemDefinition proof", failures)
	_expect(&"demon_cloak" in definition_ids, "the special-acquisition Demon Cloak remains previewable", failures)
	_expect(&"ash_mantle" not in definition_ids, "legacy-only Ash Mantle is excluded from the playable picker", failures)

	for definition_id: StringName in definition_ids:
		var preview := PREVIEW_SCENE.instantiate() as Node2D
		_expect(preview != null, "%s preview scene instantiates" % definition_id, failures)
		if preview == null:
			continue
		preview.set("item_id", definition_id)
		root.add_child(preview)
		await process_frame
		var summary := preview.call("get_preview_summary") as Dictionary
		_expect(bool(summary.get("ready", false)), "%s preview is ready" % definition_id, failures)
		_expect(bool(summary.get("actions_ready", false)), "%s preview actions are bound" % definition_id, failures)
		_expect(StringName(str(summary.get("id", ""))) == definition_id, "%s preview preserves its stable ID" % definition_id, failures)
		_expect(not str(summary.get("slot", "")).is_empty(), "%s preview resolves a canonical slot" % definition_id, failures)
		var source_definition := catalog.definition_resource(definition_id)
		var expected_editable := source_definition != null and not source_definition.catalog_owned
		_expect(bool(summary.get("editable", false)) == expected_editable, "%s editability follows explicit catalog ownership" % definition_id, failures)

		var expected_instance: ItemInstance = catalog.create_preview_instance(definition_id, 1, &"common", 0)
		_expect(expected_instance != null, "%s creates a deterministic preview instance" % definition_id, failures)
		if expected_instance != null:
			_expect(summary.get("bonuses", {}) == catalog.bonuses(expected_instance), "%s preview uses ItemCatalog's bonus calculation" % definition_id, failures)
			_expect(summary.get("effect_lines", []) == catalog.effect_display_lines(expected_instance, true), "%s preview uses ItemCatalog's effect presentation" % definition_id, failures)
		preview.queue_free()
		await process_frame

	var catalog_owned_definition := catalog.definition_resource(&"plain_hood")
	_expect(catalog_owned_definition != null and catalog_owned_definition.catalog_owned, "Plain Hood is an explicitly catalog-owned typed resource", failures)
	var catalog_owned_set := catalog.definition_resource(&"swift_weapon")
	_expect(catalog_owned_set != null and catalog_owned_set.catalog_owned and catalog_owned_set.set_id == &"swift", "Swift Blade is an explicitly catalog-owned typed set resource", failures)
	_expect(catalog.save_authored_definition(catalog_owned_set) == ERR_INVALID_PARAMETER, "catalog-owned set item cannot be saved through the catalog API", failures)
	if catalog_owned_definition != null:
		var read_only_preview := PREVIEW_SCENE.instantiate() as Node2D
		read_only_preview.set("item_id", &"plain_hood")
		root.add_child(read_only_preview)
		await process_frame
		var original_name := str(read_only_preview.get("display_name"))
		read_only_preview.set("display_name", "Edited Baseline")
		var read_only_summary := read_only_preview.call("get_preview_summary") as Dictionary
		_expect(str(read_only_preview.get("display_name")) == original_name, "catalog-owned item fields ignore workbench edits", failures)
		_expect(not bool(read_only_summary.get("editable", true)) and not bool(read_only_summary.get("dirty", true)), "catalog-owned item remains preview-only and clean", failures)
		_expect(str(read_only_preview.get("selected_source")).contains("read-only"), "catalog-owned source is labeled read-only", failures)
		_expect(catalog.save_authored_definition(catalog_owned_definition) == ERR_INVALID_PARAMETER, "catalog-owned item cannot be saved through the catalog API", failures)
		read_only_preview.call("save_selected_definition")
		read_only_preview.queue_free()
		await process_frame

	var first_instance: ItemInstance = catalog.create_preview_instance(&"cinder_blade", 4917, &"rare", 3)
	var second_instance: ItemInstance = catalog.create_preview_instance(&"cinder_blade", 4917, &"rare", 3)
	_expect(first_instance != null and second_instance != null, "the selected item can build seeded preview instances", failures)
	if first_instance != null and second_instance != null:
		_expect(first_instance.to_dictionary() == second_instance.to_dictionary(), "preview instance rolls are repeatable for a fixed seed", failures)
	_expect(catalog.create_preview_instance(&"missing_item", 1) == null, "unknown IDs do not build preview instances", failures)

	if initial_manifest_problems.is_empty():
		await _run_authored_lifecycle(catalog, failures)

	_finished = true
	_cleanup_test_resources(failures, true)
	call_deferred("_finish", failures)


func _run_authored_lifecycle(catalog: ItemCatalog, failures: Array[String]) -> void:
	var source_definition := catalog.definition_resource(&"cinder_blade")
	_expect(source_definition != null and not source_definition.catalog_owned, "lifecycle starts from an editable standalone definition", failures)
	if source_definition == null:
		return

	for attempt: int in range(8):
		var candidate_id := StringName("codex_item_lifecycle_%d_%d" % [Time.get_ticks_usec(), attempt])
		var candidate_path := ITEM_RESOURCE_ROOT.path_join("%s.tres" % String(candidate_id))
		if catalog.definition_exists(candidate_id):
			continue
		if FileAccess.file_exists(candidate_path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(candidate_path)):
			continue
		var candidate_uid_path := candidate_path + ".uid"
		if FileAccess.file_exists(candidate_uid_path):
			continue
		_fixture_id = candidate_id
		_fixture_path = candidate_path
		_fixture_uid_path = candidate_uid_path
		_fixture_path_reserved = true
		break
	_expect(_fixture_path_reserved, "lifecycle reserves an unused disposable ID and path", failures)
	if not _fixture_path_reserved:
		return

	_workbench = PREVIEW_SCENE.instantiate() as Node2D
	_expect(_workbench != null, "lifecycle workbench instantiates", failures)
	if _workbench == null:
		return
	_workbench.set("item_id", &"cinder_blade")
	root.add_child(_workbench)
	await process_frame
	_workbench.set("new_item_id", String(_fixture_id))
	_workbench.call("create_authored_item")
	_fixture_file_created = FileAccess.file_exists(_fixture_path)
	_expect(FileAccess.file_exists(_fixture_path), "create writes one standalone ItemDefinition", failures)

	var created_definition := ResourceLoader.load(
		_fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as ItemDefinition
	_expect(created_definition != null, "created ItemDefinition reloads from its standalone path", failures)
	if created_definition != null:
		_expect(created_definition.id == _fixture_id, "save round-trip preserves the stable fixture ID", failures)
		_expect(not created_definition.catalog_owned, "new standalone items remain author-editable", failures)
		_expect(created_definition.slot == source_definition.slot, "creation preserves the source equipment slot", failures)
		_expect(created_definition.locked_slots == source_definition.locked_slots, "creation preserves the source equipment-slot contract", failures)
		_expect(created_definition.source_tags == source_definition.source_tags, "creation preserves acquisition sources", failures)
		_expect(created_definition.bonuses == source_definition.bonuses, "creation preserves authored balance values", failures)
		_expect(created_definition.effects == source_definition.effects and created_definition.shield == source_definition.shield, "creation preserves effect and shield data", failures)

		var instance: ItemInstance = ITEM_INSTANCE_SCRIPT.new()
		instance.definition_id = _fixture_id
		instance.rarity = &"common"
		var restored_instance: ItemInstance = ITEM_INSTANCE_SCRIPT.from_dictionary(instance.to_dictionary())
		_expect(restored_instance != null and restored_instance.definition_id == _fixture_id, "item instance save/load round-trip preserves the new ID", failures)

	var after_create_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	_expect(after_create_catalog.definition_exists(_fixture_id), "a newly created ID is immediately discovered by a fresh ItemCatalog", failures)
	_expect(_fixture_id in after_create_catalog.playable_definition_ids(), "a new live item is immediately available to the playable picker", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "create refreshes all generated definition manifests", failures)
	_expect(StringName(str(_workbench.get("item_id"))) == _fixture_id, "workbench selects the new item after creation", failures)

	_preview = PREVIEW_SCENE.instantiate() as Node2D
	_expect(_preview != null, "new item preview workbench instantiates", failures)
	if _preview != null:
		_preview.set("item_id", _fixture_id)
		root.add_child(_preview)
		await process_frame
		var summary := _preview.call("get_preview_summary") as Dictionary
		_expect(bool(summary.get("ready", false)), "new standalone item is immediately previewable", failures)
		_expect(StringName(str(summary.get("id", ""))) == _fixture_id, "new item preview preserves the stable ID", failures)
		_expect(str(summary.get("source_path", "")) == _fixture_path, "new preview resolves the saved definition path", failures)
		_expect(str(summary.get("visual_source", "")) == "slot-level", "new item retains shared slot-level visual ownership", failures)

	var initial_file_text := FileAccess.get_file_as_string(_fixture_path) if FileAccess.file_exists(_fixture_path) else ""
	_workbench.set("new_item_id", String(_fixture_id))
	_workbench.call("create_authored_item")
	_fixture_file_created = FileAccess.file_exists(_fixture_path)
	_expect(FileAccess.get_file_as_string(_fixture_path) == initial_file_text, "duplicate creation cannot overwrite the existing fixture resource", failures)

	var baseline_path := catalog.definition_source_path(&"plain_hood")
	var baseline_text := FileAccess.get_file_as_string(baseline_path)
	_workbench.set("new_item_id", "plain_hood")
	_workbench.call("create_authored_item")
	_fixture_file_created = FileAccess.file_exists(_fixture_path)
	_expect(FileAccess.get_file_as_string(baseline_path) == baseline_text, "a catalog-owned baseline ID cannot be overwritten", failures)

	var escape_stem := "codex_item_escape_%d" % Time.get_ticks_usec()
	_escape_path = ("res://resources/definitions/items/../%s.tres" % escape_stem).simplify_path()
	_escape_path_reserved = not FileAccess.file_exists(_escape_path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_escape_path))
	_workbench.set("new_item_id", "../%s" % escape_stem)
	_workbench.call("create_authored_item")
	_fixture_file_created = FileAccess.file_exists(_fixture_path)
	_expect(str(_workbench.get("authoring_status")).contains("Item ID must match"), "workbench rejects path traversal in a new ID", failures)
	_expect(not FileAccess.file_exists(_escape_path), "rejected path traversal creates no resource outside the item root", failures)

	var lifecycle_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	var supports_create_remove := lifecycle_catalog.has_method("create_authored_definition") and lifecycle_catalog.has_method("remove_authored_definition")
	_expect(supports_create_remove, "ItemCatalog exposes transactional create/remove APIs", failures)
	var supports_undo_redo := lifecycle_catalog.has_method("undo_authored_definition_action") and lifecycle_catalog.has_method("redo_authored_definition_action")
	_expect(supports_undo_redo, "ItemCatalog exposes workbench undo/redo lifecycle callbacks", failures)
	if supports_create_remove:
		_exercise_transaction_boundaries(lifecycle_catalog, source_definition, failures)
	if supports_undo_redo and created_definition != null and FileAccess.file_exists(_fixture_path):
		_exercise_undo_redo(lifecycle_catalog, created_definition, source_definition, failures)


func _exercise_transaction_boundaries(
	catalog: ItemCatalog,
	source_definition: ItemDefinition,
	failures: Array[String],
) -> void:
	var collision_candidate := source_definition.duplicate(true) as ItemDefinition
	collision_candidate.id = &"plain_hood"
	var baseline_collision_path := ITEM_RESOURCE_ROOT.path_join("%s_baseline_collision.tres" % String(_fixture_id))
	var baseline_collision_reserved := not FileAccess.file_exists(baseline_collision_path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(baseline_collision_path))
	var baseline_collision_error := int(catalog.call("create_authored_definition", collision_candidate, baseline_collision_path))
	_expect(baseline_collision_error == ERR_ALREADY_EXISTS, "catalog rejects an ID already owned by a live baseline", failures)
	_expect(not FileAccess.file_exists(baseline_collision_path), "baseline ID collision writes no standalone resource", failures)
	if baseline_collision_reserved and FileAccess.file_exists(baseline_collision_path):
		_remove_file(baseline_collision_path)

	var path_candidate := source_definition.duplicate(true) as ItemDefinition
	path_candidate.id = StringName("%s_path_probe" % String(_fixture_id))
	_outside_catalog_path = "res://addons/%s.tres" % path_candidate.id
	_outside_catalog_path_reserved = not FileAccess.file_exists(_outside_catalog_path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_outside_catalog_path))
	var outside_path_error := int(catalog.call("create_authored_definition", path_candidate, _outside_catalog_path))
	_expect(outside_path_error == ERR_INVALID_PARAMETER, "catalog rejects a resource path outside the item-definition root", failures)
	_expect(not FileAccess.file_exists(_outside_catalog_path), "rejected catalog path writes no resource", failures)

	var blocker_id := StringName("codex_item_write_block_%d" % Time.get_ticks_usec())
	_blocked_path = ITEM_RESOURCE_ROOT.path_join("%s.tres" % String(blocker_id))
	_blocked_path_reserved = not FileAccess.file_exists(_blocked_path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_blocked_path))
	if not _blocked_path_reserved:
		_expect(false, "rollback path fixture is unused", failures)
		return
	var directory_error := DirAccess.make_dir_absolute(ProjectSettings.globalize_path(_blocked_path))
	_blocked_directory_created = directory_error == OK or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_blocked_path))
	_expect(_blocked_directory_created, "rollback fixture creates a directory at the new resource path", failures)
	if not _blocked_directory_created:
		return

	var before_failure_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	var before_failure_ids := before_failure_catalog.all_definition_ids()
	var before_failure_manifests: Array[String] = CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness()
	var blocked_candidate := source_definition.duplicate(true) as ItemDefinition
	blocked_candidate.id = blocker_id
	var failed_write_error := int(catalog.call("create_authored_definition", blocked_candidate, _blocked_path))
	_expect(failed_write_error != OK, "failed resource writes report an error", failures)
	_expect(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_blocked_path)), "failed create preserves the pre-existing path", failures)
	_expect(not FileAccess.file_exists(_blocked_path), "failed create leaves no partial resource file", failures)
	var after_failure_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	_expect(not after_failure_catalog.definition_exists(blocker_id), "failed create does not register the blocked ID", failures)
	_expect(after_failure_catalog.all_definition_ids() == before_failure_ids, "failed create rolls back the catalog cache", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness() == before_failure_manifests, "failed create leaves generated manifests unchanged", failures)
	var remove_directory_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(_blocked_path))
	_expect(remove_directory_error == OK, "rollback directory fixture is removed", failures)
	if remove_directory_error == OK or not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_blocked_path)):
		_blocked_directory_created = false

	_exercise_manifest_failure_rollback(catalog, source_definition, failures)


func _exercise_undo_redo(
	catalog: ItemCatalog,
	definition: ItemDefinition,
	source_definition: ItemDefinition,
	failures: Array[String],
) -> void:
	var source_id := source_definition.id
	var workbench_ref: WeakRef = weakref(_workbench)
	catalog.call("undo_authored_definition_action", definition, _fixture_path, source_id, workbench_ref)
	_expect(not FileAccess.file_exists(_fixture_path), "undo removes the standalone definition file", failures)
	_fixture_file_created = FileAccess.file_exists(_fixture_path)
	var after_undo_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	_expect(not after_undo_catalog.definition_exists(_fixture_id), "undo removes the item from catalog discovery", failures)
	_expect(StringName(str(_workbench.get("item_id"))) == source_id, "undo restores the source selection", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "undo refreshes all generated manifests", failures)

	if not FileAccess.file_exists(_fixture_path):
		_exercise_existing_path_collision(catalog, definition, failures)
		var redo_source_name := source_definition.display_name
		catalog.call(
			"redo_authored_definition_action",
			definition,
			_fixture_path,
			_fixture_id,
			redo_source_name,
			workbench_ref
		)
		_fixture_file_created = FileAccess.file_exists(_fixture_path)
		_expect(_fixture_file_created, "redo recreates the standalone definition file", failures)
		var after_redo_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
		_expect(after_redo_catalog.definition_exists(_fixture_id), "redo restores item catalog discovery", failures)
		_expect(StringName(str(_workbench.get("item_id"))) == _fixture_id, "redo selects the restored item", failures)
		_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "redo refreshes all generated manifests", failures)
		_exercise_replaced_file_rejection(catalog, definition, source_definition, failures)


func _exercise_replaced_file_rejection(
	catalog: ItemCatalog,
	definition: ItemDefinition,
	source_definition: ItemDefinition,
	failures: Array[String],
) -> void:
	if not FileAccess.file_exists(_fixture_path):
		_expect(false, "replacement rejection starts with the recreated fixture", failures)
		return
	var original_bytes := FileAccess.get_file_as_bytes(_fixture_path)
	var original_text := FileAccess.get_file_as_string(_fixture_path)
	var original_display_field := 'display_name = "%s"' % definition.display_name
	var changed_display_text := original_text.replace(
		original_display_field, 'display_name = "EXTERNAL EDIT"'
	)
	_expect(changed_display_text != original_text, "same-ID probe finds the serialized display name", failures)
	if changed_display_text != original_text:
		_exercise_replacement_attempt(
			catalog,
			definition,
			original_bytes,
			changed_display_text,
			"remove rejects same-ID external content changes",
			failures
		)
		if _replacement_probe_active or FileAccess.get_file_as_bytes(_fixture_path) != original_bytes:
			return

	var original_id_field := 'id = &"%s"' % String(_fixture_id)
	var replacement_id_field := 'id = &"%s"' % String(source_definition.id)
	var replacement_id_text := original_text.replace(original_id_field, replacement_id_field)
	_expect(replacement_id_text != original_text, "replacement probe finds the serialized stable ID", failures)
	if replacement_id_text != original_text:
		_exercise_replacement_attempt(
			catalog,
			definition,
			original_bytes,
			replacement_id_text,
			"remove rejects an on-disk definition with a replaced ID",
			failures
		)
		if _replacement_probe_active:
			return
	_fixture_file_created = FileAccess.file_exists(_fixture_path)
	_expect(
		FileAccess.get_file_as_bytes(_fixture_path) == original_bytes,
		"replacement probes leave the original fixture resource intact",
		failures
	)


func _exercise_replacement_attempt(
	catalog: ItemCatalog,
	definition: ItemDefinition,
	original_bytes: PackedByteArray,
	replacement_text: String,
	rejection_label: String,
	failures: Array[String],
) -> void:
	if not _reserve_replacement_backup(original_bytes, failures):
		return
	var replacement_file := FileAccess.open(_fixture_path, FileAccess.WRITE)
	_expect(replacement_file != null, "replacement probe writes only the reserved fixture path", failures)
	if replacement_file == null:
		return
	_replacement_probe_active = true
	replacement_file.store_string(replacement_text)
	replacement_file.flush()
	replacement_file.close()
	var replacement_bytes := FileAccess.get_file_as_bytes(_fixture_path)
	var remove_error := int(catalog.call("remove_authored_definition", definition, _fixture_path))
	_expect(remove_error == ERR_INVALID_DATA, rejection_label, failures)
	_expect(
		FileAccess.get_file_as_bytes(_fixture_path) == replacement_bytes,
		"remove rejection preserves externally replaced resource bytes",
		failures
	)
	_restore_replaced_fixture_resource(failures)
	_expect(
		FileAccess.get_file_as_bytes(_fixture_path) == original_bytes,
		"replacement probe restores the original fixture bytes",
		failures
	)


func _reserve_replacement_backup(
	original_bytes: PackedByteArray,
	failures: Array[String],
) -> bool:
	if _replacement_backup_reserved and FileAccess.file_exists(_replacement_backup_path):
		_expect(false, "previous replacement byte backup remains reserved", failures)
		return false
	_replacement_backup_path = "res://resources/generated/%s_replacement_backup.bin" % String(_fixture_id)
	_replacement_backup_reserved = (
		not FileAccess.file_exists(_replacement_backup_path)
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_replacement_backup_path))
	)
	_expect(_replacement_backup_reserved, "replacement probe reserves a byte backup path", failures)
	if not _replacement_backup_reserved:
		return false
	var backup := FileAccess.open(_replacement_backup_path, FileAccess.WRITE)
	_expect(backup != null, "replacement probe backs up the fixture before mutation", failures)
	if backup == null:
		return false
	backup.store_buffer(original_bytes)
	backup.flush()
	backup.close()
	if FileAccess.get_file_as_bytes(_replacement_backup_path) != original_bytes:
		_expect(false, "replacement probe backup preserves the fixture bytes", failures)
		return false
	_replacement_original_bytes = original_bytes
	return true


func _restore_replaced_fixture_resource(failures: Array[String]) -> void:
	if not _replacement_probe_active:
		return
	var restore_file := FileAccess.open(_fixture_path, FileAccess.WRITE)
	if restore_file == null:
		failures.append("replacement probe could not restore the fixture bytes (%d)" % FileAccess.get_open_error())
		return
	restore_file.store_buffer(_replacement_original_bytes)
	restore_file.flush()
	restore_file.close()
	if FileAccess.get_file_as_bytes(_fixture_path) != _replacement_original_bytes:
		failures.append("replacement probe restored different fixture bytes")
		return
	_replacement_probe_active = false
	if _replacement_backup_reserved and FileAccess.file_exists(_replacement_backup_path):
		var backup_remove_error := _remove_file(_replacement_backup_path)
		if backup_remove_error != OK:
			failures.append("replacement probe backup cleanup failed (%d)" % backup_remove_error)
		else:
			_replacement_backup_reserved = false


func _exercise_existing_path_collision(
	catalog: ItemCatalog,
	definition: ItemDefinition,
	failures: Array[String],
) -> void:
	if FileAccess.file_exists(_fixture_path) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_fixture_path)):
		_expect(false, "undo leaves an unused path for the collision boundary check", failures)
		return
	var marker := "codex item path collision %d" % Time.get_ticks_usec()
	var marker_file := FileAccess.open(_fixture_path, FileAccess.WRITE)
	_expect(marker_file != null, "path collision marker is written only to the reserved fixture path", failures)
	if marker_file == null:
		return
	marker_file.store_string(marker)
	marker_file.flush()
	marker_file.close()

	var collision_error := int(catalog.call("create_authored_definition", definition, _fixture_path))
	_expect(collision_error == ERR_ALREADY_EXISTS, "catalog rejects an already occupied resource path", failures)
	_expect(FileAccess.get_file_as_string(_fixture_path) == marker, "path collision rejection preserves existing file contents", failures)
	var remove_error := _remove_file(_fixture_path)
	_expect(remove_error == OK, "path collision marker is cleaned up", failures)
	var manifest_error := int(CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest())
	_expect(manifest_error == OK, "path collision cleanup restores generated manifests", failures)
	ITEM_CATALOG_DATA_SCRIPT.invalidate_default_cache()


func _exercise_manifest_failure_rollback(
	catalog: ItemCatalog,
	source_definition: ItemDefinition,
	failures: Array[String],
) -> void:
	var fixture_stem := "codex_item_manifest_failure_%d" % Time.get_ticks_usec()
	var candidate_id := StringName(fixture_stem)
	_manifest_failure_path = ITEM_RESOURCE_ROOT.path_join("%s.tres" % fixture_stem)
	_manifest_failure_path_reserved = (
		not FileAccess.file_exists(_manifest_failure_path)
		and not FileAccess.file_exists(_manifest_failure_path + ".uid")
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_manifest_failure_path))
	)
	_expect(_manifest_failure_path_reserved, "post-save failure resource path is unused", failures)
	if not _manifest_failure_path_reserved:
		return

	_manifest_failure_backup_path = "res://resources/generated/%s_manifest_backup.bin" % fixture_stem
	_manifest_failure_backup_reserved = (
		not FileAccess.file_exists(_manifest_failure_backup_path)
		and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_manifest_failure_backup_path))
	)
	_expect(_manifest_failure_backup_reserved, "post-save failure backup path is unused", failures)
	if not _manifest_failure_backup_reserved:
		return

	for manifest_path: String in GENERATED_MANIFEST_PATHS:
		var exists := FileAccess.file_exists(manifest_path)
		_manifest_failure_original_manifests[manifest_path] = {
			"exists": exists,
			"bytes": FileAccess.get_file_as_bytes(manifest_path) if exists else PackedByteArray(),
		}
	var item_manifest_state: Dictionary = _manifest_failure_original_manifests.get(ITEM_MANIFEST_PATH, {})
	if not bool(item_manifest_state.get("exists", false)):
		_expect(false, "post-save failure starts with an item manifest file", failures)
		return

	var backup := FileAccess.open(_manifest_failure_backup_path, FileAccess.WRITE)
	_expect(backup != null, "post-save rollback keeps a temporary byte-for-byte manifest backup", failures)
	if backup == null:
		return
	var backup_bytes: PackedByteArray = item_manifest_state.get("bytes", PackedByteArray())
	backup.store_buffer(backup_bytes)
	backup.flush()
	backup.close()
	_manifest_failure_fixture_active = true
	if FileAccess.get_file_as_bytes(_manifest_failure_backup_path) != backup_bytes:
		_expect(false, "post-save rollback backup preserves item manifest bytes", failures)
		_restore_manifest_failure_fixture(failures)
		return

	var remove_manifest_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(ITEM_MANIFEST_PATH))
	_expect(remove_manifest_error == OK, "post-save rollback removes the manifest file for the failure fixture", failures)
	if remove_manifest_error != OK:
		_restore_manifest_failure_fixture(failures)
		return
	var directory_error := DirAccess.make_dir_absolute(ProjectSettings.globalize_path(ITEM_MANIFEST_PATH))
	_manifest_failure_directory_created = (
		directory_error == OK
		or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ITEM_MANIFEST_PATH))
	)
	_expect(_manifest_failure_directory_created, "post-save rollback blocks the item manifest write", failures)
	if not _manifest_failure_directory_created:
		_restore_manifest_failure_fixture(failures)
		return

	var before_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	var before_ids: Array[StringName] = before_catalog.all_definition_ids()
	var candidate := source_definition.duplicate(true) as ItemDefinition
	candidate.id = candidate_id
	var create_error := int(catalog.call("create_authored_definition", candidate, _manifest_failure_path))
	_expect(create_error != OK, "manifest write failure aborts create after saving the definition", failures)
	_expect(not FileAccess.file_exists(_manifest_failure_path), "post-save rollback removes its new definition file", failures)
	_expect(not FileAccess.file_exists(_manifest_failure_path + ".uid"), "post-save rollback removes its new UID sidecar", failures)
	_expect(
		FileAccess.get_file_as_bytes(GENERATED_MANIFEST_PATHS[0])
			== _manifest_failure_original_manifests[GENERATED_MANIFEST_PATHS[0]].get("bytes", PackedByteArray()),
		"post-save rollback restores the overall manifest bytes",
		failures
	)
	_expect(
		FileAccess.get_file_as_bytes(GENERATED_MANIFEST_PATHS[1])
			== _manifest_failure_original_manifests[GENERATED_MANIFEST_PATHS[1]].get("bytes", PackedByteArray()),
		"post-save rollback restores the enemy manifest bytes",
		failures
	)
	_expect(
		DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ITEM_MANIFEST_PATH))
			and not FileAccess.file_exists(ITEM_MANIFEST_PATH),
		"post-save rollback preserves the pre-existing item manifest obstruction",
		failures
	)
	var after_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
	_expect(not after_catalog.definition_exists(candidate_id), "post-save rollback does not register the new ID", failures)
	_expect(after_catalog.all_definition_ids() == before_ids, "post-save rollback restores catalog discovery", failures)
	_restore_manifest_failure_fixture(failures)


func _restore_manifest_failure_fixture(failures: Array[String]) -> void:
	if not _manifest_failure_fixture_active:
		if _manifest_failure_backup_reserved and FileAccess.file_exists(_manifest_failure_backup_path):
			var unused_backup_error := _remove_file(_manifest_failure_backup_path)
			if unused_backup_error != OK:
				failures.append("post-save manifest backup cleanup failed (%d)" % unused_backup_error)
		return

	var restore_succeeded := true
	if _manifest_failure_path_reserved:
		for path: String in [_manifest_failure_path, _manifest_failure_path + ".uid"]:
			if FileAccess.file_exists(path):
				var candidate_remove_error := _remove_file(path)
				if candidate_remove_error != OK:
					failures.append("post-save candidate cleanup failed (%d)" % candidate_remove_error)
					restore_succeeded = false

	if _manifest_failure_directory_created and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ITEM_MANIFEST_PATH)):
		var directory_remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(ITEM_MANIFEST_PATH))
		if directory_remove_error != OK:
			failures.append("post-save manifest obstruction cleanup failed (%d)" % directory_remove_error)
			restore_succeeded = false
		else:
			_manifest_failure_directory_created = false

	for manifest_path: String in GENERATED_MANIFEST_PATHS:
		var state: Dictionary = _manifest_failure_original_manifests.get(manifest_path, {})
		if bool(state.get("exists", false)):
			var manifest_file := FileAccess.open(manifest_path, FileAccess.WRITE)
			if manifest_file == null:
				failures.append("post-save manifest restore failed for %s (%d)" % [manifest_path, FileAccess.get_open_error()])
				restore_succeeded = false
				continue
			var manifest_bytes: PackedByteArray = state.get("bytes", PackedByteArray())
			manifest_file.store_buffer(manifest_bytes)
			manifest_file.flush()
			manifest_file.close()
			if FileAccess.get_file_as_bytes(manifest_path) != manifest_bytes:
				failures.append("post-save manifest byte restore was incomplete for %s" % manifest_path)
				restore_succeeded = false
		elif FileAccess.file_exists(manifest_path):
			var manifest_remove_error := _remove_file(manifest_path)
			if manifest_remove_error != OK:
				failures.append("post-save manifest removal failed for %s (%d)" % [manifest_path, manifest_remove_error])
				restore_succeeded = false

	if restore_succeeded and FileAccess.file_exists(ITEM_MANIFEST_PATH):
		var restored_manifest := ResourceLoader.load(
			ITEM_MANIFEST_PATH, "", ResourceLoader.CACHE_MODE_REPLACE
		) as Resource
		if restored_manifest == null:
			failures.append("post-save item manifest cache reload failed")
			restore_succeeded = false
		else:
			var default_data := load("res://resources/definitions/item_catalog.tres") as ItemCatalogData
			if default_data == null:
				failures.append("post-save item catalog data reload failed")
				restore_succeeded = false
			else:
				default_data._item_manifest_dependency = restored_manifest
				default_data.invalidate_authored_definition_cache()

	if restore_succeeded and _manifest_failure_backup_reserved and FileAccess.file_exists(_manifest_failure_backup_path):
		var backup_remove_error := _remove_file(_manifest_failure_backup_path)
		if backup_remove_error != OK:
			failures.append("post-save manifest backup cleanup failed (%d)" % backup_remove_error)
			restore_succeeded = false
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ITEM_MANIFEST_PATH)) and restore_succeeded:
		_manifest_failure_fixture_active = false
		_manifest_failure_directory_created = false
		ITEM_CATALOG_DATA_SCRIPT.invalidate_default_cache()


func _watchdog() -> void:
	if _finished:
		return
	await create_timer(90.0).timeout
	if _finished:
		return
	var cleanup_failures: Array[String] = []
	_cleanup_test_resources(cleanup_failures, false)
	push_error("TEST_ABORTED: item preview workbench smoke did not finish")
	for failure: String in cleanup_failures:
		push_error("CLEANUP FAILED: %s" % failure)
	quit(1)


func _cleanup_test_resources(failures: Array[String], verify_cleanup: bool) -> void:
	_restore_replaced_fixture_resource(failures)
	_restore_manifest_failure_fixture(failures)
	if _replacement_backup_reserved and not _replacement_probe_active and FileAccess.file_exists(_replacement_backup_path):
		var replacement_backup_remove_error := _remove_file(_replacement_backup_path)
		if replacement_backup_remove_error != OK:
			failures.append("replacement probe backup cleanup failed (%d)" % replacement_backup_remove_error)
		else:
			_replacement_backup_reserved = false
	if _fixture_path_reserved and not _replacement_probe_active and (_fixture_file_created or FileAccess.file_exists(_fixture_path)):
		var cleanup_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
		var definition := ResourceLoader.load(
			_fixture_path, "", ResourceLoader.CACHE_MODE_IGNORE
		) as ItemDefinition
		if definition != null and cleanup_catalog.has_method("remove_authored_definition"):
			var lifecycle_error := int(cleanup_catalog.call("remove_authored_definition", definition, _fixture_path))
			if lifecycle_error != OK and verify_cleanup:
				failures.append("transactional cleanup failed (%d)" % lifecycle_error)
		if FileAccess.file_exists(_fixture_path):
			var remove_error := _remove_file(_fixture_path)
			if remove_error != OK:
				failures.append("fixture file cleanup failed (%d)" % remove_error)
	if _fixture_path_reserved and not _replacement_probe_active and FileAccess.file_exists(_fixture_uid_path):
		var uid_remove_error := _remove_file(_fixture_uid_path)
		if uid_remove_error != OK:
			failures.append("fixture UID cleanup failed (%d)" % uid_remove_error)
	if _escape_path_reserved and FileAccess.file_exists(_escape_path):
		var escape_remove_error := _remove_file(_escape_path)
		if escape_remove_error != OK:
			failures.append("unexpected traversal resource cleanup failed (%d)" % escape_remove_error)
	if _outside_catalog_path_reserved and FileAccess.file_exists(_outside_catalog_path):
		var outside_remove_error := _remove_file(_outside_catalog_path)
		if outside_remove_error != OK:
			failures.append("unexpected out-of-root resource cleanup failed (%d)" % outside_remove_error)
	if _blocked_directory_created and DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_blocked_path)):
		var directory_remove_error := DirAccess.remove_absolute(ProjectSettings.globalize_path(_blocked_path))
		if directory_remove_error != OK:
			failures.append("rollback directory cleanup failed (%d)" % directory_remove_error)
		_blocked_directory_created = false

	if _fixture_path_reserved and _replacement_probe_active and verify_cleanup:
		failures.append("replacement fixture could not be restored; preserving the file and byte backup")
	if _fixture_path_reserved and not _replacement_probe_active:
		var manifest_error := int(CONTENT_MANIFEST_SERVICE_SCRIPT.refresh_manifest())
		if manifest_error != OK:
			failures.append("generated manifest cleanup failed (%d)" % manifest_error)
		ITEM_CATALOG_DATA_SCRIPT.invalidate_default_cache()
		var default_data := load("res://resources/definitions/item_catalog.tres") as ItemCatalogData
		if default_data != null:
			default_data.invalidate_authored_definition_cache()
		if verify_cleanup:
			_expect(not FileAccess.file_exists(_fixture_path), "test leaves no standalone fixture resource", failures)
			_expect(not FileAccess.file_exists(_fixture_uid_path), "test leaves no fixture UID sidecar", failures)
			var final_manifest_problems: Array[String] = CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness()
			_expect(final_manifest_problems.is_empty(), "test restores every generated definition manifest", failures)
			var final_catalog := ITEM_CATALOG_SCRIPT.new() as ItemCatalog
			_expect(not final_catalog.definition_exists(_fixture_id), "test invalidates catalog caches after fixture cleanup", failures)
			_expect(_fixture_id not in final_catalog.playable_definition_ids(), "test removes the fixture from playable catalog IDs", failures)


func _remove_file(resource_path: String) -> Error:
	if not FileAccess.file_exists(resource_path):
		return OK
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ITEM_PREVIEW_WORKBENCH_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
