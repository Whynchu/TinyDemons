extends Node
class_name SaveFlowController

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")


func build_title_screen(root: Object) -> void:
	var controls: Dictionary = root.screen_state_controller.build_title(root.ui, Callable(root, "_pixel_text_texture"), Callable(root, "_start_new_game"), Callable(root, "_continue_game"), root.has_persistent_profile, Callable(root, "_open_settings_from_title"))
	root.screen_state_controller.title_overlay = controls["overlay"] as ColorRect
	root.screen_state_controller.title_screen_text = controls["text"] as Sprite2D
	root.screen_state_controller.title_start_button = controls["new_game"] as Button
	root.screen_state_controller.title_continue_button = controls["continue"] as Button
	root.screen_state_controller.title_settings_button = controls["settings"] as Button
	root.screen_state_controller.title_start_text = controls["start_text"] as Sprite2D
	root.screen_state_controller.title_settings_text = controls["settings_text"] as Sprite2D
	root.screen_state_controller.title_cursor_text = controls["cursor"] as Sprite2D
	build_archetype_screen(root)
	var name_controls: Dictionary = root.screen_state_controller.build_name_entry(root.ui, Callable(root, "_pixel_text_texture"), Callable(root, "_finish_name_entry"), Callable(root, "_cancel_name_entry"), Callable(root, "_save_preview_texture"))
	root.screen_state_controller.name_entry_overlay = name_controls["overlay"] as ColorRect
	root.screen_state_controller.name_entry_prompt_text = name_controls["prompt"] as Sprite2D
	root.screen_state_controller.name_entry_name_text = name_controls["name"] as Sprite2D
	root.screen_state_controller.name_entry_page_text = name_controls["page"] as Sprite2D
	root.screen_state_controller.name_entry_message_text = name_controls["message"] as Sprite2D
	root.screen_state_controller.name_entry_actions_text = name_controls["actions"] as Sprite2D
	root.screen_state_controller.name_entry_confirm_text = name_controls["confirm"] as Sprite2D
	root.screen_state_controller.name_entry_back_text = name_controls["back"] as Sprite2D
	root.screen_state_controller.name_entry_cursor_text = name_controls["cursor"] as Sprite2D
	root.screen_state_controller.name_entry_preview = name_controls["preview"] as Sprite2D
	root.screen_state_controller.name_entry_cell_buttons = name_controls["cells"] as Array[Button]


func build_archetype_screen(root: Object) -> void:
	var controls: Dictionary = root.screen_state_controller.build_archetype(root.ui, Callable(root, "_shift_archetype"), Callable(root, "_shift_archetype_color"), Callable(root, "_start_selected_archetype"), Callable(root, "_pixel_text_texture"))
	root.screen_state_controller.archetype_overlay = controls["overlay"] as ColorRect
	root.screen_state_controller.archetype_preview = controls["preview"] as Sprite2D
	root.screen_state_controller.archetype_name_text = controls["name"] as Sprite2D
	root.screen_state_controller.archetype_left_buttons = controls["left"] as Array[Button]
	root.screen_state_controller.archetype_right_buttons = controls["right"] as Array[Button]
	root.screen_state_controller.archetype_type_left_button = controls["type_left"] as Button
	root.screen_state_controller.archetype_type_right_button = controls["type_right"] as Button
	root.screen_state_controller.archetype_start_button = controls["start"] as Button
	root.screen_state_controller.archetype_hold_cover = controls["cover"] as ColorRect
	update_archetype_screen(root)


func update_title_screen(root: Object, delta: float) -> void:
	root.screen_state_controller.update_title_flow(root, delta)


func start_new_game(root: Object) -> void:
	root.screen_state_controller.start_save_select(root, "new")


func continue_game(root: Object) -> void:
	root.screen_state_controller.start_save_select(root, "continue")


func open_save_select_after_title_transition(root: Object) -> void:
	if root.screen_state_controller.save_select_overlay == null:
		root.screen_state_controller.save_select_overlay = root.screen_state_controller.build_save_select(root.ui, Callable(root, "_pixel_text_texture"), Callable(root, "_select_save_slot"), Callable(root, "_confirm_overwrite"), Callable(root, "_cancel_overwrite"), Callable(root, "_save_preview_texture"))
	root.screen_state_controller.save_select_index = 0
	root.screen_state_controller.menu_input_release_lock = true
	# Keep the opaque title cover behind the save menu so the gameplay scene is
	# never exposed between the title transition and save selection.
	if root.screen_state_controller.title_overlay != null:
		root.screen_state_controller.title_overlay.visible = true
		root.screen_state_controller.title_overlay.modulate.a = 1.0
	root.screen_state_controller.save_select_overlay.visible = true
	update_save_select_cursor(root)


func update_save_select_cursor(root: Object) -> void:
	if root.screen_state_controller.save_select_overlay == null: return
	for child in root.screen_state_controller.save_select_overlay.get_children():
		if child is Button and child.has_meta("save_slot") and int(child.get_meta("save_slot")) == root.screen_state_controller.save_select_index:
			(child as Button).release_focus()
	var cursor := root.screen_state_controller.save_select_overlay.get_node_or_null("SaveSelectCursor") as Sprite2D
	if cursor != null:
		var display := root.get("display_controller") as DisplayController
		var view_width := float(display.view_size_value().x) if display != null else 240.0
		cursor.position = Vector2((view_width - 130.0) * 0.5, 70 + root.screen_state_controller.save_select_index * 20)


func save_preview_texture(root: Object, palette_name: String) -> Texture2D:
	if root.player_animation_component == null:
		return null
	var base_frames: Array[Texture2D] = root.player_animation_component.base_idle_frames
	if base_frames.is_empty():
		return null
	return root.player_animation_component.recolor_texture(base_frames[0], palette_name)


func select_save_slot(root: Object, slot: int) -> void:
	root.screen_state_controller.save_select_index = clampi(slot, 0, ProfileSaveService.SLOT_COUNT - 1)
	update_save_select_cursor(root)
	if root.screen_state_controller.save_select_mode == "continue":
		select_continue_slot(root, slot)
		return
	if ProfileSaveService.slot_has_profile(slot):
		root.screen_state_controller.save_overwrite_slot = slot
		set_overwrite_prompt(root, true)
		return
	root.screen_state_controller.save_overwrite_slot = slot
	confirm_overwrite(root)


func set_overwrite_prompt(root: Object, active: bool) -> void:
	root.screen_state_controller.save_overwrite_prompt_active = active
	root.screen_state_controller.save_overwrite_choice = 0
	root.screen_state_controller.menu_input_release_lock = active
	for node_name in ["OverwritePrompt", "OverwriteYes", "OverwriteNo"]:
		var node: CanvasItem = root.screen_state_controller.save_select_overlay.get_node_or_null(node_name) as CanvasItem
		if node != null: node.visible = active
	var cursor := root.screen_state_controller.save_select_overlay.get_node_or_null("OverwriteCursor") as Sprite2D
	if cursor != null:
		cursor.visible = active
		var display := root.get("display_controller") as DisplayController
		var view_width := float(display.view_size_value().x) if display != null else 240.0
		cursor.position = Vector2((view_width - 42.0) * 0.5, 140)


func cancel_overwrite(root: Object) -> void:
	root.screen_state_controller.save_overwrite_prompt_active = false
	set_overwrite_prompt(root, false)
	update_save_select_cursor(root)


func confirm_overwrite(root: Object) -> void:
	root.screen_state_controller.save_overwrite_prompt_active = false
	set_overwrite_prompt(root, false)
	var selected_slot: int = int(root.screen_state_controller.save_overwrite_slot if ProfileSaveService.slot_has_profile(root.screen_state_controller.save_overwrite_slot) else root.screen_state_controller.save_select_index)
	ProfileSaveService.select_slot(selected_slot)
	if root.screen_state_controller.save_select_overlay != null: root.screen_state_controller.save_select_overlay.visible = false
	# Keep the old profile on disk and in memory until the player confirms a
	# name. This makes BACK from the name screen safe even when the selected slot
	# is an overwrite of an existing file.
	root.screen_state_controller.show_name_entry(root, selected_slot)


func finish_name_entry(root: Object, player_name: String) -> void:
	var selected_slot: int = int(root.screen_state_controller.name_entry_pending_slot)
	if selected_slot < 0:
		return
	ProfileSaveService.select_slot(selected_slot)
	ProfileSaveService.clear_slot(selected_slot)
	root.player_profile = PlayerProfile.new()
	root.player_profile.player_name = PlayerProfile.normalize_player_name(player_name)
	reset_runtime_for_new_save(root)
	root.has_persistent_profile = false
	root.call("_apply_profile_to_runtime")
	root.call("_update_gold_indicator")
	root.call("_update_soul_indicator")
	if root.screen_state_controller.name_entry_overlay != null:
		root.screen_state_controller.name_entry_overlay.visible = false
	root.screen_state_controller.name_entry_owner = null
	root.screen_state_controller.name_entry_pending_slot = -1
	root.screen_state_controller.show_character_creation(root)


func reset_runtime_for_new_save(root: Object) -> void:
	# New slots must not inherit the previous profile's run rank, grade-weighted
	# loot state, dungeon topology, or in-progress telemetry.
	root.player_profile.completed_runs = 0
	root.player_profile.last_clear_score = 0
	root.player_profile.difficulty_rank = 1
	root.player_profile.last_run_grade = "D"
	root.run_start_palette_name = root.player_profile.hub_palette()
	root.player_profile.pending_route = "title"
	root.player_profile.open_hub_on_load = false
	if root.run_state != null:
		root.run_state = RunState.new()
	var random_source: RandomNumberGenerator = root.rng if root.rng != null else RandomNumberGenerator.new()
	if root.rng == null:
		random_source.randomize()
	root.current_dungeon_seed = random_source.randi()
	root.room_controller.room_states.clear()
	if root.dungeon_map_controller != null:
		var start_room_id: StringName = StringName(root.dungeon_map_controller.call("begin_run", root.dungeon_graph, root.current_dungeon_seed, 0, root.player_profile.starter_flame, root.player_profile.bound_element if root.player_profile.has_bound_element else &""))
		root.dungeon_minimap_controller.call("configure", root.dungeon_map_controller)
		root.current_room_id = start_room_id
	else:
		root.dungeon_graph.configure_progression(0)
		root.dungeon_graph.initialize(root.current_dungeon_seed)
		root.current_room_id = root.dungeon_graph.start_room_id
	root.room_controller.progression_run_rank = 1
	root.call("_sync_current_room_metadata")
	root.room_controller.set_current_room(root.current_room_id, root.current_room_type)
	root.call("_ensure_current_room_layout")
	root.call("_apply_room_state")
	root.call("_update_room_number_indicator")


func update_overwrite_cursor(root: Object) -> void:
	var cursor := root.screen_state_controller.save_select_overlay.get_node_or_null("OverwriteCursor") as Sprite2D
	if cursor != null:
		var display := root.get("display_controller") as DisplayController
		var view_width := float(display.view_size_value().x) if display != null else 240.0
		var base_x := (view_width - 42.0) * 0.5
		cursor.position = Vector2(base_x if root.screen_state_controller.save_overwrite_choice == 0 else base_x + 30.0, 140)


func close_save_select(root: Object) -> void:
	if root.screen_state_controller.save_select_overlay != null: root.screen_state_controller.save_select_overlay.visible = false
	root.screen_state_controller.menu_input_release_lock = false
	if root.screen_state_controller.title_overlay != null:
		root.screen_state_controller.title_overlay.visible = true
		root.screen_state_controller.title_overlay.modulate.a = 1.0
	if root.screen_state_controller.title_screen_text != null: root.screen_state_controller.title_screen_text.visible = true
	if root.screen_state_controller.title_start_text != null: root.screen_state_controller.title_start_text.visible = true
	if root.screen_state_controller.title_start_button != null: root.screen_state_controller.title_start_button.visible = true
	if root.screen_state_controller.title_continue_button != null: root.screen_state_controller.title_continue_button.visible = not root.screen_state_controller.title_continue_button.disabled
	if root.screen_state_controller.title_settings_button != null: root.screen_state_controller.title_settings_button.visible = true
	if root.screen_state_controller.title_cursor_text != null: root.screen_state_controller.title_cursor_text.visible = true
	root.screen_state_controller.title_transition_active = false
	root.screen_state_controller.pending_title_destination = ""
	root.screen_state_controller.set_state(&"title")
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func cancel_character_creation(root: Object) -> void:
	root.call("_play_sound", "ui_decline", 0.0, 1.0)
	if root.screen_state_controller.archetype_overlay != null: root.screen_state_controller.archetype_overlay.visible = false
	if root.screen_state_controller.title_overlay != null:
		root.screen_state_controller.title_overlay.visible = true
		root.screen_state_controller.title_overlay.modulate.a = 1.0
	if root.screen_state_controller.title_screen_text != null: root.screen_state_controller.title_screen_text.visible = true
	if root.screen_state_controller.title_start_text != null: root.screen_state_controller.title_start_text.visible = true
	if root.screen_state_controller.title_start_button != null: root.screen_state_controller.title_start_button.visible = true
	if root.screen_state_controller.title_continue_button != null: root.screen_state_controller.title_continue_button.visible = not root.screen_state_controller.title_continue_button.disabled
	if root.screen_state_controller.title_settings_button != null: root.screen_state_controller.title_settings_button.visible = true
	if root.screen_state_controller.title_cursor_text != null: root.screen_state_controller.title_cursor_text.visible = true
	root.screen_state_controller.title_transition_active = false
	root.screen_state_controller.pending_title_destination = ""
	root.screen_state_controller.set_state(&"title")


func select_continue_slot(root: Object, slot: int) -> void:
	if not ProfileSaveService.slot_has_profile(slot): return
	ProfileSaveService.select_slot(slot)
	root.player_profile = ProfileSaveService.load_profile()
	if not root.player_profile.has_started: return
	root.player_profile.pending_route = "run"
	ProfileSaveService.save_profile(root.player_profile)
	if root.screen_state_controller.save_select_overlay != null: root.screen_state_controller.save_select_overlay.visible = false
	root.call("_begin_scene_transition")


func enter_starting_room_from_menu(root: Object) -> void:
	if root.screen_state_controller.title_overlay != null: root.screen_state_controller.title_overlay.visible = false
	if root.screen_state_controller.archetype_overlay != null: root.screen_state_controller.archetype_overlay.visible = false
	if root.screen_state_controller.hub_overlay != null: root.screen_state_controller.hub_overlay.visible = false
	root.player.visible = false
	if root.player_shadow != null: root.player_shadow.visible = false
	if root.player_sprite_shadow != null: root.player_sprite_shadow.visible = false
	if root.player_attack_visual != null: root.player_attack_visual.visible = false
	root.loading_screen_active = true
	root.loading_screen_fading = false
	root.loading_screen_timer = 0.0
	root.loading_screen_overlay.visible = true
	root.loading_screen_overlay.modulate.a = 1.0
	root.screen_state_controller.set_state(&"loading")
	await root.get_tree().process_frame
	root.call("_place_player_at_hub_fire")
	root.call("_apply_player_palette_async", root.screen_state_controller.player_palette_name)
	root.call("_update_player_aggro_marker_colors")
	var maximum_health: float = float(root.call("_player_max_health"))
	if root.player_health_component != null:
		root.player_health_component.maximum_health = maximum_health
		root.player_health_component.reset(maximum_health)
	root.player_display_health = maximum_health
	root.player_animation_component.apply_frame(root)
	root.call("_update_player_shadow")
	root.call("_build_depth_lists")
	root.player.visible = true
	root.call("_update_player_shadow")
	root.call("_build_depth_lists")
	root.call("_begin_new_run")
	root.loading_screen_fading = true
	root.loading_screen_timer = 0.0


func place_player_at_hub_fire(root: Object) -> void:
	if root.rest_fire == null: return
	var requested_foot: Vector2 = root.rest_fire.global_position + Vector2(-14.0, 3.0)
	var valid_foot: Vector2 = root.call("_nearest_slime_walkable_point", requested_foot)
	root.player.global_position = valid_foot - root.ACTOR_FOOT_OFFSET


func update_archetype_input(root: Object, delta: float) -> void:
	root.screen_state_controller.update_archetype_input(root, delta)


func shift_archetype(root: Object, direction: int) -> void:
	root.screen_state_controller.starter_flame_index = posmod(root.screen_state_controller.starter_flame_index + direction, AspectCatalogScript.STARTER_FLAMES.size())
	root.screen_state_controller.archetype_index = root.screen_state_controller.starter_flame_index
	root.call("_archetype_arrow_pulse", direction)
	root.call("_update_archetype_screen")


func shift_archetype_color(root: Object, direction: int) -> void:
	root.screen_state_controller.archetype_color_index = posmod(root.screen_state_controller.archetype_color_index + direction, PaletteLibrary.SELECTABLE_PALETTES.size())
	root.call("_archetype_arrow_pulse", direction)
	root.call("_update_archetype_screen")


func archetype_arrow_pulse(root: Object, direction: int) -> void:
	root.screen_state_controller.archetype_arrow_anim_direction = direction
	root.screen_state_controller.archetype_arrow_anim_timer = 0.18


func update_archetype_arrow_animation(root: Object) -> void:
	var amount: float = clampf(root.screen_state_controller.archetype_arrow_anim_timer / 0.18, 0.0, 1.0)
	var pulse: float = 1.0 + amount * 0.22
	root.screen_state_controller.archetype_type_left_button.scale = Vector2.ONE * (pulse if root.screen_state_controller.archetype_arrow_anim_direction < 0 and root.screen_state_controller.archetype_menu_row == 0 else 1.0)
	root.screen_state_controller.archetype_type_right_button.scale = Vector2.ONE * (pulse if root.screen_state_controller.archetype_arrow_anim_direction > 0 and root.screen_state_controller.archetype_menu_row == 0 else 1.0)
	for button in root.screen_state_controller.archetype_left_buttons: button.scale = Vector2.ONE * (pulse if root.screen_state_controller.archetype_arrow_anim_direction < 0 and root.screen_state_controller.archetype_menu_row == 1 else 1.0)
	for right_button in root.screen_state_controller.archetype_right_buttons: right_button.scale = Vector2.ONE * (pulse if root.screen_state_controller.archetype_arrow_anim_direction > 0 and root.screen_state_controller.archetype_menu_row == 1 else 1.0)


func select_archetype_menu_row(root: Object, row: int) -> void:
	root.screen_state_controller.archetype_menu_row = posmod(row, 2)
	root.call("_update_archetype_screen")


func update_archetype_screen(root: Object) -> void:
	var display := root.get("display_controller") as DisplayController
	var view_width := float(display.view_size_value().x) if display != null else 240.0
	var flame: StringName = AspectCatalogScript.STARTER_FLAMES[root.screen_state_controller.starter_flame_index]
	var flame_name: String = AspectCatalogScript.display_name(flame)
	var flame_palette: String = AspectCatalogScript.palette_for_flame(flame)
	root.screen_state_controller.archetype_name_text.texture = root.call("_pixel_text_texture", flame_name, PaletteLibrary.normal(flame_palette) if root.screen_state_controller.archetype_menu_row == 0 else Color.WHITE)
	root.screen_state_controller.archetype_name_text.position = Vector2((view_width - root.screen_state_controller.archetype_name_text.texture.get_width()) * 0.5, 36)
	var colors: Array[String] = [flame_palette]
	if not root.player_animation_component.idle_frames.is_empty():
		if root.screen_state_controller.archetype_preview_palette != colors[0] or root.screen_state_controller.archetype_preview_frames.size() != root.player_animation_component.idle_frames.size():
			root.screen_state_controller.archetype_preview_frames.clear()
			root.screen_state_controller.archetype_preview_palette = colors[0]
			for frame in root.player_animation_component.idle_frames: root.screen_state_controller.archetype_preview_frames.append(root.player_animation_component.recolor_texture(frame, root.screen_state_controller.archetype_preview_palette))
		update_archetype_preview_animation(root)
	root.call("_update_archetype_button_styles")


func update_archetype_preview_animation(root: Object) -> void:
	if root.screen_state_controller.archetype_preview == null or root.screen_state_controller.archetype_preview_frames.is_empty(): return
	var frame_time: float = maxf(root.player_tuning.idle_frame_time, 0.01)
	var frame_index: int = posmod(int(root.screen_state_controller.archetype_frame_timer / frame_time), root.screen_state_controller.archetype_preview_frames.size())
	root.screen_state_controller.archetype_preview.texture = root.screen_state_controller.archetype_preview_frames[frame_index]
	var display := root.get("display_controller") as DisplayController
	var view_width := float(display.view_size_value().x) if display != null else 240.0
	root.screen_state_controller.archetype_preview.position = Vector2((view_width - root.screen_state_controller.archetype_preview.texture.get_width() * root.screen_state_controller.archetype_preview.scale.x) * 0.5, 48)


func update_archetype_button_styles(root: Object) -> void:
	root.screen_state_controller.update_archetype_button_styles(root)


func start_selected_archetype(root: Object) -> void:
	root.screen_state_controller.start_selected_archetype(root)


func build_loading_screen(root: Object) -> void:
	var controls: Dictionary = root.screen_state_controller.build_loading(root.ui, Callable(root, "_pixel_text_texture"))
	root.loading_screen_overlay = controls["overlay"] as ColorRect
	root.loading_screen_text = controls["text"] as Sprite2D


func update_loading_screen(root: Object, delta: float) -> void:
	var result: Dictionary = root.screen_state_controller.update_loading(root.loading_screen_overlay, root.loading_screen_text, root.loading_screen_fading, root.loading_screen_timer, delta, Callable(root, "_pixel_text_texture"))
	root.loading_screen_fading = result["fading"]
	root.loading_screen_timer = result["timer"]
	if result["finished"]: root.loading_screen_active = false
