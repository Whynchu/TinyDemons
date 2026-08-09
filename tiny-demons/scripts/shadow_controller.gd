extends Node
class_name ShadowController

var shadow_sprites: Array[Sprite2D] = []


func set_shadows(new_shadows: Array[Sprite2D]) -> void:
	shadow_sprites = new_shadows.duplicate()


func register_shadow(shadow: Sprite2D) -> void:
	if not shadow_sprites.has(shadow):
		shadow_sprites.append(shadow)
