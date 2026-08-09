extends Node
class_name PlayerAttackComponent

signal attack_started(variant: int)
signal attack_finished

var active := false
var variant := 1
var hit_targets: Array[Sprite2D] = []


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
