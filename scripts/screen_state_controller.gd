extends Node
class_name ScreenStateController

signal state_changed(state: StringName)
var state: StringName = &"gameplay"
var title_particles: Array[Dictionary] = []

func retro_button_alpha(timer: float) -> float:
	var phase := fmod(timer, 2.4); var pulse := lerpf(1.0, 0.45, (phase - 0.6) / 0.9) if phase >= 0.6 and phase < 1.5 else lerpf(0.45, 1.0, (phase - 1.5) / 0.6) if phase >= 1.5 and phase < 2.1 else 1.0; return snappedf(snappedf(pulse, 0.08), 0.125)

func retro_button_bob(timer: float) -> float: return snappedf(sin(timer / 3.6 * TAU) * 1.5, 0.5)

func set_archetype_button_state(button: Button, active: bool, color: Color) -> void:
	if button == null: return
	if bool(button.get_meta("archetype_arrow", false)):
		button.modulate = color if active else Color.WHITE
		return
	var normal := StyleBoxFlat.new(); normal.bg_color = Color(0, 0, 0, 0); normal.border_color = Color(color if active else Color.WHITE, 0.95 if active else 0.0); normal.set_border_width_all(1 if active else 0); var focus := StyleBoxFlat.new(); focus.bg_color = Color(color, 0.18 if active else 0.0); focus.border_color = color if active else Color.WHITE; focus.set_border_width_all(1 if active else 0)
	button.add_theme_color_override("font_color", color if active else Color.WHITE); button.add_theme_color_override("font_hover_color", color if active else Color.WHITE); button.add_theme_color_override("font_focus_color", color if active else Color.WHITE); button.add_theme_color_override("font_disabled_color", color if active else Color(0.65, 0.65, 0.65)); button.add_theme_stylebox_override("normal", normal); button.add_theme_stylebox_override("hover", focus); button.add_theme_stylebox_override("focus", focus); button.add_theme_stylebox_override("pressed", focus); button.add_theme_stylebox_override("disabled", focus if active else normal)
	for child in button.get_children():
		if child is Sprite2D: (child as Sprite2D).modulate = color if active else Color(0.65, 0.65, 0.65) if button.disabled else Color.WHITE


func set_state(new_state: StringName) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func update_title_flow(root: Object, delta: float) -> void:
	var archetype := root.get("archetype_overlay") as ColorRect
	var title_transition := bool(root.get("title_transition_active"))
	if archetype != null and archetype.visible and not title_transition:
		root.call("_update_archetype_input", delta)
		return
	if title_transition:
		update_particles(delta, Callable(root, "_snap_half_pixel"))
		var timer := float(root.get("title_transition_timer")) + delta
		root.set("title_transition_timer", timer)
		var overlay := root.get("title_overlay") as ColorRect
		var fade_start := 0.72
		var fade_duration := 0.42
		# Save selection is still a title-screen state. Keep the black cover
		# opaque while the fizzle runs; fading it out here exposes the live game
		# scene before the save menu has been opened.
		var opening_save_select := str(root.get("pending_title_destination")) == "save_select"
		overlay.modulate.a = 1.0 if opening_save_select or timer < fade_start else clampf(1.0 - (timer - fade_start) / fade_duration, 0.0, 1.0)
		if timer >= fade_start + fade_duration:
			root.set("title_transition_active", false)
			if str(root.get("pending_title_destination")) == "save_select":
				root.set("pending_title_destination", "")
				overlay.visible = true
				overlay.modulate.a = 1.0
				root.call("_open_save_select_after_title_transition")
			else:
				overlay.visible = false
				root.set("archetype_transition_timer", -0.35)
				root.call("_select_archetype_menu_row", 0)
		return
	var frame_timer := float(root.get("title_frame_timer")) + delta
	root.set("title_frame_timer", frame_timer)
	var new_game := root.get("title_start_button") as Button
	var continue_button := root.get("title_continue_button") as Button
	if new_game != null: new_game.modulate.a = retro_button_alpha(frame_timer); new_game.position.y = 102.0 + retro_button_bob(frame_timer)
	if continue_button != null: continue_button.modulate.a = retro_button_alpha(frame_timer + 0.4); continue_button.position.y = 120.0 + retro_button_bob(frame_timer + 0.4)
	var cursor := root.get("title_cursor_text") as Sprite2D
	var focused := root.get_viewport().gui_get_focus_owner() as Button
	var selected := continue_button if focused == continue_button and not continue_button.disabled else new_game
	if cursor != null and selected != null:
		cursor.visible = true
		cursor.position = Vector2(selected.position.x - 8, selected.position.y + 4)
		cursor.texture = root.call("_pixel_text_texture", ">", Color.WHITE) as Texture2D
	if root.call("_is_interact_input_pressed"):
		var interact_focused := root.get_viewport().gui_get_focus_owner() as Button
		if interact_focused != null and not interact_focused.disabled: interact_focused.pressed.emit()


func update_archetype_input(root: Object, delta: float) -> void:
	if bool(root.get("archetype_transition_active")):
		var transition_timer := float(root.get("archetype_transition_timer")) + delta
		root.set("archetype_transition_timer", transition_timer)
		if transition_timer < 0.0:
			return
		if not bool(root.get("archetype_fade_out")):
			(root.get("archetype_hold_cover") as ColorRect).visible = false
			root.set("archetype_transition_active", false)
			return
		(root.get("archetype_overlay") as ColorRect).modulate.a = clampf(1.0 - transition_timer / 0.42, 0.0, 1.0)
		if transition_timer >= 0.42:
			root.set("archetype_transition_active", false)
			if bool(root.get("archetype_fade_out")):
				(root.get("archetype_overlay") as ColorRect).visible = false
		return
	if bool(root.get("menu_input_release_lock")):
		var released := not bool(root.call("_is_interact_input_pressed")) and not Input.is_action_pressed("ui_accept") and not bool(root.call("_is_menu_cancel_input_pressed"))
		if released: root.set("menu_input_release_lock", false)
		else: return
	if root.call("_is_menu_cancel_input_pressed"):
		root.call("_cancel_character_creation")
		return
	root.set("archetype_frame_timer", float(root.get("archetype_frame_timer")) + delta)
	root.set("archetype_arrow_anim_timer", maxf(float(root.get("archetype_arrow_anim_timer")) - delta, 0.0))
	root.call("_update_archetype_preview_animation")
	root.call("_update_archetype_arrow_animation")
	var button := root.get("archetype_start_button") as Button
	button.modulate.a = retro_button_alpha(root.get("archetype_frame_timer"))
	button.position.y = 104.0 + retro_button_bob(root.get("archetype_frame_timer"))
	var row := int(root.get("archetype_menu_row"))
	if Input.is_action_just_pressed("ui_up"):
		root.call("_select_archetype_menu_row", row - 1)
	elif Input.is_action_just_pressed("ui_down"):
		root.call("_select_archetype_menu_row", row + 1)
	elif Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		var direction := -1 if Input.is_action_just_pressed("ui_left") else 1
		if row == 0: root.call("_shift_archetype", direction)
		elif row == 1: root.call("_shift_archetype_color", direction)
		else: root.call("_select_archetype_menu_row", 2)
	if Input.is_action_just_pressed("ui_accept") or root.call("_is_interact_input_pressed"):
		if row == 2: root.call("_start_selected_archetype")
		else: root.call("_select_archetype_menu_row", row + 1)


func start_selected_archetype(root: Object) -> void:
	var overlay := root.get("archetype_overlay") as ColorRect
	if overlay == null or not overlay.visible or bool(root.get("loading_screen_active")):
		return
	var profile := root.get("player_profile") as PlayerProfile
	var stats := root.get("player_stats") as StatsComponent
	if profile != null and not profile.has_started:
		stats.manual_allocation_enabled = false
		stats.allocation_profile = root.get("selected_archetype")
		var initial_stats := stats.get_stats()
		profile.base_vit = int(initial_stats["VIT"])
		profile.base_str = int(initial_stats["STR"])
		profile.base_def = int(initial_stats["DEF"])
		profile.base_spd = int(initial_stats["SPD"])
		profile.allocation_profile = int(root.get("selected_archetype"))
		profile.palette_name = ["blue", "orange", "green", "red", "yellow", "grey", "purple", "aquamarine"][int(root.get("archetype_color_index"))]
		profile.has_started = true
		profile.ensure_starter_items()
		root.call("_apply_profile_to_runtime")
		root.call("_save_player_profile")
	overlay.visible = false
	(root.get("archetype_hold_cover") as ColorRect).visible = false
	root.set("has_persistent_profile", true)
	root.call("_enter_starting_room_from_menu")


func start_new_game(root: Object) -> void:
	var title_overlay := root.get("title_overlay") as ColorRect
	if title_overlay == null or not title_overlay.visible:
		return
	root.call("_spawn_title_pixel_breakup", root.get("title_screen_text"))
	root.call("_spawn_title_pixel_breakup", root.get("title_start_text"))
	root.call("_spawn_title_button_frame_breakup")
	title_overlay.visible = true; title_overlay.modulate.a = 1.0
	root.set("title_transition_active", true); root.set("title_transition_timer", 0.0)
	var title_text := root.get("title_screen_text") as Sprite2D
	var start_text := root.get("title_start_text") as Sprite2D
	var start_button := root.get("title_start_button") as Button
	var continue_button := root.get("title_continue_button") as Button
	if title_text != null: title_text.visible = false
	if start_text != null: start_text.visible = false
	if start_button != null: start_button.visible = false; start_button.release_focus()
	if continue_button != null: continue_button.visible = false; continue_button.release_focus()
	var title_cursor := root.get("title_cursor_text") as Sprite2D
	if title_cursor != null: title_cursor.visible = false
	var archetype_overlay := root.get("archetype_overlay") as ColorRect
	archetype_overlay.visible = true; set_state(&"archetype")
	archetype_overlay.modulate.a = 1.0
	(root.get("archetype_hold_cover") as ColorRect).visible = true
	root.set("archetype_transition_active", true); root.set("archetype_transition_timer", -1.0); root.set("archetype_fade_out", false)


func start_save_select(root: Object, mode: String) -> void:
	var title_overlay := root.get("title_overlay") as ColorRect
	if title_overlay == null or not title_overlay.visible:
		return
	root.set("save_select_mode", mode)
	root.set("pending_title_destination", "save_select")
	root.call("_spawn_title_pixel_breakup", root.get("title_screen_text"))
	root.call("_spawn_title_pixel_breakup", root.get("title_start_text"))
	root.call("_spawn_title_button_frame_breakup")
	title_overlay.visible = true
	title_overlay.modulate.a = 1.0
	root.set("title_transition_active", true)
	root.set("title_transition_timer", 0.0)
	var title_text := root.get("title_screen_text") as Sprite2D
	var start_text := root.get("title_start_text") as Sprite2D
	var start_button := root.get("title_start_button") as Button
	var continue_button := root.get("title_continue_button") as Button
	if title_text != null: title_text.visible = false
	if start_text != null: start_text.visible = false
	if start_button != null: start_button.visible = false; start_button.release_focus()
	if continue_button != null: continue_button.visible = false; continue_button.release_focus()
	var title_cursor := root.get("title_cursor_text") as Sprite2D
	if title_cursor != null: title_cursor.visible = false


func show_character_creation(root: Object) -> void:
	var title_overlay := root.get("title_overlay") as ColorRect
	var archetype_overlay := root.get("archetype_overlay") as ColorRect
	if title_overlay == null or archetype_overlay == null:
		return
	title_overlay.visible = false
	root.set("title_transition_active", false)
	root.set("pending_title_destination", "")
	archetype_overlay.visible = true
	archetype_overlay.modulate.a = 1.0
	archetype_overlay.z_index = 3
	set_state(&"archetype")
	var hold_cover := root.get("archetype_hold_cover") as ColorRect
	if hold_cover != null: hold_cover.visible = false
	root.set("archetype_transition_active", false)
	root.set("menu_input_release_lock", true)
	root.call("_select_archetype_menu_row", 0)


func update_player_death(root: Object, delta: float, game_over_fade_time: float) -> void:
	var death_timer := float(root.get("player_death_timer")) + delta
	root.set("player_death_timer", death_timer)
	var overlay := root.get("player_death_overlay") as Sprite2D
	var tuning := root.get("player_tuning") as PlayerTuning
	if overlay != null:
		if death_timer < tuning.death_particle_delay:
			overlay.modulate.a = clampf(death_timer / tuning.death_fade_time, 0.0, 1.0)
		elif not bool(root.get("player_death_particles_started")):
			root.set("player_death_particles_started", true); root.call("_spawn_player_death_pixels"); overlay.queue_free(); root.set("player_death_overlay", null)
	if not bool(root.get("player_death_particles_started")):
		return
	var death_effect_end := tuning.death_particle_delay + tuning.death_particle_lifetime
	var game_over := root.get("game_over_overlay") as ColorRect
	if game_over != null and game_over.visible:
		var fade_timer := float(root.get("game_over_fade_timer")) + delta
		root.set("game_over_fade_timer", fade_timer); game_over.modulate.a = clampf(fade_timer / game_over_fade_time, 0.0, 1.0)
		var restart := root.get("game_over_button") as Button
		var title := root.get("game_over_title_button") as Button
		if restart != null: restart.modulate.a = retro_button_alpha(fade_timer); restart.position.y = 105.0 + retro_button_bob(fade_timer)
		if title != null: title.modulate.a = retro_button_alpha(fade_timer + 0.6); title.position.y = 121.0 + retro_button_bob(fade_timer + 0.4)
		var cursor := root.get("game_over_cursor_text") as Sprite2D
		var focused := root.get_viewport().gui_get_focus_owner() as Button
		var selected := title if focused == title and not title.disabled else restart
		if cursor != null:
			cursor.visible = true
			cursor.position = Vector2(selected.position.x - 8, selected.position.y + 3)
			cursor.texture = root.call("_pixel_text_texture", ">", Color.WHITE) as Texture2D
	elif death_timer >= death_effect_end + float(root.get("player_tuning").death_observe_time):
		root.call("_show_game_over")


func update_archetype_button_styles(root: Object) -> void:
	var color: Color = PaletteLibrary.ARCHETYPE_HIGHLIGHTS[int(root.get("archetype_color_index"))]; var row := int(root.get("archetype_menu_row"))
	var type_active := row == 0; var sprite_active := row == 1; var start_active := row == 2
	var type_left := root.get("archetype_type_left_button") as Button; var type_right := root.get("archetype_type_right_button") as Button; var start := root.get("archetype_start_button") as Button
	set_archetype_button_state(type_left, type_active, color); set_archetype_button_state(type_right, type_active, color)
	for button in root.get("archetype_left_buttons") as Array[Button]: set_archetype_button_state(button, sprite_active, color)
	for button in root.get("archetype_right_buttons") as Array[Button]: set_archetype_button_state(button, sprite_active, color)
	set_archetype_button_state(start, start_active, color)


func add_particle(particle_data: Dictionary) -> void:
	title_particles.append(particle_data)


func update_particles(delta: float, snap_position: Callable) -> void:
	for index in range(title_particles.size() - 1, -1, -1):
		var particle_data := title_particles[index]
		var particle := particle_data["sprite"] as Sprite2D
		var timer := float(particle_data["timer"]) - delta
		if particle == null or timer <= 0.0:
			if particle != null:
				particle.queue_free()
			title_particles.remove_at(index)
			continue
		var logical_position := particle_data.get("logical_position", particle.position) as Vector2
		logical_position += particle_data["velocity"] as Vector2 * delta
		particle_data["logical_position"] = logical_position
		particle.position = snap_position.call(logical_position)
		particle.modulate.a = clampf(timer / float(particle_data.get("lifetime", 1.14)), 0.0, 1.0)
		particle_data["timer"] = timer


func spawn_pixel_breakup(source_sprite: Sprite2D, particle_parent: Node, pixel_texture: Callable, random_seed: int) -> void:
	if source_sprite == null or source_sprite.texture == null:
		return
	var image := source_sprite.texture.get_image()
	if image == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.28
	for y in image.get_height():
		for x in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var pixel_position := source_sprite.global_position
			var pixel_size := source_sprite.scale
			if source_sprite.centered:
				pixel_position -= Vector2(image.get_width(), image.get_height()) * pixel_size * 0.5
			pixel_position += Vector2(x, y) * pixel_size
			var particle := Sprite2D.new()
			particle.texture = pixel_texture.call(color) as Texture2D
			particle.centered = false
			particle.scale = pixel_size
			particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			particle.z_as_relative = true
			particle.z_index = 3
			particle.position = pixel_position
			particle_parent.add_child(particle)
			add_particle({"sprite": particle, "velocity": Vector2(0.0, -(8.0 + (noise.get_noise_2d(float(x), float(y)) + 1.0) * 14.0)), "timer": 1.14, "lifetime": 1.14, "gravity": 0.0})


func spawn_button_frame_breakup(button: Button, particle_parent: Node, pixel_texture: Callable, random_seed: int) -> void:
	if button == null:
		return
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.28
	var origin := button.position
	if particle_parent is Node2D:
		origin = (particle_parent as Node2D).to_local(button.global_position)
	var width := int(button.size.x)
	var height := int(button.size.y)
	for x in range(width):
		_spawn_frame_particle(origin + Vector2(x, 0), particle_parent, pixel_texture, noise.get_noise_2d(float(x), 0.0))
		_spawn_frame_particle(origin + Vector2(x, height - 1), particle_parent, pixel_texture, noise.get_noise_2d(float(x), float(height - 1)))
	for y in range(1, height - 1):
		_spawn_frame_particle(origin + Vector2(0, y), particle_parent, pixel_texture, noise.get_noise_2d(0.0, float(y)))
		_spawn_frame_particle(origin + Vector2(width - 1, y), particle_parent, pixel_texture, noise.get_noise_2d(float(width - 1), float(y)))


func _spawn_frame_particle(frame_position: Vector2, particle_parent: Node, pixel_texture: Callable, noise_value: float) -> void:
	var particle := Sprite2D.new()
	particle.texture = pixel_texture.call(Color.WHITE) as Texture2D
	particle.centered = false
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = true
	particle.z_index = 3
	particle.position = frame_position
	particle_parent.add_child(particle)
	var rise_speed := 8.0 + (noise_value + 1.0) * 14.0
	add_particle({"sprite": particle, "velocity": Vector2(0.0, -rise_speed), "timer": 1.14, "lifetime": 1.14, "gravity": 0.0})


func style_archetype_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 8)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(1, 1, 1, 0.12)
	focus.border_color = Color.WHITE
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)


func make_retro_button(label: String, button_position: Vector2, size: Vector2, pixel_texture: Callable) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = size
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color.WHITE
	normal.set_border_width_all(1)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(1, 1, 1, 0.12)
	focus.border_color = Color.WHITE
	focus.set_border_width_all(1)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	var text := Sprite2D.new()
	text.texture = pixel_texture.call(label, Color.WHITE) as Texture2D
	text.centered = true
	text.position = size * 0.5
	text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(text)
	return button


func build_game_over(parent: Node, pixel_texture: Callable, restart: Callable, return_title: Callable) -> Dictionary:
	var overlay := create_overlay(parent, "GameOverOverlay", Vector2(240, 160), Color(0, 0, 0, 0.62), 0, false)
	overlay.modulate.a = 0.0
	var title_texture := pixel_texture.call("GAME OVER", Color.WHITE) as Texture2D
	create_sprite(overlay, "GameOverTitle", title_texture, Vector2((240.0 - title_texture.get_width() * 3.0) * 0.5, 50), false, Vector2(3, 3))
	var saved_texture := pixel_texture.call("PROGRESS SAVED", Color8(167, 240, 112)) as Texture2D
	create_sprite(overlay, "GameOverSaved", saved_texture, Vector2((240.0 - saved_texture.get_width()) * 0.5, 88), false)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 0)
	normal_style.border_color = Color(0.72, 0.72, 0.72, 0.9)
	normal_style.set_border_width_all(1)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(1, 1, 1, 0.12)
	focus_style.border_color = Color.WHITE
	focus_style.set_border_width_all(1)
	var restart_button := _make_text_button("HUB", Vector2(99, 105), normal_style, focus_style, pixel_texture, restart)
	var title_button := _make_text_button("TITLE", Vector2(99, 121), normal_style, focus_style, pixel_texture, return_title)
	overlay.add_child(restart_button)
	overlay.add_child(title_button)
	var cursor := create_sprite(overlay, "GameOverCursor", pixel_texture.call(">", Color.WHITE) as Texture2D, Vector2(91, 108), false)
	return {"overlay": overlay, "restart": restart_button, "title": title_button, "cursor": cursor}


func build_run_complete(parent: Node, pixel_texture: Callable, return_to_hub: Callable) -> Dictionary:
	var panel_size := Vector2(216, 152)
	var overlay := create_overlay(parent, "RunCompleteOverlay", panel_size, Color(0.015, 0.02, 0.035, 0.96), 6, false)
	overlay.position = Vector2((240.0 - panel_size.x) * 0.5, (160.0 - panel_size.y) * 0.5)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = overlay.color
	panel_style.border_color = Color8(255, 205, 117)
	panel_style.set_border_width_all(1)
	overlay.add_theme_stylebox_override("panel", panel_style)
	var title_texture := pixel_texture.call("RUN COMPLETE", Color8(255, 205, 117)) as Texture2D
	create_sprite(overlay, "RunCompleteTitle", title_texture, Vector2((panel_size.x - title_texture.get_width()) * 0.5, 5), false)
	var lines: Array[Sprite2D] = []
	for index in 11:
		lines.append(create_sprite(overlay, "RunCompleteLine%d" % index, null, Vector2(10, 20 + index * 10), false))
	var return_button := make_retro_button("RETURN TO HUB", Vector2(65, 136), Vector2(86, 12), pixel_texture)
	return_button.focus_mode = Control.FOCUS_NONE
	return_button.pressed.connect(return_to_hub)
	overlay.add_child(return_button)
	var cursor := create_sprite(overlay, "RunCompleteCursor", pixel_texture.call(">", Color.WHITE) as Texture2D, Vector2(56, 139), false)
	return {"overlay": overlay, "lines": lines, "return": return_button, "cursor": cursor}


func build_hub(parent: Node, pixel_texture: Callable, adjust_stat: Callable, apply_stats: Callable, cancel_stats: Callable, auto_allocate: Callable, respec: Callable, _start_run: Callable, _return_title: Callable, set_page: Callable, item_action: Callable, select_gear_slot: Callable) -> Dictionary:
	var panel_size := Vector2(156, 116)
	var overlay := create_overlay(parent, "HubOverlay", panel_size, Color(0.015, 0.02, 0.035, 0.94), 3, false)
	overlay.position = Vector2((240.0 - panel_size.x) * 0.5, (160.0 - panel_size.y) * 0.5)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = overlay.color
	panel_style.border_color = Color(0.75, 0.78, 0.86, 0.9)
	panel_style.set_border_width_all(1)
	overlay.add_theme_stylebox_override("panel", panel_style)
	var title_texture := pixel_texture.call("DEMON HUB", Color.WHITE) as Texture2D
	create_sprite(overlay, "HubTitle", title_texture, Vector2((panel_size.x - title_texture.get_width()) * 0.5, 4), false)
	var pages: Array[Button] = []
	for page_index in 4:
		var page_button := make_retro_button(["STATS", "GEAR", "SHOP", "FUSE"][page_index], Vector2(4 + page_index * 38, 15), Vector2(36, 12), pixel_texture)
		page_button.focus_mode = Control.FOCUS_NONE
		page_button.pressed.connect(set_page.bind(page_index))
		overlay.add_child(page_button); pages.append(page_button)
	var summary := create_sprite(overlay, "HubSummary", null, Vector2.ZERO, false)
	summary.visible = false
	var points := create_sprite(overlay, "HubPoints", null, Vector2(7, 32), false)
	var stats: Array[Sprite2D] = []
	var stat_buttons: Array[Button] = []
	var stat_left: Array[Button] = []
	var stat_right: Array[Button] = []
	var derived: Array[Sprite2D] = []
	var stat_names := [&"VIT", &"STR", &"DEF", &"SPD"]
	for index in stat_names.size():
		var stat_text := create_sprite(overlay, "HubStat%d" % index, null, Vector2(18, 42 + index * 12), false)
		stats.append(stat_text)
		var left := make_archetype_arrow(overlay, -1, Vector2(4, 40 + index * 12), adjust_stat.bind(stat_names[index], -1), pixel_texture)
		var right := make_archetype_arrow(overlay, 1, Vector2(84, 40 + index * 12), adjust_stat.bind(stat_names[index], 1), pixel_texture)
		left.set_meta("hub_stat_direction", -1); right.set_meta("hub_stat_direction", 1)
		left.set_meta("hub_stat_index", index); right.set_meta("hub_stat_index", index)
		stat_left.append(left); stat_right.append(right); stat_buttons.append(left); stat_buttons.append(right)
	for index in 4:
		derived.append(create_sprite(overlay, "HubDerived%d" % index, null, Vector2(100, 42 + index * 12), false))
	var apply_button := make_retro_button("APPLY", Vector2(3, 88), Vector2(34, 11), pixel_texture)
	apply_button.focus_mode = Control.FOCUS_NONE
	apply_button.pressed.connect(apply_stats)
	overlay.add_child(apply_button)
	var cancel_button := make_retro_button("CANCEL", Vector2(39, 88), Vector2(38, 11), pixel_texture)
	cancel_button.focus_mode = Control.FOCUS_NONE
	cancel_button.pressed.connect(cancel_stats)
	overlay.add_child(cancel_button)
	var auto_button := make_retro_button("AUTO", Vector2(79, 88), Vector2(29, 11), pixel_texture)
	auto_button.focus_mode = Control.FOCUS_NONE
	auto_button.pressed.connect(auto_allocate)
	overlay.add_child(auto_button)
	var respec_button := make_retro_button("RESPEC", Vector2(110, 88), Vector2(43, 11), pixel_texture)
	respec_button.focus_mode = Control.FOCUS_NONE
	respec_button.pressed.connect(respec)
	overlay.add_child(respec_button)
	var item_name := create_sprite(overlay, "HubItemName", null, Vector2(8, 38), false)
	item_name.visible = false
	var item_list: Array[Sprite2D] = []
	for list_index in 5:
		item_list.append(create_sprite(overlay, "HubItemList%d" % list_index, null, Vector2(7, 32 + list_index * 10), false))
	var shop_prices: Array[Sprite2D] = []
	for list_index in 5:
		shop_prices.append(create_sprite(overlay, "HubShopPrice%d" % list_index, null, Vector2(125, 32 + list_index * 10), false))
	var gear_slot_buttons: Array[Button] = []
	for slot_index in 4:
		var slot_button := Button.new()
		slot_button.position = Vector2(2, 30 + slot_index * 10); slot_button.size = Vector2(100, 10); slot_button.focus_mode = Control.FOCUS_NONE; slot_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var transparent := StyleBoxFlat.new(); transparent.bg_color = Color(0, 0, 0, 0); transparent.set_border_width_all(0)
		slot_button.add_theme_stylebox_override("normal", transparent); slot_button.add_theme_stylebox_override("hover", transparent); slot_button.add_theme_stylebox_override("pressed", transparent)
		slot_button.pressed.connect(select_gear_slot.bind(slot_index)); overlay.add_child(slot_button); gear_slot_buttons.append(slot_button)
	var gear_choices: Array[Sprite2D] = []
	for choice_index in 4:
		gear_choices.append(create_sprite(overlay, "HubGearChoice%d" % choice_index, null, Vector2(6, 85 + choice_index * 7), false))
		gear_choices[choice_index].visible = false
	var gear_stat_panel := Panel.new()
	gear_stat_panel.name = "HubGearStatPanel"; gear_stat_panel.position = Vector2(101, 29); gear_stat_panel.size = Vector2(51, 53); gear_stat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gear_stat_style := StyleBoxFlat.new(); gear_stat_style.bg_color = Color(0.04, 0.06, 0.10, 0.85); gear_stat_style.border_color = Color(0.42, 0.48, 0.62, 0.9); gear_stat_style.set_border_width_all(1)
	gear_stat_panel.add_theme_stylebox_override("panel", gear_stat_style); overlay.add_child(gear_stat_panel)
	var gear_stats: Array[Sprite2D] = []
	for stat_index in 5:
		gear_stats.append(create_sprite(overlay, "HubGearStat%d" % stat_index, null, Vector2(105, 32 + stat_index * 10), false))
	var item_details: Array[Sprite2D] = []
	for detail_index in 4:
		item_details.append(create_sprite(overlay, "HubItemDetail%d" % detail_index, null, Vector2(7, 83 + detail_index * 7), false))
		item_details[detail_index].visible = false
	var item_action_button := make_retro_button("EQUIP", Vector2(52, 89), Vector2(52, 10), pixel_texture)
	item_action_button.focus_mode = Control.FOCUS_NONE; item_action_button.pressed.connect(item_action); overlay.add_child(item_action_button)
	var cursor := create_sprite(overlay, "HubCursor", null, Vector2(0, 0), false)
	cursor.visible = false
	return {"overlay": overlay, "summary": summary, "points": points, "stats": stats, "stat_buttons": stat_buttons, "stat_left": stat_left, "stat_right": stat_right, "derived": derived, "apply": apply_button, "cancel": cancel_button, "auto": auto_button, "respec": respec_button, "start": null, "title": null, "pages": pages, "item_name": item_name, "item_list": item_list, "shop_prices": shop_prices, "gear_choices": gear_choices, "gear_slot_buttons": gear_slot_buttons, "gear_stats": gear_stats, "gear_stat_panel": gear_stat_panel, "item_details": item_details, "item_action": item_action_button, "cursor": cursor}


func update_hub_ui(root: Object, pixel_texture: Callable) -> void:
	var profile := root.get("player_profile") as PlayerProfile
	if profile == null: return
	var summary := root.get("hub_summary_text") as Sprite2D
	var points := root.get("hub_points_text") as Sprite2D
	var progression := root.get("progression_tuning") as ProgressionTuning
	if summary != null: summary.texture = pixel_texture.call("LV %d   XP %d/%d   GOLD %d" % [profile.level, profile.xp, PlayerProfile.xp_required_for_level(profile.level, progression), profile.gold], Color.WHITE) as Texture2D
	var page := int(root.get("hub_page"))
	var pause_mode := bool(root.get("hub_pause_mode"))
	var page_buttons := root.get("hub_page_buttons") as Array[Button]
	var highlight_color: Color = root.call("_health_feedback_color", root.get("player_palette_name"))
	var cursor := root.get("hub_cursor_text") as Sprite2D
	if cursor != null:
		cursor.visible = false
	for page_index in page_buttons.size():
		page_buttons[page_index].visible = not pause_mode
		set_archetype_button_state(page_buttons[page_index], page == page_index, highlight_color)
	if summary != null:
		summary.visible = pause_mode
		summary.position = Vector2(7, 18)
	var title := (root.get("hub_overlay") as ColorRect).get_node_or_null("HubTitle") as Sprite2D
	if title != null:
		var title_texture := pixel_texture.call("PAUSE" if pause_mode else "DEMON HUB", Color.WHITE) as Texture2D
		title.texture = title_texture
		title.position.x = (156.0 - title_texture.get_width()) * 0.5
	var stat_nodes: Array[CanvasItem] = []
	stat_nodes.append(root.get("hub_points_text") as Sprite2D); stat_nodes.append_array(root.get("hub_stat_texts") as Array[Sprite2D]); stat_nodes.append_array(root.get("hub_stat_buttons") as Array[Button]); stat_nodes.append_array(root.get("hub_derived_texts") as Array[Sprite2D]); stat_nodes.append(root.get("hub_apply_button") as Button); stat_nodes.append(root.get("hub_cancel_button") as Button); stat_nodes.append(root.get("hub_auto_button") as Button); stat_nodes.append(root.get("hub_respec_button") as Button)
	for node in stat_nodes:
		if node != null: node.visible = page == 0
	var item_name := root.get("hub_item_name_text") as Sprite2D
	var item_list := root.get("hub_item_list_texts") as Array[Sprite2D]
	var shop_prices := root.get("hub_shop_price_texts") as Array[Sprite2D]
	var gear_choices := root.get("hub_gear_choice_texts") as Array[Sprite2D]
	var gear_stats := root.get("hub_gear_stat_texts") as Array[Sprite2D]
	var item_details := root.get("hub_item_detail_texts") as Array[Sprite2D]
	var item_action := root.get("hub_item_action_button") as Button
	if item_name != null: item_name.visible = false
	for node in item_list: node.visible = page != 0
	for node in shop_prices: node.visible = page == 2
	for node in gear_choices: node.visible = page == 1 and bool(root.get("hub_gear_browsing"))
	for button in root.get("hub_gear_slot_buttons") as Array[Button]: button.visible = page == 1 and not bool(root.get("hub_gear_browsing"))
	for node in gear_stats: node.visible = page == 1 or page == 3
	var gear_stat_panel := root.get("hub_gear_stat_panel") as Panel
	if gear_stat_panel != null: gear_stat_panel.visible = page == 1 or page == 3
	for node in item_details: node.visible = page != 0
	if item_action != null: item_action.visible = page != 0
	if page != 0:
		_update_hub_item_page(root, pixel_texture, profile, page, item_list, item_details, item_action, highlight_color)
		return
	var pending := [int(root.get("hub_pending_vit")), int(root.get("hub_pending_str")), int(root.get("hub_pending_def")), int(root.get("hub_pending_spd"))]
	var remaining := int(root.call("_hub_points_remaining"))
	if points != null: points.texture = pixel_texture.call("POINTS TO SPEND: %d" % remaining, Color8(255, 205, 117)) as Texture2D
	var values := [profile.base_vit + profile.allocated_vit + pending[0], profile.base_str + profile.allocated_str + pending[1], profile.base_def + profile.allocated_def + pending[2], profile.base_spd + profile.allocated_spd + pending[3]]
	var allocations := [profile.allocated_vit + pending[0], profile.allocated_str + pending[1], profile.allocated_def + pending[2], profile.allocated_spd + pending[3]]
	var stat_texts := root.get("hub_stat_texts") as Array[Sprite2D]
	var selected_row := int(root.get("hub_menu_row"))
	for index in stat_texts.size():
		stat_texts[index].texture = pixel_texture.call("%s %d  A+%d" % [["VIT", "STR", "DEF", "SPD"][index], values[index], allocations[index]], highlight_color if selected_row == index else Color.WHITE) as Texture2D
	var stat_buttons := root.get("hub_stat_buttons") as Array[Button]
	for button in stat_buttons:
		var direction := int(button.get_meta("hub_stat_direction", 1))
		var stat_index := int(button.get_meta("hub_stat_index", 0))
		button.disabled = remaining <= 0 if direction > 0 else int(pending[stat_index]) <= 0
		set_archetype_button_state(button, selected_row == stat_index, highlight_color)
	var snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot
	if snapshot != null:
		snapshot.vit += pending[0]; snapshot.strength += pending[1]; snapshot.def += pending[2]; snapshot.speed += pending[3]
		var combat_tuning := root.get("combat_tuning") as CombatTuning
		var derived_texts := root.get("hub_derived_texts") as Array[Sprite2D]
		var derived_values := ["HP %d" % roundi(CombatCalculator.max_health_for_snapshot(snapshot, combat_tuning)), "ATK %d" % roundi((combat_tuning.damage_base + float(snapshot.strength)) * (1.0 + maxf(snapshot.gear_damage_rate, 0.0))), "DEF %d" % snapshot.def, "SPD %d" % snapshot.speed]
		for index in derived_texts.size():
			derived_texts[index].texture = pixel_texture.call(derived_values[index], Color8(167, 240, 112)) as Texture2D if index < derived_values.size() else null
	var pending_total: int = int(pending[0]) + int(pending[1]) + int(pending[2]) + int(pending[3])
	var apply_button := root.get("hub_apply_button") as Button
	var cancel_button := root.get("hub_cancel_button") as Button
	if apply_button != null: apply_button.disabled = pending_total <= 0
	if cancel_button != null: cancel_button.disabled = pending_total <= 0
	var auto_button := root.get("hub_auto_button") as Button
	if auto_button != null: auto_button.disabled = remaining <= 0
	var respec_button := root.get("hub_respec_button") as Button
	if respec_button != null:
		var cost := profile.respec_cost()
		respec_button.disabled = profile.allocated_vit + profile.allocated_str + profile.allocated_def <= 0 or profile.gold < cost
		var label := respec_button.get_child(0) as Sprite2D
		if label != null: label.texture = pixel_texture.call("RESPEC" if cost <= 0 else "RESPEC %d" % cost, Color.WHITE) as Texture2D
	var utility_buttons: Array[Button] = [apply_button, cancel_button, auto_button, respec_button]
	var exit_buttons: Array[Button] = [root.get("hub_start_button") as Button, root.get("hub_title_button") as Button]
	var selected_column := int(root.get("hub_action_column"))
	for index in utility_buttons.size(): set_archetype_button_state(utility_buttons[index], selected_row == 4 and selected_column == index, highlight_color)
	for index in exit_buttons.size(): set_archetype_button_state(exit_buttons[index], selected_row == 5 and selected_column == index, highlight_color)
	var start_button := root.get("hub_start_button") as Button
	if start_button != null:
		var start_label := start_button.get_child(0) as Sprite2D
		if start_label != null: start_label.texture = pixel_texture.call("RETURN" if bool(root.get("hub_opened_from_npc")) else "START RUN", Color.WHITE) as Texture2D


func _update_hub_item_page(root: Object, pixel_texture: Callable, profile: PlayerProfile, page: int, item_list: Array[Sprite2D], details: Array[Sprite2D], action: Button, highlight_color: Color) -> void:
	var catalog := ItemCatalog.new()
	var shop_prices := root.get("hub_shop_price_texts") as Array[Sprite2D]
	if page == 1:
		_update_hub_gear_slots(root, pixel_texture, profile, catalog, item_list, root.get("hub_gear_choice_texts") as Array[Sprite2D], details, action, highlight_color)
		return
	for detail_index in range(2, details.size()):
		details[detail_index].visible = false
	details[0].position = Vector2(7, 83); details[1].position = Vector2(7, 103); action.position = Vector2(52, 89)
	var item: ItemInstance = null
	var price := 0
	var sold := false
	var index := int(root.get("hub_item_index"))
	var count := 0
	if page == 1:
		count = profile.inventory.size()
		if count > 0: item = ItemInstance.from_dictionary(profile.inventory[clampi(index, 0, count - 1)])
	elif page == 2:
		var run_state := root.get("run_state") as RunState
		if run_state != null:
			run_state.ensure_shop_stock(profile.level); count = run_state.shop_stock.size()
			if count > 0:
				var entry: Dictionary = run_state.shop_stock[clampi(index, 0, count - 1)]
				item = ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary); price = int(entry.get("price", 0)); sold = bool(entry.get("sold", false))
	else:
		var fusion_items := root.call("_hub_fusion_candidates") as Array[ItemInstance]
		count = fusion_items.size()
		if count > 0:
			item = fusion_items[clampi(index, 0, count - 1)]
	var selected := clampi(index, 0, maxi(count - 1, 0))
	var window_start := clampi(selected - 2, 0, maxi(count - item_list.size(), 0))
	for row in item_list.size():
		var source_index := window_start + row
		if source_index >= count:
			item_list[row].texture = null
			if row < shop_prices.size(): shop_prices[row].texture = null
			continue
		var row_item: ItemInstance
		var row_sold := false
		var row_price := 0
		if page == 1:
			row_item = ItemInstance.from_dictionary(profile.inventory[source_index])
		elif page == 2:
			var row_state := root.get("run_state") as RunState
			var row_entry: Dictionary = row_state.shop_stock[source_index]
			row_item = ItemInstance.from_dictionary(row_entry.get("item", {}) as Dictionary); row_sold = bool(row_entry.get("sold", false)); row_price = int(row_entry.get("price", 0))
		else:
			var fusion_items := root.call("_hub_fusion_candidates") as Array[ItemInstance]
			if source_index >= fusion_items.size():
				item_list[row].texture = null; continue
			row_item = fusion_items[source_index]
		var definition: Dictionary = ItemCatalog.DEFINITIONS.get(row_item.definition_id, {})
		var prefix := ">" if source_index == selected else " "
		var rarity_mark := catalog.rarity_letter_grade(row_item.rarity)
		var row_label := "%s%s %s" % [prefix, rarity_mark, str(definition.get("name", "ITEM"))]
		var row_mastery := row_item.enhancement_level
		if row_mastery > 0 and page != 3: row_label += " +%d" % row_mastery
		if page == 2 and row_sold: row_label += " SOLD"
		elif page == 3: row_label += "  +%d" % row_mastery
		if page == 3:
			var row_slot := catalog.definition_slot(row_item.definition_id)
			if str(profile.equipped_instance_ids.get(String(row_slot), "")) == row_item.instance_id:
				row_label += " E"
		var row_color := Color8(120, 120, 130) if row_sold else catalog.rarity_color(row_item.rarity)
		item_list[row].texture = pixel_texture.call(row_label, row_color) as Texture2D
		if page == 2 and row < shop_prices.size():
			shop_prices[row].texture = pixel_texture.call("SOLD" if row_sold else "%dG" % row_price, Color8(120, 120, 130) if row_sold else Color8(255, 205, 117)) as Texture2D
	if item == null:
		if not item_list.is_empty():
			var empty_text := str(root.get("hub_fusion_message")) if page == 3 and not str(root.get("hub_fusion_message")).is_empty() else ("NO FUSE / SALVAGE" if page == 3 else "NO ITEMS")
			item_list[0].texture = pixel_texture.call(empty_text, Color8(255, 205, 117) if page == 3 else Color.WHITE) as Texture2D
		for detail in details: detail.texture = null
		for stale_stat in root.get("hub_gear_stat_texts") as Array[Sprite2D]: stale_stat.texture = null
		action.disabled = true; return
	var mastery := item.enhancement_level
	var bonuses := catalog.bonuses(item, mastery); var bonus_parts: Array[String] = []
	if page != 3:
		for stat: String in bonuses:
			var rate := stat in ["health_rate", "damage_rate", "speed"]
			var label: String = str({"health_rate": "HP", "damage_rate": "DMG"}.get(stat, stat.to_upper()))
			var value := float(bonuses[stat])
			bonus_parts.append("%s %s%.1f%s" % [label, "+" if value > 0 else "", value, "%" if rate else ""])
		details[0].texture = pixel_texture.call("  ".join(bonus_parts), Color.WHITE) as Texture2D
	var selected_transmutation_name := catalog.transmutation_name(item.transmutation_id)
	if page == 3 and not selected_transmutation_name.is_empty():
		details[0].texture = pixel_texture.call("SPECIAL: %s" % selected_transmutation_name, Color8(148, 220, 255)) as Texture2D
	elif page == 3:
		details[0].texture = null
	var slot := catalog.definition_slot(item.definition_id)
	var equipped := str(profile.equipped_instance_ids.get(String(slot), "")) == item.instance_id
	var overflow := profile.can_salvage_overflow(item.instance_id, catalog)
	var material_count := profile.fusion_material_count(item.instance_id, catalog)
	var can_fuse := material_count > 0
	var fusion_count := clampi(int(root.get("hub_fusion_count")), 1, maxi(material_count, 1))
	if page == 3 and overflow:
		details[1].texture = pixel_texture.call("MYTHIC +10  SALVAGE %dG" % catalog.overflow_salvage_value(item), Color8(255, 205, 117)) as Texture2D
		for stale_stat in root.get("hub_gear_stat_texts") as Array[Sprite2D]: stale_stat.texture = null
	elif page == 3:
		var batch_cost := profile.fusion_batch_cost(item, fusion_count)
		var fusion_color := Color8(255, 205, 117) if profile.gold >= batch_cost else Color8(255, 105, 105)
		var final_rarity := item.rarity
		var final_enhancement := mastery
		for step in fusion_count:
			if final_enhancement >= PlayerProfile.MAX_ITEM_ENHANCEMENT:
				final_rarity = ItemCatalog.next_rarity(final_rarity)
				final_enhancement = 0
			else:
				final_enhancement += 1
		var next_text := "%s -> %s +0" % [String(final_rarity).to_upper(), String(ItemCatalog.next_rarity(final_rarity)).to_upper()] if final_rarity != item.rarity else "+%d -> +%d" % [mastery, final_enhancement]
		details[1].texture = pixel_texture.call("FUSE x%d  %dG  HAVE %d  %s" % [fusion_count, batch_cost, material_count, next_text], fusion_color) as Texture2D
		var projected := ItemInstance.from_dictionary(item.to_dictionary())
		projected.enhancement_level = final_enhancement
		projected.rarity = final_rarity
		var next_bonuses := catalog.bonuses(projected, 0)
		var preview_stats := root.get("hub_gear_stat_texts") as Array[Sprite2D]
		var preview_rows: Array[String] = []
		var preview_order := ["health_rate", "damage_rate", "strength", "defense", "vitality", "speed"]
		for stat: String in preview_order:
			var before := float(bonuses.get(stat, 0.0))
			var after := float(next_bonuses.get(stat, 0.0))
			if is_equal_approx(before, 0.0) and is_equal_approx(after, 0.0):
				continue
			var rate := stat in ["health_rate", "damage_rate", "speed"]
			var label: String = str({"health_rate": "HP", "damage_rate": "DMG", "strength": "STR", "defense": "DEF", "vitality": "VIT", "speed": "SPD"}.get(stat, stat.to_upper()))
			preview_rows.append("%s %.1f>%.1f%s" % [label, before, after, "%" if rate else ""])
		for row_index in preview_stats.size():
			if row_index < preview_rows.size():
				preview_stats[row_index].texture = pixel_texture.call(preview_rows[row_index], Color8(167, 240, 112)) as Texture2D
				preview_stats[row_index].visible = true
			else:
				preview_stats[row_index].texture = null
				preview_stats[row_index].visible = false
	else:
		details[1].texture = pixel_texture.call(selected_transmutation_name, Color8(148, 220, 255)) as Texture2D if not selected_transmutation_name.is_empty() else null
	action.disabled = sold or (page == 2 and profile.gold < price) or (page == 1 and equipped) or (page == 3 and (not can_fuse and not overflow or (can_fuse and profile.gold < profile.fusion_batch_cost(item, fusion_count))))
	var label := action.get_child(0) as Sprite2D
	if label != null: label.texture = pixel_texture.call("BUY" if page == 2 else ("SALVAGE" if page == 3 and overflow else ("FUSE x%d" % fusion_count if page == 3 else "EQUIP")), Color.WHITE) as Texture2D
	set_archetype_button_state(action, true, highlight_color)


func _update_hub_gear_slots(root: Object, pixel_texture: Callable, profile: PlayerProfile, catalog: ItemCatalog, item_list: Array[Sprite2D], choices: Array[Sprite2D], details: Array[Sprite2D], action: Button, highlight_color: Color) -> void:
	var selected_slot_index := clampi(int(root.get("hub_item_index")), 0, ItemCatalog.SLOTS.size() - 1)
	var candidate_indices := root.get("hub_gear_candidate_indices") as Dictionary
	var browsing := bool(root.get("hub_gear_browsing"))
	var selected_candidate: ItemInstance = null
	for detail in details:
		detail.visible = false
	for row in item_list.size():
		if row >= ItemCatalog.SLOTS.size():
			item_list[row].texture = null
			continue
		var slot := ItemCatalog.SLOTS[row]
		var shown_item := profile.find_item(str(profile.equipped_instance_ids.get(String(slot), "")))
		if row == selected_slot_index:
			selected_candidate = shown_item
		var slot_name: String = ["WPN", "ARM", "SHD", "ACC"][row]
		var shown_name := "EMPTY"
		var shown_color := Color8(140, 145, 160)
		if shown_item != null:
			shown_name = str(ItemCatalog.DEFINITIONS.get(shown_item.definition_id, {}).get("name", "ITEM"))
			var shown_mastery := shown_item.enhancement_level
			if shown_mastery > 0: shown_name += " +%d" % shown_mastery
			shown_color = catalog.rarity_color(shown_item.rarity)
		var prefix := ">" if row == selected_slot_index else " "
		item_list[row].texture = pixel_texture.call("%s%s: %s" % [prefix, slot_name, shown_name], shown_color) as Texture2D
	for choice in choices: choice.texture = null
	if browsing:
		var selected_slot := ItemCatalog.SLOTS[selected_slot_index]
		var slot_candidates := root.call("_hub_gear_candidates", selected_slot) as Array[ItemInstance]
		var current_index := posmod(int(candidate_indices.get(String(selected_slot), 0)), maxi(slot_candidates.size(), 1))
		if not slot_candidates.is_empty(): selected_candidate = slot_candidates[current_index]
		var window_start := clampi(current_index - 1, 0, maxi(slot_candidates.size() - choices.size(), 0))
		for choice_row in choices.size():
			var choice_index := window_start + choice_row
			if choice_index >= slot_candidates.size(): break
			var choice_item := slot_candidates[choice_index]
			var choice_prefix := ">" if choice_index == current_index else " "
			var is_unequip := choice_item.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID
			var choice_label := "%s%s" % [choice_prefix, "UNEQUIP SHIELD" if is_unequip else "%s %s" % [String(choice_item.rarity).substr(0, 1).to_upper(), str(ItemCatalog.DEFINITIONS.get(choice_item.definition_id, {}).get("name", "ITEM"))]]
			var choice_mastery := choice_item.enhancement_level
			if choice_mastery > 0: choice_label += " +%d" % choice_mastery
			choices[choice_row].texture = pixel_texture.call(choice_label, Color8(140, 145, 160) if is_unequip else catalog.rarity_color(choice_item.rarity)) as Texture2D
			details[0].texture = null; details[1].texture = null
		action.visible = false
		if selected_candidate != null:
			_update_gear_comparison_stats(root, pixel_texture, profile, catalog, selected_candidate, selected_slot_index, true)
		return
	else:
		for choice in choices: choice.visible = false
	details[0].visible = true; details[1].visible = true
	details[0].position = Vector2(6, 75); details[1].position = Vector2(6, 80)
	if details.size() > 2: details[2].position = Vector2(6, 87)
	if details.size() > 3: details[3].position = Vector2(6, 94)
	action.position = Vector2(26, 101)
	if selected_candidate == null:
		var available_candidates := root.call("_hub_gear_candidates", ItemCatalog.SLOTS[selected_slot_index]) as Array[ItemInstance]
		if selected_slot_index == ItemCatalog.SLOTS.find(&"shield") and not available_candidates.is_empty():
			details[0].texture = pixel_texture.call("NO SHIELD EQUIPPED", Color8(255, 205, 117)) as Texture2D
			details[1].texture = pixel_texture.call("SELECT FROM INVENTORY", Color8(148, 220, 255)) as Texture2D
			action.disabled = false
			action.visible = true
		else:
			details[0].texture = pixel_texture.call("NO GEAR FOR THIS SLOT", Color8(255, 205, 117)) as Texture2D
			action.disabled = true
			action.visible = false
		var empty_label := action.get_child(0) as Sprite2D
		if empty_label != null: empty_label.texture = pixel_texture.call("SELECT", Color.WHITE) as Texture2D
		return
	_update_gear_comparison_stats(root, pixel_texture, profile, catalog, selected_candidate, selected_slot_index, browsing)
	details[0].texture = null
	var transmutation_name := catalog.transmutation_name(selected_candidate.transmutation_id)
	details[1].texture = pixel_texture.call("SPECIAL: %s" % transmutation_name, Color8(148, 220, 255)) as Texture2D if not transmutation_name.is_empty() else null
	_set_transmutation_description(details, pixel_texture, catalog.transmutation_description(selected_candidate.transmutation_id))
	if selected_slot_index == ItemCatalog.SLOTS.find(&"shield"):
		var shield_values := catalog.shield_bonuses(selected_candidate)
		if details.size() > 2:
			details[2].texture = pixel_texture.call("BLOCK +%d  ARM +%d%%" % [roundi(float(shield_values.get("guard_durability", 0.0))), roundi(float(shield_values.get("guard_reduction", 0.0)))], Color8(148, 220, 255)) as Texture2D
			details[2].visible = true
		if details.size() > 3:
			details[3].texture = pixel_texture.call("ATK -%d%%  DMG -%d%%" % [roundi(float(shield_values.get("strength_penalty", 0.0))), roundi(float(shield_values.get("damage_penalty", 0.0)))], Color8(239, 125, 87)) as Texture2D
			details[3].visible = true
	action.disabled = false
	action.visible = not browsing
	var label := action.get_child(0) as Sprite2D
	if label != null: label.texture = pixel_texture.call("SELECT", Color.WHITE) as Texture2D
	set_archetype_button_state(action, true, highlight_color)


func _set_transmutation_description(details: Array[Sprite2D], pixel_texture: Callable, description: String) -> void:
	for detail_index in range(2, details.size()):
		details[detail_index].texture = null
		details[detail_index].visible = false
	if description.is_empty():
		return
	var words := description.split(" ")
	var lines: Array[String] = []
	var line := ""
	for word in words:
		var candidate := word if line.is_empty() else "%s %s" % [line, word]
		if candidate.length() > 34 and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty(): lines.append(line)
	for line_index in mini(lines.size(), details.size() - 2):
		details[line_index + 2].texture = pixel_texture.call(lines[line_index], Color8(210, 220, 235)) as Texture2D
		details[line_index + 2].visible = true


func _update_gear_comparison_stats(root: Object, pixel_texture: Callable, profile: PlayerProfile, catalog: ItemCatalog, candidate: ItemInstance, slot_index: int, comparing: bool) -> void:
	var stats := root.get("hub_gear_stat_texts") as Array[Sprite2D]
	if bool(root.get("hub_pause_mode")) and not comparing:
		var snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot
		if snapshot != null:
			var tuning := root.get("combat_tuning") as CombatTuning
			var values := [roundi(CombatCalculator.max_health_for_snapshot(snapshot, tuning)), snapshot.vit, snapshot.strength, snapshot.def, snapshot.speed]
			for index in mini(stats.size(), values.size()):
				stats[index].texture = pixel_texture.call("%s %d" % [["HP", "VIT", "STR", "DEF", "SPD"][index], values[index]], Color8(167, 240, 112)) as Texture2D
		return
	var slot := ItemCatalog.SLOTS[clampi(slot_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var equipped := profile.find_item(str(profile.equipped_instance_ids.get(String(slot), "")))
	var candidate_bonuses := _effective_item_bonuses(catalog, candidate, profile.mastery_level(candidate.definition_id))
	var equipped_bonuses := _effective_item_bonuses(catalog, equipped, profile.mastery_level(equipped.definition_id)) if equipped != null else {}
	var fields := [{"key": "health_rate", "label": "HP", "rate": true}, {"key": "vitality", "label": "VIT", "rate": true}, {"key": "strength", "label": "STR", "rate": true}, {"key": "defense", "label": "DEF", "rate": true}, {"key": "speed", "label": "SPD", "rate": true}]
	for index in mini(stats.size(), fields.size()):
		var field: Dictionary = fields[index]
		var key := str(field["key"])
		var value := float(candidate_bonuses.get(key, 0.0)) - float(equipped_bonuses.get(key, 0.0)) if comparing else float(candidate_bonuses.get(key, 0.0))
		var prefix := "+" if value > 0 else "-" if value < 0 else ""
		var color := Color8(148, 220, 255) if value > 0 else Color8(239, 125, 87) if value < 0 else Color8(150, 156, 170)
		stats[index].texture = pixel_texture.call("%s %s%.1f%s" % [str(field["label"]), prefix, absf(value), "%" if bool(field["rate"]) else ""], color) as Texture2D


func _effective_item_bonuses(catalog: ItemCatalog, item: ItemInstance, mastery_level: int = 0) -> Dictionary:
	if item == null:
		return {}
	var result := catalog.bonuses(item, mastery_level)
	if catalog.definition_slot(item.definition_id) == &"shield":
		var shield_values := catalog.shield_bonuses(item)
		result["strength"] = float(result.get("strength", 0.0)) - float(shield_values.get("strength_penalty", 0.0))
		result["damage_rate"] = float(result.get("damage_rate", 0.0)) - float(shield_values.get("damage_penalty", 0.0))
		result["speed"] = float(result.get("speed", 0.0)) - float(shield_values.get("speed_penalty", 0.0))
	return result

func update_hub_input(root: Object) -> void:
	var row := int(root.get("hub_menu_row"))
	var page := int(root.get("hub_page"))
	var interact_down := bool(root.call("_is_interact_input_pressed"))
	var interact_pressed := interact_down and not bool(root.get("hub_interact_input_was_down"))
	root.set("hub_interact_input_was_down", interact_down)
	var previous_page_down := bool(root.call("_is_hub_previous_page_input_pressed"))
	var next_page_down := bool(root.call("_is_hub_next_page_input_pressed"))
	var previous_page_pressed := previous_page_down and not bool(root.get("hub_page_previous_input_was_down"))
	var next_page_pressed := next_page_down and not bool(root.get("hub_page_next_input_was_down"))
	root.set("hub_page_previous_input_was_down", previous_page_down)
	root.set("hub_page_next_input_was_down", next_page_down)
	var cancel_down := bool(root.call("_is_menu_cancel_input_pressed"))
	var cancel_pressed := cancel_down and not bool(root.get("hub_cancel_input_was_down"))
	root.set("hub_cancel_input_was_down", cancel_down)
	if cancel_pressed:
		if page == 1 and bool(root.get("hub_gear_browsing")): root.call("_close_hub_gear_browse")
		else: root.call("_close_hub_to_run")
		return
	if bool(root.get("hub_pause_mode")):
		if bool(root.get("hub_gear_browsing")):
			if Input.is_action_just_pressed("ui_up"): root.call("_shift_hub_gear_candidate", -1)
			elif Input.is_action_just_pressed("ui_down"): root.call("_shift_hub_gear_candidate", 1)
			elif Input.is_action_just_pressed("ui_accept") or interact_pressed: root.call("_hub_item_action")
			return
		if Input.is_action_just_pressed("ui_up"): root.call("_shift_hub_item", -1)
		elif Input.is_action_just_pressed("ui_down"): root.call("_shift_hub_item", 1)
		elif Input.is_action_just_pressed("ui_accept") or interact_pressed:
			var pause_action := root.get("hub_item_action_button") as Button
			if pause_action != null and not pause_action.disabled: pause_action.pressed.emit()
		return
	if previous_page_pressed:
		root.call("_set_hub_page", page - 1); return
	if next_page_pressed:
		root.call("_set_hub_page", page + 1); return
	if page != 0:
		if page == 1 and bool(root.get("hub_gear_browsing")):
			if Input.is_action_just_pressed("ui_up"): root.call("_shift_hub_gear_candidate", -1)
			elif Input.is_action_just_pressed("ui_down"): root.call("_shift_hub_gear_candidate", 1)
			elif Input.is_action_just_pressed("ui_accept") or interact_pressed:
				root.call("_hub_item_action")
			elif Input.is_action_just_pressed("ui_cancel"): root.call("_close_hub_gear_browse")
			return
		if Input.is_action_just_pressed("ui_up"): root.call("_shift_hub_item", -1)
		elif Input.is_action_just_pressed("ui_down"): root.call("_shift_hub_item", 1)
		elif page == 1 and Input.is_action_just_pressed("ui_left"): root.call("_shift_hub_gear_candidate", -1)
		elif page == 1 and Input.is_action_just_pressed("ui_right"): root.call("_shift_hub_gear_candidate", 1)
		elif page == 3 and Input.is_action_just_pressed("ui_left"): root.call("_shift_hub_fusion_count", -1)
		elif page == 3 and Input.is_action_just_pressed("ui_right"): root.call("_shift_hub_fusion_count", 1)
		elif Input.is_action_just_pressed("ui_accept") or interact_pressed:
			var action := root.get("hub_item_action_button") as Button
			if action != null and not action.disabled: action.pressed.emit()
		elif Input.is_action_just_pressed("ui_cancel"): root.call("_set_hub_page", 0)
		return
	if Input.is_action_just_pressed("ui_up"):
		root.call("_select_hub_menu_row", row - 1)
	elif Input.is_action_just_pressed("ui_down"):
		root.call("_select_hub_menu_row", row + 1)
	elif Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
		var direction := -1 if Input.is_action_just_pressed("ui_left") else 1
		if row < 4:
			root.call("_hub_adjust_stat", [&"VIT", &"STR", &"DEF", &"SPD"][row], direction)
		else:
			root.call("_shift_hub_action_column", direction)
	elif Input.is_action_just_pressed("ui_accept") or interact_pressed:
		if row < 4:
			root.call("_select_hub_menu_row", row + 1)
		elif row == 4:
			var utility_button := [root.get("hub_apply_button"), root.get("hub_cancel_button"), root.get("hub_auto_button"), root.get("hub_respec_button")][int(root.get("hub_action_column"))] as Button
			if utility_button != null and not utility_button.disabled: utility_button.pressed.emit()
		else:
			var exit_button := [root.get("hub_start_button"), root.get("hub_title_button")][int(root.get("hub_action_column"))] as Button
			if exit_button != null and not exit_button.disabled: exit_button.pressed.emit()
	elif Input.is_action_just_pressed("ui_cancel"):
		if bool(root.get("hub_opened_from_npc")): root.call("_close_hub_to_run")
		else: root.call("_return_to_title")


func build_title(parent: Node, pixel_texture: Callable, new_game_callback: Callable, continue_callback: Callable, has_profile: bool) -> Dictionary:
	var overlay := create_overlay(parent, "TitleOverlay", Vector2(240, 160), Color.BLACK, 2)
	var title_texture := pixel_texture.call("TINY DEMONS", Color.WHITE) as Texture2D
	var title_text := create_sprite(overlay, "TitleText", title_texture, Vector2((240.0 - title_texture.get_width() * 3.0) * 0.5, 48), false, Vector2(3, 3))
	var new_game_button := make_retro_button("NEW GAME", Vector2(88, 102), Vector2(64, 14), pixel_texture)
	new_game_button.pressed.connect(new_game_callback)
	overlay.add_child(new_game_button)
	var continue_button := make_retro_button("CONTINUE", Vector2(88, 120), Vector2(64, 14), pixel_texture)
	continue_button.pressed.connect(continue_callback)
	continue_button.disabled = not has_profile
	overlay.add_child(continue_button)
	var cursor := create_sprite(overlay, "TitleCursor", pixel_texture.call(">", Color.WHITE) as Texture2D, Vector2(80, 106 if not has_profile else 124), false)
	(continue_button if has_profile else new_game_button).grab_focus()
	return {"overlay": overlay, "text": title_text, "new_game": new_game_button, "continue": continue_button, "start_text": new_game_button.get_child(0) as Sprite2D, "cursor": cursor}

func build_save_select(parent: Node, pixel_texture: Callable, select_callback: Callable, overwrite_yes: Callable = Callable(), overwrite_no: Callable = Callable(), preview_texture: Callable = Callable()) -> ColorRect:
	var overlay := create_overlay(parent, "SaveSelectOverlay", Vector2(240, 160), Color.BLACK, 4, false)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var title := create_sprite(overlay, "SaveSelectTitle", pixel_texture.call("CHOOSE SAVE", Color.WHITE) as Texture2D, Vector2(88, 42), false)
	var cursor := create_sprite(overlay, "SaveSelectCursor", pixel_texture.call(">", Color.WHITE) as Texture2D, Vector2(55, 70), false)
	var prompt := create_sprite(overlay, "OverwritePrompt", pixel_texture.call("OVERWRITE?  YES / NO", Color.WHITE) as Texture2D, Vector2(70, 126), false)
	prompt.visible = false
	var prompt_cursor := create_sprite(overlay, "OverwriteCursor", pixel_texture.call(">", Color.WHITE) as Texture2D, Vector2(99, 140), false); prompt_cursor.visible = false
	var yes := make_retro_button("YES", Vector2(105, 137), Vector2(24, 12), pixel_texture); yes.name = "OverwriteYes"; yes.visible = false; yes.pressed.connect(overwrite_yes); overlay.add_child(yes)
	var no := make_retro_button("NO", Vector2(135, 137), Vector2(20, 12), pixel_texture); no.name = "OverwriteNo"; no.visible = false; no.pressed.connect(overwrite_no); overlay.add_child(no)
	for slot in ProfileSaveService.SLOT_COUNT:
		var profile := ProfileSaveService.load_profile_for_slot(slot)
		var label := "SAVE %d  EMPTY" % (slot + 1)
		if profile != null and profile.has_started:
			label = "SAVE %d  LV %d  G %d" % [slot + 1, profile.level, profile.gold]
		var button := make_retro_button(label, Vector2(64, 66 + slot * 20), Vector2(112, 14), pixel_texture)
		button.disabled = false
		button.set_meta("save_slot", slot)
		button.pressed.connect(select_callback.bind(slot))
		overlay.add_child(button)
		if profile != null and profile.has_started and preview_texture.is_valid():
			var demon := Sprite2D.new()
			demon.name = "Save%dPreview" % slot
			demon.texture = preview_texture.call(profile.palette_name) as Texture2D
			demon.position = Vector2(58, 73 + slot * 20)
			demon.scale = Vector2.ONE * 0.55
			demon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			overlay.add_child(demon)
	return overlay


func build_archetype(parent: Node, shift_type: Callable, shift_color: Callable, start_callback: Callable, pixel_texture: Callable) -> Dictionary:
	var overlay := create_overlay(parent, "ArchetypeOverlay", Vector2(240, 160), Color.BLACK, 1, false)
	var preview := create_sprite(overlay, "ArchetypePreview", null, Vector2(0, 43), false, Vector2(1.5, 1.5))
	var name_text := create_sprite(overlay, "ArchetypeName", null, Vector2.ZERO, false)
	var left_buttons: Array[Button] = []
	var right_buttons: Array[Button] = []
	for side in [-1, 1]:
		var button := make_archetype_arrow(overlay, side, Vector2(75 if side < 0 else 155, 69), shift_color.bind(side), pixel_texture)
		(left_buttons if side < 0 else right_buttons).append(button)
	var left_type := make_archetype_arrow(overlay, -1, Vector2(75, 33), shift_type.bind(-1), pixel_texture)
	var right_type := make_archetype_arrow(overlay, 1, Vector2(155, 33), shift_type.bind(1), pixel_texture)
	var start_button := make_retro_button("START", Vector2(99, 104), Vector2(42, 14), pixel_texture)
	start_button.pressed.connect(start_callback)
	overlay.add_child(start_button)
	var hold_cover := create_overlay(overlay, "ArchetypeHoldCover", Vector2(240, 160), Color.BLACK, 10)
	return {"overlay": overlay, "preview": preview, "name": name_text, "left": left_buttons, "right": right_buttons, "type_left": left_type, "type_right": right_type, "start": start_button, "cover": hold_cover}


func make_archetype_arrow(parent: Node, side: int, button_position: Vector2, pressed_callback: Callable, pixel_texture: Callable) -> Button:
	var button := Button.new(); button.position = button_position; button.size = Vector2(10, 10); button.text = ""; button.focus_mode = Control.FOCUS_NONE; button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND; button.set_meta("archetype_arrow", true)
	for style_state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new(); style.bg_color = Color.TRANSPARENT; style.border_width_left = 0; style.border_width_top = 0; style.border_width_right = 0; style.border_width_bottom = 0; button.add_theme_stylebox_override(style_state, style)
	var glyph := Sprite2D.new(); glyph.texture = pixel_texture.call("<" if side < 0 else ">", Color.WHITE) as Texture2D; glyph.centered = true; glyph.position = button.size * 0.5; glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; button.add_child(glyph)
	button.pressed.connect(pressed_callback); parent.add_child(button); return button


func build_loading(parent: Node, pixel_texture: Callable) -> Dictionary:
	var overlay := create_overlay(parent, "LoadingScreen", Vector2(240, 160), Color.BLACK, 4090, false)
	var text := create_sprite(overlay, "LoadingText", pixel_texture.call("LOADING", Color.WHITE) as Texture2D, Vector2.ZERO, false, Vector2.ONE, 4091)
	text.position = Vector2(240, 160) - text.texture.get_size() - Vector2(4, 4)
	return {"overlay": overlay, "text": text}


func update_loading(overlay: ColorRect, text: Sprite2D, fading: bool, timer: float, delta: float, pixel_texture: Callable) -> Dictionary:
	if fading:
		timer += delta
		overlay.modulate.a = clampf(1.0 - timer / 0.35, 0.0, 1.0)
		if timer >= 0.35:
			fading = false
			overlay.visible = false
			set_state(&"gameplay")
		return {"fading": fading, "timer": timer, "finished": timer >= 0.35}
	timer += delta
	var labels := ["LOADING", "LOADING.", "LOADING..", "LOADING..."]
	text.texture = pixel_texture.call(labels[mini(int(timer / 0.28) % 4, 3)], Color.WHITE) as Texture2D
	text.position = Vector2(240, 160) - text.texture.get_size() - Vector2(4, 4)
	return {"fading": fading, "timer": timer, "finished": false}


func _make_text_button(label: String, button_position: Vector2, normal_style: StyleBoxFlat, focus_style: StyleBoxFlat, pixel_texture: Callable, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = Vector2(42, 12)
	button.text = ""
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", normal_style)
	button.add_theme_stylebox_override("hover", focus_style)
	button.add_theme_stylebox_override("focus", focus_style)
	var text := Sprite2D.new()
	text.texture = pixel_texture.call(label, Color.WHITE) as Texture2D
	text.centered = true
	text.position = button.size * 0.5
	text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(text)
	button.pressed.connect(pressed_callback)
	return button


func create_overlay(parent: Node, overlay_name: String, size: Vector2, color: Color, z_index: int, visible: bool = true) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = overlay_name
	overlay.position = Vector2.ZERO
	overlay.size = size
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = z_index
	overlay.visible = visible
	parent.add_child(overlay)
	return overlay


func create_sprite(parent: Node, sprite_name: String, texture: Texture2D, sprite_position: Vector2, centered: bool, scale: Vector2 = Vector2.ONE, z_index: int = 0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.centered = centered
	sprite.position = sprite_position
	sprite.scale = scale
	sprite.z_index = z_index
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite
