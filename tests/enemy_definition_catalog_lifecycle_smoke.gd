extends SceneTree

## Focused saved-resource lifecycle for the editor-created enemy definition action.

const ENEMY_CATALOG_SCRIPT := preload("res://scripts/content/enemy_catalog.gd")
const CONTENT_MANIFEST_SERVICE_SCRIPT := preload("res://scripts/content/content_definition_manifest_service.gd")

var _finished := false


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
	var source_definition := ENEMY_CATALOG_SCRIPT.definition_resource(&"guard_slime")
	_expect(source_definition != null, "catalog lifecycle fixture has a source definition", failures)
	if source_definition == null:
		_finish(failures)
		return

	var fixture_id := StringName("codex_catalog_lifecycle_%d" % Time.get_ticks_usec())
	var definition_path := "res://resources/definitions/%s.tres" % fixture_id
	var traversal_path := "res://resources/definitions/../../addons/codex_traversal_fixture.tres"
	var fixture := source_definition.duplicate(true) as EnemyDefinition
	fixture.id = fixture_id
	fixture.display_name = "Catalog Lifecycle Fixture"
	fixture.resource_name = fixture.display_name

	var traversal_error: Error = ENEMY_CATALOG_SCRIPT.create_authored_definition(fixture, traversal_path)
	_expect(traversal_error == ERR_INVALID_PARAMETER, "create rejects paths outside the definitions root", failures)
	_expect(not FileAccess.file_exists("res://addons/codex_traversal_fixture.tres"), "rejected traversal writes no file", failures)


	var probe := WorkbenchProbe.new()
	root.add_child(probe)
	var adapter: RefCounted = ENEMY_CATALOG_SCRIPT.new()
	var workbench_ref: WeakRef = weakref(probe)
	var source_id: StringName = source_definition.variant_id

	_expect(not ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "catalog lifecycle ID is unused", failures)
	_expect(not FileAccess.file_exists(definition_path), "catalog lifecycle path is unused", failures)
	adapter.redo_authored_definition_action(
		fixture, definition_path, fixture_id, source_definition.display_name, workbench_ref
	)
	_expect(FileAccess.file_exists(definition_path), "create writes the standalone definition file", failures)
	_expect(fixture.resource_path == definition_path, "create assigns its saved resource path", failures)
	_expect(ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "create invalidates the catalog cache", failures)
	_expect(probe.selected_variant_id == fixture_id, "create selects the new variant", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "create refreshes generated manifests", failures)
	var created_catalog := ResourceLoader.load(
		ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as SlimeVariantCatalogData
	_expect(created_catalog != null and _catalog_contains_id(created_catalog, fixture_id), "saved catalog reload discovers the definition", failures)

	adapter.undo_authored_definition_action(fixture, definition_path, source_id, workbench_ref)
	_expect(not FileAccess.file_exists(definition_path), "undo removes the standalone definition file", failures)
	_expect(fixture.resource_path.is_empty(), "undo clears the removed resource path", failures)
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
	_expect(FileAccess.file_exists(definition_path), "redo recreates the definition file", failures)
	_expect(fixture.resource_path == definition_path, "redo restores the resource path", failures)
	_expect(ENEMY_CATALOG_SCRIPT.contains_id(fixture_id), "redo restores the catalog entry", failures)
	_expect(probe.selected_variant_id == fixture_id, "redo selects the recreated variant", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "redo refreshes generated manifests", failures)
	var redone_catalog := ResourceLoader.load(
		ENEMY_CATALOG_SCRIPT.CATALOG_RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as SlimeVariantCatalogData
	_expect(redone_catalog != null and _catalog_contains_id(redone_catalog, fixture_id), "saved catalog reload discovers the redone definition", failures)

	if ENEMY_CATALOG_SCRIPT.DATA.definitions.has(fixture) or FileAccess.file_exists(definition_path):
		var cleanup_error: Error = ENEMY_CATALOG_SCRIPT.remove_authored_definition(fixture, definition_path)
		_expect(cleanup_error == OK, "test cleanup removes its definition", failures)
	_expect(not FileAccess.file_exists(definition_path), "test leaves no temporary definition file", failures)
	_expect(CONTENT_MANIFEST_SERVICE_SCRIPT.check_freshness().is_empty(), "test leaves generated manifests fresh", failures)
	probe.queue_free()
	await process_frame
	_finished = true
	_finish(failures)


func _catalog_contains_id(catalog_data: SlimeVariantCatalogData, enemy_id: StringName) -> bool:
	for definition in catalog_data.authored_definitions():
		if definition.variant_id == enemy_id:
			return true
	return false


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
	push_error("TEST_ABORTED: enemy definition catalog lifecycle smoke failed before completion")
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)