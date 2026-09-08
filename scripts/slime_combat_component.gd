extends Node
class_name SlimeCombatComponent

signal attack_started
signal hit_confirmed
signal attack_finished

var active := false
var timer := 0.0
var hit_done := false
var cooldown := 0.0
var frame := 0
var face_left := false
var flash_timer := 0.0
var hitstun_timer := 0.0
var knockback_velocity := Vector2.ZERO
var knockback_timer := 0.0
var lunge_remaining := 0.0
var lunge_total := 0.0
var lunge_vector := Vector2.ZERO
var attack_target_point := Vector2.ZERO
var attack_lunge_vector := Vector2.ZERO
var dead := false
## Boss Jump Slam protection is split so the telegraph can take damage without
## allowing hitstun, while the airborne/impact portion can reject damage too.
var boss_jump_phase_active := false
var boss_jump_phase_invulnerable := false
var boss_jump_phase_stun_resistant := false


func tick(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)


func begin() -> void:
	active = true
	timer = 0.001
	hit_done = false
	attack_target_point = Vector2.ZERO
	attack_lunge_vector = Vector2.ZERO
	attack_started.emit()


func confirm_hit() -> bool:
	if hit_done:
		return false
	hit_done = true
	hit_confirmed.emit()
	return true


func finish(next_cooldown: float) -> void:
	active = false
	timer = 0.0
	hit_done = false
	attack_target_point = Vector2.ZERO
	attack_lunge_vector = Vector2.ZERO
	cooldown = maxf(next_cooldown, 0.0)
	attack_finished.emit()


func begin_lunge(vector: Vector2, duration: float) -> void:
	lunge_vector = vector
	lunge_total = maxf(duration, 0.001)
	lunge_remaining = lunge_total


func clear_boss_jump_phase() -> void:
	boss_jump_phase_active = false
	boss_jump_phase_invulnerable = false
	boss_jump_phase_stun_resistant = false


func tick_attack(delta: float, actor: Sprite2D, tuning: SlimeTuning, frames: Array[Texture2D], player_dead: bool, set_frame: Callable, set_texture: Callable, apply_lunge: Callable, apply_hit: Callable, restore_idle: Callable, can_attack: Callable, start_attack: Callable) -> bool:
	if player_dead:
		timer = 0.0
		return false
	var is_boss := float(actor.get_meta("encounter_scale", 1.0)) > 1.0
	var frame_time := tuning.attack_frame_time * (tuning.boss_attack_frame_time_multiplier if is_boss else 1.0)
	frame_time *= float(actor.get_meta("attack_speed_multiplier", 1.0))
	var cooldown_after := tuning.attack_cooldown * (tuning.boss_attack_cooldown_multiplier if is_boss else 1.0)
	if timer > 0.0:
		timer += delta
		if frames.is_empty():
			timer = 0.0
			return false
		var frame_index := mini(int(floor(timer / frame_time)), frames.size() - 1)
		frame = frame_index
		set_frame.call(actor, frame_index)
		set_texture.call(actor, frames[frame_index])
		var hit_frame := tuning.boss_attack_hit_frame if is_boss else tuning.attack_hit_frame
		if is_boss and frame_index >= hit_frame - 3 and attack_target_point == Vector2.ZERO:
			attack_target_point = actor.get_meta("attack_target_point", Vector2.ZERO)
			attack_lunge_vector = actor.get_meta("attack_lunge_vector", Vector2.ZERO)
		if not hit_done and frame_index >= hit_frame - 2 and lunge_remaining <= 0.0:
			lunge_total = tuning.boss_attack_lunge_duration if is_boss else 0.12
			lunge_remaining = lunge_total
			apply_lunge.call(actor, 0.0)
		if lunge_remaining > 0.0:
			var step := minf(delta, lunge_remaining)
			lunge_remaining = maxf(lunge_remaining - delta, 0.0)
			apply_lunge.call(actor, step / lunge_total)
		if frame_index == hit_frame and not hit_done and confirm_hit():
			# Cooldown starts at impact so a full recovery window is guaranteed
			# from the actual attack, not merely from animation cleanup.
			cooldown = maxf(cooldown, cooldown_after)
			apply_hit.call(actor)
		if timer >= frame_time * float(frames.size()):
			finish(cooldown)
			restore_idle.call(actor)
		return true
	if cooldown > 0.0 or not can_attack.call(actor):
		return false
	start_attack.call(actor)
	return true


func tick_knockback(delta: float, actor: Sprite2D, move_actor: Callable, reset_scoot: Callable) -> bool:
	if knockback_timer <= 0.0:
		return false
	var step_time := minf(delta, knockback_timer)
	knockback_timer = maxf(knockback_timer - delta, 0.0)
	var did_move := bool(move_actor.call(actor, knockback_velocity * step_time))
	# A blocked knockback is complete. Continuing to push against the boundary
	# every frame makes the actor vibrate and delays its return to navigation.
	if not did_move:
		knockback_timer = 0.0
	if knockback_timer <= 0.0:
		knockback_velocity = Vector2.ZERO
		reset_scoot.call(actor)
	return true
