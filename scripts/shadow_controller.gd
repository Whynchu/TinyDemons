extends Node
class_name ShadowController


func z_index_for(foot_y: float, depth_scale: float) -> int:
	return int(round(foot_y * depth_scale)) - 1


func update_player_shadow(root: Object, depth_scale: float) -> void:
	var player := root.get("player") as Sprite2D; var shadow := root.get("player_shadow") as Sprite2D; var attack_visual := root.get("player_attack_visual") as Sprite2D
	if shadow == null: return
	shadow.visible = player.visible or (attack_visual != null and attack_visual.visible)
	shadow.global_position = player.global_position + root.get("player_shadow_offset"); shadow.global_scale = root.get("player_shadow_scale"); shadow.self_modulate = Color(1, 1, 1, 0.25); shadow.flip_h = player.flip_h; shadow.z_index = z_index_for(root.call("_actor_foot", player).y, depth_scale)
	var sprite_shadow := root.get("player_sprite_shadow") as Sprite2D
	if sprite_shadow != null:
		var source: Sprite2D = root.get("player_attack_visual") if bool(root.get("player_is_attacking")) else player
		_sync_sprite_shadow(sprite_shadow, source, Vector2(-0.5, 0.0))


func sync_player_attack_shadow(root: Object, depth_scale: float) -> void:
	# Attack1 swaps from the base player sprite to a separate render layer in
	# the middle of input processing. Refresh both shadow layers immediately so
	# a grey/empty-MP attack cannot render the previous idle or attack frame.
	update_player_shadow(root, depth_scale)


func update_cloaked_demon_shadow(root: Object, depth_scale: float) -> void:
	var demon := root.get("cloaked_demon") as Sprite2D; var shadow := root.get("cloaked_demon_shadow") as Sprite2D
	if shadow == null: return
	shadow.visible = demon.visible
	var sprite_shadow := root.get("cloaked_demon_sprite_shadow") as Sprite2D
	if sprite_shadow != null: sprite_shadow.visible = demon.visible
	if not demon.visible: return
	shadow.global_position = demon.global_position + root.get("cloaked_demon_shadow_offset"); shadow.global_scale = root.get("cloaked_demon_shadow_scale"); shadow.flip_h = demon.flip_h; shadow.self_modulate = Color(1, 1, 1, 0.25); shadow.z_index = z_index_for(root.call("_cloaked_demon_foot_position").y, depth_scale)
	if sprite_shadow != null: _sync_sprite_shadow(sprite_shadow, demon, Vector2(-0.5, 0.0))


func _sync_sprite_shadow(sprite_shadow: Sprite2D, source: Sprite2D, offset: Vector2) -> void:
	# A drop shadow follows the source frame, but it must not inherit the source
	# material. The player and attack layers can carry the MP desaturation shader;
	# copying that material makes this layer render as a normal-colour duplicate
	# instead of the black silhouette used by the sword/shield shadows.
	sprite_shadow.texture = source.texture
	sprite_shadow.material = null
	sprite_shadow.self_modulate = Color(0.0, 0.0, 0.0, 0.25)
	sprite_shadow.global_position = source.global_position + offset
	sprite_shadow.offset = source.offset
	sprite_shadow.scale = source.scale
	sprite_shadow.flip_h = source.flip_h
	sprite_shadow.modulate.a = source.modulate.a
	sprite_shadow.visible = source.visible and source.texture != null
	sprite_shadow.z_index = source.z_index - 1
