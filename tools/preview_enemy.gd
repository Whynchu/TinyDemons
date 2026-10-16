extends SceneTree

## Headless/editor-friendly preview command for the enemy authoring workbench.
## The workbench itself is the source of truth; this driver only selects an id,
## waits for the scene to materialize, and reports the same contract summary an
## agent needs for a fast check.

const PREVIEW_SCENE := preload("res://scenes/authoring/previews/enemy_preview_workbench.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var enemy_id := _enemy_id_from_args()
	var preview := PREVIEW_SCENE.instantiate() as Node2D
	if preview == null:
		push_error("ENEMY_PREVIEW_FAILED id=%s error=scene could not be instantiated" % enemy_id)
		quit(1)
		return
	preview.set("enemy_id", StringName(enemy_id))
	root.add_child(preview)
	await process_frame

	var summary := preview.call("get_preview_summary") as Dictionary
	if typeof(summary) != TYPE_DICTIONARY:
		push_error("ENEMY_PREVIEW_FAILED id=%s error=preview returned no summary" % enemy_id)
		preview.queue_free()
		await process_frame
		quit(1)
		return
	var resolved_id := StringName(str(summary.get("id", "")))
	if not bool(summary.get("ready", false)) or resolved_id != StringName(enemy_id):
		var failure := str(summary.get("error", ""))
		if resolved_id != StringName(enemy_id):
			failure = "requested ID resolved to '%s'" % resolved_id
		if failure.is_empty():
			failure = "preview is not ready"
		push_error("ENEMY_PREVIEW_FAILED id=%s error=%s" % [enemy_id, failure])
		preview.queue_free()
		await process_frame
		quit(1)
		return

	print("ENEMY_PREVIEW_OK id=%s display=%s element=%s geometry=%s" % [resolved_id, summary.get("display_name", ""), summary.get("element", ""), summary.get("geometry_valid", false)])
	preview.queue_free()
	await process_frame
	quit(0)


func _enemy_id_from_args() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--enemy-id="):
			return argument.trim_prefix("--enemy-id=")
	return "guard_slime"
