@tool
extends EditorPlugin

const AuthoringDock := preload("res://addons/tiny_demons_authoring/authoring_dock.gd")
const PreviewSessionLauncher := preload("res://addons/tiny_demons_authoring/preview_session_launcher.gd")
const HUB_PREVIEW_SCENE := "res://scenes/authoring/previews/hub_world_preview.tscn"
const ENEMY_PREVIEW_SCENE := "res://scenes/authoring/previews/enemy_preview_workbench.tscn"

var _dock: Control = null
var _preview_launcher: RefCounted = null
var _pending_enemy_preview_id: StringName = &""
var _resource_filesystem: EditorFileSystem = null
var _authoring_refresh_queued := false


func _enter_tree() -> void:
	# The dock only exists in the interactive editor. Headless validation scans
	# project.godot and scripts but must not construct editor UI.
	if DisplayServer.get_name() == "headless":
		return
	set_input_event_forwarding_always_enabled()
	_preview_launcher = PreviewSessionLauncher.new() as RefCounted
	_dock = AuthoringDock.new()
	_dock.call("configure", self)
	_dock.connect("design_preview_requested", _open_enemy_design_preview)
	_dock.connect("interactive_preview_requested", _launch_interactive_enemy_preview)
	_dock.connect("stop_preview_requested", _stop_interactive_preview)
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, _dock)
	scene_changed.connect(_on_scene_changed)
	resource_saved.connect(_on_resource_saved)
	_resource_filesystem = get_editor_interface().get_resource_filesystem()
	if _resource_filesystem != null:
		_resource_filesystem.resources_reimported.connect(_on_resources_reimported)
		_resource_filesystem.filesystem_changed.connect(_on_filesystem_changed)
	set_process(true)
	call_deferred("_refresh_dock")


func _exit_tree() -> void:
	if _preview_launcher != null:
		_preview_launcher.call("stop_and_cleanup")
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if resource_saved.is_connected(_on_resource_saved):
		resource_saved.disconnect(_on_resource_saved)
	if _resource_filesystem != null and _resource_filesystem.resources_reimported.is_connected(_on_resources_reimported):
		_resource_filesystem.resources_reimported.disconnect(_on_resources_reimported)
	if _resource_filesystem != null and _resource_filesystem.filesystem_changed.is_connected(_on_filesystem_changed):
		_resource_filesystem.filesystem_changed.disconnect(_on_filesystem_changed)
	_resource_filesystem = null
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
	_preview_launcher = null
	_pending_enemy_preview_id = &""
	_authoring_refresh_queued = false


func _process(_delta: float) -> void:
	if _preview_launcher == null:
		return
	_preview_launcher.call("tick")
	if _dock != null:
		_dock.call("set_preview_status", String(_preview_launcher.get("status")), bool(_preview_launcher.call("is_running")))


func _on_scene_changed(scene_root: Node) -> void:
	_apply_pending_enemy_preview(scene_root)
	if _dock != null:
		_dock.call("set_scene_root", scene_root)


func _refresh_dock() -> void:
	if _dock != null:
		_dock.call("set_scene_root", get_editor_interface().get_edited_scene_root())
	if _pending_enemy_preview_id != &"":
		_apply_pending_enemy_preview(get_editor_interface().get_edited_scene_root())


func _on_resource_saved(_resource: Resource) -> void:
	_queue_authoring_refresh()


func _on_resources_reimported(_resources: PackedStringArray) -> void:
	_queue_authoring_refresh()


func _on_filesystem_changed() -> void:
	_queue_authoring_refresh()


func _queue_authoring_refresh() -> void:
	if _authoring_refresh_queued:
		return
	_authoring_refresh_queued = true
	call_deferred("_refresh_authoring_content")


func _refresh_authoring_content() -> void:
	_authoring_refresh_queued = false
	if _dock != null:
		_dock.call("_refresh_authoring_content")


func _open_enemy_design_preview(enemy_id: StringName) -> void:
	var scene_root := get_editor_interface().get_edited_scene_root()
	if scene_root != null and scene_root.scene_file_path == ENEMY_PREVIEW_SCENE:
		_apply_enemy_id_to_scene(scene_root, enemy_id)
		return
	_pending_enemy_preview_id = enemy_id
	get_editor_interface().open_scene_from_path(ENEMY_PREVIEW_SCENE)


func _apply_pending_enemy_preview(scene_root: Node) -> void:
	if _pending_enemy_preview_id == &"" or scene_root == null or scene_root.scene_file_path != ENEMY_PREVIEW_SCENE:
		return
	_apply_enemy_id_to_scene(scene_root, _pending_enemy_preview_id)
	_pending_enemy_preview_id = &""


func _apply_enemy_id_to_scene(scene_root: Node, enemy_id: StringName) -> void:
	if scene_root == null:
		return
	scene_root.set("enemy_id", enemy_id)


func _launch_interactive_enemy_preview(enemy_id: StringName, seed_value: int) -> void:
	if _preview_launcher == null:
		return
	_preview_launcher.call("launch_enemy", enemy_id, seed_value)
	if _dock != null:
		_dock.call("set_preview_status", String(_preview_launcher.get("status")), bool(_preview_launcher.call("is_running")))


func _stop_interactive_preview() -> void:
	if _preview_launcher == null:
		return
	_preview_launcher.call("stop")
	if _dock != null:
		_dock.call("set_preview_status", String(_preview_launcher.get("status")), bool(_preview_launcher.call("is_running")))


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
