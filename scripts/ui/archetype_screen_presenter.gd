extends RefCounted
class_name ArchetypeScreenPresenter

var overlay: ColorRect = null
var hold_cover: ColorRect = null
var preview: Sprite2D = null
var name_text: Sprite2D = null
var start_button: Button = null
var left_buttons: Array[Button] = []
var right_buttons: Array[Button] = []
var type_left_button: Button = null
var type_right_button: Button = null
var footer_text: Sprite2D = null
var preview_frames: Array[Texture2D] = []
var preview_palette := ""
var frame_timer := 0.0
var index := 0
var color_index := 0
var menu_row := 0
var transition_active := false
var transition_timer := 0.0
var fade_out := false
var arrow_anim_timer := 0.0
var arrow_anim_direction := 0
var selected_archetype := StatsComponent.AllocationProfile.BALANCED
var starter_flame_index := 0


func build(parent: Node, view_size: Vector2, shift_type: Callable, shift_color: Callable, start_callback: Callable, pixel_texture: Callable, widget_factory: MenuWidgetFactory) -> Dictionary:
	overlay = widget_factory.create_overlay(parent, "ArchetypeOverlay", view_size, Color.BLACK, 1, false)
	overlay.set_meta("display_full_view", true)
	preview = widget_factory.create_sprite(overlay, "ArchetypePreview", null, Vector2(0, 43), false, Vector2(1.5, 1.5))
	name_text = widget_factory.create_sprite(overlay, "ArchetypeName", null, Vector2.ZERO, false)
	left_buttons.clear()
	right_buttons.clear()
	for side in [-1, 1]:
		var button := make_arrow(overlay, side, Vector2(75 if side < 0 else 155, 69), shift_color.bind(side), pixel_texture)
		(left_buttons if side < 0 else right_buttons).append(button)
	# Flame owns identity selection; retain the old palette row as hidden layout compatibility.
	for button in left_buttons:
		button.visible = false
	for button in right_buttons:
		button.visible = false
	type_left_button = make_arrow(overlay, -1, Vector2(view_size.x * 0.5 - 45.0, 33), shift_type.bind(-1), pixel_texture)
	type_right_button = make_arrow(overlay, 1, Vector2(view_size.x * 0.5 + 35.0, 33), shift_type.bind(1), pixel_texture)
	start_button = widget_factory.make_retro_button("START", Vector2((view_size.x - 42.0) * 0.5, 104), Vector2(42, 14), pixel_texture)
	start_button.focus_mode = Control.FOCUS_NONE
	start_button.pressed.connect(start_callback)
	overlay.add_child(start_button)
	footer_text = widget_factory.create_sprite(overlay, "ArchetypeFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(view_size.x - 64.0, view_size.y - 18.0), false)
	hold_cover = widget_factory.create_overlay(overlay, "ArchetypeHoldCover", view_size, Color.BLACK, 10)
	hold_cover.set_meta("display_full_view", true)
	return {"overlay": overlay, "preview": preview, "name": name_text, "left": left_buttons, "right": right_buttons, "type_left": type_left_button, "type_right": type_right_button, "start": start_button, "cover": hold_cover}


func position_controls(view_size: Vector2) -> void:
	if overlay == null:
		return
	if hold_cover != null:
		hold_cover.size = view_size
	if type_left_button != null:
		type_left_button.position = Vector2(view_size.x * 0.5 - 45.0, 33.0)
	if type_right_button != null:
		type_right_button.position = Vector2(view_size.x * 0.5 + 35.0, 33.0)
	if start_button != null:
		start_button.position.x = (view_size.x - start_button.size.x) * 0.5
	for button in left_buttons:
		button.position = Vector2(view_size.x * 0.5 - 45.0, 69.0)
	for button in right_buttons:
		button.position = Vector2(view_size.x * 0.5 + 35.0, 69.0)
	if footer_text != null:
		footer_text.position = Vector2(view_size.x - 64.0, view_size.y - 18.0)


func make_arrow(parent: Node, side: int, button_position: Vector2, pressed_callback: Callable, pixel_texture: Callable, hit_size: Vector2 = Vector2(10, 10)) -> Button:
	var button := Button.new()
	button.position = button_position
	button.size = hit_size
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.set_meta("archetype_arrow", true)
	for style_state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT
		style.border_width_left = 0
		style.border_width_top = 0
		style.border_width_right = 0
		style.border_width_bottom = 0
		button.add_theme_stylebox_override(style_state, style)
	var glyph := Sprite2D.new()
	glyph.texture = pixel_texture.call("<" if side < 0 else ">", Color.WHITE) as Texture2D
	glyph.centered = true
	glyph.position = button.size * 0.5
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.add_child(glyph)
	button.pressed.connect(pressed_callback)
	parent.add_child(button)
	return button
