extends SceneTree

## Headless contract for the editor-safe enemy design preview lifecycle.
## This does not replace editor-visible acceptance of the rendered preview.

const PREVIEW_SCENE := preload("res://scenes/enemy_preview_workbench.tscn")

var _finished := false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var preview := PREVIEW_SCENE.instantiate()
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
