extends Node
class_name PlayerRollComponent

signal roll_started(direction: Vector2)
signal roll_finished

var active := false
var direction := Vector2.ZERO
var elapsed := 0.0


func begin(new_direction: Vector2) -> void:
	active = true
	direction = new_direction.normalized() if new_direction.length_squared() > 0.0 else Vector2.RIGHT
	elapsed = 0.0
	roll_started.emit(direction)


func advance(delta: float, duration: float) -> bool:
	if not active:
		return false
	elapsed += delta
	if elapsed >= duration:
		active = false
		roll_finished.emit()
	return active


func cancel() -> void:
	if active:
		active = false
		roll_finished.emit()
