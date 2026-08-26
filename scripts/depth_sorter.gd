extends Node
class_name DepthSorter

var sprites: Array[Sprite2D] = []


func set_sprites(new_sprites: Array[Sprite2D]) -> void:
	sprites = new_sprites.duplicate()


func depth_key(_sprite: Sprite2D, foot_y: float) -> float:
	return foot_y


func z_index_for(sprite: Sprite2D, foot_y: float, scale: float) -> int:
	return int(round(depth_key(sprite, foot_y) * scale))


func visible_lists(player: Sprite2D, slimes: Array[Sprite2D], chest: Sprite2D, rest_fire: Sprite2D, cloaked_demon: Sprite2D, is_dead: Callable) -> Dictionary:
	var depth: Array[Sprite2D] = [player]
	# Moving combat actors cross one another through foot-based depth sorting.
	# They must not enter the per-pixel cover pipeline, whose cost otherwise
	# multiplies across every player equipment layer and every enemy.
	var occluders: Array[Sprite2D] = []
	for slime in slimes:
		if is_dead.call(slime):
			continue
		depth.append(slime)
	if chest.visible:
		depth.append(chest)
	if rest_fire.visible:
		depth.append(rest_fire)
		occluders.append(rest_fire)
	if cloaked_demon.visible:
		depth.append(cloaked_demon)
		occluders.append(cloaked_demon)
	return {"depth": depth, "occluders": occluders}
