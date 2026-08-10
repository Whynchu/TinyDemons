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


func move_player(root: Object, delta: float) -> void:
	var controller := root.get("player_controller") as PlayerController
	if controller != null and not controller.can_receive_input(): root.set("player_is_moving", false); return
	if bool(root.get("player_death_pending")) or bool(root.get("player_is_attacking")) or bool(root.get("player_is_rolling")) or is_in_knockback() or float(root.get("player_hitstun_timer")) > 0.0: root.set("player_is_moving", false); return
	var input: Vector2 = root.call("_movement_input"); var moving := input.length_squared() > 0.0; root.set("player_is_moving", moving)
	if not moving: return
	var player := root.get("player") as Sprite2D
	if input.x < 0.0: player.flip_h = true
	elif input.x > 0.0: player.flip_h = false
	var tuning := root.get("player_tuning") as PlayerTuning
	request_motion(root.call("_perspective_movement", input.normalized() * tuning.speed * delta))


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
