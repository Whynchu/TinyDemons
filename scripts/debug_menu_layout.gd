extends RefCounted
class_name DebugMenuLayout

signal action_requested(action: StringName, amount: int)

var page: Control
var run_value: Sprite2D
var level_value: Sprite2D
var reset_button: Button
var toggle_buttons: Dictionary = {}
var buttons: Array[Button] = []


func build(parent: Control, pixel_texture: Callable) -> Dictionary:
	page = Control.new()
	page.name = "PauseDebugPage"
	page.position = Vector2.ZERO
	page.size = Vector2(240, 160)
	page.mouse_filter = Control.MOUSE_FILTER_STOP
	page.visible = false
	parent.add_child(page)
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color8(13, 18, 29, 244)
	background.position = Vector2.ZERO
	background.size = page.size
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(background)
	var title := Sprite2D.new()
	title.name = "Title"
	title.texture = pixel_texture.call("DEBUG", Color.WHITE) as Texture2D
	title.position = Vector2(14, 9)
	title.centered = false
	page.add_child(title)
	var rule := ColorRect.new()
	rule.position = Vector2(8, 22)
	rule.size = Vector2(224, 1)
	rule.color = Color8(91, 120, 146)
	page.add_child(rule)
	var run_label := _label("RUN NUMBER", Vector2(14, 28), pixel_texture)
	page.add_child(run_label)
	var run_minus := _button("-", Vector2(14, 36), Vector2(28, 16), &"run_decrease", pixel_texture)
	var run_plus := _button("+", Vector2(90, 36), Vector2(28, 16), &"run_increase", pixel_texture)
	run_value = _label("R1", Vector2(53, 40), pixel_texture)
	page.add_child(run_value)
	reset_button = _button("RESET RUN", Vector2(128, 36), Vector2(94, 16), &"reset_run", pixel_texture)
	var level_label := _label("PLAYER LEVEL", Vector2(14, 57), pixel_texture)
	page.add_child(level_label)
	var level_minus := _button("-", Vector2(14, 65), Vector2(28, 16), &"level_decrease", pixel_texture)
	var level_plus := _button("+", Vector2(90, 65), Vector2(28, 16), &"level_increase", pixel_texture)
	level_value = _label("LV 1", Vector2(53, 69), pixel_texture)
	page.add_child(level_value)
	var invulnerable_button := _button("INVULN OFF", Vector2(14, 91), Vector2(94, 16), &"toggle_invulnerable", pixel_texture)
	var chroma_button := _button("CHROMA OFF", Vector2(120, 91), Vector2(102, 16), &"toggle_unlimited_chroma", pixel_texture)
	var enemies_button := _button("ENEMIES ON", Vector2(14, 112), Vector2(94, 16), &"toggle_pause_enemies", pixel_texture)
	var guides_button := _button("GUIDES OFF", Vector2(120, 112), Vector2(102, 16), &"toggle_geometry_guides", pixel_texture)
	toggle_buttons = {&"invulnerable": invulnerable_button, &"unlimited_chroma": chroma_button, &"pause_enemies": enemies_button, &"geometry_guides": guides_button}
	var end_button := _button("END DEBUG", Vector2(14, 136), Vector2(94, 16), &"end_session", pixel_texture)
	var back_button := _button("BACK", Vector2(128, 136), Vector2(94, 16), &"back", pixel_texture)
	buttons = [run_minus, run_plus, reset_button, level_minus, level_plus, invulnerable_button, chroma_button, enemies_button, guides_button, end_button, back_button]
	return {"page": page, "buttons": buttons}


func refresh(pixel_texture: Callable, run_number: int, player_level: int, reset_confirmation_armed: bool, toggles: Dictionary = {}) -> void:
	if run_value != null:
		run_value.texture = pixel_texture.call("R%d" % run_number, Color8(255, 219, 142)) as Texture2D
	if level_value != null:
		level_value.texture = pixel_texture.call("LV %d" % player_level, Color8(148, 220, 255)) as Texture2D
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
	var background := page.get_node_or_null("Background") as ColorRect
	if background != null:
		background.size = view_size


func _label(text: String, position: Vector2, pixel_texture: Callable) -> Sprite2D:
	var label := Sprite2D.new()
	label.texture = pixel_texture.call(text, Color.WHITE) as Texture2D
	label.position = position
	label.centered = false
	return label


func _button(text: String, position: Vector2, size: Vector2, action: StringName, pixel_texture: Callable) -> Button:
	var button := Button.new()
	button.position = position
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(action_requested.emit.bind(action, 0))
	_set_button_label(button, text, pixel_texture)
	page.add_child(button)
	return button


func _set_button_label(button: Button, text: String, pixel_texture: Callable) -> void:
	var existing := button.get_node_or_null("Label") as Sprite2D
	if existing == null:
		existing = Sprite2D.new()
		existing.name = "Label"
		existing.centered = true
		button.add_child(existing)
		button.resized.connect(func(): existing.position = button.size * 0.5)
	existing.texture = pixel_texture.call(text, Color.WHITE) as Texture2D
	existing.position = button.size * 0.5
