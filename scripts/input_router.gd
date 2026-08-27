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
var touch_provider: Node = null
var _touch_snapshot: Dictionary = {}

const ACTIONS := [&"attack", &"interact", &"roll", &"magic", &"cancel", &"pause", &"target", &"guard", &"ui_accept", &"ui_cancel", &"ui_up", &"ui_down", &"ui_left", &"ui_right", &"move_left", &"move_right", &"move_up", &"move_down"]


func poll(next_context: int) -> void:
	context = next_context
	if touch_provider != null and touch_provider.has_method("set_input_context"):
		touch_provider.call("set_input_context", context)
	_previous = _current.duplicate()
	_current.clear()
	_touch_snapshot = _read_touch_snapshot()
	for action in ACTIONS:
		_current[action] = Input.is_action_pressed(action) or _touch_action_pressed(action) or _touch_action_just_pressed(action)
	devices = connected_devices()
	_movement = _read_movement()
	_target_axis = _strongest_axis(JOY_AXIS_RIGHT_X)
	_guard_axis = _strongest_trigger(JOY_AXIS_TRIGGER_LEFT)


func set_touch_provider(provider: Node) -> void:
	touch_provider = provider
	_touch_snapshot.clear()


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


func raw_movement() -> Vector2:
	## Returns the merged stick/D-pad/keyboard/touch sample without applying the
	## locomotion deadzone. Gesture recognizers need the same input source as
	## movement, but must see the full analog path between samples.
	return _movement.limit_length(1.0)


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
	var touch_movement: Variant = _touch_snapshot.get("movement", Vector2.ZERO)
	if touch_movement is Vector2 and (touch_movement as Vector2).length() > value.length():
		value = touch_movement as Vector2
	return value


func _read_touch_snapshot() -> Dictionary:
	if touch_provider == null or not touch_provider.has_method("is_active"):
		return {}
	if not bool(touch_provider.call("is_active")):
		return {}
	if not touch_provider.has_method("snapshot"):
		return {}
	var snapshot: Variant = touch_provider.call("snapshot")
	return snapshot as Dictionary if snapshot is Dictionary else {}


func _touch_action_pressed(action: StringName) -> bool:
	var actions: Variant = _touch_snapshot.get("actions", {})
	return bool((actions as Dictionary).get(action, false)) if actions is Dictionary else false


func _touch_action_just_pressed(action: StringName) -> bool:
	var just_pressed: Variant = _touch_snapshot.get("just_pressed", {})
	return bool((just_pressed as Dictionary).get(action, false)) if just_pressed is Dictionary else false


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
