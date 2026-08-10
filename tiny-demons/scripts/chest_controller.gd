extends Node
class_name ChestController

signal unlocked
signal reward_claimed

var unlocked_state := false
var claimed := false
var unlock_fade_timer := 0.0


func update_interaction(root: Object, interact_input_down: bool, interact_input_was_down: bool, reward_gold: int, flash_time: float) -> void:
	if interact_input_down and not interact_input_was_down:
		var chest := root.get("chest") as Sprite2D
		if bool(root.get("chest_unlocked")) and not bool(root.get("chest_claimed")) and bool(root.call("_can_interact_with_chest")):
			root.set("chest_claimed", true)
			var room_controller := root.get("room_controller") as RoomController
			var state := room_controller.room_states.get(root.get("current_room_id"), {}) as Dictionary
			state["finished"] = true; room_controller.room_states[root.get("current_room_id")] = state
			root.set("chest_collect_flash_timer", flash_time); root.call("_start_chest_flash")
			root.set("gold", int(root.get("gold")) + reward_gold); root.call("_update_gold_indicator")
			root.call("_spawn_gold_number", chest.global_position + Vector2(5, -8), reward_gold)
			print("Gold: %d" % int(root.get("gold")))
		elif bool(root.call("_can_interact_with_npc")):
			root.call("_show_npc_dialogue")
	root.set("interact_input_was_down", interact_input_down)


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
