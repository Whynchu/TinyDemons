extends Node
class_name InputDeviceTracker

## Classifies the last deliberate input event so prompts and touch controls can
## follow the device the player is actually using.

signal device_changed(device: int)

enum Device { KEYBOARD_MOUSE, GAMEPAD, TOUCH }

const JOYPAD_MOTION_THRESHOLD := 0.5
const EMULATED_DEVICE_ID := -1
## Mobile browsers can emit a mouse-motion echo while a finger is dragging.
## Keep the touch device selected for this short handoff window so a virtual
## stick cannot disappear in the middle of a drag.
const TOUCH_MOUSE_ECHO_GRACE_MSEC := 250
const LAST_DEVICE_META_KEY := "tiny_demons_last_input_device"

var current_device: int = Device.KEYBOARD_MOUSE
var _active_touch_indices: Dictionary = {}
var _last_real_touch_msec := -1000000


func _ready() -> void:
	var persisted_device := int(Engine.get_meta(LAST_DEVICE_META_KEY, -1))
	if persisted_device >= Device.KEYBOARD_MOUSE and persisted_device <= Device.TOUCH:
		# GameplayState is rebuilt during transitions; retain the last deliberate
		# device across that rebuild instead of falling back to keyboard prompts.
		current_device = persisted_device
	elif DisplayServer.is_touchscreen_available():
		current_device = Device.TOUCH
		Engine.set_meta(LAST_DEVICE_META_KEY, current_device)


func _input(event: InputEvent) -> void:
	var detected := classify_event(event)
	if detected >= 0:
		set_device(detected)


func set_device(device: int) -> void:
	if device < Device.KEYBOARD_MOUSE or device > Device.TOUCH or device == current_device:
		return
	current_device = device
	Engine.set_meta(LAST_DEVICE_META_KEY, current_device)
	device_changed.emit(device)


func classify_event(event: InputEvent) -> int:
	if event == null:
		return -1
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.device == EMULATED_DEVICE_ID:
			return -1
		_record_real_touch(touch.index, touch.pressed)
		return Device.TOUCH
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.device == EMULATED_DEVICE_ID:
			return -1
		# Some browser/device combinations deliver a drag before the matching
		# touch-down event. Treating it as active keeps the mouse echo filtered.
		_record_real_touch(drag.index, true)
		return Device.TOUCH
	if event is InputEventKey:
		var key_event := event as InputEventKey
		return Device.KEYBOARD_MOUSE if key_event.pressed and not key_event.echo else -1
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if not mouse_button.pressed or mouse_button.device == EMULATED_DEVICE_ID or _touch_echo_active():
			return -1
		return Device.KEYBOARD_MOUSE
	if event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion
		if mouse_motion.device == EMULATED_DEVICE_ID or _touch_echo_active():
			return -1
		return Device.KEYBOARD_MOUSE if mouse_motion.relative.length_squared() > 0.0 else -1
	if event is InputEventJoypadButton:
		return Device.GAMEPAD if (event as InputEventJoypadButton).pressed else -1
	if event is InputEventJoypadMotion:
		return Device.GAMEPAD if absf((event as InputEventJoypadMotion).axis_value) > JOYPAD_MOTION_THRESHOLD else -1
	return -1


func _record_real_touch(index: int, pressed: bool) -> void:
	_last_real_touch_msec = Time.get_ticks_msec()
	if pressed:
		_active_touch_indices[index] = true
	else:
		_active_touch_indices.erase(index)


func _touch_echo_active() -> bool:
	if not _active_touch_indices.is_empty():
		return true
	return Time.get_ticks_msec() - _last_real_touch_msec <= TOUCH_MOUSE_ECHO_GRACE_MSEC


func prompt_label(action: StringName) -> String:
	var normalized := action
	if normalized == &"ui_accept": normalized = &"interact"
	elif normalized == &"ui_cancel": normalized = &"cancel"
	match current_device:
		Device.GAMEPAD:
			return {&"attack": "X", &"interact": "B", &"roll": "A", &"magic": "Y", &"cancel": "A", &"pause": "BACK", &"target": "RB", &"guard": "LB"}.get(normalized, "BTN")
		Device.TOUCH:
			return "TAP" if normalized in [&"interact", &"ui_accept", &"cancel", &"ui_cancel"] else "TOUCH"
		_:
			return {&"attack": "J", &"interact": "E", &"roll": "K", &"magic": "U", &"cancel": "X", &"pause": "ESC", &"target": "Q", &"guard": "L"}.get(normalized, "KEY")


func menu_confirm_prompt() -> String:
	match current_device:
		Device.GAMEPAD:
			return "O SELECT" if _is_playstation_pad() else "B SELECT"
		Device.TOUCH:
			return "TAP SELECT"
		_:
			return "ENTER SELECT"


func menu_back_prompt() -> String:
	match current_device:
		Device.GAMEPAD:
			return "X BACK" if _is_playstation_pad() else "A BACK"
		Device.TOUCH:
			return "BACK"
		_:
			return "ESC BACK"


func _is_playstation_pad() -> bool:
	for device in Input.get_connected_joypads():
		var joy_name := Input.get_joy_name(device).to_lower()
		if joy_name.contains("playstation") or joy_name.contains("dualshock") or joy_name.contains("dualsense") or joy_name.contains("ps4") or joy_name.contains("ps5") or joy_name == "wireless controller":
			return true
	return false
