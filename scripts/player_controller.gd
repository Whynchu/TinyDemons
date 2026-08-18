extends Node
class_name PlayerController

## Boundary for player action locks during composition migration.

const MOVE_ACTIONS := {
	Vector2.LEFT: &"move_left",
	Vector2.RIGHT: &"move_right",
	Vector2.UP: &"move_up",
	Vector2.DOWN: &"move_down",
}


func can_receive_input() -> bool:
	return true


func connected_devices() -> Array[int]:
	var devices: Array[int] = []
	for device in Input.get_connected_joypads():
		devices.append(int(device))
	if devices.is_empty():
		devices.append(0)
	return devices


func movement_input(devices: Array[int], deadzone: float) -> Vector2:
	var input := Vector2.ZERO
	for direction in MOVE_ACTIONS:
		if Input.is_action_pressed(MOVE_ACTIONS[direction]):
			input += direction
	for device in devices:
		var stick := Vector2(Input.get_joy_axis(device, JOY_AXIS_LEFT_X), Input.get_joy_axis(device, JOY_AXIS_LEFT_Y))
		if stick.length() >= deadzone: input += stick
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_RIGHT): input.x += 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_LEFT): input.x -= 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_DOWN): input.y += 1.0
		if Input.is_joy_button_pressed(device, JOY_BUTTON_DPAD_UP): input.y -= 1.0
	return input.limit_length(1.0)


func action_pressed(action: StringName, devices: Array[int], _button: int) -> bool:
	if Input.is_action_pressed(action):
		return true
	return false


func target_held(devices: Array[int], trigger_deadzone: float) -> bool:
	if Input.is_action_pressed(&"target"):
		return true
	for device in devices:
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT) > trigger_deadzone: return true
	return false


func guard_held(devices: Array[int], trigger_deadzone: float) -> bool:
	if Input.is_action_pressed(&"guard"):
		return true
	for device in devices:
		if Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT) > trigger_deadzone: return true
	return false