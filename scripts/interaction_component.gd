extends Node
class_name InteractionComponent

## Editor-facing targeting tuning.
@export var prompt_bob_time := 1.0

var prompt_timer := 0.0
var target_cycle_axis := 0


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


func target_facing_left(context: InteractionContext, target: Sprite2D) -> bool:
	var player := context.player
	if player == null or target == null:
		return false
	var player_foot: Vector2 = context.actor_foot.call(player)
	var target_foot: Vector2 = context.actor_foot.call(target)
	return target_foot.x < player_foot.x


func target_is_in_front(context: InteractionContext, target_position: Vector2) -> bool:
	var player := context.player
	if player == null:
		return false
	var player_foot: Vector2 = context.actor_foot.call(player)
	var offset := target_position - player_foot
	if offset.length_squared() <= 0.0001:
		return true
	var facing := Vector2.LEFT if player.flip_h else Vector2.RIGHT
	if context.player_facing_vector.is_valid():
		var facing_value: Variant = context.player_facing_vector.call()
		if facing_value is Vector2 and (facing_value as Vector2).length_squared() > 0.0001:
			facing = facing_value as Vector2
	return facing.normalized().dot(offset.normalized()) >= 0.0


func update_targeting(context: InteractionContext) -> void:
	var should_target := bool(context.is_target_input_held.call())
	if not should_target:
		context.set_current_target.call(null); context.set_target_ui_visible.call(false); context.target_input_was_down_set.call(false); target_cycle_axis = 0; return
	if not bool(context.target_input_was_down_get.call()):
		context.set_current_target.call(context.closest_target.call()); context.target_input_was_down_set.call(true)
	var target := context.valid_current_target.call() as Sprite2D
	if target != null and not bool(context.is_slime_targetable.call(target)): context.set_current_target.call(null); target = null
	var cycle_direction := int(context.target_cycle_direction.call())
	if cycle_direction != 0 and cycle_direction != target_cycle_axis:
		context.cycle_target.call(cycle_direction)
	target_cycle_axis = cycle_direction
	target = context.valid_current_target.call() as Sprite2D
	var player := context.player
	if not bool(context.player_is_attacking_get.call()) and not bool(context.player_is_magic_casting_get.call()):
		if target != null:
			var target_left := target_facing_left(context, target)
			# Targeting owns the complete kit's horizontal facing, including while
			# the player is holding shield and moving backwards. Keep the selected
			# target direction as the persistent facing when lock-on is released.
			player.flip_h = target_left
			context.last_player_facing_left_set.call(target_left)
		else:
			# Lock the facing the player had when they pressed lock-on, even with
			# no target to stare at, so the lock keeps them looking that way.
			player.flip_h = context.last_player_facing_left_get.call() == true
	context.update_target_ui.call()


func update_world_prompt(context: InteractionContext, delta: float, bob_time: float, ui_z: int) -> void:
	var chest := context.chest
	var chest_anchor := (context.collision_rect.call(chest) as Rect2).get_center()
	var near_item := bool(context.can_interact_with_world_item.call())
	var item_position: Vector2 = context.world_item_drop_position.call()
	var npc := context.npc_controller
	var dialogue_visible: bool = npc != null and npc.dialogue_box != null and npc.dialogue_box.visible
	update_prompt(delta, context.interact_prompt, dialogue_visible, bool(context.can_interact_with_chest.call()), bool(context.can_interact_with_npc.call()), near_item, bool(context.can_interact_with_fire.call()), chest_anchor, context.cloaked_demon_head_position.call(), item_position, context.fire_anchor.call(), Vector2(0, -13), context.snap_half_pixel, bob_time, ui_z)


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


func set_prompt_texture(prompt: Sprite2D, texture: Texture2D) -> void:
	if prompt == null or texture == null:
		return
	if prompt.texture == texture:
		return
	prompt.texture = texture
	var highlight := prompt.get_parent().get_node_or_null("InteractPromptHighlight") as Sprite2D
	if highlight != null:
		highlight.texture = _highlight_button_texture(texture)


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


func update_prompt(delta: float, prompt: Sprite2D, dialogue_visible: bool, near_chest: bool, near_npc: bool, near_item: bool, near_fire: bool, chest_position: Vector2, npc_head_position: Vector2, item_position: Vector2, fire_position: Vector2, base_position: Vector2, snap_position: Callable, bob_time: float, ui_z: int) -> void:
	if prompt == null:
		return
	var fire_cost := prompt.get_node_or_null("FireCost") as Sprite2D
	if dialogue_visible:
		prompt.visible = false
		var dialogue_highlight := prompt.get_parent().get_node_or_null("InteractPromptHighlight") as Sprite2D
		if dialogue_highlight != null: dialogue_highlight.visible = false
		if fire_cost != null: fire_cost.visible = false
		return
	var should_show := near_chest or near_npc or near_item or near_fire
	prompt.visible = should_show
	var highlight := prompt.get_parent().get_node_or_null("InteractPromptHighlight") as Sprite2D
	if highlight != null: highlight.visible = should_show
	if fire_cost != null:
		fire_cost.visible = should_show and near_fire
		if fire_cost.visible:
			var prompt_size := prompt.texture.get_size() * prompt.scale
			var cost_size := fire_cost.texture.get_size() * fire_cost.scale if fire_cost.texture != null else Vector2(5, 5)
			fire_cost.position = Vector2(0, -prompt_size.y * 0.5 - cost_size.y * 0.5 - 1.0)
	if not should_show:
		return
	if highlight != null: highlight.global_position = prompt.global_position
	prompt_timer = fmod(prompt_timer + delta, bob_time)
	var bob := snappedf(sin((prompt_timer / bob_time) * TAU) * 0.5, 0.5)
	if near_item:
		var prompt_size := prompt.texture.get_size() * prompt.scale
		prompt.global_position = snap_position.call(item_position + Vector2(0, -15 - prompt_size.y * 0.5 + bob))
	elif near_npc and not near_chest and not near_fire:
		var prompt_size := prompt.texture.get_size() * prompt.scale
		prompt.global_position = snap_position.call(npc_head_position + Vector2(1, -prompt_size.y * 0.5 - 2 + bob))
	elif near_fire and not near_chest:
		var prompt_size := prompt.texture.get_size() * prompt.scale
		prompt.global_position = snap_position.call(fire_position + Vector2(0, -prompt_size.y * 0.5 - 12 + bob))
	else:
		var prompt_size := prompt.texture.get_size() * prompt.scale
		prompt.global_position = snap_position.call(chest_position + base_position + Vector2(0, -prompt_size.y * 0.5) + Vector2(0, bob))
	prompt.z_index = ui_z
	if highlight != null:
		highlight.global_position = prompt.global_position
		highlight.z_index = ui_z - 1
