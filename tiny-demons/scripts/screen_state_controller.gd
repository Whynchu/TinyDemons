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


func spawn_button_frame_breakup(button: Button, particle_parent: Node, pixel_texture: Callable) -> void:
	if button == null:
		return
	var origin := button.position
	var width := int(button.size.x)
	var height := int(button.size.y)
	for x in range(width):
		_spawn_frame_particle(origin + Vector2(x, 0), particle_parent, pixel_texture)
		_spawn_frame_particle(origin + Vector2(x, height - 1), particle_parent, pixel_texture)
	for y in range(1, height - 1):
		_spawn_frame_particle(origin + Vector2(0, y), particle_parent, pixel_texture)
		_spawn_frame_particle(origin + Vector2(width - 1, y), particle_parent, pixel_texture)


func _spawn_frame_particle(frame_position: Vector2, particle_parent: Node, pixel_texture: Callable) -> void:
	var particle := Sprite2D.new()
	particle.texture = pixel_texture.call(Color.WHITE) as Texture2D
	particle.centered = false
	particle.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	particle.z_as_relative = true
	particle.z_index = 3
	particle.position = frame_position
	particle_parent.add_child(particle)
	add_particle({"sprite": particle, "velocity": Vector2(0.0, -10.0), "timer": 1.14, "lifetime": 1.14, "gravity": 0.0})


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
	return {"overlay": overlay, "text": title_text, "button": button}


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
