extends Node
class_name ShadowController

var shadow_sprites: Array[Sprite2D] = []


func set_shadows(new_shadows: Array[Sprite2D]) -> void:
	shadow_sprites = new_shadows.duplicate()


func register_shadow(shadow: Sprite2D) -> void:
	if not shadow_sprites.has(shadow):
		shadow_sprites.append(shadow)


func z_index_for(foot_y: float, depth_scale: float) -> int:
	return int(round(foot_y * depth_scale)) - 1
