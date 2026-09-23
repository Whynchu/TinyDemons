@tool
extends EditorPlugin

const AuthoringDock := preload("res://addons/tiny_demons_authoring/authoring_dock.gd")

var _dock: Control = null


func _enter_tree() -> void:
	# The dock only exists in the interactive editor. Headless validation scans
	# project.godot and scripts but must not construct editor UI.
	if DisplayServer.get_name() == "headless":
		return
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
