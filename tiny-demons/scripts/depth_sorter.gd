extends Node
class_name DepthSorter

var sprites: Array[Sprite2D] = []


func set_sprites(new_sprites: Array[Sprite2D]) -> void:
	sprites = new_sprites.duplicate()


func depth_key(_sprite: Sprite2D, foot_y: float) -> float:
	return foot_y
