extends Node
class_name InteractionComponent

signal availability_changed(available: bool)
signal interacted

var available := false


func set_available(value: bool) -> void:
	if available == value:
		return
	available = value
	availability_changed.emit(available)


func interact() -> void:
	if available:
		interacted.emit()
