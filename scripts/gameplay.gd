extends "res://scripts/gameplay_state.gd"
const RunGradeEvaluator = preload("res://scripts/run_grade.gd")
const ProgressionControllerScript = preload("res://scripts/progression_controller.gd")
func _add_runtime_node(script: Script, node_name: StringName, parent: Node = self) -> Node:
	var node := script.new() as Node; node.name = node_name; parent.add_child(node); return node
func _ready() -> void:
	var bootstrap := _add_runtime_node(GameplayBootstrap, "GameplayBootstrap") as GameplayBootstrap; bootstrap.initialize(self)
	if OS.has_feature("web"):
		var flush_callback := JavaScriptBridge.create_callback(_flush_save_from_js)
		JavaScriptBridge.eval("window.__tdFlushSave = %s" % flush_callback)
func _flush_save_from_js(_args: Array) -> void:
	if player_profile != null:
		ProfileSaveService.save_profile(player_profile)
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		# The browser flush-on-hide is a web durability feature; the JS
		# pagehide hook also calls the same save. Desktop tests and editor runs
		# must not mutate the persistent save just by losing window focus.
		if OS.has_feature("web") and player_profile != null:
			ProfileSaveService.save_profile(player_profile)
func _grant_chest_item_reward() -> bool:
	if player_profile == null or run_state == null:
		return false
	var reward_id := "drop-%s-%s" % [run_state.run_id, String(current_room_id)]
	if player_profile.find_item(reward_id) != null or player_profile.find_item("%s-0" % reward_id) != null:
		return true
	run_state.record_chest_open()
	var generation_seed := int(current_dungeon_seed) ^ String(current_room_id).hash()
	var reward_rng := RandomNumberGenerator.new()
	reward_rng.seed = generation_seed ^ 0x4C4F4F54
	if reward_rng.randf() >= _chest_item_drop_chance():
		return true
	var item_drops: Array[ItemInstance] = []
	var drop_count := _chest_item_drop_count(reward_rng.randf())
	var catalog := ItemCatalog.new()
	for index in drop_count:
		var item_seed := generation_seed ^ (0x13579BDF + index * 0x2468ACE)
		var slot := catalog.select_slot_for_source(player_profile, item_seed, player_profile.level, &"chest", _run_rank())
		var slot_was_empty := catalog.slot_needs_introduction(player_profile, slot)
		var rarity := _roll_run_loot_rarity(reward_rng.randf())
		var item := catalog.generate_item(slot, item_seed, player_profile.level, rarity, false, &"chest", _run_rank())
		if item.definition_id.is_empty():
			continue
		item.instance_id = "%s-%d" % [reward_id, index]
		item_drops.append(item)
		run_state.record_gear_reward(&"chest", item, _run_rank(), player_profile.level, -1, "", slot_was_empty, false, &"dropped")
	_spawn_chest_item_drops(item_drops)
	_play_sound("ui_use_item")
	return true
func _save_player_profile() -> void:
	if player_profile != null:
		ProfileSaveService.save_profile(player_profile)
func _on_player_walk_step(_step_frame: int) -> void:
	if not player_is_moving or player_is_rolling or player_is_attacking or player_is_defending:
		return
	_play_sound("foot_left" if _step_frame == 1 else "foot_right", -8.0, 1.0 + rng.randf_range(-0.025, 0.025))
func _fade_out_music(duration: float = 1.0) -> void:
	# Keep the desired track in sync with the fade. This prevents the music
	# state tick from immediately starting the run track again while the result
	# screen is being shown.
	music_track_wanted = &""
	music_wanted = false
	if sound_manager != null:
		sound_manager.fade_out_music(duration)
func _start_music() -> void:
	if sound_manager != null:
		sound_manager.start_title_music()
func _start_run_music() -> void:
	if sound_manager != null:
		sound_manager.start_run_music()
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
	var desired_track: StringName = &""
	if title_menu_frames >= 2:
		desired_track = &"title"
	# A run becomes active in the hub before the starter flame is collected.
	# Keep Dungeon-Crawl silent during that teaching beat; the flame interaction
	# flips this flag and the next music-state tick starts the run soundtrack.
	elif run_state != null and run_state.active and starter_flame_attuned_this_run:
		desired_track = &"run"
	if desired_track == music_track_wanted:
		return
	music_track_wanted = desired_track
	music_wanted = not desired_track.is_empty()
	if desired_track == &"title":
		_start_music()
	elif desired_track == &"run":
		_start_run_music()
	else:
		_fade_out_music()
func _physics_process(delta: float) -> void:
	if input_router != null:
		input_router.poll(_input_context())
		if input_device_tracker != null:
			input_device_tracker.call("observe_polled_input")
	gameplay_frame_controller.tick(self, delta)
	# Depth sorting runs inside the frame schedule for gameplay; the world is
	# frozen during dialogue/overlays, so the last sort still stands there.
	_update_player_shadow()
	_update_roll_dust(0.0)
	_update_large_room_camera()
func _update_game_over_input() -> void:
	if screen_state_controller != null:
		screen_state_controller.update_game_over_input(self)
func _return_to_title() -> void:
	_settle_current_run(&"return_to_title")
	if player_profile != null:
		player_profile.open_hub_on_load = false
		player_profile.pending_route = "title"
		_save_player_profile()
	_begin_scene_transition()
func _on_player_motor_motion(motion: Vector2) -> void: _try_move_actor(player, motion)
func _interrupt_player_attack() -> void:
	_cancel_magic_animation()
	player_is_attacking = false; if player_attack_component != null: player_attack_component.cancel()
	orb_knockback_animation_lock = false; orb_knockback_animation_grace = false; orb_knockback_attack_cancelled = false
	player_attack_hit_done = false; player_attack_visual.visible = false; player.visible = true; _restore_actor_base_visual_scale(player); player_anim_name = player_animation_component.movement_anim_name(self); player_anim_frame = 0; player_anim_timer = 0.0; player_animation_component.apply_frame(self)
	if player_equipment_visual_component != null: player_equipment_visual_component.interrupt_attack(self)
	_update_player_shadow()
func _player_facing_vector() -> Vector2:
	if player_is_attacking:
		return Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT
	return Vector2.LEFT if player.flip_h else Vector2.RIGHT
func _apply_player_attack_hitbox() -> void: if player_attack_component != null: player_attack_component.apply_hitbox(self)
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
func _cache_npc_texture(_actor: Sprite2D, texture: Texture2D) -> void: occlusion_renderer.sprite_images[cloaked_demon] = occlusion_renderer.cached_texture_image(texture)
func _can_interact_with_chest() -> bool:
	if chest == null or player == null or current_room_type != DungeonGraph.ROOM_TREASURE or not chest_unlocked or chest_claimed:
		return false
	var chest_rect := _collision_rect(chest)
	var player_foot := _actor_foot(player)
	var nearest_chest_point := Vector2(
		clampf(player_foot.x, chest_rect.position.x, chest_rect.end.x),
		clampf(player_foot.y, chest_rect.position.y, chest_rect.end.y)
	)
	return player_foot.distance_to(nearest_chest_point) <= CHEST_INTERACT_DISTANCE and _is_interaction_target_in_front(nearest_chest_point)
func _on_chest_collected() -> void:
	if current_room_type == DungeonGraph.ROOM_DOWNSTAIRS and _are_all_slimes_dead():
		_open_final_exit()
func _enter_final_settlement_room() -> void:
	if not final_exit_open or settlement_room_active:
		return
	final_exit_open = false
	settlement_room_active = true
	room_transition_locked = true
	player_is_attacking = false
	player_is_rolling = false
	player_is_backflipping = false
	player_is_defending = false
	player.global_position = Vector2(120, 80) + display_world_offset
	player.flip_h = false
	last_player_facing_left = false
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
func _update_player_palette_flash(delta: float) -> void:
	var overlay := player_palette_flash_overlay
	if overlay == null: return
	var timer := player_palette_flash_timer + delta
	ActorGeometry.sync_overlay(overlay, player); overlay.z_index = 2
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
func _snap_half_pixel(world_position: Vector2) -> Vector2: return Vector2(snappedf(world_position.x, 0.5), snappedf(world_position.y, 0.5))
func _slime_brain(slime: Sprite2D) -> SlimeBrain: return SlimeActor.component(slime, "Brain", SlimeBrain) as SlimeBrain
func _slime_combat(slime: Sprite2D) -> SlimeCombatComponent: return SlimeActor.component(slime, "Combat", SlimeCombatComponent) as SlimeCombatComponent
func _slime_stats(slime: Sprite2D) -> StatsComponent: return slime.get_node_or_null("Stats") as StatsComponent
func _slime_visual(slime: Sprite2D) -> SlimeVisualComponent: return SlimeActor.component(slime, "Visual", SlimeVisualComponent) as SlimeVisualComponent
func _slime_animation(slime: Sprite2D) -> SlimeAnimationComponent: return SlimeActor.component(slime, "Animation", SlimeAnimationComponent) as SlimeAnimationComponent
func _slime_health_presenter(slime: Sprite2D) -> SlimeHealthPresenter: return SlimeActor.component(slime, "HealthPresenter", SlimeHealthPresenter) as SlimeHealthPresenter
func _slime_health(slime: Sprite2D) -> HealthComponent: return slime.get_node_or_null("Health") as HealthComponent
func _load_health_bar_texture(path: String) -> Texture2D:
	if health_bar_texture_cache.has(path): return health_bar_texture_cache[path] as Texture2D
	var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null; health_bar_texture_cache[path] = texture; return texture
func _build_rest_fire_frames() -> void: rest_fire_frames = sprite_frame_library.slice_frames("res://assets/artwork/Fire.png", FIRE_FRAME_SIZE); rest_fire_base_frames = rest_fire_frames; if not rest_fire_frames.is_empty(): _set_rest_fire_frame(0)
func _apply_rest_fire_palette(palette_name: String) -> void:
	if palette_name.is_empty() or rest_fire_base_frames.is_empty(): return
	if not rest_fire_frames_by_palette.has(palette_name): rest_fire_frames_by_palette[palette_name] = sprite_frame_library.recolor_fire_frames(rest_fire_base_frames, palette_name)
	rest_fire_frames = rest_fire_frames_by_palette[palette_name] as Array[Texture2D]; current_fire_palette_name = palette_name; _set_rest_fire_frame(0)
func _random_npc_walkable_point_near(point: Vector2, radius: float) -> Vector2:
	var candidates: Array[Vector2] = []
	for index in 32: var angle := rng.randf_range(0.0, TAU); var distance := rng.randf_range(3.0, radius); var candidate := point + _perspective_movement(Vector2(cos(angle), sin(angle)) * distance); if _is_walkable(candidate): candidates.append(candidate)
	return point if candidates.is_empty() else candidates[rng.randi_range(0, candidates.size() - 1)]
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
func _slime_current_health(slime: Sprite2D) -> float: var max_health := _enemy_max_health(slime); var health_component := _slime_health(slime); return health_component.current_health if health_component != null else max_health
func _slime_display_health(slime: Sprite2D) -> float: return _slime_health_presenter(slime).display_health
func _slime_encounter_scale(slime: Sprite2D) -> float: return float(slime.get_meta("encounter_scale", 1.0))
