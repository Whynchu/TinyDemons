extends Node
class_name PlayerController

## Boundary for player action locks during composition migration.

var input_locked := false


func set_input_locked(locked: bool) -> void:
	input_locked = locked


func can_receive_input() -> bool:
	return not input_locked
