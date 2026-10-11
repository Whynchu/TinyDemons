extends RefCounted
class_name SettingsScreenPresenter

const MenuPromptTextureFactoryScript = preload("res://scripts/ui/menu_prompt_texture_factory.gd")
const MENU_CIRCLE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_CIRCLE_TEXTURE
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")

var overlay: ColorRect = null
var title_text: Sprite2D = null
var row_labels: Array[Sprite2D] = []
var value_buttons: Array[Button] = []
var left_buttons: Array[Button] = []
var right_buttons: Array[Button] = []
var option_buttons: Array[Array] = []
var option_labels: Array[Array] = []
var description_text: Sprite2D = null
var back_button: Button = null
var cursor_text: Sprite2D = null
var row := 0
var origin := &"title"
var interact_input_was_down := false

var _settings_service: SettingsService = null
var _view_size := Vector2.ZERO
var _cursor_left_gap := 10.0
var _widget_factory: MenuWidgetFactory = null
var _prompt_factory: MenuPromptTextureFactory = null
var _cursor_animator: MenuCursorAnimator = null
var _tween_owner: Node = null


func build(parent: Node, view_size: Vector2, pixel_texture: Callable, adjust_callback: Callable, close_callback: Callable, select_option_callback: Callable, widget_factory: MenuWidgetFactory, prompt_factory: MenuPromptTextureFactory, cursor_animator: MenuCursorAnimator, cursor_left_gap: float, tween_owner: Node, settings_service: SettingsService) -> Dictionary:
	_view_size = view_size
	_widget_factory = widget_factory
	_prompt_factory = prompt_factory
	_cursor_animator = cursor_animator
	_cursor_left_gap = cursor_left_gap
	_tween_owner = tween_owner
	_settings_service = settings_service
	overlay = widget_factory.create_overlay(parent, "SettingsOverlay", view_size, Color(0.015, 0.02, 0.035, 1.0), 8, false)
	overlay.set_meta("display_full_view", true)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	widget_factory.add_menu_frame(overlay, view_size)
	title_text = widget_factory.add_menu_title(overlay, "SettingsTitle", "SETTINGS", pixel_texture, view_size)
	option_buttons.clear()
	option_labels.clear()
	row_labels.clear()
	value_buttons.clear()
	left_buttons.clear()
	right_buttons.clear()
	var row_names := ["FULLSCREEN", "ASPECT", "PIXEL PERFECT", "MUSIC", "SFX", "VIBRATION", "DEBUG MENU"]
	var authored_options: Array[Array] = [["OFF", "ON"], ["FULL", "3:2", "16:10", "16:9"], ["OFF", "ON"], ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"], ["0", "10", "20", "30", "40", "50", "60", "70", "80", "90", "100"], ["OFF", "ON"], ["OFF", "ON"]]
	var option_start := maxf(90.0, view_size.x * 0.38)
	var row_pitch := minf(16.0, maxf(12.0, (view_size.y - 65.0) / maxf(float(row_names.size()), 1.0)))
	for index in row_names.size():
		var label := widget_factory.create_sprite(overlay, "SettingsLabel%d" % index, pixel_texture.call(row_names[index], Color.WHITE) as Texture2D, Vector2(14, 23.0 + index * row_pitch + 3.0), false)
		row_labels.append(label)
		var options_for_row: Array[Button] = []
		for choice_index in authored_options[index].size():
			var option_text: String = str(authored_options[index][choice_index])
			var option_button := widget_factory.make_retro_button(option_text, Vector2(option_start + choice_index * 14.0, 23.0 + index * row_pitch), Vector2(12, 12), pixel_texture)
			option_button.name = "SettingsOption%d_%d" % [index, choice_index]
			option_button.focus_mode = Control.FOCUS_NONE
			if select_option_callback.is_valid():
				option_button.pressed.connect(select_option_callback.bind(index, choice_index))
			overlay.add_child(option_button)
			options_for_row.append(option_button)
		option_buttons.append(options_for_row)
		option_labels.append(authored_options[index])
		var left := widget_factory.make_retro_button("<", Vector2(option_start - 20.0, 23.0 + index * row_pitch), Vector2(16, 12), pixel_texture)
		left.name = "SettingsLeft%d" % index
		left.focus_mode = Control.FOCUS_NONE
		if adjust_callback.is_valid():
			left.pressed.connect(adjust_callback.bind(index, -1))
		overlay.add_child(left)
		left_buttons.append(left)
		var value := widget_factory.make_retro_button("", Vector2(option_start, 23.0 + index * row_pitch), Vector2(65, 12), pixel_texture)
		value.name = "SettingsValue%d" % index
		if adjust_callback.is_valid():
			value.pressed.connect(adjust_callback.bind(index, 1))
		overlay.add_child(value)
		value_buttons.append(value)
		var right := widget_factory.make_retro_button(">", Vector2(option_start + 68.0, 23.0 + index * row_pitch), Vector2(16, 12), pixel_texture)
		right.name = "SettingsRight%d" % index
		right.focus_mode = Control.FOCUS_NONE
		if adjust_callback.is_valid():
			right.pressed.connect(adjust_callback.bind(index, 1))
		overlay.add_child(right)
		right_buttons.append(right)
		# Keep the legacy arrow/value controls available as hidden compatibility handles.
		left.visible = false
		value.visible = false
		right.visible = false
	description_text = widget_factory.create_sprite(overlay, "SettingsDescription", null, Vector2(14, 128), false)
	back_button = widget_factory.make_retro_button("BACK", Vector2(view_size.x - 68.0, view_size.y - 19.0), Vector2(60, 13), pixel_texture)
	back_button.name = "SettingsBack"
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.pressed.connect(close_callback)
	overlay.add_child(back_button)
	cursor_text = widget_factory.create_sprite(overlay, "SettingsCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false)
	position_controls(view_size)
	return {"overlay": overlay, "title": title_text, "labels": row_labels, "values": value_buttons, "left": left_buttons, "right": right_buttons, "options": option_buttons, "back": back_button, "description": description_text, "cursor": cursor_text}


func position_controls(view_size: Vector2) -> void:
	_view_size = view_size
	if overlay == null:
		return
	var option_start := maxf(90.0, view_size.x * 0.38)
	if title_text != null and title_text.texture != null:
		title_text.position = Vector2(13, 4)
	var rule := overlay.get_node_or_null("SettingsTitleRule") as ColorRect
	if rule != null:
		rule.size = Vector2(maxf(view_size.x - 16.0, 16.0), 1.0)
	for index in row_labels.size():
		var row_pitch := minf(16.0, maxf(12.0, (view_size.y - 65.0) / maxf(float(row_labels.size()), 1.0)))
		var y := 23.0 + index * row_pitch
		row_labels[index].position = Vector2(14, y + 3.0)
		left_buttons[index].position = Vector2(option_start - 20.0, y)
		value_buttons[index].position = Vector2(option_start, y)
		right_buttons[index].position = Vector2(option_start + 68.0, y)
		if index < option_buttons.size():
			var option_x := option_start
			var option_gap := 1.0 if index >= 3 else 2.0
			for choice_index in option_buttons[index].size():
				var option_button := option_buttons[index][choice_index] as Button
				var option_width := 12.0 if index >= 3 else maxf(26.0, str(option_labels[index][choice_index]).length() * 6.0 + 8.0)
				option_button.position = Vector2(option_x, y)
				option_button.size = Vector2(option_width, 12)
				var option_text := option_button.get_child(0) as Sprite2D
				if option_text != null:
					option_text.position = option_button.size * 0.5
				option_x += option_width + option_gap
	if back_button != null:
		back_button.position = Vector2(view_size.x - 68.0, view_size.y - 19.0)
	if description_text != null:
		description_text.position = Vector2(14, view_size.y - 32.0)
	update_cursor()


func update_visuals(settings_service: SettingsService, pixel_texture: Callable, highlight: Color, back_prompt: String, use_face_art: bool) -> void:
	_settings_service = settings_service
	if settings_service == null or value_buttons.is_empty():
		return
	var values := settings_service.values()
	var value_texts := ["ON" if bool(values.get("fullscreen", false)) else "OFF", str(values.get("aspect", "FULL")), "ON" if bool(values.get("pixel_perfect", true)) else "OFF", str(values.get("music_volume", 100)), str(values.get("sfx_volume", 100)), "ON" if bool(values.get("vibration", true)) else "OFF", "ON" if bool(values.get("debug_menu_enabled", false)) else "OFF"]
	_prompt_factory.set_button_text(back_button, back_prompt, pixel_texture, highlight)
	for index in value_buttons.size():
		var value_text := value_buttons[index].get_child(0) as Sprite2D
		if value_text != null:
			value_text.texture = pixel_texture.call(value_texts[index], Color.WHITE) as Texture2D
		_widget_factory.set_archetype_button_state(value_buttons[index], false, highlight)
		_widget_factory.set_archetype_button_state(left_buttons[index], false, highlight)
		_widget_factory.set_archetype_button_state(right_buttons[index], false, highlight)
		if index < option_buttons.size():
			var selected_option := option_index(index, values)
			for choice_index in option_buttons[index].size():
				var option_button := option_buttons[index][choice_index] as Button
				var active := choice_index == selected_option and row == index
				option_button.visible = true
				option_button.focus_mode = Control.FOCUS_NONE
				_widget_factory.set_archetype_button_state(option_button, active, highlight)
				_prompt_factory.set_menu_button_icon(option_button, MENU_CIRCLE_TEXTURE, use_face_art and active and option_button.size.x >= 24.0)
	if back_button != null:
		_widget_factory.set_archetype_button_state(back_button, row == value_buttons.size(), highlight)
	if description_text != null:
		var descriptions := ["DISPLAY MODE", "LOGICAL ASPECT", "PIXEL FILTER", "MUSIC VOLUME", "SFX VOLUME", "VIBRATION", "PAUSE MENU DEBUG ACCESS", "RETURN"]
		var description_index := clampi(row, 0, descriptions.size() - 1)
		description_text.texture = pixel_texture.call(descriptions[description_index], Color8(148, 220, 255)) as Texture2D
	update_cursor()


func option_index_for_cursor(target_row: int) -> int:
	if _settings_service == null:
		return 0
	return option_index(target_row, _settings_service.values())


func select_option(settings_service: SettingsService, target_row: int, selected_option: int) -> void:
	if settings_service == null:
		return
	row = clampi(target_row, 0, 6)
	match row:
		0: settings_service.set_setting(&"fullscreen", selected_option == 1)
		1:
			var aspects := ["FULL", "3:2", "16:10", "16:9"]
			settings_service.set_setting(&"aspect", aspects[clampi(selected_option, 0, aspects.size() - 1)])
		2: settings_service.set_setting(&"pixel_perfect", selected_option == 1)
		3: settings_service.set_setting(&"music_volume", clampi(selected_option, 0, 10) * 10)
		4: settings_service.set_setting(&"sfx_volume", clampi(selected_option, 0, 10) * 10)
		5: settings_service.set_setting(&"vibration", selected_option == 1)
		6: settings_service.set_setting(&"debug_menu_enabled", selected_option == 1)


func adjust_option(settings_service: SettingsService, target_row: int, direction: int) -> void:
	if settings_service == null:
		return
	row = clampi(target_row, 0, 6)
	var current: Variant
	match row:
		0:
			current = not bool(settings_service.get_setting(&"fullscreen", false))
			settings_service.set_setting(&"fullscreen", current)
		1:
			var aspects := ["FULL", "3:2", "16:10", "16:9"]
			var current_index := maxi(aspects.find(str(settings_service.get_setting(&"aspect", "FULL"))), 0)
			settings_service.set_setting(&"aspect", aspects[posmod(current_index + (1 if direction >= 0 else -1), aspects.size())])
		2:
			current = not bool(settings_service.get_setting(&"pixel_perfect", true))
			settings_service.set_setting(&"pixel_perfect", current)
		3:
			settings_service.set_setting(&"music_volume", int(settings_service.get_setting(&"music_volume", 100)) + (10 if direction >= 0 else -10))
		4:
			settings_service.set_setting(&"sfx_volume", int(settings_service.get_setting(&"sfx_volume", 100)) + (10 if direction >= 0 else -10))
		5:
			current = not bool(settings_service.get_setting(&"vibration", true))
			settings_service.set_setting(&"vibration", current)
		6:
			current = not bool(settings_service.get_setting(&"debug_menu_enabled", false))
			settings_service.set_setting(&"debug_menu_enabled", current)


func update_cursor() -> void:
	if cursor_text == null or value_buttons.is_empty():
		return
	var back_row := value_buttons.size()
	var selected_row := clampi(row, 0, back_row)
	var selected: Control = back_button
	if selected_row != back_row and selected_row >= 0 and selected_row < option_buttons.size():
		selected = option_buttons[selected_row][option_index_for_cursor(selected_row)] as Button
	if selected == null:
		return
	cursor_text.visible = true
	_cursor_animator.move_menu_cursor(cursor_text, Vector2(selected.position.x - _cursor_left_gap, selected.position.y + 4.0), true, _tween_owner)


func option_index(target_row: int, values: Dictionary) -> int:
	match target_row:
		0: return 1 if bool(values.get("fullscreen", false)) else 0
		1: return maxi(["FULL", "3:2", "16:10", "16:9"].find(str(values.get("aspect", "FULL"))), 0)
		2: return 1 if bool(values.get("pixel_perfect", true)) else 0
		3: return clampi(roundi(float(values.get("music_volume", 100)) / 10.0), 0, 10)
		4: return clampi(roundi(float(values.get("sfx_volume", 100)) / 10.0), 0, 10)
		5: return 1 if bool(values.get("vibration", true)) else 0
		6: return 1 if bool(values.get("debug_menu_enabled", false)) else 0
	return 0
