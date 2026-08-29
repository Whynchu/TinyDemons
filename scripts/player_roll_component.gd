extends Node
class_name PlayerRollComponent

signal roll_started(direction: Vector2)
signal roll_finished

const BACKFLIP_AWAY_DOT_THRESHOLD := 0.5

var active := false
var direction := Vector2.ZERO
var elapsed := 0.0
var frame := 0
var frame_timer := 0.0
var velocity := Vector2.ZERO
var landing_sound_played := false


func start_from_root(root: Object) -> void:
	var anim := root.get("player_animation_component") as PlayerAnimationComponent
	var frames := anim.roll_frames as Array[Texture2D]
	if frames.is_empty(): return
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_roll(bool(root.call("_is_run_combat_active")))
	var movement_direction: Vector2 = root.call("_movement_input")
	if movement_direction.length_squared() <= 0.0: movement_direction = root.call("_player_facing_vector")
	else: movement_direction = movement_direction.normalized()
	var player := root.get("player") as Sprite2D
	var motor := root.get("player_motor") as ActorMotor
	if motor != null:
		motor.update_horizontal_facing(root, movement_direction)
	elif absf(movement_direction.x) > 0.1:
		root.set("last_player_facing_left", movement_direction.x < 0.0)
		player.flip_h = movement_direction.x < 0.0
	root.set("player_is_rolling", true); begin(movement_direction)
	if root.has_method("_play_sound"):
		root.call("_play_sound", "flee", -8.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
	if motor != null: motor.begin_roll()
	root.set("roll_dust_spawned_this_roll", false); (root.get("player_attack_visual") as Sprite2D).visible = false
	var tuning := root.get("player_tuning") as PlayerTuning
	var roll_multiplier := _roll_multiplier_for(root, tuning)
	start_motion(root.call("_perspective_movement", movement_direction * (tuning.roll_distance * roll_multiplier / tuning.roll_duration))); player.visible = true
	anim.apply_frame(root)


## A backflip is the target-lock retreat dodge: the player must hold the lock-on
## input and push away from the locked target (or, with no target, away from the
## facing they had before holding lock-on) before pressing the roll button.
func should_backflip(root: Object) -> bool:
	if not bool(root.get("player_is_targeting")):
		return false
	var anim := root.get("player_animation_component") as PlayerAnimationComponent
	if anim == null or (anim.backflip_frames as Array[Texture2D]).is_empty():
		return false
	var input: Vector2 = root.call("_movement_input")
	if input.length_squared() <= 0.0:
		return false
	var away := backflip_away_direction(root)
	if away.length_squared() <= 0.0001:
		return false
	var movement_world := root.call("_perspective_movement", input.normalized()) as Vector2
	return movement_world.normalized().dot(away) > BACKFLIP_AWAY_DOT_THRESHOLD


## The direction the backflip retreats toward, in world space: away from the
## locked target, or backward relative to the player's pre-target facing when no
## target is locked.
func backflip_away_direction(root: Object) -> Vector2:
	var target := root.call("_valid_current_target") as Sprite2D
	if target != null:
		var player := root.get("player") as Sprite2D
		return ((root.call("_actor_foot", player) as Vector2) - (root.call("_actor_foot", target) as Vector2)).normalized()
	return -(root.call("_player_facing_vector") as Vector2).normalized()


func start_backflip_from_root(root: Object) -> void:
	var anim := root.get("player_animation_component") as PlayerAnimationComponent
	var frames := anim.backflip_frames as Array[Texture2D]
	if frames.is_empty(): return
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_roll(bool(root.call("_is_run_combat_active")))
	var player := root.get("player") as Sprite2D
	# The flip keeps the facing the player had before holding lock-on, not the
	# retreat/movement direction.
	player.flip_h = bool(root.get("player_facing_left_before_target"))
	var away := backflip_away_direction(root)
	if away.length_squared() <= 0.0001:
		away = Vector2.RIGHT
	root.set("player_is_backflipping", true); begin(away)
	if root.has_method("_play_sound"):
		root.call("_play_sound", "flee", -8.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
	var motor := root.get("player_motor") as ActorMotor
	if motor != null: motor.begin_roll()
	(root.get("player_attack_visual") as Sprite2D).visible = false
	landing_sound_played = false
	var tuning := root.get("player_tuning") as PlayerTuning
	var roll_multiplier := _roll_multiplier_for(root, tuning)
	# The backflip uses the full animation cadence, so derive its velocity from
	# that duration while keeping the same total travel as a regular roll.
	var backflip_duration := tuning.backflip_frame_time * float(frames.size()) / roll_multiplier
	start_motion(away * (tuning.roll_distance / maxf(backflip_duration, 0.001))); player.visible = true
	anim.apply_frame(root)


func update_from_root(root: Object, delta: float) -> void:
	var is_backflip := bool(root.get("player_is_backflipping"))
	if not bool(root.get("player_is_rolling")) and not is_backflip: return
	var anim := root.get("player_animation_component") as PlayerAnimationComponent
	var tuning := root.get("player_tuning") as PlayerTuning; var player := root.get("player") as Sprite2D; var before := player.global_position
	var roll_multiplier := _roll_multiplier_for(root, tuning)
	var frame_set: Array[Texture2D] = anim.backflip_frames if is_backflip else anim.roll_frames
	var frame_time := tuning.roll_frame_time / roll_multiplier
	var hold_landing_frame := true
	if is_backflip:
		# Backflip movement follows the complete seven-frame sequence. Do not
		# reuse the roll's shorter fixed duration: it ends the retreat early.
		frame_time = tuning.backflip_frame_time / roll_multiplier
		hold_landing_frame = false
	var motion_duration := tuning.roll_duration
	if is_backflip:
		motion_duration = frame_time * float(frame_set.size())
	var result := tick_motion(delta, motion_duration, frame_time, frame_set.size(), Callable(self, "move_swept").bind(root), hold_landing_frame)
	if is_backflip:
		if not landing_sound_played and frame == frame_set.size() - 1:
			landing_sound_played = true
			if root.has_method("_play_sound"):
				var pitch := 1.0 + RandomNumberGenerator.new().randf_range(-0.025, 0.025)
				root.call("_play_sound", "foot_left", -8.0, pitch)
				root.call("_play_sound", "foot_right", -8.0, pitch)
	elif not bool(root.get("roll_dust_spawned_this_roll")):
		var movement_direction := player.global_position - before
		if movement_direction.length_squared() <= 0.0001: movement_direction = root.call("_perspective_movement", self.direction)
		root.call("_start_roll_dust", movement_direction.normalized()); root.set("roll_dust_spawned_this_roll", true)
	if bool(result["finished"]):
		if is_backflip:
			root.set("player_is_backflipping", false)
		else:
			root.set("player_is_rolling", false)
		var motor := root.get("player_motor") as ActorMotor
		if motor != null: motor.end_roll()
		root.set("player_anim_name", anim.movement_anim_name(root))
	anim.apply_frame(root)


func _roll_multiplier_for(root: Object, tuning: PlayerTuning) -> float:
	var agi_value: Variant = root.get("player_agi")
	var effective_agi := float(agi_value) if agi_value != null else float(root.get("player_spd"))
	return tuning.roll_multiplier_for_agi(effective_agi)


func move_swept(movement: Vector2, root: Object) -> bool:
	return (root.get("actor_collision_system") as ActorCollisionSystem).try_move_swept(root.get("player"), movement, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))


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


func tick_motion(delta: float, duration: float, frame_time: float, frame_count: int, move_motion: Callable, hold_landing_frame: bool = true) -> Dictionary:
	if not active:
		return {"finished": true}
	var elapsed_at_frame := frame_timer + float(frame) * frame_time
	var step_time := minf(delta, maxf(duration - elapsed_at_frame, 0.0))
	if hold_landing_frame and frame >= frame_count - 2:
		step_time *= 0.25
	move_motion.call(velocity * step_time)
	frame_timer += delta
	var current_frame_time := frame_time
	if hold_landing_frame and frame == frame_count - 2:
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
