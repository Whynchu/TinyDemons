extends "res://scripts/gameplay_state.gd"
func _add_runtime_node(script: Script, node_name: StringName, parent: Node = self) -> Node:
	var node := script.new() as Node; node.name = node_name; parent.add_child(node); return node
func _ensure_player_component(script: Script, node_name: StringName) -> Node:
	var component := player.get_node_or_null(NodePath(node_name)) as Node
	if component == null: component = _add_runtime_node(script, node_name, player)
	return component
func _ready() -> void:
	var bootstrap := _add_runtime_node(GameplayBootstrap, "GameplayBootstrap") as GameplayBootstrap; bootstrap.initialize(self)
func _physics_process(delta: float) -> void: gameplay_frame_controller.tick(self, delta)
func _start_player_death() -> void:
	effects_spawner.begin_player_death(self, DEPTH_Z_SCALE)
	if player_equipment_visual_component != null: player_equipment_visual_component.begin_death(self)
func _update_player_death(delta: float) -> void: screen_state_controller.update_player_death(self, delta, GAME_OVER_FADE_TIME)
func _spawn_player_death_pixels() -> void: effects_spawner.spawn_player_death_particles(self, player_death_texture, player_death_origin, player_death_offset, player_death_scale, int(round(_depth_key(player) * DEPTH_Z_SCALE)) + 2, player_tuning.death_particle_lifetime, rng.randi(), Callable(self, "_pixel_particle_texture"))
func _build_game_over_ui() -> void: var controls := screen_state_controller.build_game_over(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_restart_game"), Callable(self, "_return_to_title")); game_over_overlay = controls["overlay"] as ColorRect; game_over_button = controls["restart"] as Button; game_over_title_button = controls["title"] as Button
func _show_game_over() -> void:
	if game_over_overlay == null or game_over_overlay.visible: return
	game_over_overlay.visible = true; screen_state_controller.set_state(&"game_over"); game_over_fade_timer = 0.0; game_over_overlay.modulate.a = 0.0; game_over_button.grab_focus()
func _build_title_screen() -> void: var controls := screen_state_controller.build_title(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_start_from_title")); title_overlay = controls["overlay"] as ColorRect; title_screen_text = controls["text"] as Sprite2D; title_start_button = controls["button"] as Button; title_start_text = controls["start_text"] as Sprite2D; _build_archetype_screen()
func _build_archetype_screen() -> void: var controls := screen_state_controller.build_archetype(ui, Callable(self, "_shift_archetype"), Callable(self, "_shift_archetype_color"), Callable(self, "_start_selected_archetype"), Callable(self, "_pixel_text_texture")); archetype_overlay = controls["overlay"] as ColorRect; archetype_preview = controls["preview"] as Sprite2D; archetype_name_text = controls["name"] as Sprite2D; archetype_left_buttons = controls["left"] as Array[Button]; archetype_right_buttons = controls["right"] as Array[Button]; archetype_type_left_button = controls["type_left"] as Button; archetype_type_right_button = controls["type_right"] as Button; archetype_start_button = controls["start"] as Button; archetype_hold_cover = controls["cover"] as ColorRect; _update_archetype_screen()
func _style_archetype_button(button: Button) -> void: screen_state_controller.style_archetype_button(button)
func _update_title_screen(delta: float) -> void: screen_state_controller.update_title_flow(self, delta)
func _start_from_title() -> void: screen_state_controller.start_from_title(self)
func _update_archetype_input(delta: float) -> void: screen_state_controller.update_archetype_input(self, delta)
func _shift_archetype(direction: int) -> void: archetype_index = posmod(archetype_index + direction, 4); selected_archetype = archetype_index as StatsComponent.AllocationProfile; _archetype_arrow_pulse(direction); _update_archetype_screen()
func _shift_archetype_color(direction: int) -> void: archetype_color_index = posmod(archetype_color_index + direction, 8); _archetype_arrow_pulse(direction); _update_archetype_screen()
func _archetype_arrow_pulse(direction: int) -> void: archetype_arrow_anim_direction = direction; archetype_arrow_anim_timer = 0.18
func _update_archetype_arrow_animation() -> void:
	var amount := clampf(archetype_arrow_anim_timer / 0.18, 0.0, 1.0); var pulse := 1.0 + amount * 0.22
	archetype_type_left_button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction < 0 and archetype_menu_row == 0 else 1.0); archetype_type_right_button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction > 0 and archetype_menu_row == 0 else 1.0)
	for button in archetype_left_buttons: button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction < 0 and archetype_menu_row == 1 else 1.0); for right_button in archetype_right_buttons: right_button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction > 0 and archetype_menu_row == 1 else 1.0)
func _select_archetype_menu_row(row: int) -> void: archetype_menu_row = posmod(row, 3); _update_archetype_screen(); if archetype_menu_row == 2: archetype_start_button.grab_focus()
func _update_archetype_screen() -> void:
	var names := ["BALANCED", "VIT", "STR", "DEF"]; var colors := ["blue", "orange", "green", "red", "yellow", "grey", "purple", "aquamarine"]
	var highlight_colors := [Color8(65, 166, 246), Color8(255, 205, 117), Color8(167, 240, 112), Color8(239, 125, 87), Color8(255, 240, 150), Color8(148, 176, 194), Color8(118, 78, 142), Color8(58, 138, 151)]
	archetype_name_text.texture = _pixel_text_texture(names[archetype_index], highlight_colors[archetype_color_index] if archetype_menu_row == 0 else Color.WHITE); archetype_name_text.position = Vector2((240.0 - archetype_name_text.texture.get_width()) * 0.5, 36)
	if not player_idle_frames.is_empty():
		if archetype_preview_palette != colors[archetype_color_index] or archetype_preview_frames.size() != player_idle_frames.size():
			archetype_preview_frames.clear(); archetype_preview_palette = colors[archetype_color_index]
			for frame in player_idle_frames: archetype_preview_frames.append(player_animation_component.recolor_texture(frame, archetype_preview_palette))
		_update_archetype_preview_animation()
	_update_archetype_button_styles()
func _update_archetype_preview_animation() -> void:
	if archetype_preview == null or archetype_preview_frames.is_empty(): return
	var frame_time := maxf(player_tuning.idle_frame_time, 0.01); var frame_index := posmod(int(archetype_frame_timer / frame_time), archetype_preview_frames.size())
	archetype_preview.texture = archetype_preview_frames[frame_index]; archetype_preview.position = Vector2((240.0 - archetype_preview.texture.get_width() * archetype_preview.scale.x) * 0.5, 48)
func _update_archetype_button_styles() -> void: screen_state_controller.update_archetype_button_styles(self)
func _start_selected_archetype() -> void: screen_state_controller.start_selected_archetype(self)
func _build_loading_screen() -> void: var controls := screen_state_controller.build_loading(ui, Callable(self, "_pixel_text_texture")); loading_screen_overlay = controls["overlay"] as ColorRect; loading_screen_text = controls["text"] as Sprite2D
func _update_loading_screen(delta: float) -> void: var result := screen_state_controller.update_loading(loading_screen_overlay, loading_screen_text, loading_screen_fading, loading_screen_timer, delta, Callable(self, "_pixel_text_texture")); loading_screen_fading = result["fading"]; loading_screen_timer = result["timer"]; if result["finished"]: loading_screen_active = false
func _apply_player_palette_async(palette_name: String) -> void:
	if player_animation_component != null: await player_animation_component.apply_palette_async(self, palette_name)
	if player_equipment_visual_component != null: player_equipment_visual_component.apply_palette(self)
	var player_hud := ui.get_node_or_null("PlayerHud") as Node2D
	if player_hud != null:
		player_hud.call("apply_bar_colors", _health_feedback_color(palette_name))
	_update_player_progression_ui()
func _update_player_aggro_marker_colors() -> void: hud_controller.update_aggro_markers(hud_controller.target_overhead_aggro_markers, player_palette_name, Callable(self, "_pixel_particle_texture"))
func _spawn_title_pixel_breakup(source_sprite: Sprite2D) -> void:
	if title_particle_layer == null:
		title_particle_layer = Node2D.new(); title_particle_layer.name = "TitleParticleLayer"; title_particle_layer.z_index = 10; ui.add_child(title_particle_layer)
	screen_state_controller.spawn_pixel_breakup(source_sprite, title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _spawn_title_button_frame_breakup() -> void: screen_state_controller.spawn_button_frame_breakup(title_start_button, title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _update_game_over_input() -> void:
	if game_over_overlay == null or not game_over_overlay.visible: return
	if Input.is_action_just_pressed("ui_accept") or _is_interact_input_pressed(): _restart_game()
func _restart_game() -> void: _begin_scene_transition()
func _return_to_title() -> void: _begin_scene_transition()
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
	player_attack_hit_done = false; player_attack_hit_targets.clear(); player_attack_visual.visible = false; player.visible = true; _restore_actor_base_visual_scale(player); player_anim_name = "walk" if player_is_moving else "idle"; player_anim_frame = 0; player_anim_timer = 0.0; player_animation_component.apply_frame(self)
func _player_facing_vector() -> Vector2: return Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT if player_is_attacking else Vector2.LEFT if player.flip_h else Vector2.RIGHT
func _apply_player_attack_hitbox() -> void: if player_attack_component != null: player_attack_component.apply_hitbox(self)
func _damage_slime(slime: Sprite2D, amount: float, was_critical: bool = false) -> void: SlimeActor.damage_actor(self, slime, amount, was_critical)
func _player_attack_damage_against(slime: Sprite2D) -> float: return _combat_damage(player_stats, _slime_stats(slime))
func _combat_damage(attacker_stats: StatsComponent, defender_stats: StatsComponent) -> float:
	var attacker_equipment_damage := player_equipment.damage_bonus if attacker_stats == player_stats and player_equipment != null else 0.0
	var defender_equipment_defense := player_equipment.defense_bonus if defender_stats == player_stats and player_equipment != null else 0.0
	var result := CombatCalculator.calculate_damage(attacker_stats, defender_stats, attacker_equipment_damage, defender_equipment_defense, attacker_stats == player_stats, rng, combat_tuning)
	last_damage_was_critical = result.critical; return result.amount
func _max_health_for_stats(stats: StatsComponent) -> float: return CombatCalculator.max_health_for_stats(stats, player_equipment.health_bonus if stats == player_stats and player_equipment != null else 0.0, combat_tuning)
func _player_max_health() -> float: return _max_health_for_stats(player_stats)
func _enemy_max_health(slime: Sprite2D) -> float: return _max_health_for_stats(_slime_stats(slime))
func _enemy_level_for_room() -> int: return maxi(1, ceili(float(current_room_depth) / 2.0))
func _apply_enemy_room_level(slime: Sprite2D, level_override: int = 0) -> void: var stats := _slime_stats(slime); if stats != null: stats.level = maxi(1, level_override if level_override > 0 else _enemy_level_for_room())
func _configure_slime_variant(slime: Sprite2D, variant: String) -> void:
	var palette := variant if variant == "blue" or variant == "green" or variant == "red" else "green"
	slime.set("variant", palette)
	var stats := _slime_stats(slime)
	if stats != null: stats.allocation_profile = StatsComponent.AllocationProfile.FAVOR_DEF if palette == "blue" else StatsComponent.AllocationProfile.FAVOR_STR if palette == "red" else StatsComponent.AllocationProfile.FAVOR_VIT
func _knockback_slime(slime: Sprite2D) -> void:
	if _is_slime_dead(slime): return
	var direction := _actor_foot(slime) - _actor_foot(player); if direction.length_squared() < 0.01: direction = Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT
	var combat := _slime_combat(slime); combat.knockback_velocity = _perspective_movement(direction.normalized() * (player_tuning.attack_knockback / slime_tuning.knockback_duration)); combat.knockback_timer = slime_tuning.knockback_duration
	var brain := _slime_brain(slime); brain.scoot_start = slime.position; brain.scoot_target = slime.position; brain.scoot_timer = 0.0; brain.hold_timer = slime_tuning.hitstun_time
func _kill_slime(slime: Sprite2D) -> void:
	if _is_slime_dead(slime): return
	_award_slime_xp(slime)
	effects_spawner.spawn_slime_death_from_root(self, slime); room_controller.kill_slime_without_effects(self, slime)
	if current_target == slime:
		if _is_target_input_held(): _set_current_target(_closest_target())
		else: _set_current_target(null); _set_target_ui_visible(false)
	if _are_all_slimes_dead(): _unlock_chest()
func _is_slime_dead(slime: Sprite2D) -> bool: return _slime_combat(slime).dead
func _are_all_slimes_dead() -> bool:
	for slime in slimes: if not _is_slime_dead(slime): return false
	return true
func _unlock_chest() -> void:
	if chest_unlocked: return
	chest_unlocked = true; if chest_normal_texture != null: chest_controller.start_unlock_fade(self)
func _build_interact_prompt() -> void:
	var interaction_marker := _load_texture_or_null("res://assets/artwork/circle55.png")
	interact_prompt = interaction_component.build_prompt(self, interaction_marker, OVERWORLD_UI_Z + 1); interact_prompt_base_position = Vector2(6, -7)
func _build_npc_dialogue() -> void: var dialogue := npc_controller.build_dialogue(self, _load_texture_or_null("res://assets/artwork/circle55.png")); npc_dialogue_layer = dialogue["layer"] as CanvasLayer; npc_dialogue_box = dialogue["box"] as ColorRect; npc_dialogue_text = dialogue["text"] as Sprite2D; npc_dialogue_button = dialogue["button"] as Sprite2D; npc_dialogue_button_shadow = dialogue["shadow"] as Sprite2D
func _build_room_number_indicator() -> void:
	var hud: Dictionary = hud_controller.build_world_hud(ui, sprite_frame_library, Callable(self, "_load_texture_or_null"), target_health_bar, target_health_fill, player_health_fill)
	room_number_indicator = hud["room"] as Sprite2D; gold_indicator = hud["gold"] as Sprite2D; gold_amount_indicator = hud["gold_amount"] as Sprite2D; gold_animation_frames = hud["gold_frames"] as Array[Texture2D]; button_hud_sprites = hud["buttons"] as Array[Sprite2D]; target_health_text = hud["target_text"] as Sprite2D; player_health_text = hud["player_text"] as Sprite2D; _update_room_number_indicator()
	var hud_root := ui.get_node("PlayerHud") as Node2D
	var player_hud_color := _health_feedback_color(player_palette_name)
	hud_root.call("set_static_text", "lv. 1", player_hud_color)
	hud_root.call("apply_bar_colors", player_hud_color)
	_update_player_progression_ui()
func _update_gold_indicator() -> void: if gold_indicator != null: gold_amount_indicator.texture = _pixel_number_texture(str(gold), Color8(255, 205, 117))
func _update_room_number_indicator() -> void: hud_controller.update_room_number(self)
func _set_entrance_open(is_open: bool) -> void:
	entrance_open = is_open; for socket_value in room_controller.active_entrance_sockets.values(): var visual := (socket_value as DungeonSocket).visual(); if visual != null: visual.visible = true
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
	var near_player := _can_interact_with_npc(); var patrolling := (current_room_type == DungeonGraph.ROOM_START or current_room_type == DungeonGraph.ROOM_NPC) and not near_player and (npc_dialogue_box == null or not npc_dialogue_box.visible)
	var result := npc_controller.update_patrol_animation(cloaked_demon, cloaked_demon_idle_frames, cloaked_demon_walk_frames, delta, near_player, patrolling, cloaked_demon_patrol_paused, cloaked_demon_wander_target, cloaked_demon_wander_has_target, cloaked_demon_patrol_pause_timer, cloaked_demon_patrol_direction, player.global_position.x, rng, Callable(self, "_cloaked_demon_foot_position"), Callable(self, "_random_npc_walkable_point_near"), Callable(self, "_move_cloaked_demon"), Callable(self, "_perspective_movement"), Callable(self, "_cache_npc_texture"), cloaked_demon_animation_timer, cloaked_demon_animation_frame)
	cloaked_demon_wander_target = result["wander_target"]; cloaked_demon_wander_has_target = result["has_target"]; cloaked_demon_patrol_paused = result["paused"]; cloaked_demon_patrol_pause_timer = result["pause_timer"]; cloaked_demon_patrol_direction = result["direction"]; cloaked_demon_animation_timer = result["timer"]; cloaked_demon_animation_frame = result["frame"]
func _move_cloaked_demon(movement: Vector2, max_step: float) -> bool: return actor_collision_system.try_move_swept(cloaked_demon, movement, max_step, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
func _cache_npc_texture(_actor: Sprite2D, texture: Texture2D) -> void: occlusion_renderer.sprite_images[cloaked_demon] = occlusion_renderer.cached_texture_image(texture)
func _can_interact_with_chest() -> bool: return chest_unlocked and not chest_claimed and _actor_foot(player).distance_to(_collision_rect(chest).get_center()) <= CHEST_INTERACT_DISTANCE
func _can_interact_with_npc() -> bool: return cloaked_demon != null and cloaked_demon.visible and _actor_foot(player).distance_to(_cloaked_demon_visual_center()) <= NPC_INTERACT_DISTANCE
func _update_interact_prompt(delta: float) -> void: interaction_component.update_world_prompt(self, delta, NPC_DIALOGUE_BUTTON_BOB_TIME, OVERWORLD_UI_Z + 1)
func _set_door_active(is_active: bool) -> void:
	door_active = is_active
	for socket_value in room_controller.active_door_sockets.values():
		var visual := (socket_value as DungeonSocket).visual(); if visual != null: visual.visible = is_active
func _collect_dungeon_sockets() -> void:
	room_controller.dungeon_sockets.clear()
	if sockets_root == null: return
	for child in sockets_root.get_children(): var socket := child as DungeonSocket; if socket != null: room_controller.dungeon_sockets[socket.socket_id()] = socket
func _sync_current_room_metadata() -> void:
	var room := dungeon_graph.get_room(current_room_id); if room != null: current_room_depth = room.depth; current_room_display_number = room.display_number; current_room_type = room.room_type
func _ensure_current_room_layout() -> void:
	var room := dungeon_graph.get_room(current_room_id)
	if room == null: return
	var state := room_controller.ensure_layout(dungeon_graph, current_room_id, room, current_room_type, current_room_depth); _configure_room_sockets(bool(state.get("finished", false)))
func _configure_room_sockets(is_unlocked: bool) -> void: room_controller.configure_sockets(dungeon_graph, current_room_id, is_unlocked, Callable(self, "_build_entrance_block_polygons")); door_active = is_unlocked; entrance_open = is_unlocked; _set_door_active(is_unlocked)
func _update_door_transition() -> void: if not room_transition_locked: room_controller.try_enter_active_socket(self, door_active, entrance_open, room_transition_locked)
func _try_enter_any_active_socket() -> bool: return room_controller.try_enter_active_socket(self, door_active, entrance_open, room_transition_locked)
func _enter_connected_room(destination_room_id: StringName, arrival_socket_id: StringName) -> void: room_controller.enter_connected_room(self, destination_room_id, arrival_socket_id)
func _release_room_transition_lock() -> void: room_transition_locked = false; if room_controller != null: room_controller.end_transition()
func _save_current_room_state() -> void:
	var state := room_controller.room_states.get(current_room_id, {}) as Dictionary; state["finished"] = chest_claimed; room_controller.room_states[current_room_id] = state; if room_controller != null and chest_claimed: room_controller.mark_cleared(current_room_id)
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
func _move_slimes(delta: float) -> void:
	for slime in slimes:
		if not _is_slime_dead(slime):
			_recover_slime_position(slime)
		var slime_actor := slime as SlimeActor
		if slime_actor != null:
			slime_actor.tick_components(delta); slime_actor.tick_runtime(delta, Callable(self, "_is_slime_dead"), Callable(self, "_update_slime_knockback"), Callable(self, "_update_slime_attack"), Callable(self, "_is_slime_aggroed"), Callable(self, "_aggro_slime_target"), Callable(self, "_update_slime_scoot")); continue
		SlimeActor.tick_legacy_runtime(slime, delta, Callable(self, "_is_slime_dead"), Callable(self, "_update_slime_knockback"), Callable(self, "_update_slime_attack"), Callable(self, "_is_slime_aggroed"), Callable(self, "_aggro_slime_target"), Callable(self, "_update_slime_scoot"))
	actor_collision_system.resolve_slime_contacts(slimes, self)
	for slime in slimes:
		if not _is_slime_dead(slime):
			_recover_slime_position(slime)
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
func _restore_slime_idle_texture(slime: Sprite2D) -> void: _set_slime_facing(slime, -1.0 if _slime_combat(slime).face_left else 1.0)
func _can_slime_attack_player(slime: Sprite2D) -> bool:
	var attack_distance := slime_tuning.attack_range + 5.0
	if player_dead or _actor_foot(player).distance_to(_actor_foot(slime)) > attack_distance:
		return false
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics == null:
		return true
	var own_combat := _slime_combat(slime)
	if tactics.attack_reserved and (own_combat == null or not own_combat.active):
		tactics.release_attack_slot()
	var active_attackers := 0
	for other in slimes:
		if _is_slime_dead(other):
			continue
		var combat := _slime_combat(other)
		if combat != null and combat.active:
			active_attackers += 1
	return tactics.request_attack_slot(active_attackers, MAX_ACTIVE_ENEMY_ATTACKERS)
func _is_slime_aggroed(slime: Sprite2D) -> bool:
	return not _is_slime_dead(slime) and not player_dead and (_slime_brain(slime).persistent_aggro or _actor_foot(slime).distance_to(_actor_foot(player)) <= slime_tuning.aggro_range)
func _is_any_slime_aggroed() -> bool:
	for slime in slimes: if _is_slime_aggroed(slime): return true
	return false
func _aggro_slime_target(slime: Sprite2D) -> Vector2:
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		var slot_index := slimes.find(slime)
		tactics.set_formation_slot(-1 if slot_index % 3 == 1 else 1 if slot_index % 3 == 2 else 0)
	return SlimeBrain.aggro_target(self, slime)
func _apply_slime_attack_hit(slime: Sprite2D) -> void: SlimeActor.apply_attack_hit(self, slime)
func _slime_attack_damage(slime: Sprite2D) -> float: return _combat_damage(_slime_stats(slime), player_stats)
func _mark_player_in_combat() -> void: if player_health_component != null: player_health_component.regen_delay_timer = player_tuning.regen_delay; player_health_component.regen_accumulator = 0.0
func _on_player_health_damaged(_amount: float) -> void: player_damage_fill_hold_timer = player_tuning.health_damage_hang_time
func _on_player_health_changed(current: float, _maximum: float) -> void: player_health = current; if is_instance_valid(player_health_fill): _update_player_health_ui()
func _on_player_health_healed(amount: float) -> void:
	player_display_health = minf(player_display_health, player_health_component.current_health if player_health_component != null else player_health)
	_spawn_player_healing_number(amount, Color8(177, 62, 83))
func _on_slime_health_damaged(_amount: float, slime: Sprite2D) -> void: _slime_health_presenter(slime).damage_fill_hold_timer = slime_tuning.health_damage_hang_time
func _on_slime_health_changed(_current: float, _maximum: float, slime: Sprite2D) -> void:
	if slime == current_target and is_instance_valid(target_health_fill): _update_target_ui()
func _on_slime_health_healed(amount: float, slime: Sprite2D) -> void:
	var health_component := _slime_health(slime); if health_component != null: _slime_health_presenter(slime).display_health = minf(_slime_health_presenter(slime).display_health, health_component.current_health)
	_spawn_slime_healing_number(slime, amount, _health_feedback_color(String(slime.get("variant"))))
func _update_player_health_regen(delta: float) -> void:
	if current_room_type != DungeonGraph.ROOM_START and current_room_type != DungeonGraph.ROOM_REST: return
	var max_health := _player_max_health(); if player_health >= max_health: return
	if _is_any_slime_aggroed(): _mark_player_in_combat(); return
	if player_health_component != null:
		player_health_component.regen_interval = player_tuning.regen_interval * 2.0
		player_health_component.regen_amount = maxf(1.0, roundf(max_health / 6.0))
		player_health_component.tick_regeneration(delta)
	_update_player_health_ui()
func _apply_slime_attack_lunge(slime: Sprite2D) -> void: var direction := _actor_foot(player) - _actor_foot(slime); direction = Vector2.LEFT if direction.length_squared() < 0.01 and _slime_combat(slime).face_left else Vector2.RIGHT if direction.length_squared() < 0.01 else direction.normalized(); direction = Vector2(direction.x, direction.y * 1.5).normalized(); actor_collision_system.try_move_swept(slime, _perspective_movement(direction * slime_tuning.attack_lunge_distance), 0.75, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
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
func _update_enemy_hit_flashes(delta: float) -> void:
	for slime in slimes: if not _is_slime_dead(slime): _slime_combat(slime).flash_timer = maxf(_slime_combat(slime).flash_timer - delta, 0.0)
func _update_enemy_health(delta: float) -> void:
	for slime in slimes: if not _is_slime_dead(slime): _slime_health_presenter(slime).update(delta, _slime_health(slime), _enemy_max_health(slime), slime_tuning)
func _spawn_damage_number(slime: Sprite2D, amount: float, was_critical: bool = false) -> void:
	_spawn_floating_number(slime.global_position + Vector2(5, -9), int(round(amount)), Vector2(0.0, -effects_tuning.damage_number_float_speed), was_critical)
func _spawn_player_damage_number(amount: float) -> void:
	var value := int(round(amount))
	_spawn_floating_number(_player_floating_number_origin(str(maxi(value, 0)), Color.WHITE), value, Vector2(0.0, effects_tuning.damage_number_float_speed))
func _spawn_player_shield_damage_number(amount: float) -> void:
	var value := int(round(amount))
	var color := Color8(148, 220, 255)
	var origin := _player_floating_number_origin(str(maxi(value, 0)), color) + Vector2(8, 0)
	_spawn_floating_number(origin, value, Vector2(0.0, effects_tuning.damage_number_float_speed), false, false, color, str(maxi(value, 0)))
func _spawn_player_healing_number(amount: float, color: Color) -> void:
	var value := int(round(amount))
	_spawn_floating_number(_player_floating_number_origin("+%d" % maxi(value, 0), color), value, Vector2(0.0, effects_tuning.damage_number_float_speed), false, true, color)
func _player_floating_number_origin(text: String, color: Color) -> Vector2:
	var number_texture := _pixel_number_texture(text, color) as Texture2D
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
	effects_spawner.spawn_health_number(self, world_position, value, velocity, was_critical, is_healing, healing_color, Callable(self, "_pixel_number_texture"), Callable(self, "_snap_half_pixel"), effects_tuning.damage_number_lifetime, effects_tuning.damage_number_pop_time, display_text)
func _health_feedback_color(palette_name: String) -> Color:
	var colors := {"blue": Color8(59, 93, 201), "orange": Color8(239, 125, 87), "green": Color8(56, 183, 100), "red": Color8(177, 62, 83), "yellow": Color8(255, 205, 117), "grey": Color8(86, 108, 134), "purple": Color8(118, 78, 142), "aquamarine": Color8(58, 138, 151)}
	return colors.get(palette_name, colors["blue"])
func _xp_required_for_level(level: int) -> int:
	# Per-level JRPG curve: early levels arrive steadily, while each later level
	# asks for meaningfully more fights without using enormous reward numbers.
	return maxi(1, roundi(20.0 + 12.0 * pow(float(maxi(level, 1)), 1.6)))
func _xp_reward_for_slime(slime: Sprite2D) -> int:
	var stats := _slime_stats(slime)
	var enemy_level := maxi(stats.level if stats != null else 1, 1)
	var base_reward := 2.0 + 2.0 * pow(float(enemy_level), 0.85)
	var level_difference := enemy_level - player_level
	var difficulty_modifier := pow(1.15, float(level_difference)) if level_difference >= 0 else pow(0.72, float(-level_difference))
	return maxi(1, roundi(base_reward * clampf(difficulty_modifier, 0.2, 2.0)))
func _award_slime_xp(slime: Sprite2D) -> void:
	var reward := _xp_reward_for_slime(slime)
	player_xp += reward
	var leveled_up := false
	while player_level < 99:
		var required := _xp_required_for_level(player_level)
		if player_xp < required:
			break
		player_xp -= required
		player_level += 1
		leveled_up = true
	if leveled_up:
		_spawn_player_level_number(player_level)
		_apply_player_level()
	_spawn_player_xp_number(reward)
	_update_player_progression_ui()
func _apply_player_level() -> void:
	player_stats.level = player_level
	var new_max_health := _player_max_health()
	if player_health_component != null:
		player_health_component.set_maximum_health(new_max_health, false)
		player_health_component.apply_healing(new_max_health - player_health_component.current_health)
		player_health = player_health_component.current_health
		player_display_health = player_health
	_update_player_health_ui()
func _update_player_progression_ui() -> void:
	if not is_instance_valid(player_level_text) or not is_instance_valid(player_xp_fill) or not is_instance_valid(player_xp_text):
		return
	var required := _xp_required_for_level(player_level)
	var hud_root := ui.get_node_or_null("PlayerHud") as Node2D
	if hud_root != null:
		hud_root.call("set_static_text", "lv. %d" % player_level, _health_feedback_color(player_palette_name))
	player_xp_text.texture = _pixel_number_texture("%d/%d" % [player_xp, required], Color.WHITE)
	var fill_size := player_xp_fill.texture.get_size() if player_xp_fill.texture != null else Vector2(48, 16)
	hud_controller.set_fill_ratio(player_xp_fill, fill_size, float(player_xp) / float(required))
func _spawn_player_xp_number(amount: int) -> void:
	var color := _health_feedback_color(player_palette_name)
	var text := "+%d xp" % maxi(amount, 0)
	_spawn_floating_number(_player_floating_number_origin(text, color), amount, Vector2(0.0, effects_tuning.damage_number_float_speed), false, true, color, text)
func _spawn_player_level_number(level: int) -> void:
	var text := "+%d lv!" % maxi(level, 1)
	_spawn_floating_number(_player_floating_number_origin(text, Color.WHITE), level, Vector2(0.0, effects_tuning.damage_number_float_speed), false, false, Color.WHITE, text)
func _update_damage_numbers(delta: float) -> void: effects_spawner.update_damage_numbers(delta, Callable(self, "_snap_half_pixel"), effects_tuning.damage_number_lifetime)
func _pixel_text_texture(text: String, color: Color) -> Texture2D: return effects_spawner.number_texture(text, color)
func _pixel_name_texture(text: String, color: Color) -> Texture2D: return effects_spawner.name_texture(text, color)
func _pixel_number_texture(text: String, color: Color) -> Texture2D: return effects_spawner.number_texture(text, color)
func _update_slime_scoot(slime: Sprite2D, delta: float) -> void:
	var brain := _slime_brain(slime)
	brain.set_aggro(_is_slime_aggroed(slime))
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		var slot_index := slimes.find(slime)
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
func _set_actor_visual_scale(actor: Sprite2D, visual_scale: Vector2) -> void: occlusion_renderer.actor_visual_scales[actor] = visual_scale
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
func _is_enemy_control_locked(actor: Sprite2D) -> bool: return _slime_combat(actor).hitstun_timer > 0.0 or _slime_combat(actor).knockback_timer > 0.0
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
	if actor == firepit:
		var polygon := actor.get_node_or_null("CollisionPolygon") as Polygon2D
		if polygon != null and polygon.polygon.size() >= 3:
			var bounds := Rect2(polygon.to_global(polygon.polygon[0]), Vector2.ZERO)
			for point in polygon.polygon:
				bounds = bounds.expand(polygon.to_global(point))
			return bounds
	var guide_rect := _collision_guide_rect(actor); var foot := _actor_foot(actor); var size := Vector2(ACTOR_COLLISION_WIDTH, ACTOR_COLLISION_HEIGHT); return guide_rect if guide_rect.has_area() else Rect2(actor.global_position + Vector2(8, 13) - CHEST_COLLISION_SIZE * 0.5, CHEST_COLLISION_SIZE) if actor == chest else Rect2(foot - Vector2(size.x * 0.5, size.y * 0.55), size)
func _collision_guide_rect(actor: Sprite2D) -> Rect2: return _collision_guide_rect_by_name(actor, "CollisionGuide")
func _collision_guide_rect_by_name(actor: Sprite2D, guide_name: String) -> Rect2:
	var guide := actor.get_node_or_null(guide_name) as Node2D
	if guide == null: return Rect2()
	var scaled_position: Vector2 = guide.get("rect_position"); var scaled_size: Vector2 = guide.get("rect_size"); var origin := actor.global_position + guide.position + scaled_position + Vector2(minf(scaled_size.x, 0.0), minf(scaled_size.y, 0.0)); return Rect2(origin, scaled_size.abs())
func _build_depth_lists() -> void:
	var lists := depth_sorter.visible_lists(player, slimes, chest, rest_fire, cloaked_demon, Callable(self, "_is_slime_dead"))
	depth_sprites = lists["depth"] as Array[Sprite2D]; occluder_sprites = lists["occluders"] as Array[Sprite2D]
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
func _build_slime_direction_textures() -> void:
	var paths := {}
	for slime in slimes:
		var palette := String(slime.get("variant")); paths[slime] = ["res://assets/artwork/Slime%sLeft.png" % palette.capitalize(), "res://assets/artwork/Slime%sRight.png" % palette.capitalize()]
	SlimeVisualComponent.build_direction_textures(slimes, paths, Callable(self, "_load_texture_or_null"))
func _build_slime_attack_frames() -> void: slime_attack_frames_by_palette = SlimeVisualComponent.build_attack_frame_library(sprite_frame_library, SLIME_ATTACK_FRAME_SIZE, occlusion_renderer.texture_image_cache, Callable(player_animation_component, "warm_texture_cache")); SlimeVisualComponent.assign_attack_frames(slimes, slime_attack_frames_by_palette)
func _assign_slime_attack_frames() -> void: SlimeVisualComponent.assign_attack_frames(slimes, slime_attack_frames_by_palette)
func _build_enemy_health_ui() -> void:
	player_base_health_fill_texture = hud_controller.build_enemy_health_ui(slimes, target_health_fill, target_health_bar, player_health_fill, player_health_damage_fill, hp_overhead, hp_overhead_fill, slime_green, Callable(self, "_load_health_bar_texture"), Callable(hud_controller, "brighter_bar_texture"), Callable(hud_controller, "duplicate_fill_sprite"), Callable(hud_controller, "register_overhead_bar"), Callable(self, "_pixel_particle_texture"))
	target_health_damage_fill = target_health_fill.get_parent().get_node_or_null("EnemyHpDamageFill") as Sprite2D; player_health_damage_fill = player_health_fill.get_parent().get_node_or_null("HpBarDamageFill") as Sprite2D
	var player_hud := ui.get_node_or_null("PlayerHud") as Node2D
	if player_hud != null:
		player_base_health_fill_texture = player_health_fill.texture
		if player_health_damage_fill != null:
			player_health_damage_fill.texture = player_hud.call("hp_highlight_texture") as Texture2D
func _refresh_enemy_palette_textures() -> void: hud_controller.refresh_enemy_palette_textures(slimes, Callable(self, "_load_health_bar_texture"), Callable(hud_controller, "brighter_bar_texture"))
func _load_texture_or_null(path: String) -> Texture2D: return load(path) as Texture2D if ResourceLoader.exists(path) else null
func _load_health_bar_texture(path: String) -> Texture2D:
	if health_bar_texture_cache.has(path): return health_bar_texture_cache[path] as Texture2D
	var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null; health_bar_texture_cache[path] = texture; return texture
func _build_rest_fire_frames() -> void: rest_fire_frames = sprite_frame_library.slice_frames("res://assets/artwork/Fire.png", FIRE_FRAME_SIZE); if not rest_fire_frames.is_empty(): _set_rest_fire_frame(0)
func _build_cloaked_demon_frames() -> void: var frames := npc_controller.build_cloaked_demon_frames(sprite_frame_library, cloaked_demon, CLOAKED_DEMON_FRAME_SIZE, Callable(occlusion_renderer, "cached_texture_image")); cloaked_demon_idle_frames = frames["idle"]; cloaked_demon_walk_frames = frames["walk"]; cloaked_demon_visual_bounds = frames["bounds"]
func _cloaked_demon_head_position() -> Vector2: return _cloaked_demon_texture_origin() + Vector2(cloaked_demon_visual_bounds.get_center().x, cloaked_demon_visual_bounds.position.y)
func _cloaked_demon_visual_center() -> Vector2: return _cloaked_demon_texture_origin() + cloaked_demon_visual_bounds.get_center()
func _cloaked_demon_foot_position() -> Vector2: return _cloaked_demon_texture_origin() + Vector2(cloaked_demon_visual_bounds.get_center().x, cloaked_demon_visual_bounds.end.y - 1.0)
func _configure_cloaked_demon_patrol_route() -> void:
	var route := npc_controller.configure_patrol_route(cloaked_demon, walkable_outline, Callable(self, "_cloaked_demon_foot_position"), Callable(self, "_is_walkable"))
	if route.is_empty(): return
	cloaked_demon_patrol_min_x = route["min_x"]; cloaked_demon_patrol_max_x = route["max_x"]; cloaked_demon_wander_origin = route["origin"]; cloaked_demon_patrol_position_x = route["position_x"]; cloaked_demon_wander_target = route["target"]; cloaked_demon_wander_has_target = route["has_target"]
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
	occlusion_renderer.update_actor_occlusion(actor_sprites, occluder_sprites, player, current_target, delta, OCCLUSION_RELEASE_GRACE, Callable(self, "_is_actor_occlusion_flashing"), Callable(self, "_depth_key"), Callable(self, "_sprite_source_global_rect"), Callable(self, "_build_exact_occluded_actor_texture"), Callable(self, "_apply_actor_scale"), Callable(self, "_restore_actor_base_visual_scale"))
	if player_equipment_visual_component != null:
		player_equipment_visual_component.update_occlusion(self, delta)
func _is_actor_occlusion_flashing(actor: Sprite2D) -> bool: return player_hit_flash_timer > 0.0 if actor == player else _slime_combat(actor).flash_timer > 0.0
func _update_player_shadow() -> void: shadow_controller.update_player_shadow(self, DEPTH_Z_SCALE)
func _update_cloaked_demon_shadow() -> void: shadow_controller.update_cloaked_demon_shadow(self, DEPTH_Z_SCALE)
func _build_player_sprite_shadow() -> void: player_sprite_shadow = Sprite2D.new(); player_sprite_shadow.name = "TinyDemonSpriteShadow"; player_sprite_shadow.centered = player.centered; player_sprite_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; player_sprite_shadow.self_modulate = Color(0.0, 0.0, 0.0, 0.25); player_sprite_shadow.z_as_relative = false; player_sprite_shadow.z_index = player.z_index - 1; player.get_parent().add_child(player_sprite_shadow)
func _build_cloaked_demon_sprite_shadow() -> void: cloaked_demon_sprite_shadow = Sprite2D.new(); cloaked_demon_sprite_shadow.name = "CloakedDemonSpriteShadow"; cloaked_demon_sprite_shadow.centered = cloaked_demon.centered; cloaked_demon_sprite_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; cloaked_demon_sprite_shadow.self_modulate = Color(0.0, 0.0, 0.0, 0.25); cloaked_demon_sprite_shadow.z_as_relative = false; cloaked_demon_sprite_shadow.z_index = cloaked_demon.z_index - 1; cloaked_demon.get_parent().add_child(cloaked_demon_sprite_shadow)
func _update_targeting() -> void: interaction_component.update_targeting(self)
func _movement_input() -> Vector2: return player_controller.movement_input(_controller_devices(), CONTROLLER_DEADZONE)
func _is_target_input_held() -> bool: return player_controller.target_held(_controller_devices(), CONTROLLER_TRIGGER_DEADZONE)
func _is_guard_input_held() -> bool: return player_controller.guard_held(_controller_devices(), CONTROLLER_TRIGGER_DEADZONE)
func _is_attack_input_pressed() -> bool: return player_controller.action_pressed([KEY_J, KEY_SPACE], _controller_devices(), JOY_BUTTON_X)
func _is_interact_input_pressed() -> bool: return player_controller.action_pressed([KEY_E, KEY_ENTER], _controller_devices(), JOY_BUTTON_B)
func _is_roll_input_pressed() -> bool: return player_controller.action_pressed([KEY_K], _controller_devices(), JOY_BUTTON_A)
func _controller_devices() -> Array[int]: return player_controller.connected_devices()
func _closest_target() -> Sprite2D: return interaction_component.closest_target(player, slimes, TARGET_LOCK_MAX_DISTANCE, Callable(self, "_actor_foot"), Callable(self, "_is_slime_dead"))
func _set_current_target(target: Sprite2D) -> void: if current_target != target: current_target = target; if hud_controller != null: hud_controller.set_target(target)
func _update_target_ui() -> void:
	if current_target == null: _set_target_ui_visible(false); return
	_set_target_ui_visible(true); target_health_bar_size = hud_controller.update_target_ui(current_target, target_name_text, target_health_bar, target_health_damage_fill, target_health_fill, target_health_text, target_health_bar_size, Callable(self, "_slime_display_name"), Callable(self, "_enemy_max_health"), Callable(self, "_slime_current_health"), Callable(self, "_slime_display_health"), Callable(self, "_pixel_name_texture"), Callable(self, "_pixel_number_texture"), Callable(hud_controller, "set_health_bar_values"))
func _set_target_ui_visible(target_visible: bool) -> void: hud_controller.set_visible(target_name_text, target_health_bar, target_health_damage_fill, target_health_fill, target_health_text, target_visible)
func _slime_display_name(slime: Sprite2D) -> String:
	var palette := String(slime.get("variant")); var display_name := "Blue Slime" if palette == "blue" else "Red Slime" if palette == "red" else "Green Slime"; var stats := _slime_stats(slime); return "lv.%d %s" % [stats.level if stats != null else 1, display_name]
func _update_player_health_ui(delta: float = 0.0) -> void: var result: Dictionary = hud_controller.update_player_health_ui(player_health, player_display_health, player_damage_fill_hold_timer, delta, slime_tuning.health_regen_fill_speed, slime_tuning.health_drain_fill_speed, _player_max_health(), player_health_fill, player_health_damage_fill, player_health_fill_size, player_health_text, Callable(self, "_pixel_number_texture"), Callable(hud_controller, "set_health_bar_values")); player_display_health = result["display_health"]; player_damage_fill_hold_timer = result["damage_hold"]
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
func _build_exact_occluded_actor_texture(actor: Sprite2D, active_occluders: Array[Sprite2D], include_outline: bool) -> Texture2D: return occlusion_renderer.build_exact_occluded_actor_texture(actor, active_occluders, include_outline, Callable(self, "_is_pixel_covered_by_occluder"), Callable(self, "_actor_visual_offset"))
func _is_pixel_covered_by_occluder(world_pixel: Vector2, active_occluders: Array[Sprite2D]) -> bool: return occlusion_renderer.is_pixel_covered_by_occluder(world_pixel, active_occluders, Callable(self, "_actor_screen_scale"), Callable(self, "_actor_visual_offset"))
func _apply_actor_scale(actor: Sprite2D, _use_effect_texture: bool) -> void: actor.scale = _actor_screen_scale(actor); actor.offset = _actor_visual_offset(actor)
func _restore_actor_base_visual_scale(actor: Sprite2D) -> void: if occlusion_renderer.original_actor_scales.has(actor): actor.scale = occlusion_renderer.original_actor_scales[actor] as Vector2; actor.offset = _actor_visual_offset(actor)
func _actor_screen_scale(actor: Sprite2D) -> Vector2:
	var original_scale: Vector2 = occlusion_renderer.original_actor_scales.get(actor, Vector2.ONE)
	var visual_scale: Vector2 = occlusion_renderer.actor_visual_scales.get(actor, Vector2.ONE)
	return original_scale * visual_scale
func _actor_visual_offset(actor: Sprite2D) -> Vector2: return PLAYER_TEXTURE_OFFSET if actor == player else Vector2.ZERO
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
	var guide := slime.get_node_or_null("CollisionPolygon") as Polygon2D
	if guide == null or guide.polygon.size() < 3:
		return PackedVector2Array()
	var offset := Vector2.ZERO if foot == Vector2.INF else foot - _actor_foot(slime)
	var polygon := PackedVector2Array()
	for point in guide.polygon:
		polygon.append(guide.to_global(point) + offset)
	return polygon
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
func _actor_foot(actor: Sprite2D) -> Vector2: return _cloaked_demon_foot_position() if actor == cloaked_demon else actor.global_position + ACTOR_FOOT_OFFSET
