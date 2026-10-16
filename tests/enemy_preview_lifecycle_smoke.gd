extends SceneTree

## Headless contract for the editor-safe enemy design preview lifecycle.
## This does not replace editor-visible acceptance of the rendered preview.

const PREVIEW_SCENE := preload("res://scenes/authoring/previews/enemy_preview_workbench.tscn")

var _finished := false
var _roundtrip_path := ""
var _roundtrip_owned := false
var _preview: Node


func _initialize() -> void:
	create_timer(90.0).timeout.connect(_watchdog)
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var preview := PREVIEW_SCENE.instantiate()
	_preview = preview
	# The editor scene opens in Boss mode; this fixture starts with the regular
	# family geometry before explicitly switching to its boss counterpart.
	preview.set("preview_actor_size", 0)
	preview.set("enemy_id", &"guard_slime")
	root.add_child(preview)
	await process_frame

	var summary := preview.call("get_preview_summary") as Dictionary
	_expect(bool(summary.get("ready", false)), "selected enemy preview resolves", failures)
	_expect(String(summary.get("id", "")) == "guard_slime", "preview reports the selected stable ID", failures)
	_expect((preview.get("preview_actor") as Node).process_mode == Node.PROCESS_MODE_DISABLED, "preview actor simulation is disabled", failures)
	var supports_label_fitting := preview.has_method("_fit_pixel_label_texture")
	_expect(supports_label_fitting, "pixel labels expose their bounded fitting contract", failures)
	if supports_label_fitting:
		var long_name := "A VERY LONG AUTHORED ENEMY NAME WITH A UNIQUE NUMERIC SUFFIX 20261015"
		var fitted: Texture2D = preview.call("_fit_pixel_label_texture", long_name, Color.WHITE, 136.0)
		_expect(fitted != null and fitted.get_width() <= 136, "long authored labels fit the preview panel", failures)
		_expect(preview.call("_fit_pixel_label_texture", long_name, Color.WHITE, 2.0) == null, "labels narrower than the ellipsis safely omit drawing", failures)
		_expect(preview.call("_fit_pixel_label_texture", long_name, Color.WHITE, 0.0) == null, "zero-width labels safely omit drawing", failures)
		var selected_definition := preview.get("definition") as EnemyDefinition
		var original_name := selected_definition.display_name
		selected_definition.display_name = long_name
		preview.queue_redraw()
		await process_frame
		_expect(bool((preview.call("get_preview_summary") as Dictionary).get("ready", false)), "drawing a long authored name returns to the next frame", failures)
		selected_definition.display_name = original_name

	preview.call("preview_death_effect")
	var first_particle_count := (preview.get("_death_effect_particles") as Array).size()
	_expect(first_particle_count > 0, "death effect creates visible pixel particles", failures)
	_expect(not (preview.get("preview_actor") as CanvasItem).visible, "death effect hides the intact preview actor", failures)
	preview.call("preview_death_effect")
	var second_particle_count := (preview.get("_death_effect_particles") as Array).size()
	_expect(second_particle_count == first_particle_count, "death effect uses deterministic particle count", failures)
	preview.call("refresh_preview")
	_expect((preview.get("_death_effect_particles") as Array).is_empty(), "refresh removes transient death particles", failures)
	_expect((preview.get("preview_actor") as CanvasItem).visible, "refresh restores the preview actor", failures)
	_expect(bool((preview.call("get_preview_summary") as Dictionary).get("ready", false)), "refresh leaves a ready preview", failures)

	var regular_geometry: Dictionary = preview.call("_capture_geometry")
	_expect(not preview.get_node("PreviewEnemy/AttackGuideL").visible and not preview.get_node("PreviewEnemy/AttackGuideR").visible, "slime legacy attack boxes are hidden", failures)
	preview.set("preview_actor_size", 1)
	await process_frame
	var boss_geometry: Dictionary = preview.call("_capture_geometry")
	_expect(boss_geometry != regular_geometry, "boss preview uses native boss geometry", failures)
	_expect(boss_geometry["body_hitbox_polygon"] == preview.get_node("PreviewEnemy/BodyHitbox").polygon, "boss edit handles match displayed body", failures)
	var edited := boss_geometry.duplicate(true)
	var points: PackedVector2Array = edited["body_hitbox_polygon"]
	points[0] += Vector2(0.5, 0.0)
	edited["body_hitbox_polygon"] = points
	preview.call("_push_geometry_undo", boss_geometry)
	preview.call("_apply_geometry_snapshot", edited)
	_expect(preview.call("_definition_is_dirty"), "boss geometry edits mark workbench dirty", failures)
	_expect(preview.get_node("PreviewEnemy/BodyHitbox").polygon == points, "boss edit changes visible body", failures)
	preview.call("refresh_preview")
	_expect(preview.call("_capture_geometry") == edited, "refresh preserves unsaved boss geometry", failures)
	preview.call("undo_geometry_edit")
	_expect(preview.call("_capture_geometry") == boss_geometry, "boss undo restores authored geometry", failures)
	preview.call("redo_geometry_edit")
	_expect(preview.call("_capture_geometry") == edited, "boss redo restores edited geometry", failures)
	var packed: PackedScene = preview.call("_pack_boss_geometry")
	_roundtrip_path = "res://.godot/enemy_preview_boss_roundtrip_%d_%d.tscn" % [OS.get_process_id(), Time.get_ticks_usec()]
	_roundtrip_owned = not FileAccess.file_exists(_roundtrip_path) and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(_roundtrip_path)) and not FileAccess.file_exists(_roundtrip_path + ".uid")
	_expect(_roundtrip_owned, "preview roundtrip reserves a unique ignored path", failures)
	if _roundtrip_owned:
		var save_result := ResourceSaver.save(packed, _roundtrip_path)
		_expect(save_result == OK, "boss geometry scene saves", failures)
		if save_result == OK:
			var saved_scene := ResourceLoader.load(_roundtrip_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
			_expect(saved_scene != null, "saved boss geometry scene reloads", failures)
			if saved_scene != null:
				var saved_actor := saved_scene.instantiate()
				_expect(saved_actor.get_node("BodyHitbox").polygon == points, "boss saved scene retains edited body", failures)
				_expect(saved_actor.get_node("Combat") != null and saved_actor.get_node("Visual") != null, "boss save preserves runtime components", failures)
				saved_actor.free()
	preview.call("undo_geometry_edit")
	preview.set("preview_actor_size", 0)
	await process_frame
	_expect(preview.call("_capture_geometry") == regular_geometry, "boss edits leave regular family geometry unchanged", failures)

	var actor := preview.get("preview_actor") as Node
	preview.queue_free()
	await process_frame
	_expect(not is_instance_valid(actor), "closing the preview frees its factory actor", failures)
	_finished = true
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if is_instance_valid(_preview):
		_preview.free()
	if _roundtrip_owned:
		for path in [_roundtrip_path, _roundtrip_path + ".uid"]:
			if FileAccess.file_exists(path):
				_expect(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "preview removes only its reserved roundtrip artifact", failures)
	if failures.is_empty():
		print("ENEMY_PREVIEW_LIFECYCLE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _watchdog() -> void:
	if not _finished:
		_finish(["enemy preview lifecycle smoke timed out"])


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
