extends Node
class_name ScreenStateController

signal state_changed(state: StringName)
var state: StringName = &"gameplay"
var title_particles: Array[Dictionary] = []


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
		root.call("_update_title_particles", delta)
		var timer := float(root.get("title_transition_timer")) + delta
		root.set("title_transition_timer", timer)
		var overlay := root.get("title_overlay") as ColorRect
		var fade_start := 0.72
		var fade_duration := 0.42
		overlay.modulate.a = 1.0 if timer < fade_start else clampf(1.0 - (timer - fade_start) / fade_duration, 0.0, 1.0)
		if timer >= fade_start + fade_duration:
			root.set("title_transition_active", false)
			overlay.visible = false
			root.set("archetype_transition_timer", -0.35)
			root.call("_select_archetype_menu_row", 0)
		return
	var frame_timer := float(root.get("title_frame_timer")) + delta
	root.set("title_frame_timer", frame_timer)
	var button := root.get("title_start_button") as Button
	if button != null:
		button.modulate.a = root.call("_retro_button_alpha", frame_timer)
		button.position.y = 103.0 + root.call("_retro_button_bob", frame_timer)
	if Input.is_action_just_pressed("ui_accept") or root.call("_is_interact_input_pressed"):
		root.call("_start_from_title")


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
	root.set("archetype_frame_timer", float(root.get("archetype_frame_timer")) + delta)
	root.set("archetype_arrow_anim_timer", maxf(float(root.get("archetype_arrow_anim_timer")) - delta, 0.0))
	root.call("_update_archetype_arrow_animation")
	var button := root.get("archetype_start_button") as Button
	button.modulate.a = root.call("_retro_button_alpha", root.get("archetype_frame_timer"))
	button.position.y = 127.0 + root.call("_retro_button_bob", root.get("archetype_frame_timer"))
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
	(root.get("player_stats") as StatsComponent).allocation_profile = root.get("selected_archetype")
	var palette_name: String = ["blue", "orange", "green", "red", "yellow", "grey"][int(root.get("archetype_color_index"))]
	root.set("player_palette_name", palette_name)
	root.set("loading_screen_active", true)
	set_state(&"loading")
	root.set("loading_screen_fading", false)
	root.set("loading_screen_timer", 0.0)
	var loading_overlay := root.get("loading_screen_overlay") as ColorRect
	loading_overlay.visible = true; loading_overlay.modulate.a = 1.0
	overlay.visible = false
	(root.get("archetype_hold_cover") as ColorRect).visible = false
	var title_overlay := root.get("title_overlay") as ColorRect
	if title_overlay != null: title_overlay.visible = false
	await root.get_tree().process_frame
	await root.call("_apply_player_palette_async", palette_name)
	root.call("_update_player_aggro_marker_colors")
	var player_health := float(root.call("_player_max_health"))
	root.set("player_health", player_health)
	var health := root.get("player_health_component") as HealthComponent
	if health != null: health.maximum_health = player_health; health.reset(player_health)
	root.set("player_display_health", player_health)
	root.set("player_damage_fill_hold_timer", 0.0)
	root.call("_update_player_health_ui")
	(root.get("player") as Sprite2D).visible = true
	root.call("_apply_player_animation_frame")
	root.set("loading_screen_fading", true); root.set("loading_screen_timer", 0.0)


func start_from_title(root: Object) -> void:
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
	if title_text != null: title_text.visible = false
	if start_text != null: start_text.visible = false
	if start_button != null: start_button.visible = false; start_button.release_focus()
	var archetype_overlay := root.get("archetype_overlay") as ColorRect
	archetype_overlay.visible = true; set_state(&"archetype")
	archetype_overlay.modulate.a = 1.0
	(root.get("archetype_hold_cover") as ColorRect).visible = true
	root.set("archetype_transition_active", true); root.set("archetype_transition_timer", -1.0); root.set("archetype_fade_out", false)


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
		if restart != null: restart.modulate.a = root.call("_retro_button_alpha", fade_timer); restart.position.y = 105.0 + root.call("_retro_button_bob", fade_timer)
		if title != null: title.modulate.a = root.call("_retro_button_alpha", fade_timer + 0.6); title.position.y = 121.0 + root.call("_retro_button_bob", fade_timer + 0.4)
	elif death_timer >= death_effect_end + float(root.get("player_tuning").death_observe_time):
		root.call("_show_game_over")


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
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 0)
	normal_style.border_color = Color(0.72, 0.72, 0.72, 0.9)
	normal_style.set_border_width_all(1)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(1, 1, 1, 0.12)
	focus_style.border_color = Color.WHITE
	focus_style.set_border_width_all(1)
	var restart_button := _make_text_button("RESTART", Vector2(99, 105), normal_style, focus_style, pixel_texture, restart)
	var title_button := _make_text_button("TITLE", Vector2(99, 121), normal_style, focus_style, pixel_texture, return_title)
	overlay.add_child(restart_button)
	overlay.add_child(title_button)
	return {"overlay": overlay, "restart": restart_button, "title": title_button}


func build_title(parent: Node, pixel_texture: Callable, start_callback: Callable) -> Dictionary:
	var overlay := create_overlay(parent, "TitleOverlay", Vector2(240, 160), Color.BLACK, 2)
	var title_texture := pixel_texture.call("TINY DEMONS", Color.WHITE) as Texture2D
	var title_text := create_sprite(overlay, "TitleText", title_texture, Vector2((240.0 - title_texture.get_width() * 3.0) * 0.5, 48), false, Vector2(3, 3))
	var button := make_retro_button("START", Vector2(99, 103), Vector2(42, 14), pixel_texture)
	button.pressed.connect(start_callback)
	overlay.add_child(button)
	button.grab_focus()
	return {"overlay": overlay, "text": title_text, "button": button, "start_text": button.get_child(0) as Sprite2D}


func build_archetype(parent: Node, style_button: Callable, shift_type: Callable, shift_color: Callable, start_callback: Callable, pixel_texture: Callable) -> Dictionary:
	var overlay := create_overlay(parent, "ArchetypeOverlay", Vector2(240, 160), Color.BLACK, 1, false)
	var preview := create_sprite(overlay, "ArchetypePreview", null, Vector2(102, 28), false, Vector2(3, 3))
	var name_text := create_sprite(overlay, "ArchetypeName", null, Vector2.ZERO, false)
	var left_buttons: Array[Button] = []
	var right_buttons: Array[Button] = []
	for side in [-1, 1]:
		var button := Button.new()
		button.text = "<" if side < 0 else ">"
		button.position = Vector2(48 if side < 0 else 178, 42)
		button.size = Vector2(14, 14)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		style_button.call(button)
		button.pressed.connect(shift_color.bind(side))
		overlay.add_child(button)
		(left_buttons if side < 0 else right_buttons).append(button)
	var left_type := Button.new()
	left_type.text = "<"
	left_type.position = Vector2(58, 15)
	left_type.size = Vector2(14, 14)
	left_type.focus_mode = Control.FOCUS_NONE
	style_button.call(left_type)
	left_type.pressed.connect(shift_type.bind(-1))
	overlay.add_child(left_type)
	var right_type := Button.new()
	right_type.text = ">"
	right_type.position = Vector2(168, 15)
	right_type.size = Vector2(14, 14)
	right_type.focus_mode = Control.FOCUS_NONE
	style_button.call(right_type)
	right_type.pressed.connect(shift_type.bind(1))
	overlay.add_child(right_type)
	var start_button := make_retro_button("START", Vector2(99, 127), Vector2(42, 14), pixel_texture)
	start_button.pressed.connect(start_callback)
	overlay.add_child(start_button)
	var hold_cover := create_overlay(overlay, "ArchetypeHoldCover", Vector2(240, 160), Color.BLACK, 10)
	return {"overlay": overlay, "preview": preview, "name": name_text, "left": left_buttons, "right": right_buttons, "type_left": left_type, "type_right": right_type, "start": start_button, "cover": hold_cover}


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
