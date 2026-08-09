extends Node
class_name ScreenStateController

signal state_changed(state: StringName)
var state: StringName = &"gameplay"
var title_particles: Array[Dictionary] = []


func set_state(new_state: StringName) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)
