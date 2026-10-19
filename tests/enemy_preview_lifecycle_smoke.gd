extends SceneTree

## Headless contract for the editor-safe enemy design preview lifecycle.
## This does not replace editor-visible acceptance of the rendered preview.

const PREVIEW_SCENE := preload("res://scenes/authoring/previews/enemy_preview_workbench.tscn")

var _finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var preview := PREVIEW_SCENE.instantiate()
	# The workbench scene opens in Boss actor mode for the editor. Start this
	# regular-family characterization explicitly, then exercise the size switch.
	preview.set("preview_actor_size", 0)
	preview.set("enemy_id", &"guard_slime")
	root.add_child(preview)
	await process_frame

	var summary := preview.call("get_preview_summary") as Dictionary
	_expect(bool(summary.get("ready", false)), "selected enemy preview resolves", failures)
	_expect(String(summary.get("id", "")) == "guard_slime", "preview reports the selected stable ID", failures)
	_expect((preview.get("preview_actor") as Node).process_mode == Node.PROCESS_MODE_DISABLED, "preview actor simulation is disabled", failures)

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
	var roundtrip_path := "user://enemy_preview_boss_roundtrip.tscn"
	var save_result := ResourceSaver.save(packed, roundtrip_path)
	_expect(save_result == OK, "boss geometry scene saves", failures)
	if save_result == OK:
		var saved_scene := ResourceLoader.load(roundtrip_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
		var saved_actor := saved_scene.instantiate()
		_expect(saved_actor.get_node("BodyHitbox").polygon == points, "boss saved scene retains edited body", failures)
		_expect(saved_actor.get_node("Combat") != null and saved_actor.get_node("Visual") != null, "boss save preserves runtime components", failures)
		saved_actor.free()
		DirAccess.remove_absolute(ProjectSettings.globalize_path(roundtrip_path))
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
	if failures.is_empty():
		print("ENEMY_PREVIEW_LIFECYCLE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
