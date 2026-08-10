extends Node
class_name NpcController

var full_message := ""
var character_index := 0
var type_timer := 0.0
var button_timer := 0.0
var dialogue_complete := false

signal dialogue_requested


func request_dialogue() -> void:
	dialogue_requested.emit()
func begin_dialogue(message: String) -> void:
	full_message = message
	character_index = 0
	type_timer = 0.0
	button_timer = 0.0
	dialogue_complete = false


func end_dialogue() -> void:
	full_message = ""
	character_index = 0
	type_timer = 0.0
	button_timer = 0.0
	dialogue_complete = false


func update_dialogue(delta: float, box: ColorRect, text: Sprite2D, button: Sprite2D, button_shadow: Sprite2D, head_position: Vector2, pixel_texture: Callable, snap_position: Callable, type_interval: float, button_bob_time: float) -> void:
	if box == null or not box.visible:
		return
	if not dialogue_complete:
		type_timer += delta
		while type_timer >= type_interval and character_index < full_message.length():
			type_timer -= type_interval
			character_index += 1
			text.texture = pixel_texture.call(full_message.substr(0, character_index), Color.WHITE) as Texture2D
		if character_index >= full_message.length():
			dialogue_complete = true
			button.visible = true
	var full_text_texture := pixel_texture.call(full_message, Color.WHITE) as Texture2D
	var box_size := full_text_texture.get_size() + Vector2(10, 10)
	var box_position := snap_position.call(head_position + Vector2(-box_size.x * 0.5, -box_size.y - 6)) as Vector2
	box.position = box_position
	box.size = box_size
	text.position = snap_position.call(box_position + Vector2(5, 5))
	if button.visible:
		button_timer = fmod(button_timer + delta, button_bob_time)
		var button_bob := snappedf(sin((button_timer / button_bob_time) * TAU) * 0.5, 0.5)
		var button_size := button.texture.get_size()
		var button_position := snap_position.call(box_position + box_size - button_size * 0.5 + Vector2(0, -1)) as Vector2
		button.position = button_position + Vector2(0, button_bob)
		button_shadow.position = button_position + Vector2(0, button_bob) + Vector2(-0.5, 0.5)
		button_shadow.visible = true
	else:
		button_shadow.visible = false
