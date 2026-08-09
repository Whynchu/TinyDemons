extends Node
class_name RestFireController

signal rest_requested


func request_rest() -> void:
	rest_requested.emit()
