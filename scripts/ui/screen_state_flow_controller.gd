extends RefCounted
class_name ScreenStateFlowController

## Owns title, archetype, and defeat route timing/input.
## ScreenStateController retains stable entry points and shared menu services.
var screen: ScreenStateController

func bind(owner: Variant) -> void:
	screen = owner

# --- Title menu flow and command selection ---
func update_title_flow(root: GameplayState, delta: float) -> void:
	var cloud_panel := root.cloud_save_panel
	if cloud_panel != null and cloud_panel.overlay != null and cloud_panel.overlay.visible:
		cloud_panel.update_input()
		return
	if screen.settings_presenter.overlay != null and screen.settings_presenter.overlay.visible:
		screen._screen_route_controller.update_settings_input(root)
		return
	if screen.menu_input_release_lock:
		# A confirm used to close title Settings must be released before the title
		# screen can dispatch its focused button. Otherwise BACK immediately falls
		# through to New Game on the next frame.
		var released := not root._is_menu_confirm_pressed() and not root._is_menu_back_pressed()
		if released:
			screen.menu_input_release_lock = false
		else:
			return
	if screen.archetype_presenter.overlay != null and screen.archetype_presenter.overlay.visible and not screen.title_presenter.transition_active:
		update_archetype_input(root, delta)
		return
	if screen.title_presenter.transition_active:
		screen._title_particle_controller.update_particles(delta, Callable(root, "_snap_half_pixel"))
		screen.title_presenter.transition_timer += delta
		var overlay: Variant = screen.title_presenter.overlay
		var fade_start := 0.72
		var fade_duration := 0.42
		# Save selection is still a title-screen screen.state. Keep the black cover
		# opaque while the fizzle runs; fading it out here exposes the live game
		# scene before the save menu has been opened.
		var opening_save_select: Variant = screen.title_presenter.pending_destination == "save_select"
		overlay.modulate.a = 1.0 if opening_save_select or screen.title_presenter.transition_timer < fade_start else clampf(1.0 - (screen.title_presenter.transition_timer - fade_start) / fade_duration, 0.0, 1.0)
		if screen.title_presenter.transition_timer >= fade_start + fade_duration:
			screen.title_presenter.transition_active = false
			if screen.title_presenter.pending_destination == "save_select":
				screen.title_presenter.pending_destination = ""
				overlay.visible = true
				overlay.modulate.a = 1.0
				root._open_save_select_after_title_transition()
			else:
				overlay.visible = false
				screen.archetype_presenter.transition_timer = -0.35
				root._select_archetype_menu_row(0)
		return
	screen.title_presenter.frame_timer += delta
	var frame_timer: Variant = screen.title_presenter.frame_timer
	var new_game: Variant = screen.title_presenter.start_button
	var continue_button: Variant = screen.title_presenter.continue_button
	var settings_button: Variant = screen.title_presenter.settings_button
	var cloud_button: Variant = screen.title_presenter.cloud_button
	var title_buttons: Array[Button] = [new_game, continue_button, cloud_button, settings_button]
	var visible_index := 0
	for button in title_buttons:
		if button == null or button.disabled or not button.visible: continue
		var phase := visible_index * 0.3
		button.modulate.a = screen._menu_widget_factory.retro_button_alpha(frame_timer + phase)
		var base_y := float(button.get_meta("menu_base_y", 93.0 + visible_index * 16.0))
		button.position.y = base_y
		visible_index += 1
	var command_list: Variant = screen.title_presenter.command_list
	if command_list != null:
		command_list.configure(title_buttons, [93.0, 109.0, 125.0, 141.0])
		command_list.row = screen.title_presenter.menu_row
		if command_list.available_rows().is_empty(): return
		if not command_list.available_rows().has(screen.title_presenter.menu_row): screen.title_presenter.menu_row = command_list.available_rows()[0]; command_list.row = screen.title_presenter.menu_row
		if root._is_menu_direction_just_pressed(&"ui_up"):
			command_list.move_up(); screen.title_presenter.menu_row = command_list.row
			root._play_sound("ui_hover", -6.0, 1.0)
		elif root._is_menu_direction_just_pressed(&"ui_down"):
			command_list.move_down(); screen.title_presenter.menu_row = command_list.row
			root._play_sound("ui_hover", -6.0, 1.0)
		var cursor: Variant = screen.title_presenter.cursor_text
		var selected: Variant = command_list.selected()
		if cursor != null and selected != null:
			cursor.visible = true
			var base_y := float(selected.get_meta("menu_base_y", selected.position.y))
			screen._menu_cursor_animator.move_menu_cursor(cursor, Vector2(selected.position.x - screen.CURSOR_LEFT_GAP, base_y + 4.0), true, screen)
			cursor.texture = screen.MENU_CURSOR_TEXTURE
		if root._is_menu_confirm_just_pressed() and selected != null and not selected.disabled:
			# Preserve the title transition's original fizzle cue for both NEW GAME
			# and CONTINUE. Generic menu confirms use the authored Confirm sound.
			root._play_sound("enemy_death", -6.0, 0.95)
			selected.pressed.emit()
		return


# --- Archetype selection and preview flow ---
func update_archetype_input(root: GameplayState, delta: float) -> void:
	if screen.archetype_presenter.footer_text != null:
		screen._menu_prompt_texture_factory.pixel_prompt_texture(Callable(root, "_pixel_text_texture"), screen._menu_back_prompt_for(root), Color8(148, 220, 255))
	if screen.archetype_presenter.transition_active:
		screen.archetype_presenter.transition_timer += delta
		var transition_timer: Variant = screen.archetype_presenter.transition_timer
		if transition_timer < 0.0:
			return
		if not screen.archetype_presenter.fade_out:
			screen.archetype_presenter.hold_cover.visible = false
			screen.archetype_presenter.transition_active = false
			return
		screen.archetype_presenter.overlay.modulate.a = clampf(1.0 - transition_timer / 0.42, 0.0, 1.0)
		if transition_timer >= 0.42:
			screen.archetype_presenter.transition_active = false
			if screen.archetype_presenter.fade_out:
				screen.archetype_presenter.overlay.visible = false
		return
	if screen.menu_input_release_lock:
		var released := not root._is_menu_confirm_pressed() and not root._is_menu_back_pressed()
		if released: screen.menu_input_release_lock = false
		else: return
	if root._is_menu_back_just_pressed():
		root._cancel_character_creation()
		return
	screen.archetype_presenter.frame_timer += delta
	screen.archetype_presenter.arrow_anim_timer = maxf(screen.archetype_presenter.arrow_anim_timer - delta, 0.0)
	update_archetype_preview_animation(root)
	update_archetype_arrow_animation(root)
	var button: Variant = screen.archetype_presenter.start_button
	button.modulate.a = screen._menu_widget_factory.retro_button_alpha(screen.archetype_presenter.frame_timer)
	button.position.y = 104.0 + screen._menu_widget_factory.retro_button_bob(screen.archetype_presenter.frame_timer)
	var row: Variant = screen.archetype_presenter.menu_row
	if root._is_menu_direction_just_pressed(&"ui_up"):
		select_archetype_menu_row(root, row - 1); root._play_sound("ui_hover", -6.0, 1.0)
	elif root._is_menu_direction_just_pressed(&"ui_down"):
		select_archetype_menu_row(root, row + 1); root._play_sound("ui_hover", -6.0, 1.0)
	elif root._is_menu_direction_just_pressed(&"ui_left") or root._is_menu_direction_just_pressed(&"ui_right"):
		var direction := -1 if root._is_menu_direction_just_pressed(&"ui_left") else 1
		if row == 0: shift_archetype(root, direction)
		else: select_archetype_menu_row(root, 1)
		root._play_sound("ui_hover", -6.0, 1.0)
	if root._is_menu_confirm_just_pressed():
		root._play_sound("ui_confirm", 0.0, 1.0)
		if row == 1: start_selected_archetype(root)
		else: select_archetype_menu_row(root, 1)


func start_selected_archetype(root: GameplayState) -> void:
	if screen.archetype_presenter.overlay == null or not screen.archetype_presenter.overlay.visible or root.loading_screen_active:
		return
	var profile := root.player_profile
	if profile != null and not profile.has_started:
		var stats := root.player_stats
		stats.manual_allocation_enabled = true
		# Starter aspect selection is presentation/element identity only. Every
		# new player starts from the same even two-point baseline.
		profile.base_vit = 2
		profile.base_str = 2
		profile.base_def = 2
		profile.base_agi = 2
		profile.base_int = 2
		profile.base_mnd = 2
		var starter_flame: StringName = screen.ASPECT_CATALOG_SCRIPT.STARTER_FLAMES[screen.archetype_presenter.starter_flame_index]
		profile.starter_flame = starter_flame
		profile.allocation_profile = int(StatsComponent.AllocationProfile.BALANCED)
		profile.palette_name = screen.ASPECT_CATALOG_SCRIPT.palette_for_flame(starter_flame)
		profile.has_started = true
		profile.ensure_starter_items()
		root._apply_profile_to_runtime()
		root._save_player_profile()
	screen.archetype_presenter.overlay.visible = false
	screen.archetype_presenter.hold_cover.visible = false
	root.has_persistent_profile = true
	root._enter_starting_room_from_menu()


func shift_archetype(root: GameplayState, direction: int) -> void:
	screen.archetype_presenter.starter_flame_index = posmod(screen.archetype_presenter.starter_flame_index + direction, screen.ASPECT_CATALOG_SCRIPT.STARTER_FLAMES.size())
	screen.archetype_presenter.index = screen.archetype_presenter.starter_flame_index
	archetype_arrow_pulse(root, direction)
	update_archetype_screen(root)


func shift_archetype_color(root: GameplayState, direction: int) -> void:
	screen.archetype_presenter.color_index = posmod(screen.archetype_presenter.color_index + direction, PaletteLibrary.SELECTABLE_PALETTES.size())
	archetype_arrow_pulse(root, direction)
	update_archetype_screen(root)


func archetype_arrow_pulse(_root: GameplayState, direction: int) -> void:
	screen.archetype_presenter.arrow_anim_direction = direction
	screen.archetype_presenter.arrow_anim_timer = 0.18


func update_archetype_arrow_animation(_root: GameplayState) -> void:
	var amount: float = clampf(screen.archetype_presenter.arrow_anim_timer / 0.18, 0.0, 1.0)
	var pulse: float = 1.0 + amount * 0.22
	screen.archetype_presenter.type_left_button.scale = Vector2.ONE * (pulse if screen.archetype_presenter.arrow_anim_direction < 0 and screen.archetype_presenter.menu_row == 0 else 1.0)
	screen.archetype_presenter.type_right_button.scale = Vector2.ONE * (pulse if screen.archetype_presenter.arrow_anim_direction > 0 and screen.archetype_presenter.menu_row == 0 else 1.0)
	for button in screen.archetype_presenter.left_buttons: button.scale = Vector2.ONE * (pulse if screen.archetype_presenter.arrow_anim_direction < 0 and screen.archetype_presenter.menu_row == 1 else 1.0)
	for right_button in screen.archetype_presenter.right_buttons: right_button.scale = Vector2.ONE * (pulse if screen.archetype_presenter.arrow_anim_direction > 0 and screen.archetype_presenter.menu_row == 1 else 1.0)


func select_archetype_menu_row(root: GameplayState, row: int) -> void:
	screen.archetype_presenter.menu_row = posmod(row, 2)
	update_archetype_screen(root)


func update_archetype_screen(root: GameplayState) -> void:
	var display := root.get("display_controller") as DisplayController
	var view_width: float = screen.layout_controller.layout_view_size().x
	var flame: StringName = screen.ASPECT_CATALOG_SCRIPT.STARTER_FLAMES[screen.archetype_presenter.starter_flame_index]
	var flame_name: String = screen.ASPECT_CATALOG_SCRIPT.display_name(flame)
	var flame_palette: String = screen.ASPECT_CATALOG_SCRIPT.palette_for_flame(flame)
	screen.archetype_presenter.name_text.texture = root.call("_pixel_text_texture", flame_name, PaletteLibrary.normal(flame_palette) if screen.archetype_presenter.menu_row == 0 else Color.WHITE) as Texture2D
	screen.archetype_presenter.name_text.position = Vector2((view_width - screen.archetype_presenter.name_text.texture.get_width()) * 0.5, 36)
	var colors: Array[String] = [flame_palette]
	var cached_palette_frames: Dictionary = root.player_animation_component.frames_by_palette.get(flame_palette, {}) as Dictionary
	var preview_source_frames: Array[Texture2D] = []
	var idle_value: Variant = cached_palette_frames.get("idle")
	if idle_value is Array:
		for frame: Texture2D in idle_value:
			preview_source_frames.append(frame)
	if preview_source_frames.is_empty():
		for frame in root.player_animation_component.idle_frames:
			preview_source_frames.append(root.player_animation_component.recolor_texture(frame, flame_palette))
	if not preview_source_frames.is_empty():
		if screen.archetype_presenter.preview_palette != colors[0] or screen.archetype_presenter.preview_frames.size() != preview_source_frames.size():
			screen.archetype_presenter.preview_frames.clear()
			screen.archetype_presenter.preview_palette = colors[0]
			for frame in preview_source_frames: screen.archetype_presenter.preview_frames.append(frame)
		update_archetype_preview_animation(root)
		update_archetype_button_styles(root)


func update_archetype_preview_animation(root: GameplayState) -> void:
	if screen.archetype_presenter.preview == null or screen.archetype_presenter.preview_frames.is_empty(): return
	var frame_time: float = maxf(root.player_tuning.idle_frame_time, 0.01)
	var frame_index: int = posmod(int(screen.archetype_presenter.frame_timer / frame_time), screen.archetype_presenter.preview_frames.size())
	screen.archetype_presenter.preview.texture = screen.archetype_presenter.preview_frames[frame_index]
	var display := root.get("display_controller") as DisplayController
	var view_width: float = screen.layout_controller.layout_view_size().x
	screen.archetype_presenter.preview.position = Vector2((view_width - screen.archetype_presenter.preview.texture.get_width() * screen.archetype_presenter.preview.scale.x) * 0.5, 48)


func start_save_select(root: GameplayState, mode: String) -> void:
	if screen.title_presenter.overlay == null or not screen.title_presenter.overlay.visible:
		return
	screen.save_select_mode = mode
	screen.title_presenter.pending_destination = "save_select"
	root._spawn_title_ui_breakup()
	screen.title_presenter.overlay.visible = true
	screen.title_presenter.overlay.modulate.a = 1.0
	screen.title_presenter.transition_active = true
	screen.title_presenter.transition_timer = 0.0
	if screen.title_presenter.title_text != null: screen.title_presenter.title_text.visible = false
	var version: Variant = screen.title_presenter.overlay.get_node_or_null("TitleVersion") as Sprite2D
	if version != null: version.visible = false
	if screen.title_presenter.start_text != null: screen.title_presenter.start_text.visible = false
	if screen.title_presenter.start_button != null: screen.title_presenter.start_button.visible = false; screen.title_presenter.start_button.release_focus()
	if screen.title_presenter.continue_button != null: screen.title_presenter.continue_button.visible = false; screen.title_presenter.continue_button.release_focus()
	if screen.title_presenter.settings_button != null: screen.title_presenter.settings_button.visible = false; screen.title_presenter.settings_button.release_focus()
	if screen.title_presenter.cloud_button != null: screen.title_presenter.cloud_button.visible = false; screen.title_presenter.cloud_button.release_focus()
	if screen.title_presenter.cursor_text != null: screen.title_presenter.cursor_text.visible = false


func show_character_creation(root: GameplayState) -> void:
	if screen.title_presenter.overlay == null or screen.archetype_presenter.overlay == null:
		return
	screen.title_presenter.overlay.visible = false
	screen.title_presenter.transition_active = false
	screen.title_presenter.pending_destination = ""
	screen.archetype_presenter.overlay.visible = true
	screen.archetype_presenter.overlay.modulate.a = 1.0
	screen.archetype_presenter.overlay.z_index = 3
	screen.set_state(&"archetype")
	if screen.archetype_presenter.hold_cover != null: screen.archetype_presenter.hold_cover.visible = false
	screen.archetype_presenter.transition_active = false
	screen.menu_input_release_lock = true
	root._select_archetype_menu_row(0)


# --- Player death and game-over transitions ---
func update_player_death(root: GameplayState, delta: float, game_over_fade_time: float) -> void:
	var death_timer := root.player_death_timer + delta
	root.player_death_timer = death_timer
	var overlay := root.player_death_overlay
	var tuning := root.player_tuning
	if overlay != null:
		if death_timer < tuning.death_particle_delay:
			overlay.modulate.a = clampf(death_timer / tuning.death_fade_time, 0.0, 1.0)
		elif not root.player_death_particles_started:
			root.player_death_particles_started = true; root._spawn_player_death_pixels(); overlay.queue_free(); root.player_death_overlay = null
			root._play_sound("enemy_death", -4.0, 0.90 + RandomNumberGenerator.new().randf_range(-0.06, 0.06))
	if not root.player_death_particles_started:
		return
	var death_effect_end := tuning.death_particle_delay + tuning.death_particle_lifetime
	var game_over: Variant = screen.game_over_presenter.overlay
	if game_over != null and game_over.visible:
		var fade_timer: Variant = screen.game_over_presenter.fade_timer + delta
		var restart: Variant = screen.game_over_presenter.restart_button
		var title: Variant = screen.game_over_presenter.title_button
		var selected: Variant = title if screen.game_over_presenter.row == 1 and title != null and not title.disabled else restart
		if selected != null:
			screen.game_over_presenter.row = 1 if selected == title else 0
		screen._game_over_screen_presenter.position_controls(screen.display_view_size, screen._menu_cursor_animator, screen, screen.CURSOR_LEFT_GAP)
		var footer_prompt: Variant = screen._menu_prompt_texture_factory.pixel_prompt_texture(Callable(root, "_pixel_text_texture"), screen._menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
		screen._game_over_screen_presenter.update_fade(fade_timer, game_over_fade_time, footer_prompt, screen._menu_widget_factory)
	elif death_timer >= death_effect_end + tuning.death_observe_time:
		root._show_game_over()


func update_game_over_input(root: GameplayState) -> void:
	var overlay: Variant = screen.game_over_presenter.overlay
	if overlay == null or not overlay.visible:
		return
	if screen.menu_input_release_lock:
		if not root._is_menu_confirm_pressed() and not root._is_menu_back_pressed():
			screen.menu_input_release_lock = false
		else:
			return
	var restart: Variant = screen.game_over_presenter.restart_button
	var title: Variant = screen.game_over_presenter.title_button
	if root._is_menu_back_just_pressed():
		if title != null and not title.disabled:
			root._play_sound("ui_decline", 0.0, 1.0)
			title.pressed.emit()
		return
	if root._is_menu_direction_just_pressed(&"ui_up") or root._is_menu_direction_just_pressed(&"ui_down"):
		screen.game_over_presenter.row = 1 - screen.game_over_presenter.row
		root._play_sound("ui_hover", -6.0, 1.0)
	var selected: Variant = title if screen.game_over_presenter.row == 1 else restart
	if selected == null or selected.disabled:
		selected = restart if restart != null and not restart.disabled else title
	if selected != null:
		screen.game_over_presenter.row = 1 if selected == title else 0
		if screen.game_over_presenter.cursor_text != null:
			screen.game_over_presenter.cursor_text.visible = true
			screen._menu_cursor_animator.move_menu_cursor(screen.game_over_presenter.cursor_text, Vector2(selected.position.x - screen.CURSOR_LEFT_GAP, selected.position.y + 3.0), true, screen)
	if screen.game_over_presenter.footer_text != null:
		screen.game_over_presenter.footer_text.visible = true
		screen.game_over_presenter.footer_text.texture = screen._menu_prompt_texture_factory.pixel_prompt_texture(Callable(root, "_pixel_text_texture"), screen._menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
	if root._is_menu_confirm_just_pressed() and selected != null and not selected.disabled:
		root._play_sound("ui_confirm", 0.0, 1.0)
		selected.pressed.emit()


func update_archetype_button_styles(_root: Object) -> void:
	var flame: StringName = screen.ASPECT_CATALOG_SCRIPT.STARTER_FLAMES[screen.archetype_presenter.starter_flame_index]
	var color := PaletteLibrary.normal(screen.ASPECT_CATALOG_SCRIPT.palette_for_flame(flame)); var row: Variant = screen.archetype_presenter.menu_row
	var type_active: bool = row == 0; var sprite_active: bool = false; var start_active: bool = row == 1
	var type_left: Variant = screen.archetype_presenter.type_left_button; var type_right: Variant = screen.archetype_presenter.type_right_button; var start: Variant = screen.archetype_presenter.start_button
	screen._menu_widget_factory.set_archetype_button_state(type_left, type_active, color); screen._menu_widget_factory.set_archetype_button_state(type_right, type_active, color)
	for button in screen.archetype_presenter.left_buttons: screen._menu_widget_factory.set_archetype_button_state(button, sprite_active, color)
	for button in screen.archetype_presenter.right_buttons: screen._menu_widget_factory.set_archetype_button_state(button, sprite_active, color)
	screen._menu_widget_factory.set_archetype_button_state(start, start_active, color)
