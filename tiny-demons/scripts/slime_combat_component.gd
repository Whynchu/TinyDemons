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
