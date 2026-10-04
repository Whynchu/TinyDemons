extends Node
class_name PlayerRollComponent

signal roll_started(direction: Vector2)
signal roll_finished

## Editor-facing backflip tuning.
@export var backflip_away_dot_threshold := 0.5

var active := false
var direction := Vector2.ZERO
var elapsed := 0.0
var frame := 0
var frame_timer := 0.0
var velocity := Vector2.ZERO
var landing_sound_played := false


func start_from_root(context: PlayerRollContext) -> void:
	var anim := context.player_animation_component
	var frames := anim.roll_frames as Array[Texture2D]
	if frames.is_empty(): return
	var run_state := context.run_state
	if run_state != null:
		run_state.record_roll(bool(context.is_run_combat_active.call()))
	var movement_direction: Vector2 = context.movement_input.call()
	if movement_direction.length_squared() <= 0.0: movement_direction = context.player_facing_vector.call()
	else: movement_direction = movement_direction.normalized()
	var player := context.player
	var motor := context.player_motor
	if motor != null:
		context.update_motor_facing.call(movement_direction)
	elif absf(movement_direction.x) > 0.1:
		context.last_player_facing_left_set.call(movement_direction.x < 0.0)
		player.flip_h = movement_direction.x < 0.0
	context.player_is_rolling_set.call(true); begin(movement_direction)
	if context.play_sound.is_valid():
		context.play_sound.call("flee", -8.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
	if motor != null: motor.begin_roll()
	context.roll_dust_spawned_this_roll_set.call(false); context.player_attack_visual.visible = false
	var tuning := context.player_tuning
	var roll_multiplier := _roll_multiplier_for(context, tuning)
	start_motion(context.perspective_movement.call(movement_direction * (tuning.roll_distance * roll_multiplier / tuning.roll_duration))); player.visible = true
	context.apply_animation_frame.call()


## A backflip is the target-lock retreat dodge: the player must hold the lock-on
## input and push away from the locked target (or, with no target, away from the
## facing they had before holding lock-on) before pressing the roll button.
func should_backflip(context: PlayerRollContext) -> bool:
	if not bool(context.player_is_targeting_get.call()):
		return false
	var anim := context.player_animation_component
	if anim == null or (anim.backflip_frames as Array[Texture2D]).is_empty():
		return false
	var input: Vector2 = context.movement_input.call()
	if input.length_squared() <= 0.0:
		return false
	var away := backflip_away_direction(context)
	if away.length_squared() <= 0.0001:
		return false
	var movement_world := context.perspective_movement.call(input.normalized()) as Vector2
	return movement_world.normalized().dot(away) > backflip_away_dot_threshold


## The direction the backflip retreats toward, in world space: away from the
## locked target, or backward relative to the player's pre-target facing when no
## target is locked.
func backflip_away_direction(context: PlayerRollContext) -> Vector2:
	var target := context.valid_current_target.call() as Sprite2D
	if target != null:
		var player := context.player
		return ((context.actor_foot.call(player) as Vector2) - (context.actor_foot.call(target) as Vector2)).normalized()
	return -(context.player_facing_vector.call() as Vector2).normalized()


func start_backflip_from_root(context: PlayerRollContext) -> void:
	var anim := context.player_animation_component
	var frames := anim.backflip_frames as Array[Texture2D]
	if frames.is_empty(): return
	var run_state := context.run_state
	if run_state != null:
		run_state.record_roll(bool(context.is_run_combat_active.call()))
	var player := context.player
	# The flip keeps the facing the player had before holding lock-on, not the
	# retreat/movement direction.
	player.flip_h = bool(context.player_facing_left_before_target_get.call())
	var away := backflip_away_direction(context)
	if away.length_squared() <= 0.0001:
		away = Vector2.RIGHT
	context.player_is_backflipping_set.call(true); begin(away)
	if context.play_sound.is_valid():
		context.play_sound.call("flee", -8.0, 0.95 + RandomNumberGenerator.new().randf_range(-0.08, 0.08))
	var motor := context.player_motor
	if motor != null: motor.begin_roll()
	context.player_attack_visual.visible = false
	landing_sound_played = false
	var tuning := context.player_tuning
	var roll_multiplier := _roll_multiplier_for(context, tuning)
	# The backflip uses the full animation cadence, so derive its velocity from
	# that duration while keeping the same total travel as a regular roll.
	var backflip_duration := tuning.backflip_frame_time * float(frames.size()) / roll_multiplier
	start_motion(away * (tuning.roll_distance / maxf(backflip_duration, 0.001))); player.visible = true
	context.apply_animation_frame.call()


func update_from_root(context: PlayerRollContext, delta: float) -> void:
	var is_backflip := bool(context.player_is_backflipping_get.call())
	if not bool(context.player_is_rolling_get.call()) and not is_backflip: return
	var anim := context.player_animation_component
	var tuning := context.player_tuning; var player := context.player; var before := player.global_position
	var roll_multiplier := _roll_multiplier_for(context, tuning)
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
	var result := tick_motion(delta, motion_duration, frame_time, frame_set.size(), Callable(self, "move_swept").bind(context), hold_landing_frame)
	if is_backflip:
		if not landing_sound_played and frame == frame_set.size() - 1:
			landing_sound_played = true
			if context.play_sound.is_valid():
				var pitch := 1.0 + RandomNumberGenerator.new().randf_range(-0.025, 0.025)
				context.play_sound.call("foot_left", -8.0, pitch)
				context.play_sound.call("foot_right", -8.0, pitch)
	elif not bool(context.roll_dust_spawned_this_roll_get.call()):
		var movement_direction := player.global_position - before
		if movement_direction.length_squared() <= 0.0001: movement_direction = context.perspective_movement.call(self.direction)
		context.start_roll_dust.call(movement_direction.normalized()); context.roll_dust_spawned_this_roll_set.call(true)
	if bool(result["finished"]):
		if is_backflip:
			context.player_is_backflipping_set.call(false)
		else:
			context.player_is_rolling_set.call(false)
		var motor := context.player_motor
		if motor != null: motor.end_roll()
		context.player_anim_name_set.call(context.movement_anim_name.call())
	context.apply_animation_frame.call()


func _roll_multiplier_for(context: PlayerRollContext, tuning: PlayerTuning) -> float:
	var agi_value: Variant = context.player_agi_get.call()
	var effective_agi := float(agi_value) if agi_value != null else float(context.player_spd_get.call())
	return tuning.roll_multiplier_for_agi(effective_agi)


func move_swept(movement: Vector2, context: PlayerRollContext) -> bool:
	return bool(context.try_move_actor.call(context.player, movement))


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
