extends Node
class_name SlimeAnimationComponent

@export var facing_left := false
@export var attack_frame := 0


func set_facing(left: bool) -> void:
	facing_left = left


func set_attack_frame(frame: int) -> void:
	attack_frame = maxi(frame, 0)
