extends Node
class_name ChestController

signal unlocked
signal reward_claimed

var unlocked_state := false
var claimed := false
var unlock_fade_timer := 0.0
var flame_hold_timer := 0.0
var flame_hold_active := false
var flame_action_resolved := false

const FLAME_FUSION_HOLD_THRESHOLD := 0.35


func update_interaction(root: Object, interact_input_down: bool, interact_input_was_down: bool, reward_gold: int, flash_time: float, delta: float = 0.0) -> void:
	var interact_pressed := interact_input_down and not interact_input_was_down
	var near_fire := bool(root.call("_can_interact_with_fire"))
	if flame_hold_active:
		if not interact_input_down or not near_fire:
			# A short press is resolved on release so the same input can safely
			# distinguish Swap from the longer Fuse gesture.
			if not interact_input_down and not flame_action_resolved and near_fire:
				root.call("_interact_with_fire")
			_reset_flame_gesture()
		elif not flame_action_resolved:
			flame_hold_timer += maxf(delta, 0.0)
			var hold_threshold := float(root.get("FLAME_FUSION_HOLD_THRESHOLD"))
			if hold_threshold <= 0.0:
				hold_threshold = FLAME_FUSION_HOLD_THRESHOLD
			if flame_hold_timer >= hold_threshold:
				if bool(root.call("_can_fuse_with_fire")):
					root.call("_fuse_with_fire")
				else:
					var target_palette := str(root.call("_fire_target_palette"))
					var feedback_color := Color.WHITE
					if not target_palette.is_empty():
						feedback_color = root.call("_health_feedback_color", target_palette) as Color
					root.call("_show_fire_exchange_text", "NO FUSION", feedback_color)
					root.call("_play_sound", "ui_no_input", 0.0, 1.0)
				flame_action_resolved = true
		root.set("interact_input_was_down", interact_input_down)
		return
	if interact_pressed:
		var chest := root.get("chest") as Sprite2D
		if bool(root.get("chest_unlocked")) and not bool(root.get("chest_claimed")) and bool(root.call("_can_interact_with_chest")):
			root.set("chest_claimed", true)
			var room_controller := root.get("room_controller") as RoomController
			var state := room_controller.room_states.get(root.get("current_room_id"), {}) as Dictionary
			room_controller.save_treasure_chest_state(root)
			if not bool(state.get("item_rewarded", false)):
				state["item_rewarded"] = bool(root.call("_grant_chest_item_reward"))
			room_controller.room_states[root.get("current_room_id")] = state
			root.set("chest_collect_flash_timer", flash_time); start_flash(root)
			var scaled_gold := int(root.call("_chest_gold_reward", reward_gold))
			var profile := root.get("player_profile") as PlayerProfile
			var current_gold := profile.gold if profile != null else 0
			root.call("_set_gold_value", current_gold + scaled_gold)
			(root.get("effects_spawner") as EffectsSpawner).spawn_gold_from_root(root, chest.global_position + Vector2(5, -8), scaled_gold)
			# The claim is a safe, idempotent room-state boundary. Persist it before
			# the presentation flash so a browser restart cannot replay the reward.
			root.call("_checkpoint_safe_run_state")
			root.call("_play_sound", "chest_reward", -3.0, 1.0)
			print("Gold: %d" % (current_gold + scaled_gold))
		elif near_fire:
			flame_hold_active = true
			flame_hold_timer = 0.0
			flame_action_resolved = false
		elif bool(root.call("_can_interact_with_npc")):
			(root.get("npc_controller") as NpcController).show_dialogue(root)
		elif bool(root.call("_can_interact_with_world_item")):
			root.call("_collect_world_item_drop")
	root.set("interact_input_was_down", interact_input_down)


func _reset_flame_gesture() -> void:
	flame_hold_timer = 0.0
	flame_hold_active = false
	flame_action_resolved = false


func unlock() -> void:
	if not unlocked_state:
		unlocked_state = true
		unlocked.emit()


func claim_reward() -> void:
	if unlocked_state and not claimed:
		claimed = true
		reward_claimed.emit()


func start_flash(root: Object) -> void:
	var old_overlay := root.get("chest_flash_overlay") as Sprite2D; if old_overlay != null: old_overlay.queue_free()
	var chest := root.get("chest") as Sprite2D; var overlay := Sprite2D.new(); overlay.name = "ChestFlashOverlay"; overlay.texture = root.call("_white_texture", chest.texture); overlay.centered = chest.centered; overlay.offset = chest.offset; overlay.scale = chest.scale; overlay.flip_h = chest.flip_h; overlay.texture_filter = chest.texture_filter; overlay.z_as_relative = false; overlay.z_index = chest.z_index + 1; overlay.global_position = chest.global_position; overlay.modulate = Color.WHITE; root.add_child(overlay); root.set("chest_flash_overlay", overlay)


func start_unlock_fade(root: Object) -> void:
	var old_overlay := root.get("chest_unlock_overlay") as Sprite2D; if old_overlay != null: old_overlay.queue_free()
	var chest := root.get("chest") as Sprite2D; var normal_texture := root.get("chest_normal_texture") as Texture2D; chest.texture = root.get("chest_gray_texture"); chest.visible = true; begin_unlock_fade(float(root.get("CHEST_UNLOCK_FADE_TIME")))
	var overlay := Sprite2D.new(); overlay.name = "ChestUnlockOverlay"; overlay.texture = normal_texture; overlay.centered = chest.centered; overlay.offset = chest.offset; overlay.scale = chest.scale; overlay.flip_h = chest.flip_h; overlay.texture_filter = chest.texture_filter; overlay.z_as_relative = false; overlay.z_index = chest.z_index + 1; overlay.global_position = chest.global_position; overlay.self_modulate = Color.WHITE; overlay.modulate = Color(1, 1, 1, 0); root.add_child(overlay); root.set("chest_unlock_overlay", overlay)


func update_visuals_from_root(root: Object, delta: float) -> void:
	root.call("_update_interact_prompt", delta)
	var overlay := root.get("chest_unlock_overlay") as Sprite2D
	if overlay != null and update_unlock_fade(delta, root.get("chest") as Sprite2D, overlay, root.get("chest_normal_texture"), float(root.get("CHEST_UNLOCK_FADE_TIME"))):
		var renderer := root.get("occlusion_renderer") as OcclusionRenderer; var chest := root.get("chest") as Sprite2D; renderer.sprite_images[chest] = renderer.cached_texture_image(root.get("chest_normal_texture")); overlay.queue_free(); root.set("chest_unlock_overlay", null)
	var flash_timer := float(root.get("chest_collect_flash_timer"))
	if flash_timer > 0.0:
		flash_timer = maxf(flash_timer - delta, 0.0); root.set("chest_collect_flash_timer", flash_timer); var flash := root.get("chest_flash_overlay") as Sprite2D; var chest := root.get("chest") as Sprite2D
		if flash != null: flash.global_position = chest.global_position; flash.z_index = chest.z_index + 1; flash.modulate = Color(1, 1, 1, 1.0 - flash_timer / float(root.get("CHEST_COLLECT_FLASH_TIME")))
		if flash_timer <= 0.0 and not bool(root.get("chest_evaporated")): start_evaporation(root)
	elif not bool(root.get("chest_claimed")): root.call("_apply_chest_map_tint")


func start_evaporation(root: Object) -> void:
	root.set("chest_evaporated", true); var room_controller := root.get("room_controller") as RoomController; if room_controller != null: room_controller.save_treasure_chest_state(root); (root.get("effects_spawner") as EffectsSpawner).spawn_chest_evaporation_from_root(root); (root.get("chest") as Sprite2D).visible = false; root.call("_set_door_active", true); root.call("_set_entrance_open", true)
	var overlay := root.get("chest_flash_overlay") as Sprite2D; if overlay != null: overlay.queue_free(); root.set("chest_flash_overlay", null)
	var chest := root.get("chest") as Sprite2D; (root.get("collision_sprites") as Array[Sprite2D]).erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest); var prompt := root.get("interact_prompt") as Sprite2D; if prompt != null: prompt.visible = false
	if root.has_method("_on_chest_collected"):
		root.call("_on_chest_collected")


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
