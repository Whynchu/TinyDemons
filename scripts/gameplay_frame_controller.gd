extends Node
class_name GameplayFrameController

const PHASE_INPUT := &"input"
const PHASE_SIMULATION := &"simulation"
const PHASE_CONTACT := &"contact_resolution"
const PHASE_DAMAGE := &"damage_and_progression"
const PHASE_PRESENTATION := &"presentation"
const PHASE_TRANSITIONS := &"transitions"
const PHASE_ORDER: Array[StringName] = [PHASE_INPUT, PHASE_SIMULATION, PHASE_CONTACT, PHASE_DAMAGE, PHASE_PRESENTATION, PHASE_TRANSITIONS]

static func phase_order() -> Array[StringName]:
	return PHASE_ORDER.duplicate()


func _guard_context(root: GameplayState) -> PlayerGuardContext:
	var context := PlayerGuardContext.new()
	context.ui_parent = root
	context.player = root.player
	context.equipment = root.player_equipment
	context.visuals = root.player_equipment_visual_component
	context.overworld_ui_z = root.OVERWORLD_UI_Z
	context.is_defending_get = func() -> Variant: return root.get("player_is_defending")
	context.is_defending_set = func(value: Variant) -> void: root.set("player_is_defending", value)
	context.player_dead_get = func() -> Variant: return root.get("player_dead")
	context.player_death_pending_get = func() -> Variant: return root.get("player_death_pending")
	context.player_is_attacking_get = func() -> Variant: return root.get("player_is_attacking")
	context.player_is_rolling_get = func() -> Variant: return root.get("player_is_rolling")
	context.player_is_backflipping_get = func() -> Variant: return root.get("player_is_backflipping")
	context.player_hitstun_timer_get = func() -> Variant: return root.get("player_hitstun_timer")
	context.actor_foot = Callable(root, "_actor_foot")
	return context


func _roll_context(root: GameplayState) -> PlayerRollContext:
	var context := PlayerRollContext.new()
	context.player = root.player
	context.player_motor = root.player_motor
	context.player_animation_component = root.player_animation_component
	context.player_attack_visual = root.player_attack_visual
	context.run_state = root.run_state
	context.player_tuning = root.player_tuning
	context.player_agi_get = func() -> Variant: return root.get("player_agi")
	context.player_spd_get = func() -> Variant: return root.get("player_spd")
	context.player_is_targeting_get = func() -> Variant: return root.get("player_is_targeting")
	context.player_is_rolling_get = func() -> Variant: return root.get("player_is_rolling")
	context.player_is_backflipping_get = func() -> Variant: return root.get("player_is_backflipping")
	context.player_is_rolling_set = func(value: Variant) -> void: root.set("player_is_rolling", value)
	context.player_is_backflipping_set = func(value: Variant) -> void: root.set("player_is_backflipping", value)
	context.player_facing_left_before_target_get = func() -> Variant: return root.get("player_facing_left_before_target")
	context.last_player_facing_left_set = func(value: Variant) -> void: root.set("last_player_facing_left", value)
	context.roll_dust_spawned_this_roll_get = func() -> Variant: return root.get("roll_dust_spawned_this_roll")
	context.roll_dust_spawned_this_roll_set = func(value: Variant) -> void: root.set("roll_dust_spawned_this_roll", value)
	context.player_anim_name_set = func(value: Variant) -> void: root.set("player_anim_name", value)
	context.apply_animation_frame = func() -> void: root.player_animation_component.apply_frame(root) if root.player_animation_component != null else null
	context.movement_anim_name = func() -> Variant: return root.player_animation_component.movement_anim_name(root) if root.player_animation_component != null else ""
	context.update_motor_facing = func(direction: Vector2) -> void: root.player_motor.update_horizontal_facing(root, direction) if root.player_motor != null else null
	context.movement_input = Callable(root, "_movement_input")
	context.player_facing_vector = Callable(root, "_player_facing_vector")
	context.perspective_movement = Callable(root, "_perspective_movement")
	context.try_move_actor = Callable(root, "_try_move_actor")
	context.actor_foot = Callable(root, "_actor_foot")
	context.valid_current_target = Callable(root, "_valid_current_target")
	context.is_run_combat_active = Callable(root, "_is_run_combat_active")
	context.play_sound = Callable(root, "_play_sound")
	context.start_roll_dust = Callable(root, "_start_roll_dust")
	return context


func interaction_context(root: GameplayState) -> InteractionContext:
	var context := InteractionContext.new()
	context.player = root.player
	context.chest = root.chest
	context.npc_controller = root.npc_controller
	context.interact_prompt = root.interact_prompt
	context.player_is_attacking_get = func() -> Variant: return root.get("player_is_attacking")
	context.player_is_magic_casting_get = func() -> Variant: return root.get("player_is_magic_casting")
	context.target_input_was_down_get = func() -> Variant: return root.get("target_input_was_down")
	context.target_input_was_down_set = func(value: Variant) -> void: root.set("target_input_was_down", value)
	context.last_player_facing_left_get = func() -> Variant: return root.get("last_player_facing_left")
	context.last_player_facing_left_set = func(value: Variant) -> void: root.set("last_player_facing_left", value)
	context.actor_foot = Callable(root, "_actor_foot")
	context.is_target_input_held = Callable(root, "_is_target_input_held")
	context.set_current_target = Callable(root, "_set_current_target")
	context.set_target_ui_visible = Callable(root, "_set_target_ui_visible")
	context.closest_target = Callable(root, "_closest_target")
	context.valid_current_target = Callable(root, "_valid_current_target")
	context.is_slime_targetable = Callable(root, "_is_slime_targetable")
	context.target_cycle_direction = Callable(root, "_target_cycle_direction")
	context.cycle_target = Callable(root, "_cycle_target")
	context.update_target_ui = Callable(root, "_update_target_ui")
	context.player_facing_vector = Callable(root, "_player_facing_vector")
	context.can_interact_with_chest = Callable(root, "_can_interact_with_chest")
	context.can_interact_with_npc = Callable(root, "_can_interact_with_npc")
	context.can_interact_with_world_item = Callable(root, "_can_interact_with_world_item")
	context.can_interact_with_fire = Callable(root, "_can_interact_with_fire")
	context.collision_rect = Callable(root, "_collision_rect")
	context.world_item_drop_position = Callable(root, "_world_item_drop_position")
	context.cloaked_demon_head_position = Callable(root, "_cloaked_demon_head_position")
	context.fire_anchor = Callable(root, "_fire_anchor")
	context.snap_half_pixel = Callable(root, "_snap_half_pixel")
	return context


func update_player_input(root: GameplayState, delta: float) -> void:
	var attack_down: bool = root._is_attack_input_pressed(); var attack := root.player_attack_component
	if attack != null:
		attack.set_attack_input_held(attack_down)
		attack.update_spin_input(root, root._raw_movement_input(), delta, not root.player_is_attacking and not root.player_is_magic_casting and not root.player_is_rolling and not root.player_is_backflipping and not root.player_is_defending)
	if attack_down and not root.player_attack_input_was_down:
		var accepted_attack := false
		if not root.player_is_attacking and not root.player_is_magic_casting and not root.player_is_rolling and not root.player_is_backflipping and not root.player_is_defending and (attack == null or attack.can_start_attack2()):
			if attack != null and attack.spin_gesture.is_armed():
				accepted_attack = attack.start_spin_attack(root)
			elif attack != null and root.player_is_running:
				# A roll-continuation run commits directly to the stronger Attack 2
				# variant; it does not spend the run on a weaker opening swing.
				accepted_attack = attack.start_running_attack(root)
			elif root.player_between_timer > 0.0:
				if attack != null and not attack.combo_buffered:
					attack.buffer_combo(root.player_tuning.combo_window); attack.set_combo_movement(root._movement_input()); accepted_attack = true
			elif attack != null:
				attack.start_player_attack(root, 1); accepted_attack = true
		elif root.player_is_attacking and root.player_anim_name == "attack1" and attack != null and not attack.combo_buffered:
			attack.buffer_combo(root.player_tuning.combo_window); attack.set_combo_movement(root._movement_input()); accepted_attack = true
		root._record_run_action_input(&"attack", accepted_attack)
	root.player_attack_input_was_down = attack_down
	var roll_down: bool = root._is_roll_input_pressed()
	if roll_down and not root.player_roll_input_was_down:
		var accepted_roll := false
		if not root.player_is_attacking and not root.player_is_magic_casting and not root.player_is_rolling and not root.player_is_backflipping and not root.player_is_defending and (root.player_motor == null or not root.player_motor.is_in_knockback()):
			var roll := root.player_roll_component
			if roll != null:
				var roll_context := _roll_context(root)
				if roll.should_backflip(roll_context):
					roll.start_backflip_from_root(roll_context)
				else:
					roll.start_from_root(roll_context)
				accepted_roll = true
		if accepted_roll:
			# Running is a continuation of this roll-button hold: while the button
			# stays held after the dodge, movement becomes a run instead of a walk.
			root.player_roll_hold_armed = true
		root._record_run_action_input(&"roll", accepted_roll)
	root.player_roll_input_was_down = roll_down
	root.player_roll_input_held = roll_down
	if not roll_down:
		root.player_roll_hold_armed = false
	var target_down: bool = root._is_target_input_held()
	if target_down and not root.target_input_was_down:
		# Remember the facing from just before the lock-on so a no-target backflip
		# retreats while keeping the player's original facing.
		root.player_facing_left_before_target = root.last_player_facing_left
	root.player_is_targeting = target_down
	_update_magic_input(root, delta)


func _update_magic_input(root: GameplayState, delta: float) -> void:
	var magic_down: bool = root._is_magic_input_pressed()
	var accepted_magic: bool = root._update_magic_input(magic_down, root.magic_input_was_down, delta)
	if accepted_magic:
		root._record_run_action_input(&"magic", accepted_magic)
	root.magic_input_was_down = magic_down


func tick(root: GameplayState, delta: float) -> void:
	root._update_mp_desaturation()
	root._update_music_state()
	if root.boot_active:
		if root.loading_screen_active: root._update_loading_screen(delta)
		return
	var aspect_ability := root.player_aspect_ability_component
	if aspect_ability != null:
		aspect_ability.call("tick", delta)
	var attack := root.player_attack_component
	if attack != null: attack.tick_combo(delta); attack.tick_attack2_cooldown(delta); attack.tick_spin_hits(delta)
	if root.walkable_outline.is_empty(): return
	# Entry Orb presentation is independent of input, dialogue, and hitstop so
	# its bob/twinkle animation remains alive while the room is being taught.
	root._update_entry_orb_animation(delta)
	if root.scene_transition_active:
		var transition_timer: float = root.scene_transition_timer + delta; root.scene_transition_timer = transition_timer
		root.scene_transition_overlay.modulate.a = clampf(transition_timer / 0.28, 0.0, 1.0)
		if transition_timer >= 0.34: root.get_tree().reload_current_scene()
		return
	var ssc := root.screen_state_controller as ScreenStateController
	if ssc.save_select_overlay != null and ssc.save_select_overlay.visible:
		if ssc.save_select_footer_text != null:
			ssc.save_select_footer_text.texture = ssc._pixel_prompt_texture(Callable(root, "_pixel_text_texture"), str(root._menu_back_prompt()), Color8(148, 220, 255)) as Texture2D
		if root._is_menu_back_just_pressed():
			if ssc.save_overwrite_prompt_active: root._cancel_overwrite()
			else: root._close_save_select()
			return
		if ssc.menu_input_release_lock:
			if not root._is_menu_confirm_pressed() and not root._is_menu_back_pressed():
				ssc.menu_input_release_lock = false
			else:
				return
		if ssc.save_overwrite_prompt_active:
			var choice := ssc.save_overwrite_choice
			if root._is_menu_direction_just_pressed(&"ui_left") or root._is_menu_direction_just_pressed(&"ui_right"):
				ssc.save_overwrite_choice = 1 - choice; root._update_overwrite_cursor(); root._play_sound("ui_hover", -6.0, 1.0)
			elif root._is_menu_confirm_just_pressed():
				if choice == 0: (ssc.save_select_overlay.get_node("OverwriteYes") as Button).pressed.emit()
				else: (ssc.save_select_overlay.get_node("OverwriteNo") as Button).pressed.emit()
			return
		var slot := ssc.save_select_index
		if root._is_menu_direction_just_pressed(&"ui_up"): slot -= 1
		elif root._is_menu_direction_just_pressed(&"ui_down"): slot += 1
		if slot != ssc.save_select_index:
			ssc.save_select_index = posmod(slot, ProfileSaveService.SLOT_COUNT)
			root._update_save_select_cursor()
			root._play_sound("ui_hover", -6.0, 1.0)
		elif root._is_menu_confirm_just_pressed():
			for child in ssc.save_select_overlay.get_children():
				if child is Button and child.has_meta("save_slot") and int(child.get_meta("save_slot")) == ssc.save_select_index:
					(child as Button).pressed.emit()
					break
		return
	if ssc.settings_overlay != null and ssc.settings_overlay.visible:
		root._update_settings_input()
		return
	if ssc.name_entry_overlay != null and ssc.name_entry_overlay.visible:
		ssc.update_name_entry_input(root)
		return
	var title_overlay := ssc.title_overlay; var archetype_overlay := ssc.archetype_overlay
	if ssc.title_transition_active or (title_overlay != null and title_overlay.visible) or (archetype_overlay != null and archetype_overlay.visible):
		root._update_title_screen(delta)
		if ssc.title_transition_active and ssc.title_transition_timer < 0.72: return
		if not ssc.title_transition_active: return
	if root.loading_screen_active: root._update_loading_screen(delta); return
	var minimap := root.dungeon_minimap_controller
	var input_router := root.input_router
	if minimap != null and bool(minimap.call("is_map_open")):
		if input_router != null and input_router.just_pressed(&"pause"):
			minimap.call("close_map")
			root._open_pause_menu()
			return
		minimap.call("handle_input", root)
		return
	if minimap != null and input_router != null and input_router.just_pressed(&"open_minimap") and bool(minimap.call("can_open_map", root)):
		if bool(minimap.call("open_map", root)):
			root._play_sound("ui_pause", 0.0, 1.0)
		return
	var pause_overlay := ssc.pause_overlay
	if pause_overlay != null and pause_overlay.visible:
		if root._is_pause_input_just_pressed():
			root._close_hub_to_run()
			return
		root._update_pause_input()
		# The HUD remains alive above the menu. Continue ticking it so the coin
		# animation and top-bar status do not freeze while the game is paused.
		root._update_overworld_ui()
		return
	var hub_overlay := ssc.hub_overlay
	if hub_overlay != null and hub_overlay.visible:
		root._update_hub_input()
		# The HUD remains alive above the nested hub panel. Continue ticking it so
		# the coin animation and gold display do not freeze while shopping.
		root._update_overworld_ui()
		return
	var run_complete_overlay := ssc.run_complete_overlay
	if run_complete_overlay != null and run_complete_overlay.visible:
		root._update_run_complete_input()
		return
	if ssc.menu_input_release_lock:
		if not root._is_menu_back_pressed() and not root._is_menu_confirm_pressed():
			ssc.menu_input_release_lock = false
		else:
			return
	var npc := root.npc_controller; var dialogue_was_active: bool = npc != null and npc.dialogue_box != null and npc.dialogue_box.visible
	if dialogue_was_active: npc.update_dialogue_from_root(root, delta); npc.update_dialogue_input(root); root._update_cloaked_demon_animation(delta)
	var hitstop: float = root.hitstop_timer
	if hitstop > 0.0: root.hitstop_timer = maxf(hitstop - delta, 0.0); return
	if root.player_death_pending and not root.player_dead:
		root.player_motor.update_player_hit_reaction(root, delta); root.player_equipment_visual_component.tick_death_pending(root); root._update_damage_numbers(delta)
		var motor := root.player_motor
		if motor == null or not motor.is_in_knockback(): root._start_player_death()
		return
	if root.player_dead:
		root.effects_spawner.update_pixel_particles_from_root(root, delta); root._update_player_death(delta); root.player_equipment_visual_component.tick_death(root); root._update_damage_numbers(delta)
		var tuning := root.player_tuning
		if root.player_death_particles_started and root.player_death_timer >= tuning.death_particle_delay + tuning.death_particle_lifetime: root._move_slimes(delta); root._update_enemy_hit_flashes(delta); root._update_enemy_health(delta)
		root._update_depth_sorting(); root._update_actor_occlusion(delta); _stabilize(root); root._update_overworld_ui(); root._update_game_over_input(); return
	if root._is_pause_input_just_pressed():
		root._open_pause_menu()
		return
	var player_input_locked: bool = dialogue_was_active or root.player_is_magic_casting
	var player_tuning := root.player_tuning
	var previous_attacking: bool = root.player_is_attacking
	var previous_attack_animation := root.player_anim_name
	var guard := root.player_guard_component
	if guard != null: guard.tick(_guard_context(root), delta, not player_input_locked and root._is_guard_input_held())
	if not player_input_locked:
		update_player_input(root, delta)
	elif root.player_is_magic_casting or root.magic_input_was_down:
		# The shared magic animation is also the hold-to-IMBUE decision window.
		# Keep polling Triangle while that window is active, even though movement
		# and the other player actions remain locked.
		_update_magic_input(root, delta)
	player_input_locked = dialogue_was_active or root.player_is_magic_casting
	var player_attack := root.player_attack_component
	if player_attack != null and not player_input_locked:
		player_attack.tick_charge(root, delta)
	if player_attack != null and player_attack.combo_buffered and root.player_is_attacking and root.player_anim_name == "attack1":
		var movement: Vector2 = root._movement_input(); var combo_direction_changed := movement.length() > 0.25 and (player_attack.combo_movement.length() <= 0.25 or movement.normalized().dot(player_attack.combo_movement.normalized()) < 0.99)
		if combo_direction_changed: player_attack.consume_combo()
	if player_attack != null and player_attack.combo_buffered and not root.player_is_attacking and root.player_between_timer <= 0.0 and player_attack.can_start_attack2(): player_attack.start_player_attack(root, 2); player_attack.consume_combo()
	if player_attack != null: player_attack.update_lunge(root, delta)
	if root.player_roll_component != null: root.player_roll_component.update_from_root(_roll_context(root), delta)
	root._update_roll_dust(delta); root.player_motor.update_player_hit_reaction(root, delta); root._update_entry_orb_player_reaction()
	if not player_input_locked and root.player_motor != null: root.player_motor.move_player(root, delta)
	root.magic_runtime_controller.tick_magic_animation(root, delta); root.player_animation_component.tick_coordinator_animation(root, delta); root._tick_run_telemetry(delta); root._move_slimes(delta); root._update_special_enemy_respawns(delta); root._update_enemy_hit_flashes(delta); root._update_enemy_health(delta); root._update_target_ui(); root._update_player_health_regen(delta); root._update_player_health_ui(delta); root._update_player_mp_ui(delta); root._update_magic_projectiles(delta); root._update_damage_numbers(delta); root.effects_spawner.update_pixel_particles_from_root(root, delta); root.player_equipment_visual_component.tick(root, delta)
	if not dialogue_was_active:
		var chest_controller := root.chest_controller; chest_controller.update_interaction(root, root._is_interact_input_pressed(), root.interact_input_was_down, GameplayState.CHEST_REWARD_GOLD, GameplayState.CHEST_COLLECT_FLASH_TIME, delta); chest_controller.update_visuals_from_root(root, delta); root._update_world_item_drops(delta); root._update_chroma_pickups(delta); root._update_soul_pickups(delta); root._update_rest_fire_animation(delta); root._update_cloaked_demon_animation(delta); root._update_door_transition(); root._update_depth_sorting(); root._update_targeting(); root._update_actor_occlusion(delta); root._update_player_palette_flash(delta); _stabilize(root)
		# The charge pose is rendered by the base player sprite. The shared attack
		# visual updater must not turn the previous attack frame back on after the
		# animation component has deliberately hidden it.
		var attack_visual_active := root.player_is_attacking and root.player_anim_name != "charge"
		root.player_animation_component.update_attack_visual(root.player, root.player_attack_visual, attack_visual_active, Vector2(-10, -10), root.player.z_index)
	else:
		root._update_player_palette_flash(delta)
	var now_attacking: bool = root.player_is_attacking
	var anim := root.player_animation_component
	if previous_attacking and not now_attacking:
		var orb_cancelled := root.orb_knockback_attack_cancelled
		root.orb_knockback_attack_cancelled = false
		if not orb_cancelled and previous_attack_animation != "spin_attack":
			# Spin owns its full recovery in the authored animation. Do not let the
			# generic attack completion bridge add a between/after pose afterward.
			var agi_value: Variant = root.player_agi
			var effective_agi := float(agi_value) if agi_value != null else float(root.player_spd)
			var attack_multiplier := player_tuning.attack_multiplier_for_agi(effective_agi)
			if root.player_just_finished_attack2 and anim.after_attack2_texture != null:
				anim.begin_transition(root, "after", anim.after_attack2_texture, player_tuning.attack2_cooldown / attack_multiplier)
			elif (player_attack == null or not player_attack.combo_buffered) and anim.between_attack_texture != null:
				anim.begin_transition(root, "between", anim.between_attack_texture, player_tuning.between_attack_time / attack_multiplier)
		root.player_just_finished_attack2 = false
	var between_timer: float = root.player_between_timer
	if between_timer > 0.0:
		between_timer = maxf(between_timer - delta, 0.0); root.player_between_timer = between_timer
		if between_timer <= 0.0:
			if player_attack != null and player_attack.combo_buffered and player_attack.can_start_attack2():
				player_attack.start_player_attack(root, 2); player_attack.consume_combo()
			elif not root.player_is_magic_casting and not (anim.idle_frames as Array[Texture2D]).is_empty():
				root.player_anim_name = anim.movement_anim_name(root)
				root.player_anim_frame = 0
				root.player_anim_timer = 0.0
				anim.apply_frame(root)
	root._update_player_shadow(); root._update_cloaked_demon_shadow(); root._update_overworld_ui(); root._tick_focus_combo(delta); root._update_focus_indicator(delta)


func _stabilize(root: GameplayState) -> void:
	root.actor_collision_system.stabilize_guides(root.actor_sprites, Callable(root, "_update_slime_attack_guides"))
	var geometry_debug := root.actor_geometry_debug_drawer
	if geometry_debug != null: geometry_debug.refresh()
