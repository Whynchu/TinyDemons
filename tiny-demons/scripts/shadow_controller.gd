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


func update_player_shadow(root: Object, depth_scale: float) -> void:
	var player := root.get("player") as Sprite2D; var shadow := root.get("player_shadow") as Sprite2D
	shadow.global_position = player.global_position + root.get("player_shadow_offset"); shadow.global_scale = root.get("player_shadow_scale"); shadow.self_modulate = Color(1, 1, 1, 0.25); shadow.flip_h = player.flip_h; shadow.z_index = z_index_for(root.call("_actor_foot", player).y, depth_scale)
	var sprite_shadow := root.get("player_sprite_shadow") as Sprite2D
	if sprite_shadow != null:
		var source: Sprite2D = root.get("player_attack_visual") if bool(root.get("player_is_attacking")) else player
		sprite_shadow.texture = source.texture; sprite_shadow.global_position = source.global_position + Vector2(-0.5, 0.0); sprite_shadow.offset = source.offset; sprite_shadow.scale = source.scale; sprite_shadow.flip_h = source.flip_h; sprite_shadow.visible = source.visible and source.texture != null; sprite_shadow.z_index = source.z_index - 1


func update_cloaked_demon_shadow(root: Object, depth_scale: float) -> void:
	var demon := root.get("cloaked_demon") as Sprite2D; var shadow := root.get("cloaked_demon_shadow") as Sprite2D
	if shadow == null: return
	shadow.visible = demon.visible
	var sprite_shadow := root.get("cloaked_demon_sprite_shadow") as Sprite2D
	if sprite_shadow != null: sprite_shadow.visible = demon.visible
	if not demon.visible: return
	shadow.global_position = demon.global_position + root.get("cloaked_demon_shadow_offset"); shadow.global_scale = root.get("cloaked_demon_shadow_scale"); shadow.flip_h = demon.flip_h; shadow.self_modulate = Color(1, 1, 1, 0.25); shadow.z_index = z_index_for(root.call("_cloaked_demon_foot_position").y, depth_scale)
	if sprite_shadow != null: sprite_shadow.texture = demon.texture; sprite_shadow.global_position = demon.global_position + Vector2(-0.5, 0.0); sprite_shadow.offset = demon.offset; sprite_shadow.scale = demon.scale; sprite_shadow.flip_h = demon.flip_h; sprite_shadow.visible = demon.texture != null; sprite_shadow.z_index = demon.z_index - 1
