extends Node
class_name RestFireController

signal rest_requested
var animation_timer := 0.0
var frame_index := 0


func request_rest() -> void:
	rest_requested.emit()


func reset_animation() -> void:
	animation_timer = 0.0
	frame_index = 0


func update_animation(fire: Sprite2D, frames: Array[Texture2D], delta: float, frame_time: float, refresh_image: Callable) -> void:
	if fire == null or not fire.visible or frames.is_empty():
		return
	animation_timer += delta
	while animation_timer >= frame_time:
		animation_timer -= frame_time
		frame_index = (frame_index + 1) % frames.size()
		fire.texture = frames[frame_index]
		fire.hframes = 1
		fire.frame = 0
		refresh_image.call(fire)
