extends Node
class_name ScreenStateController

signal state_changed(state: StringName)
var state: StringName = &"gameplay"


func set_state(new_state: StringName) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
