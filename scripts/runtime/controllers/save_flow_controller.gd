extends Node
class_name SaveFlowController

const AspectCatalogScript = preload("res://scripts/content/aspect_catalog.gd")
const ActiveRunSaveServiceScript = preload("res://scripts/runtime/services/active_run_save_service.gd")


func build_title_screen(root: Object) -> void:
	root.screen_state_controller.assembly_controller.build_title(root.ui, Callable(root, "_pixel_text_texture"), Callable(root, "_start_new_game"), Callable(root, "_continue_game"), root.has_persistent_profile, Callable(root, "_open_settings_from_title"), Callable(root, "_open_cloud_save"))
	root.screen_state_controller.refresh_title_menu_layout(root.has_persistent_profile)
	var enters_saved_route: bool = root.player_profile != null and root.player_profile.has_started and (root.player_profile.pending_route == "hub" or root.player_profile.pending_route == "run")
	if enters_saved_route and root.screen_state_controller.title_presenter.overlay != null:
		# Full-run boot still constructs the shared title assets, but the title must
		# never become visible during the yielded loading phases before gameplay.
		root.screen_state_controller.title_presenter.overlay.visible = false
	build_archetype_screen(root)
	root.screen_state_controller.assembly_controller.build_name_entry(root.ui, Callable(root, "_pixel_text_texture"), Callable(root, "_finish_name_entry"), Callable(root, "_cancel_name_entry"), Callable(root, "_save_preview_texture"))


func build_archetype_screen(root: Object) -> void:
	root.screen_state_controller.assembly_controller.build_archetype(root.ui, Callable(root, "_shift_archetype"), Callable(root, "_shift_archetype_color"), Callable(root, "_start_selected_archetype"), Callable(root, "_pixel_text_texture"))
	root.screen_state_controller.state_flow_controller.update_archetype_screen(root)


func update_title_screen(root: Object, delta: float) -> void:
	root.screen_state_controller.state_flow_controller.update_title_flow(root, delta)


func start_new_game(root: Object) -> void:
	root.screen_state_controller.state_flow_controller.start_save_select(root, "new")


func continue_game(root: Object) -> void:
	root.screen_state_controller.state_flow_controller.start_save_select(root, "continue")


func open_save_select_after_title_transition(root: Object) -> void:
	if root.screen_state_controller.save_select_presenter.overlay == null:
		root.screen_state_controller.save_select_presenter.overlay = root.screen_state_controller.assembly_controller.build_save_select(root.ui, Callable(root, "_pixel_text_texture"), Callable(root, "_select_save_slot"), Callable(root, "_confirm_overwrite"), Callable(root, "_save_overwrite_no"), Callable(root, "_save_portrait_texture"), Callable(root, "_close_save_select"))
	root.screen_state_controller.save_select_index = 0
	root.screen_state_controller.menu_input_release_lock = true
	# Keep the opaque title cover behind the save menu so the gameplay scene is
	# never exposed between the title transition and save selection.
	if root.screen_state_controller.title_presenter.overlay != null:
		root.screen_state_controller.title_presenter.overlay.visible = true
		root.screen_state_controller.title_presenter.overlay.modulate.a = 1.0
	root.screen_state_controller.save_select_presenter.overlay.visible = true
	update_save_select_cursor(root)


func update_save_select_cursor(root: Object) -> void:
	if root.screen_state_controller.save_select_presenter.overlay == null: return
	for child in root.screen_state_controller.save_select_presenter.overlay.get_children():
		if child is Button and child.has_meta("save_slot") and int(child.get_meta("save_slot")) == root.screen_state_controller.save_select_index:
			(child as Button).release_focus()
	var cursor := root.screen_state_controller.save_select_presenter.overlay.get_node_or_null("SaveSelectCursor") as Sprite2D
	if cursor != null:
		var display := root.get("display_controller") as DisplayController
		var view_width := float(display.view_size_value().x) if display != null else 240.0
		root.screen_state_controller._menu_cursor_animator.move_menu_cursor(cursor, Vector2((view_width - 130.0) * 0.5 - root.screen_state_controller.CURSOR_LEFT_GAP, 70 + root.screen_state_controller.save_select_index * 20), true, root)


func save_preview_texture(root: Object, palette_name: String) -> Texture2D:
	if root.player_animation_component == null:
		return null
	var palette_frames: Dictionary = root.player_animation_component.frames_by_palette.get(palette_name, {}) as Dictionary
	var baked_idle_frames: Array[Texture2D] = []
	var idle_value: Variant = palette_frames.get("idle")
	if idle_value is Array:
		for frame: Texture2D in idle_value:
			baked_idle_frames.append(frame)
	if not baked_idle_frames.is_empty():
		# Save/name previews must use the same pre-rendered palette frames as
		# character creation; recoloring the blue source would restore old eyes.
		return baked_idle_frames[0]
	var base_frames: Array[Texture2D] = root.player_animation_component.base_idle_frames
	if base_frames.is_empty():
		return null
	return root.player_animation_component.recolor_texture(base_frames[0], palette_name)


func save_portrait_texture(root: Object, palette_name: String, cloaked := false) -> Texture2D:
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary
	if library == null:
		return null
	var source_path := "res://assets/artwork/player_cloaked_UI_portrait.png" if cloaked else "res://assets/artwork/player_UI_portrait.png"
	var source := load(source_path) as Texture2D
	return library.recolor_cloaked_portrait_texture(source, palette_name) if cloaked else library.recolor_portrait_texture(source, palette_name)


func select_save_slot(root: Object, slot: int) -> void:
	root.screen_state_controller.save_select_index = clampi(slot, 0, ProfileSaveService.SLOT_COUNT - 1)
	update_save_select_cursor(root)
	if root.screen_state_controller.save_select_mode == "continue":
		select_continue_slot(root, slot)
		return
	if ProfileSaveService.slot_has_profile(slot):
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		root.screen_state_controller.save_overwrite_slot = slot
		set_overwrite_prompt(root, true)
		return
	root.screen_state_controller.save_overwrite_slot = slot
	confirm_overwrite(root)


func set_overwrite_prompt(root: Object, active: bool) -> void:
	root.screen_state_controller.save_overwrite_prompt_active = active
	root.screen_state_controller.save_recovery_prompt_active = false
	root.screen_state_controller.save_overwrite_choice = 0
	root.screen_state_controller.menu_input_release_lock = active
	for node_name in ["OverwritePrompt", "OverwriteYes", "OverwriteNo"]:
		var node: CanvasItem = root.screen_state_controller.save_select_presenter.overlay.get_node_or_null(node_name) as CanvasItem
		if node != null: node.visible = active
	for node_name in ["SaveNavBack"]:
		var nav := root.screen_state_controller.save_select_presenter.overlay.get_node_or_null(node_name) as CanvasItem
		if nav != null: nav.visible = not active
	var cursor := root.screen_state_controller.save_select_presenter.overlay.get_node_or_null("OverwriteCursor") as Sprite2D
	if cursor != null:
		cursor.visible = active
		var display := root.get("display_controller") as DisplayController
		var view_width := float(display.view_size_value().x) if display != null else 240.0
		root.screen_state_controller._menu_cursor_animator.move_menu_cursor(cursor, Vector2((view_width - 42.0) * 0.5 - root.screen_state_controller.CURSOR_LEFT_GAP, 140), true, root)
	var prompt := root.screen_state_controller.save_select_presenter.overlay.get_node_or_null("OverwritePrompt") as Sprite2D
	if prompt != null:
		prompt.texture = root.call("_pixel_text_texture", "OVERWRITE?  YES / NO", Color.WHITE)


func set_recovery_prompt(root: Object, active: bool) -> void:
	root.screen_state_controller.save_overwrite_prompt_active = active
	root.screen_state_controller.save_recovery_prompt_active = active
	root.screen_state_controller.save_overwrite_choice = 0
	root.screen_state_controller.menu_input_release_lock = active
	for node_name in ["OverwritePrompt", "OverwriteYes", "OverwriteNo"]:
		var node: CanvasItem = root.screen_state_controller.save_select_presenter.overlay.get_node_or_null(node_name) as CanvasItem
		if node != null: node.visible = active
	var nav := root.screen_state_controller.save_select_presenter.overlay.get_node_or_null("SaveNavBack") as CanvasItem
	if nav != null: nav.visible = not active
	var cursor := root.screen_state_controller.save_select_presenter.overlay.get_node_or_null("OverwriteCursor") as Sprite2D
	if cursor != null:
		cursor.visible = active
		var display := root.get("display_controller") as DisplayController
		var view_width := float(display.view_size_value().x) if display != null else 240.0
		root.screen_state_controller._menu_cursor_animator.move_menu_cursor(cursor, Vector2((view_width - 42.0) * 0.5 - root.screen_state_controller.CURSOR_LEFT_GAP, 140), true, root)
	var prompt := root.screen_state_controller.save_select_presenter.overlay.get_node_or_null("OverwritePrompt") as Sprite2D
	if prompt != null:
		prompt.texture = root.call("_pixel_text_texture", "RESUME RUN?  YES / NO", Color.WHITE)


func cancel_overwrite(root: Object) -> void:
	if root.screen_state_controller.save_recovery_prompt_active:
		root.screen_state_controller.save_recovery_prompt_active = false
		root.screen_state_controller.save_overwrite_prompt_active = false
		set_recovery_prompt(root, false)
		update_save_select_cursor(root)
		root.call("_play_sound", "ui_decline", 0.0, 1.0)
		return
	root.screen_state_controller.save_overwrite_prompt_active = false
	set_overwrite_prompt(root, false)
	update_save_select_cursor(root)
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func confirm_overwrite(root: Object) -> void:
	if root.screen_state_controller.save_recovery_prompt_active:
		if root.screen_state_controller.save_overwrite_choice == 0:
			confirm_recovery_resume(root)
		else:
			confirm_recovery_discard(root)
		return
	root.screen_state_controller.save_overwrite_prompt_active = false
	set_overwrite_prompt(root, false)
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	var selected_slot: int = int(root.screen_state_controller.save_overwrite_slot if ProfileSaveService.slot_has_profile(root.screen_state_controller.save_overwrite_slot) else root.screen_state_controller.save_select_index)
	ProfileSaveService.select_slot(selected_slot)
	if root.screen_state_controller.save_select_presenter.overlay != null: root.screen_state_controller.save_select_presenter.overlay.visible = false
	# Keep the old profile on disk and in memory until the player confirms a
	# name. This makes BACK from the name screen safe even when the selected slot
	# is an overwrite of an existing file.
	root.screen_state_controller.show_name_entry(root, selected_slot)


func finish_name_entry(root: Object, player_name: String) -> void:
	var selected_slot: int = root.screen_state_controller.name_entry_controller.pending_name_slot()
	if selected_slot < 0:
		return
	ProfileSaveService.select_slot(selected_slot)
	ProfileSaveService.clear_slot(selected_slot)
	ActiveRunSaveServiceScript.clear_snapshot(selected_slot)
	root.player_profile = PlayerProfile.new()
	root.player_profile.player_name = PlayerProfile.normalize_player_name(player_name)
	reset_runtime_for_new_save(root)
	root.has_persistent_profile = false
	root.call("_apply_profile_to_runtime")
	root.call("_update_gold_indicator")
	root.call("_update_soul_indicator")
	root.screen_state_controller.name_entry_controller.complete()
	root.screen_state_controller.state_flow_controller.show_character_creation(root)


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
	var cursor := root.screen_state_controller.save_select_presenter.overlay.get_node_or_null("OverwriteCursor") as Sprite2D
	if cursor != null:
		var display := root.get("display_controller") as DisplayController
		var view_width := float(display.view_size_value().x) if display != null else 240.0
		var base_x := (view_width - 42.0) * 0.5
		var gap: float = root.screen_state_controller.CURSOR_LEFT_GAP
		root.screen_state_controller._menu_cursor_animator.move_menu_cursor(cursor, Vector2((base_x if root.screen_state_controller.save_overwrite_choice == 0 else base_x + 30.0) - gap, 140), true, root)


func close_save_select(root: Object) -> void:
	if root.screen_state_controller.save_select_presenter.overlay != null: root.screen_state_controller.save_select_presenter.overlay.visible = false
	root.screen_state_controller.menu_input_release_lock = false
	if root.screen_state_controller.title_presenter.overlay != null:
		root.screen_state_controller.title_presenter.overlay.visible = true
		root.screen_state_controller.title_presenter.overlay.modulate.a = 1.0
	if root.screen_state_controller.title_presenter.title_text != null: root.screen_state_controller.title_presenter.title_text.visible = true
	var title_version: Sprite2D = root.screen_state_controller.title_presenter.overlay.get_node_or_null("TitleVersion") as Sprite2D if root.screen_state_controller.title_presenter.overlay != null else null
	if title_version != null: title_version.visible = true
	if root.screen_state_controller.title_presenter.start_text != null: root.screen_state_controller.title_presenter.start_text.visible = true
	if root.screen_state_controller.title_presenter.start_button != null: root.screen_state_controller.title_presenter.start_button.visible = true
	if root.screen_state_controller.title_presenter.continue_button != null: root.screen_state_controller.title_presenter.continue_button.visible = not root.screen_state_controller.title_presenter.continue_button.disabled
	if root.screen_state_controller.title_presenter.settings_button != null: root.screen_state_controller.title_presenter.settings_button.visible = true
	if root.screen_state_controller.title_presenter.cloud_button != null: root.screen_state_controller.title_presenter.cloud_button.visible = true
	if root.screen_state_controller.title_presenter.cursor_text != null: root.screen_state_controller.title_presenter.cursor_text.visible = true
	root.screen_state_controller.title_presenter.transition_active = false
	root.screen_state_controller.title_presenter.pending_destination = ""
	root.screen_state_controller.set_state(&"title")
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func cancel_character_creation(root: Object) -> void:
	root.call("_play_sound", "ui_decline", 0.0, 1.0)
	if root.screen_state_controller.archetype_presenter.overlay != null: root.screen_state_controller.archetype_presenter.overlay.visible = false
	if root.screen_state_controller.title_presenter.overlay != null:
		root.screen_state_controller.title_presenter.overlay.visible = true
		root.screen_state_controller.title_presenter.overlay.modulate.a = 1.0
	if root.screen_state_controller.title_presenter.title_text != null: root.screen_state_controller.title_presenter.title_text.visible = true
	var title_version: Sprite2D = root.screen_state_controller.title_presenter.overlay.get_node_or_null("TitleVersion") as Sprite2D if root.screen_state_controller.title_presenter.overlay != null else null
	if title_version != null: title_version.visible = true
	if root.screen_state_controller.title_presenter.start_text != null: root.screen_state_controller.title_presenter.start_text.visible = true
	if root.screen_state_controller.title_presenter.start_button != null: root.screen_state_controller.title_presenter.start_button.visible = true
	if root.screen_state_controller.title_presenter.continue_button != null: root.screen_state_controller.title_presenter.continue_button.visible = not root.screen_state_controller.title_presenter.continue_button.disabled
	if root.screen_state_controller.title_presenter.settings_button != null: root.screen_state_controller.title_presenter.settings_button.visible = true
	if root.screen_state_controller.title_presenter.cloud_button != null: root.screen_state_controller.title_presenter.cloud_button.visible = true
	if root.screen_state_controller.title_presenter.cursor_text != null: root.screen_state_controller.title_presenter.cursor_text.visible = true
	root.screen_state_controller.title_presenter.transition_active = false
	root.screen_state_controller.title_presenter.pending_destination = ""
	root.screen_state_controller.set_state(&"title")


func select_continue_slot(root: Object, slot: int) -> void:
	if not ProfileSaveService.slot_has_profile(slot):
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	ProfileSaveService.select_slot(slot)
	var loaded_profile := ProfileSaveService.load_profile()
	if loaded_profile == null or not loaded_profile.has_started:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	if ActiveRunSaveServiceScript.has_valid_snapshot(slot):
		root.screen_state_controller.save_overwrite_slot = slot
		set_recovery_prompt(root, true)
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		return
	_load_continue_slot(root, slot, loaded_profile)


func confirm_recovery_resume(root: Object) -> void:
	var slot: int = int(root.screen_state_controller.save_overwrite_slot)
	var loaded_profile := ProfileSaveService.load_profile_for_slot(slot)
	if loaded_profile == null or not loaded_profile.has_started:
		set_recovery_prompt(root, false)
		return
	set_recovery_prompt(root, false)
	_load_continue_slot(root, slot, loaded_profile)


func confirm_recovery_discard(root: Object) -> void:
	var slot: int = int(root.screen_state_controller.save_overwrite_slot)
	ActiveRunSaveServiceScript.clear_snapshot(slot)
	set_recovery_prompt(root, false)
	_load_continue_slot(root, slot, ProfileSaveService.load_profile_for_slot(slot))


func _load_continue_slot(root: Object, slot: int, loaded_profile: PlayerProfile) -> void:
	if loaded_profile == null or not loaded_profile.has_started:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	root.player_profile = loaded_profile
	root.player_profile.pending_route = "run"
	root.pending_run_restore = ActiveRunSaveServiceScript.has_valid_snapshot(slot)
	ProfileSaveService.request_next_boot_route("run")
	ProfileSaveService.save_profile(root.player_profile)
	if root.screen_state_controller.save_select_presenter.overlay != null: root.screen_state_controller.save_select_presenter.overlay.visible = false
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	root.call("_begin_scene_transition")


func enter_starting_room_from_menu(root: GameplayState) -> void:
	# A title-only boot skips gameplay components to keep startup light. A newly
	# created profile must reload through the saved run route before entering the
	# room, just like Continue, so bootstrap creates Motor and hides editor guides.
	if root.player_motor == null:
		if root.player_profile != null:
			root.player_profile.pending_route = "run"
			root.player_profile.open_hub_on_load = false
			ProfileSaveService.request_next_boot_route("run")
			root._save_player_profile()
		root._begin_scene_transition()
		return
	root.actor_presentation_runtime_controller.set_title_world_visible(root, true)
	root.screen_state_controller.set_hud_visibility(root, true)
	if root.screen_state_controller.title_presenter.overlay != null: root.screen_state_controller.title_presenter.overlay.visible = false
	if root.screen_state_controller.archetype_presenter.overlay != null: root.screen_state_controller.archetype_presenter.overlay.visible = false
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
	await root.actor_presentation_runtime_controller.ensure_slime_visuals_ready(root)
	root.call("_place_player_at_hub_fire")
	root.call("_apply_player_palette_async", root.screen_state_controller.player_palette_name)
	root.call("_update_player_aggro_marker_colors")
	var maximum_health: float = float(root.call("_player_max_health"))
	if root.player_health_component != null:
		root.player_health_component.maximum_health = maximum_health
		root.player_health_component.reset(maximum_health)
	root.player_display_health = maximum_health
	root.player_animation_component.apply_frame(root.gameplay_frame_controller.animation_context(root))
	root.call("_update_player_shadow")
	root.call("_build_depth_lists")
	root.player.visible = true
	root.call("_update_player_shadow")
	root.call("_build_depth_lists")
	var requested_restore := bool(root.get("pending_run_restore"))
	if requested_restore:
		if not bool(root.call("_restore_active_run_checkpoint")):
			# Keep the checkpoint and return to the title. The player can retry Resume
			# or explicitly Discard it; a corrupt/unsupported run must never be
			# silently replaced by a fresh dungeon.
			show_active_run_restore_failure(root)
			return
	else:
		root.call("_begin_new_run")
		# The hub/start room is a safe initial boundary for an interrupted-free run.
		root.call("_save_active_run_checkpoint")
	root.loading_screen_fading = true
	root.loading_screen_timer = 0.0


func show_active_run_restore_failure(root: Object) -> void:
	root.set("pending_run_restore", false)
	var diagnostics := root.call("get_node_or_null", "WebRunDiagnostics") as Node
	if diagnostics != null and diagnostics.has_method("record"):
		diagnostics.call("record", "restore_failed", root)
	push_error("Active run restore failed; checkpoint retained for Resume or Discard.")
	# Reuse the normal title transition so the persisted checkpoint remains
	# available to Continue without exposing a half-restored runtime.
	root.call("_return_to_title")


func place_player_at_hub_fire(root: Object) -> void:
	if root.player == null: return
	var requested_position: Vector2 = root.player_start_position
	root.player.global_position = requested_position
	if root._can_actor_stand_at_current_position(root.player):
		return
	var requested_foot: Vector2 = root._actor_foot(root.player)
	var valid_foot: Vector2 = root._nearest_slime_walkable_point(requested_foot)
	if valid_foot != Vector2.INF:
		root.player.global_position = valid_foot - root.ACTOR_FOOT_OFFSET


func build_loading_screen(root: Object) -> void:
	var controls: Dictionary = root.screen_state_controller.assembly_controller.build_loading(root.ui, Callable(root, "_pixel_text_texture"))
	root.loading_screen_overlay = controls["overlay"] as ColorRect
	root.loading_screen_text = controls["text"] as Sprite2D


func update_loading_screen(root: Object, delta: float) -> void:
	var result: Dictionary = root.screen_state_controller.assembly_controller.update_loading(root.loading_screen_overlay, root.loading_screen_text, root.loading_screen_fading, root.loading_screen_timer, delta, Callable(root, "_pixel_text_texture"))
	root.loading_screen_fading = result["fading"]
	root.loading_screen_timer = result["timer"]
	if result["finished"]: root.loading_screen_active = false
