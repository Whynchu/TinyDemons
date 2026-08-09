extends Node
class_name PlayerAnimationComponent

signal animation_changed(name: StringName)

var animation_name: StringName = &"idle"
var frame := 0
var timer := 0.0


func play(new_name: StringName, reset := true) -> void:
	if animation_name != new_name:
		animation_name = new_name
		animation_changed.emit(animation_name)
	if reset:
		frame = 0
		timer = 0.0


func reset() -> void:
	frame = 0
	timer = 0.0
