extends Node
class_name ChestController

signal unlocked
signal reward_claimed

var unlocked_state := false
var claimed := false
var unlock_fade_timer := 0.0


func unlock() -> void:
	if not unlocked_state:
		unlocked_state = true
		unlocked.emit()


func claim_reward() -> void:
	if unlocked_state and not claimed:
		claimed = true
		reward_claimed.emit()


func begin_unlock_fade(duration: float) -> void:
	unlock_fade_timer = duration


func update_unlock_fade(delta: float, chest: Sprite2D, overlay: Sprite2D, normal_texture: Texture2D, duration: float) -> bool:
	if overlay == null:
		return false
	unlock_fade_timer = maxf(unlock_fade_timer - delta, 0.0)
	overlay.global_position = chest.global_position
	overlay.z_index = chest.z_index + 1
	overlay.modulate = Color(1, 1, 1, 1.0 - unlock_fade_timer / duration)
	if unlock_fade_timer <= 0.0:
		chest.texture = normal_texture
		return true
	return false
