extends CanvasLayer
class_name TouchControlsLayer

## Optional touch provider for the shared InputRouter. The root Control stays
## pass-through while inactive so a first touch can switch the device tracker;
## gameplay controls only become visible for a touch-last device.

const DEVICE_TOUCH := 2
const CONTEXT_GAMEPLAY := 0
const CONTEXT_DIALOGUE := 1
const STICK_RADIUS := 19.0
const STICK_KNOB_RADIUS := 5.0

var _touch_root: Control = null
var _stick_area: Control = null
var _stick_base: Panel = null
var _stick_knob: Panel = null
var _button_nodes: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _press_latches: Dictionary = {}
var _stick_vector := Vector2.ZERO
var _stick_pointer_id := -1
var _mouse_stick_active := false
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
	_touch_root.gui_input.connect(_on_root_gui_input)
	add_child(_touch_root)
	_build_stick()
	var button_specs := [
		{&"action": &"attack", &"label": "ATK", &"position": Vector2(171, 103)},
		{&"action": &"roll", &"label": "ROLL", &"position": Vector2(194, 103)},
		{&"action": &"magic", &"label": "MAG", &"position": Vector2(217, 103)},
		{&"action": &"guard", &"label": "GUARD", &"position": Vector2(171, 121)},
		{&"action": &"target", &"label": "TGT", &"position": Vector2(194, 121)},
		{&"action": &"interact", &"label": "USE", &"position": Vector2(217, 121)},
		{&"action": &"pause", &"label": "II", &"position": Vector2(217, 4), &"size": Vector2(18, 13)},
	]
	for spec in button_specs:
		_build_button(spec)
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
		return
	_pressed_actions[action] = pressed
	if pressed:
		_press_latches[action] = true


func _build_stick() -> void:
	_stick_area = Control.new()
	_stick_area.name = "VirtualStick"
	_stick_area.position = Vector2(7, 99)
	_stick_area.size = Vector2(55, 55)
	_stick_area.mouse_filter = Control.MOUSE_FILTER_STOP
	_stick_area.gui_input.connect(_on_stick_gui_input)
	_touch_root.add_child(_stick_area)
	_stick_base = Panel.new()
	_stick_base.position = Vector2(4, 4)
	_stick_base.size = Vector2(47, 47)
	_stick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_base.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.15, 0.62), Color(0.52, 0.58, 0.72, 0.78), 2))
	_stick_area.add_child(_stick_base)
	_stick_knob = Panel.new()
	_stick_knob.name = "Knob"
	_stick_knob.size = Vector2(STICK_KNOB_RADIUS * 2.0, STICK_KNOB_RADIUS * 2.0)
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.82, 0.86, 1.0, 0.82), Color(1.0, 1.0, 1.0, 0.92), 2))
	_stick_area.add_child(_stick_knob)
	_update_stick_knob()


func _build_button(spec: Dictionary) -> void:
	var action: StringName = spec[&"action"]
	var button := Button.new()
	button.name = "Touch_%s" % String(action).capitalize()
	button.position = spec[&"position"]
	button.size = spec.get(&"size", Vector2(21, 15))
	button.text = spec[&"label"]
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.clip_text = true
	button.add_theme_font_size_override("font_size", 6)
	button.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 0.94))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.04, 0.05, 0.08, 0.78), Color(0.46, 0.52, 0.66, 0.92), 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.18, 0.21, 0.32, 0.9), Color.WHITE, 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.38, 0.42, 0.58, 0.95), Color.WHITE, 1))
	button.button_down.connect(_on_button_down.bind(action))
	button.button_up.connect(_on_button_up.bind(action))
	button.mouse_exited.connect(_on_button_exited.bind(action))
	_touch_root.add_child(button)
	_button_nodes[action] = button
	_pressed_actions[action] = false


func _panel_style(background: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(2)
	return style


func _on_root_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		# InputDeviceTracker normally performs this transition. Keeping the root
		# listener as a pass-through fallback makes the first touch reveal the
		# controls even on browser/device combinations with delayed reporting.
		set_last_input_device(DEVICE_TOUCH)


func _on_stick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _stick_pointer_id < 0:
			_stick_pointer_id = touch.index
			set_virtual_stick(_stick_value_from_position(touch.position))
		elif not touch.pressed and touch.index == _stick_pointer_id:
			_release_stick()
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_pointer_id:
			set_virtual_stick(_stick_value_from_position(drag.position))
		return
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_mouse_stick_active = true
			set_virtual_stick(_stick_value_from_position(mouse_button.position))
		else:
			_release_stick()
		return
	if event is InputEventMouseMotion and _mouse_stick_active:
		set_virtual_stick(_stick_value_from_position((event as InputEventMouseMotion).position))


func _stick_value_from_position(position: Vector2) -> Vector2:
	var center := _stick_area.size * 0.5
	return (position - center).limit_length(STICK_RADIUS) / STICK_RADIUS


func _release_stick() -> void:
	_stick_pointer_id = -1
	_mouse_stick_active = false
	set_virtual_stick(Vector2.ZERO)


func _update_stick_knob() -> void:
	if _stick_knob == null or _stick_area == null:
		return
	var center := _stick_area.size * 0.5
	_stick_knob.position = center - _stick_knob.size * 0.5 + _stick_vector * STICK_RADIUS


func _on_button_down(action: StringName) -> void:
	set_button_state(action, true)


func _on_button_up(action: StringName) -> void:
	set_button_state(action, false)


func _on_button_exited(action: StringName) -> void:
	if bool(_pressed_actions.get(action, false)):
		set_button_state(action, false)


func _refresh_controls() -> void:
	_controls_visible = _last_input_device == DEVICE_TOUCH and (_input_context == CONTEXT_GAMEPLAY or _input_context == CONTEXT_DIALOGUE)
	if not _controls_visible:
		_stick_vector = Vector2.ZERO
		_stick_pointer_id = -1
		_mouse_stick_active = false
		_pressed_actions.clear()
		_press_latches.clear()
	if not _built:
		return
	if _stick_area != null:
		_stick_area.visible = _controls_visible
	for action in _button_nodes:
		(_button_nodes[action] as Control).visible = _controls_visible
