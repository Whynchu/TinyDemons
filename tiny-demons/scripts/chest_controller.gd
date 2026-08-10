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
			root.set("chest_collect_flash_timer", flash_time); start_flash(root)
			root.set("gold", int(root.get("gold")) + reward_gold); root.call("_update_gold_indicator")
			(root.get("effects_spawner") as EffectsSpawner).spawn_gold_from_root(root, chest.global_position + Vector2(5, -8), reward_gold)
			print("Gold: %d" % int(root.get("gold")))
		elif bool(root.call("_can_interact_with_npc")):
			(root.get("npc_controller") as NpcController).show_dialogue(root)
	root.set("interact_input_was_down", interact_input_down)


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
	var chest := root.get("chest") as Sprite2D; var overlay := Sprite2D.new(); overlay.name = "ChestFlashOverlay"; overlay.texture = root.call("_white_texture", chest.texture); overlay.centered = chest.centered; overlay.offset = chest.offset; overlay.scale = chest.scale; overlay.texture_filter = chest.texture_filter; overlay.z_as_relative = false; overlay.z_index = chest.z_index + 1; overlay.global_position = chest.global_position; overlay.modulate = Color.WHITE; root.add_child(overlay); root.set("chest_flash_overlay", overlay)


func start_unlock_fade(root: Object) -> void:
	var old_overlay := root.get("chest_unlock_overlay") as Sprite2D; if old_overlay != null: old_overlay.queue_free()
	var chest := root.get("chest") as Sprite2D; var normal_texture := root.get("chest_normal_texture") as Texture2D; chest.texture = root.get("chest_gray_texture"); chest.visible = true; begin_unlock_fade(float(root.get("CHEST_UNLOCK_FADE_TIME")))
	var overlay := Sprite2D.new(); overlay.name = "ChestUnlockOverlay"; overlay.texture = normal_texture; overlay.centered = chest.centered; overlay.offset = chest.offset; overlay.scale = chest.scale; overlay.texture_filter = chest.texture_filter; overlay.z_as_relative = false; overlay.z_index = chest.z_index + 1; overlay.global_position = chest.global_position; overlay.modulate = Color(1, 1, 1, 0); root.add_child(overlay); root.set("chest_unlock_overlay", overlay)


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
	elif not bool(root.get("chest_claimed")): (root.get("chest") as Sprite2D).self_modulate = Color.WHITE


func start_evaporation(root: Object) -> void:
	root.set("chest_evaporated", true); (root.get("effects_spawner") as EffectsSpawner).spawn_chest_evaporation_from_root(root); (root.get("chest") as Sprite2D).visible = false; root.call("_set_door_active", true); root.call("_set_entrance_open", true)
	var overlay := root.get("chest_flash_overlay") as Sprite2D; if overlay != null: overlay.queue_free(); root.set("chest_flash_overlay", null)
	var chest := root.get("chest") as Sprite2D; (root.get("collision_sprites") as Array[Sprite2D]).erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest); var prompt := root.get("interact_prompt") as Sprite2D; if prompt != null: prompt.visible = false


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
