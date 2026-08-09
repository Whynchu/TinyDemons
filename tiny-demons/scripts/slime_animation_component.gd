extends Node
class_name SlimeAnimationComponent

var facing_left := false
var attack_frame := 0
var scoot_progress := 0.0
var breathing := false


func set_facing(left: bool) -> void:
	facing_left = left


func set_attack_frame(frame: int) -> void:
	attack_frame = maxi(frame, 0)


func set_scoot_progress(progress: float) -> void:
	scoot_progress = clampf(progress, 0.0, 1.0)


func set_breathing(value: bool) -> void:
	breathing = value
