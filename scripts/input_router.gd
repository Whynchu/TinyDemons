extends Node
class_name InputRouter

## One per-frame polling boundary for gameplay, dialogue, hub, and menu input.

enum Context { GAMEPLAY, DIALOGUE, HUB, MENU }

var context := Context.GAMEPLAY
var devices: Array[int] = []
var _current: Dictionary = {}
var _previous: Dictionary = {}
var _movement := Vector2.ZERO
var _target_axis := 0.0
var _guard_axis := 0.0

const ACTIONS := [&"attack", &"interact", &"roll", &"magic", &"cancel", &"pause", &"target", &"guard", &"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right", &"move_left", &"move_right", &"move_up", &"move_down"]


func poll(next_context: int) -> void:
	context = next_context
	_previous = _current.duplicate()
	_current.clear()
	for action in ACTIONS:
		_current[action] = Input.is_action_pressed(action)
	devices = connected_devices()
	_movement = _read_movement()
	_target_axis = _strongest_axis(JOY_AXIS_RIGHT_X)
	_guard_axis = _strongest_trigger(JOY_AXIS_TRIGGER_LEFT)


func connected_devices() -> Array[int]:
	var result: Array[int] = []
	for device in Input.get_connected_joypads():
		result.append(int(device))
	if result.is_empty():
		result.append(0)
	return result


func pressed(action: StringName) -> bool:
	return bool(_current.get(action, false))


func just_pressed(action: StringName) -> bool:
	return pressed(action) and not bool(_previous.get(action, false))


func just_released(action: StringName) -> bool:
	return not pressed(action) and bool(_previous.get(action, false))


func movement(deadzone: float) -> Vector2:
	return _movement.limit_length(1.0) if _movement.length() >= deadzone else Vector2.ZERO


func action_pressed(action: StringName) -> bool:
	return pressed(action)


func button_pressed(button: int) -> bool:
	return pressed(&"magic") if button == JOY_BUTTON_Y else pressed(&"attack") if button == JOY_BUTTON_X else pressed(&"roll") if button == JOY_BUTTON_A else pressed(&"interact") if button == JOY_BUTTON_B else false


func target_held(trigger_deadzone: float) -> bool:
	return pressed(&"target") or _strongest_trigger(JOY_AXIS_TRIGGER_RIGHT) > trigger_deadzone


func target_cycle_direction(deadzone: float) -> int:
	if absf(_target_axis) < deadzone:
		return 0
	return 1 if _target_axis > 0.0 else -1


func guard_held(trigger_deadzone: float) -> bool:
	return pressed(&"guard") or _guard_axis > trigger_deadzone


func ui_accept_pressed() -> bool:
	return pressed(&"ui_accept")


func ui_accept_just_pressed() -> bool:
	return just_pressed(&"ui_accept")


func ui_cancel_pressed() -> bool:
	return pressed(&"ui_cancel")


func ui_cancel_just_pressed() -> bool:
	return just_pressed(&"ui_cancel")


func ui_direction_just_pressed(direction: StringName) -> bool:
	return just_pressed(direction)


func _read_movement() -> Vector2:
	var value := Vector2.ZERO
	if pressed(&"move_left"): value.x -= 1.0
	if pressed(&"move_right"): value.x += 1.0
	if pressed(&"move_up"): value.y -= 1.0
	if pressed(&"move_down"): value.y += 1.0
	for device in devices:
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if stick.length() > value.length(): value = stick
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT): value.x += 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT): value.x -= 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN): value.y += 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP): value.y -= 1.0
	return value


func _strongest_axis(axis: int) -> float:
	var strongest := 0.0
	for device in devices:
		var value := Input.get_joy_axis(device, axis)
		if absf(value) > absf(strongest): strongest = value
	return strongest


func _strongest_trigger(axis: int) -> float:
	var strongest := 0.0
	for device in devices:
		strongest = maxf(strongest, Input.get_joy_axis(device, axis))
	return strongest
