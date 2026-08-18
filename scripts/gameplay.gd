extends "res://scripts/gameplay_state.gd"
const RunGradeEvaluator = preload("res://scripts/run_grade.gd")
func _add_runtime_node(script: Script, node_name: StringName, parent: Node = self) -> Node:
	var node := script.new() as Node; node.name = node_name; parent.add_child(node); return node
func _ensure_player_component(script: Script, node_name: StringName) -> Node:
	var component := player.get_node_or_null(NodePath(node_name)) as Node
	if component == null: component = _add_runtime_node(script, node_name, player)
	return component
func _ready() -> void:
	var bootstrap := _add_runtime_node(GameplayBootstrap, "GameplayBootstrap") as GameplayBootstrap; bootstrap.initialize(self)
func _apply_profile_to_runtime() -> void:
	if player_profile == null:
		return
	screen_state_controller.player_palette_name = player_profile.palette_name
	player_profile.ensure_starter_items()
	if player_equipment != null:
		player_equipment.configure_from_profile(player_profile)
	if player_stats == null:
		return
	player_stats.level = player_profile.level
	if player_profile.has_started:
		player_stats.configure_manual_growth(player_profile.base_vit, player_profile.base_str, player_profile.base_def, player_profile.base_spd, player_profile.allocated_vit, player_profile.allocated_str, player_profile.allocated_def, player_profile.allocated_spd)
	else:
		player_stats.manual_allocation_enabled = false
	_configure_equipment_transmutations()
	_recompute_player_speed_multiplier()

func _reapply_equipment_preserving_health() -> void:
	var old_max := _player_max_health() if player_stats != null and player_equipment != null else 1.0
	var current_health := player_health_component.current_health if player_health_component != null else 0.0
	var health_ratio := clampf(current_health / old_max, 0.0, 1.0) if old_max > 0.0 else 1.0
	player_equipment.configure_from_profile(player_profile)
	_configure_equipment_transmutations()
	var new_max := _player_max_health()
	if player_health_component != null:
		player_health_component.maximum_health = new_max
		player_health_component.reset(minf(new_max, maxf(1.0, new_max * health_ratio)))
	_save_player_profile()
	_update_player_health_ui()
	_recompute_player_speed_multiplier()

func _equip_profile_item(instance_id: String) -> bool:
	if player_profile == null or not player_profile.equip_item(instance_id):
		return false
	_reapply_equipment_preserving_health()
	_play_sound("ui_equip", 0.0, 1.0)
	return true

func _unequip_profile_slot(slot: StringName) -> bool:
	if player_profile == null or not player_profile.unequip_slot(slot):
		return false
	_reapply_equipment_preserving_health()
	_play_sound("ui_unequip", 0.0, 1.0)
	return true

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

func _placeholder_item_texture() -> Texture2D:
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)

func _spawn_chest_item_drop(item: ItemInstance) -> void:
	if world_item_drop != null and is_instance_valid(world_item_drop):
		world_item_drop.queue_free()
	if world_item_drop_label != null and is_instance_valid(world_item_drop_label):
		world_item_drop_label.queue_free()
	var catalog := ItemCatalog.new()
	var sprite := Sprite2D.new()
	sprite.name = "ChestItemDrop"
	sprite.texture = _placeholder_item_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = catalog.rarity_color(item.rarity)
	sprite.global_position = chest.global_position + Vector2(0, -4)
	sprite.z_as_relative = false
	sprite.z_index = chest.z_index + 3
	add_child(sprite)
	var label := Sprite2D.new()
	label.name = "ChestItemDropLabel"
	var item_name := str(ItemCatalog.DEFINITIONS.get(item.definition_id, {}).get("name", "ITEM"))
	label.texture = _pixel_text_texture("%s %s +%d" % [catalog.rarity_letter_grade(item.rarity), item_name, item.enhancement_level], catalog.rarity_color(item.rarity))
	label.centered = true
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.z_as_relative = false
	label.z_index = sprite.z_index + 1
	add_child(label)
	world_item_drop = sprite
	world_item_drop_label = label
	world_item_drop_instance = item
	var launch_rng := RandomNumberGenerator.new()
	launch_rng.seed = item.instance_id.hash()
	world_item_drop_velocity = Vector2(launch_rng.randf_range(-18.0, 18.0), -30.0)
	world_item_drop_air_time = 0.38
	_constrain_world_item_drop()

func _restore_chest_item_drop(item: ItemInstance, saved_position: Vector2) -> void:
	_spawn_chest_item_drop(item)
	world_item_drop.global_position = _nearest_slime_walkable_point(saved_position)
	world_item_drop_velocity = Vector2.ZERO
	world_item_drop_air_time = 0.0

func _constrain_world_item_drop() -> void:
	if world_item_drop == null or not is_instance_valid(world_item_drop):
		return
	world_item_drop.global_position = _nearest_slime_walkable_point(world_item_drop.global_position)

func _update_world_item_drop(delta: float) -> void:
	if world_item_drop == null or not is_instance_valid(world_item_drop):
		return
	if world_item_drop_air_time > 0.0:
		world_item_drop_air_time = maxf(world_item_drop_air_time - delta, 0.0)
		world_item_drop_velocity.y += 92.0 * delta
		world_item_drop.global_position += world_item_drop_velocity * delta
		_constrain_world_item_drop()
		if world_item_drop_air_time <= 0.0:
			world_item_drop_velocity = Vector2.ZERO
	var distance := _actor_foot(player).distance_to(world_item_drop.global_position)
	if distance < 10.0 and player_is_moving and world_item_drop_air_time <= 0.0:
		var push := world_item_drop.global_position - _actor_foot(player)
		if push.length_squared() < 0.01:
			push = _player_facing_vector()
		world_item_drop.global_position += push.normalized() * 18.0 * delta
		_constrain_world_item_drop()
	world_item_drop.z_index = int(round(world_item_drop.global_position.y * DEPTH_Z_SCALE)) + 2
	if world_item_drop_label != null and is_instance_valid(world_item_drop_label):
		world_item_drop_label.global_position = world_item_drop.global_position + Vector2(0, -10)
		world_item_drop_label.z_index = world_item_drop.z_index + 1

func _can_interact_with_world_item() -> bool:
	return world_item_drop != null and is_instance_valid(world_item_drop) and world_item_drop_air_time <= 0.0 and _actor_foot(player).distance_to(world_item_drop.global_position) <= CHEST_INTERACT_DISTANCE

func _collect_world_item_drop() -> bool:
	if not _can_interact_with_world_item() or world_item_drop_instance == null or player_profile == null:
		return false
	if not player_profile.grant_item(world_item_drop_instance):
		return false
	_save_player_profile()
	_spawn_floating_number(_actor_foot(player) + Vector2(0, -18), 0, Vector2(0, -12), false, false, Color("ffd866"), "FOUND %s" % ItemCatalog.new().display_name(world_item_drop_instance))
	world_item_drop.queue_free()
	if world_item_drop_label != null: world_item_drop_label.queue_free()
	world_item_drop = null
	world_item_drop_label = null
	world_item_drop_instance = null
	return true

func _loot_grade_bonus(grade: String = "") -> float:
	var value := grade.to_upper() if not grade.is_empty() else (player_profile.last_run_grade if player_profile != null else "D")
	return 3.0 if value == "S" else 2.0 if value == "A" else 1.0 if value == "B" else 0.5 if value == "C" else -0.5 if value == "F" else 0.0

func _chest_item_drop_chance() -> float:
	var exploration_bonus := minf(float(run_state.chests_opened) * 0.025, 0.20) if run_state != null else 0.0
	return clampf(0.34 + exploration_bonus + float(_run_rank() - 1) * 0.035 + _loot_grade_bonus() * 0.025, 0.30, 0.88)

func _chest_gold_reward(base_gold: int) -> int:
	var reward_rng := RandomNumberGenerator.new()
	reward_rng.seed = int(current_dungeon_seed) ^ String(current_room_id).hash() ^ 0x474F4C44
	var rolled_gold := reward_rng.randi_range(roundi(base_gold * 0.55), roundi(base_gold * 1.15))
	var multiplier := 1.0 + float(_run_rank() - 1) * 0.06 + _loot_grade_bonus() * 0.04
	return maxi(1, roundi(float(rolled_gold) * clampf(multiplier, 0.80, 1.90)))

func _save_player_profile() -> void:
	if player_profile != null:
		ProfileSaveService.save_profile(player_profile)
func _play_sound(sound_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if sound_manager != null:
		sound_manager.play(sound_name, volume_db, pitch_scale)
func _set_gold_value(value: int) -> void:
	if player_profile == null:
		return
	player_profile.gold = maxi(value, 0)
	_save_player_profile()
	_update_gold_indicator()
func _sync_runtime_progression_to_profile() -> void:
	if player_profile == null:
		return
	if player_stats != null and player_stats.manual_allocation_enabled:
		var allocation := player_stats.manual_allocation()
		player_profile.allocated_vit = int(allocation["VIT"])
		player_profile.allocated_str = int(allocation["STR"])
		player_profile.allocated_def = int(allocation["DEF"])
		player_profile.allocated_spd = int(allocation["SPD"])
	_save_player_profile()
func _respec_player_stats() -> int:
	if player_profile == null or not player_profile.has_started:
		return 0
	var refunded := player_profile.reset_allocated_stats()
	_apply_profile_to_runtime()
	_apply_player_level()
	_sync_runtime_progression_to_profile()
	return refunded
func _physics_process(delta: float) -> void:
	gameplay_frame_controller.tick(self, delta)
	_update_large_room_camera()
func _start_player_death() -> void:
	effects_spawner.begin_player_death(self, DEPTH_Z_SCALE)
	if player_equipment_visual_component != null: player_equipment_visual_component.begin_death(self)
func _update_player_death(delta: float) -> void: screen_state_controller.update_player_death(self, delta, GAME_OVER_FADE_TIME)
func _spawn_player_death_pixels() -> void: effects_spawner.spawn_player_death_particles(self, player_death_texture, player_death_origin, player_death_offset, player_death_scale, int(round(_depth_key(player) * DEPTH_Z_SCALE)) + 2, player_tuning.death_particle_lifetime, rng.randi(), Callable(self, "_pixel_particle_texture"))
func _build_game_over_ui() -> void: var controls := screen_state_controller.build_game_over(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_return_to_hub"), Callable(self, "_return_to_title")); game_over_overlay = controls["overlay"] as ColorRect; game_over_button = controls["restart"] as Button; game_over_title_button = controls["title"] as Button; screen_state_controller.game_over_cursor_text = controls["cursor"] as Sprite2D
func _build_run_complete_ui() -> void:
	var controls := screen_state_controller.build_run_complete(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_return_from_run_complete"))
	screen_state_controller.run_complete_overlay = controls["overlay"] as ColorRect
	screen_state_controller.run_complete_texts = controls["lines"] as Array[Sprite2D]
	screen_state_controller.run_complete_button = controls["return"] as Button
	screen_state_controller.run_complete_cursor = controls["cursor"] as Sprite2D
func _build_hub_ui() -> void:
	var controls := screen_state_controller.build_hub(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_hub_adjust_stat"), Callable(self, "_hub_confirm_stats"), Callable(self, "_hub_cancel_stats"), Callable(self, "_hub_auto_allocate"), Callable(self, "_hub_respec"), Callable(self, "_start_from_hub"), Callable(self, "_return_to_title"), Callable(self, "_set_hub_page"), Callable(self, "_hub_item_action"), Callable(self, "_select_hub_gear_slot"))
	screen_state_controller.hub_overlay = controls["overlay"] as ColorRect
	screen_state_controller.hub_summary_text = controls["summary"] as Sprite2D
	screen_state_controller.hub_points_text = controls["points"] as Sprite2D
	screen_state_controller.hub_stat_texts = controls["stats"] as Array[Sprite2D]
	screen_state_controller.hub_stat_buttons = controls["stat_buttons"] as Array[Button]
	screen_state_controller.hub_stat_left_buttons = controls["stat_left"] as Array[Button]
	screen_state_controller.hub_stat_right_buttons = controls["stat_right"] as Array[Button]
	screen_state_controller.hub_respec_button = controls["respec"] as Button
	screen_state_controller.hub_start_button = controls["start"] as Button
	screen_state_controller.hub_title_button = controls["title"] as Button
	screen_state_controller.hub_derived_texts = controls["derived"] as Array[Sprite2D]
	screen_state_controller.hub_apply_button = controls["apply"] as Button
	screen_state_controller.hub_cancel_button = controls["cancel"] as Button
	screen_state_controller.hub_auto_button = controls["auto"] as Button
	screen_state_controller.hub_page_buttons = controls["pages"] as Array[Button]
	screen_state_controller.hub_item_name_text = controls["item_name"] as Sprite2D
	screen_state_controller.hub_item_list_texts = controls["item_list"] as Array[Sprite2D]
	screen_state_controller.hub_shop_price_texts = controls["shop_prices"] as Array[Sprite2D]
	screen_state_controller.hub_gear_choice_texts = controls["gear_choices"] as Array[Sprite2D]
	screen_state_controller.hub_gear_slot_buttons = controls["gear_slot_buttons"] as Array[Button]
	screen_state_controller.hub_gear_stat_texts = controls["gear_stats"] as Array[Sprite2D]
	screen_state_controller.hub_gear_stat_panel = controls["gear_stat_panel"] as Panel
	screen_state_controller.hub_cursor_text = controls["cursor"] as Sprite2D
	screen_state_controller.hub_item_detail_texts = controls["item_details"] as Array[Sprite2D]
	screen_state_controller.hub_item_action_button = controls["item_action"] as Button
func _show_hub(from_npc: bool = false, pause_mode: bool = false) -> void:
	if screen_state_controller.hub_overlay == null: return
	screen_state_controller.hub_opened_from_npc = from_npc
	screen_state_controller.hub_pause_mode = pause_mode
	screen_state_controller.hub_interact_input_was_down = _is_interact_input_pressed()
	screen_state_controller.hub_cancel_input_was_down = _is_menu_cancel_input_pressed()
	screen_state_controller.hub_page_previous_input_was_down = _is_hub_previous_page_input_pressed()
	screen_state_controller.hub_page_next_input_was_down = _is_hub_next_page_input_pressed()
	if screen_state_controller.title_overlay != null: screen_state_controller.title_overlay.visible = false
	if screen_state_controller.archetype_overlay != null: screen_state_controller.archetype_overlay.visible = false
	if loading_screen_overlay != null: loading_screen_overlay.visible = false
	if game_over_overlay != null: game_over_overlay.visible = false
	screen_state_controller.hub_overlay.visible = true
	screen_state_controller.hub_page = 1 if pause_mode else 0
	screen_state_controller.hub_item_index = 0
	_hub_cancel_stats()
	_play_sound("ui_pause" if pause_mode else "ui_confirm", 0.0, 1.0)
	screen_state_controller.set_state(&"hub")
	_select_hub_menu_row(0)
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))

func _open_pause_menu() -> void:
	if player_dead or player_death_pending or screen_state_controller.hub_overlay == null or screen_state_controller.hub_overlay.visible:
		return
	screen_state_controller.pause_input_was_down = true
	_show_hub(false, true)
func _open_hub_from_cloaked_demon() -> void:
	if player_dead or screen_state_controller.hub_overlay == null: return
	if npc_controller.dialogue_box != null and npc_controller.dialogue_box.visible: npc_controller.hide_dialogue(self)
	player_is_moving = false
	player_is_attacking = false
	player_is_rolling = false
	player_attack_visual.visible = false
	interact_prompt.visible = false
	_show_hub(true)
func _close_hub_to_run() -> void:
	if screen_state_controller.hub_overlay == null: return
	var was_pause := screen_state_controller.hub_pause_mode
	_hub_cancel_stats()
	screen_state_controller.hub_gear_browsing = false
	screen_state_controller.menu_input_release_lock = _is_menu_cancel_input_pressed()
	screen_state_controller.hub_overlay.visible = false
	screen_state_controller.hub_opened_from_npc = false
	screen_state_controller.hub_pause_mode = false
	interact_input_was_down = _is_interact_input_pressed()
	screen_state_controller.set_state(&"gameplay")
	if was_pause:
		_play_sound("ui_unpause", 0.0, 1.0)
	else:
		_play_sound("ui_decline", 0.0, 1.0)
func _update_hub_input() -> void: screen_state_controller.update_hub_input(self)
func _is_hub_previous_page_input_pressed() -> bool: return player_controller.guard_held(_controller_devices(), 0.35)
func _is_hub_next_page_input_pressed() -> bool: return player_controller.target_held(_controller_devices(), 0.35)
func _is_menu_cancel_input_pressed() -> bool: return player_controller.action_pressed(&"cancel", _controller_devices(), JOY_BUTTON_A)
func _is_pause_input_just_pressed() -> bool:
	var is_down := Input.is_action_pressed(&"pause")
	var just_pressed := is_down and not screen_state_controller.pause_input_was_down
	screen_state_controller.pause_input_was_down = is_down
	return just_pressed
func _set_hub_page(page: int) -> void:
	screen_state_controller.hub_page = posmod(page, 4)
	screen_state_controller.hub_item_index = 0
	screen_state_controller.hub_gear_browsing = false
	screen_state_controller.hub_fusion_message = ""
	screen_state_controller.hub_fusion_count = 1
	if run_state != null and screen_state_controller.hub_page == 2:
		run_state.ensure_shop_stock(player_profile.level)
	if screen_state_controller.hub_page == 3:
		_refresh_hub_fusion_candidates()
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
	_play_sound("ui_hover", -6.0, 1.0)
func _shift_hub_item(direction: int) -> void:
	var count := 0
	if screen_state_controller.hub_page == 1:
		count = ItemCatalog.SLOTS.size()
	elif screen_state_controller.hub_page == 2:
		count = run_state.shop_stock.size() if run_state != null else 0
	elif screen_state_controller.hub_page == 3:
		_refresh_hub_fusion_candidates()
		count = screen_state_controller.hub_fusion_candidates.size()
		screen_state_controller.hub_fusion_count = 1
	if count > 0: screen_state_controller.hub_item_index = posmod(screen_state_controller.hub_item_index + direction, count)
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _hub_gear_candidates(slot: StringName) -> Array[ItemInstance]:
	var candidates: Array[ItemInstance] = []
	if player_profile == null: return candidates
	var catalog := ItemCatalog.new()
	if slot == &"shield":
		var unequip := ItemInstance.new()
		unequip.instance_id = ItemCatalog.UNEQUIP_SHIELD_ID
		candidates.append(unequip)
	for data: Dictionary in player_profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		if catalog.definition_slot(item.definition_id) == slot: candidates.append(item)
	return candidates
func _shift_hub_gear_candidate(direction: int) -> void:
	if screen_state_controller.hub_page != 1 or not screen_state_controller.hub_gear_browsing: return
	var slot := ItemCatalog.SLOTS[clampi(screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var candidates := _hub_gear_candidates(slot)
	if candidates.is_empty(): return
	var key := String(slot)
	screen_state_controller.hub_gear_candidate_indices[key] = posmod(int(screen_state_controller.hub_gear_candidate_indices.get(key, 0)) + direction, candidates.size())
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _select_hub_gear_slot(slot_index: int) -> void:
	if screen_state_controller.hub_page != 1: return
	screen_state_controller.hub_item_index = clampi(slot_index, 0, ItemCatalog.SLOTS.size() - 1)
	var slot := ItemCatalog.SLOTS[screen_state_controller.hub_item_index]
	var candidates := _hub_gear_candidates(slot)
	if not candidates.is_empty():
		var equipped_id := str(player_profile.equipped_instance_ids.get(String(slot), ""))
		for index in candidates.size():
			if candidates[index].instance_id == equipped_id:
				screen_state_controller.hub_gear_candidate_indices[String(slot)] = index
				break
		screen_state_controller.hub_gear_browsing = true
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _close_hub_gear_browse() -> void:
	screen_state_controller.hub_gear_browsing = false
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _refresh_hub_fusion_candidates() -> void:
	screen_state_controller.hub_fusion_candidates.clear()
	if player_profile == null: return
	var catalog := ItemCatalog.new()
	for data: Dictionary in player_profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		if player_profile.fusion_material_count(item.instance_id, catalog) > 0 or player_profile.can_salvage_overflow(item.instance_id, catalog):
			screen_state_controller.hub_fusion_candidates.append(item)
func _hub_fusion_candidates() -> Array[ItemInstance]:
	_refresh_hub_fusion_candidates()
	return screen_state_controller.hub_fusion_candidates
func _fuse_profile_target(instance_id: String, count: int) -> bool:
	if player_profile == null or count <= 0 or not player_profile.fuse_duplicates(instance_id, count, ItemCatalog.new()):
		return false
	player_equipment.configure_from_profile(player_profile)
	_configure_equipment_transmutations()
	_apply_player_level()
	_save_player_profile()
	_update_gold_indicator()
	return true
func _shift_hub_fusion_count(direction: int) -> void:
	if screen_state_controller.hub_page != 3: return
	_refresh_hub_fusion_candidates()
	if screen_state_controller.hub_fusion_candidates.is_empty(): return
	var index := clampi(screen_state_controller.hub_item_index, 0, screen_state_controller.hub_fusion_candidates.size() - 1)
	var target := screen_state_controller.hub_fusion_candidates[index]
	if player_profile.can_salvage_overflow(target.instance_id): return
	var material_count := player_profile.fusion_material_count(target.instance_id)
	if material_count <= 0: return
	screen_state_controller.hub_fusion_count = clampi(int(screen_state_controller.hub_fusion_count) + direction, 1, material_count)
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _salvage_profile_overflow(instance_id: String) -> int:
	if player_profile == null: return 0
	var value := player_profile.salvage_overflow(instance_id)
	if value <= 0: return 0
	_save_player_profile()
	_update_gold_indicator()
	return value
func _hub_item_action() -> void:
	if player_profile == null: return
	if screen_state_controller.hub_page == 1:
		var slot := ItemCatalog.SLOTS[clampi(screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var candidates := _hub_gear_candidates(slot)
		if not candidates.is_empty():
			var candidate_index := posmod(int(screen_state_controller.hub_gear_candidate_indices.get(String(slot), 0)), candidates.size())
			if not screen_state_controller.hub_gear_browsing:
				var equipped_id := str(player_profile.equipped_instance_ids.get(String(slot), ""))
				for index in candidates.size():
					if candidates[index].instance_id == equipped_id:
						screen_state_controller.hub_gear_candidate_indices[String(slot)] = index
						break
				screen_state_controller.hub_gear_browsing = true
			else:
				var selected := candidates[candidate_index]
				var equipped_id := str(player_profile.equipped_instance_ids.get(String(slot), ""))
				if selected.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID:
					_unequip_profile_slot(slot)
				elif slot == &"shield" and selected.instance_id == equipped_id:
					_unequip_profile_slot(slot)
				else:
					_equip_profile_item(selected.instance_id)
				screen_state_controller.hub_gear_browsing = false
			screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
		return
	elif screen_state_controller.hub_page == 2 and run_state != null and not run_state.shop_stock.is_empty():
		var index := clampi(screen_state_controller.hub_item_index, 0, run_state.shop_stock.size() - 1)
		var entry: Dictionary = run_state.shop_stock[index]
		if not bool(entry.get("sold", false)):
			var item := ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary)
			if player_profile.purchase_item(item, int(entry.get("price", 0))):
				entry["sold"] = true; run_state.shop_stock[index] = entry; _save_player_profile(); _update_gold_indicator(); _play_sound("ui_confirm", 0.0, 1.0); _play_sound("ui_buy_sell", -8.0, 1.0)
			else:
				_play_sound("ui_denied", 0.0, 1.0)
	elif screen_state_controller.hub_page == 3:
		_refresh_hub_fusion_candidates()
		if not screen_state_controller.hub_fusion_candidates.is_empty():
			var index := clampi(screen_state_controller.hub_item_index, 0, screen_state_controller.hub_fusion_candidates.size() - 1)
			var target := screen_state_controller.hub_fusion_candidates[index]
			if player_profile.fusion_material_count(target.instance_id) > 0:
				var material_count := player_profile.fusion_material_count(target.instance_id)
				var count := clampi(int(screen_state_controller.hub_fusion_count), 1, material_count)
				var batch_cost := player_profile.fusion_batch_cost(target, count)
				if player_profile.gold < batch_cost:
					screen_state_controller.hub_fusion_message = "NEED %dG" % batch_cost
					_play_sound("ui_denied", 0.0, 1.0)
				else:
					var family_name := str(ItemCatalog.DEFINITIONS.get(target.definition_id, {}).get("name", "ITEM"))
					if _fuse_profile_target(target.instance_id, count):
						screen_state_controller.hub_fusion_message = "%s ENHANCED" % family_name
						_play_sound("ui_confirm", 0.0, 1.0)
						_play_sound("ui_buy_sell", -8.0, 1.0)
			elif player_profile.can_salvage_overflow(target.instance_id):
				var salvage_value := _salvage_profile_overflow(target.instance_id)
				if salvage_value > 0:
					screen_state_controller.hub_fusion_message = "SALVAGED %dG" % salvage_value
					_play_sound("ui_buy_sell", -8.0, 1.0)
			if not screen_state_controller.hub_fusion_message.is_empty():
				_refresh_hub_fusion_candidates()
				screen_state_controller.hub_item_index = clampi(screen_state_controller.hub_item_index, 0, maxi(screen_state_controller.hub_fusion_candidates.size() - 1, 0))
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _select_hub_menu_row(row: int) -> void:
	screen_state_controller.hub_menu_row = posmod(row, 5)
	if screen_state_controller.hub_menu_row < 4: screen_state_controller.hub_action_column = 0
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _shift_hub_action_column(direction: int) -> void:
	var count := 4 if screen_state_controller.hub_menu_row == 4 else 2
	screen_state_controller.hub_action_column = posmod(screen_state_controller.hub_action_column + direction, count)
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _hub_adjust_stat(stat_name: StringName, direction: int) -> void:
	if direction > 0:
		_hub_allocate_stat(stat_name)
		return
	match stat_name:
		&"VIT": screen_state_controller.hub_pending_vit = maxi(screen_state_controller.hub_pending_vit - 1, 0)
		&"STR": screen_state_controller.hub_pending_str = maxi(screen_state_controller.hub_pending_str - 1, 0)
		&"DEF": screen_state_controller.hub_pending_def = maxi(screen_state_controller.hub_pending_def - 1, 0)
		&"SPD": screen_state_controller.hub_pending_spd = maxi(screen_state_controller.hub_pending_spd - 1, 0)
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _hub_allocate_stat(stat_name: StringName) -> void:
	if player_profile == null or _hub_points_remaining() <= 0: return
	match stat_name:
		&"VIT": screen_state_controller.hub_pending_vit += 1
		&"STR": screen_state_controller.hub_pending_str += 1
		&"DEF": screen_state_controller.hub_pending_def += 1
		&"SPD": screen_state_controller.hub_pending_spd += 1
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _hub_points_remaining() -> int: return maxi(player_profile.unspent_stat_points - screen_state_controller.hub_pending_vit - screen_state_controller.hub_pending_str - screen_state_controller.hub_pending_def - screen_state_controller.hub_pending_spd, 0) if player_profile != null else 0
func _hub_confirm_stats() -> void:
	if player_profile == null: return
	_play_sound("ui_confirm", 0.0, 1.0)
	player_profile.allocate_stat(&"VIT", screen_state_controller.hub_pending_vit)
	player_profile.allocate_stat(&"STR", screen_state_controller.hub_pending_str)
	player_profile.allocate_stat(&"DEF", screen_state_controller.hub_pending_def)
	player_profile.allocate_stat(&"SPD", screen_state_controller.hub_pending_spd)
	screen_state_controller.hub_pending_vit = 0; screen_state_controller.hub_pending_str = 0; screen_state_controller.hub_pending_def = 0; screen_state_controller.hub_pending_spd = 0
	_apply_profile_to_runtime(); _apply_player_level(); _sync_runtime_progression_to_profile()
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _hub_cancel_stats() -> void:
	screen_state_controller.hub_pending_vit = 0; screen_state_controller.hub_pending_str = 0; screen_state_controller.hub_pending_def = 0; screen_state_controller.hub_pending_spd = 0
	if screen_state_controller != null and screen_state_controller.hub_overlay != null: screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _hub_auto_allocate() -> void:
	if player_profile == null: return
	var patterns := [[&"VIT", &"STR", &"DEF", &"SPD"], [&"VIT", &"VIT", &"STR", &"VIT", &"DEF", &"SPD"], [&"STR", &"STR", &"VIT", &"STR", &"DEF", &"SPD"], [&"DEF", &"DEF", &"VIT", &"DEF", &"STR", &"SPD"], [&"STR", &"DEF", &"STR", &"DEF", &"SPD"]]
	var pattern: Array = patterns[clampi(player_profile.allocation_profile, 0, patterns.size() - 1)]
	var index := 0
	while _hub_points_remaining() > 0:
		match pattern[index % pattern.size()]:
			&"VIT": screen_state_controller.hub_pending_vit += 1
			&"STR": screen_state_controller.hub_pending_str += 1
			&"DEF": screen_state_controller.hub_pending_def += 1
			&"SPD": screen_state_controller.hub_pending_spd += 1
		index += 1
	screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _hub_respec() -> void:
	_hub_cancel_stats()
	if _respec_player_stats() > 0: screen_state_controller.update_hub_ui(self, Callable(self, "_pixel_text_texture"))
func _start_from_hub() -> void:
	if screen_state_controller.hub_opened_from_npc:
		_close_hub_to_run()
		return
	if screen_state_controller.hub_overlay != null: screen_state_controller.hub_overlay.visible = false
	if player_profile != null:
		player_profile.open_hub_on_load = false
		player_profile.pending_route = "run"
		_save_player_profile()
	_play_sound("ui_confirm", 0.0, 1.0)
	_begin_scene_transition()

func _run_difficulty_bonus() -> int:
	if player_profile == null:
		return 0
	return clampi(player_profile.difficulty_rank - 1, 0, 12)

func _run_rank() -> int:
	return maxi(player_profile.difficulty_rank if player_profile != null else 1, 1)

func _apply_run_rank_grade(grade: String) -> void:
	if player_profile == null:
		return
	var normalized_grade := grade.to_upper()
	var rank_change := 2 if normalized_grade == "S" else 1 if normalized_grade == "A" or normalized_grade == "B" else -1 if normalized_grade == "F" else 0
	player_profile.difficulty_rank = clampi(player_profile.difficulty_rank + rank_change, 1, 20)
	player_profile.last_run_grade = normalized_grade

func _begin_new_run() -> void:
	_combat_momentum().reset_all()
	if run_state != null:
		run_state.begin(current_dungeon_seed, _run_difficulty_bonus(), _player_max_health())
func _return_to_hub() -> void:
	_settle_current_run(&"defeat" if player_dead else &"return_to_hub")
	if player_profile != null:
		player_profile.open_hub_on_load = false
		player_profile.pending_route = "run"
		_save_player_profile()
	_begin_scene_transition()
func _settle_current_run(result: StringName) -> bool:
	if run_state == null or not run_state.active:
		return false
	_sync_runtime_progression_to_profile()
	return RunSettlement.settle(player_profile, run_state, result)
func _tick_run_telemetry(delta: float) -> void:
	if run_state == null or not run_state.active:
		return
	run_state.tick(delta)
	if _is_run_combat_active():
		run_state.record_combat_time(delta, player_is_moving)
	if player_is_moving:
		run_state.record_movement(delta)
func _is_run_combat_active() -> bool:
	return run_state != null and run_state.active and _is_any_slime_aggroed()
func _on_player_successful_block(_shield_damage: float, _health_damage: float) -> void:
	if run_state != null and _is_run_combat_active():
		run_state.record_block()
	_play_sound("block", -8.0, 0.95 + rng.randf_range(-0.08, 0.08))

func _record_run_action_input(action: StringName, accepted: bool) -> void:
	if run_state != null and run_state.active:
		run_state.record_action_input(action, accepted)

func _clear_reward_rarity(score: int, roll: float) -> StringName:
	return _roll_run_loot_rarity(roll, clampf(float(score) / 100.0, 0.0, 1.0))

func _roll_run_loot_rarity(roll: float, score_quality: float = -1.0) -> StringName:
	var performance_bonus := score_quality * 3.0 if score_quality >= 0.0 else _loot_grade_bonus()
	return ItemCatalog.new().roll_run_rarity(roll, _run_rank(), performance_bonus)

func _complete_run() -> void:
	if run_state == null or run_state.settled or screen_state_controller.run_complete_overlay == null or screen_state_controller.run_complete_overlay.visible:
		return
	_finalize_run_exploration()
	_finalize_run_enemy_total()
	var grade: Dictionary = RunGradeEvaluator.evaluate(run_state, run_state.starting_health)
	var score := int(grade["score"])
	_apply_run_rank_grade(str(grade["grade"]))
	var gold_reward := 45 + score * 3 + int(grade["variety_count"]) * 8
	var reward_rng := RandomNumberGenerator.new()
	reward_rng.seed = current_dungeon_seed ^ run_state.run_id.hash() ^ score * 7919
	var dropped_item: ItemInstance = null
	if reward_rng.randf() < clampf(0.30 + float(score) * 0.0065, 0.30, 0.95):
		var catalog := ItemCatalog.new()
		var slot := ItemCatalog.SLOTS[reward_rng.randi_range(0, ItemCatalog.SLOTS.size() - 1)]
		var rarity := _clear_reward_rarity(score, reward_rng.randf())
		dropped_item = catalog.generate_item(slot, reward_rng.randi(), player_profile.level, rarity)
		dropped_item.instance_id = player_profile.create_item_id("clear")
		player_profile.grant_item(dropped_item)
	if player_profile != null:
		player_profile.gold += gold_reward
		player_profile.completed_runs += 1
		player_profile.last_clear_score = score
	_update_gold_indicator()
	var drop_label := "NO GEAR DROP"
	var drop_color := Color8(150, 156, 170)
	if dropped_item != null:
		var reward_catalog := ItemCatalog.new()
		drop_label = reward_catalog.display_name(dropped_item)
		drop_color = reward_catalog.rarity_color(dropped_item.rarity)
	run_state.clear_summary = {"score": score, "grade": str(grade["grade"]), "gold": gold_reward, "drop": drop_label, "difficulty": _run_difficulty_bonus(), "run_rank": _run_rank(), "time": run_state.elapsed_time, "damage": run_state.damage_taken, "variety": int(grade["variety_count"]), "variety_max": int(grade["variety_max"]), "kills": run_state.enemies_killed, "total_enemies": run_state.total_enemies, "blocks": run_state.block_count, "attacks": run_state.attack_count, "attack_hits": run_state.attack_swing_hit_count, "accuracy": float(grade["accuracy"]), "wasted_inputs": run_state.total_wasted_inputs(), "explored_rooms": int(grade["explored_rooms"]), "explorable_rooms": int(grade["explorable_rooms"]), "dodges": run_state.dodge_count, "time_quality": float(grade["time_score"]) / 28.0, "survival_quality": float(grade["survival_score"]) / 25.0, "control_quality": float(grade["control_score"]) / 2.0}
	_sync_runtime_progression_to_profile()
	_settle_current_run(&"complete")
	_show_run_complete(drop_color)

func _show_run_complete(drop_color: Color) -> void:
	if screen_state_controller.run_complete_overlay == null or run_state == null:
		return
	var summary := run_state.clear_summary
	var elapsed := int(round(float(summary.get("time", 0.0))))
	var kills := int(summary.get("kills", 0))
	var total_enemies := maxi(int(summary.get("total_enemies", 0)), kills)
	var exploration_quality := float(summary.get("explored_rooms", 0)) / float(maxi(int(summary.get("explorable_rooms", 0)), 1))
	var kill_quality := float(kills) / float(maxi(total_enemies, 1))
	var accuracy_quality := float(summary.get("accuracy", 0.0))
	var style_quality := float(summary.get("variety", 0)) / float(maxi(int(summary.get("variety_max", 0)), 1))
	var lines := ["GRADE %s    SCORE %03d" % [str(summary.get("grade", "D")), int(summary.get("score", 0))], "TIME %02d:%02d  DMG %d" % [floori(float(elapsed) / 60.0), elapsed % 60, roundi(float(summary.get("damage", 0.0)))], "EXPLORE %d/%d" % [int(summary.get("explored_rooms", 0)), int(summary.get("explorable_rooms", 0))], "KILLS %d/%d  BLOCKS %d  DODGES %d" % [kills, total_enemies, int(summary.get("blocks", 0)), int(summary.get("dodges", 0))], "ATTACKS %d  HITS %d" % [int(summary.get("attacks", 0)), int(summary.get("attack_hits", 0))], "ACCURACY %d%%" % roundi(accuracy_quality * 100.0), "MISINPUTS %d" % int(summary.get("wasted_inputs", 0)), "STYLE %d/%d" % [int(summary.get("variety", 0)), int(summary.get("variety_max", 3))], "SPOILS", "+%d GOLD" % int(summary.get("gold", 0)), str(summary.get("drop", "NO GEAR DROP"))]
	var line_colors := [Color8(255, 205, 117), _run_metric_color((float(summary.get("time_quality", 0.0)) + float(summary.get("survival_quality", 0.0))) * 0.5), _run_metric_color(exploration_quality), _run_metric_color(kill_quality), _run_metric_color(accuracy_quality), _run_metric_color(accuracy_quality), _run_metric_color(float(summary.get("control_quality", 0.0))), _run_metric_color(style_quality), Color8(255, 205, 117), Color8(255, 205, 117), drop_color]
	for index in mini(screen_state_controller.run_complete_texts.size(), lines.size()):
		screen_state_controller.run_complete_texts[index].texture = _pixel_text_texture(lines[index], line_colors[index])
	screen_state_controller.run_complete_overlay.visible = true
	screen_state_controller.set_state(&"run_complete")

func _run_metric_color(quality: float) -> Color:
	var value := clampf(quality, 0.0, 1.0)
	if value >= 0.95:
		return Color8(177, 62, 83) # Mythic
	if value >= 0.85:
		return Color8(255, 205, 117) # Legendary
	if value >= 0.70:
		return Color8(118, 66, 138) # Epic
	if value >= 0.50:
		return Color8(65, 166, 246) # Rare
	return Color.WHITE # Common

func _update_run_complete_input() -> void:
	if screen_state_controller.run_complete_button == null:
		return
	if Input.is_action_just_pressed("ui_accept") or _is_interact_input_pressed() or _is_menu_cancel_input_pressed():
		screen_state_controller.run_complete_button.pressed.emit()

func _return_from_run_complete() -> void:
	if screen_state_controller.run_complete_overlay != null:
		screen_state_controller.run_complete_overlay.visible = false
	if player_profile != null:
		player_profile.open_hub_on_load = false
		player_profile.pending_route = "run"
		_save_player_profile()
	_begin_scene_transition()
func _show_game_over() -> void:
	if game_over_overlay == null or game_over_overlay.visible: return
	_apply_run_rank_grade("F")
	_settle_current_run(&"defeat")
	game_over_overlay.visible = true; screen_state_controller.set_state(&"game_over"); game_over_fade_timer = 0.0; game_over_overlay.modulate.a = 0.0; game_over_button.grab_focus()
func _build_title_screen() -> void: var controls := screen_state_controller.build_title(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_start_new_game"), Callable(self, "_continue_game"), has_persistent_profile); screen_state_controller.title_overlay = controls["overlay"] as ColorRect; screen_state_controller.title_screen_text = controls["text"] as Sprite2D; screen_state_controller.title_start_button = controls["new_game"] as Button; screen_state_controller.title_continue_button = controls["continue"] as Button; screen_state_controller.title_start_text = controls["start_text"] as Sprite2D; screen_state_controller.title_cursor_text = controls["cursor"] as Sprite2D; _build_archetype_screen()
func _build_archetype_screen() -> void: var controls := screen_state_controller.build_archetype(ui, Callable(self, "_shift_archetype"), Callable(self, "_shift_archetype_color"), Callable(self, "_start_selected_archetype"), Callable(self, "_pixel_text_texture")); screen_state_controller.archetype_overlay = controls["overlay"] as ColorRect; screen_state_controller.archetype_preview = controls["preview"] as Sprite2D; screen_state_controller.archetype_name_text = controls["name"] as Sprite2D; screen_state_controller.archetype_left_buttons = controls["left"] as Array[Button]; screen_state_controller.archetype_right_buttons = controls["right"] as Array[Button]; screen_state_controller.archetype_type_left_button = controls["type_left"] as Button; screen_state_controller.archetype_type_right_button = controls["type_right"] as Button; screen_state_controller.archetype_start_button = controls["start"] as Button; screen_state_controller.archetype_hold_cover = controls["cover"] as ColorRect; _update_archetype_screen()
func _update_title_screen(delta: float) -> void: screen_state_controller.update_title_flow(self, delta)
func _start_new_game() -> void:
	screen_state_controller.start_save_select(self, "new")
func _continue_game() -> void:
	screen_state_controller.start_save_select(self, "continue")

func _open_save_select_after_title_transition() -> void:
	if screen_state_controller.save_select_overlay == null:
		screen_state_controller.save_select_overlay = screen_state_controller.build_save_select(ui, Callable(self, "_pixel_text_texture"), Callable(self, "_select_save_slot"), Callable(self, "_confirm_overwrite"), Callable(self, "_cancel_overwrite"), Callable(self, "_save_preview_texture"))
	screen_state_controller.save_select_index = 0
	screen_state_controller.menu_input_release_lock = true
	# Keep the opaque title cover behind the save menu. The gameplay scene must
	# never be exposed between the title transition and save selection.
	if screen_state_controller.title_overlay != null:
		screen_state_controller.title_overlay.visible = true
		screen_state_controller.title_overlay.modulate.a = 1.0
	screen_state_controller.save_select_overlay.visible = true
	_update_save_select_cursor()

func _update_save_select_cursor() -> void:
	if screen_state_controller.save_select_overlay == null: return
	for child in screen_state_controller.save_select_overlay.get_children():
		if child is Button and child.has_meta("save_slot") and int(child.get_meta("save_slot")) == screen_state_controller.save_select_index:
			(child as Button).grab_focus()
	var cursor := screen_state_controller.save_select_overlay.get_node_or_null("SaveSelectCursor") as Sprite2D
	if cursor != null: cursor.position = Vector2(55, 70 + screen_state_controller.save_select_index * 20)

func _save_preview_texture(palette_name: String) -> Texture2D:
	if player_animation_component == null:
		return null
	var base_frames := player_animation_component.base_idle_frames as Array[Texture2D]
	if base_frames.is_empty():
		return null
	return player_animation_component.recolor_texture(base_frames[0], palette_name)

func _select_save_slot(slot: int) -> void:
	screen_state_controller.save_select_index = clampi(slot, 0, ProfileSaveService.SLOT_COUNT - 1)
	_update_save_select_cursor()
	if screen_state_controller.save_select_mode == "continue":
		_select_continue_slot(slot)
		return
	if ProfileSaveService.slot_has_profile(slot):
		screen_state_controller.save_overwrite_slot = slot
		_set_overwrite_prompt(true)
		return
	screen_state_controller.save_overwrite_slot = slot
	_confirm_overwrite()

func _set_overwrite_prompt(active: bool) -> void:
	screen_state_controller.save_overwrite_prompt_active = active
	screen_state_controller.save_overwrite_choice = 0
	screen_state_controller.menu_input_release_lock = active
	for node_name in ["OverwritePrompt", "OverwriteYes", "OverwriteNo"]:
		var node := screen_state_controller.save_select_overlay.get_node_or_null(node_name)
		if node != null: node.visible = active
	var cursor := screen_state_controller.save_select_overlay.get_node_or_null("OverwriteCursor") as Sprite2D
	if cursor != null: cursor.visible = active; cursor.position = Vector2(99, 140)

func _cancel_overwrite() -> void:
	screen_state_controller.save_overwrite_prompt_active = false
	_set_overwrite_prompt(false)
	_update_save_select_cursor()

func _confirm_overwrite() -> void:
	screen_state_controller.save_overwrite_prompt_active = false
	_set_overwrite_prompt(false)
	var selected_slot := screen_state_controller.save_overwrite_slot if ProfileSaveService.slot_has_profile(screen_state_controller.save_overwrite_slot) else screen_state_controller.save_select_index
	ProfileSaveService.select_slot(selected_slot)
	ProfileSaveService.clear_slot(selected_slot)
	if screen_state_controller.save_select_overlay != null: screen_state_controller.save_select_overlay.visible = false
	player_profile = PlayerProfile.new()
	_reset_runtime_for_new_save()
	has_persistent_profile = false
	_apply_profile_to_runtime()
	_update_gold_indicator()
	screen_state_controller.show_character_creation(self)

func _reset_runtime_for_new_save() -> void:
	# New slots must not inherit the previous profile's run rank, grade-weighted
	# loot state, dungeon topology, or in-progress telemetry.
	player_profile.completed_runs = 0
	player_profile.last_clear_score = 0
	player_profile.difficulty_rank = 1
	player_profile.last_run_grade = "D"
	player_profile.pending_route = "title"
	player_profile.open_hub_on_load = false
	if run_state != null:
		run_state = RunState.new()
	var random_source := rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		random_source.randomize()
	current_dungeon_seed = random_source.randi()
	dungeon_graph.configure_progression(0)
	dungeon_graph.initialize(current_dungeon_seed)
	room_controller.room_states.clear()
	room_controller.progression_run_rank = 1
	current_room_id = dungeon_graph.start_room_id
	_sync_current_room_metadata()
	room_controller.set_current_room(current_room_id, current_room_type)
	_ensure_current_room_layout()
	_apply_room_state()
	_update_room_number_indicator()

func _update_overwrite_cursor() -> void:
	var cursor := screen_state_controller.save_select_overlay.get_node_or_null("OverwriteCursor") as Sprite2D
	if cursor != null:
		cursor.position = Vector2(99 if screen_state_controller.save_overwrite_choice == 0 else 129, 140)

func _close_save_select() -> void:
	if screen_state_controller.save_select_overlay != null:
		screen_state_controller.save_select_overlay.visible = false
	screen_state_controller.menu_input_release_lock = false
	if screen_state_controller.title_overlay != null:
		screen_state_controller.title_overlay.visible = true
		screen_state_controller.title_overlay.modulate.a = 1.0
	if screen_state_controller.title_screen_text != null: screen_state_controller.title_screen_text.visible = true
	if screen_state_controller.title_start_text != null: screen_state_controller.title_start_text.visible = true
	if screen_state_controller.title_start_button != null: screen_state_controller.title_start_button.visible = true
	if screen_state_controller.title_continue_button != null: screen_state_controller.title_continue_button.visible = screen_state_controller.title_continue_button.disabled == false
	if screen_state_controller.title_cursor_text != null: screen_state_controller.title_cursor_text.visible = true
	screen_state_controller.title_transition_active = false
	screen_state_controller.pending_title_destination = ""
	screen_state_controller.set_state(&"title")
	if screen_state_controller.title_continue_button != null:
		(screen_state_controller.title_continue_button if not screen_state_controller.title_continue_button.disabled else screen_state_controller.title_start_button).grab_focus()
	_play_sound("ui_decline", 0.0, 1.0)

func _cancel_character_creation() -> void:
	_play_sound("ui_decline", 0.0, 1.0)
	if screen_state_controller.archetype_overlay != null: screen_state_controller.archetype_overlay.visible = false
	if screen_state_controller.title_overlay != null:
		screen_state_controller.title_overlay.visible = true
		screen_state_controller.title_overlay.modulate.a = 1.0
	if screen_state_controller.title_screen_text != null: screen_state_controller.title_screen_text.visible = true
	if screen_state_controller.title_start_text != null: screen_state_controller.title_start_text.visible = true
	if screen_state_controller.title_start_button != null: screen_state_controller.title_start_button.visible = true
	if screen_state_controller.title_continue_button != null: screen_state_controller.title_continue_button.visible = not screen_state_controller.title_continue_button.disabled
	if screen_state_controller.title_cursor_text != null: screen_state_controller.title_cursor_text.visible = true
	screen_state_controller.title_transition_active = false
	screen_state_controller.pending_title_destination = ""
	screen_state_controller.set_state(&"title")
	if screen_state_controller.title_start_button != null: screen_state_controller.title_start_button.grab_focus()

func _select_continue_slot(slot: int) -> void:
	if not ProfileSaveService.slot_has_profile(slot):
		return
	ProfileSaveService.select_slot(slot)
	player_profile = ProfileSaveService.load_profile()
	if not player_profile.has_started:
		return
	player_profile.pending_route = "run"
	ProfileSaveService.save_profile(player_profile)
	if screen_state_controller.save_select_overlay != null:
		screen_state_controller.save_select_overlay.visible = false
	_begin_scene_transition()
func _enter_starting_room_from_menu() -> void:
	if screen_state_controller.title_overlay != null: screen_state_controller.title_overlay.visible = false
	if screen_state_controller.archetype_overlay != null: screen_state_controller.archetype_overlay.visible = false
	if screen_state_controller.hub_overlay != null: screen_state_controller.hub_overlay.visible = false
	# Keep the player and both shadow layers covered while the starting position,
	# palette, and depth transforms are initialized. Otherwise the shadow can
	# visibly slide in from the scene's editor position during a new game.
	player.visible = false
	if player_shadow != null: player_shadow.visible = false
	if player_sprite_shadow != null: player_sprite_shadow.visible = false
	if player_attack_visual != null: player_attack_visual.visible = false
	loading_screen_active = true
	loading_screen_fading = false
	loading_screen_timer = 0.0
	loading_screen_overlay.visible = true
	loading_screen_overlay.modulate.a = 1.0
	screen_state_controller.set_state(&"loading")
	await get_tree().process_frame
	_place_player_at_hub_fire()
	await _apply_player_palette_async(screen_state_controller.player_palette_name)
	_update_player_aggro_marker_colors()
	var maximum_health := _player_max_health()
	if player_health_component != null:
		player_health_component.maximum_health = maximum_health
		player_health_component.reset(maximum_health)
	player_display_health = maximum_health
	player_animation_component.apply_frame(self)
	_update_player_shadow()
	_build_depth_lists()
	player.visible = true
	_update_player_shadow()
	_build_depth_lists()
	_begin_new_run()
	loading_screen_fading = true
	loading_screen_timer = 0.0

func _place_player_at_hub_fire() -> void:
	if rest_fire == null:
		return
	# The hub always begins with the player just left of the fire, rather than
	# reusing an editor-positioned start marker.
	var requested_foot := rest_fire.global_position + Vector2(-14.0, 3.0)
	var valid_foot := _nearest_slime_walkable_point(requested_foot)
	player.global_position = valid_foot - ACTOR_FOOT_OFFSET
func _update_archetype_input(delta: float) -> void: screen_state_controller.update_archetype_input(self, delta)
func _shift_archetype(direction: int) -> void: screen_state_controller.archetype_index = posmod(screen_state_controller.archetype_index + direction, 4); screen_state_controller.selected_archetype = screen_state_controller.archetype_index as StatsComponent.AllocationProfile; _archetype_arrow_pulse(direction); _update_archetype_screen()
func _shift_archetype_color(direction: int) -> void: screen_state_controller.archetype_color_index = posmod(screen_state_controller.archetype_color_index + direction, 8); _archetype_arrow_pulse(direction); _update_archetype_screen()
func _archetype_arrow_pulse(direction: int) -> void: screen_state_controller.archetype_arrow_anim_direction = direction; screen_state_controller.archetype_arrow_anim_timer = 0.18
func _update_archetype_arrow_animation() -> void:
	var amount := clampf(screen_state_controller.archetype_arrow_anim_timer / 0.18, 0.0, 1.0); var pulse := 1.0 + amount * 0.22
	screen_state_controller.archetype_type_left_button.scale = Vector2.ONE * (pulse if screen_state_controller.archetype_arrow_anim_direction < 0 and screen_state_controller.archetype_menu_row == 0 else 1.0); screen_state_controller.archetype_type_right_button.scale = Vector2.ONE * (pulse if screen_state_controller.archetype_arrow_anim_direction > 0 and screen_state_controller.archetype_menu_row == 0 else 1.0)
	for button in screen_state_controller.archetype_left_buttons: button.scale = Vector2.ONE * (pulse if screen_state_controller.archetype_arrow_anim_direction < 0 and screen_state_controller.archetype_menu_row == 1 else 1.0); for right_button in screen_state_controller.archetype_right_buttons: right_button.scale = Vector2.ONE * (pulse if screen_state_controller.archetype_arrow_anim_direction > 0 and screen_state_controller.archetype_menu_row == 1 else 1.0)
func _select_archetype_menu_row(row: int) -> void: screen_state_controller.archetype_menu_row = posmod(row, 3); _update_archetype_screen(); if screen_state_controller.archetype_menu_row == 2: screen_state_controller.archetype_start_button.grab_focus()
func _update_archetype_screen() -> void:
	var names := ["BALANCED", "VIT", "STR", "DEF"]; var colors := ["blue", "orange", "green", "red", "yellow", "grey", "purple", "aquamarine"]
	screen_state_controller.archetype_name_text.texture = _pixel_text_texture(names[screen_state_controller.archetype_index], PaletteLibrary.ARCHETYPE_HIGHLIGHTS[screen_state_controller.archetype_color_index] if screen_state_controller.archetype_menu_row == 0 else Color.WHITE); screen_state_controller.archetype_name_text.position = Vector2((240.0 - screen_state_controller.archetype_name_text.texture.get_width()) * 0.5, 36)
	if not player_animation_component.idle_frames.is_empty():
		if screen_state_controller.archetype_preview_palette != colors[screen_state_controller.archetype_color_index] or screen_state_controller.archetype_preview_frames.size() != player_animation_component.idle_frames.size():
			screen_state_controller.archetype_preview_frames.clear(); screen_state_controller.archetype_preview_palette = colors[screen_state_controller.archetype_color_index]
			for frame in player_animation_component.idle_frames: screen_state_controller.archetype_preview_frames.append(player_animation_component.recolor_texture(frame, screen_state_controller.archetype_preview_palette))
		_update_archetype_preview_animation()
	_update_archetype_button_styles()
func _update_archetype_preview_animation() -> void:
	if screen_state_controller.archetype_preview == null or screen_state_controller.archetype_preview_frames.is_empty(): return
	var frame_time := maxf(player_tuning.idle_frame_time, 0.01); var frame_index := posmod(int(screen_state_controller.archetype_frame_timer / frame_time), screen_state_controller.archetype_preview_frames.size())
	screen_state_controller.archetype_preview.texture = screen_state_controller.archetype_preview_frames[frame_index]; screen_state_controller.archetype_preview.position = Vector2((240.0 - screen_state_controller.archetype_preview.texture.get_width() * screen_state_controller.archetype_preview.scale.x) * 0.5, 48)
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
func _update_player_aggro_marker_colors() -> void: hud_controller.update_aggro_markers(hud_controller.target_overhead_aggro_markers, screen_state_controller.player_palette_name, Callable(self, "_pixel_particle_texture"))
func _spawn_title_pixel_breakup(source_sprite: Sprite2D) -> void:
	if screen_state_controller.title_particle_layer == null:
		screen_state_controller.title_particle_layer = Node2D.new(); screen_state_controller.title_particle_layer.name = "TitleParticleLayer"; screen_state_controller.title_particle_layer.z_index = 10; ui.add_child(screen_state_controller.title_particle_layer)
	screen_state_controller.spawn_pixel_breakup(source_sprite, screen_state_controller.title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _spawn_title_button_frame_breakup() -> void: screen_state_controller.spawn_button_frame_breakup(screen_state_controller.title_start_button, screen_state_controller.title_particle_layer, Callable(self, "_pixel_particle_texture"), rng.randi())
func _update_game_over_input() -> void:
	if game_over_overlay == null or not game_over_overlay.visible: return
	if _is_interact_input_pressed(): _return_to_hub()
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
	_register_combo_hit()
	var ambush := _slime_ambush(slime)
	if ambush != null:
		ambush.extend_rehide(slime, slime_tuning.ambush_hit_extension)
	SlimeActor.damage_actor(self, slime, amount, was_critical)
	_play_sound("slash", -15.0, 0.95 + rng.randf_range(-0.10, 0.10))
	_play_sound("flesh", -10.0, 0.88 + rng.randf_range(-0.06, 0.06))
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
func _reset_combo() -> void: _combat_momentum().reset_combo()
func _player_attack_damage_share_divisor(slime: Sprite2D, target_count: int) -> float:
	return equipment_transmutation_component.damage_share_divisor(slime, target_count) if equipment_transmutation_component != null else maxf(float(target_count), 1.0)
func _combat_damage(attacker_stats: StatsComponent, defender_stats: StatsComponent) -> float:
	var attacker_snapshot := CombatStatSnapshot.from_components(attacker_stats, player_equipment if attacker_stats == player_stats else null)
	var defender_snapshot := CombatStatSnapshot.from_components(defender_stats, player_equipment if defender_stats == player_stats else null)
	var result := CombatCalculator.calculate_snapshot_damage(attacker_snapshot, defender_snapshot, attacker_stats == player_stats, rng, combat_tuning)
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
	var scale := _slime_encounter_scale(slime)
	if scale > 1.0:
		health *= scale * 1.25
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
	var direction := _actor_foot(slime) - _actor_foot(player); if direction.length_squared() < 0.01: direction = Vector2.LEFT if player_attack_flip_h else Vector2.RIGHT
	var knockback_multiplier := equipment_transmutation_component.attack_knockback_multiplier() if equipment_transmutation_component != null else 1.0
	var attack_component := player_attack_component as PlayerAttackComponent
	var combo_multiplier := 1.0 if attack_component != null and attack_component.variant == 2 else player_tuning.attack1_knockback_multiplier
	var combat := _slime_combat(slime); combat.knockback_velocity = _perspective_movement(direction.normalized() * (player_tuning.attack_knockback * combo_multiplier * knockback_multiplier / slime_tuning.knockback_duration)); combat.knockback_timer = slime_tuning.knockback_duration
	var brain := _slime_brain(slime); brain.scoot_start = slime.position; brain.scoot_target = slime.position; brain.scoot_timer = 0.0; brain.hold_timer = slime_tuning.hitstun_time
func _kill_slime(slime: Sprite2D) -> void:
	if _is_slime_dead(slime): return
	if run_state != null and run_state.active:
		run_state.record_enemy_kill()
	_play_sound("enemy_death", -6.0, 0.90 + rng.randf_range(-0.08, 0.08))
	_award_slime_xp(slime)
	effects_spawner.spawn_slime_death_from_root(self, slime); room_controller.kill_slime_without_effects(self, slime)
	if current_target == slime:
		if _is_target_input_held(): _set_current_target(_closest_target())
		else: _set_current_target(null); _set_target_ui_visible(false)
	if _are_all_slimes_dead():
		_unlock_chest()
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
func _build_npc_dialogue() -> void: var dialogue := npc_controller.build_dialogue(self, _load_texture_or_null("res://assets/artwork/circle55.png")); npc_controller.dialogue_layer = dialogue["layer"] as CanvasLayer; npc_controller.dialogue_box = dialogue["box"] as ColorRect; npc_controller.dialogue_text = dialogue["text"] as Sprite2D; npc_controller.dialogue_button = dialogue["button"] as Sprite2D; npc_controller.dialogue_button_shadow = dialogue["shadow"] as Sprite2D; npc_controller.dialogue_yes_text = dialogue["yes"] as Sprite2D; npc_controller.dialogue_no_text = dialogue["no"] as Sprite2D
func _build_room_number_indicator() -> void:
	var hud: Dictionary = hud_controller.build_world_hud(ui, sprite_frame_library, Callable(self, "_load_texture_or_null"), target_health_bar, target_health_fill, player_health_fill)
	hud_controller.room_number_indicator = hud["room"] as Sprite2D; hud_controller.dungeon_run_indicator = hud["dungeon_run"] as Sprite2D; hud_controller.gold_indicator = hud["gold"] as Sprite2D; hud_controller.gold_amount_indicator = hud["gold_amount"] as Sprite2D; hud_controller.run_timer_indicator = hud["timer"] as Sprite2D; hud_controller.gold_animation_frames = hud["gold_frames"] as Array[Texture2D]; 	hud_controller.button_hud_sprites = hud["buttons"] as Array[Sprite2D]; target_health_text = hud["target_text"] as Sprite2D; focus_label = hud["focus_label"] as Sprite2D; player_health_text = hud["player_text"] as Sprite2D; _update_room_number_indicator(); _update_gold_indicator()
	var hud_root := ui.get_node("PlayerHud") as Node2D
	var player_hud_color := _health_feedback_color(screen_state_controller.player_palette_name)
	hud_root.call("set_static_text", "lv. 1", player_hud_color)
	hud_root.call("apply_bar_colors", player_hud_color)
	_update_player_progression_ui()
func _update_gold_indicator() -> void: if hud_controller.gold_indicator != null: hud_controller.gold_amount_indicator.texture = _pixel_text_texture(str(player_profile.gold if player_profile != null else 0), Color8(255, 205, 117))
func _update_room_number_indicator() -> void: hud_controller.update_room_number(self)
func _set_entrance_open(is_open: bool) -> void:
	entrance_open = is_open; _refresh_room_socket_visuals(is_open)
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
func _update_interact_prompt(delta: float) -> void: interaction_component.update_world_prompt(self, delta, NPC_DIALOGUE_BUTTON_BOB_TIME, OVERWORLD_UI_Z + 1)
func _set_door_active(is_active: bool) -> void:
	door_active = is_active; _refresh_room_socket_visuals(is_active)
func _collect_dungeon_sockets() -> void:
	room_controller.dungeon_sockets.clear()
	if sockets_root == null: return
	for child in sockets_root.get_children(): var socket := child as DungeonSocket; if socket != null: room_controller.dungeon_sockets[socket.socket_id()] = socket
func _sync_current_room_metadata() -> void:
	var room := dungeon_graph.get_room(current_room_id)
	if room != null:
		current_room_depth = room.depth
		current_room_display_number = room.display_number
		current_room_type = room.room_type
		if current_room_depth >= 1 and run_state != null and run_state.active:
			run_state.start_timer()
			run_state.record_room_visited(current_room_id)
func _finalize_run_exploration() -> void:
	if run_state == null or dungeon_graph == null:
		return
	var explorable_rooms := 0
	for room_id in dungeon_graph.get_room_ids():
		var room := dungeon_graph.get_room(room_id)
		if room != null and room.depth >= 1:
			explorable_rooms += 1
	run_state.set_explorable_room_count(explorable_rooms)
func _finalize_run_enemy_total() -> void:
	if run_state == null or dungeon_graph == null or room_controller == null:
		return
	var total_enemies := 0
	for room_id in dungeon_graph.get_room_ids():
		var room := dungeon_graph.get_room(room_id)
		total_enemies += room_controller.enemy_count_for_room(room)
	run_state.set_total_enemies(total_enemies)
func _ensure_current_room_layout() -> void:
	var room := dungeon_graph.get_room(current_room_id)
	if room == null: return
	room_controller.progression_run_rank = _run_rank()
	_apply_room_geometry()
	_collect_walkable_tiles(floor_tiles)
	_build_entrance_block_polygons()
	_build_walkable_outline()
	var state := room_controller.ensure_layout(dungeon_graph, current_room_id, room, current_room_type, current_room_depth)
	_configure_room_sockets(bool(state.get("finished", false)))
func _configure_room_sockets(is_unlocked: bool) -> void:
	room_controller.configure_sockets(dungeon_graph, current_room_id, is_unlocked, Callable(self, "_build_entrance_block_polygons")); door_active = is_unlocked; entrance_open = is_unlocked; _refresh_room_socket_visuals(is_unlocked)
func _refresh_room_socket_visuals(is_unlocked: bool) -> void:
	var shut_texture := _load_texture_or_null("res://assets/artwork/DoorRightenemyshut.png")
	var open_texture := _load_texture_or_null("res://assets/artwork/DoorRight.png")
	var stairs_down_texture := _load_texture_or_null("res://assets/artwork/DoorStairsRight.png")
	var stairs_up_texture := _load_texture_or_null("res://assets/artwork/DoorStairsUPRight.png")
	for socket_value in room_controller.active_door_sockets.values():
		var socket := socket_value as DungeonSocket; var visual := socket.visual() as Sprite2D
		if visual == null: continue
		var connection: DungeonGraph.ConnectionRecord = dungeon_graph.get_connection(current_room_id, socket.socket_id())
		var destination_room: DungeonGraph.RoomRecord = dungeon_graph.get_room(connection.destination_room_id) if connection != null else null
		var leads_downstairs := destination_room != null and destination_room.room_type == DungeonGraph.ROOM_DOWNSTAIRS
		visual.visible = true if current_room_type == DungeonGraph.ROOM_COMBAT and not is_unlocked else is_unlocked
		visual.texture = stairs_up_texture if current_room_type == DungeonGraph.ROOM_DOWNSTAIRS else stairs_down_texture if leads_downstairs else open_texture if is_unlocked else shut_texture
		visual.flip_h = socket.socket_id() == DungeonGraph.WALL_LEFT
	for socket_value in room_controller.active_entrance_sockets.values():
		var socket := socket_value as DungeonSocket; var visual := socket.visual() as Sprite2D
		if visual == null: continue
		if socket.socket_id() == DungeonGraph.BOTTOM_LEFT or socket.socket_id() == DungeonGraph.BOTTOM_RIGHT:
			# Lower entrances are floor extensions, never door or stair renderers.
			visual.visible = true
			continue
		visual.visible = true
		visual.texture = open_texture
		visual.flip_h = socket.socket_id() == DungeonGraph.WALL_LEFT
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
	state["finished"] = chest_claimed
	if world_item_drop != null and is_instance_valid(world_item_drop) and world_item_drop_instance != null:
		state["world_item_drop"] = {"item": world_item_drop_instance.to_dictionary(), "position": world_item_drop.global_position}
	else:
		state.erase("world_item_drop")
	room_controller.room_states[current_room_id] = state
	if room_controller != null and chest_claimed: room_controller.mark_cleared(current_room_id)
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
	return not _is_slime_dead(slime) and not _is_slime_hidden(slime)
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
	_play_sound("ui_confirm", -10.0, 1.0)
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
	if player_dead or _actor_foot(player).distance_to(_actor_foot(slime)) > attack_distance:
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
	var combat := _slime_combat(slime)
	var guide_name := "AttackGuideL" if combat != null and combat.face_left else "AttackGuideR"
	var guide := slime.get_node_or_null(guide_name) as Node2D
	var guide_reach := slime_tuning.attack_hit_range
	if guide != null:
		var guide_position: Vector2 = guide.get("rect_position")
		var guide_size: Vector2 = guide.get("rect_size")
		var guide_rect := Rect2(slime.global_position + guide.position + guide_position + Vector2(minf(guide_size.x, 0.0), minf(guide_size.y, 0.0)), guide_size.abs())
		var foot := _actor_foot(slime)
		guide_reach = absf((guide_rect.position.x if combat != null and combat.face_left else guide_rect.end.x) - foot.x)
	var encounter_scale := _slime_encounter_scale(slime)
	return (guide_reach + slime_tuning.attack_lunge_distance) * encounter_scale + 0.75
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
func _on_player_health_changed(current: float, _maximum: float) -> void: if is_instance_valid(player_health_fill): _update_player_health_ui()
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
	var to_player := _actor_foot(player) - _actor_foot(slime)
	var direction := Vector2.LEFT if to_player.length_squared() < 0.01 and _slime_combat(slime).face_left else Vector2.RIGHT if to_player.length_squared() < 0.01 else to_player.normalized()
	direction = Vector2(direction.x, direction.y * 1.5).normalized()
	var contact_gap := actor_collision_system.actor_contact_radius(self, slime) + actor_collision_system.actor_contact_radius(self, player) + 0.5
	var max_lunge := slime_tuning.attack_lunge_distance * _slime_encounter_scale(slime)
	var lunge_distance := minf(max_lunge, maxf(to_player.length() - contact_gap, 0.0))
	if lunge_distance <= 0.01:
		return
	actor_collision_system.try_move_swept(slime, _perspective_movement(direction * lunge_distance), 0.75, Callable(self, "_can_actor_stand_at_current_position"), Callable(self, "_collides_with_static"))
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
		overlay.z_index = 1
		slime.add_child(overlay)
	var source := occlusion_renderer.original_actor_textures.get(slime, slime.texture) as Texture2D
	if source != null:
		overlay.texture = occlusion_renderer.white_texture(source)
	overlay.offset = slime.offset
	overlay.flip_h = slime.flip_h
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
		progression = player_profile.award_xp(reward, progression_tuning)
		_apply_profile_to_runtime()
	var levels_gained := int(progression.get("levels", 0))
	if levels_gained > 0:
		_spawn_player_level_number(player_profile.level if player_profile != null else 1)
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
func _build_rest_fire_frames() -> void: rest_fire_frames = sprite_frame_library.slice_frames("res://assets/artwork/Fire.png", FIRE_FRAME_SIZE); if not rest_fire_frames.is_empty(): _set_rest_fire_frame(0)
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
	if current_target != null and current_target != player and not _is_slime_dead(current_target):
		occlusion_actors.append(current_target)
	occlusion_renderer.update_actor_occlusion(occlusion_actors, occluder_sprites, player, current_target, delta, OCCLUSION_RELEASE_GRACE, Callable(self, "_is_actor_occlusion_flashing"), Callable(self, "_depth_key"), Callable(self, "_sprite_source_global_rect"), Callable(self, "_build_exact_occluded_actor_texture"), Callable(self, "_apply_actor_scale"), Callable(self, "_restore_actor_base_visual_scale"))
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
func _is_guard_input_held() -> bool: return player_controller.guard_held(_controller_devices(), CONTROLLER_TRIGGER_DEADZONE)
func _is_attack_input_pressed() -> bool: return player_controller.action_pressed(&"attack", _controller_devices(), JOY_BUTTON_X)
func _is_interact_input_pressed() -> bool: return player_controller.action_pressed(&"interact", _controller_devices(), JOY_BUTTON_B)
func _is_roll_input_pressed() -> bool: return player_controller.action_pressed(&"roll", _controller_devices(), JOY_BUTTON_A)
func _controller_devices() -> Array[int]: return player_controller.connected_devices()
func _closest_target() -> Sprite2D: return interaction_component.closest_target(player, slimes, TARGET_LOCK_MAX_DISTANCE, Callable(self, "_actor_foot"), Callable(self, "_is_slime_dead"), Callable(self, "_is_slime_targetable"))
func _set_current_target(target: Sprite2D) -> void:
	if current_target != target:
		current_target = target
		_combat_momentum().on_target_changed(target != null)
		_update_focus_indicator()
func _update_target_ui() -> void:
	if current_target == null: _set_target_ui_visible(false); return
	_set_target_ui_visible(true); target_health_bar_size = hud_controller.update_target_ui(current_target, target_name_text, target_health_bar, target_health_damage_fill, target_health_fill, target_health_text, target_health_bar_size, Callable(self, "_slime_display_name"), Callable(self, "_enemy_max_health"), Callable(self, "_slime_current_health"), Callable(self, "_slime_display_health"), Callable(self, "_pixel_name_texture"), Callable(self, "_pixel_text_texture"), Callable(hud_controller, "set_health_bar_values"))
func _set_target_ui_visible(target_visible: bool) -> void: hud_controller.set_visible(target_name_text, target_health_bar, target_health_damage_fill, target_health_fill, target_health_text, target_visible)
func _update_focus_indicator() -> void:
	if focus_label == null:
		return
	if current_target == null:
		focus_label.visible = false
		return
	focus_label.visible = true
	var momentum := _combat_momentum()
	var focus_color := Color8(255, 220, 120) if momentum.focus_active else Color8(200, 80, 80)
	focus_label.texture = _pixel_text_texture("FOCUS", focus_color)
	var name_width := (target_name_text.texture.get_size().x * 0.5 + 5.0) if target_name_text.texture != null else 16.0
	focus_label.position = target_name_text.position + Vector2(name_width, 0.0)
func _slime_display_name(slime: Sprite2D) -> String:
	var palette := String(slime.get("variant")); var display_name := "Blue Slime" if palette == "blue" else "Red Slime" if palette == "red" else "Rogue Slime" if palette == "purple" else "Green Slime"; var stats := _slime_stats(slime); return "lv.%d %s" % [stats.level if stats != null else 1, display_name]
func _update_player_health_ui(delta: float = 0.0) -> void: var result: Dictionary = hud_controller.update_player_health_ui(player_health_component.current_health if player_health_component != null else 0.0, player_display_health, player_damage_fill_hold_timer, delta, slime_tuning.health_regen_fill_speed, slime_tuning.health_drain_fill_speed, _player_max_health(), player_health_fill, player_health_damage_fill, player_health_fill_size, player_health_text, Callable(self, "_pixel_text_texture"), Callable(hud_controller, "set_health_bar_values")); player_display_health = result["display_health"]; player_damage_fill_hold_timer = result["damage_hold"]
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
func _restore_actor_base_visual_scale(actor: Sprite2D) -> void: if occlusion_renderer.original_actor_scales.has(actor): actor.scale = _actor_screen_scale(actor); actor.offset = _actor_visual_offset(actor)
func _actor_screen_scale(actor: Sprite2D) -> Vector2:
	var original_scale: Vector2 = occlusion_renderer.original_actor_scales.get(actor, Vector2.ONE)
	var visual_scale: Vector2 = occlusion_renderer.actor_visual_scales.get(actor, Vector2.ONE)
	return original_scale * visual_scale
func _slime_encounter_scale(slime: Sprite2D) -> float: return float(slime.get_meta("encounter_scale", 1.0))
func _actor_visual_offset(actor: Sprite2D) -> Vector2:
	if actor == player: return PLAYER_TEXTURE_OFFSET
	if slimes.has(actor):
		var encounter_scale := _slime_encounter_scale(actor)
		if encounter_scale > 1.0: return ACTOR_FOOT_OFFSET * (1.0 / encounter_scale - 1.0)
	return Vector2.ZERO
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
