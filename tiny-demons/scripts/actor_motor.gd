extends Node
class_name ActorMotor

## Motion-state boundary for actors.
## Collision resolution remains in gameplay until the world-system milestone.

signal motion_requested(motion: Vector2)
signal knockback_started
signal knockback_finished

var knockback_velocity := Vector2.ZERO
var knockback_remaining := 0.0
var rolling := false


func request_motion(motion: Vector2) -> void:
	if motion.length_squared() > 0.0:
		motion_requested.emit(motion)


func start_knockback(velocity: Vector2, duration: float) -> void:
	knockback_velocity = velocity
	knockback_remaining = maxf(duration, 0.0)
	if knockback_remaining > 0.0:
		knockback_started.emit()


func consume_knockback(delta: float) -> Vector2:
	if knockback_remaining <= 0.0:
		return Vector2.ZERO
	var step := minf(delta, knockback_remaining)
	knockback_remaining = maxf(knockback_remaining - delta, 0.0)
	var motion := knockback_velocity * step
	if knockback_remaining <= 0.0:
		knockback_velocity = Vector2.ZERO
		knockback_finished.emit()
	return motion


func is_in_knockback() -> bool:
	return knockback_remaining > 0.0


func begin_roll() -> void:
	rolling = true


func end_roll() -> void:
	rolling = false
