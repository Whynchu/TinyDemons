extends RefCounted
class_name DebugMenuLayout

signal action_requested(action: StringName, amount: int)

const MENU_FRAME_TEXTURE: Texture2D = preload("res://assets/artwork/frame 16x16.png")

var page: Control
var run_value: Sprite2D
var level_value: Sprite2D
var points_value: Sprite2D
var cursor: Sprite2D
var reset_button: Button
var toggle_buttons: Dictionary = {}
var buttons: Array[Button] = []


func build(parent: Control, pixel_texture: Callable, button_factory: Callable, cursor_texture: Texture2D) -> Dictionary:
	page = Control.new()
	page.name = "PauseDebugPage"
	page.position = Vector2.ZERO
	page.size = Vector2(240, 160)
	page.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.visible = false
	parent.add_child(page)
	var background := NinePatchRect.new()
	background.name = "Background"
	background.texture = MENU_FRAME_TEXTURE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.position = Vector2.ZERO
	background.size = page.size
	background.patch_margin_left = 3
	background.patch_margin_top = 3
	background.patch_margin_right = 3
	background.patch_margin_bottom = 3
	background.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	background.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	var title := Sprite2D.new()
	title.name = "Title"
	title.texture = pixel_texture.call("DEBUG", Color.WHITE) as Texture2D
	title.position = Vector2(14, 9)
	title.centered = false
	title.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	page.add_child(title)
	var rule := ColorRect.new()
	rule.name = "TitleRule"
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.position = Vector2(8, 22)
	rule.size = Vector2(224, 1)
	rule.color = Color8(91, 120, 146)
	page.add_child(rule)
	var run_label := _label("RUN", Vector2(14, 28), pixel_texture, Color8(255, 219, 142))
	page.add_child(run_label)
	var run_minus := _button("-", Vector2(14, 35), Vector2(27, 14), &"run_decrease", pixel_texture, button_factory)
	var run_plus := _button("+", Vector2(77, 35), Vector2(27, 14), &"run_increase", pixel_texture, button_factory)
	run_value = _label("R1", Vector2(49, 39), pixel_texture, Color8(255, 219, 142))
	page.add_child(run_value)
	reset_button = _button("RESET RUN", Vector2(126, 35), Vector2(96, 14), &"reset_run", pixel_texture, button_factory)
	var level_label := _label("PLAYER", Vector2(14, 56), pixel_texture, Color8(148, 220, 255))
	page.add_child(level_label)
	var level_minus := _button("-", Vector2(14, 63), Vector2(27, 14), &"level_decrease", pixel_texture, button_factory)
	var level_plus := _button("+", Vector2(90, 63), Vector2(27, 14), &"level_increase", pixel_texture, button_factory)
	level_value = _label("LV 1", Vector2(49, 67), pixel_texture, Color8(148, 220, 255))
	page.add_child(level_value)
	points_value = _label("PTS 0", Vector2(126, 67), pixel_texture, Color8(255, 219, 142))
	page.add_child(points_value)
	var cheats_label := _label("CHEATS", Vector2(14, 86), pixel_texture, Color8(148, 220, 255))
	page.add_child(cheats_label)
	var invulnerable_button := _button("INVULN OFF", Vector2(14, 95), Vector2(96, 14), &"toggle_invulnerable", pixel_texture, button_factory)
	var chroma_button := _button("CHROMA OFF", Vector2(122, 95), Vector2(100, 14), &"toggle_unlimited_chroma", pixel_texture, button_factory)
	var enemies_button := _button("ENEMIES ON", Vector2(14, 113), Vector2(96, 14), &"toggle_pause_enemies", pixel_texture, button_factory)
	var guides_button := _button("GUIDES OFF", Vector2(122, 113), Vector2(100, 14), &"toggle_geometry_guides", pixel_texture, button_factory)
	toggle_buttons = {&"invulnerable": invulnerable_button, &"unlimited_chroma": chroma_button, &"pause_enemies": enemies_button, &"geometry_guides": guides_button}
	var end_button := _button("END DEBUG", Vector2(14, 138), Vector2(96, 14), &"end_session", pixel_texture, button_factory)
	var back_button := _button("BACK", Vector2(126, 138), Vector2(96, 14), &"back", pixel_texture, button_factory)
	buttons = [run_minus, run_plus, reset_button, level_minus, level_plus, invulnerable_button, chroma_button, enemies_button, guides_button, end_button, back_button]
	cursor = Sprite2D.new()
	cursor.name = "DebugCursor"
	cursor.texture = cursor_texture
	cursor.centered = false
	cursor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	cursor.z_index = 10
	page.add_child(cursor)
	return {"page": page, "buttons": buttons}


func refresh(pixel_texture: Callable, run_number: int, player_level: int, unspent_stat_points: int, reset_confirmation_armed: bool, toggles: Dictionary = {}) -> void:
	if run_value != null:
		run_value.texture = pixel_texture.call("R%d" % run_number, Color8(255, 219, 142)) as Texture2D
	if level_value != null:
		level_value.texture = pixel_texture.call("LV %d" % player_level, Color8(148, 220, 255)) as Texture2D
	if points_value != null:
		points_value.texture = pixel_texture.call("PTS %d" % maxi(unspent_stat_points, 0), Color8(255, 219, 142)) as Texture2D
	if reset_button != null:
		_set_button_label(reset_button, "CONFIRM" if reset_confirmation_armed else "RESET RUN", pixel_texture)
	var toggle_labels := {&"invulnerable": ["INVULN OFF", "INVULN ON"], &"unlimited_chroma": ["CHROMA OFF", "CHROMA ON"], &"pause_enemies": ["ENEMIES ON", "ENEMIES PAUSED"], &"geometry_guides": ["GUIDES OFF", "GUIDES ON"]}
	for key: StringName in toggle_buttons:
		var options: Array = toggle_labels[key]
		_set_button_label(toggle_buttons[key] as Button, str(options[1] if bool(toggles.get(key, false)) else options[0]), pixel_texture)


func apply_layout(view_size: Vector2) -> void:
	if page == null:
		return
	page.size = view_size
	var background := page.get_node_or_null("Background") as NinePatchRect
	if background != null:
		background.size = view_size
	if cursor != null:
		cursor.visible = page.visible


func select_row(row: int) -> void:
	if cursor == null or buttons.is_empty():
		return
	var selected := buttons[clampi(row, 0, buttons.size() - 1)]
	cursor.visible = page.visible
	cursor.position = Vector2(maxf(selected.position.x - 8.0, 3.0), selected.position.y + floorf((selected.size.y - 5.0) * 0.5))


func _label(text: String, position: Vector2, pixel_texture: Callable, color: Color = Color.WHITE) -> Sprite2D:
	var label := Sprite2D.new()
	label.texture = pixel_texture.call(text, color) as Texture2D
	label.position = position
	label.centered = false
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return label


func _button(text: String, position: Vector2, size: Vector2, action: StringName, pixel_texture: Callable, button_factory: Callable) -> Button:
	var button := button_factory.call(text, position, size, pixel_texture) as Button
	if button == null:
		return null
	button.position = position
	button.size = size
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(action_requested.emit.bind(action, 0))
	_set_button_label(button, text, pixel_texture)
	page.add_child(button)
	return button


func _set_button_label(button: Button, text: String, pixel_texture: Callable) -> void:
	if button == null:
		return
	var existing := button.get_node_or_null("Label") as Sprite2D
	if existing == null:
		for child in button.get_children():
			if child is Sprite2D:
				existing = child as Sprite2D
				break
	if existing == null:
		existing = Sprite2D.new()
		button.add_child(existing)
	existing.name = "Label"
	existing.centered = true
	existing.texture = pixel_texture.call(text, Color.WHITE) as Texture2D
	existing.position = button.size * 0.5
	existing.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
