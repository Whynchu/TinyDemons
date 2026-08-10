extends Node
class_name InteractionComponent

signal availability_changed(available: bool)
signal interacted

var available := false
var prompt_timer := 0.0


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
