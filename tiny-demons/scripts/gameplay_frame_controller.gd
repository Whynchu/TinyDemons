extends Node
class_name GameplayFrameController


func tick(root: Object, delta: float) -> void:
	var attack := root.get("player_attack_component") as PlayerAttackComponent
	if attack != null: attack.tick_combo(delta); attack.tick_attack2_cooldown(delta)
	if (root.get("walkable_outline") as PackedVector2Array).is_empty(): return
	if bool(root.get("scene_transition_active")):
		var transition_timer: float = root.get("scene_transition_timer") + delta; root.set("scene_transition_timer", transition_timer)
		(root.get("scene_transition_overlay") as ColorRect).modulate.a = clampf(transition_timer / 0.28, 0.0, 1.0)
		if transition_timer >= 0.34: root.get_tree().reload_current_scene()
		return
	var title_overlay := root.get("title_overlay") as ColorRect; var archetype_overlay := root.get("archetype_overlay") as ColorRect
	if bool(root.get("title_transition_active")) or (title_overlay != null and title_overlay.visible) or (archetype_overlay != null and archetype_overlay.visible):
		root.call("_update_title_screen", delta)
		if bool(root.get("title_transition_active")) and float(root.get("title_transition_timer")) < 0.72: return
		if not bool(root.get("title_transition_active")): return
	if bool(root.get("loading_screen_active")): root.call("_update_loading_screen", delta); return
	var dialogue_box := root.get("npc_dialogue_box") as ColorRect; var dialogue_was_active: bool = dialogue_box != null and dialogue_box.visible
	if dialogue_was_active: root.call("_update_npc_dialogue", delta); root.call("_update_npc_dialogue_input")
	var hitstop: float = root.get("hitstop_timer")
	if hitstop > 0.0: root.set("hitstop_timer", maxf(hitstop - delta, 0.0)); return
	if bool(root.get("player_death_pending")) and not bool(root.get("player_dead")):
		root.call("_update_player_hit_reaction", delta); root.call("_update_damage_numbers", delta)
		var motor := root.get("player_motor") as ActorMotor
		if motor == null or not motor.is_in_knockback(): root.call("_start_player_death")
		return
	if bool(root.get("player_dead")):
		root.call("_update_pixel_particles", delta); root.call("_update_player_death", delta); root.call("_update_damage_numbers", delta)
		var tuning := root.get("player_tuning") as PlayerTuning
		if bool(root.get("player_death_particles_started")) and float(root.get("player_death_timer")) >= tuning.death_particle_delay + tuning.death_particle_lifetime: root.call("_move_slimes", delta); root.call("_update_enemy_hit_flashes", delta); root.call("_update_enemy_health", delta)
		root.call("_update_depth_sorting"); root.call("_update_actor_occlusion", delta); _stabilize(root); root.call("_update_overworld_ui"); root.call("_update_game_over_input"); return
	var player_input_locked: bool = dialogue_was_active
	var player_tuning := root.get("player_tuning") as PlayerTuning
	var previous_attack_input: bool = root.get("player_attack_input_was_down"); var previous_attacking: bool = root.get("player_is_attacking")
	if not player_input_locked: root.call("_update_player_attack_input")
	var attack_input_down: bool = root.call("_is_attack_input_pressed")
	var player_attack := root.get("player_attack_component") as PlayerAttackComponent
	if not player_input_locked and attack_input_down and not previous_attack_input and previous_attacking and root.get("player_anim_name") == "attack1":
		if player_attack != null: player_attack.buffer_combo(player_tuning.combo_window); player_attack.set_combo_movement(root.call("_movement_input"))
	if player_attack != null and player_attack.combo_buffered and bool(root.get("player_is_attacking")) and root.get("player_anim_name") == "attack1":
		var movement: Vector2 = root.call("_movement_input"); var combo_direction_changed := movement.length() > 0.25 and (player_attack.combo_movement.length() <= 0.25 or movement.normalized().dot(player_attack.combo_movement.normalized()) < 0.99)
		if combo_direction_changed: player_attack.consume_combo()
	if player_attack != null and player_attack.combo_buffered and not bool(root.get("player_is_attacking")) and float(root.get("player_between_timer")) <= 0.0 and player_attack.can_start_attack2(): player_attack.start_player_attack(root, 2); player_attack.consume_combo()
	if not player_input_locked: root.call("_update_player_roll_input")
	root.call("_update_player_attack_lunge", delta)
	if root.get("player_roll_component") != null: (root.get("player_roll_component") as PlayerRollComponent).update_from_root(root, delta)
	root.call("_update_roll_dust", delta); root.call("_update_player_hit_reaction", delta)
	if not player_input_locked and root.get("player_motor") != null: (root.get("player_motor") as ActorMotor).move_player(root, delta)
	(root.get("player_animation_component") as PlayerAnimationComponent).tick_coordinator_animation(root, delta); root.call("_move_slimes", delta); root.call("_update_enemy_hit_flashes", delta); root.call("_update_enemy_health", delta); root.call("_update_player_health_regen", delta); root.call("_update_player_health_ui", delta); root.call("_update_damage_numbers", delta); root.call("_update_pixel_particles", delta)
	if not dialogue_was_active:
		root.call("_update_chest_interaction"); root.call("_update_chest_visuals", delta); root.call("_update_rest_fire_animation", delta); root.call("_update_cloaked_demon_animation", delta); root.call("_update_door_transition"); root.call("_update_depth_sorting"); root.call("_update_targeting"); root.call("_update_actor_occlusion", delta); _stabilize(root); (root.get("player_animation_component") as PlayerAnimationComponent).update_attack_visual(root.get("player"), root.get("player_attack_visual"), root.get("player_is_attacking"), Vector2(5, 7), root.get("player").z_index)
	var now_attacking: bool = root.get("player_is_attacking")
	if previous_attacking and not now_attacking:
		if bool(root.get("player_just_finished_attack2")) and root.get("player_after_attack2_texture") != null:
			root.set("player_between_timer", player_tuning.attack2_cooldown); root.call("_set_actor_base_texture", root.get("player"), root.get("player_after_attack2_texture"))
		elif (player_attack == null or not player_attack.combo_buffered) and root.get("player_between_attack_texture") != null:
			root.set("player_between_timer", player_tuning.between_attack_time); root.call("_set_actor_base_texture", root.get("player"), root.get("player_between_attack_texture"))
		root.set("player_just_finished_attack2", false)
	var between_timer: float = root.get("player_between_timer")
	if between_timer > 0.0:
		between_timer = maxf(between_timer - delta, 0.0); root.set("player_between_timer", between_timer)
		if between_timer <= 0.0 and not (root.get("player_idle_frames") as Array[Texture2D]).is_empty(): root.call("_set_actor_base_texture", root.get("player"), (root.get("player_idle_frames") as Array[Texture2D])[0])
	root.call("_update_player_shadow"); root.call("_update_cloaked_demon_shadow"); root.call("_update_overworld_ui")


func _stabilize(root: Object) -> void:
	(root.get("actor_collision_system") as ActorCollisionSystem).stabilize_guides(root.get("actor_sprites"), Callable(root, "_update_slime_attack_guides"))
