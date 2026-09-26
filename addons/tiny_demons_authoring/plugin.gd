@tool
extends EditorPlugin

const AuthoringDock := preload("res://addons/tiny_demons_authoring/authoring_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	# The dock only exists in the interactive editor. Headless validation scans
	# project.godot and scripts but must not construct editor UI.
	if DisplayServer.get_name() == "headless":
		return
	set_input_event_forwarding_always_enabled()
	_dock = AuthoringDock.new()
	_dock.call("configure", self)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	scene_changed.connect(_on_scene_changed)
	call_deferred("_refresh_dock")


func _exit_tree() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null


func _on_scene_changed(scene_root: Node) -> void:
	if _dock != null:
		_dock.call("set_scene_root", scene_root)


func _refresh_dock() -> void:
	if _dock != null:
		_dock.call("set_scene_root", get_editor_interface().get_edited_scene_root())


func _handles(object: Object) -> bool:
	return object is Node and object.has_method("handle_editor_canvas_input")


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not event is InputEventMouse:
		return false
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root == null or not scene_root.has_method("handle_editor_canvas_input"):
		return false
	var workbench := scene_root as Node2D
	if workbench == null:
		return false
	var viewport := get_editor_interface().get_editor_viewport_2d()
	if viewport == null:
		return false
	var canvas_position: Vector2 = viewport.global_canvas_transform.affine_inverse() * event.position
	var workbench_position: Vector2 = workbench.to_local(canvas_position)
	return bool(workbench.call("handle_editor_canvas_input", event, workbench_position))
