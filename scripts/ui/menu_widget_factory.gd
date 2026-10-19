extends RefCounted
class_name MenuWidgetFactory

const MENU_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/components/menu_screen.tscn")


func create_menu_screen(parent: Node, screen_name: String, view_size: Vector2, z_index: int, title_name: String, heading: String, pixel_texture: Callable) -> MenuScreen:
	var screen := MENU_SCREEN_SCENE.instantiate() as MenuScreen
	screen.name = screen_name
	screen.size = view_size
	screen.z_index = z_index
	screen.visible = false
	screen.set_heading(title_name, heading, pixel_texture)
	parent.add_child(screen)
	return screen


func retro_button_alpha(timer: float) -> float:
	var phase := fmod(timer, 2.4)
	var pulse := lerpf(1.0, 0.45, (phase - 0.6) / 0.9) if phase >= 0.6 and phase < 1.5 else lerpf(0.45, 1.0, (phase - 1.5) / 0.6) if phase >= 1.5 and phase < 2.1 else 1.0
	return snappedf(snappedf(pulse, 0.08), 0.125)


func retro_button_bob(timer: float) -> float:
	return snappedf(sin(timer / 3.6 * TAU) * 1.5, 0.5)


func set_archetype_button_state(button: Button, active: bool, color: Color) -> void:
	if button == null:
		return
	if bool(button.get_meta("archetype_arrow", false)):
		button.modulate = color if active else Color.WHITE
		return
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0, 0, 0, 0)
	normal.border_color = Color(color if active else Color.WHITE, 0.95 if active else 0.0)
	normal.set_border_width_all(1 if active else 0)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(color, 0.18 if active else 0.0)
	focus.border_color = color if active else Color.WHITE
	focus.set_border_width_all(1 if active else 0)
	button.add_theme_color_override("font_color", color if active else Color.WHITE)
	button.add_theme_color_override("font_hover_color", color if active else Color.WHITE)
	button.add_theme_color_override("font_focus_color", color if active else Color.WHITE)
	button.add_theme_color_override("font_disabled_color", color if active else Color(0.65, 0.65, 0.65))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", focus)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_stylebox_override("pressed", focus)
	button.add_theme_stylebox_override("disabled", focus if active else normal)
	for child in button.get_children():
		if child is Sprite2D:
			(child as Sprite2D).modulate = color if active else Color(0.65, 0.65, 0.65) if button.disabled else Color.WHITE


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
	# Pixel sprites provide the labels, so avoid a second, mismatched native tooltip.
	button.tooltip_text = ""
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


func make_menu_command_button(label: String, button_position: Vector2, size: Vector2, pixel_texture: Callable) -> Button:
	var button := make_retro_button(label, button_position, size, pixel_texture)
	button.focus_mode = Control.FOCUS_NONE
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	transparent.set_border_width_all(0)
	for style_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_state, transparent)
	return button


func resize_menu_frame(overlay: ColorRect, panel_size: Vector2) -> void:
	if overlay == null:
		return
	if overlay is MenuScreen:
		overlay.size = panel_size
		(overlay as MenuScreen).apply_layout()
		return
	var outer := overlay.get_node_or_null("FrameOuter") as Panel
	if outer != null:
		outer.size = panel_size
	var inner := overlay.get_node_or_null("FrameInner") as Panel
	if inner != null:
		inner.size = panel_size - Vector2(6, 6)


func menu_card_style() -> StyleBoxTexture:
	return MenuWindow.panel_style()


func make_menu_card(parent: Node, card_name: String, card_position: Vector2, card_size: Vector2) -> Panel:
	var card := Panel.new()
	card.name = card_name
	card.position = card_position
	card.size = card_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_theme_stylebox_override("panel", menu_card_style())
	parent.add_child(card)
	return card


func make_transparent_touch_button(parent: Node, button_name: String, button_position: Vector2, button_size: Vector2, callback: Callable = Callable(), callback_arg: Variant = null) -> Button:
	var button := Button.new()
	button.name = button_name
	button.position = button_position
	button.size = button_size
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	transparent.set_border_width_all(0)
	for style_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(style_state, transparent)
	if callback.is_valid():
		if callback_arg == null:
			button.pressed.connect(callback)
		else:
			button.pressed.connect(callback.bind(callback_arg))
	parent.add_child(button)
	return button


func make_text_button(label: String, button_position: Vector2, normal_style: StyleBoxFlat, focus_style: StyleBoxFlat, pixel_texture: Callable, pressed_callback: Callable) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = Vector2(42, 12)
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
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
	if sprite_name.contains("Cursor"):
		var cursor_script := load("res://scripts/ui/menu_cursor.gd") as Script
		if cursor_script != null:
			sprite.set_script(cursor_script)
	sprite.name = sprite_name
	sprite.texture = texture
	sprite.centered = centered
	sprite.position = sprite_position
	sprite.scale = scale
	sprite.z_index = 4095 if sprite_name.contains("Cursor") else z_index
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	parent.add_child(sprite)
	return sprite
