extends SceneTree

## Headless contract for the enemy actions and selector exposed by the dock.

const AuthoringDockScript := preload("res://addons/tiny_demons_authoring/authoring_dock.gd")
const SlimeVariantCatalogScript := preload("res://scripts/content/slime_variant_catalog.gd")

var _design_id: StringName = &""
var _interactive_id: StringName = &""
var _interactive_seed := -2


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var dock := AuthoringDockScript.new() as Control
	dock.call("configure", null)
	root.add_child(dock)
	dock.connect("design_preview_requested", _on_design_preview_requested)
	dock.connect("interactive_preview_requested", _on_interactive_preview_requested)
	dock.call("_refresh_authoring_content")

	var picker := dock.get("_enemy_picker") as OptionButton
	_expect(picker != null, "dock builds its registered enemy picker", failures)
	if picker != null:
		var actual_ids: Array[StringName] = []
		for index in picker.item_count:
			var value: Variant = picker.get_item_metadata(index)
			actual_ids.append(value as StringName if value is StringName else StringName(str(value)))
		var expected_ids := SlimeVariantCatalogScript.variants()
		var all_ids_present := actual_ids.size() == expected_ids.size()
		for expected_variant_id in expected_ids:
			all_ids_present = all_ids_present and expected_variant_id in actual_ids
		_expect(all_ids_present, "dock selector preserves the full registered enemy ID set", failures)
		var expected_id: StringName = &""
		if SlimeVariantCatalogScript.is_variant(&"guard_slime"):
			expected_id = &"guard_slime"
		elif not actual_ids.is_empty():
			expected_id = actual_ids[0]
		var selected_index := actual_ids.find(expected_id)
		if selected_index >= 0:
			picker.select(selected_index)
			dock.call("_request_design_preview")
			var seed_input := dock.get("_preview_seed") as SpinBox
			if seed_input != null:
				seed_input.value = 41723
			dock.call("_request_interactive_preview")
		_expect(_design_id == expected_id, "Design requests the selected stable enemy ID", failures)
		_expect(_interactive_id == expected_id, "Play requests the selected stable enemy ID", failures)
		_expect(_interactive_seed == 41723, "Play forwards the reproducible seed", failures)
	else:
		_expect(false, "registered enemy selector is available", failures)

	var stop_button := dock.get("_stop_preview_button") as Button
	dock.call("set_preview_status", "Preview running", true)
	_expect(stop_button != null and not stop_button.disabled, "Stop becomes available while a child session runs", failures)
	dock.call("set_preview_status", "No preview", false)
	_expect(stop_button != null and stop_button.disabled, "Stop is disabled when no child session runs", failures)
	dock.queue_free()
	await process_frame
	_finish(failures)


func _on_design_preview_requested(enemy_id: StringName) -> void:
	_design_id = enemy_id


func _on_interactive_preview_requested(enemy_id: StringName, seed_value: int) -> void:
	_interactive_id = enemy_id
	_interactive_seed = seed_value


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("AUTHORING_DOCK_PREVIEW_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
