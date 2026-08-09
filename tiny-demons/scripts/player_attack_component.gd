extends Node
class_name PlayerAttackComponent

signal attack_started(variant: int)
signal attack_finished

var active := false
var variant := 1
var hit_targets: Array[Sprite2D] = []
var combo_buffered := false
var combo_timer := 0.0


func begin(new_variant: int) -> void:
	active = true
	variant = new_variant
	hit_targets.clear()
	attack_started.emit(variant)


func register_hit(target: Sprite2D) -> bool:
	if hit_targets.has(target):
		return false
	hit_targets.append(target)
	return true


func finish() -> void:
	if active:
		active = false
		attack_finished.emit()
	hit_targets.clear()


func cancel() -> void:
	finish()


func buffer_combo(window: float) -> void:
	combo_buffered = true
	combo_timer = maxf(window, 0.0)


func tick_combo(delta: float) -> void:
	if combo_timer <= 0.0:
		return
	combo_timer = maxf(combo_timer - delta, 0.0)
	if combo_timer <= 0.0:
		combo_buffered = false


func consume_combo() -> bool:
	if not combo_buffered:
		return false
	combo_buffered = false
	combo_timer = 0.0
	return true
