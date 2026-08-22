extends "res://scripts/gameplay_state.gd"
const RunGradeEvaluator = preload("res://scripts/run_grade.gd")
const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const ProgressionControllerScript = preload("res://scripts/progression_controller.gd")
func _add_runtime_node(script: Script, node_name: StringName, parent: Node = self) -> Node:
	var node := script.new() as Node; node.name = node_name; parent.add_child(node); return node
func _ready() -> void:
	var bootstrap := _add_runtime_node(GameplayBootstrap, "GameplayBootstrap") as GameplayBootstrap; bootstrap.initialize(self)
func _apply_profile_to_runtime() -> void:
	profile_runtime_controller.call("apply_profile_to_runtime", self)

func _reapply_equipment_preserving_health() -> void:
	profile_runtime_controller.call("reapply_equipment_preserving_health", self)

func _equip_profile_item(instance_id: String) -> bool:
	return bool(profile_runtime_controller.call("equip_profile_item", self, instance_id))

func _unequip_profile_slot(slot: StringName) -> bool:
	return bool(profile_runtime_controller.call("unequip_profile_slot", self, slot))

func _grant_chest_item_reward() -> bool:
	if player_profile == null or run_state == null:
		return false
	var reward_id := "drop-%s-%s" % [run_state.run_id, String(current_room_id)]
	if player_profile.find_item(reward_id) != null:
		return true
	run_state.record_chest_open()
	var generation_seed := int(current_dungeon_seed) ^ String(current_room_id).hash()
	var reward_rng := RandomNumberGenerator.new()
	reward_rng.seed = generation_seed ^ 0x4C4F4F54
	if reward_rng.randf() >= _chest_item_drop_chance():
		return true
	var slot := ItemCatalog.SLOTS[posmod(generation_seed, ItemCatalog.SLOTS.size())]
	var rarity := _roll_run_loot_rarity(reward_rng.randf())
	var item := ItemCatalog.new().generate_item(slot, generation_seed, player_profile.level, rarity)
	item.instance_id = reward_id
	_spawn_chest_item_drop(item)
	_play_sound("ui_use_item")
	return true

func _spawn_chest_item_drop(item: ItemInstance) -> void:
	pickup_runtime_controller.call("spawn_chest_item_drop", self, item)

func _restore_chest_item_drop(item: ItemInstance, saved_position: Vector2) -> void:
	pickup_runtime_controller.call("restore_chest_item_drop", self, item, saved_position)

func _constrain_world_item_drop() -> void:
	pickup_runtime_controller.call("constrain_world_item_drop", self)

func _update_world_item_drop(delta: float) -> void:
	pickup_runtime_controller.call("update_world_item_drop", self, delta)

func _can_interact_with_world_item() -> bool:
	return bool(pickup_runtime_controller.call("can_interact_with_world_item", self))

func _collect_world_item_drop() -> bool:
	return bool(pickup_runtime_controller.call("collect_world_item_drop", self))

func _spawn_chroma_pickup(position: Vector2, value: int = CHROMA_PICKUP_VALUE, launch_seed: int = 0, launch_direction: Vector2 = Vector2.ZERO) -> void:
	pickup_runtime_controller.call("spawn_chroma_pickup", self, position, value, launch_seed, launch_direction)

func _restore_chroma_pickups(saved_pickups: Array) -> void:
	pickup_runtime_controller.call("restore_chroma_pickups", self, saved_pickups)

func _update_chroma_pickups(delta: float) -> void:
	pickup_runtime_controller.call("update_chroma_pickups", self, delta)

func _collect_chroma_pickup(index: int) -> void:
	pickup_runtime_controller.call("collect_chroma_pickup", self, index)

func _remove_chroma_pickup(index: int) -> void:
	pickup_runtime_controller.call("remove_chroma_pickup", self, index)

func _clear_chroma_pickups() -> void:
	pickup_runtime_controller.call("clear_chroma_pickups", self)

func _loot_grade_bonus(grade: String = "") -> float:
	return float(run_flow_controller.call("loot_grade_bonus", self, grade))

func _chest_item_drop_chance() -> float:
	return float(run_flow_controller.call("chest_item_drop_chance", self))

func _chest_gold_reward(base_gold: int) -> int:
	return int(run_flow_controller.call("chest_gold_reward", self, base_gold))

func _save_player_profile() -> void:
	if player_profile != null:
		ProfileSaveService.save_profile(player_profile)
func _play_sound(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if sound_manager != null:
		sound_manager.play(sound_name, volume_db, pitch_scale)
func _on_player_walk_step(_step_frame: int) -> void:
	if not player_is_moving or player_is_rolling or player_is_attacking or player_is_defending:
		return
	_play_sound("foot_left" if _step_frame == 1 else "foot_right", -8.0, 1.0 + rng.randf_range(-0.025, 0.025))
func _fade_out_music() -> void:
	if sound_manager != null:
		sound_manager.fade_out_music()
func _start_music() -> void:
	if sound_manager != null:
		sound_manager.start_music()
func _is_on_title_menu() -> bool:
	var ssc := screen_state_controller
	if ssc == null or ssc.state != &"title" or ssc.title_transition_active:
		return false
	if ssc.title_overlay == null or not ssc.title_overlay.visible:
		return false
	if ssc.save_select_overlay != null and ssc.save_select_overlay.visible:
		return false
	return true
func _update_music_state() -> void:
	if _is_on_title_menu():
		title_menu_frames = mini(title_menu_frames + 1, 2)
	else:
		title_menu_frames = 0
	var should_play := title_menu_frames >= 2
	if should_play == music_wanted:
		return
	music_wanted = should_play
	if should_play:
		_start_music()
	else:
		_fade_out_music()
func _set_gold_value(value: int) -> void:
	profile_runtime_controller.call("set_gold_value", self, value)
func _sync_runtime_progression_to_profile() -> void:
	profile_runtime_controller.call("sync_runtime_progression_to_profile", self)
func _respec_player_stats() -> int:
	return int(profile_runtime_controller.call("respec_player_stats", self))
func _physics_process(delta: float) -> void:
	if input_router != null: input_router.poll(_input_context())
	gameplay_frame_controller.tick(self, delta)
	# Bosses are much taller than normal slimes; refresh foot-based z-order every
	# frame so the player can correctly pass in front of or behind them.
	_update_depth_sorting()
	_update_player_shadow()
	_update_roll_dust(0.0)
	_update_large_room_camera()
func _start_player_death() -> void:
	effects_spawner.begin_player_death(self, DEPTH_Z_SCALE)
	if player_equipment_visual_component != null: player_equipment_visual_component.begin_death(self)
func _update_player_death(delta: float) -> void: screen_state_controller.update_player_death(self, delta, GAME_OVER_FADE_TIME)
func _spawn_player_death_pixels() -> void: effects_spawner.spawn_player_death_particles(self, player_death_texture, player_death_origin, player_death_offset, player_death_scale, int(round(_depth_key(player) * DEPTH_Z_SCALE)) + 2, player_tuning.death_particle_lifetime, rng.randi(), Callable(self, "_pixel_particle_texture"))
func _build_game_over_ui() -> void: var controls: Dictionary = screen_state_controller.build_game_over(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_return_to_hub"), Callable(self, "_return_to_title")); game_over_overlay = controls["overlay"] as ColorRect; game_over_button = controls["restart"] as Button; game_over_title_button = controls["title"] as Button; screen_state_controller.game_over_cursor_text = controls["cursor"] as Sprite2D
func _build_run_complete_ui() -> void:
	var controls: Dictionary = screen_state_controller.build_run_complete(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_return_from_run_complete"))
	screen_state_controller.run_complete_overlay = controls["overlay"] as ColorRect
	screen_state_controller.run_complete_texts = controls["lines"] as Array[Sprite2D]
	screen_state_controller.run_complete_button = controls["return"] as Button
	screen_state_controller.run_complete_cursor = controls["cursor"] as Sprite2D
func _build_hub_ui() -> void:
	hub_flow_controller.call("build_hub_ui", self)
func _show_hub(from_npc: bool = false, pause_mode: bool = false) -> void:
	hub_flow_controller.call("show_hub", self, from_npc, pause_mode)

func _open_pause_menu() -> void:
	hub_flow_controller.call("open_pause_menu", self)
func _open_hub_from_cloaked_demon() -> void:
	hub_flow_controller.call("open_hub_from_cloaked_demon", self)
func _close_hub_to_run() -> void:
	hub_flow_controller.call("close_hub_to_run", self)
func _update_hub_input() -> void: hub_flow_controller.call("update_hub_input", self)
func _is_hub_previous_page_input_pressed() -> bool: return player_controller.guard_held(_controller_devices(), 0.35)
func _is_hub_next_page_input_pressed() -> bool: return player_controller.target_held(_controller_devices(), 0.35)
func _is_menu_cancel_input_pressed() -> bool: return player_controller.action_pressed(&"cancel", _controller_devices(), JOY_BUTTON_A)
func _is_ui_accept_pressed() -> bool: return input_router != null and input_router.ui_accept_pressed()
func _is_ui_accept_just_pressed() -> bool: return input_router != null and input_router.ui_accept_just_pressed()
func _is_ui_cancel_just_pressed() -> bool: return input_router != null and input_router.ui_cancel_just_pressed()
func _is_ui_direction_just_pressed(direction: StringName) -> bool: return input_router != null and input_router.ui_direction_just_pressed(direction)
func _is_pause_input_just_pressed() -> bool:
	var is_down := input_router != null and input_router.pressed(&"pause")
	var just_pressed: bool = is_down and not bool(screen_state_controller.pause_input_was_down)
	screen_state_controller.pause_input_was_down = is_down
	return just_pressed
func _input_context() -> int:
	if screen_state_controller == null: return InputRouter.Context.GAMEPLAY
	var ssc := screen_state_controller as ScreenStateController
	if ssc.save_select_overlay != null and ssc.save_select_overlay.visible: return InputRouter.Context.MENU
	if ssc.title_overlay != null and ssc.title_overlay.visible: return InputRouter.Context.MENU
	if ssc.archetype_overlay != null and ssc.archetype_overlay.visible: return InputRouter.Context.MENU
	if ssc.hub_overlay != null and ssc.hub_overlay.visible: return InputRouter.Context.HUB
	if npc_controller != null and npc_controller.dialogue_box != null and npc_controller.dialogue_box.visible: return InputRouter.Context.DIALOGUE
	return InputRouter.Context.GAMEPLAY
func _set_hub_page(page: int) -> void:
	hub_flow_controller.call("set_hub_page", self, page)
func _shift_hub_item(direction: int) -> void:
	hub_flow_controller.call("shift_hub_item", self, direction)
func _hub_gear_candidates(slot: StringName) -> Array[ItemInstance]:
	return hub_flow_controller.call("hub_gear_candidates", self, slot) as Array[ItemInstance]
func _shift_hub_gear_candidate(direction: int) -> void:
	hub_flow_controller.call("shift_hub_gear_candidate", self, direction)
func _select_hub_gear_slot(slot_index: int) -> void:
	hub_flow_controller.call("select_hub_gear_slot", self, slot_index)
func _close_hub_gear_browse() -> void:
	hub_flow_controller.call("close_hub_gear_browse", self)
func _refresh_hub_fusion_candidates() -> void:
	hub_flow_controller.call("refresh_hub_fusion_candidates", self)
func _invalidate_hub_fusion_candidates() -> void:
	hub_flow_controller.call("invalidate_hub_fusion_candidates", self)
func _hub_fusion_candidates() -> Array[ItemInstance]:
	return hub_flow_controller.call("hub_fusion_candidates", self) as Array[ItemInstance]
func _fuse_profile_target(instance_id: String, count: int) -> bool:
	return bool(hub_flow_controller.call("fuse_profile_target", self, instance_id, count))
func _shift_hub_fusion_count(direction: int) -> void:
	hub_flow_controller.call("shift_hub_fusion_count", self, direction)
func _salvage_profile_overflow(instance_id: String) -> int:
	return int(hub_flow_controller.call("salvage_profile_overflow", self, instance_id))
func _hub_item_action() -> void:
	hub_flow_controller.call("hub_item_action", self)
func _select_hub_menu_row(row: int) -> void:
	hub_flow_controller.call("select_hub_menu_row", self, row)
func _shift_hub_action_column(direction: int) -> void:
	hub_flow_controller.call("shift_hub_action_column", self, direction)
func _hub_adjust_stat(stat_name: StringName, direction: int) -> void:
	hub_flow_controller.call("hub_adjust_stat", self, stat_name, direction)
func _hub_allocate_stat(stat_name: StringName) -> void:
	hub_flow_controller.call("hub_allocate_stat", self, stat_name)
func _hub_points_remaining() -> int: return int(hub_flow_controller.call("hub_points_remaining", self))
func _hub_confirm_stats() -> void:
	hub_flow_controller.call("hub_confirm_stats", self)
func _hub_cancel_stats() -> void:
	hub_flow_controller.call("hub_cancel_stats", self)
func _hub_auto_allocate() -> void:
	hub_flow_controller.call("hub_auto_allocate", self)
func _hub_respec() -> void:
	hub_flow_controller.call("hub_respec", self)
func _start_from_hub() -> void:
	hub_flow_controller.call("start_from_hub", self)

func _run_difficulty_bonus() -> int:
	return int(run_flow_controller.call("run_difficulty_bonus", self))

func _run_rank() -> int:
	return int(run_flow_controller.call("run_rank", self))

func _apply_run_rank_grade(grade: String) -> void:
	run_flow_controller.call("apply_run_rank_grade", self, grade)

func _begin_new_run() -> void:
	run_flow_controller.call("begin_new_run", self)
func _return_to_hub() -> void:
	run_flow_controller.call("return_to_hub", self)
func _settle_current_run(result: StringName) -> bool:
	return bool(run_flow_controller.call("settle_current_run", self, result))
func _tick_run_telemetry(delta: float) -> void:
	run_flow_controller.call("tick_run_telemetry", self, delta)
func _is_run_combat_active() -> bool:
	return bool(run_flow_controller.call("is_run_combat_active", self))
func _on_player_successful_block(_shield_damage: float, _health_damage: float) -> void:
	run_flow_controller.call("on_player_successful_block", self, _shield_damage, _health_damage)

func _record_run_action_input(action: StringName, accepted: bool) -> void:
	run_flow_controller.call("record_run_action_input", self, action, accepted)

func _clear_reward_rarity(score: int, roll: float) -> StringName:
	return run_flow_controller.call("clear_reward_rarity", self, score, roll) as StringName

func _roll_run_loot_rarity(roll: float, score_quality: float = -1.0) -> StringName:
	return run_flow_controller.call("roll_run_loot_rarity", self, roll, score_quality) as StringName

func _complete_run() -> void:
	run_flow_controller.call("complete_run", self)

func _show_run_complete(drop_color: Color) -> void:
	run_flow_controller.call("show_run_complete", self, drop_color)

func _run_metric_color(quality: float) -> Color:
	return run_flow_controller.call("metric_color", quality) as Color

func _update_run_complete_input() -> void:
	if screen_state_controller.run_complete_button == null:
		return
	if _is_ui_accept_just_pressed() or _is_interact_input_pressed() or _is_menu_cancel_input_pressed():
		screen_state_controller.run_complete_button.pressed.emit()

func _return_from_run_complete() -> void:
	run_flow_controller.call("return_from_run_complete", self)
func _show_game_over() -> void:
	if game_over_overlay == null or game_over_overlay.visible: return
	_apply_run_rank_grade("F")
	_settle_current_run(&"defeat")
	game_over_overlay.visible = true; screen_state_controller.set_state(&"game_over"); game_over_fade_timer = 0.0; game_over_overlay.modulate.a = 0.0; last_game_over_focus = null; game_over_button.grab_focus()
func _build_title_screen() -> void: save_flow_controller.call("build_title_screen", self)
func _build_archetype_screen() -> void: save_flow_controller.call("build_archetype_screen", self)
func _update_title_screen(delta: float) -> void: save_flow_controller.call("update_title_screen", self, delta)
func _start_new_game() -> void: save_flow_controller.call("start_new_game", self)
func _continue_game() -> void: save_flow_controller.call("continue_game", self)

func _open_save_select_after_title_transition() -> void:
	save_flow_controller.call("open_save_select_after_title_transition", self)

func _update_save_select_cursor() -> void:
	save_flow_controller.call("update_save_select_cursor", self)

func _save_preview_texture(palette_name: String) -> Texture2D:
	return save_flow_controller.call("save_preview_texture", self, palette_name) as Texture2D

func _select_save_slot(slot: int) -> void:
	save_flow_controller.call("select_save_slot", self, slot)

func _set_overwrite_prompt(active: bool) -> void:
	save_flow_controller.call("set_overwrite_prompt", self, active)

func _cancel_overwrite() -> void:
	save_flow_controller.call("cancel_overwrite", self)

func _confirm_overwrite() -> void:
	save_flow_controller.call("confirm_overwrite", self)

func _reset_runtime_for_new_save() -> void:
	save_flow_controller.call("reset_runtime_for_new_save", self)

func _update_overwrite_cursor() -> void:
	save_flow_controller.call("update_overwrite_cursor", self)

func _close_save_select() -> void:
	save_flow_controller.call("close_save_select", self)

func _cancel_character_creation() -> void:
	save_flow_controller.call("cancel_character_creation", self)

func _select_continue_slot(slot: int) -> void:
	save_flow_controller.call("select_continue_slot", self, slot)
func _enter_starting_room_from_menu() -> void:
	save_flow_controller.call("enter_starting_room_from_menu", self)

func _place_player_at_hub_fire() -> void:
	save_flow_controller.call("place_player_at_hub_fire", self)
func _update_archetype_input(delta: float) -> void: save_flow_controller.call("update_archetype_input", self, delta)
func _shift_archetype(direction: int) -> void: save_flow_controller.call("shift_archetype", self, direction)
func _shift_archetype_color(direction: int) -> void: save_flow_controller.call("shift_archetype_color", self, direction)
func _archetype_arrow_pulse(direction: int) -> void: save_flow_controller.call("archetype_arrow_pulse", self, direction)
func _update_archetype_arrow_animation() -> void: save_flow_controller.call("update_archetype_arrow_animation", self)
func _select_archetype_menu_row(row: int) -> void: save_flow_controller.call("select_archetype_menu_row", self, row)
func _update_archetype_screen() -> void: save_flow_controller.call("update_archetype_screen", self)
func _update_archetype_preview_animation() -> void: save_flow_controller.call("update_archetype_preview_animation", self)
func _update_archetype_button_styles() -> void: save_flow_controller.call("update_archetype_button_styles", self)
func _start_selected_archetype() -> void: save_flow_controller.call("start_selected_archetype", self)
func _build_loading_screen() -> void: save_flow_controller.call("build_loading_screen", self)
func _update_loading_screen(delta: float) -> void: save_flow_controller.call("update_loading_screen", self, delta)
func _apply_player_palette_async(palette_name: String) -> void:
	if player_animation_component != null: player_animation_component.apply_palette_async(self, palette_name)
	if player_equipment_visual_component != null: player_equipment_visual_component.apply_palette(self)
	var player_hud := ui.get_node_or_null("PlayerHud") as Node2D
	if player_hud != null:
		player_hud.call("apply_bar_colors", _health_feedback_color(palette_name))
	_update_player_progression_ui()
	_update_mp_desaturation()


func _update_mp_desaturation() -> void:
	var saturation := _chroma_visual_saturation()
	var material_was_created := false
	if mp_desaturation_material == null:
		mp_desaturation_material = ShaderMaterial.new()
		mp_desaturation_material.shader = preload("res://shaders/mp_desaturation.gdshader")
		material_was_created = true
	mp_desaturation_material.set_shader_parameter("grey_mix", 1.0 - saturation)
	if player != null:
		player.material = mp_desaturation_material
	if player_attack_visual != null:
		player_attack_visual.material = mp_desaturation_material
	if material_was_created and player_animation_component != null:
		# The first animation frame may have been assigned before the material
		# existed, so initialize the sampler with its matching grey frame now.
		player_animation_component.apply_frame(self)


func _set_mp_grey_texture(texture: Texture2D) -> void:
	if mp_desaturation_material != null:
		mp_desaturation_material.set_shader_parameter("grey_texture", texture)
		mp_desaturation_material.set_shader_parameter("grey_mix", 1.0 - _chroma_visual_saturation())

func _chroma_visual_saturation() -> float:
	var normalized := clampf(_current_player_chroma() / PLAYER_MAX_MP, 0.0, 1.0)
	if normalized <= 0.0:
		return 0.0
	if normalized >= 1.0:
		return 1.0
	# Keep the character colorful through most of the bar, then let the final
	# quarter fall toward Gray more sharply. With the current exponent, 75/50/25
	# map approximately to 83/64/41 percent visual saturation.
	return pow(normalized, CHROMA_SATURATION_CURVE_EXPONENT)
func _update_player_aggro_marker_colors() -> void: hud_controller.update_aggro_markers(hud_controller.target_overhead_aggro_markers, screen_state_controller.player_palette_name, Callable(self, "_pixel_particle_texture"))
func _spawn_title_pixel_breakup(source_sprite: Sprite2D) -> void:
	if screen_state_controller.title_particle_layer == null:
		screen_state_controller.title_particle_layer = Node2D.new(); screen_state_controller.title_particle_layer.name = "TitleParticleLayer"; screen_state_controller.title_particle_layer.z_index = 10; ui.add_child(screen_state_controller.title_particle_layer)
	screen_state_controller.spawn_pixel_breakup(source_sprite, screen_state_controller.title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _spawn_title_button_frame_breakup() -> void: screen_state_controller.spawn_button_frame_breakup(screen_state_controller.title_start_button, screen_state_controller.title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _update_game_over_input() -> void:
	if game_over_overlay == null or not game_over_overlay.visible: return
	var focused := get_viewport().gui_get_focus_owner() as Button
	if focused != last_game_over_focus:
		var changed_from_existing := last_game_over_focus != null
		last_game_over_focus = focused
		if changed_from_existing and focused != null:
			_play_sound("ui_hover", -6.0, 1.0)
	if _is_interact_input_pressed():
		var interact_focused := get_viewport().gui_get_focus_owner() as Button
		if interact_focused != null and not interact_focused.disabled:
			_play_sound("ui_confirm", 0.0, 1.0)
			interact_focused.pressed.emit()
func _return_to_title() -> void:
	_settle_current_run(&"return_to_title")
	if player_profile != null:
		player_profile.open_hub_on_load = false
		player_profile.pending_route = "title"
		_save_player_profile()
	_begin_scene_transition()
func _build_scene_transition() -> void: scene_transition_overlay = screen_state_controller.create_overlay(ui, "SceneTransitionOverlay", Vector2(240, 160), Color.BLACK, 200); scene_transition_overlay.modulate.a = 0.0
func _begin_scene_transition() -> void:
	if scene_transition_active or scene_transition_overlay == null: return
	scene_transition_active = true; screen_state_controller.set_state(&"transition"); scene_transition_timer = 0.0; scene_transition_overlay.visible = true
func _on_player_motor_motion(motion: Vector2) -> void: _try_move_actor(player, motion)
func _start_roll_dust(direction: Vector2) -> void: effects_spawner.start_roll_dust(self, player, direction, roll_dust_frames, roll_dust_flipped_frames, Callable(self, "_actor_foot"), Callable(self, "_snap_half_pixel"))
func _update_roll_dust(delta: float) -> void: effects_spawner.update_roll_dust(delta, player.z_index, roll_dust_frames, roll_dust_flipped_frames, effects_tuning.roll_dust_frame_time, Callable(self, "_snap_half_pixel"))
func _clear_roll_dust() -> void: effects_spawner.clear_roll_dust()
func _interrupt_player_attack() -> void:
	player_is_attacking = false; if player_attack_component != null: player_attack_component.cancel()
	player_attack_hit_done = false; player_attack_visual.visible = false; player.visible = true; _restore_actor_base_visual_scale(player); player_anim_name = "walk" if player_is_moving else "idle"; player_anim_frame = 0; player_anim_timer = 0.0; player_animation_component.apply_frame(self)
func _player_facing_vector() -> Vector2: return Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT if player_is_attacking else Vector2.LEFT if player.flip_h else Vector2.RIGHT
func _apply_player_attack_hitbox() -> void: if player_attack_component != null: player_attack_component.apply_hitbox(self)
func _damage_slime(slime: Sprite2D, amount: float, was_critical: bool = false) -> void:
	_damage_slime_with_number(slime, amount, was_critical, true)


func _damage_slime_with_number(slime: Sprite2D, amount: float, was_critical: bool, show_damage_number: bool) -> void:
	_register_combo_hit()
	var ambush := _slime_ambush(slime)
	if ambush != null:
		ambush.extend_rehide(slime, slime_tuning.ambush_hit_extension)
	SlimeActor.damage_actor(self, slime, amount, was_critical, show_damage_number)
	_play_sound("slash", -15.0, 0.95 + rng.randf_range(-0.10, 0.10))
	_play_sound("enemy_hit", -10.0, 0.88 + rng.randf_range(-0.06, 0.06))
func _player_attack_damage_against(slime: Sprite2D) -> float:
	var damage := _combat_damage(player_stats, _slime_stats(slime))
	var momentum := _combat_momentum()
	var multiplier := momentum.focus_multiplier(slime == current_target) * momentum.combo_multiplier()
	if equipment_transmutation_component != null:
		var snapshot := _player_stat_snapshot()
		var transmutation_multiplier := equipment_transmutation_component.duelist_damage_multiplier(slime, current_target, snapshot.strength)
		if not is_equal_approx(transmutation_multiplier, 1.0):
			equipment_transmutation_component.consume_duelist_feedback(slime == current_target, snapshot.strength)
		multiplier *= transmutation_multiplier
	return damage * multiplier
func _combat_momentum() -> CombatMomentumComponent:
	if combat_momentum == null:
		combat_momentum = CombatMomentumComponent.new()
		combat_momentum.configure(player_tuning)
	return combat_momentum
func _register_combo_hit() -> void: _combat_momentum().register_hit()
func _tick_focus_combo(delta: float) -> void:
	var momentum := _combat_momentum()
	var was_focus_active := momentum.focus_active
	momentum.tick(delta, current_target != null)
	if was_focus_active and not momentum.focus_active and current_target != null:
		_play_sound("ui_decline", -10.0, 1.0)
		focus_flash_timer = FOCUS_FLASH_TIME
func _reset_combo() -> void: _combat_momentum().reset_combo()
func _player_attack_damage_share_divisor(slime: Sprite2D, target_count: int) -> float:
	return equipment_transmutation_component.damage_share_divisor(slime, target_count) if equipment_transmutation_component != null else maxf(float(target_count), 1.0)
func _combat_damage(attacker_stats: StatsComponent, defender_stats: StatsComponent) -> float:
	var attacker_snapshot := CombatStatSnapshot.from_components(attacker_stats, player_equipment if attacker_stats == player_stats else null)
	var defender_snapshot := CombatStatSnapshot.from_components(defender_stats, player_equipment if defender_stats == player_stats else null)
	var strength_damage_scale := combat_tuning.damage_per_strength if attacker_stats == player_stats else combat_tuning.enemy_damage_per_strength
	var result := CombatCalculator.calculate_snapshot_damage(attacker_snapshot, defender_snapshot, attacker_stats == player_stats, rng, combat_tuning, strength_damage_scale)
	last_damage_was_critical = result.critical; return result.amount
func _max_health_for_stats(stats: StatsComponent) -> float: return CombatCalculator.max_health_for_snapshot(CombatStatSnapshot.from_components(stats, player_equipment if stats == player_stats else null), combat_tuning)
func _player_stat_snapshot() -> CombatStatSnapshot: return CombatStatSnapshot.from_components(player_stats, player_equipment)
func _recompute_player_speed_multiplier() -> void:
	if player_stats == null or player_tuning == null:
		return
	var snapshot := _player_stat_snapshot()
	player_spd = snapshot.speed
	player_speed_multiplier = player_tuning.speed_multiplier(snapshot.speed)
func _player_max_health() -> float: return _max_health_for_stats(player_stats)
func _enemy_max_health(slime: Sprite2D) -> float:
	var health := _max_health_for_stats(_slime_stats(slime))
	# The first run is onboarding: basic enemies should fall in roughly 2–3
	# clean hits. Later runs use the normal progression curve.
	var encounter_scale := _slime_encounter_scale(slime)
	if player_profile != null and player_profile.completed_runs <= 0 and encounter_scale <= 1.0:
		health *= 0.60
	if encounter_scale > 1.0:
		health *= encounter_scale * 0.90
		if player_profile != null and player_profile.completed_runs <= 0:
			health *= 0.50
	return health
func _enemy_level_for_room() -> int: return maxi(1, ceili(float(current_room_depth) / 4.0))
func _enemy_level_cap_for_run() -> int:
	# Early ranks keep a low level ceiling so runs feel readable and fair; once
	# the player reaches R11, depth is allowed to scale without a ceiling.
	return 999 if _run_rank() > 10 else 2 + _run_rank()
func _run_enemy_level_bonus() -> int: return maxi(0, _run_rank() - 8)
func _apply_enemy_room_level(slime: Sprite2D, level_override: int = 0) -> void:
	var stats := _slime_stats(slime)
	if stats == null:
		return
	var requested_level := (level_override if level_override > 0 else _enemy_level_for_room()) + _run_enemy_level_bonus() + (run_state.difficulty_bonus if run_state != null else 0)
	stats.level = clampi(requested_level, 1, _enemy_level_cap_for_run())
func _configure_slime_variant(slime: Sprite2D, variant: String) -> void:
	var palette := variant if variant == "blue" or variant == "green" or variant == "red" or variant == "purple" else "green"
	slime.set("variant", palette)
	var stats := _slime_stats(slime)
	if stats != null:
		stats.allocation_profile = StatsComponent.AllocationProfile.FAVOR_DEF if palette == "blue" else StatsComponent.AllocationProfile.FAVOR_STR if palette == "red" else StatsComponent.AllocationProfile.FAVOR_STR_DEF if palette == "purple" else StatsComponent.AllocationProfile.FAVOR_VIT
	_configure_slime_ambush(slime, palette)
func _knockback_slime(slime: Sprite2D) -> void:
	if _is_slime_dead(slime): return
	var direction := _slime_knockback_direction(slime)
	var knockback_multiplier := equipment_transmutation_component.attack_knockback_multiplier() if equipment_transmutation_component != null else 1.0
	var attack_component := player_attack_component as PlayerAttackComponent
	var combo_multiplier := 1.0 if attack_component != null and attack_component.variant == 2 else player_tuning.attack1_knockback_multiplier
	var combat := _slime_combat(slime); combat.knockback_velocity = _perspective_movement(direction.normalized() * (player_tuning.attack_knockback * combo_multiplier * knockback_multiplier / slime_tuning.knockback_duration)); combat.knockback_timer = slime_tuning.knockback_duration
	var brain := _slime_brain(slime); brain.scoot_start = slime.position; brain.scoot_target = slime.position; brain.scoot_timer = 0.0; brain.hold_timer = slime_tuning.hitstun_time
func _slime_knockback_direction(slime: Sprite2D) -> Vector2:
	var direction := _actor_foot(slime) - _actor_foot(player)
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT
	return direction.normalized()
func _kill_slime(slime: Sprite2D) -> void:
	if _is_slime_dead(slime): return
	if run_state != null and run_state.active:
		run_state.record_enemy_kill()
	_play_sound("enemy_death", -6.0, 0.90 + rng.randf_range(-0.08, 0.08))
	_award_slime_xp(slime)
	var drop_seed := int(current_dungeon_seed) ^ String(current_room_id).hash() ^ slime.get_instance_id()
	var drop_rng := RandomNumberGenerator.new(); drop_rng.seed = drop_seed
	if drop_rng.randf() < chroma_tuning.enemy_drop_chance:
		_spawn_chroma_pickup(_actor_foot(slime), chroma_tuning.pickup_value, drop_seed, _slime_knockback_direction(slime))
	effects_spawner.spawn_slime_death_from_root(self, slime); room_controller.kill_slime_without_effects(self, slime)
	if current_target == slime:
		if _is_target_input_held(): _set_current_target(_closest_target(), false)
		else: _set_current_target(null, false); _set_target_ui_visible(false)
	if _are_all_slimes_dead():
		_unlock_chest()
func _is_slime_dead(slime: Sprite2D) -> bool: return _slime_combat(slime).dead
func _are_all_slimes_dead() -> bool:
	for slime in slimes: if not _is_slime_dead(slime): return false
	return true
func _unlock_chest() -> void:
	if chest_unlocked: return
	chest_unlocked = true; if chest_normal_texture != null: chest_controller.start_unlock_fade(self)
	_play_sound("chest_unlock", -6.0, 1.0)
func _build_interact_prompt() -> void:
	var interaction_marker := _load_texture_or_null("res://assets/artwork/circle55.png")
	interact_prompt = interaction_component.build_prompt(self, interaction_marker, OVERWORLD_UI_Z + 1); interact_prompt_base_position = Vector2(6, -7)
func _build_npc_dialogue() -> void: var dialogue := npc_controller.build_dialogue(self, _load_texture_or_null("res://assets/artwork/circle55.png")); npc_controller.dialogue_layer = dialogue["layer"] as CanvasLayer; npc_controller.dialogue_box = dialogue["box"] as ColorRect; npc_controller.dialogue_text = dialogue["text"] as Sprite2D; npc_controller.dialogue_button = dialogue["button"] as Sprite2D; npc_controller.dialogue_button_shadow = dialogue["shadow"] as Sprite2D; npc_controller.dialogue_yes_text = dialogue["yes"] as Sprite2D; npc_controller.dialogue_no_text = dialogue["no"] as Sprite2D
func _build_room_number_indicator() -> void:
	var hud: Dictionary = hud_controller.build_world_hud(ui, sprite_frame_library, Callable(self, "_load_texture_or_null"), target_health_bar, target_health_fill, player_health_fill)
	hud_controller.room_number_indicator = hud["room"] as Sprite2D; hud_controller.dungeon_run_indicator = hud["dungeon_run"] as Sprite2D; hud_controller.gold_indicator = hud["gold"] as Sprite2D; hud_controller.gold_amount_indicator = hud["gold_amount"] as Sprite2D; 	hud_controller.run_timer_indicator = hud["timer"] as Sprite2D; hud_controller.gold_animation_frames = hud["gold_frames"] as Array[Texture2D]; hud_controller.button_hud_sprites = hud["buttons"] as Array[Sprite2D]; target_health_text = hud["target_text"] as Sprite2D; focus_label = hud["focus_label"] as Sprite2D; focus_label_base = hud["focus_label_base"] as Sprite2D; player_health_text = hud["player_text"] as Sprite2D; _update_room_number_indicator(); _update_gold_indicator()
	var hud_root := ui.get_node("PlayerHud") as Node2D
	var player_hud_color := _health_feedback_color(screen_state_controller.player_palette_name)
	hud_root.call("set_static_text", "lv. 1", player_hud_color)
	hud_root.call("apply_bar_colors", player_hud_color)
	_update_player_progression_ui()
func _update_gold_indicator() -> void: if hud_controller.gold_indicator != null: hud_controller.gold_amount_indicator.texture = _pixel_text_texture(str(player_profile.gold if player_profile != null else 0), Color8(255, 205, 117))
func _update_room_number_indicator() -> void: hud_controller.update_room_number(self)
func _set_entrance_open(is_open: bool) -> void:
	entrance_open = is_open; _refresh_room_socket_visuals(door_active)
func _update_rest_fire_animation(delta: float) -> void:
	rest_fire_controller.update_animation(rest_fire, rest_fire_frames, delta, FIRE_FRAME_TIME, Callable(self, "_refresh_rest_fire_image"))
	var light_step := posmod(floori(rest_fire_controller.frame_index * 0.65), 6)
	var energy_steps := [0.10, 0.14, 0.18, 0.15, 0.11, 0.13]
	var scale_steps := [0.64, 0.72, 0.82, 0.76, 0.66, 0.72]
	var fire_light := rest_fire.get_node_or_null("FireLight") as PointLight2D
	if fire_light != null and rest_fire.visible:
		fire_light.energy = energy_steps[light_step]
		fire_light.texture_scale = scale_steps[light_step]
func _refresh_rest_fire_image(fire: Sprite2D) -> void: occlusion_renderer.sprite_images[fire] = occlusion_renderer.cached_texture_image(fire.texture)
func _set_rest_fire_frame(frame_index: int) -> void:
	if rest_fire_frames.is_empty(): return
	rest_fire_controller.frame_index = posmod(frame_index, rest_fire_frames.size()); rest_fire.texture = rest_fire_frames[rest_fire_controller.frame_index]; rest_fire.hframes = 1; rest_fire.frame = 0; occlusion_renderer.sprite_images[rest_fire] = occlusion_renderer.cached_texture_image(rest_fire.texture)
func _update_cloaked_demon_animation(delta: float) -> void:
	var near_player := _can_interact_with_npc(); var patrolling := (current_room_type == DungeonGraph.ROOM_START or current_room_type == DungeonGraph.ROOM_NPC) and not near_player and (npc_controller.dialogue_box == null or not npc_controller.dialogue_box.visible)
	var result := npc_controller.update_patrol_animation(cloaked_demon, npc_controller.demon_idle_frames, npc_controller.demon_walk_frames, delta, near_player, patrolling, npc_controller.demon_patrol_paused, npc_controller.demon_wander_target, npc_controller.demon_wander_has_target, npc_controller.demon_patrol_pause_timer, npc_controller.demon_patrol_direction, player.global_position.x, rng, Callable(self, "_cloaked_demon_foot_position"), Callable(self, "_random_npc_walkable_point_near"), Callable(self, "_move_cloaked_demon"), Callable(self, "_perspective_movement"), Callable(self, "_cache_npc_texture"), npc_controller.demon_animation_timer, npc_controller.demon_animation_frame)
	npc_controller.demon_wander_target = result["wander_target"]; npc_controller.demon_wander_has_target = result["has_target"]; npc_controller.demon_patrol_paused = result["paused"]; npc_controller.demon_patrol_pause_timer = result["pause_timer"]; npc_controller.demon_patrol_direction = result["direction"]; npc_controller.demon_animation_timer = result["timer"]; npc_controller.demon_animation_frame = result["frame"]
func _move_cloaked_demon(movement: Vector2, max_step: float) -> bool: return actor_collision_system.try_move_swept(cloaked_demon, movement, max_step, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _cache_npc_texture(_actor: Sprite2D, texture: Texture2D) -> void: occlusion_renderer.sprite_images[cloaked_demon] = occlusion_renderer.cached_texture_image(texture)
func _can_interact_with_chest() -> bool: return chest_unlocked and not chest_claimed and _actor_foot(player).distance_to(_collision_rect(chest).get_center()) <= CHEST_INTERACT_DISTANCE
func _on_chest_collected() -> void:
	if current_room_type == DungeonGraph.ROOM_DOWNSTAIRS and _are_all_slimes_dead():
		_open_final_exit()

func _open_final_exit() -> void:
	if final_exit_open or settlement_room_active:
		return
	final_exit_open = true
	var exit_socket := room_controller.dungeon_sockets.get(DungeonGraph.WALL_RIGHT) as DungeonSocket
	if exit_socket != null:
		room_controller.active_door_sockets[DungeonGraph.WALL_RIGHT] = exit_socket
	door_active = true
	entrance_open = false
	_refresh_room_socket_visuals(true)
	_build_entrance_block_polygons()

func _enter_final_settlement_room() -> void:
	if not final_exit_open or settlement_room_active:
		return
	final_exit_open = false
	settlement_room_active = true
	room_transition_locked = true
	player_is_attacking = false
	player_is_rolling = false
	player_is_defending = false
	player.global_position = Vector2(120, 80)
	player.flip_h = false
	map_root.visible = false
	player_shadow.visible = false
	player_attack_visual.visible = false
	for slime in slimes:
		slime.visible = false
	cloaked_demon.visible = false
	chest.visible = false
	_set_target_ui_visible(false)
	_update_depth_sorting()
	_complete_run()
func _can_interact_with_npc() -> bool: return cloaked_demon != null and cloaked_demon.visible and _actor_foot(player).distance_to(_cloaked_demon_visual_center()) <= NPC_INTERACT_DISTANCE
func _fire_target_palette() -> String:
	if current_fire_palette_name.is_empty():
		return ""
	# A fire assigned the starter palette must remain usable as a route back to
	# that palette after the player changes away from it. Other fires retain
	# their existing behavior and continue to offer their assigned color.
	var starter_palette := run_start_palette_name
	if starter_palette.is_empty() and screen_state_controller != null:
		starter_palette = screen_state_controller.player_palette_name
	# During the first Chroma slice, only the file's selected starter flame is
	# an attunement source. Other legacy random rest-fire palettes stay inert
	# until the later flame-swap curriculum is implemented.
	if player_chroma_component != null and current_fire_palette_name != starter_palette:
		return ""
	if current_fire_palette_name == starter_palette and screen_state_controller != null and screen_state_controller.player_palette_name != starter_palette:
		return starter_palette
	return current_fire_palette_name


func _can_interact_with_fire() -> bool:
	var target_palette := _fire_target_palette()
	if rest_fire == null or not rest_fire.visible or target_palette.is_empty() or screen_state_controller == null:
		return false
	var palette_change_available: bool = target_palette != String(screen_state_controller.player_palette_name)
	var mp_restore_available := _current_player_chroma() < PLAYER_MAX_MP
	return (palette_change_available or mp_restore_available) and _actor_foot(player).distance_to(_fire_anchor()) <= FIRE_INTERACT_DISTANCE
func _fire_anchor() -> Vector2:
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	if firepit != null:
		return _collision_rect(firepit).get_center()
	return rest_fire.global_position
func _interact_with_fire() -> void:
	var new_palette := _fire_target_palette()
	if new_palette.is_empty(): return
	_play_sound("ui_confirm", 0.0, 1.0)
	if new_palette != screen_state_controller.player_palette_name:
		_start_player_palette_flash(new_palette)
	var flame := AspectCatalogScript.flame_for_palette(new_palette)
	if player_chroma_component != null and not flame.is_empty() and player_chroma_component.call("attune_flame", flame):
		_update_player_mp_ui()
		if current_room_type == DungeonGraph.ROOM_START and not starter_flame_attuned_this_run:
			starter_flame_attuned_this_run = true
			_set_door_active(true)
			_set_entrance_open(true)
	else:
		_restore_player_mp()
func _start_player_palette_flash(new_palette: String) -> void:
	screen_state_controller.player_palette_name = new_palette
	current_player_palette_name = new_palette
	_apply_player_palette_async(new_palette)
	_update_player_aggro_marker_colors()
	var old_overlay := player_palette_flash_overlay
	if old_overlay != null: old_overlay.queue_free()
	var overlay := Sprite2D.new()
	overlay.name = "PlayerPaletteFlash"
	var source := occlusion_renderer.original_actor_textures.get(player, player.texture) as Texture2D
	overlay.texture = _white_texture(source)
	overlay.centered = player.centered
	overlay.offset = player.offset
	overlay.scale = player.scale
	overlay.flip_h = player.flip_h
	overlay.flip_v = player.flip_v
	overlay.texture_filter = player.texture_filter
	overlay.z_as_relative = false
	overlay.z_index = player.z_index + 2
	overlay.top_level = true
	overlay.global_position = player.global_position
	overlay.modulate = Color(1, 1, 1, 0.0)
	player.add_child(overlay)
	player_palette_flash_overlay = overlay
	player_palette_flash_phase = 0
	player_palette_flash_timer = 0.0
func _update_player_palette_flash(delta: float) -> void:
	var overlay := player_palette_flash_overlay
	if overlay == null: return
	var timer := player_palette_flash_timer + delta
	overlay.global_position = player.global_position; overlay.scale = player.scale; overlay.offset = player.offset; overlay.flip_h = player.flip_h; overlay.flip_v = player.flip_v; overlay.z_index = player.z_index + 2
	match player_palette_flash_phase:
		0:
			overlay.modulate.a = minf(timer / PLAYER_PALETTE_FADE_IN, 1.0)
			if timer >= PLAYER_PALETTE_FADE_IN: player_palette_flash_phase = 1; player_palette_flash_timer = 0.0
			else: player_palette_flash_timer = timer
		1:
			overlay.modulate.a = 1.0
			if timer >= PLAYER_PALETTE_HOLD_TIME: player_palette_flash_phase = 2; player_palette_flash_timer = 0.0
			else: player_palette_flash_timer = timer
		_:
			overlay.modulate.a = maxf(1.0 - timer / PLAYER_PALETTE_FADE_OUT, 0.0)
			if timer >= PLAYER_PALETTE_FADE_OUT: overlay.queue_free(); player_palette_flash_overlay = null; player_palette_flash_phase = 0; player_palette_flash_timer = 0.0
			else: player_palette_flash_timer = timer
func _update_interact_prompt(delta: float) -> void: interaction_component.update_world_prompt(self, delta, NPC_DIALOGUE_BUTTON_BOB_TIME, OVERWORLD_UI_Z + 1)
func _set_door_active(is_active: bool) -> void:
	room_puzzle_controller.call("set_door_active", self, is_active)
func _collect_dungeon_sockets() -> void:
	room_controller.dungeon_sockets.clear()
	if sockets_root == null: return
	for child in sockets_root.get_children(): var socket := child as DungeonSocket; if socket != null: room_controller.dungeon_sockets[socket.socket_id()] = socket
func _sync_current_room_metadata() -> void:
	run_flow_controller.call("sync_current_room_metadata", self)
func _finalize_run_exploration() -> void:
	run_flow_controller.call("finalize_run_exploration", self)
func _finalize_run_enemy_total() -> void:
	run_flow_controller.call("finalize_run_enemy_total", self)
func _ensure_current_room_layout() -> void:
	var room := dungeon_graph.get_room(current_room_id)
	if room == null: return
	room_controller.progression_run_rank = _run_rank()
	_apply_room_geometry()
	_collect_walkable_tiles(floor_tiles)
	_build_entrance_block_polygons()
	_build_walkable_outline()
	var state := room_controller.ensure_layout(dungeon_graph, current_room_id, room, current_room_type, current_room_depth)
	var required_aspect: StringName = &""
	if current_room_type == DungeonGraph.ROOM_PUZZLE:
		required_aspect = _puzzle_required_aspect(room)
		state["puzzle_required_flame"] = String(required_aspect)
		if not state.has("puzzle_torch_colors"):
			var initial_palette := AspectCatalogScript.palette_for_flame(_current_run_puzzle_flame()) if required_aspect == &"gray" else "grey"
			state["puzzle_torch_colors"] = [initial_palette, initial_palette]
		_build_puzzle_torches(state)
		state["finished"] = _puzzle_torches_solved(_puzzle_palette_for_aspect(required_aspect))
		room_controller.room_states[current_room_id] = state
	else:
		_clear_puzzle_torches()
	_configure_room_sockets(bool(state.get("finished", false)))
	_update_puzzle_room_tint(room if current_room_type == DungeonGraph.ROOM_PUZZLE else null, required_aspect)
func _configure_room_sockets(is_unlocked: bool) -> void:
	room_puzzle_controller.call("configure_room_sockets", self, is_unlocked)

func _current_run_puzzle_flame() -> StringName:
	return room_puzzle_controller.call("current_run_puzzle_flame", self) as StringName

func _puzzle_required_aspect(room: DungeonGraph.RoomRecord) -> StringName:
	return room_puzzle_controller.call("puzzle_required_aspect", self, room) as StringName

func _puzzle_palette_for_aspect(aspect: StringName) -> String:
	return str(room_puzzle_controller.call("puzzle_palette_for_aspect", aspect))

func _update_puzzle_room_tint(room: DungeonGraph.RoomRecord, required_flame: StringName) -> void:
	room_puzzle_controller.call("update_puzzle_room_tint", self, room, required_flame)

func _apply_puzzle_environment_tint(tint: Color) -> void:
	room_puzzle_controller.call("apply_puzzle_environment_tint", self, tint)

func _set_puzzle_surface_tint(node: Node, tint: Color) -> void:
	room_puzzle_controller.call("set_puzzle_surface_tint", node, tint)

func _build_puzzle_torches(state: Dictionary) -> void:
	room_puzzle_controller.call("build_puzzle_torches", self, state)

func _clear_puzzle_torches() -> void:
	room_puzzle_controller.call("clear_puzzle_torches", self)

func _puzzle_torches_solved(required_palette: String) -> bool:
	return bool(room_puzzle_controller.call("puzzle_torches_solved", self, required_palette))

func _refresh_puzzle_torch_puzzle_state() -> void:
	room_puzzle_controller.call("refresh_puzzle_torch_puzzle_state", self)

func _activate_puzzle_torch(torch: Sprite2D, world_position: Vector2, palette: String) -> void:
	room_puzzle_controller.call("activate_puzzle_torch", self, torch, world_position, palette)
func _refresh_room_socket_visuals(is_unlocked: bool) -> void:
	room_puzzle_controller.call("refresh_room_socket_visuals", self, is_unlocked)
func _apply_room_geometry() -> void:
	if floor_tiles == null: return
	_capture_normal_room_geometry()
	if current_room_type != DungeonGraph.ROOM_DOWNSTAIRS:
		_restore_normal_room_geometry()
		var underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
		if underlay != null: underlay.visible = false
		_configure_large_room_camera(false)
		return
	_apply_authored_boss_room_geometry()
	_configure_large_room_camera(true)
func _apply_authored_boss_room_geometry() -> void:
	# The dedicated debug scene already contains the authored geometry. Avoid
	# instantiating a second full gameplay scene when testing it directly.
	if scene_file_path == "res://scenes/boss_room_debug.tscn":
		var existing_underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
		if existing_underlay != null: existing_underlay.visible = true
		return
	var packed_scene := load("res://scenes/boss_room_debug.tscn") as PackedScene
	if packed_scene == null:
		push_error("Could not load the authored boss room scene.")
		return
	var template := packed_scene.instantiate()
	for path in ["Map/FloorTiles/FloorLayer", "Map/FloorTiles/FloorLFaceLayer", "Map/FloorTiles/FloorRFaceLayer", "Map/Walls/WallLeftLayer", "Map/Walls/WallRightLayer"]:
		_copy_authored_tile_layer(template.get_node_or_null(path) as TileMapLayer, get_node_or_null(path) as TileMapLayer)
	_copy_authored_polygon(template, "Map/FloorTiles/FloorCollisionGuide")
	_copy_boss_floor_underlay(template)
	for path in ["Map/FloorTiles/Entrance", "Map/FloorTiles/EntranceRight", "Map/Walls/DoorLeft", "Map/Walls/DoorRight"]:
		_copy_authored_room_sprite(template, path)
	template.free()
func _copy_authored_room_sprite(template: Node, path: NodePath) -> void:
	var source := template.get_node_or_null(path) as Sprite2D
	var destination := get_node_or_null(path) as Sprite2D
	if source == null or destination == null: return
	destination.position = source.position
	destination.texture = source.texture
	destination.flip_h = source.flip_h
	destination.flip_v = source.flip_v
	destination.offset = source.offset
	destination.scale = source.scale
func _copy_boss_floor_underlay(template: Node) -> void:
	var source := template.get_node_or_null("Map/FloorTiles/BossFloorUnderlay") as Polygon2D
	if source == null: return
	var underlay := floor_tiles.get_node_or_null("BossFloorUnderlay") as Polygon2D
	if underlay == null:
		underlay = Polygon2D.new()
		underlay.name = "BossFloorUnderlay"
		floor_tiles.add_child(underlay)
	underlay.position = source.position
	underlay.polygon = source.polygon.duplicate()
	underlay.color = source.color
	underlay.z_index = -1
	underlay.visible = true
func _copy_authored_tile_layer(source: TileMapLayer, destination: TileMapLayer) -> void:
	if source == null or destination == null: return
	destination.clear()
	for cell in source.get_used_cells():
		destination.set_cell(cell, source.get_cell_source_id(cell), source.get_cell_atlas_coords(cell), source.get_cell_alternative_tile(cell))
	destination.update_internals()
func _copy_authored_polygon(template: Node, path: NodePath) -> void:
	var source := template.get_node_or_null(path) as Polygon2D
	var destination := get_node_or_null(path) as Polygon2D
	if source == null or destination == null: return
	destination.position = source.position
	destination.polygon = source.polygon.duplicate()
func _capture_normal_room_geometry() -> void:
	if not normal_room_geometry.is_empty(): return
	for path in ["FloorTiles/FloorLayer", "FloorTiles/FloorLFaceLayer", "FloorTiles/FloorRFaceLayer", "Walls/WallLeftLayer", "Walls/WallRightLayer"]:
		var layer := map_root.get_node_or_null(path) as TileMapLayer
		if layer != null: normal_room_geometry[path] = layer.get_used_cells()
	var guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as Polygon2D
	if guide != null:
		normal_room_geometry["guide_position"] = guide.position
		normal_room_geometry["guide_polygon"] = guide.polygon.duplicate()
	for path in ["FloorTiles/Entrance", "FloorTiles/EntranceRight", "Walls/DoorLeft", "Walls/DoorRight"]:
		var node := map_root.get_node_or_null(path) as Sprite2D
		if node != null:
			normal_room_geometry["position:%s" % path] = node.position
			normal_room_geometry["texture:%s" % path] = node.texture
			normal_room_geometry["flip_h:%s" % path] = node.flip_h
			normal_room_geometry["flip_v:%s" % path] = node.flip_v
			normal_room_geometry["offset:%s" % path] = node.offset
			normal_room_geometry["scale:%s" % path] = node.scale
func _restore_normal_room_geometry() -> void:
	if normal_room_geometry.is_empty(): return
	for path in ["FloorTiles/FloorLayer", "FloorTiles/FloorLFaceLayer", "FloorTiles/FloorRFaceLayer", "Walls/WallLeftLayer", "Walls/WallRightLayer"]:
		var layer := map_root.get_node_or_null(path) as TileMapLayer
		if layer == null: continue
		layer.clear()
		var saved_cells: Array = normal_room_geometry.get(path, []) as Array
		for cell_value in saved_cells:
			var cell: Vector2i = cell_value
			layer.set_cell(cell, 0, Vector2i.ZERO)
		layer.update_internals()
	var guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as Polygon2D
	if guide != null:
		var saved_guide_position: Vector2 = normal_room_geometry.get("guide_position", guide.position)
		var saved_guide_polygon: PackedVector2Array = normal_room_geometry.get("guide_polygon", guide.polygon)
		guide.position = saved_guide_position
		guide.polygon = saved_guide_polygon
	for path in ["FloorTiles/Entrance", "FloorTiles/EntranceRight", "Walls/DoorLeft", "Walls/DoorRight"]:
		var node := map_root.get_node_or_null(path) as Sprite2D
		if node != null:
			var saved_position: Vector2 = normal_room_geometry.get("position:%s" % path, node.position)
			node.position = saved_position
			var saved_texture: Texture2D = normal_room_geometry.get("texture:%s" % path, node.texture)
			node.texture = saved_texture
			node.flip_h = bool(normal_room_geometry.get("flip_h:%s" % path, node.flip_h))
			node.flip_v = bool(normal_room_geometry.get("flip_v:%s" % path, node.flip_v))
			var saved_offset: Vector2 = normal_room_geometry.get("offset:%s" % path, node.offset)
			var saved_scale: Vector2 = normal_room_geometry.get("scale:%s" % path, node.scale)
			node.offset = saved_offset
			node.scale = saved_scale
func _configure_large_room_camera(enabled: bool) -> void:
	var camera := player.get_node_or_null("LargeRoomCamera") as Camera2D
	if camera == null:
		camera = Camera2D.new()
		camera.name = "LargeRoomCamera"
		camera.position_smoothing_enabled = true
		camera.position_smoothing_speed = 5.5
		camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
		player.add_child(camera)
		camera.top_level = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.5
	camera.enabled = enabled
	if enabled: _update_large_room_camera()
func _update_large_room_camera() -> void:
	var camera := player.get_node_or_null("LargeRoomCamera") as Camera2D
	if camera == null or not camera.enabled: return
	var actor_center := _actor_foot(player) + Vector2(0.0, -7.0)
	camera.global_position = actor_center
func _update_door_transition() -> void: if not room_transition_locked: room_controller.try_enter_active_socket(self, door_active, entrance_open, room_transition_locked)
func _try_enter_any_active_socket() -> bool: return room_controller.try_enter_active_socket(self, door_active, entrance_open, room_transition_locked)
func _enter_connected_room(destination_room_id: StringName, arrival_socket_id: StringName) -> void: room_controller.enter_connected_room(self, destination_room_id, arrival_socket_id)
func _release_room_transition_lock() -> void: room_transition_locked = false; if room_controller != null: room_controller.end_transition()
func _save_current_room_state() -> void:
	var state := room_controller.room_states.get(current_room_id, {}) as Dictionary
	if current_room_type == DungeonGraph.ROOM_PUZZLE:
		var room: DungeonGraph.RoomRecord = dungeon_graph.get_room(current_room_id) if dungeon_graph != null else null
		var required_aspect := StringName(state.get("puzzle_required_flame", _puzzle_required_aspect(room)))
		state["finished"] = _puzzle_torches_solved(_puzzle_palette_for_aspect(required_aspect))
	else:
		state["finished"] = chest_claimed
	if world_item_drop != null and is_instance_valid(world_item_drop) and world_item_drop_instance != null:
		state["world_item_drop"] = {"item": world_item_drop_instance.to_dictionary(), "position": world_item_drop.global_position}
	else:
		state.erase("world_item_drop")
	var saved_pickups: Array = []
	for index in chroma_pickup_controller.sprites.size():
		var pickup := chroma_pickup_controller.sprites[index]
		if pickup != null and is_instance_valid(pickup):
			saved_pickups.append({"position": pickup.global_position, "value": chroma_pickup_controller.values[index]})
	if saved_pickups.is_empty(): state.erase("chroma_pickups")
	else: state["chroma_pickups"] = saved_pickups
	room_controller.room_states[current_room_id] = state
	if room_controller != null and bool(state.get("finished", false)): room_controller.mark_cleared(current_room_id)
func _apply_room_state() -> void: room_controller.apply_state(self)
func _apply_rest_room_state() -> void: room_controller.apply_rest_state(self)
func _apply_npc_room_state() -> void: room_controller.apply_npc_state(self)
func _apply_finished_room_state() -> void: room_controller.apply_finished_state(self)
func _snap_half_pixel(world_position: Vector2) -> Vector2: return Vector2(snappedf(world_position.x, 0.5), snappedf(world_position.y, 0.5))
func _pixel_particle_texture(color: Color, size: int = 1) -> Texture2D:
	var key := "%02X%02X%02X:%d" % [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0)), size]
	if effects_spawner.pixel_particle_texture_cache.has(key):
		return effects_spawner.pixel_particle_texture_cache[key]
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8); image.fill(color); var texture := ImageTexture.create_from_image(image)
	effects_spawner.pixel_particle_texture_cache[key] = texture
	return texture
func _white_texture(source: Texture2D) -> Texture2D: return occlusion_renderer.white_texture(source)
func _try_knockback_slime(slime: Sprite2D, movement: Vector2) -> bool:
	# Axis movement lets an angled impact glide along a wall instead of repeatedly
	# driving the slime into it for the remainder of the knockback timer.
	var original := slime.position
	if _slime_position_is_valid(slime):
		slime_last_valid_positions[slime] = original
	var moved := _try_move_actor_axes(slime, movement)
	_separate_slime_from_player(slime)
	# Contact resolution happens after swept movement and can push an actor. Never
	# allow that secondary push to commit a footprint outside the floor polygon.
	if not _can_actor_stand_at_current_position(slime) or _collides_with_static(slime):
		slime.position = original
		moved = false
	var actual_movement := slime.position - original
	var moved_distance := slime.position.distance_to(original)
	var x_clipped := absf(movement.x) > 0.01 and absf(actual_movement.x) < absf(movement.x) * 0.92
	var y_clipped := absf(movement.y) > 0.01 and absf(actual_movement.y) < absf(movement.y) * 0.92
	var blocked := not moved or moved_distance < movement.length() * 0.92 or x_clipped or y_clipped
	if blocked:
		# Do not leave the slime parked on the exact boundary reached by a partial
		# knockback. Roll back, then take a tiny step opposite the impact so its
		# next pathfinding move starts with usable clearance from the wall.
		slime.position = original
		if movement.length_squared() > 0.001:
			actor_collision_system.try_move_swept(slime, -movement.normalized() * 2.5, 0.5, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
		_recover_slime_position(slime)
		var combat := _slime_combat(slime)
		combat.knockback_timer = 0.0
		combat.knockback_velocity = Vector2.ZERO
		_repath_slime_after_block(slime)
	return slime.position.distance_squared_to(original) > 0.0001 if blocked else moved
func _separate_slime_from_player(slime: Sprite2D) -> void:
	var overlap_push := actor_collision_system.overlap_push_vector(self, slime, player); if overlap_push != Vector2.ZERO: actor_collision_system.try_move_swept(slime, overlap_push, 0.75, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _slime_brain(slime: Sprite2D) -> SlimeBrain: return SlimeActor.component(slime, "Brain", SlimeBrain) as SlimeBrain
func _slime_combat(slime: Sprite2D) -> SlimeCombatComponent: return SlimeActor.component(slime, "Combat", SlimeCombatComponent) as SlimeCombatComponent
func _slime_stats(slime: Sprite2D) -> StatsComponent: return slime.get_node_or_null("Stats") as StatsComponent
func _slime_visual(slime: Sprite2D) -> SlimeVisualComponent: return SlimeActor.component(slime, "Visual", SlimeVisualComponent) as SlimeVisualComponent
func _slime_animation(slime: Sprite2D) -> SlimeAnimationComponent: return SlimeActor.component(slime, "Animation", SlimeAnimationComponent) as SlimeAnimationComponent
func _slime_health_presenter(slime: Sprite2D) -> SlimeHealthPresenter: return SlimeActor.component(slime, "HealthPresenter", SlimeHealthPresenter) as SlimeHealthPresenter
func _slime_health(slime: Sprite2D) -> HealthComponent: return slime.get_node_or_null("Health") as HealthComponent
func _configure_slime_ambush(slime: Sprite2D, palette: String) -> void:
	var ambush := slime.get_node_or_null("Ambush") as SlimeAmbushComponent
	if palette == "purple":
		if ambush == null:
			ambush = SlimeAmbushComponent.new()
			ambush.name = "Ambush"
			slime.add_child(ambush)
		ambush.configure(true, slime_tuning.ambush_reveal_window, slime_tuning.ambush_block_stun, slime_tuning.ambush_hit_extension)
		ambush.apply_hidden(slime)
	elif ambush != null:
		ambush.configure(false, 0.0, 0.0, 0.0)
		slime.self_modulate = Color.WHITE
func _slime_ambush(slime: Sprite2D) -> SlimeAmbushComponent: return slime.get_node_or_null("Ambush") as SlimeAmbushComponent
func _is_slime_hidden(slime: Sprite2D) -> bool:
	var ambush := _slime_ambush(slime)
	return ambush != null and ambush.is_hidden()
func _is_slime_targetable(slime: Sprite2D) -> bool:
	if puzzle_torches.has(slime):
		return is_instance_valid(slime) and slime.visible
	return not _is_slime_dead(slime) and not _is_slime_hidden(slime)

func _is_target_actor_dead(target: Sprite2D) -> bool:
	return false if puzzle_torches.has(target) else _is_slime_dead(target)
func _move_slimes(delta: float) -> void:
	_prepare_slime_frame_cache()
	for slime in slimes:
		if not _is_slime_dead(slime):
			var slime_actor := slime as SlimeActor
			if slime_actor != null:
				slime_actor.tick_components(delta); slime_actor.tick_runtime(delta, Callable(self, "_is_slime_dead"), Callable(self, "_update_slime_knockback"), Callable(self, "_update_slime_attack"), Callable(self, "_is_slime_aggroed"), Callable(self, "_aggro_slime_target"), Callable(self, "_update_slime_scoot")); continue
			SlimeActor.tick_legacy_runtime(slime, delta, Callable(self, "_is_slime_dead"), Callable(self, "_update_slime_knockback"), Callable(self, "_update_slime_attack"), Callable(self, "_is_slime_aggroed"), Callable(self, "_aggro_slime_target"), Callable(self, "_update_slime_scoot"))
	# A single separation pass is enough in a packed encounter because every
	# slime is validated immediately afterward.  The former second pass could
	# multiply expensive polygon walkability checks for every overlapping boss
	# and add pair.
	var separation_passes := 1 if slimes.size() >= 5 else 2
	actor_collision_system.resolve_slime_contacts(slimes, self, separation_passes)
	# Attack lunges do not travel through the normal movement-input path. Resolve
	# slime/player contact after every slime update so lunging or idle enemies can
	# never finish a frame inside the player.
	if not player_dead:
		for slime in slimes:
			if is_instance_valid(slime) and slime.visible and not _is_slime_dead(slime):
				actor_collision_system.resolve_contact_pair(slime, player, Vector2.ZERO, self)
	# Swept movement and contact resolution already validate every moved slime.
	# Avoid re-testing each idle enemy against the room polygon every frame.

func _prepare_slime_frame_cache() -> void:
	slime_frame_aggro.clear()
	slime_frame_slots.clear()
	slime_frame_active_attackers = 0
	var player_foot := _actor_foot(player)
	for index in slimes.size():
		var slime := slimes[index]
		if _is_slime_dead(slime):
			continue
		slime_frame_slots[slime] = index
		var brain := _slime_brain(slime)
		var is_aggroed := not player_dead and (brain.persistent_aggro or _actor_foot(slime).distance_squared_to(player_foot) <= slime_tuning.aggro_range * slime_tuning.aggro_range)
		if is_aggroed and not brain.aggroed and not brain.notice_started and not _is_slime_hidden(slime):
			_trigger_slime_notice(slime)
			slime_frame_aggro[slime] = true
		else:
			slime_frame_aggro[slime] = is_aggroed
		var combat := _slime_combat(slime)
		if combat != null and combat.active:
			slime_frame_active_attackers += 1
	slime_frame_cache_valid = true

func _trigger_slime_notice(slime: Sprite2D) -> void:
	var brain := _slime_brain(slime)
	if brain == null or brain.notice_started or _is_slime_dead(slime):
		return
	brain.persistent_aggro = true
	var shocked_frames := _slime_shocked_frames(slime)
	var notice_duration := maxf(float(shocked_frames.size()) * SLIME_NOTICE_FRAME_TIME, SLIME_NOTICE_FRAME_TIME)
	brain.begin_notice(notice_duration)
	_set_slime_notice_frame(slime, 0)
	if run_state != null and run_state.active:
		run_state.record_enemy_encounter()
	effects_spawner.spawn_slime_notice(self, slime, notice_duration)
	_play_sound("enemy_alert", -8.0, 0.96 + rng.randf_range(-0.04, 0.04))
func _slime_position_is_valid(slime: Sprite2D) -> bool:
	return _can_actor_stand_at_current_position(slime) and not _collides_with_static(slime)
func _recover_slime_position(slime: Sprite2D) -> void:
	if _slime_position_is_valid(slime):
		slime_last_valid_positions[slime] = slime.position
		return
	if slime_last_valid_positions.has(slime):
		slime.position = slime_last_valid_positions[slime] as Vector2
	if not _slime_position_is_valid(slime):
		var recovery_foot := _nearest_valid_slime_walkable_point(_actor_foot(slime), slime)
		slime.position += recovery_foot - _actor_foot(slime)
	if _slime_position_is_valid(slime):
		slime_last_valid_positions[slime] = slime.position
	var combat := _slime_combat(slime)
	combat.knockback_timer = 0.0
	combat.knockback_velocity = Vector2.ZERO
func _update_slime_attack(slime: Sprite2D, delta: float) -> bool:
	var combat := _slime_combat(slime)
	var was_active := combat.active
	var result := combat.tick_attack(delta, slime, slime_tuning, _slime_attack_frames(slime), player_dead, Callable(self, "_set_slime_attack_frame"), Callable(self, "_set_actor_base_texture"), Callable(self, "_apply_slime_attack_lunge"), Callable(self, "_apply_slime_attack_hit"), Callable(self, "_restore_slime_idle_texture"), Callable(self, "_can_slime_attack_player"), Callable(self, "_start_slime_attack"))
	if was_active and not combat.active:
		var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
		if tactics != null:
			tactics.release_attack_slot()
	return result
func _set_slime_attack_frame(slime: Sprite2D, frame_index: int) -> void: _slime_animation(slime).set_attack_frame(frame_index)
func _start_slime_attack(slime: Sprite2D) -> void:
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		tactics.attack_reserved = true
	SlimeActor.start_attack_actor(self, slime)
func _slime_attack_frames(slime: Sprite2D) -> Array[Texture2D]:
	var visual := _slime_visual(slime); return [] if visual == null else visual.attack_left_frames if _slime_combat(slime).face_left else visual.attack_right_frames
func _slime_shocked_frames(slime: Sprite2D) -> Array[Texture2D]:
	var visual := _slime_visual(slime)
	return [] if visual == null else visual.shocked_frames
func _set_slime_notice_frame(slime: Sprite2D, frame_index: int) -> void:
	var frames := _slime_shocked_frames(slime)
	if frames.is_empty():
		return
	_set_actor_base_texture(slime, frames[clampi(frame_index, 0, frames.size() - 1)])
func _restore_slime_idle_texture(slime: Sprite2D) -> void: _set_slime_facing(slime, -1.0 if _slime_combat(slime).face_left else 1.0)
func _can_slime_attack_player(slime: Sprite2D) -> bool:
	var brain := _slime_brain(slime)
	if brain != null and brain.is_noticing():
		return false
	var attack_distance := _slime_attack_reach(slime)
	if player_dead or _slime_attack_offset(slime).length() > attack_distance:
		return false
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics == null:
		return true
	var own_combat := _slime_combat(slime)
	if tactics.attack_reserved and (own_combat == null or not own_combat.active):
		tactics.release_attack_slot()
	var active_attackers := slime_frame_active_attackers
	if not slime_frame_cache_valid:
		active_attackers = 0
		for other in slimes:
			if _is_slime_dead(other):
				continue
			var combat := _slime_combat(other)
			if combat != null and combat.active:
				active_attackers += 1
	var granted := tactics.request_attack_slot(active_attackers, MAX_ACTIVE_ENEMY_ATTACKERS)
	if granted and slime_frame_cache_valid:
		slime_frame_active_attackers += 1
	return granted
func _is_slime_aggroed(slime: Sprite2D) -> bool:
	if slime_frame_cache_valid and slime_frame_aggro.has(slime):
		return bool(slime_frame_aggro[slime])
	return not _is_slime_dead(slime) and not player_dead and (_slime_brain(slime).persistent_aggro or _actor_foot(slime).distance_to(_actor_foot(player)) <= slime_tuning.aggro_range)
func _is_any_slime_aggroed() -> bool:
	for slime in slimes: if _is_slime_aggroed(slime): return true
	return false
func _slime_attack_reach(slime: Sprite2D) -> float:
	var to_player := _slime_attack_offset(slime)
	var direction := to_player.normalized() if to_player.length_squared() > 0.001 else Vector2.RIGHT
	var encounter_scale := _slime_encounter_scale(slime)
	# Attack availability is derived from the same body polygon used by the bite
	# test. This keeps enlarged bosses from stopping short because an old
	# rectangular guide underestimated their actual body reach.
	return maxf(slime_tuning.attack_hit_range, _slime_attack_contact_gap(slime, direction)) + slime_tuning.attack_lunge_distance * encounter_scale + 0.75


func _slime_attack_contact_gap(slime: Sprite2D, direction: Vector2) -> float:
	var slime_body := _slime_body_polygon(slime)
	var slime_center := ActorGeometry.polygon_center(slime_body)
	var body_reach := ActorGeometry.directional_reach(slime_body, slime_center, direction)
	var player_rect := _collision_rect(player)
	var player_body := PackedVector2Array([player_rect.position, Vector2(player_rect.end.x, player_rect.position.y), player_rect.end, Vector2(player_rect.position.x, player_rect.end.y)])
	var player_reach := ActorGeometry.directional_reach(player_body, player_rect.get_center(), -direction)
	return maxf(body_reach + player_reach - 0.5, 0.0)


func _slime_attack_offset(slime: Sprite2D) -> Vector2:
	var slime_body := _slime_body_polygon(slime)
	var slime_center := ActorGeometry.polygon_center(slime_body) if slime_body.size() >= 3 else _collision_rect(slime).get_center()
	return _collision_rect(player).get_center() - slime_center
func _aggro_slime_target(slime: Sprite2D) -> Vector2:
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		var slot_index := int(slime_frame_slots.get(slime, slimes.find(slime)))
		tactics.set_formation_slot(-1 if slot_index % 3 == 1 else 1 if slot_index % 3 == 2 else 0)
	return SlimeBrain.aggro_target(self, slime)
func _apply_slime_attack_hit(slime: Sprite2D) -> void:
	var ambush := _slime_ambush(slime)
	if ambush != null:
		ambush.reveal(slime)
		ambush.begin_rehide(slime, slime_tuning.ambush_reveal_window)
	SlimeActor.apply_attack_hit(self, slime)
func _slime_attack_damage(slime: Sprite2D) -> float: return _combat_damage(_slime_stats(slime), player_stats)
func _mark_player_in_combat() -> void: if player_health_component != null: player_health_component.regen_delay_timer = player_tuning.regen_delay; player_health_component.regen_accumulator = 0.0
func _on_player_health_damaged(amount: float) -> void:
	_reset_combo()
	player_damage_fill_hold_timer = player_tuning.health_damage_hang_time
	if run_state != null:
		run_state.record_damage(amount)
	_play_sound("impact_flesh", -6.0, 0.95 + rng.randf_range(-0.08, 0.08))
func _on_player_health_changed(_current: float, _maximum: float) -> void: if is_instance_valid(player_health_fill): _update_player_health_ui()
func _on_player_health_healed(amount: float) -> void:
	player_display_health = minf(player_display_health, player_health_component.current_health if player_health_component != null else player_display_health)
	_spawn_player_healing_number(amount, Color8(177, 62, 83))
func _on_slime_health_damaged(_amount: float, slime: Sprite2D) -> void: _slime_health_presenter(slime).damage_fill_hold_timer = slime_tuning.health_damage_hang_time
func _on_slime_health_changed(_current: float, _maximum: float, slime: Sprite2D) -> void:
	if slime == current_target and is_instance_valid(target_health_fill): _update_target_ui()
func _on_slime_health_healed(amount: float, slime: Sprite2D) -> void:
	var health_component := _slime_health(slime); if health_component != null: _slime_health_presenter(slime).display_health = minf(_slime_health_presenter(slime).display_health, health_component.current_health)
	_spawn_slime_healing_number(slime, amount, _health_feedback_color(String(slime.get("variant"))))
func _update_player_health_regen(delta: float) -> void:
	if current_room_type != DungeonGraph.ROOM_START and current_room_type != DungeonGraph.ROOM_REST: return
	var max_health := _player_max_health(); if player_health_component != null and player_health_component.current_health >= max_health: return
	if _is_any_slime_aggroed(): _mark_player_in_combat(); return
	if player_health_component != null:
		player_health_component.regen_interval = player_tuning.regen_interval * 2.0
		player_health_component.regen_amount = maxf(1.0, roundf(max_health / 6.0))
		player_health_component.tick_regeneration(delta)
	_update_player_health_ui()
func _apply_slime_attack_lunge(slime: Sprite2D) -> void:
	var movement := _slime_attack_lunge_vector(slime)
	if movement.length_squared() <= 0.0001:
		return
	actor_collision_system.try_move_swept(slime, movement, 0.75, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))


func _slime_attack_lunge_vector(slime: Sprite2D) -> Vector2:
	var to_player := _slime_attack_offset(slime)
	var direction := Vector2.LEFT if to_player.length_squared() < 0.01 and _slime_combat(slime).face_left else Vector2.RIGHT if to_player.length_squared() < 0.01 else to_player.normalized()
	# The vector between combat-body centers is already in world coordinates.
	# Running it through perspective movement flattened vertical lunges. Directional
	# polygon reach also avoids using the boss's wide horizontal radius vertically.
	var contact_gap := _slime_attack_contact_gap(slime, direction)
	var max_lunge := slime_tuning.attack_lunge_distance * _slime_encounter_scale(slime)
	var lunge_distance := minf(max_lunge, maxf(to_player.length() - contact_gap, 0.0))
	return direction * lunge_distance
func _apply_player_hit_knockback(slime: Sprite2D) -> void:
	var direction := _actor_foot(player) - _actor_foot(slime)
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT if player.global_position.x >= slime.global_position.x else Vector2.LEFT
	if player_motor != null:
		player_motor.start_knockback(_perspective_movement(direction.normalized() * (player_tuning.hit_knockback / player_tuning.hit_knockback_duration)), player_tuning.hit_knockback_duration)
func _update_slime_knockback(slime: Sprite2D, delta: float) -> bool: return _slime_combat(slime).tick_knockback(delta, slime, Callable(self, "_try_knockback_slime"), Callable(self, "_reset_slime_scoot"))
func _reset_slime_scoot(slime: Sprite2D) -> void:
	var brain := _slime_brain(slime)
	brain.scoot_start = slime.position
	brain.scoot_target = slime.position
	brain.scoot_timer = 0.0
	brain.hold_timer = 0.0
	brain.repath_timer = 0.0
	brain.blocked_repath_cooldown = 0.0
	_set_actor_visual_scale(slime, Vector2.ONE)
func _show_slime_hit_flash(slime: Sprite2D) -> void:
	var overlay := slime.get_node_or_null("HitFlashOverlay") as Sprite2D
	if overlay == null:
		overlay = Sprite2D.new()
		overlay.name = "HitFlashOverlay"
		overlay.centered = slime.centered
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slime.add_child(overlay)
	var source := occlusion_renderer.original_actor_textures.get(slime, slime.texture) as Texture2D
	if source != null:
		overlay.texture = occlusion_renderer.white_texture(source)
		ActorGeometry.sync_overlay(overlay, slime)
	overlay.z_as_relative = true
	overlay.z_index = 1
	overlay.visible = overlay.texture != null

func _update_enemy_hit_flashes(delta: float) -> void:
	for slime in slimes:
		if _is_slime_dead(slime):
			continue
		var combat := _slime_combat(slime)
		combat.flash_timer = maxf(combat.flash_timer - delta, 0.0)
		var overlay := slime.get_node_or_null("HitFlashOverlay") as Sprite2D
		if overlay != null:
			if combat.flash_timer > 0.0:
				_show_slime_hit_flash(slime)
			else:
				overlay.visible = false
func _update_enemy_health(delta: float) -> void:
	for slime in slimes: if not _is_slime_dead(slime): _slime_health_presenter(slime).update(delta, _slime_health(slime), _enemy_max_health(slime), slime_tuning)
func _spawn_damage_number(slime: Sprite2D, amount: float, was_critical: bool = false) -> void:
	_spawn_floating_number(slime.global_position + Vector2(5, -9), int(round(amount)), Vector2(0.0, -effects_tuning.damage_number_float_speed), was_critical)
func _spawn_player_number(text: String, value: int, color: Color, is_healing: bool, display_text: String) -> void:
	var origin := _player_floating_number_origin(text, color)
	_spawn_floating_number(origin, value, Vector2(0.0, effects_tuning.damage_number_float_speed), false, is_healing, color, display_text)
func _spawn_player_damage_number(amount: float) -> void:
	var value := int(round(amount))
	_spawn_player_number(str(maxi(value, 0)), value, Color.WHITE, false, "")
func _spawn_player_shield_damage_number(amount: float) -> void:
	var value := int(round(amount))
	var color := Color8(148, 220, 255)
	var origin := _player_floating_number_origin(str(maxi(value, 0)), color) + Vector2(8, 0)
	_spawn_floating_number(origin, value, Vector2(0.0, effects_tuning.damage_number_float_speed), false, false, color, str(maxi(value, 0)))
func _spawn_player_healing_number(amount: float, color: Color) -> void:
	var value := int(round(amount))
	_spawn_player_number("+%d" % maxi(value, 0), value, color, true, "")
func _apply_player_lifesteal(damage: float) -> void:
	if equipment_transmutation_component == null or player_health_component == null:
		return
	var heal := equipment_transmutation_component.life_steal_amount(damage)
	if heal <= 0.0:
		return
	var applied := player_health_component.apply_healing(heal)
	if applied <= 0.0:
		return
	_update_player_health_ui()
	_spawn_player_healing_number(applied, Color8(177, 62, 83))
func _player_floating_number_origin(text: String, color: Color) -> Vector2:
	var number_texture := _pixel_text_texture(text, color) as Texture2D
	var number_width := number_texture.get_width() if number_texture != null else 0
	return _actor_foot(player) + Vector2(-float(number_width) * 0.5, 2)
func _spawn_slime_healing_number(slime: Sprite2D, amount: float, color: Color) -> void:
	_spawn_floating_number(slime.global_position + Vector2(5, -9), int(round(amount)), Vector2(0.0, -effects_tuning.damage_number_float_speed), false, true, color)
func _spawn_floating_number(world_position: Vector2, value: int, velocity: Vector2, was_critical: bool = false, is_healing: bool = false, healing_color: Color = Color.WHITE, display_text := "") -> void:
	# Keep simultaneous progression feedback readable: level-up first, health
	# second, XP third. The offsets also make the priority visible in the world.
	var priority_offset := Vector2.ZERO
	if display_text.contains("lv!"):
		priority_offset = Vector2(0.0, -6.0)
	elif display_text.contains("xp"):
		priority_offset = Vector2(0.0, 6.0)
	elif is_healing:
		priority_offset = Vector2(0.0, 0.0)
	world_position += priority_offset
	effects_spawner.spawn_health_number(self, world_position, value, velocity, was_critical, is_healing, healing_color, Callable(self, "_pixel_text_texture"), Callable(self, "_snap_half_pixel"), effects_tuning.damage_number_lifetime, effects_tuning.damage_number_pop_time, display_text)
func _health_feedback_color(palette_name: String) -> Color:
	return PaletteLibrary.normal(palette_name)
func _configure_equipment_transmutations() -> void:
	if equipment_transmutation_component == null or player_equipment == null: return
	equipment_transmutation_component.configure(player_equipment)
	if player_guard_component != null:
		var snapshot := _player_stat_snapshot()
		var shield_maximum := PlayerGuardComponent.MAX_DURABILITY + player_equipment.guard_durability_bonus
		player_guard_component.set_maximum_durability(equipment_transmutation_component.guard_maximum_durability(shield_maximum, snapshot.def), true)
func _on_transmutation_effect_triggered(_effect_id: StringName, message: String) -> void:
	if _effect_id == &"duelist_focus":
		return
	if player == null or message.is_empty(): return
	var color := Color8(148, 220, 255)
	_spawn_floating_number(_actor_foot(player) + Vector2(0, -14), 0, Vector2(0, -10), false, false, color, message)
func _xp_required_for_level(level: int) -> int:
	return PlayerProfile.xp_required_for_level(level, progression_tuning)
func _xp_reward_for_slime(slime: Sprite2D) -> int:
	var stats := _slime_stats(slime)
	var enemy_level := maxi(stats.level if stats != null else 1, 1)
	var base_reward := 2.0 + 2.0 * pow(float(enemy_level), 0.85)
	var level_difference := enemy_level - (player_profile.level if player_profile != null else 1)
	var difficulty_modifier := pow(1.15, float(level_difference)) if level_difference >= 0 else pow(0.72, float(-level_difference))
	return maxi(1, roundi(base_reward * clampf(difficulty_modifier, 0.2, 2.0)))
func _award_slime_xp(slime: Sprite2D) -> void:
	var reward := _xp_reward_for_slime(slime)
	var progression := {"levels": 0}
	if player_profile != null:
		progression = ProgressionControllerScript.award_xp(player_profile, reward, progression_tuning)
		_apply_profile_to_runtime()
	var levels_gained := int(progression.get("levels", 0))
	if levels_gained > 0:
		_spawn_player_level_number(player_profile.level if player_profile != null else 1)
		_play_sound("level_up", -3.0, 1.0)
		_apply_player_level()
	_spawn_player_xp_number(reward)
	_update_player_progression_ui()
	_sync_runtime_progression_to_profile()
func _apply_player_level() -> void:
	player_stats.level = player_profile.level if player_profile != null else player_stats.level
	var new_max_health := _player_max_health()
	if player_health_component != null:
		# Preserve the player's health percentage when the maximum increases.
		player_health_component.set_maximum_health(new_max_health, true)
		player_display_health = player_health_component.current_health
	_update_player_health_ui()
func _update_player_progression_ui() -> void:
	if not is_instance_valid(player_level_text) or not is_instance_valid(player_xp_fill) or not is_instance_valid(player_xp_text):
		return
	var level := player_profile.level if player_profile != null else 1
	var xp := player_profile.xp if player_profile != null else 0
	var required := _xp_required_for_level(level)
	var hud_root := ui.get_node_or_null("PlayerHud") as Node2D
	if hud_root != null:
		hud_root.call("set_static_text", "lv. %d" % level, _health_feedback_color(screen_state_controller.player_palette_name))
	player_xp_text.texture = _pixel_text_texture("%d/%d" % [xp, required], Color.WHITE)
	var fill_size := player_xp_fill.texture.get_size() if player_xp_fill.texture != null else Vector2(48, 16)
	hud_controller.set_fill_ratio(player_xp_fill, fill_size, float(xp) / float(required))
func _spawn_player_xp_number(amount: int) -> void:
	var color := _health_feedback_color(screen_state_controller.player_palette_name)
	var text := "+%d xp" % maxi(amount, 0)
	_spawn_player_number(text, amount, color, true, text)
func _spawn_player_level_number(level: int) -> void:
	var text := "lv up!"
	_spawn_player_number(text, level, Color.WHITE, false, text)
func _update_damage_numbers(delta: float) -> void: effects_spawner.update_damage_numbers(delta, Callable(self, "_snap_half_pixel"), effects_tuning.damage_number_lifetime)
func _pixel_text_texture(text: String, color: Color) -> Texture2D: return effects_spawner.number_texture(text, color)
func _pixel_name_texture(text: String, color: Color) -> Texture2D: return effects_spawner.name_texture(text, color)
func _update_slime_scoot(slime: Sprite2D, delta: float) -> void:
	var brain := _slime_brain(slime)
	brain.set_aggro(_is_slime_aggroed(slime))
	if brain.is_noticing():
		var frames := _slime_shocked_frames(slime)
		if frames.is_empty():
			_set_actor_visual_scale(slime, brain.notice_wiggle_scale())
		else:
			var progress := 1.0 - clampf(brain.notice_timer / brain.notice_duration, 0.0, 1.0)
			_set_actor_visual_scale(slime, Vector2.ONE)
			_set_slime_notice_frame(slime, int(floor(progress * float(frames.size()))))
		return
	if brain.notice_started and not brain.notice_animation_finished:
		brain.notice_animation_finished = true
		_restore_slime_idle_texture(slime)
		_set_actor_visual_scale(slime, Vector2.ONE)
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		var slot_index := int(slime_frame_slots.get(slime, slimes.find(slime)))
		tactics.set_formation_slot(-1 if slot_index % 3 == 1 else 1 if slot_index % 3 == 2 else 0)
	brain.tick_scoot(slime, delta, slime_tuning, Callable(self, "_is_slime_aggroed"), Callable(self, "_try_move_actor"), Callable(self, "_set_actor_visual_scale"), Callable(self, "_repath_slime_after_block"), Callable(self, "_start_slime_hold"), Callable(self, "_start_slime_scoot"))
func _start_slime_scoot(slime: Sprite2D) -> void: _set_actor_visual_scale(slime, Vector2.ONE); _slime_brain(slime).start_scoot(slime, slime_tuning, rng, Callable(self, "_actor_foot"), Callable(self, "_aggro_slime_target"), Callable(self, "_random_slime_walkable_point_near"), Callable(self, "_perspective_movement"), Callable(self, "_set_slime_facing"))
func _repath_slime_after_block(slime: Sprite2D) -> void:
	if _is_slime_dead(slime): return
	var brain := _slime_brain(slime); brain.scoot_timer = 0.0; brain.scoot_start = slime.position; brain.scoot_target = slime.position; brain.repath_timer = 0.0
	if brain.blocked_repath_cooldown > 0.0: brain.hold_timer = maxf(brain.hold_timer, brain.blocked_repath_cooldown); _set_actor_visual_scale(slime, Vector2.ONE); return
	brain.blocked_repath_cooldown = rng.randf_range(0.10, 0.18)
	if _is_slime_aggroed(slime):
		brain.detour_target = _slime_wall_detour_target(slime)
		brain.detour_timer = 0.42
		brain.target = brain.detour_target
		brain.hold_timer = 0.0
	else: brain.target = _random_slime_walkable_point_near(_actor_foot(slime), 8, slime); brain.hold_timer = rng.randf_range(0.08, 0.18)
	_set_actor_visual_scale(slime, Vector2.ONE)
func _slime_wall_detour_target(slime: Sprite2D) -> Vector2:
	var foot := _actor_foot(slime)
	var player_foot := _actor_foot(player)
	var toward_player := player_foot - foot
	if toward_player.length_squared() < 0.01: return _aggro_slime_target(slime)
	var side := toward_player.normalized().rotated(PI * 0.5)
	var best := Vector2.ZERO
	var best_score := INF
	for radius_value in [12.0, 18.0, 24.0]:
		for direction in [side, -side]:
			var candidate: Vector2 = foot + (direction as Vector2) * radius_value
			if not _is_slime_collision_rect_walkable_at(slime, candidate): continue
			var score := candidate.distance_to(player_foot) + rng.randf_range(0.0, 2.0)
			if score < best_score: best = candidate; best_score = score
	return best if best_score < INF else _aggro_slime_target(slime)
func _start_slime_hold(slime: Sprite2D) -> void: _slime_brain(slime).start_random_hold(slime_tuning, rng)
func _set_actor_visual_scale(actor: Sprite2D, visual_scale: Vector2) -> void:
	var encounter_scale := float(actor.get_meta("encounter_scale", 1.0)) if slimes.has(actor) else 1.0
	occlusion_renderer.actor_visual_scales[actor] = visual_scale * encounter_scale
	# Most slimes no longer pass through the expensive per-pixel occlusion update
	# every frame. Apply their lightweight transform here so movement/idle squish
	# remains visible whether or not they are the current target.
	_apply_actor_scale(actor, false)
func _try_move_actor(actor: Sprite2D, movement: Vector2) -> bool:
	var original := actor.position
	var moved := _try_move_actor_axes(actor, movement)
	if actor == player or not slimes.has(actor) or not _is_slime_aggroed(actor) or movement.length_squared() < 0.001:
		return moved
	var moved_distance := actor.position.distance_to(original)
	var movement_was_clipped := moved and moved_distance < movement.length() * 0.65
	if moved and not movement_was_clipped:
		return true
	var slide := movement.rotated(PI * 0.5) * 0.72
	if _try_move_actor_axes(actor, slide): return true
	if _try_move_actor_axes(actor, -slide): return true
	return false
func _try_move_actor_axes(actor: Sprite2D, movement: Vector2) -> bool:
	var original := actor.position
	actor.position.x += movement.x; if actor == player and _try_enter_any_active_socket(): return true
	if not _can_actor_stand_at_current_position(actor) or _collides_with_static(actor): actor.position.x = original.x
	else: _resolve_actor_contacts(actor, Vector2(movement.x, 0.0))
	actor.position.y += movement.y; if actor == player and _try_enter_any_active_socket(): return true
	if not _can_actor_stand_at_current_position(actor) or _collides_with_static(actor): actor.position.y = original.y
	else: _resolve_actor_contacts(actor, Vector2(0.0, movement.y))
	return actor.position.distance_squared_to(original) > 0.0001
func _resolve_actor_contacts(actor: Sprite2D, movement: Vector2) -> void:
	if actor_collision_system == null:
		return
	var valid_position := actor.position
	actor_collision_system.resolve_motion_contacts(actor, movement, collision_sprites, self)
	if not _can_actor_stand_at_current_position(actor) or _collides_with_static(actor):
		actor.position = valid_position
func _collides_with_static(actor: Sprite2D) -> bool:
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	for other in collision_sprites:
		if other == actor or (other != chest and other != firepit): continue
		if other == firepit and _collision_polygon_intersects_actor(actor, firepit): return true
		if other == chest and _collision_rect(actor).intersects(_collision_rect(other), false): return true
	return false
func _collision_polygon_intersects_actor(actor: Sprite2D, polygon_owner: Sprite2D) -> bool:
	var polygon := polygon_owner.get_node_or_null("CollisionPolygon") as Polygon2D
	if polygon == null or polygon.polygon.size() < 3: return false
	var rect := _collision_rect(actor)
	var rect_polygon := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var world_polygon := PackedVector2Array()
	for point in polygon.polygon: world_polygon.append(polygon.to_global(point))
	return not Geometry2D.intersect_polygons(rect_polygon, world_polygon).is_empty()
func _perspective_movement(movement: Vector2) -> Vector2: return Vector2(movement.x, movement.y * VERTICAL_MOVEMENT_SCALE)
func _collision_rect(actor: Sprite2D) -> Rect2:
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	return ActorGeometry.collision_rect(actor, chest, firepit, slimes, ACTOR_FOOT_OFFSET, Vector2(ACTOR_COLLISION_WIDTH, ACTOR_COLLISION_HEIGHT), CHEST_COLLISION_SIZE, _slime_encounter_scale(actor))
func _collision_guide_rect(actor: Sprite2D) -> Rect2: return ActorGeometry.guide_rect(actor, "CollisionGuide")
func _collision_guide_rect_by_name(actor: Sprite2D, guide_name: String) -> Rect2: return ActorGeometry.guide_rect(actor, guide_name)
func _build_depth_lists() -> void:
	var lists := depth_sorter.visible_lists(player, slimes, chest, rest_fire, cloaked_demon, Callable(self, "_is_slime_dead"))
	depth_sprites = lists["depth"] as Array[Sprite2D]; occluder_sprites = lists["occluders"] as Array[Sprite2D]
	for torch in puzzle_torches:
		if is_instance_valid(torch) and torch.visible and not depth_sprites.has(torch):
			depth_sprites.append(torch)
	if cloaked_demon.visible: occlusion_renderer.sprite_images[cloaked_demon] = occlusion_renderer.cached_texture_image(cloaked_demon.texture)
	if rest_fire.visible: occlusion_renderer.sprite_images[rest_fire] = occlusion_renderer.cached_texture_image(rest_fire.texture)
	if chest.visible: for path in OCCLUDER_PATHS: _collect_occluders(get_node_or_null(path))
	_update_depth_sorting()
func _hide_editor_only_guides() -> void:
	room_controller.hide_editor_only_guides(floor_tiles)
	var firepit_polygon := rest_fire.get_node_or_null("Firepit/CollisionPolygon") as Polygon2D if rest_fire != null else null
	if firepit_polygon != null:
		firepit_polygon.visible = false
	for slime in slimes:
		var collision_polygon := slime.get_node_or_null("CollisionPolygon") as Polygon2D
		if collision_polygon != null:
			collision_polygon.visible = false
		var body_hitbox := slime.get_node_or_null("BodyHitbox") as Polygon2D
		if body_hitbox != null:
			body_hitbox.visible = false
func _build_slime_direction_textures() -> void:
	var paths := {}
	for slime in slimes:
		var palette := String(slime.get("variant"))
		var source := "SlimeGreen" if palette == "purple" else "Slime%s" % palette.capitalize()
		paths[slime] = ["res://assets/artwork/%sLeft.png" % source, "res://assets/artwork/%sRight.png" % source]
	SlimeVisualComponent.build_direction_textures(slimes, paths, Callable(self, "_load_texture_or_null"))
	var purple_slimes: Array[Sprite2D] = []
	for slime in slimes:
		if String(slime.get("variant")) == "purple":
			purple_slimes.append(slime)
	if not purple_slimes.is_empty():
		SlimeVisualComponent.recolor_direction_textures(purple_slimes, "purple", occlusion_renderer.texture_image_cache)
func _build_slime_attack_frames() -> void: slime_attack_frames_by_palette = SlimeVisualComponent.build_attack_frame_library(sprite_frame_library, SLIME_ATTACK_FRAME_SIZE, occlusion_renderer.texture_image_cache, Callable(player_animation_component, "warm_texture_cache")); SlimeVisualComponent.assign_attack_frames(slimes, slime_attack_frames_by_palette)
func _assign_slime_attack_frames() -> void: SlimeVisualComponent.assign_attack_frames(slimes, slime_attack_frames_by_palette)
func _build_slime_shocked_frames() -> void: slime_shocked_frames_by_palette = SlimeVisualComponent.build_shocked_frame_library(sprite_frame_library, SLIME_ATTACK_FRAME_SIZE, occlusion_renderer.texture_image_cache, Callable(player_animation_component, "warm_texture_cache")); SlimeVisualComponent.assign_shocked_frames(slimes, slime_shocked_frames_by_palette)
func _assign_slime_shocked_frames() -> void: SlimeVisualComponent.assign_shocked_frames(slimes, slime_shocked_frames_by_palette)
func _build_enemy_health_ui() -> void:
	player_animation_component.base_health_fill_texture = hud_controller.build_enemy_health_ui(slimes, target_health_fill, target_health_bar, player_health_fill, player_health_damage_fill, hp_overhead, hp_overhead_fill, slime_green, Callable(self, "_load_health_bar_texture"), Callable(hud_controller, "brighter_bar_texture"), Callable(hud_controller, "duplicate_fill_sprite"), Callable(hud_controller, "register_overhead_bar"), Callable(self, "_pixel_particle_texture"))
	target_health_damage_fill = target_health_fill.get_parent().get_node_or_null("EnemyHpDamageFill") as Sprite2D; player_health_damage_fill = player_health_fill.get_parent().get_node_or_null("HpBarDamageFill") as Sprite2D
	var player_hud := ui.get_node_or_null("PlayerHud") as Node2D
	if player_hud != null:
		player_animation_component.base_health_fill_texture = player_health_fill.texture
		if player_health_damage_fill != null:
			player_health_damage_fill.texture = player_hud.call("hp_highlight_texture") as Texture2D
func _refresh_enemy_palette_textures() -> void: hud_controller.refresh_enemy_palette_textures(slimes, Callable(self, "_load_health_bar_texture"), Callable(hud_controller, "brighter_bar_texture"))
func _load_texture_or_null(path: String) -> Texture2D: return load(path) as Texture2D if ResourceLoader.exists(path) else null
func _load_health_bar_texture(path: String) -> Texture2D:
	if health_bar_texture_cache.has(path): return health_bar_texture_cache[path] as Texture2D
	var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null; health_bar_texture_cache[path] = texture; return texture
func _build_rest_fire_frames() -> void: rest_fire_frames = sprite_frame_library.slice_frames("res://assets/artwork/Fire.png", FIRE_FRAME_SIZE); rest_fire_base_frames = rest_fire_frames; if not rest_fire_frames.is_empty(): _set_rest_fire_frame(0)
func _apply_rest_fire_palette(palette_name: String) -> void:
	if palette_name.is_empty() or rest_fire_base_frames.is_empty(): return
	if not rest_fire_frames_by_palette.has(palette_name): rest_fire_frames_by_palette[palette_name] = sprite_frame_library.recolor_fire_frames(rest_fire_base_frames, palette_name)
	rest_fire_frames = rest_fire_frames_by_palette[palette_name] as Array[Texture2D]; current_fire_palette_name = palette_name; _set_rest_fire_frame(0)
func _build_cloaked_demon_frames() -> void: var frames := npc_controller.build_cloaked_demon_frames(sprite_frame_library, cloaked_demon, CLOAKED_DEMON_FRAME_SIZE, Callable(occlusion_renderer, "cached_texture_image")); npc_controller.demon_idle_frames = frames["idle"]; npc_controller.demon_walk_frames = frames["walk"]; npc_controller.demon_visual_bounds = frames["bounds"]
func _cloaked_demon_head_position() -> Vector2: return _cloaked_demon_texture_origin() + Vector2(npc_controller.demon_visual_bounds.get_center().x, npc_controller.demon_visual_bounds.position.y)
func _cloaked_demon_visual_center() -> Vector2: return _cloaked_demon_texture_origin() + npc_controller.demon_visual_bounds.get_center()
func _cloaked_demon_foot_position() -> Vector2: return _cloaked_demon_texture_origin() + Vector2(npc_controller.demon_visual_bounds.get_center().x, npc_controller.demon_visual_bounds.end.y - 1.0)
func _configure_cloaked_demon_patrol_route() -> void:
	var route := npc_controller.configure_patrol_route(cloaked_demon, walkable_outline, Callable(self, "_cloaked_demon_foot_position"), Callable(self, "_is_walkable"))
	if route.is_empty(): return
	npc_controller.demon_patrol_min_x = route["min_x"]; npc_controller.demon_patrol_max_x = route["max_x"]; npc_controller.demon_wander_origin = route["origin"]; npc_controller.demon_patrol_position_x = route["position_x"]; npc_controller.demon_wander_target = route["target"]; npc_controller.demon_wander_has_target = route["has_target"]
func _random_npc_walkable_point_near(point: Vector2, radius: float) -> Vector2:
	var candidates: Array[Vector2] = []
	for index in 32: var angle := rng.randf_range(0.0, TAU); var distance := rng.randf_range(3.0, radius); var candidate := point + _perspective_movement(Vector2(cos(angle), sin(angle)) * distance); if _is_walkable(candidate): candidates.append(candidate)
	return point if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]
func _cloaked_demon_texture_origin() -> Vector2:
	return cloaked_demon.global_position + cloaked_demon.offset - cloaked_demon.texture.get_size() * 0.5 if cloaked_demon.centered and cloaked_demon.texture != null else cloaked_demon.global_position + cloaked_demon.offset
func _set_slime_facing(slime: Sprite2D, direction_x: float) -> void: SlimeVisualComponent.set_facing(self, slime, direction_x)
func _update_slime_attack_guides(slime: Sprite2D) -> void: var active_name := "AttackGuideL" if _slime_combat(slime).face_left else "AttackGuideR"; for child in slime.get_children(): if child is Node2D and child.name.begins_with("AttackGuide"): (child as Node2D).visible = child.name == active_name
func _set_actor_base_texture(actor: Sprite2D, texture: Texture2D) -> void: occlusion_renderer.set_actor_base_texture(actor, texture)
func _collect_occluders(node: Node) -> void:
	if node == null: return
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.visible: _add_depth_sprite(sprite); if not occluder_sprites.has(sprite): occluder_sprites.append(sprite)
	for child in node.get_children(): _collect_occluders(child)
func _add_depth_sprite(sprite: Sprite2D) -> void: if not depth_sprites.has(sprite): sprite.z_as_relative = false; depth_sprites.append(sprite)
func _update_depth_sorting() -> void: for sprite in depth_sprites: sprite.z_index = depth_sorter.z_index_for(sprite, _depth_key(sprite), DEPTH_Z_SCALE) if depth_sorter != null else int(round(_depth_key(sprite) * DEPTH_Z_SCALE))
func _update_actor_occlusion(delta: float) -> void:
	# Slimes are depth-sorted combat actors, not per-pixel occludable props.
	# Keep exact work to the player and target so targeting feedback remains intact.
	var occlusion_actors: Array[Sprite2D] = [player]
	if current_target != null and current_target != player and actor_sprites.has(current_target) and not _is_target_actor_dead(current_target):
		occlusion_actors.append(current_target)
	var target_focus_lost := current_target != null and not _combat_momentum().focus_active
	var release_grace := OCCLUSION_RELEASE_GRACE if current_target != null else 0.0
	occlusion_renderer.update_actor_occlusion(occlusion_actors, occluder_sprites, player, current_target, target_focus_lost, delta, release_grace, Callable(self, "_is_actor_occlusion_flashing"), Callable(self, "_depth_key"), Callable(self, "_sprite_source_global_rect"), Callable(self, "_build_exact_occluded_actor_texture"), Callable(self, "_apply_actor_scale"), Callable(self, "_restore_actor_base_visual_scale"))
	if player_equipment_visual_component != null:
		player_equipment_visual_component.update_occlusion(self, delta)
func _is_actor_occlusion_flashing(actor: Sprite2D) -> bool: return actor == player and player_hit_flash_timer > 0.0
func _update_player_shadow() -> void: shadow_controller.update_player_shadow(self, DEPTH_Z_SCALE)
func _update_cloaked_demon_shadow() -> void: shadow_controller.update_cloaked_demon_shadow(self, DEPTH_Z_SCALE)
func _build_sprite_shadow(actor: Sprite2D, shadow_ref: StringName, z_index_value: int) -> Sprite2D:
	var sprite_shadow := Sprite2D.new()
	sprite_shadow.name = shadow_ref
	sprite_shadow.centered = actor.centered
	sprite_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_shadow.self_modulate = Color(0.0, 0.0, 0.0, 0.25)
	sprite_shadow.z_as_relative = false
	sprite_shadow.z_index = z_index_value
	actor.get_parent().add_child(sprite_shadow)
	return sprite_shadow
func _build_player_sprite_shadow() -> void: player_sprite_shadow = _build_sprite_shadow(player, &"TinyDemonSpriteShadow", player.z_index - 1)
func _build_cloaked_demon_sprite_shadow() -> void: cloaked_demon_sprite_shadow = _build_sprite_shadow(cloaked_demon, &"CloakedDemonSpriteShadow", cloaked_demon.z_index - 1)
func _update_targeting() -> void: interaction_component.update_targeting(self)
func _movement_input() -> Vector2: return player_controller.movement_input(_controller_devices(), CONTROLLER_DEADZONE)
func _is_target_input_held() -> bool: return player_controller.target_held(_controller_devices(), CONTROLLER_TRIGGER_DEADZONE)
func _target_cycle_direction() -> int: return player_controller.target_cycle_direction(_controller_devices(), CONTROLLER_DEADZONE)
func _is_guard_input_held() -> bool: return player_controller.guard_held(_controller_devices(), CONTROLLER_TRIGGER_DEADZONE)
func _is_attack_input_pressed() -> bool: return player_controller.action_pressed(&"attack", _controller_devices(), JOY_BUTTON_X)
func _is_interact_input_pressed() -> bool: return player_controller.action_pressed(&"interact", _controller_devices(), JOY_BUTTON_B)
func _is_roll_input_pressed() -> bool: return player_controller.action_pressed(&"roll", _controller_devices(), JOY_BUTTON_A)
func _is_magic_input_pressed() -> bool: return player_controller.action_pressed(&"magic", _controller_devices(), JOY_BUTTON_Y)
func _controller_devices() -> Array[int]: return player_controller.connected_devices()
func _closest_target() -> Sprite2D:
	var candidates: Array[Sprite2D] = slimes.duplicate()
	candidates.append_array(puzzle_torches)
	return interaction_component.closest_target(player, candidates, TARGET_LOCK_MAX_DISTANCE, Callable(self, "_actor_foot"), Callable(self, "_is_target_actor_dead"), Callable(self, "_is_slime_targetable"))

func _cycle_target(direction: int) -> void:
	if direction == 0:
		return
	var candidates: Array[Sprite2D] = slimes.duplicate()
	candidates.append_array(puzzle_torches)
	var origin := current_target if current_target != null and _is_slime_targetable(current_target) else player
	var origin_position := _actor_foot(origin)
	var best: Sprite2D = null
	var best_score := INF
	for candidate in candidates:
		if candidate == null or candidate == current_target or not _is_slime_targetable(candidate):
			continue
		var offset := _actor_foot(candidate) - origin_position
		if origin != player and offset.x * float(direction) <= 0.5:
			continue
		var proximity_to_previous := offset.length()
		var distance_from_player := _actor_foot(candidate).distance_to(_actor_foot(player))
		var score := proximity_to_previous + distance_from_player * 0.25
		if score < best_score:
			best_score = score
			best = candidate
	if best == null:
		# Wrap around when there is no target on the requested side.
		for candidate in candidates:
			if candidate == null or candidate == current_target or not _is_slime_targetable(candidate):
				continue
			var candidate_position := _actor_foot(candidate)
			var wrap_score := candidate_position.x * -float(direction) + candidate_position.distance_to(_actor_foot(player)) * 0.01
			if best == null or wrap_score < best_score:
				best_score = wrap_score
				best = candidate
	if best != null:
		_set_current_target(best)
func _set_current_target(target: Sprite2D, play_feedback: bool = true) -> void:
	if current_target != target:
		if actor_sprites.has(current_target) and is_instance_valid(current_target):
			# The occlusion pass only visits the active target. Restore the previous
			# actor immediately so its highlight cannot persist after retargeting.
			occlusion_renderer.apply_unoccluded_actor_texture(current_target, false, false, 0.0, Callable(self, "_apply_actor_scale"), 0.0)
		if puzzle_torches.has(current_target):
			_set_puzzle_torch_target_highlight(current_target, false)
		if play_feedback and current_target != null and target == null:
			_play_sound("target_release", -8.0, 1.0)
		current_target = target
		if puzzle_torches.has(current_target):
			_set_puzzle_torch_target_highlight(current_target, true)
		focus_flash_timer = 0.0
		_combat_momentum().on_target_changed(target != null)
		_update_focus_indicator()

func _set_puzzle_torch_target_highlight(torch: Sprite2D, highlighted: bool) -> void:
	if torch == null or not is_instance_valid(torch):
		return
	var highlight := torch.get_node_or_null("TargetHighlight") as Sprite2D
	if highlighted and highlight == null:
		highlight = Sprite2D.new()
		highlight.name = "TargetHighlight"
		highlight.texture = _pixel_particle_texture(Color(1.0, 1.0, 1.0, 0.65), 10)
		highlight.centered = true
		highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		highlight.z_index = -1
		torch.add_child(highlight)
	if highlight != null:
		highlight.visible = highlighted
func _update_target_ui() -> void:
	if current_target == null: _set_target_ui_visible(false); return
	if puzzle_torches.has(current_target):
		_update_puzzle_torch_target_ui(current_target)
		return
	_set_target_ui_visible(true); target_health_bar_size = hud_controller.update_target_ui(current_target, target_name_text, target_health_bar, target_health_damage_fill, target_health_fill, target_health_text, target_health_bar_size, Callable(self, "_slime_display_name"), Callable(self, "_enemy_max_health"), Callable(self, "_slime_current_health"), Callable(self, "_slime_display_health"), Callable(self, "_pixel_name_texture"), Callable(self, "_pixel_text_texture"), Callable(hud_controller, "set_health_bar_values"))
func _update_puzzle_torch_target_ui(torch: Sprite2D) -> void:
	_set_target_ui_visible(true)
	target_name_text.texture = _pixel_name_texture("ENTRY ORB", Color.WHITE)
	target_name_text.centered = true
	target_name_text.position = Vector2(120, 148)
	target_health_text.visible = false
	var palette := String(torch.get_meta("puzzle_torch_palette", "grey"))
	var color := PaletteLibrary.normal(palette)
	if target_health_bar_size == Vector2.ZERO:
		target_health_bar_size = target_health_fill.texture.get_size() if target_health_fill.texture != null else Vector2(48, 16)
	target_health_fill.self_modulate = color
	if target_health_damage_fill != null:
		target_health_damage_fill.self_modulate = color
		hud_controller.set_fill_ratio(target_health_damage_fill, target_health_bar_size, 1.0)
	hud_controller.set_fill_ratio(target_health_fill, target_health_bar_size, 1.0)
func _set_target_ui_visible(target_visible: bool) -> void: hud_controller.set_visible(target_name_text, target_health_bar, target_health_damage_fill, target_health_fill, target_health_text, target_visible)
func _update_focus_indicator(delta: float = 0.0) -> void:
	if focus_label == null or focus_label_base == null:
		return
	if current_target == null:
		focus_label.visible = false
		focus_label_base.visible = false
		focus_flash_timer = 0.0
		return
	var momentum := _combat_momentum()
	if focus_flash_timer > 0.0:
		focus_flash_timer = maxf(focus_flash_timer - delta, 0.0)
	var active := momentum.focus_active and momentum.focus_timer > 0.0
	var name_half := (target_name_text.texture.get_size().x * 0.5) if target_name_text.texture != null else 0.0
	var top_left := target_name_text.position + Vector2(name_half + 12.0, -FOCUS_TEXT_HEIGHT * 0.5 - 1.0)
	focus_label.position = top_left
	focus_label_base.position = top_left
	focus_label.visible = true
	focus_label_base.visible = true
	focus_label_base.texture = _pixel_text_texture("FOCUS", Color8(150, 150, 150))
	var fill_ratio := 0.0
	var fill_color := _health_feedback_color(screen_state_controller.player_palette_name)
	if focus_flash_timer > 0.0:
		fill_ratio = 1.0
		fill_color = Color.WHITE
	elif active:
		fill_ratio = clampf(momentum.focus_timer / momentum.focus_window, 0.0, 1.0)
	focus_label.texture = _pixel_text_texture("FOCUS", fill_color)
	if fill_ratio >= 1.0:
		focus_label.region_enabled = false
	else:
		focus_label.region_enabled = true
		focus_label.region_rect = Rect2(Vector2.ZERO, Vector2(FOCUS_TEXT_WIDTH * fill_ratio, FOCUS_TEXT_HEIGHT))
func _slime_display_name(slime: Sprite2D) -> String:
	var palette := String(slime.get("variant")); var display_name := "Blue Slime" if palette == "blue" else "Red Slime" if palette == "red" else "Rogue Slime" if palette == "purple" else "Green Slime"; var stats := _slime_stats(slime); return "lv.%d %s" % [stats.level if stats != null else 1, display_name]
func _update_player_health_ui(delta: float = 0.0) -> void: var result: Dictionary = hud_controller.update_player_health_ui(player_health_component.current_health if player_health_component != null else 0.0, player_display_health, player_damage_fill_hold_timer, delta, slime_tuning.health_regen_fill_speed, slime_tuning.health_drain_fill_speed, _player_max_health(), player_health_fill, player_health_damage_fill, player_health_fill_size, player_health_text, Callable(self, "_pixel_text_texture"), Callable(hud_controller, "set_health_bar_values")); player_display_health = result["display_health"]; player_damage_fill_hold_timer = result["damage_hold"]
func _update_player_mp_ui(_delta: float = 0.0) -> void:
	# The visual state must update even while the MP HUD is not built or visible.
	# In particular, a spell can consume MP before the HUD is ready.
	_update_mp_desaturation()
	if player_mp_fill == null:
		return
	if player_mp_fill_size == Vector2.ZERO and player_mp_fill.texture != null:
		player_mp_fill_size = player_mp_fill.texture.get_size()
	if player_mp_fill_size == Vector2.ZERO:
		player_mp_fill_size = Vector2(48, 16)
	var current_chroma := _current_player_chroma()
	hud_controller.set_fill_ratio(player_mp_fill, player_mp_fill_size, clampf(current_chroma / PLAYER_MAX_MP, 0.0, 1.0))
	if player_mp_text != null:
		player_mp_text.texture = _pixel_text_texture("%d/%d" % [ceili(current_chroma), int(PLAYER_MAX_MP)], Color.WHITE)
func _current_player_chroma() -> float:
	return float(player_chroma_component.get("current_chroma")) if player_chroma_component != null and is_instance_valid(player_chroma_component) else 0.0
func _restore_player_mp() -> void:
	if player_chroma_component != null and is_instance_valid(player_chroma_component):
		player_chroma_component.call("attune", player_chroma_component.get("current_aspect"))
	_update_player_mp_ui()
func _try_cast_magic() -> bool:
	if player_is_attacking or player_is_rolling or player_is_defending or player_dead:
		return false
	if player_aspect_ability_component != null and player_chroma_component != null:
		var accepted := bool(player_aspect_ability_component.call("try_activate", player_chroma_component, Callable(self, "_execute_current_aspect_ability")))
		if accepted:
			_sync_chroma_presentation()
			_update_player_mp_ui()
		return accepted
	return false

func _sync_chroma_presentation() -> void:
	if player_chroma_component == null:
		return
	var flame := String(player_chroma_component.call("aspect_name"))
	var palette := "grey" if flame == "gray" else AspectCatalogScript.palette_for_flame(StringName(flame))
	if palette.is_empty() or palette == current_player_palette_name:
		return
	_start_player_palette_flash(palette)


func _execute_current_aspect_ability(_mode: int) -> bool:
	var target := current_target if current_target != null and _is_slime_targetable(current_target) else _closest_target()
	var direction := Vector2.RIGHT
	if target != null:
		var to_target := _magic_target_point(target) - _player_visual_center()
		direction = to_target.normalized() if to_target.length_squared() > 0.0001 else Vector2.RIGHT
	else:
		direction = last_player_input_direction.normalized()
	var origin := _player_visual_center() + Vector2(signf(direction.x) * 5.0, 1.0)
	if target != null:
		player.flip_h = direction.x < 0.0
	_spawn_magic_projectile(origin, direction, target)
	_play_sound("magic_cast", -8.0, 1.0)
	return true
func _player_visual_center() -> Vector2:
	return player.global_position + Vector2(8, 7)
func _slime_visual_center(slime: Sprite2D) -> Vector2:
	return slime.global_position + Vector2(8, 2)


func _magic_target_point(slime: Sprite2D) -> Vector2:
	# The floor CollisionGuide is for locomotion/contact, not combat aiming. Use
	# the authored damage body so homing projectiles target the visible boss body.
	if puzzle_torches.has(slime):
		return slime.global_position
	var body := _slime_body_polygon(slime)
	return ActorGeometry.polygon_center(body) if body.size() >= 3 else ActorGeometry.combat_target_point(_collision_rect(slime))
func _spawn_magic_projectile(origin: Vector2, direction: Vector2, homing_target: Sprite2D = null) -> void:
	var palette := current_player_palette_name
	var base_color := PaletteLibrary.normal(palette)
	var accent_color := PaletteLibrary.accent(palette)
	var projectile := Sprite2D.new()
	projectile.name = "MagicProjectile"
	projectile.texture = _pixel_particle_texture(base_color, MAGIC_PROJECTILE_SIZE)
	projectile.centered = true
	projectile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	projectile.z_as_relative = false
	projectile.z_index = player.z_index + 1
	projectile.position = origin
	add_child(projectile)
	var outline := Sprite2D.new()
	outline.name = "MagicProjectileOutline"
	outline.texture = _magic_projectile_outline_texture(base_color, accent_color)
	outline.centered = true
	outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	outline.z_as_relative = false
	outline.z_index = player.z_index + 1
	outline.position = origin
	add_child(outline)
	magic_projectile_controller.spawn(projectile, outline, direction, MAGIC_PROJECTILE_LIFETIME, palette, homing_target)
func _magic_projectile_outline_texture(base_color: Color, accent_color: Color) -> Texture2D:
	var key := "magic_outline:%s:%s" % [base_color.to_html(false), accent_color.to_html(false)]
	if effects_spawner.pixel_particle_texture_cache.has(key):
		return effects_spawner.pixel_particle_texture_cache[key]
	var size := MAGIC_PROJECTILE_SIZE + 2
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in size:
		for x in size:
			var on_border := x == 0 or y == 0 or x == size - 1 or y == size - 1
			if on_border:
				image.set_pixel(x, y, accent_color)
	var texture := ImageTexture.create_from_image(image)
	effects_spawner.pixel_particle_texture_cache[key] = texture
	return texture
func _update_magic_projectiles(delta: float) -> void:
	magic_projectile_controller.tick(delta, MAGIC_PROJECTILE_SPEED, Callable(self, "_snap_half_pixel"), Callable(self, "_magic_target_point"), Callable(self, "_is_slime_targetable"), Callable(self, "_magic_projectile_hit_target"), Callable(self, "_resolve_magic_projectile_hit"), Callable(self, "_spawn_magic_trail"))
func _resolve_magic_projectile_hit(target: Sprite2D, world_position: Vector2, palette: String) -> void:
	if puzzle_torches.has(target):
		_activate_puzzle_torch(target, world_position, palette)
	else:
		_magic_hit_slime(target, world_position, palette)
func _magic_projectile_hit_target(sprite: Sprite2D) -> Sprite2D:
	var radius := MAGIC_PROJECTILE_SIZE * 0.5 + 2.0
	for torch in puzzle_torches:
		if not _is_slime_targetable(torch):
			continue
		var torch_rect := Rect2(torch.global_position - Vector2(3.0, 3.0), Vector2(6.0, 6.0))
		if torch_rect.grow(radius).has_point(sprite.global_position):
			return torch
	for slime in slimes:
		if not _is_slime_targetable(slime):
			continue
		var body := _slime_body_polygon(slime)
		if _circle_intersects_polygon(sprite.global_position, radius, body):
			return slime
	return null
func _circle_intersects_polygon(center: Vector2, radius: float, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(center, polygon):
		return true
	for index in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(center, polygon[index], polygon[(index + 1) % polygon.size()])
		if center.distance_squared_to(closest) <= radius * radius:
			return true
	return false
func _magic_hit_slime(slime: Sprite2D, world_position: Vector2, palette: String) -> void:
	var base_damage := _player_attack_damage_against(slime)
	var damage := maxf(floorf(base_damage * 1.1), 1.0)
	_damage_slime_with_number(slime, damage, false, false)
	_knockback_slime(slime)
	_spawn_damage_number(slime, damage, false)
	_play_sound("magic_hit", -8.0, 1.0)
	_spawn_magic_impact(world_position, palette)
func _spawn_magic_trail(world_position: Vector2, palette: String) -> void:
	var particle := Sprite2D.new()
	particle.texture = _pixel_particle_texture(PaletteLibrary.normal(palette), 1) as Texture2D
	particle.centered = false
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = false
	particle.z_index = player.z_index + 1
	particle.position = world_position
	add_child(particle)
	var lifetime := 0.35
	effects_spawner.pixel_particles.append({"sprite": particle, "velocity": Vector2(0, 0), "timer": lifetime, "lifetime": lifetime, "gravity": 0.0})
func _spawn_magic_impact(world_position: Vector2, palette: String) -> void:
	var color := PaletteLibrary.normal(palette)
	for i in 8:
		var particle := Sprite2D.new()
		particle.texture = _pixel_particle_texture(color, 1) as Texture2D
		particle.centered = false
		particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		particle.z_as_relative = false
		particle.z_index = player.z_index + 1
		particle.position = world_position
		add_child(particle)
		var angle := float(i) / 8.0 * TAU
		var speed := float(rng.randf_range(14.0, 30.0))
		var lifetime := float(rng.randf_range(0.3, 0.5))
		effects_spawner.pixel_particles.append({"sprite": particle, "velocity": Vector2(cos(angle), sin(angle)) * speed, "timer": lifetime, "lifetime": lifetime, "gravity": 20.0})
func _update_overworld_ui() -> void: hud_controller.update_overworld(self, get_process_delta_time(), OVERWORLD_UI_Z)
func _slime_current_health(slime: Sprite2D) -> float: var max_health := _enemy_max_health(slime); var health_component := _slime_health(slime); return health_component.current_health if health_component != null else max_health
func _slime_display_health(slime: Sprite2D) -> float: return _slime_health_presenter(slime).display_health
func _depth_key(sprite: Sprite2D) -> float: return _actor_foot(sprite).y if actor_sprites.has(sprite) else rest_fire_depth_marker.global_position.y if sprite == rest_fire else _cloaked_demon_foot_position().y if sprite == cloaked_demon else sprite.global_position.y + 28.0 if sprite.name.begins_with("WallLeft") or sprite.name.begins_with("WallRight") else sprite.global_position.y + 30.0 if sprite.name.begins_with("Door") else sprite.global_position.y + float(sprite.texture.get_height() if sprite.texture != null else 0)
func _equipment_occlusion_depth_key(sprite: Sprite2D) -> float: return _actor_foot(player).y if String(sprite.name).begins_with("Equipment") else _depth_key(sprite)
func _sprite_source_global_rect(sprite: Sprite2D) -> Rect2:
	var texture: Texture2D = occlusion_renderer.original_actor_textures[sprite] if occlusion_renderer.original_actor_textures.has(sprite) else sprite.texture
	if texture == null: return Rect2(sprite.global_position, Vector2.ZERO)
	var sprite_scale := sprite.scale.abs(); if occlusion_renderer.original_actor_scales.has(sprite): sprite_scale = _actor_screen_scale(sprite).abs()
	var size: Vector2 = texture.get_size() * sprite_scale; var source_offset := _actor_visual_offset(sprite) if occlusion_renderer.original_actor_scales.has(sprite) else sprite.offset; var origin := sprite.global_position + source_offset * sprite_scale - size * 0.5 if sprite.centered else sprite.global_position + source_offset * sprite_scale; return Rect2(origin, size)
func _build_exact_occluded_actor_texture(actor: Sprite2D, active_occluders: Array[Sprite2D], is_target: bool, use_grey_highlight: bool) -> Texture2D: return occlusion_renderer.build_exact_occluded_actor_texture(actor, active_occluders, is_target, use_grey_highlight, Callable(self, "_is_pixel_covered_by_occluder"), Callable(self, "_actor_visual_offset"))
func _is_pixel_covered_by_occluder(world_pixel: Vector2, active_occluders: Array[Sprite2D]) -> bool: return occlusion_renderer.is_pixel_covered_by_occluder(world_pixel, active_occluders, Callable(self, "_actor_screen_scale"), Callable(self, "_actor_visual_offset"))
func _apply_actor_scale(actor: Sprite2D, _use_effect_texture: bool) -> void:
	actor.scale = _actor_screen_scale(actor)
	actor.offset = _actor_visual_offset(actor)
	_sync_actor_geometry_offset(actor)
func _restore_actor_base_visual_scale(actor: Sprite2D) -> void: if occlusion_renderer.original_actor_scales.has(actor): actor.scale = _actor_screen_scale(actor); actor.offset = _actor_visual_offset(actor)
func _actor_screen_scale(actor: Sprite2D) -> Vector2:
	var original_scale: Vector2 = occlusion_renderer.original_actor_scales.get(actor, Vector2.ONE)
	var visual_scale: Vector2 = occlusion_renderer.actor_visual_scales.get(actor, Vector2.ONE)
	return original_scale * visual_scale
func _slime_encounter_scale(slime: Sprite2D) -> float: return float(slime.get_meta("encounter_scale", 1.0))
func _actor_visual_offset(actor: Sprite2D) -> Vector2:
	return ActorGeometry.visual_offset(actor, player, slimes, ACTOR_FOOT_OFFSET)
func _sync_actor_geometry_offset(actor: Sprite2D) -> void:
	if not slimes.has(actor):
		return
	for node_name in [&"CollisionGuide", &"CollisionPolygon", &"BodyHitbox", &"AttackGuideL", &"AttackGuideR"]:
		var geometry := actor.get_node_or_null(NodePath(node_name)) as Node2D
		if geometry == null:
			continue
		if not geometry.has_meta("authored_position"):
			geometry.set_meta("authored_position", geometry.position)
		var authored_position := geometry.get_meta("authored_position") as Vector2
		geometry.position = authored_position + actor.offset
func _collect_walkable_tiles(node: Node) -> void: if walkable_area != null: walkable_area.collect_geometry(node, Callable(self, "_tile_top_polygon")); walkable_points = walkable_area.points.duplicate(); walkable_polygons = walkable_area.polygons.duplicate()
func _build_walkable_outline() -> void: if walkable_area != null: walkable_area.build_outline(use_walkable_polygon_direct); walkable_outline = walkable_area.outline
func _build_entrance_block_polygons() -> void: room_controller.build_entrance_blocks(self); if walkable_area != null: walkable_area.set_entrance_blocks(entrance_block_polygons)
func _is_walkable(point: Vector2) -> bool: return walkable_area == null or walkable_area.is_walkable(point)
func _can_actor_stand_at_current_position(actor: Sprite2D) -> bool: return actor_collision_system.can_actor_stand(actor, slimes, Callable(self, "_actor_foot"), Callable(self, "_is_walkable"), Callable(self, "_is_slime_walkable_point"), Callable(self, "_collision_rect"), Callable(self, "_slime_collision_polygon"))
func _is_slime_walkable_point(point: Vector2) -> bool: return walkable_area != null and walkable_area.is_slime_walkable(point)
func _tile_top_polygon(tile: Sprite2D) -> PackedVector2Array: return PackedVector2Array([tile.to_global(Vector2(8, 0)), tile.to_global(Vector2(16, 4)), tile.to_global(Vector2(8, 7)), tile.to_global(Vector2(0, 4))])
func _nearest_slime_walkable_point(point: Vector2) -> Vector2: return walkable_area.nearest_slime_walkable_point(point) if walkable_area != null and not walkable_area.is_empty() else point
func _random_slime_walkable_point_near(point: Vector2, sample_count: int, ignored_slime: Sprite2D = null) -> Vector2:
	if walkable_area == null: return point
	for attempt in 16:
		var candidate := walkable_area.random_slime_walkable_point_near(point, sample_count, ignored_slime, rng, Callable(self, "_is_point_near_other_slime"))
		if ignored_slime == null or _is_slime_collision_rect_walkable_at(ignored_slime, candidate): return candidate
	return _nearest_valid_slime_walkable_point(point, ignored_slime)


func _nearest_valid_slime_walkable_point(point: Vector2, slime: Sprite2D) -> Vector2:
	var nearest := walkable_area.nearest_slime_walkable_point(point)
	for radius_value in [0.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0]:
		var radius: float = radius_value
		for direction_index in 16:
			var candidate := nearest + Vector2.RIGHT.rotated(TAU * float(direction_index) / 16.0) * radius
			if _is_slime_collision_rect_walkable_at(slime, candidate): return candidate
	return point


func _is_slime_collision_rect_walkable_at(slime: Sprite2D, foot: Vector2) -> bool:
	var polygon := _slime_collision_polygon(slime, foot)
	if polygon.size() >= 3:
		return _is_slime_collision_polygon_walkable(polygon)
	var guide := slime.get_node_or_null("CollisionGuide") as Node2D
	var collision_rect := Rect2(foot - Vector2(4.5, 2.2), Vector2(9, 4))
	if guide != null:
		var guide_position: Vector2 = guide.get("rect_position"); var guide_size: Vector2 = guide.get("rect_size"); var actor_position := foot - ACTOR_FOOT_OFFSET; var origin := actor_position + guide.position + guide_position + Vector2(minf(guide_size.x, 0.0), minf(guide_size.y, 0.0)); collision_rect = Rect2(origin, guide_size.abs())
	var samples := [collision_rect.position, collision_rect.position + Vector2(collision_rect.size.x, 0), collision_rect.position + collision_rect.size, collision_rect.position + Vector2(0, collision_rect.size.y), collision_rect.get_center(), collision_rect.position + Vector2(collision_rect.size.x * 0.5, 0), collision_rect.position + Vector2(collision_rect.size.x, collision_rect.size.y * 0.5), collision_rect.position + Vector2(collision_rect.size.x * 0.5, collision_rect.size.y), collision_rect.position + Vector2(0, collision_rect.size.y * 0.5)]
	for sample in samples:
		if not _is_slime_walkable_point(sample): return false
	return true
func _slime_collision_polygon(slime: Sprite2D, foot: Vector2 = Vector2.INF) -> PackedVector2Array:
	return ActorGeometry.collision_polygon(slime, ACTOR_FOOT_OFFSET, foot)
func _slime_body_polygon(slime: Sprite2D) -> PackedVector2Array:
	return ActorGeometry.body_polygon(slime, ACTOR_FOOT_OFFSET)
func _is_slime_collision_polygon_walkable(polygon: PackedVector2Array) -> bool:
	var center := Vector2.ZERO
	for index in polygon.size():
		var point := polygon[index]
		var next_point := polygon[(index + 1) % polygon.size()]
		if not _is_slime_walkable_point(point) or not _is_slime_walkable_point((point + next_point) * 0.5): return false
		center += point
	return _is_slime_walkable_point(center / float(polygon.size()))
func _is_point_near_other_slime(point: Vector2, ignored_slime: Sprite2D = null) -> bool:
	for slime in slimes: if slime != ignored_slime and not _is_slime_dead(slime) and _collision_rect(slime).grow(4.0).has_point(point): return true
	return false
func _actor_foot(actor: Sprite2D) -> Vector2: return _cloaked_demon_foot_position() if actor == cloaked_demon else ActorGeometry.foot(actor, ACTOR_FOOT_OFFSET)
