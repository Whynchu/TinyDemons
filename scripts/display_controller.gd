extends Node
class_name DisplayController

## Applies the logical display settings and owns the runtime-sized void/frame.
## The content-scale pipeline remains canvas_items + keep_height; only the native
## content width and integer/fractional preference change here.

signal view_size_changed(view_size: Vector2i)

const VOID_COLOR := Color8(17, 19, 24)
const FRAME_COLOR := Color8(6, 6, 6)
const TOP_BAR_HEIGHT := 16.0
const BOTTOM_BAR_HEIGHT := 15.0

var settings_service: SettingsService = null
var current_view_size := DisplayLayout.NATIVE_SIZE
var _root: Node = null
var _void_background: ColorRect = null
var _top_bar: ColorRect = null
var _bottom_bar: ColorRect = null
var _world_offset := Vector2.ZERO


func initialize(root: Node, service: SettingsService) -> void:
	_root = root
	settings_service = service
	if settings_service != null and not settings_service.setting_changed.is_connected(_on_setting_changed):
		settings_service.setting_changed.connect(_on_setting_changed)
	var layout_callback := Callable(root, "_on_display_view_size_changed")
	if root.has_method("_on_display_view_size_changed") and not view_size_changed.is_connected(layout_callback):
		view_size_changed.connect(layout_callback)
	_build_presentation()
	apply_settings()
	var window := get_window()
	if window != null and not window.size_changed.is_connected(_on_window_size_changed):
		window.size_changed.connect(_on_window_size_changed)


func view_size_value() -> Vector2i:
	return current_view_size


func view_size_as_vector() -> Vector2:
	return Vector2(current_view_size)


func apply_settings() -> void:
	var aspect := "3:2"
	var pixel_perfect := true
	var fullscreen := false
	if settings_service != null:
		aspect = str(settings_service.get_setting(&"aspect", "3:2"))
		pixel_perfect = bool(settings_service.get_setting(&"pixel_perfect", true))
		fullscreen = bool(settings_service.get_setting(&"fullscreen", false))
	var next_size := DisplayLayout.view_size(aspect)
	var size_changed := next_size != current_view_size
	current_view_size = next_size
	var window := get_window()
	if window != null:
		window.content_scale_size = current_view_size
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		# Wide logical modes add horizontal content while preserving the native
		# 160px vertical scale. KEEP would fit a 16:9 base into a 3:2 target by
		# shrinking it vertically, which makes every menu look compressed.
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
		window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		_apply_fullscreen(window, fullscreen)
		_resize_window_width_for_aspect(window, current_view_size, fullscreen)
	RenderingServer.set_default_clear_color(VOID_COLOR)
	_sync_presentation()
	_apply_world_offset()
	if size_changed:
		view_size_changed.emit(current_view_size)


func set_fullscreen(enabled: bool) -> void:
	if settings_service != null:
		settings_service.set_setting(&"fullscreen", enabled)
	else:
		_apply_fullscreen(get_window(), enabled)


func set_aspect(aspect: String) -> void:
	if settings_service != null:
		settings_service.set_setting(&"aspect", aspect)


func set_pixel_perfect(enabled: bool) -> void:
	if settings_service != null:
		settings_service.set_setting(&"pixel_perfect", enabled)


func _apply_fullscreen(window: Window, enabled: bool) -> void:
	if window == null:
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


func _resize_window_width_for_aspect(window: Window, view_size: Vector2i, fullscreen: bool) -> void:
	# The browser/mobile viewport owns its physical size. Desktop windowed mode
	# can show the selected logical width directly while retaining the user's
	# current height, so switching to a wide mode never compresses the menu.
	if window == null or fullscreen or OS.has_feature("web"):
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var current_size := window.size
	if current_size.y <= 0 or view_size.y <= 0:
		return
	var target_width := maxi(1, roundi(float(current_size.y) * float(view_size.x) / float(view_size.y)))
	if current_size.x != target_width:
		window.size = Vector2i(target_width, current_size.y)


func _on_setting_changed(key: StringName, _value: Variant) -> void:
	if key in [&"aspect", &"pixel_perfect", &"fullscreen"]:
		# This path is called directly by a Button.pressed handler for the web
		# fullscreen rule; it intentionally is not deferred.
		apply_settings()


func _on_window_size_changed() -> void:
	_sync_presentation()


func _build_presentation() -> void:
	if _root == null:
		return
	var authored_background := _root.get_node_or_null("BackgroundCanvas/Background") as CanvasItem
	if authored_background != null:
		authored_background.visible = false
	var background_canvas := _root.get_node_or_null("BackgroundCanvas") as CanvasLayer
	if background_canvas != null and _void_background == null:
		_void_background = ColorRect.new()
		_void_background.name = "DisplayVoidBackground"
		_void_background.color = VOID_COLOR
		_void_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_void_background.z_index = -20
		background_canvas.add_child(_void_background)
	var authored_bars := _root.get_node_or_null("InterfaceCanvas/UI/BlackBars") as CanvasItem
	if authored_bars != null:
		authored_bars.visible = false
	var ui := _root.get_node_or_null("InterfaceCanvas/UI") as Node
	if ui != null and _top_bar == null:
		_top_bar = _make_bar(ui, "DisplayTopBar")
		_bottom_bar = _make_bar(ui, "DisplayBottomBar")


func _make_bar(parent: Node, bar_name: StringName) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.color = FRAME_COLOR
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.z_index = -10
	parent.add_child(bar)
	return bar


func _sync_presentation() -> void:
	var size := Vector2(current_view_size)
	if _void_background != null:
		_void_background.position = Vector2.ZERO
		_void_background.size = size
	if _top_bar != null:
		_top_bar.position = Vector2.ZERO
		_top_bar.size = Vector2(size.x, TOP_BAR_HEIGHT)
	if _bottom_bar != null:
		_bottom_bar.position = Vector2(0.0, size.y - BOTTOM_BAR_HEIGHT)
		_bottom_bar.size = Vector2(size.x, BOTTOM_BAR_HEIGHT)


func _apply_world_offset() -> void:
	if _root == null:
		return
	var desired := Vector2(DisplayLayout.center_x(float(current_view_size.x)), 0.0)
	var delta := desired - _world_offset
	if delta == Vector2.ZERO:
		_root.set("display_world_offset", desired)
		return
	var map_root := _root.get_node_or_null("Map") as Node2D
	if map_root != null:
		map_root.position += delta
	var actors_root := _root.get_node_or_null("Actors") as Node2D
	if actors_root != null:
		actors_root.position += delta
	var room_controller := _root.get("room_controller") as RoomController
	if room_controller != null:
		room_controller.rebase_enemy_spawn_positions(delta)
	_world_offset = desired
	_root.set("display_world_offset", desired)
