extends Node
class_name PlayerController

## Boundary for player action locks during composition migration.

var input_locked := false


func set_input_locked(locked: bool) -> void:
	input_locked = locked


func can_receive_input() -> bool:
	return not input_locked


func connected_devices() -> Array[int]:
	var devices: Array[int] = []
	for device in Input.get_connected_joypads():
		devices.append(int(device))
	if devices.is_empty():
		devices.append(0)
	return devices


func movement_input(devices: Array[int], deadzone: float) -> Vector2:
	var input := Vector2.ZERO
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): input.x += 1.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): input.x -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S): input.y += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W): input.y -= 1.0
	for device in devices:
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if stick.length() >= deadzone: input += stick
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT): input.x += 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT): input.x -= 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN): input.y += 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP): input.y -= 1.0
	return input.limit_length(1.0)


func action_pressed(key_codes: Array[int], devices: Array[int], button: int) -> bool:
	for key in key_codes:
		if Input.is_key_pressed(key): return true
	for device in devices:
		if Input.is_joy_button_pressed(device, button): return true
	return false


func target_held(devices: Array[int], trigger_deadzone: float) -> bool:
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_TAB): return true
	for device in devices:
		if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER) or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER): return true
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > trigger_deadzone or Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > trigger_deadzone: return true
	return false
