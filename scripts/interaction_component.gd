extends Node
class_name InteractionComponent

var prompt_timer := 0.0


func closest_target(player: Sprite2D, slimes: Array[Sprite2D], max_distance: float, actor_foot: Callable, is_dead: Callable, is_targetable: Callable = Callable()) -> Sprite2D:
	var closest: Sprite2D = null
	var closest_distance := max_distance
	var player_foot: Vector2 = actor_foot.call(player)
	for slime in slimes:
		if bool(is_dead.call(slime)):
			continue
		if is_targetable.is_valid() and not bool(is_targetable.call(slime)):
			continue
		var distance := player_foot.distance_squared_to(actor_foot.call(slime))
		if distance < closest_distance:
			closest = slime
			closest_distance = distance
	return closest


func update_targeting(root: Object) -> void:
	var should_target := bool(root.call("_is_target_input_held"))
	if not should_target:
		root.call("_set_current_target", null); root.call("_set_target_ui_visible", false); root.set("target_input_was_down", false); return
	if not bool(root.get("target_input_was_down")):
		root.call("_set_current_target", root.call("_closest_target")); root.set("target_input_was_down", true)
	var target := root.get("current_target") as Sprite2D
	if target != null and not bool(root.call("_is_slime_targetable", target)): root.call("_set_current_target", null); target = null
	var player := root.get("player") as Sprite2D
	if target != null and not bool(root.get("player_is_attacking")): player.flip_h = root.call("_actor_foot", target).x < root.call("_actor_foot", player).x
	root.call("_update_target_ui")


func update_world_prompt(root: Object, delta: float, bob_time: float, ui_z: int) -> void:
	var chest := root.get("chest") as Sprite2D
	var chest_anchor := (root.call("_collision_rect", chest) as Rect2).get_center()
	var item := root.get("world_item_drop") as Sprite2D
	var near_item := bool(root.call("_can_interact_with_world_item"))
	var npc := root.get("npc_controller") as NpcController
	var dialogue_visible: bool = npc != null and npc.dialogue_box != null and npc.dialogue_box.visible
	update_prompt(delta, root.get("interact_prompt"), dialogue_visible, bool(root.call("_can_interact_with_chest")), bool(root.call("_can_interact_with_npc")), near_item, chest_anchor, root.call("_cloaked_demon_head_position"), item.global_position if item != null else Vector2.ZERO, Vector2(0, -13), Callable(root, "_snap_half_pixel"), bob_time, ui_z)


func build_prompt(parent: Node, texture: Texture2D, ui_z: int) -> Sprite2D:
	var prompt := Sprite2D.new()
	prompt.name = "InteractPrompt"
	prompt.texture = texture
	prompt.scale = Vector2.ONE
	prompt.centered = true
	prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt.z_as_relative = false
	prompt.z_index = ui_z
	prompt.visible = false
	parent.add_child(prompt)
	var highlight := Sprite2D.new()
	highlight.name = "InteractPromptHighlight"
	highlight.texture = _highlight_button_texture(texture)
	highlight.centered = true
	highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	highlight.z_as_relative = false
	highlight.z_index = ui_z - 1
	highlight.visible = false
	parent.add_child(highlight)
	return prompt


func _highlight_button_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var source_image := source.get_image()
	var image := Image.create(source_image.get_width() + 2, source_image.get_height() + 2, false, Image.FORMAT_RGBA8)
	for y in source_image.get_height():
		for x in source_image.get_width():
			var color := source_image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var sample_x: int = x + offset.x
				var sample_y: int = y + offset.y
				if sample_x < 0 or sample_y < 0 or sample_x >= source_image.get_width() or sample_y >= source_image.get_height() or source_image.get_pixel(sample_x, sample_y).a <= 0.0:
					image.set_pixel(x + 1 + offset.x, y + 1 + offset.y, Color.WHITE)
	return ImageTexture.create_from_image(image)


func update_prompt(delta: float, prompt: Sprite2D, dialogue_visible: bool, near_chest: bool, near_npc: bool, near_item: bool, chest_position: Vector2, npc_head_position: Vector2, item_position: Vector2, base_position: Vector2, snap_position: Callable, bob_time: float, ui_z: int) -> void:
	if prompt == null:
		return
	if dialogue_visible:
		prompt.visible = false
		var dialogue_highlight := prompt.get_parent().get_node_or_null("InteractPromptHighlight") as Sprite2D
		if dialogue_highlight != null: dialogue_highlight.visible = false
		return
	var should_show := near_chest or near_npc or near_item
	prompt.visible = should_show
	var highlight := prompt.get_parent().get_node_or_null("InteractPromptHighlight") as Sprite2D
	if highlight != null: highlight.visible = should_show
	if not should_show:
		return
	if highlight != null: highlight.global_position = prompt.global_position
	prompt_timer = fmod(prompt_timer + delta, bob_time)
	var bob := snappedf(sin((prompt_timer / bob_time) * TAU) * 0.5, 0.5)
	if near_item:
		var prompt_size := prompt.texture.get_size() * prompt.scale
		prompt.global_position = snap_position.call(item_position + Vector2(0, -15 - prompt_size.y * 0.5 + bob))
	elif near_npc and not near_chest:
		var prompt_size := prompt.texture.get_size() * prompt.scale
		prompt.global_position = snap_position.call(npc_head_position + Vector2(1, -prompt_size.y * 0.5 - 2 + bob))
	else:
		var prompt_size := prompt.texture.get_size() * prompt.scale
		prompt.global_position = snap_position.call(chest_position + base_position + Vector2(0, -prompt_size.y * 0.5) + Vector2(0, bob))
	prompt.z_index = ui_z
	if highlight != null:
		highlight.global_position = prompt.global_position
		highlight.z_index = ui_z - 1
