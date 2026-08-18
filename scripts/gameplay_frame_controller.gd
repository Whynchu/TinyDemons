extends Node
class_name GameplayFrameController


func update_player_input(root: Object) -> void:
	var attack_down: bool = root.call("_is_attack_input_pressed"); var attack := root.get("player_attack_component") as PlayerAttackComponent
	if attack_down and not bool(root.get("player_attack_input_was_down")):
		var accepted_attack := false
		if not bool(root.get("player_is_attacking")) and not bool(root.get("player_is_rolling")) and not bool(root.get("player_is_defending")) and (attack == null or attack.can_start_attack2()):
			if float(root.get("player_between_timer")) > 0.0:
				if attack != null and not attack.combo_buffered:
					attack.buffer_combo((root.get("player_tuning") as PlayerTuning).combo_window); attack.set_combo_movement(root.call("_movement_input")); accepted_attack = true
			elif attack != null:
				attack.start_player_attack(root, 1); accepted_attack = true
		elif bool(root.get("player_is_attacking")) and root.get("player_anim_name") == "attack1" and attack != null and not attack.combo_buffered:
			attack.buffer_combo((root.get("player_tuning") as PlayerTuning).combo_window); attack.set_combo_movement(root.call("_movement_input")); accepted_attack = true
		root.call("_record_run_action_input", &"attack", accepted_attack)
	root.set("player_attack_input_was_down", attack_down)
	var roll_down: bool = root.call("_is_roll_input_pressed")
	if roll_down and not bool(root.get("player_roll_input_was_down")):
		var accepted_roll := false
		if not bool(root.get("player_is_attacking")) and not bool(root.get("player_is_rolling")) and not bool(root.get("player_is_defending")) and (root.get("player_motor") == null or not (root.get("player_motor") as ActorMotor).is_in_knockback()):
			var roll := root.get("player_roll_component") as PlayerRollComponent
			if roll != null:
				roll.start_from_root(root); accepted_roll = true
		root.call("_record_run_action_input", &"roll", accepted_roll)
	root.set("player_roll_input_was_down", roll_down)


func tick(root: Object, delta: float) -> void:
	var attack := root.get("player_attack_component") as PlayerAttackComponent
	if attack != null: attack.tick_combo(delta); attack.tick_attack2_cooldown(delta)
	if (root.get("walkable_outline") as PackedVector2Array).is_empty(): return
	if bool(root.get("scene_transition_active")):
		var transition_timer: float = root.get("scene_transition_timer") + delta; root.set("scene_transition_timer", transition_timer)
		(root.get("scene_transition_overlay") as ColorRect).modulate.a = clampf(transition_timer / 0.28, 0.0, 1.0)
		if transition_timer >= 0.34: root.get_tree().reload_current_scene()
		return
	var ssc := root.get("screen_state_controller") as ScreenStateController
	if ssc.save_select_overlay != null and ssc.save_select_overlay.visible:
		if bool(root.call("_is_menu_cancel_input_pressed")):
			if ssc.save_overwrite_prompt_active: root.call("_cancel_overwrite")
			else: root.call("_close_save_select")
			return
		if ssc.menu_input_release_lock:
			if not bool(root.call("_is_interact_input_pressed")) and not Input.is_action_pressed("ui_accept"):
				ssc.menu_input_release_lock = false
			else:
				return
		if ssc.save_overwrite_prompt_active:
			var choice := ssc.save_overwrite_choice
			if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
				ssc.save_overwrite_choice = 1 - choice; root.call("_update_overwrite_cursor"); root.call("_play_sound", "ui_hover", -6.0, 1.0)
			elif bool(root.call("_is_interact_input_pressed")) or Input.is_action_just_pressed("ui_accept"):
				root.call("_play_sound", "ui_confirm", 0.0, 1.0)
				if choice == 0: (ssc.save_select_overlay.get_node("OverwriteYes") as Button).pressed.emit()
				else: (ssc.save_select_overlay.get_node("OverwriteNo") as Button).pressed.emit()
			return
		var slot := ssc.save_select_index
		if Input.is_action_just_pressed("ui_up"): slot -= 1
		elif Input.is_action_just_pressed("ui_down"): slot += 1
		if slot != ssc.save_select_index:
			ssc.save_select_index = posmod(slot, ProfileSaveService.SLOT_COUNT)
			root.call("_update_save_select_cursor")
			root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif bool(root.call("_is_interact_input_pressed")) or Input.is_action_just_pressed("ui_accept"):
			root.call("_play_sound", "ui_confirm", 0.0, 1.0)
			for child in ssc.save_select_overlay.get_children():
				if child is Button and child.has_meta("save_slot") and int(child.get_meta("save_slot")) == ssc.save_select_index:
					(child as Button).pressed.emit()
					break
		return
	var title_overlay := ssc.title_overlay; var archetype_overlay := ssc.archetype_overlay
	if ssc.title_transition_active or (title_overlay != null and title_overlay.visible) or (archetype_overlay != null and archetype_overlay.visible):
		root.call("_update_title_screen", delta)
		if ssc.title_transition_active and ssc.title_transition_timer < 0.72: return
		if not ssc.title_transition_active: return
	if bool(root.get("loading_screen_active")): root.call("_update_loading_screen", delta); return
	var hub_overlay := ssc.hub_overlay
	if hub_overlay != null and hub_overlay.visible:
		if ssc.hub_pause_mode and bool(root.call("_is_pause_input_just_pressed")):
			root.call("_close_hub_to_run")
			return
		root.call("_update_hub_input")
		# The HUD remains alive above the nested hub panel. Continue ticking it so
		# the coin animation and gold display do not freeze while shopping.
		root.call("_update_overworld_ui")
		return
	var run_complete_overlay := ssc.run_complete_overlay
	if run_complete_overlay != null and run_complete_overlay.visible:
		root.call("_update_run_complete_input")
		return
	if ssc.menu_input_release_lock:
		if not bool(root.call("_is_menu_cancel_input_pressed")):
			ssc.menu_input_release_lock = false
		else:
			return
	var npc := root.get("npc_controller") as NpcController; var dialogue_was_active: bool = npc != null and npc.dialogue_box != null and npc.dialogue_box.visible
	if dialogue_was_active: npc.update_dialogue_from_root(root, delta); npc.update_dialogue_input(root); root.call("_update_cloaked_demon_animation", delta)
	var hitstop: float = root.get("hitstop_timer")
	if hitstop > 0.0: root.set("hitstop_timer", maxf(hitstop - delta, 0.0)); return
	if bool(root.get("player_death_pending")) and not bool(root.get("player_dead")):
		(root.get("player_motor") as ActorMotor).update_player_hit_reaction(root, delta); (root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent).tick_death_pending(root); root.call("_update_damage_numbers", delta)
		var motor := root.get("player_motor") as ActorMotor
		if motor == null or not motor.is_in_knockback(): root.call("_start_player_death")
		return
	if bool(root.get("player_dead")):
		(root.get("effects_spawner") as EffectsSpawner).update_pixel_particles_from_root(root, delta); root.call("_update_player_death", delta); (root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent).tick_death(root); root.call("_update_damage_numbers", delta)
		var tuning := root.get("player_tuning") as PlayerTuning
		if bool(root.get("player_death_particles_started")) and float(root.get("player_death_timer")) >= tuning.death_particle_delay + tuning.death_particle_lifetime: root.call("_move_slimes", delta); root.call("_update_enemy_hit_flashes", delta); root.call("_update_enemy_health", delta)
		root.call("_update_depth_sorting"); root.call("_update_actor_occlusion", delta); _stabilize(root); root.call("_update_overworld_ui"); root.call("_update_game_over_input"); return
	if bool(root.call("_is_pause_input_just_pressed")):
		root.call("_open_pause_menu")
		return
	var player_input_locked: bool = dialogue_was_active
	var player_tuning := root.get("player_tuning") as PlayerTuning
	var previous_attacking: bool = root.get("player_is_attacking")
	var guard := root.get("player_guard_component") as PlayerGuardComponent
	if guard != null: guard.tick(root, delta, not player_input_locked and bool(root.call("_is_guard_input_held")))
	if not player_input_locked: update_player_input(root)
	var player_attack := root.get("player_attack_component") as PlayerAttackComponent
	if player_attack != null and player_attack.combo_buffered and bool(root.get("player_is_attacking")) and root.get("player_anim_name") == "attack1":
		var movement: Vector2 = root.call("_movement_input"); var combo_direction_changed := movement.length() > 0.25 and (player_attack.combo_movement.length() <= 0.25 or movement.normalized().dot(player_attack.combo_movement.normalized()) < 0.99)
		if combo_direction_changed: player_attack.consume_combo()
	if player_attack != null and player_attack.combo_buffered and not bool(root.get("player_is_attacking")) and float(root.get("player_between_timer")) <= 0.0 and player_attack.can_start_attack2(): player_attack.start_player_attack(root, 2); player_attack.consume_combo()
	if player_attack != null: player_attack.update_lunge(root, delta)
	if root.get("player_roll_component") != null: (root.get("player_roll_component") as PlayerRollComponent).update_from_root(root, delta)
	root.call("_update_roll_dust", delta); (root.get("player_motor") as ActorMotor).update_player_hit_reaction(root, delta)
	if not player_input_locked and root.get("player_motor") != null: (root.get("player_motor") as ActorMotor).move_player(root, delta)
	(root.get("player_animation_component") as PlayerAnimationComponent).tick_coordinator_animation(root, delta); root.call("_tick_run_telemetry", delta); root.call("_move_slimes", delta); root.call("_update_enemy_hit_flashes", delta); root.call("_update_enemy_health", delta); root.call("_update_target_ui"); root.call("_update_player_health_regen", delta); root.call("_update_player_health_ui", delta); root.call("_update_damage_numbers", delta); (root.get("effects_spawner") as EffectsSpawner).update_pixel_particles_from_root(root, delta); (root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent).tick(root, delta)
	if not dialogue_was_active:
		var chest_controller := root.get("chest_controller") as ChestController; chest_controller.update_interaction(root, root.call("_is_interact_input_pressed"), bool(root.get("interact_input_was_down")), int(root.get("CHEST_REWARD_GOLD")), float(root.get("CHEST_COLLECT_FLASH_TIME"))); chest_controller.update_visuals_from_root(root, delta); root.call("_update_world_item_drop", delta); root.call("_update_rest_fire_animation", delta); root.call("_update_cloaked_demon_animation", delta); root.call("_update_door_transition"); root.call("_update_depth_sorting"); root.call("_update_targeting"); root.call("_update_actor_occlusion", delta); _stabilize(root); (root.get("player_animation_component") as PlayerAnimationComponent).update_attack_visual(root.get("player"), root.get("player_attack_visual"), root.get("player_is_attacking"), Vector2(-10, -10), root.get("player").z_index)
	var now_attacking: bool = root.get("player_is_attacking")
	var anim := root.get("player_animation_component") as PlayerAnimationComponent
	if previous_attacking and not now_attacking:
		var attack_multiplier := player_tuning.attack_multiplier(int(root.get("player_spd")))
		if bool(root.get("player_just_finished_attack2")) and anim.after_attack2_texture != null:
			root.set("player_between_timer", player_tuning.attack2_cooldown / attack_multiplier); root.call("_set_actor_base_texture", root.get("player"), anim.after_attack2_texture)
		elif (player_attack == null or not player_attack.combo_buffered) and anim.between_attack_texture != null:
			root.set("player_between_timer", player_tuning.between_attack_time / attack_multiplier); root.call("_set_actor_base_texture", root.get("player"), anim.between_attack_texture)
		root.set("player_just_finished_attack2", false)
	var between_timer: float = root.get("player_between_timer")
	if between_timer > 0.0:
		between_timer = maxf(between_timer - delta, 0.0); root.set("player_between_timer", between_timer)
		if between_timer <= 0.0:
			if player_attack != null and player_attack.combo_buffered and player_attack.can_start_attack2():
				player_attack.start_player_attack(root, 2); player_attack.consume_combo()
			elif not (anim.idle_frames as Array[Texture2D]).is_empty():
				root.call("_set_actor_base_texture", root.get("player"), (anim.idle_frames as Array[Texture2D])[0])
	root.call("_update_player_shadow"); root.call("_update_cloaked_demon_shadow"); root.call("_update_overworld_ui"); root.call("_tick_focus_combo", delta); root.call("_update_focus_indicator")


func _stabilize(root: Object) -> void:
	(root.get("actor_collision_system") as ActorCollisionSystem).stabilize_guides(root.get("actor_sprites"), Callable(root, "_update_slime_attack_guides"))
