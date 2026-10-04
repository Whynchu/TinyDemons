extends RefCounted
class_name GameOverScreenPresenter

const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")

var overlay: ColorRect = null
var restart_button: Button = null
var title_button: Button = null
var cursor_text: Sprite2D = null
var footer_text: Sprite2D = null
var row := 0
var fade_timer := 0.0


func build(parent: Node, view_size: Vector2, pixel_texture: Callable, restart: Callable, return_title: Callable, widget_factory: MenuWidgetFactory) -> void:
	overlay = widget_factory.create_overlay(parent, "GameOverOverlay", view_size, Color(0.015, 0.02, 0.035, 1.0), 8, false)
	overlay.set_meta("display_full_view", true)
	overlay.modulate.a = 0.0
	var title_texture := pixel_texture.call("GAME OVER", Color.WHITE) as Texture2D
	widget_factory.create_sprite(overlay, "GameOverTitle", title_texture, Vector2((view_size.x - title_texture.get_width() * 3.0) * 0.5, 50), false, Vector2(3, 3))
	var saved_texture := pixel_texture.call("PROGRESS SAVED", Color8(167, 240, 112)) as Texture2D
	widget_factory.create_sprite(overlay, "GameOverSaved", saved_texture, Vector2((view_size.x - saved_texture.get_width()) * 0.5, 88), false)
	var normal_style := StyleBoxFlat.new()
	normal_style.bg_color = Color(0, 0, 0, 0)
	normal_style.border_color = Color(0.72, 0.72, 0.72, 0.9)
	normal_style.set_border_width_all(1)
	var focus_style := StyleBoxFlat.new()
	focus_style.bg_color = Color(1, 1, 1, 0.12)
	focus_style.border_color = Color.WHITE
	focus_style.set_border_width_all(1)
	restart_button = widget_factory.make_text_button("HUB", Vector2((view_size.x - 42.0) * 0.5, 105), normal_style, focus_style, pixel_texture, restart)
	title_button = widget_factory.make_text_button("TITLE", Vector2((view_size.x - 42.0) * 0.5, 121), normal_style, focus_style, pixel_texture, return_title)
	restart_button.set_meta("menu_base_y", 105.0)
	title_button.set_meta("menu_base_y", 121.0)
	restart_button.name = "GameOverHub"
	title_button.name = "GameOverTitle"
	overlay.add_child(restart_button)
	overlay.add_child(title_button)
	cursor_text = widget_factory.create_sprite(overlay, "GameOverCursor", MENU_CURSOR_TEXTURE, Vector2((view_size.x - 42.0) * 0.5 - 8.0, 108), false)
	footer_text = widget_factory.create_sprite(overlay, "GameOverFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(view_size.x - 64.0, view_size.y - 18.0), false)
	row = 0
	fade_timer = 0.0


func position_controls(view_size: Vector2, cursor_animator: MenuCursorAnimator, tween_owner: Node, cursor_left_gap: float) -> void:
	if overlay == null:
		return
	for label_name in [&"GameOverTitle", &"GameOverSaved"]:
		var label := overlay.get_node_or_null(NodePath(label_name)) as Sprite2D
		if label != null and label.texture != null:
			label.position.x = (view_size.x - label.texture.get_width() * label.scale.x) * 0.5
	if footer_text != null:
		footer_text.position = Vector2(view_size.x - 64.0, view_size.y - 18.0)
	if restart_button != null:
		restart_button.position.x = (view_size.x - restart_button.size.x) * 0.5
		restart_button.position.y = float(restart_button.get_meta("menu_base_y", 105.0))
	if title_button != null:
		title_button.position.x = (view_size.x - title_button.size.x) * 0.5
		title_button.position.y = float(title_button.get_meta("menu_base_y", 121.0))
	var selected := title_button if row == 1 and title_button != null and not title_button.disabled else restart_button
	if cursor_text != null:
		cursor_text.visible = selected != null
		if selected != null:
			var base_y := float(selected.get_meta("menu_base_y", selected.position.y))
			cursor_animator.move_menu_cursor(cursor_text, Vector2(selected.position.x - cursor_left_gap, base_y + 4.0), false, tween_owner)


func update_fade(timer: float, duration: float, prompt_texture: Texture2D, widget_factory: MenuWidgetFactory) -> void:
	fade_timer = timer
	if overlay != null:
		overlay.modulate.a = clampf(timer / duration, 0.0, 1.0)
	if restart_button != null:
		restart_button.modulate.a = widget_factory.retro_button_alpha(timer)
	if title_button != null:
		title_button.modulate.a = widget_factory.retro_button_alpha(timer + 0.6)
	if cursor_text != null:
		cursor_text.texture = MENU_CURSOR_TEXTURE
	if footer_text != null:
		footer_text.visible = true
		footer_text.texture = prompt_texture
