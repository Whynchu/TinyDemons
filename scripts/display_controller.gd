extends Node
class_name DisplayController

## Applies the logical display settings and owns the runtime-sized void/frame.
## World geometry stays in its authored coordinate system. The active UI frame
## is centered inside any wider logical viewport exposed by the stretch system.

signal view_size_changed(view_size: Vector2i)

const VOID_COLOR := Color8(17, 19, 24)
const FRAME_COLOR := Color8(6, 6, 6)
const TOP_BAR_HEIGHT := 16.0
const BOTTOM_BAR_HEIGHT := 15.0
const WORLD_CENTER := Vector2(120.0, 80.0)

var settings_service: SettingsService = null
var current_view_size := DisplayLayout.NATIVE_SIZE
var current_visible_view_size := Vector2(DisplayLayout.NATIVE_SIZE)
var current_presentation_origin := Vector2.ZERO
var _root: Node = null
var _background_canvas: CanvasLayer = null
var _interface_canvas: CanvasLayer = null
var _void_background: ColorRect = null
var _top_bar: ColorRect = null
var _bottom_bar: ColorRect = null
var _world_offset := Vector2.ZERO
var _world_camera: Camera2D = null
var _large_room_camera_active := false
var _aspect_mode := "3:2"
var _content_scale_aspect := Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT
var _windowed_size_before_fixed_aspect := Vector2i.ZERO
var _applying_settings := false
var _presentation_refresh_queued := false


func initialize(root: Node, service: SettingsService) -> void:
	_root = root
	settings_service = service
	if settings_service != null and not settings_service.setting_changed.is_connected(_on_setting_changed):
		settings_service.setting_changed.connect(_on_setting_changed)
	var layout_callback := Callable(root, "_on_display_view_size_changed")
	if root.has_method("_on_display_view_size_changed") and not view_size_changed.is_connected(layout_callback):
		view_size_changed.connect(layout_callback)
	var window := get_window()
	if window != null and window.size.x > 0 and window.size.y > 0 and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		_windowed_size_before_fixed_aspect = window.size
	_build_presentation()
	apply_settings()
	if window != null and not window.size_changed.is_connected(_on_window_size_changed):
		window.size_changed.connect(_on_window_size_changed)


func view_size_value() -> Vector2i:
	return current_view_size


func view_size_as_vector() -> Vector2:
	return Vector2(current_view_size)


func visible_view_size_value() -> Vector2:
	return current_visible_view_size


func presentation_origin_value() -> Vector2:
	return current_presentation_origin


func content_scale_aspect_value() -> int:
	return _content_scale_aspect


func live_window_size_value() -> Vector2:
	return _live_window_size()


func aspect_mode() -> String:
	return _aspect_mode


func world_camera() -> Camera2D:
	return _world_camera


func apply_settings() -> void:
	if _applying_settings:
		return
	_applying_settings = true
	var previous_aspect := _aspect_mode
	var previous_content_scale_aspect := _content_scale_aspect
	var aspect := str(SettingsService.DEFAULTS.get("aspect", "3:2"))
	var pixel_perfect := true
	var fullscreen := false
	if settings_service != null:
		aspect = str(settings_service.get_setting(&"aspect", aspect))
		pixel_perfect = bool(settings_service.get_setting(&"pixel_perfect", true))
		fullscreen = bool(settings_service.get_setting(&"fullscreen", false))
	var window := get_window()
	var windowed := window != null and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED
	var desktop_window_sizing := windowed and not OS.has_feature("web") and not OS.has_feature("mobile")
	if previous_aspect == DisplayLayout.FULL_ASPECT and not DisplayLayout.is_full_aspect(aspect) and desktop_window_sizing:
		_windowed_size_before_fixed_aspect = window.size
	var restore_windowed_size := previous_aspect != DisplayLayout.FULL_ASPECT and DisplayLayout.is_full_aspect(aspect) and desktop_window_sizing and _windowed_size_before_fixed_aspect.x > 0 and _windowed_size_before_fixed_aspect.y > 0
	if restore_windowed_size:
		# FULL derives its logical width from the physical surface. Restore the
		# pre-preset window before measuring that width, otherwise FULL can retain
		# the last fixed preset's narrower desktop window for one entire route.
		window.size = _windowed_size_before_fixed_aspect
	_aspect_mode = aspect
	var next_size := _view_size_for_aspect(aspect)
	var size_changed := next_size != current_view_size
	current_view_size = next_size
	if window != null:
		window.content_scale_size = current_view_size
		window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		# Preserve the authored 160px height whenever the physical surface is at
		# least as wide as the selected frame. On a narrower surface KEEP fits the
		# whole frame and letterboxes it instead of cropping or vertically scaling
		# the menu.
		var preserve_height := _preserve_height_for_surface(_live_window_size(), current_view_size)
		_content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT if preserve_height else Window.CONTENT_SCALE_ASPECT_KEEP
		window.content_scale_aspect = _content_scale_aspect
		window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if pixel_perfect else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		_apply_fullscreen(window, fullscreen)
		_resize_window_width_for_aspect(window, current_view_size, fullscreen)
	RenderingServer.set_default_clear_color(VOID_COLOR)
	var presentation_changed := _sync_presentation()
	_apply_world_offset()
	_applying_settings = false
	var layout_changed := size_changed or presentation_changed or previous_content_scale_aspect != _content_scale_aspect
	if layout_changed:
		view_size_changed.emit(current_view_size)
		# The viewport transform may update one frame after content_scale_size is
		# assigned. Re-read it once settled so an aspect switch cannot leave the
		# UI using the previous frame's center.
		_queue_presentation_refresh()


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
	if window == null or fullscreen or OS.has_feature("web") or OS.has_feature("mobile") or DisplayLayout.is_full_aspect(_aspect_mode):
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
	if _applying_settings:
		_queue_presentation_refresh()
		return
	apply_settings()


func _queue_presentation_refresh() -> void:
	if _presentation_refresh_queued:
		return
	_presentation_refresh_queued = true
	call_deferred("_refresh_after_window_size_changed")


func _refresh_after_window_size_changed() -> void:
	_presentation_refresh_queued = false
	if _applying_settings:
		_queue_presentation_refresh()
		return
	var presentation_changed := _sync_presentation()
	if presentation_changed:
		view_size_changed.emit(current_view_size)


func _build_presentation() -> void:
	if _root == null:
		return
	var authored_background := _root.get_node_or_null("BackgroundCanvas/Background") as CanvasItem
	if authored_background != null:
		authored_background.visible = false
	_background_canvas = _root.get_node_or_null("BackgroundCanvas") as CanvasLayer
	if _background_canvas != null and _void_background == null:
		_void_background = ColorRect.new()
		_void_background.name = "DisplayVoidBackground"
		_void_background.color = VOID_COLOR
		_void_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_void_background.z_index = -20
		_background_canvas.add_child(_void_background)
	var authored_bars := _root.get_node_or_null("InterfaceCanvas/UI/BlackBars") as CanvasItem
	if authored_bars != null:
		authored_bars.visible = false
	var ui := _root.get_node_or_null("InterfaceCanvas/UI") as Node
	_interface_canvas = _root.get_node_or_null("InterfaceCanvas") as CanvasLayer
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


func _sync_presentation() -> bool:
	var size := Vector2(current_view_size)
	var visible_size := _visible_view_size_for_presentation()
	var origin := DisplayLayout.centered_origin(visible_size, size)
	var changed := not current_visible_view_size.is_equal_approx(visible_size) or not current_presentation_origin.is_equal_approx(origin)
	current_visible_view_size = visible_size
	current_presentation_origin = origin
	if _background_canvas != null:
		_background_canvas.offset = Vector2.ZERO
	if _interface_canvas != null:
		_interface_canvas.offset = origin
	if _void_background != null:
		_void_background.position = Vector2.ZERO
		_void_background.size = visible_size
	if _top_bar != null:
		_top_bar.position = Vector2.ZERO
		_top_bar.size = Vector2(size.x, TOP_BAR_HEIGHT)
	if _bottom_bar != null:
		_bottom_bar.position = Vector2(0.0, size.y - BOTTOM_BAR_HEIGHT)
		_bottom_bar.size = Vector2(size.x, BOTTOM_BAR_HEIGHT)
	return changed


func _apply_world_offset() -> void:
	# World geometry is authored in one stable coordinate system. Wide displays
	# are centered by the camera, never by translating Map, Actors, or cached
	# walkability/enemy-spawn data.
	_world_offset = Vector2.ZERO
	if _root != null:
		_root.set("display_world_offset", _world_offset)
	_sync_world_camera()


func set_large_room_camera_active(active: bool) -> void:
	_large_room_camera_active = active
	_sync_world_camera()


func _sync_world_camera() -> void:
	if _root == null:
		return
	_ensure_world_camera()
	if _world_camera == null:
		return
	_world_camera.global_position = WORLD_CENTER
	_world_camera.enabled = not _large_room_camera_active


func _ensure_world_camera() -> void:
	if _world_camera != null or _root == null:
		return
	_world_camera = Camera2D.new()
	_world_camera.name = "DisplayWorldCamera"
	_world_camera.top_level = true
	_world_camera.position_smoothing_enabled = false
	_world_camera.global_position = WORLD_CENTER
	_root.add_child(_world_camera)


func _view_size_for_aspect(aspect: String) -> Vector2i:
	if not DisplayLayout.is_full_aspect(aspect):
		return DisplayLayout.view_size(aspect)
	var live_size := _live_window_size()
	if live_size.y <= 0.0 or live_size.x <= 0.0:
		return DisplayLayout.view_size(aspect)
	var live_width := maxi(DisplayLayout.NATIVE_SIZE.x, roundi(DisplayLayout.NATIVE_SIZE.y * live_size.x / live_size.y))
	return DisplayLayout.view_size(aspect, live_width)


func _preserve_height_for_surface(surface_size: Vector2, content_size: Vector2i) -> bool:
	if surface_size.x <= 0.0 or surface_size.y <= 0.0 or content_size.x <= 0 or content_size.y <= 0:
		return true
	var surface_ratio := surface_size.x / surface_size.y
	var content_ratio := float(content_size.x) / float(content_size.y)
	return surface_ratio >= content_ratio


func _visible_view_size_for_presentation() -> Vector2:
	var content_size := Vector2(current_view_size)
	if _content_scale_aspect != Window.CONTENT_SCALE_ASPECT_KEEP_HEIGHT:
		return content_size
	var visible_size := DisplayLayout.visible_size_for_window(_live_window_size(), content_size, true)
	var viewport := get_viewport()
	if viewport != null:
		var viewport_size := viewport.get_visible_rect().size
		if viewport_size.x >= content_size.x and viewport_size.y >= content_size.y:
			visible_size.x = maxf(visible_size.x, viewport_size.x)
	return visible_size


func _live_window_size() -> Vector2:
	if OS.has_feature("web"):
		# Adaptive web canvases can retain the project override in Window.size
		# while the standalone iPhone page has already resized its CSS viewport.
		# Read the browser viewport when available so FULL follows the actual
		# borderless landscape surface, including home-screen launches.
		var browser_size: Variant = JavaScriptBridge.eval("[window.innerWidth, window.innerHeight]")
		if browser_size is Array and (browser_size as Array).size() >= 2:
			var browser_width := float((browser_size as Array)[0])
			var browser_height := float((browser_size as Array)[1])
			if browser_width > 0.0 and browser_height > 0.0:
				return Vector2(browser_width, browser_height)
	var window := get_window()
	if window != null and window.size.x > 0 and window.size.y > 0:
		return Vector2(window.size)
	var viewport := get_viewport()
	if viewport != null:
		var visible_size := viewport.get_visible_rect().size
		if visible_size.x > 0.0 and visible_size.y > 0.0:
			return visible_size
	return Vector2(DisplayLayout.NATIVE_SIZE)
