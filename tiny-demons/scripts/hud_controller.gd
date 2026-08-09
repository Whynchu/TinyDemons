extends Node
class_name HudController

signal target_changed(target: Node)

var current_target: Node = null


func set_target(target: Node) -> void:
	if current_target == target:
		return
	current_target = target
	target_changed.emit(target)
