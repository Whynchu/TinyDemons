extends RefCounted
class_name RoomEntryContext

## Typed runtime input for one room-entry execution.
##
var services: RoomEntryServices = null
var transition: RoomTransitionResult = null


func _init(new_services: RoomEntryServices, new_transition: RoomTransitionResult) -> void:
	services = new_services
	transition = new_transition


func is_valid() -> bool:
	return services != null and services.is_valid() and transition != null and transition.is_ready()
