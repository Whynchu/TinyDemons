extends RefCounted
class_name StatusContactPair

var first: Sprite2D
var second: Sprite2D


func configure(first_actor: Sprite2D, second_actor: Sprite2D) -> void:
	first = first_actor
	second = second_actor
