extends SceneTree

## Headless/editor-friendly preview command for the item authoring workbench.
## The scene owns selection, catalog resolution, and the preview contract; this
## driver only selects an ID and reports its deterministic summary.

const PREVIEW_SCENE: PackedScene = preload("res://scenes/item_preview_workbench.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var definition_id := _item_id_from_args()
	var preview := PREVIEW_SCENE.instantiate() as Node2D
	if preview == null:
		push_error("ITEM_PREVIEW_FAILED id=%s error=scene could not be instantiated" % definition_id)
		quit(1)
		return
	preview.set("item_id", definition_id)
	root.add_child(preview)
	await process_frame

	var summary := preview.call("get_preview_summary") as Dictionary
	if not bool(summary.get("ready", false)) or StringName(str(summary.get("id", ""))) != definition_id:
		push_error("ITEM_PREVIEW_FAILED id=%s error=%s" % [definition_id, str(summary.get("error", "item ID is not in the current playable catalog"))])
		preview.queue_free()
		await process_frame
		quit(1)
		return

	print("ITEM_PREVIEW_OK id=%s display=%s slot=%s editable=%s mode=%s" % [
		str(summary.get("id", definition_id)),
		str(summary.get("display_name", "")),
		str(summary.get("slot", "")),
		str(summary.get("editable", false)),
		str(summary.get("preview_mode", "card")),
	])
	preview.queue_free()
	await process_frame
	quit(0)


func _item_id_from_args() -> StringName:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--item-id="):
			return StringName(argument.trim_prefix("--item-id="))
	return &"cinder_blade"
