extends CanvasLayer
class_name TouchControlsLayer

## Optional touch provider for the shared InputRouter. The overlay measures the
## window through the root viewport's final transform, so control sizes track
## the real screen size at any integer content scale. Whenever letterbox bars
## are large enough (portrait bottom bar, landscape side bars) the controls
## live in the bars instead of covering the game. The root Control is ignored
## while inactive so it never intercepts menu Button taps; gameplay controls
## only become visible for a touch-last device.

const DEVICE_TOUCH := 2
const CONTEXT_GAMEPLAY := 0
const CONTEXT_DIALOGUE := 1
const EMULATED_DEVICE_ID := -1
const MOUSE_FINGER_ID := -2

const BASE_CONTENT_SIZE := Vector2(240.0, 160.0)
const BUTTON_FRACTION := 0.115
const BUTTON_MIN := 18.0
const BUTTON_MAX := 64.0
const STICK_FRACTION := 0.26
const STICK_MIN := 44.0
const STICK_MAX := 140.0
const MARGIN_FRACTION := 0.03

const BUTTON_ORDER := [&"attack", &"roll", &"magic", &"guard", &"target", &"interact"]
const BUTTON_LABELS := {
	&"attack": "ATK", &"roll": "ROLL", &"magic": "MAG",
	&"guard": "GUARD", &"target": "TGT", &"interact": "USE", &"pause": "II",
}

var _touch_root: Control = null
var _stick_base: Panel = null
var _stick_knob: Panel = null
var _button_nodes: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _press_latches: Dictionary = {}
var _finger_actions: Dictionary = {}
var _stick_vector := Vector2.ZERO
var _stick_pointer_id := -1
var _stick_origin := Vector2.ZERO
var _layout: Dictionary = {}
var _last_input_device := -1
var _input_context := CONTEXT_GAMEPLAY
var _controls_visible := false
var _built := false


func _ready() -> void:
	layer = 30


func build() -> void:
	if _built:
		return
	_built = true
	_touch_root = Control.new()
	_touch_root.name = "TouchControlsRoot"
	_touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_touch_root)
	_build_stick_visuals()
	for action in BUTTON_ORDER:
		_build_button(action)
	_build_button(&"pause")
	var window := get_window()
	if window != null and not window.size_changed.is_connected(_update_layout):
		window.size_changed.connect(_update_layout)
	_update_layout()
	_refresh_controls()


func set_input_context(next_context: int) -> void:
	_input_context = next_context
	_refresh_controls()


func set_last_input_device(device: int) -> void:
	_last_input_device = device
	_refresh_controls()


func is_active() -> bool:
	return _controls_visible


func movement_vector() -> Vector2:
	return _stick_vector if _controls_visible else Vector2.ZERO


func action_pressed(action: StringName) -> bool:
	if not _controls_visible:
		return false
	if action == &"ui_accept":
		return bool(_pressed_actions.get(&"interact", false))
	if action == &"cancel" or action == &"ui_cancel":
		return bool(_pressed_actions.get(&"pause", false))
	return bool(_pressed_actions.get(action, false))


func snapshot() -> Dictionary:
	if not _controls_visible:
		return {"active": false, "movement": Vector2.ZERO, "actions": {}, "just_pressed": {}}
	var actions: Dictionary = {}
	for action in [&"attack", &"interact", &"roll", &"magic", &"cancel", &"pause", &"target", &"guard"]:
		actions[action] = action_pressed(action)
	actions[&"ui_accept"] = action_pressed(&"interact")
	actions[&"ui_cancel"] = action_pressed(&"pause")
	var just_pressed: Dictionary = {}
	for action in _press_latches.keys():
		if not bool(_press_latches[action]):
			continue
		just_pressed[action] = true
		if action == &"interact": just_pressed[&"ui_accept"] = true
		if action == &"pause":
			just_pressed[&"cancel"] = true
			just_pressed[&"ui_cancel"] = true
	_press_latches.clear()
	return {"active": true, "movement": _stick_vector, "actions": actions, "just_pressed": just_pressed}


## Testable input-provider seams. Real GUI events use the same methods.
func set_virtual_stick(value: Vector2) -> void:
	if not _controls_visible:
		_stick_vector = Vector2.ZERO
	else:
		_stick_vector = value.limit_length(1.0)
	_update_stick_knob()


func set_button_state(action: StringName, pressed: bool) -> void:
	if not _controls_visible:
		if not pressed:
			_pressed_actions[action] = false
			_update_button_visual(action)
		return
	_pressed_actions[action] = pressed
	if pressed:
		_press_latches[action] = true
	_update_button_visual(action)


## Pure layout math, kept separate so tests can assert portrait/landscape
## behavior without a real device. All returned rects are in content space:
## the game occupies Rect2(Vector2.ZERO, content_size) and the letterbox bars
## are the area between that rect and window_rect.
func _compute_layout(window_logical: Vector2, content_size: Vector2) -> Dictionary:
	var content_pos := (window_logical - content_size) * 0.5
	var window_rect := Rect2(-content_pos, window_logical)
	var unit := minf(window_logical.x, window_logical.y)
	var margin := clampf(unit * MARGIN_FRACTION, 2.0, 24.0)
	var button := clampf(unit * BUTTON_FRACTION, BUTTON_MIN, BUTTON_MAX)
	var gap := maxf(2.0, margin * 0.75)
	var stick_diameter := clampf(unit * STICK_FRACTION, STICK_MIN, STICK_MAX)
	var portrait := window_logical.y >= window_logical.x
	var bar_bottom := window_rect.end.y - content_size.y
	var bar_side := -window_rect.position.x
	var stick_zone := Rect2()
	var stick_home := Vector2.ZERO
	var cluster_origin := Vector2.ZERO
	var columns := 3
	if portrait and bar_bottom >= stick_diameter * 0.6:
		# Portrait: generous bottom bar holds the stick (left) and the button
		# cluster (right) without covering the game.
		stick_zone = Rect2(window_rect.position.x + margin, content_size.y, window_logical.x * 0.5 - margin * 1.5, bar_bottom - margin * 0.5)
		columns = 3
		var cluster_w := columns * button + float(columns - 1) * gap
		var cluster_h := 2.0 * button + gap
		cluster_origin = Vector2(window_rect.end.x - margin - cluster_w, window_rect.end.y - margin - cluster_h)
		stick_home = stick_zone.position + Vector2(stick_zone.size.x * 0.5, stick_zone.size.y * 0.55)
	elif not portrait and bar_side >= stick_diameter * 0.7:
		# Landscape: side bars are wide enough for a floating stick (left) and
		# a two-column button cluster (right).
		stick_zone = Rect2(window_rect.position.x + margin * 0.5, window_rect.position.y + margin, bar_side - margin, window_logical.y - margin * 2.0)
		columns = 2
		var cluster_w := columns * button + gap
		var cluster_h := 3.0 * button + 2.0 * gap
		var right_bar: float = window_rect.end.x - content_size.x
		cluster_origin = Vector2(content_size.x + (right_bar - cluster_w) * 0.5, window_rect.position.y + (window_logical.y - cluster_h) * 0.5)
		stick_home = stick_zone.position + stick_zone.size * 0.5
	else:
		# No usable bars (near-perfect fit): overlay the bottom corners.
		stick_zone = Rect2(window_rect.position.x + margin, window_rect.end.y - margin - stick_diameter, minf(window_logical.x * 0.45, stick_diameter * 1.8), stick_diameter)
		columns = 3
		var cluster_w := columns * button + float(columns - 1) * gap
		var cluster_h := 2.0 * button + gap
		cluster_origin = Vector2(window_rect.end.x - margin - cluster_w, window_rect.end.y - margin - cluster_h)
		stick_home = stick_zone.position + stick_zone.size * 0.5
	var buttons: Dictionary = {}
	for index in BUTTON_ORDER.size():
		var col := index % columns
		var row := index / columns
		buttons[BUTTON_ORDER[index]] = Rect2(cluster_origin + Vector2(float(col) * (button + gap), float(row) * (button + gap)), Vector2(button, button))
	var pause_side := clampf(unit * 0.10, 14.0, 44.0)
	var pause := Rect2(Vector2(window_rect.end.x - margin - pause_side, window_rect.position.y + margin), Vector2(pause_side, pause_side * 0.8))
	return {
		"window_rect": window_rect,
		"margin": margin,
		"button_size": button,
		"stick_zone": stick_zone,
		"stick_home": stick_home,
		"stick_radius": stick_diameter * 0.42,
		"stick_diameter": stick_diameter,
		"buttons": buttons,
		"pause": pause,
	}


func _build_stick_visuals() -> void:
	_stick_base = Panel.new()
	_stick_base.name = "StickBase"
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.15, 0.62), Color(0.52, 0.58, 0.72, 0.78), 2))
	_touch_root.add_child(_stick_base)
	_stick_knob = Panel.new()
	_stick_knob.name = "Knob"
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.82, 0.86, 1.0, 0.82), Color(1.0, 1.0, 1.0, 0.92), 2))
	_touch_root.add_child(_stick_knob)


func _build_button(action: StringName) -> void:
	var button := Panel.new()
	button.name = "Touch_%s" % String(action).capitalize()
	button.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_touch_root.add_child(button)
	var label := Label.new()
	label.text = String(BUTTON_LABELS.get(action, "?"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 0.94))
	button.add_child(label)
	_button_nodes[action] = button
	_pressed_actions[action] = false
	_update_button_visual(action)


func _panel_style(background: Color, border: Color, width: int, radius: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style


func _input(event: InputEvent) -> void:
	if not _controls_visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.device == EMULATED_DEVICE_ID:
			return
		# The device tracker classifies touches on its own; this fallback keeps
		# the controls discoverable on browsers with delayed touch reporting.
		if _last_input_device != DEVICE_TOUCH:
			set_last_input_device(DEVICE_TOUCH)
		if touch.pressed:
			_finger_down(touch.index, touch.position)
		else:
			_finger_up(touch.index)
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.device != EMULATED_DEVICE_ID:
			_finger_moved(drag.index, drag.position)
		return
	if event is InputEventMouseButton:
		# Real-mouse path so the overlay can be tested on desktop; emulated
		# echoes of real touches are skipped to avoid double state changes.
		var mouse_button := event as InputEventMouseButton
		if mouse_button.device == EMULATED_DEVICE_ID or mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_finger_down(MOUSE_FINGER_ID, mouse_button.position)
		else:
			_finger_up(MOUSE_FINGER_ID)
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.device != EMULATED_DEVICE_ID:
			_finger_moved(MOUSE_FINGER_ID, motion.position)


func _finger_down(finger_id: int, position: Vector2) -> void:
	var buttons: Dictionary = _layout.get("buttons", {})
	for action in buttons:
		if (buttons[action] as Rect2).has_point(position):
			_finger_actions[finger_id] = action
			set_button_state(action, true)
			return
	var pause: Rect2 = _layout.get("pause", Rect2())
	if pause.has_point(position):
		_finger_actions[finger_id] = &"pause"
		set_button_state(&"pause", true)
		return
	var zone: Rect2 = _layout.get("stick_zone", Rect2())
	if _stick_pointer_id < 0 and zone.has_point(position):
		_stick_pointer_id = finger_id
		_stick_origin = _clamped_stick_origin(position)
		set_virtual_stick(_stick_value_from_position(position))
		_update_stick_visuals()


func _finger_moved(finger_id: int, position: Vector2) -> void:
	if finger_id == _stick_pointer_id:
		set_virtual_stick(_stick_value_from_position(position))
		return
	if _finger_actions.has(finger_id):
		var action: StringName = _finger_actions[finger_id]
		var rect := _button_rect(action)
		if not rect.grow(3.0).has_point(position):
			_finger_actions.erase(finger_id)
			set_button_state(action, false)


func _finger_up(finger_id: int) -> void:
	if finger_id == _stick_pointer_id:
		_release_stick()
	if _finger_actions.has(finger_id):
		var action: StringName = _finger_actions[finger_id]
		_finger_actions.erase(finger_id)
		set_button_state(action, false)


func _button_rect(action: StringName) -> Rect2:
	if action == &"pause":
		return _layout.get("pause", Rect2())
	var buttons: Dictionary = _layout.get("buttons", {})
	return buttons.get(action, Rect2())


func _clamped_stick_origin(position: Vector2) -> Vector2:
	var radius := float(_layout.get("stick_radius", 19.0))
	var window_rect: Rect2 = _layout.get("window_rect", Rect2(Vector2.ZERO, BASE_CONTENT_SIZE))
	var inner := window_rect.grow(-margin_edge() - radius * 0.35)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return position
	return position.clamp(inner.position, inner.end)


func margin_edge() -> float:
	return float(_layout.get("margin", 4.0))


func _stick_value_from_position(position: Vector2) -> Vector2:
	var radius := float(_layout.get("stick_radius", 19.0))
	return (position - _stick_origin).limit_length(radius) / radius


func _release_stick() -> void:
	_stick_pointer_id = -1
	_stick_origin = _layout.get("stick_home", _stick_origin)
	_stick_vector = Vector2.ZERO
	_update_stick_visuals()


func _update_layout() -> void:
	var window := get_window()
	if window == null:
		return
	var scale := window.get_final_transform().get_scale().x
	if scale < 0.001:
		scale = 1.0
	var window_logical := Vector2(window.size) / scale
	_layout = _compute_layout(window_logical, _content_size())
	if _stick_pointer_id < 0:
		_stick_origin = _layout["stick_home"]
	_apply_layout()


func _content_size() -> Vector2:
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", int(BASE_CONTENT_SIZE.x))),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", int(BASE_CONTENT_SIZE.y))))


func _apply_layout() -> void:
	if not _built or _layout.is_empty():
		return
	var diameter := float(_layout["stick_diameter"])
	_stick_base.size = Vector2(diameter, diameter)
	var knob_side := diameter * 0.4
	_stick_knob.size = Vector2(knob_side, knob_side)
	_stick_base.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.15, 0.62), Color(0.52, 0.58, 0.72, 0.78), 2, int(diameter * 0.5)))
	_update_stick_visuals()
	var buttons: Dictionary = _layout["buttons"]
	for action in _button_nodes:
		var node := _button_nodes[action] as Control
		node.position = _button_rect(action).position
		node.size = _button_rect(action).size
		var label := node.get_child(0) as Label
		if label != null:
			label.add_theme_font_size_override("font_size", int(clampf(node.size.y * 0.32, 6.0, 16.0)))


func _update_stick_visuals() -> void:
	if _stick_base == null or _stick_knob == null:
		return
	_stick_base.position = _stick_origin - _stick_base.size * 0.5
	_update_stick_knob()


func _update_stick_knob() -> void:
	if _stick_knob == null:
		return
	var radius := float(_layout.get("stick_radius", 19.0))
	_stick_knob.position = _stick_origin - _stick_knob.size * 0.5 + _stick_vector * radius


func _update_button_visual(action: StringName) -> void:
	if not _button_nodes.has(action):
		return
	var node := _button_nodes[action] as Panel
	var pressed := bool(_pressed_actions.get(action, false))
	var diameter := float(_layout.get("button_size", 20.0))
	var corner := int(clampf(diameter * 0.18, 2.0, 8.0))
	if pressed:
		node.add_theme_stylebox_override("panel", _panel_style(Color(0.38, 0.42, 0.58, 0.95), Color.WHITE, 2, corner))
	else:
		node.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.08, 0.78), Color(0.46, 0.52, 0.66, 0.92), 2, corner))


func _refresh_controls() -> void:
	_controls_visible = _last_input_device == DEVICE_TOUCH and (_input_context == CONTEXT_GAMEPLAY or _input_context == CONTEXT_DIALOGUE)
	if _touch_root != null:
		# InputDeviceTracker receives screen touches independently through _input,
		# so the inactive overlay does not need to remain in the GUI hit-test path.
		# Leaving it as PASS makes it the topmost Control on mobile and can swallow
		# the emulated mouse press that should activate title/menu Buttons.
		_touch_root.mouse_filter = Control.MOUSE_FILTER_PASS if _controls_visible else Control.MOUSE_FILTER_IGNORE
	if not _controls_visible:
		_stick_vector = Vector2.ZERO
		_stick_pointer_id = -1
		_finger_actions.clear()
		_pressed_actions.clear()
		_press_latches.clear()
		for action in _button_nodes:
			_update_button_visual(action)
	if not _built:
		return
	if _controls_visible:
		_update_layout()
	if _stick_base != null:
		_stick_base.visible = _controls_visible
		_stick_knob.visible = _controls_visible
	for action in _button_nodes:
		(_button_nodes[action] as Control).visible = _controls_visible
