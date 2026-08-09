extends Node
class_name DepthSorter

var sprites: Array[Sprite2D] = []


func set_sprites(new_sprites: Array[Sprite2D]) -> void:
	sprites = new_sprites.duplicate()


func depth_key(_sprite: Sprite2D, foot_y: float) -> float:
	return foot_y


func z_index_for(sprite: Sprite2D, foot_y: float, scale: float) -> int:
	return int(round(depth_key(sprite, foot_y) * scale))
