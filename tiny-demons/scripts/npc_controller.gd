extends Node
class_name NpcController

signal dialogue_requested


func request_dialogue() -> void:
	dialogue_requested.emit()
