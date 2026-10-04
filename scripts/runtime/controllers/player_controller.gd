extends Node
class_name PlayerController

## Boundary for player action locks during composition migration.

const MOVE_ACTIONS := {
	Vector2.LEFT: &"move_left",
	Vector2.RIGHT: &"move_right",
	Vector2.UP: &"move_up",
	Vector2.DOWN: &"move_down",
}

var input_router: InputRouter = null


func configure_input_router(router: InputRouter) -> void:
	input_router = router


func can_receive_input() -> bool:
	return true


func connected_devices() -> Array[int]:
	if input_router != null:
		return input_router.devices
	return []


func movement_input(_devices: Array[int], deadzone: float) -> Vector2:
	if input_router != null:
		return input_router.movement(deadzone)
	return Vector2.ZERO


func action_pressed(action: StringName, _devices: Array[int], _button: int) -> bool:
	if input_router != null:
		return input_router.action_pressed(action)
	return false


func target_held(_devices: Array[int], trigger_deadzone: float) -> bool:
	if input_router != null:
		return input_router.target_held(trigger_deadzone)
	return false


func target_cycle_direction(_devices: Array[int], deadzone: float) -> int:
	if input_router != null:
		return input_router.target_cycle_direction(deadzone)
	return 0


func guard_held(_devices: Array[int], trigger_deadzone: float) -> bool:
	if input_router != null:
		return input_router.guard_held(trigger_deadzone)
	return false
