extends CanvasLayer
class_name TouchControlsLayer

## Optional touch provider for the shared InputRouter. Controls are laid out in
## the logical viewport used by the CanvasLayer, which keeps their hit regions
## aligned with InputEventScreenTouch positions at every stretch scale. Menu
## and dialogue touches are handled separately from the gameplay overlay so a
## touch-last device can use the whole UI without showing gameplay controls on
## top of it.

const DEVICE_TOUCH := 2
const CONTEXT_GAMEPLAY := 0
const CONTEXT_DIALOGUE := 1
const CONTEXT_HUB := 2
const CONTEXT_MENU := 3
const CONTEXT_PAUSE := 4
const EMULATED_DEVICE_ID := -1
const MOUSE_FINGER_ID := -2

const BASE_CONTENT_SIZE := Vector2(240.0, 160.0)
const BUTTON_FRACTION := 0.15
const BUTTON_MIN := 20.0
const BUTTON_MAX := 80.0
const STICK_FRACTION := 0.30
const STICK_MIN := 50.0
const STICK_MAX := 160.0
const MARGIN_FRACTION := 0.03
const TAP_INTERACT_ACTION := &"tap_interact"
const MENU_SCROLL_ROW_PX := 10.0
const MENU_SCROLL_DRAG_PX := 6.0
const MENU_ACCEPT_MAX_HOLD_MS := 800

const BUTTON_ORDER := [&"attack", &"roll", &"magic", &"guard", &"target", &"interact"]
const BUTTON_GRID_POSITIONS := {
	&"magic": Vector2i(1, 0), &"attack": Vector2i(0, 1), &"interact": Vector2i(2, 1),
	&"guard": Vector2i(0, 2), &"roll": Vector2i(1, 2), &"target": Vector2i(2, 2),
}
const BUTTON_LABELS := {
	&"attack": "ATK", &"roll": "ROLL", &"magic": "MAG",
	&"guard": "GUARD", &"target": "TGT", &"interact": "USE", &"pause": "II", &"cancel": "CANCEL",
}

var _touch_root: Control = null
var _stick_base: Panel = null
var _stick_knob: Panel = null
var _button_nodes: Dictionary = {}
var _pressed_actions: Dictionary = {}
var _press_latches: Dictionary = {}
var _finger_actions: Dictionary = {}
var _tap_interact_origins: Dictionary = {}
var _menu_touch_buttons: Dictionary = {}
var _menu_button_origins: Dictionary = {}
var _menu_accept_fingers: Dictionary = {}
var _menu_accept_latch := false
var _menu_scroll_fingers: Dictionary = {}
var _menu_scroll_edges: Array = []
var _target_toggle_active := false
var _stick_vector := Vector2.ZERO
var _stick_pointer_id := -1
var _stick_origin := Vector2.ZERO
var _layout: Dictionary = {}
var _last_input_device := -1
var _input_context := CONTEXT_GAMEPLAY
var _controls_visible := false
var _touch_input_enabled := false
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
	_build_button(&"cancel")
	var window := get_window()
	if window != null and not window.size_changed.is_connected(_update_layout):
		window.size_changed.connect(_update_layout)
	_update_layout()
	_refresh_controls()


func set_input_context(next_context: int) -> void:
	if _input_context != next_context:
		_clear_transient_input()
	_input_context = next_context
	if _built:
		# The hub cancel control is nested inside HubOverlay, so refresh its
		# position whenever a menu becomes visible or closes.
		_update_layout()
	_refresh_controls()


func set_last_input_device(device: int) -> void:
	if _last_input_device != device:
		_clear_transient_input()
	_last_input_device = device
	_refresh_controls()


func is_active() -> bool:
	return _touch_input_enabled


func refresh_layout() -> void:
	if _built:
		_update_layout()


func movement_vector() -> Vector2:
	return _stick_vector if _controls_visible else Vector2.ZERO


func action_pressed(action: StringName) -> bool:
	if action == &"menu_confirm":
		return action_pressed(&"interact")
	if action == &"menu_back":
		return action_pressed(&"cancel")
	if action == &"ui_accept":
		return action_pressed(&"interact")
	if action == &"interact":
		return bool(_pressed_actions.get(&"interact", false)) or not _menu_accept_fingers.is_empty()
	if action == &"cancel" or action == &"ui_cancel":
		return bool(_pressed_actions.get(&"cancel", false)) or (bool(_pressed_actions.get(&"pause", false)) if _controls_visible else false)
	if not _controls_visible:
		return false
	return bool(_pressed_actions.get(action, false))


func snapshot() -> Dictionary:
	if not _touch_input_enabled:
		return {"active": false, "movement": Vector2.ZERO, "actions": {}, "just_pressed": {}}
	_clear_stale_menu_accepts()
	var actions: Dictionary = {}
	for action in [&"attack", &"interact", &"roll", &"magic", &"cancel", &"pause", &"target", &"guard"]:
		actions[action] = action_pressed(action)
	actions[&"ui_accept"] = action_pressed(&"interact")
	actions[&"ui_cancel"] = action_pressed(&"cancel")
	var just_pressed: Dictionary = {}
	for action in _press_latches.keys():
		if not bool(_press_latches[action]):
			continue
		just_pressed[action] = true
		if action == &"interact": just_pressed[&"ui_accept"] = true
		if action == &"cancel" or action == &"pause":
			just_pressed[&"cancel"] = true
			just_pressed[&"ui_cancel"] = true
	if _menu_accept_latch:
		just_pressed[&"interact"] = true
		just_pressed[&"ui_accept"] = true
	for direction in _menu_scroll_edges:
		just_pressed[direction] = true
	_menu_scroll_edges.clear()
	_press_latches.clear()
	_menu_accept_latch = false
	return {"active": true, "movement": _stick_vector, "actions": actions, "just_pressed": just_pressed}


## Testable input-provider seams. Real GUI events use the same methods.
func set_virtual_stick(value: Vector2) -> void:
	if not _controls_visible:
		_stick_vector = Vector2.ZERO
	else:
		_stick_vector = value.limit_length(1.0)
	_update_stick_knob()


func set_button_state(action: StringName, pressed: bool) -> void:
	var menu_cancel_enabled := action == &"cancel" and _touch_input_enabled
	if not _controls_visible and not menu_cancel_enabled:
		if not pressed:
			_pressed_actions[action] = false
			_update_button_visual(action)
		return
	_pressed_actions[action] = pressed
	if pressed:
		_press_latches[action] = true
	_update_button_visual(action)


## Pure layout math, kept separate so tests can assert behavior without a real
## device. All returned rects are in the logical viewport/canvas space. The
## physical window scale and any letterbox bars are applied outside this
## CanvasLayer by Godot, so they must not be included in these coordinates.
func _compute_layout(window_logical: Vector2, content_size: Vector2) -> Dictionary:
	var viewport_size := Vector2(maxf(window_logical.x, content_size.x), maxf(window_logical.y, content_size.y))
	var window_rect := Rect2(Vector2.ZERO, viewport_size)
	var unit := minf(viewport_size.x, viewport_size.y)
	var margin := clampf(unit * MARGIN_FRACTION, 2.0, 8.0)
	var button := clampf(unit * BUTTON_FRACTION, BUTTON_MIN, BUTTON_MAX)
	var gap := maxf(5.0, button * 0.30)
	var stick_diameter := clampf(unit * STICK_FRACTION, STICK_MIN, STICK_MAX)
	# Keep the stick in the lower-left corner and the action cluster in the
	# lower-right corner. These are deliberately inside the viewport: the
	# stretch transform maps both the visuals and touch positions together.
	var stick_width := minf(maxf(stick_diameter * 1.4, 60.0), viewport_size.x * 0.40)
	var stick_zone := Rect2(Vector2(margin, viewport_size.y - margin - stick_diameter), Vector2(maxf(stick_width, stick_diameter), stick_diameter))
	var stick_home := stick_zone.position + stick_zone.size * 0.5
	var cluster_origin := Vector2.ZERO
	var columns := 3
	var cluster_w := columns * button + float(columns - 1) * gap
	var cluster_h := 3.0 * button + 2.0 * gap
	cluster_origin = Vector2(maxf(margin, viewport_size.x - margin - cluster_w), maxf(margin, viewport_size.y - margin - cluster_h))
	var buttons: Dictionary = {}
	for action in BUTTON_ORDER:
		var grid_position: Vector2i = BUTTON_GRID_POSITIONS[action]
		buttons[action] = Rect2(cluster_origin + Vector2(float(grid_position.x) * (button + gap), float(grid_position.y) * (button + gap)), Vector2(button, button))
	var pause_side := clampf(unit * 0.10, 14.0, 44.0)
	var pause := Rect2(Vector2(maxf(margin, viewport_size.x - margin - pause_side), margin), Vector2(pause_side, pause_side * 0.8))
	var cancel_width := clampf(button * 2.5, 42.0, 96.0)
	var cancel_position := Vector2(maxf(margin, viewport_size.x - margin - cancel_width), maxf(margin, viewport_size.y - margin - button))
	var cancel := Rect2(cancel_position, Vector2(cancel_width, button))
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
		"cancel": cancel,
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
			_finger_up(touch.index, touch.position, not touch.canceled)
		return
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.device != EMULATED_DEVICE_ID:
			if _last_input_device != DEVICE_TOUCH:
				set_last_input_device(DEVICE_TOUCH)
			_finger_moved(drag.index, drag.position)
		return
	if not _touch_input_enabled:
		return
	if event is InputEventMouseButton:
		# Real-mouse path so the overlay can be tested on desktop; emulated
		# echoes of real touches are skipped to avoid double state changes.
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.device == EMULATED_DEVICE_ID:
			# A browser may provide only the emulated mouse stream. Bootstrap can
			# already know that the device is touch-capable, so accept that stream
			# only when it is not a duplicate of an active screen touch.
			if _last_input_device != DEVICE_TOUCH or _has_real_touch_capture():
				return
		elif _is_menu_context():
			# Let native Godot Buttons receive an actual desktop mouse click.
			return
		if mouse_button.pressed:
			_finger_down(MOUSE_FINGER_ID, mouse_button.position)
		else:
			_finger_up(MOUSE_FINGER_ID, mouse_button.position)
		return
	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if motion.device != EMULATED_DEVICE_ID:
			_finger_moved(MOUSE_FINGER_ID, motion.position)


func _finger_down(finger_id: int, position: Vector2) -> void:
	if not _touch_input_enabled:
		return
	# Menu and dialogue input is single-finger. A new touch supersedes any ghost
	# left by a missed touchend, which would otherwise hold interact/accept
	# pressed and permanently suppress the rising edge that advances dialogue
	# and menus (pausing and reopening cleared it by wiping this state).
	if _is_menu_context() or _input_context == CONTEXT_DIALOGUE:
		_menu_accept_fingers.clear()
		_menu_accept_latch = false
		_finger_actions.clear()
		_tap_interact_origins.clear()
		_menu_scroll_fingers.clear()
		_pressed_actions.clear()
		_press_latches.clear()
		_target_toggle_active = false
		for action in _button_nodes:
			_update_button_visual(action)
		_update_touch_capture_filter()
	var cancel: Rect2 = _layout.get("cancel", Rect2())
	if _is_menu_context():
		var menu_button := _menu_button_at(position)
		if menu_button != null:
			_menu_touch_buttons[finger_id] = menu_button
			_menu_button_origins[finger_id] = position
			_update_touch_capture_filter()
			return
		# A disabled native button still owns its visual hit area. Reserve that
		# area so it cannot accidentally fall through to the overlapping cancel
		# control at the bottom-right of the compact hub panel.
		if _menu_button_at(position, true) != null:
			return
		if cancel.has_point(position) and _cancel_control_visible():
			_finger_actions[finger_id] = &"cancel"
			set_button_state(&"cancel", true)
			_update_touch_capture_filter()
			return
		# Hub pages expose their actionable controls as native Buttons. A blank
		# touch stays inert unless it drags, which scrolls the visible list.
		if _input_context == CONTEXT_HUB or _input_context == CONTEXT_PAUSE:
			_menu_scroll_fingers[finger_id] = {"accum": 0.0, "last_y": position.y}
			return
		_menu_accept_fingers[finger_id] = Time.get_ticks_msec()
		_menu_accept_latch = true
		_update_touch_capture_filter()
		return
	if _input_context == CONTEXT_DIALOGUE:
		var dialogue_button := _menu_button_at(position)
		if dialogue_button != null:
			_menu_touch_buttons[finger_id] = dialogue_button
			_update_touch_capture_filter()
			return
		if _menu_button_at(position, true) != null:
			return
		if cancel.has_point(position) and _cancel_control_visible():
			_finger_actions[finger_id] = &"cancel"
			set_button_state(&"cancel", true)
			_update_touch_capture_filter()
			return
		# The continue prompt is a Sprite2D rather than a native Button. Treat
		# the visible dialogue panel as a touch target so the flame lesson can
		# advance even when the floating gameplay controls overlap the prompt.
		var dialogue_rect := _dialogue_touch_rect()
		if dialogue_rect.has_point(position):
			_menu_accept_fingers[finger_id] = Time.get_ticks_msec()
			_menu_accept_latch = true
			_update_touch_capture_filter()
			return
		# Dialogue uses the same tap-anywhere behavior as a controller's
		# interact/accept button when the tap is not on a gameplay control.
		var dialogue_buttons: Dictionary = _layout.get("buttons", {})
		var dialogue_pause: Rect2 = _layout.get("pause", Rect2())
		if not _rect_dictionary_contains(dialogue_buttons, position) and not dialogue_pause.has_point(position):
			_menu_accept_fingers[finger_id] = Time.get_ticks_msec()
			_menu_accept_latch = true
			_update_touch_capture_filter()
			return
	var buttons: Dictionary = _layout.get("buttons", {})
	for action in buttons:
		if (buttons[action] as Rect2).has_point(position):
			_finger_actions[finger_id] = action
			if action == &"target":
				_target_toggle_active = not _target_toggle_active
				set_button_state(&"target", _target_toggle_active)
			else:
				set_button_state(action, true)
			_update_touch_capture_filter()
			return
	var pause: Rect2 = _layout.get("pause", Rect2())
	if pause.has_point(position):
		_finger_actions[finger_id] = &"pause"
		set_button_state(&"pause", true)
		_update_touch_capture_filter()
		return
	var zone: Rect2 = _layout.get("stick_zone", Rect2())
	if _stick_pointer_id < 0 and zone.has_point(position):
		_stick_pointer_id = finger_id
		_stick_origin = _clamped_stick_origin(position)
		set_virtual_stick(_stick_value_from_position(position))
		_update_stick_visuals()
		_update_touch_capture_filter()
		return
	# A touch on the world is the direct form of the TAP prompt. Keep the
	# existing USE button for players who prefer an explicit action control, but
	# let a tap on an interactable (or empty) world position use the same input
	# path without requiring a second button press.
	if _input_context == CONTEXT_GAMEPLAY:
		_finger_actions[finger_id] = TAP_INTERACT_ACTION
		_tap_interact_origins[finger_id] = position
		set_button_state(&"interact", true)
		_update_touch_capture_filter()


func _finger_moved(finger_id: int, position: Vector2) -> void:
	if _menu_touch_buttons.has(finger_id):
		if _is_scrollable_menu() and _menu_button_origins.has(finger_id):
			var origin := _menu_button_origins[finger_id] as Vector2
			if absf(position.y - origin.y) >= MENU_SCROLL_DRAG_PX:
				_menu_touch_buttons.erase(finger_id)
				_menu_button_origins.erase(finger_id)
				_menu_scroll_fingers[finger_id] = {"accum": position.y - origin.y, "last_y": position.y}
				_update_touch_capture_filter()
				return
		var menu_button := _menu_touch_buttons[finger_id] as BaseButton
		if menu_button == null or not is_instance_valid(menu_button) or not menu_button.get_global_rect().grow(3.0).has_point(position):
			_menu_touch_buttons.erase(finger_id)
			_menu_button_origins.erase(finger_id)
			_update_touch_capture_filter()
		return
	if _menu_scroll_fingers.has(finger_id):
		_accumulate_menu_scroll(finger_id, position.y)
		return
	if _menu_accept_fingers.has(finger_id):
		return
	if _finger_actions.has(finger_id):
		var action: StringName = _finger_actions[finger_id]
		if action == TAP_INTERACT_ACTION:
			var origin := _tap_interact_origins.get(finger_id, position) as Vector2
			var threshold := maxf(float(_layout.get("button_size", 20.0)) * 0.35, 6.0)
			if origin.distance_to(position) > threshold:
				_finger_actions.erase(finger_id)
				_tap_interact_origins.erase(finger_id)
				set_button_state(&"interact", false)
				_update_touch_capture_filter()
			return
		var rect := _button_rect(action)
		if not rect.grow(3.0).has_point(position):
			_finger_actions.erase(finger_id)
			if action != &"target": set_button_state(action, false)
			_update_touch_capture_filter()
		return
	if not _controls_visible:
		return
	if finger_id == _stick_pointer_id:
		set_virtual_stick(_stick_value_from_position(position))
		return


func _finger_up(finger_id: int, position: Vector2 = Vector2.ZERO, activate_menu_button: bool = true) -> void:
	if _menu_touch_buttons.has(finger_id):
		var menu_button := _menu_touch_buttons[finger_id] as BaseButton
		_menu_touch_buttons.erase(finger_id)
		_menu_button_origins.erase(finger_id)
		if activate_menu_button and menu_button != null and is_instance_valid(menu_button) and not menu_button.disabled and menu_button.is_visible_in_tree() and menu_button.get_global_rect().grow(3.0).has_point(position):
			menu_button.pressed.emit()
		_update_touch_capture_filter()
		return
	if _menu_scroll_fingers.has(finger_id):
		_menu_scroll_fingers.erase(finger_id)
		_update_touch_capture_filter()
		return
	if _menu_accept_fingers.has(finger_id):
		_menu_accept_fingers.erase(finger_id)
		_update_touch_capture_filter()
		return
	if finger_id == _stick_pointer_id:
		_release_stick()
	if _finger_actions.has(finger_id):
		var action: StringName = _finger_actions[finger_id]
		_finger_actions.erase(finger_id)
		_tap_interact_origins.erase(finger_id)
		if action == TAP_INTERACT_ACTION:
			set_button_state(&"interact", false)
		elif action != &"target":
			set_button_state(action, false)
	_update_touch_capture_filter()


func _clear_stale_menu_accepts() -> void:
	if _menu_accept_fingers.is_empty():
		return
	var now := Time.get_ticks_msec()
	for finger_id: int in _menu_accept_fingers.keys():
		var down_time := int(_menu_accept_fingers[finger_id])
		if now - down_time > MENU_ACCEPT_MAX_HOLD_MS:
			_menu_accept_fingers.erase(finger_id)
			if _menu_accept_fingers.is_empty():
				_menu_accept_latch = false
			_update_touch_capture_filter()


func _accumulate_menu_scroll(finger_id: int, y: float) -> void:
	var data: Dictionary = _menu_scroll_fingers[finger_id]
	var last_y := float(data.get("last_y", y))
	var accum := float(data.get("accum", 0.0))
	var dy := y - last_y
	data["last_y"] = y
	accum += dy
	while accum >= MENU_SCROLL_ROW_PX:
		_menu_scroll_edges.append(&"ui_down")
		accum -= MENU_SCROLL_ROW_PX
	while accum <= -MENU_SCROLL_ROW_PX:
		_menu_scroll_edges.append(&"ui_up")
		accum += MENU_SCROLL_ROW_PX
	data["accum"] = accum
	_menu_scroll_fingers[finger_id] = data


func _is_scrollable_menu() -> bool:
	return _input_context == CONTEXT_HUB or _input_context == CONTEXT_PAUSE


func _rect_dictionary_contains(rectangles: Dictionary, position: Vector2) -> bool:
	for value in rectangles.values():
		if value is Rect2 and (value as Rect2).has_point(position):
			return true
	return false


func _is_menu_context() -> bool:
	return _input_context == CONTEXT_HUB or _input_context == CONTEXT_MENU or _input_context == CONTEXT_PAUSE


func _menu_button_at(position: Vector2, include_disabled: bool = false) -> BaseButton:
	var search_root := _active_menu_root()
	if search_root == null:
		return null
	var nodes: Array = []
	_collect_menu_buttons(search_root, nodes)
	for index in range(nodes.size() - 1, -1, -1):
		var button := nodes[index] as BaseButton
		if button == null or not is_instance_valid(button) or not button.is_visible_in_tree() or (button.disabled and not include_disabled):
			continue
		if button.mouse_filter == Control.MOUSE_FILTER_IGNORE:
			continue
		if button.get_global_rect().has_point(position):
			return button
	return null


func _active_menu_root() -> Node:
	var host := get_parent()
	if host == null:
		return null
	var preferred_names: Array[StringName] = []
	match _input_context:
		CONTEXT_HUB: preferred_names = [&"HubOverlay"]
		CONTEXT_PAUSE: preferred_names = [&"PauseOverlay"]
		CONTEXT_MENU: preferred_names = [&"SettingsOverlay", &"SaveSelectOverlay", &"ArchetypeOverlay", &"RunCompleteOverlay", &"GameOverOverlay", &"TitleOverlay"]
		CONTEXT_DIALOGUE: preferred_names = [&"NpcDialogueBox"]
	for target_name in preferred_names:
		var found := _find_visible_control(host, target_name)
		if found != null and found.is_visible_in_tree():
			return _menu_root_for_target(found, target_name)
	# A route can become visible between the current physics poll and the next
	# one. Use visible-overlay discovery as a same-frame fallback so a touch
	# released during that transition cannot search the gameplay host or a stale
	# source menu.
	var visible_fallbacks: Array[StringName] = [&"SettingsOverlay", &"SaveSelectOverlay", &"ArchetypeOverlay", &"RunCompleteOverlay", &"GameOverOverlay", &"PauseOverlay", &"HubOverlay", &"NpcDialogueBox", &"TitleOverlay"]
	for target_name in visible_fallbacks:
		if preferred_names.has(target_name):
			continue
		var found := _find_visible_control(host, target_name)
		if found != null and found.is_visible_in_tree():
			return _menu_root_for_target(found, target_name)
	return host


func _menu_root_for_target(found: Control, target_name: StringName) -> Node:
	# Dialogue's visible panel and its native YES/NO buttons are siblings in the
	# dialogue CanvasLayer. Return that owner so choice taps are discoverable;
	# routed menu overlays keep their own full subtree as the search root.
	if target_name == &"NpcDialogueBox" and found.get_parent() != null:
		return found.get_parent()
	return found


func _collect_menu_buttons(node: Node, output: Array) -> void:
	for child in node.get_children():
		if child is BaseButton:
			output.append(child)
		_collect_menu_buttons(child, output)


func _has_real_touch_capture() -> bool:
	return _stick_pointer_id >= 0 or not _finger_actions.is_empty() or not _menu_touch_buttons.is_empty() or not _menu_accept_fingers.is_empty() or not _menu_scroll_fingers.is_empty()


func _update_touch_capture_filter() -> void:
	if _touch_root == null:
		return
	if _has_real_touch_capture():
		_touch_root.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		_touch_root.mouse_filter = Control.MOUSE_FILTER_PASS if _controls_visible else Control.MOUSE_FILTER_IGNORE


func _button_rect(action: StringName) -> Rect2:
	if action == &"pause":
		return _layout.get("pause", Rect2())
	if action == &"cancel":
		return _layout.get("cancel", Rect2())
	var buttons: Dictionary = _layout.get("buttons", {})
	return buttons.get(action, Rect2())


func _cancel_control_visible() -> bool:
	return _touch_input_enabled and _input_context == CONTEXT_DIALOGUE


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
	var viewport := get_viewport()
	var content_size := _content_size()
	var viewport_size := content_size
	if viewport != null:
		viewport_size = viewport.get_visible_rect().size
		if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
			viewport_size = content_size
	_layout = _compute_layout(viewport_size, content_size)
	if _stick_pointer_id < 0:
		_stick_origin = _layout["stick_home"]
	_apply_layout()


func _context_cancel_rect(layout: Dictionary) -> Rect2:
	var cancel: Rect2 = layout.get("cancel", Rect2())
	if _input_context != CONTEXT_HUB and _input_context != CONTEXT_PAUSE:
		return cancel
	var overlay_name: StringName = &"HubOverlay" if _input_context == CONTEXT_HUB else &"PauseOverlay"
	var menu_overlay := _find_visible_control(get_parent(), overlay_name)
	if menu_overlay == null:
		return cancel
	var bounds := menu_overlay.get_global_rect()
	var inset := maxf(float(layout.get("margin", 4.0)) * 0.75, 3.0)
	var nested_position := Vector2(bounds.end.x - cancel.size.x - inset, bounds.end.y - cancel.size.y - inset)
	if bounds.encloses(Rect2(nested_position, cancel.size)):
		cancel.position = nested_position
	return cancel


func _dialogue_touch_rect() -> Rect2:
	var dialogue_box := _find_visible_control(get_parent(), &"NpcDialogueBox")
	if dialogue_box == null:
		return Rect2()
	# Include the panel border and the slightly offset TAP continue glyph.
	return dialogue_box.get_global_rect().grow(4.0)


func _find_visible_control(node: Node, target_name: StringName) -> Control:
	if node == null:
		return null
	if node is Control and node.name == target_name and (node as Control).visible:
		return node as Control
	for child in node.get_children():
		var found := _find_visible_control(child, target_name)
		if found != null:
			return found
	return null


func _content_size() -> Vector2:
	var display := get_parent().get("display_controller") as DisplayController if get_parent() != null else null
	if display != null:
		return display.view_size_as_vector()
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
	_stick_knob.add_theme_stylebox_override("panel", _panel_style(Color(0.82, 0.86, 1.0, 0.82), Color.WHITE, 2, int(knob_side * 0.5)))
	_stick_base.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.10, 0.15, 0.62), Color(0.52, 0.58, 0.72, 0.78), 2, int(diameter * 0.5)))
	_update_stick_visuals()
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
	var corner := int(diameter * 0.5)
	if pressed:
		node.add_theme_stylebox_override("panel", _panel_style(Color(0.38, 0.42, 0.58, 0.95), Color.WHITE, 2, corner))
	else:
		node.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.05, 0.08, 0.78), Color(0.46, 0.52, 0.66, 0.92), 2, corner))


func _refresh_controls() -> void:
	_controls_visible = _last_input_device == DEVICE_TOUCH and (_input_context == CONTEXT_GAMEPLAY or _input_context == CONTEXT_DIALOGUE)
	_touch_input_enabled = _last_input_device == DEVICE_TOUCH and _input_context in [CONTEXT_GAMEPLAY, CONTEXT_DIALOGUE, CONTEXT_HUB, CONTEXT_MENU, CONTEXT_PAUSE]
	_update_touch_capture_filter()
	if not _controls_visible:
		_clear_gameplay_input()
	if not _touch_input_enabled:
		_menu_touch_buttons.clear()
		_menu_accept_fingers.clear()
		_menu_accept_latch = false
		_press_latches.clear()
		_update_touch_capture_filter()
	if not _built:
		return
	if _controls_visible:
		_update_layout()
	if _stick_base != null:
		_stick_base.visible = _controls_visible
		_stick_knob.visible = _controls_visible
	for action in _button_nodes:
		var control_visible := _controls_visible
		if action == &"cancel":
			control_visible = _cancel_control_visible()
		elif action == &"pause":
			control_visible = _controls_visible
		(_button_nodes[action] as Control).visible = control_visible


func _clear_gameplay_input() -> void:
	_stick_vector = Vector2.ZERO
	_stick_pointer_id = -1
	var gameplay_fingers: Array = []
	for finger_id in _finger_actions:
		if _finger_actions[finger_id] != &"cancel":
			gameplay_fingers.append(finger_id)
	for finger_id in gameplay_fingers:
		_finger_actions.erase(finger_id)
		_tap_interact_origins.erase(finger_id)
	for action in BUTTON_ORDER:
		_pressed_actions[action] = false
		_update_button_visual(action)
	_target_toggle_active = false
	_pressed_actions[&"pause"] = false
	_update_button_visual(&"pause")
	for action in BUTTON_ORDER:
		_press_latches.erase(action)
	_press_latches.erase(&"pause")


func _clear_transient_input() -> void:
	_stick_vector = Vector2.ZERO
	_stick_pointer_id = -1
	_stick_origin = _layout.get("stick_home", _stick_origin)
	_finger_actions.clear()
	_tap_interact_origins.clear()
	_menu_touch_buttons.clear()
	_menu_button_origins.clear()
	_menu_accept_fingers.clear()
	_menu_accept_latch = false
	_menu_scroll_fingers.clear()
	_menu_scroll_edges.clear()
	_pressed_actions.clear()
	_target_toggle_active = false
	_press_latches.clear()
	for action in _button_nodes:
		_update_button_visual(action)
	_update_touch_capture_filter()
