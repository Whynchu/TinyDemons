extends Node
class_name PlayerRollComponent

signal roll_started(direction: Vector2)
signal roll_finished

var active := false
var direction := Vector2.ZERO
var elapsed := 0.0
var frame := 0
var frame_timer := 0.0
var velocity := Vector2.ZERO


func begin(new_direction: Vector2) -> void:
	active = true
	direction = new_direction.normalized() if new_direction.length_squared() > 0.0 else Vector2.RIGHT
	elapsed = 0.0
	frame = 0
	frame_timer = 0.0
	velocity = Vector2.ZERO
	roll_started.emit(direction)


func start_motion(new_velocity: Vector2) -> void:
	velocity = new_velocity


func tick_motion(delta: float, duration: float, frame_time: float, frame_count: int, move_motion: Callable) -> Dictionary:
	if not active:
		return {"finished": true}
	var elapsed_at_frame := frame_timer + float(frame) * frame_time
	var step_time := minf(delta, maxf(duration - elapsed_at_frame, 0.0))
	if frame >= frame_count - 2:
		step_time *= 0.25
	move_motion.call(velocity * step_time)
	frame_timer += delta
	var current_frame_time := frame_time
	if frame == frame_count - 2:
		current_frame_time *= 3.0
	if frame_timer < current_frame_time:
		return {"finished": false}
	frame_timer = fmod(frame_timer, current_frame_time)
	frame += 1
	if frame < frame_count:
		return {"finished": false}
	active = false
	roll_finished.emit()
	return {"finished": true}


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
