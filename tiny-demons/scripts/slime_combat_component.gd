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
var dead := false


func tick(delta: float) -> void:
	cooldown = maxf(cooldown - delta, 0.0)


func begin() -> void:
	active = true
	timer = 0.001
	hit_done = false
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
	cooldown = maxf(next_cooldown, 0.0)
	attack_finished.emit()


func tick_attack(delta: float, actor: Sprite2D, tuning: SlimeTuning, frames: Array[Texture2D], player_dead: bool, set_frame: Callable, set_texture: Callable, apply_lunge: Callable, apply_hit: Callable, restore_idle: Callable, can_attack: Callable, start_attack: Callable) -> bool:
	if player_dead:
		timer = 0.0
		return false
	if timer > 0.0:
		timer += delta
		if frames.is_empty():
			timer = 0.0
			return false
		var frame_index := mini(int(floor(timer / tuning.attack_frame_time)), frames.size() - 1)
		frame = frame_index
		set_frame.call(actor, frame_index)
		set_texture.call(actor, frames[frame_index])
		if frame_index == tuning.attack_hit_frame and not hit_done and confirm_hit():
			apply_lunge.call(actor)
			apply_hit.call(actor)
		if timer >= tuning.attack_frame_time * float(frames.size()):
			finish(tuning.attack_cooldown)
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
	move_actor.call(actor, knockback_velocity * step_time)
	if knockback_timer <= 0.0:
		knockback_velocity = Vector2.ZERO
		reset_scoot.call(actor)
	return true
