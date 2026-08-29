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

const HORIZONTAL_FACING_DEADZONE := 0.1


func move_player(root: Object, delta: float) -> void:
	var controller := root.get("player_controller") as PlayerController
	if controller != null and not controller.can_receive_input(): root.set("player_is_moving", false); root.set("player_is_running", false); return
	if bool(root.get("player_death_pending")) or bool(root.get("player_is_attacking")) or bool(root.get("player_is_rolling")) or bool(root.get("player_is_backflipping")) or is_in_knockback() or float(root.get("player_hitstun_timer")) > 0.0: root.set("player_is_moving", false); root.set("player_is_running", false); return
	var input: Vector2 = root.call("_movement_input")
	if input.length_squared() > 0.0:
		root.set("last_player_input_direction", input.normalized())
	var moving := input.length_squared() > 0.0; root.set("player_is_moving", moving)
	# Running is a roll continuation: hold the roll button after a dodge (the
	# frame controller latches player_roll_hold_armed) and keep moving. Lock-on
	# targeting (player_is_targeting) suppresses the run so the player keeps
	# walk speed while circling a target.
	var running := moving and bool(root.get("player_roll_input_held")) and bool(root.get("player_roll_hold_armed")) and not bool(root.get("player_is_defending")) and not bool(root.get("player_is_targeting"))
	root.set("player_is_running", running)
	if not moving: return
	update_horizontal_facing(root, input, not bool(root.get("player_is_defending")))
	var tuning := root.get("player_tuning") as PlayerTuning
	var guard_speed_scale := 0.5 if bool(root.get("player_is_defending")) else 1.0
	var speed_multiplier := float(root.get("player_speed_multiplier"))
	var base_speed := tuning.run_speed if running else tuning.speed
	request_motion(root.call("_perspective_movement", input.normalized() * base_speed * guard_speed_scale * speed_multiplier * delta))


func update_horizontal_facing(root: Object, direction: Vector2, update_visual: bool = true) -> void:
	var player := root.get("player") as Sprite2D
	if player == null:
		return
	# Lock-on owns the facing while the target button is held: the player must
	# not turn with movement, even when no target is locked (they keep the facing
	# they had when they pressed lock-on).
	if root.get("player_is_targeting") == true:
		return
	# Keep facing independent from the vertical component. A controller can
	# report a tiny horizontal value while the stick is held straight up/down;
	# treating that noise as a new facing direction makes the walk presentation
	# visibly flicker. Only a meaningful horizontal input changes the remembered
	# left/right direction, and vertical movement reapplies that stable choice.
	if absf(direction.x) > HORIZONTAL_FACING_DEADZONE:
		root.set("last_player_facing_left", direction.x < 0.0)
	var remembered: Variant = root.get("last_player_facing_left")
	var facing_left := bool(remembered) if remembered != null else player.flip_h
	if update_visual:
		player.flip_h = facing_left


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


func update_player_hit_reaction(root: Object, delta: float) -> void:
	root.set("player_hit_flash_timer", maxf(float(root.get("player_hit_flash_timer")) - delta, 0.0)); root.set("player_hitstun_timer", maxf(float(root.get("player_hitstun_timer")) - delta, 0.0))
	if not is_in_knockback(): return
	(root.get("actor_collision_system") as ActorCollisionSystem).try_move_swept(root.get("player"), consume_knockback(delta), 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))


func is_in_knockback() -> bool:
	return knockback_remaining > 0.0


func begin_roll() -> void:
	rolling = true


func end_roll() -> void:
	rolling = false
