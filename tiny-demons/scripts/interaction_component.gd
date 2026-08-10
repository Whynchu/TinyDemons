extends Node
class_name InteractionComponent

signal availability_changed(available: bool)
signal interacted

var available := false
var prompt_timer := 0.0


func closest_target(player: Sprite2D, slimes: Array[Sprite2D], max_distance: float, actor_foot: Callable, is_dead: Callable) -> Sprite2D:
	var closest: Sprite2D = null
	var closest_distance := max_distance
	var player_foot: Vector2 = actor_foot.call(player)
	for slime in slimes:
		if bool(is_dead.call(slime)):
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
	if target != null and bool(root.call("_is_slime_dead", target)): root.call("_set_current_target", null); target = null
	var player := root.get("player") as Sprite2D
	if target != null and not bool(root.get("player_is_attacking")): player.flip_h = root.call("_actor_foot", target).x < root.call("_actor_foot", player).x
	root.call("_update_target_ui")


func update_world_prompt(root: Object, delta: float, bob_time: float, ui_z: int) -> void:
	update_prompt(delta, root.get("interact_prompt"), bool((root.get("npc_dialogue_box") as ColorRect) != null and (root.get("npc_dialogue_box") as ColorRect).visible), bool(root.call("_can_interact_with_chest")), bool(root.call("_can_interact_with_npc")), (root.get("chest") as Sprite2D).global_position, root.call("_cloaked_demon_head_position"), root.get("interact_prompt_base_position"), Callable(root, "_snap_half_pixel"), bob_time, ui_z)


func set_available(value: bool) -> void:
	if available == value:
		return
	available = value
	availability_changed.emit(available)


func interact() -> void:
	if available:
		interacted.emit()


func build_prompt(parent: Node, texture: Texture2D, ui_z: int) -> Sprite2D:
	var prompt := Sprite2D.new()
	prompt.name = "InteractPrompt"
	prompt.texture = texture
	prompt.scale = Vector2(1.5, 1.5)
	prompt.centered = false
	prompt.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	prompt.z_as_relative = false
	prompt.z_index = ui_z
	prompt.visible = false
	parent.add_child(prompt)
	return prompt


func update_prompt(delta: float, prompt: Sprite2D, dialogue_visible: bool, near_chest: bool, near_npc: bool, chest_position: Vector2, npc_head_position: Vector2, base_position: Vector2, snap_position: Callable, bob_time: float, ui_z: int) -> void:
	if prompt == null:
		return
	if dialogue_visible:
		prompt.visible = false
		return
	var should_show := near_chest or near_npc
	prompt.visible = should_show
	if not should_show:
		return
	prompt_timer = fmod(prompt_timer + delta, bob_time)
	var bob := snappedf(sin((prompt_timer / bob_time) * TAU) * 1.0, 0.5)
	if near_npc and not near_chest:
		var prompt_size := prompt.texture.get_size() * prompt.scale
		prompt.global_position = snap_position.call(npc_head_position + Vector2(-prompt_size.x * 0.5, -prompt_size.y - 2 + bob))
	else:
		prompt.global_position = snap_position.call(chest_position + base_position + Vector2(0, bob))
	prompt.z_index = ui_z
