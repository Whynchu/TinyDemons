extends RefCounted
class_name TitleScreenPresenter

const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")

var overlay: ColorRect = null
var title_text: Sprite2D = null
var start_button: Button = null
var continue_button: Button = null
var settings_button: Button = null
var cloud_button: Button = null
var start_text: Sprite2D = null
var settings_text: Sprite2D = null
var cursor_text: Sprite2D = null
var menu_row := 0
var frame_timer := 0.0
var command_list: MenuCommandList = null
var transition_active := false
var transition_timer := 0.0
var pending_destination := ""


func build(parent: Node, view_size: Vector2, version: String, pixel_texture: Callable, new_game_callback: Callable, continue_callback: Callable, has_profile: bool, settings_callback: Callable, cloud_callback: Callable, widget_factory: MenuWidgetFactory) -> Dictionary:
	overlay = widget_factory.create_overlay(parent, "TitleOverlay", view_size, Color.BLACK, 2)
	overlay.set_meta("display_full_view", true)
	var title_texture := pixel_texture.call("TINY DEMONS", Color.WHITE) as Texture2D
	title_text = widget_factory.create_sprite(overlay, "TitleText", title_texture, Vector2((view_size.x - title_texture.get_width() * 3.0) * 0.5, 48), false, Vector2(3, 3))
	var version_text := widget_factory.create_sprite(overlay, "TitleVersion", pixel_texture.call(version, Color8(148, 220, 255)) as Texture2D, Vector2(4, view_size.y - 8.0), false)
	start_button = _make_title_button(overlay, "NEW GAME", 93.0, view_size, pixel_texture, new_game_callback, widget_factory)
	continue_button = _make_title_button(overlay, "CONTINUE", 109.0, view_size, pixel_texture, continue_callback, widget_factory)
	continue_button.disabled = not has_profile
	continue_button.visible = has_profile
	cloud_button = _make_title_button(overlay, "CLOUD SAVE", 125.0, view_size, pixel_texture, cloud_callback, widget_factory)
	settings_button = _make_title_button(overlay, "SETTINGS", 141.0, view_size, pixel_texture, settings_callback, widget_factory)
	cursor_text = widget_factory.create_sprite(overlay, "TitleCursor", MENU_CURSOR_TEXTURE, Vector2((view_size.x - 64.0) * 0.5 - 8.0, 97.0 if not has_profile else 113.0), false)
	start_text = start_button.get_child(0) as Sprite2D
	settings_text = settings_button.get_child(0) as Sprite2D
	menu_row = 1 if has_profile else 0
	command_list = MenuCommandList.new()
	command_list.configure([start_button, continue_button, cloud_button, settings_button], [93.0, 109.0, 125.0, 141.0])
	command_list.row = menu_row
	return {
		"overlay": overlay,
		"text": title_text,
		"version": version_text,
		"new_game": start_button,
		"continue": continue_button,
		"cloud": cloud_button,
		"settings": settings_button,
		"start_text": start_text,
		"settings_text": settings_text,
		"cursor": cursor_text,
	}


func refresh_menu_layout(has_profile: bool) -> void:
	if continue_button != null:
		continue_button.disabled = not has_profile
		continue_button.visible = has_profile
	var ordered: Array[Button] = [start_button, continue_button, cloud_button, settings_button]
	var visible_row := 0
	var available_rows: Array[int] = []
	for index in ordered.size():
		var button := ordered[index]
		if button == null or button.disabled or not button.visible:
			continue
		var base_y := 93.0 + visible_row * 16.0
		button.position.y = base_y
		button.set_meta("menu_base_y", base_y)
		available_rows.append(index)
		visible_row += 1
	if not available_rows.is_empty() and not available_rows.has(menu_row):
		menu_row = available_rows[0]
	if command_list != null:
		command_list.row = menu_row


func position_controls(view_size: Vector2, cursor_left_gap: float, cursor_animator: MenuCursorAnimator, tween_owner: Node) -> void:
	if overlay == null:
		return
	if title_text != null and title_text.texture != null:
		title_text.position.x = (view_size.x - title_text.texture.get_width() * title_text.scale.x) * 0.5
	var version := overlay.get_node_or_null("TitleVersion") as Sprite2D
	if version != null:
		version.position = Vector2(4.0, view_size.y - 8.0)
	var title_x := (view_size.x - 64.0) * 0.5
	for button in [start_button, continue_button, settings_button, cloud_button] as Array[Button]:
		if button != null:
			button.position.x = title_x
	if cursor_text == null or start_button == null:
		return
	var row_buttons: Array[Button] = [start_button, continue_button, cloud_button, settings_button]
	var row_selected := row_buttons[clampi(menu_row, 0, row_buttons.size() - 1)] if not row_buttons.is_empty() else null
	if row_selected != null:
		var base_y := float(row_selected.get_meta("menu_base_y", row_selected.position.y))
		var target := Vector2(row_selected.position.x - cursor_left_gap, base_y + 4.0)
		cursor_animator.move_menu_cursor(cursor_text, target, false, tween_owner)


func _make_title_button(parent: Node, label: String, base_y: float, view_size: Vector2, pixel_texture: Callable, callback: Callable, widget_factory: MenuWidgetFactory) -> Button:
	var button := widget_factory.make_retro_button(label, Vector2((view_size.x - 64.0) * 0.5, base_y), Vector2(64, 14), pixel_texture)
	button.set_meta("menu_base_y", base_y)
	button.focus_mode = Control.FOCUS_NONE
	if callback.is_valid():
		button.pressed.connect(callback)
	parent.add_child(button)
	return button
