@tool
extends Control
class_name EquipmentMenuLayout

## Authored 240x160 equipment presentation.  The controller owns the data and
## route state; this scene owns the pixel geometry, hit targets, icon anchors,
## and the finite cursor layer so reopening a menu cannot leave old cursors in
## the tree.

const NATIVE_SIZE := Vector2(240.0, 160.0)
const DIM_CURSOR_MODULATE := Color(0.5, 0.5, 0.5, 1.0)
const ACTIVE_CURSOR_MODULATE := Color.WHITE

const MODE_COMMAND := 0
const MODE_SLOT_EQUIP := 1
const MODE_SLOT_REMOVE := 2
const MODE_CANDIDATE := 3
const MODE_REMOVE_ALL_CONFIRM := 4
const EDITOR_PREVIEW_COLOR := Color.WHITE
const EDITOR_MUTED_COLOR := Color8(140, 145, 160)
const EDITOR_PROMPT_COLOR := Color.WHITE

const EffectsSpawnerScript = preload("res://scripts/effects_spawner.gd")
const MENU_CIRCLE_TEXTURE: Texture2D = preload("res://assets/artwork/circle55.png")
const MENU_X_TEXTURE: Texture2D = preload("res://assets/artwork/x55.png")

signal command_pressed(index: int)
signal slot_pressed(index: int)
signal candidate_pressed(index: int)
signal remove_all_confirmed(accepted: bool)
signal navigation_back_pressed

@export var read_only := false

var _pixel_texture: Callable = Callable()
var _cached := false
var _buttons_bound := false

var command_buttons: Array[Button] = []
var slot_buttons: Array[Button] = []
var candidate_buttons: Array[Button] = []
var confirm_buttons: Array[Button] = []

var command_cursor: Sprite2D = null
var slot_cursor: Sprite2D = null
var candidate_cursor: Sprite2D = null
var confirm_cursor: Sprite2D = null
var confirm_locked_cursor: Sprite2D = null

var _slot_texts: Array[Sprite2D] = []
var _candidate_texts: Array[Sprite2D] = []
var _description_texts: Array[Sprite2D] = []
var _summary_texts: Array[Sprite2D] = []
var _bonus_texts: Array[Sprite2D] = []
var _command_texts: Array[Sprite2D] = []
var _confirm_texts: Array[Sprite2D] = []
var _slot_icons: Array[Sprite2D] = []
var _panels: Array[Control] = []
var navigation_panel: Control = null
var navigation_text: Sprite2D = null
var navigation_back_button: Button = null


func _ready() -> void:
	_cache_nodes()
	_apply_button_style()
	_apply_layout()
	if Engine.is_editor_hint():
		call_deferred("_apply_editor_preview")


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_apply_layout()


func _cache_nodes() -> void:
	if _cached:
		return
	_cached = true
	# EQUIPMENT is the authored page tab, not a fourth command.  The three
	# actionable cells are EQUIP, REMOVE, and REMOVE ALL.
	for path in ["EquipButton", "RemoveButton", "RemoveAllButton"]:
		var button := get_node_or_null(path) as Button
		if button != null:
			command_buttons.append(button)
	for index in 6:
		var slot_button := get_node_or_null("SlotButton%d" % index) as Button
		var slot_text := get_node_or_null("SlotText%d" % index) as Sprite2D
		var slot_icon := get_node_or_null("SlotIcon%d" % index) as Sprite2D
		if slot_button != null: slot_buttons.append(slot_button)
		if slot_text != null: _slot_texts.append(slot_text)
		if slot_icon != null: _slot_icons.append(slot_icon)
	for index in 8:
		var candidate_button := get_node_or_null("CandidateButton%d" % index) as Button
		var candidate_text := get_node_or_null("CandidateText%d" % index) as Sprite2D
		if candidate_button != null: candidate_buttons.append(candidate_button)
		if candidate_text != null: _candidate_texts.append(candidate_text)
	for index in 4:
		var description := get_node_or_null("DescriptionText%d" % index) as Sprite2D
		if description != null: _description_texts.append(description)
	for path in ["NameText", "VitText", "StrText", "DefText", "AgiText", "IntText", "MndText"]:
		var summary_text := get_node_or_null(path) as Sprite2D
		if summary_text != null: _summary_texts.append(summary_text)
	for index in 3:
		var bonus := get_node_or_null("BonusText%d" % index) as Sprite2D
		if bonus != null: _bonus_texts.append(bonus)
	for path in ["EquipmentLabel", "EquipLabel", "RemoveLabel", "RemoveAllLabel"]:
		var command_text := get_node_or_null(path) as Sprite2D
		if command_text != null: _command_texts.append(command_text)
	for index in 2:
		var confirm_text := get_node_or_null("ConfirmText%d" % index) as Sprite2D
		if confirm_text != null: _confirm_texts.append(confirm_text)
	navigation_panel = get_node_or_null("NavigationPanel") as Control
	navigation_text = get_node_or_null("NavigationText") as Sprite2D
	navigation_back_button = get_node_or_null("NavigationBackButton") as Button
	for path in ["CommandCursor", "SlotCursor", "CandidateCursor", "ConfirmCursor", "ConfirmLockedCursor"]:
		var cursor := get_node_or_null(path) as Sprite2D
		if cursor == null: continue
		match path:
			"CommandCursor": command_cursor = cursor
			"SlotCursor": slot_cursor = cursor
			"CandidateCursor": candidate_cursor = cursor
			"ConfirmCursor": confirm_cursor = cursor
			"ConfirmLockedCursor": confirm_locked_cursor = cursor
	for path in ["TopPanel", "CommandPanel", "SummaryPanel", "DescriptionPanel", "StatPanel", "NavigationPanel"]:
		var panel := get_node_or_null(path) as Control
		if panel != null: _panels.append(panel)
	if not _buttons_bound:
		for index in command_buttons.size():
			command_buttons[index].pressed.connect(command_pressed.emit.bind(index))
		for index in slot_buttons.size():
			slot_buttons[index].pressed.connect(slot_pressed.emit.bind(index))
		for index in candidate_buttons.size():
			candidate_buttons[index].pressed.connect(candidate_pressed.emit.bind(index))
		if confirm_buttons.is_empty():
			for path in ["ConfirmYesButton", "ConfirmNoButton"]:
				var confirm_button := get_node_or_null(path) as Button
				if confirm_button != null: confirm_buttons.append(confirm_button)
		for index in confirm_buttons.size():
			confirm_buttons[index].pressed.connect(remove_all_confirmed.emit.bind(index == 0))
		if navigation_back_button != null:
			navigation_back_button.pressed.connect(navigation_back_pressed.emit)
		_buttons_bound = true


func _apply_layout() -> void:
	var width := maxf(size.x, NATIVE_SIZE.x)
	var height := maxf(size.y, NATIVE_SIZE.y)
	for panel in _panels:
		if panel == get_node_or_null("StatPanel") or panel == get_node_or_null("NavigationPanel"):
			continue
		panel.size.x = width - panel.position.x - 1.0
	var fill := get_node_or_null("Fill") as ColorRect
	if fill != null:
		fill.size = Vector2(width, height)
	var top := get_node_or_null("TopPanel") as Control
	if top != null:
		# The source render is 19 pixels tall: its 3-pixel NinePatch edge
		# treatment leaves the requested 15-pixel interior fill.
		top.position = Vector2(1.0, 1.0)
		top.size = Vector2(88.0, 19.0)
	var command_panel := get_node_or_null("CommandPanel") as Control
	if command_panel != null:
		command_panel.position = Vector2(90.0, 1.0)
		command_panel.size = Vector2(maxf(width - 91.0, 1.0), 19.0)
	var summary := get_node_or_null("SummaryPanel") as Control
	if summary != null:
		summary.position = Vector2(1.0, 22.0)
		summary.size = Vector2(width - 2.0, 61.0)
	var description := get_node_or_null("DescriptionPanel") as Control
	if description != null: description.size = Vector2(width - 2.0, 47.0)
	var stat := get_node_or_null("StatPanel") as Control
	if stat != null:
		stat.position = Vector2(1.0, 134.0)
		stat.size = Vector2(maxf(width - 82.0, 1.0), 25.0)
	var navigation := get_node_or_null("NavigationPanel") as Control
	if navigation != null:
		navigation.position = Vector2(maxf(width - 79.0, 0.0), 134.0)
		navigation.size = Vector2(78.0, 25.0)
	if navigation_text != null:
		var text_width := float(navigation_text.texture.get_width()) if navigation_text.texture != null else 0.0
		navigation_text.position = Vector2(navigation.position.x + floorf(maxf((navigation.size.x - text_width) * 0.5, 4.0)), 144.0)
	if navigation_back_button != null and navigation != null:
		navigation_back_button.position = Vector2(navigation.position.x + 44.0, 135.0)
		navigation_back_button.size = Vector2(34.0, 23.0)


func _apply_button_style() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color.TRANSPARENT
	transparent.set_border_width_all(0)
	var all_buttons: Array[Button] = []
	all_buttons.append_array(command_buttons)
	all_buttons.append_array(slot_buttons)
	all_buttons.append_array(candidate_buttons)
	all_buttons.append_array(confirm_buttons)
	if navigation_back_button != null:
		all_buttons.append(navigation_back_button)
	for button in all_buttons:
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = ""
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(state, transparent)


func set_pixel_texture(pixel_texture: Callable) -> void:
	_pixel_texture = pixel_texture


func set_navigation_texture(texture: Texture2D) -> void:
	if navigation_text == null:
		return
	navigation_text.texture = texture
	navigation_text.visible = texture != null
	_apply_layout()


func _editor_texture(renderer: EffectsSpawner, value: String, color: Color = EDITOR_PREVIEW_COLOR) -> Texture2D:
	return renderer.number_texture(value, color)


func _editor_prompt_texture(renderer: EffectsSpawner) -> Texture2D:
	var parts := [
		{"glyph": MENU_CIRCLE_TEXTURE, "label": "SELECT"},
		{"glyph": MENU_X_TEXTURE, "label": "BACK"},
	]
	# The mockup leaves a nine-pixel breathing space between SELECT and BACK;
	# keep a separate two-pixel gap between each face button and its label.
	var gap := 9
	var glyph_gap := 2
	var images: Array[Dictionary] = []
	var width := 0
	var height := 5
	for part: Dictionary in parts:
		var glyph := part["glyph"] as Texture2D
		var text_image := _editor_texture(renderer, str(part["label"]), EDITOR_PROMPT_COLOR).get_image()
		var glyph_image := glyph.get_image()
		var part_width := glyph_image.get_width() + glyph_gap + text_image.get_width()
		images.append({"glyph": glyph_image, "text": text_image, "width": part_width})
		width += part_width
	width += gap * maxi(images.size() - 1, 0)
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for part: Dictionary in images:
		var glyph_image := part["glyph"] as Image
		var text_image := part["text"] as Image
		image.blit_rect(glyph_image, Rect2i(Vector2i.ZERO, glyph_image.get_size()), Vector2i(x_offset, 0))
		image.blit_rect(text_image, Rect2i(Vector2i.ZERO, text_image.get_size()), Vector2i(x_offset + glyph_image.get_width() + glyph_gap, 0))
		x_offset += int(part["width"]) + gap
	return ImageTexture.create_from_image(image)


func _apply_editor_preview() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	_cache_nodes()
	var renderer := EffectsSpawnerScript.new()
	# The hub injects its pixel-texture callback at runtime; a standalone scene
	# opened in the editor has no controller to provide one. Temporarily point
	# the shared text setter at a local renderer so every placeholder is actually
	# rasterized into the scene preview, then restore the runtime callback after
	# the textures have been created.
	var previous_pixel_texture := _pixel_texture
	_pixel_texture = Callable(renderer, "number_texture")
	set_text(_command_texts[0] if _command_texts.size() > 0 else null, "EQUIPMENT")
	set_text(_command_texts[1] if _command_texts.size() > 1 else null, "EQUIP")
	set_text(_command_texts[2] if _command_texts.size() > 2 else null, "REMOVE")
	set_text(_command_texts[3] if _command_texts.size() > 3 else null, "REMOVE ALL")
	var summary := ["SAM", "VIT 15", "STR 15", "DEF 8", "AGI 7", "INT 6", "MND 5"]
	for index in _summary_texts.size():
		set_text(_summary_texts[index], summary[index] if index < summary.size() else "")
	var slots := ["SOLDIER SWORD", "HEAD", "SOLDIER ARMOR", "SOLDIER GLOVE", "WOOD SHIELD", "CHROMA TALISMAN +1"]
	for index in _slot_texts.size():
		set_text(_slot_texts[index], slots[index] if index < slots.size() else "", EDITOR_MUTED_COLOR if index == 1 else EDITOR_PREVIEW_COLOR)
	var description := ["Attack 1 against several targets", "improves the same-target shape of", "Attack."]
	for index in _description_texts.size():
		set_text(_description_texts[index], description[index] if index < description.size() else "", Color8(210, 220, 235))
	var bonuses := ["STR: 15"]
	for index in _bonus_texts.size():
		set_text(_bonus_texts[index], bonuses[index] if index < bonuses.size() else "")
	if navigation_text != null:
		navigation_text.texture = _editor_prompt_texture(renderer)
		navigation_text.visible = true
		_apply_layout()
	set_icons_visible(true)
	# Give the standalone scene the same initial command-row state it has in
	# the hub.  Without this, the authored cursor nodes all start at (0, 0) in
	# the editor and the placeholder preview looks like a stack of stray hands.
	render_mode(MODE_COMMAND, 0, 0, 0, 1)
	_pixel_texture = previous_pixel_texture
	renderer.free()


func set_read_only(value: bool) -> void:
	read_only = value


func set_text(sprite: Sprite2D, value: String, color: Color = Color.WHITE) -> void:
	if sprite == null:
		return
	sprite.visible = not value.is_empty()
	if _pixel_texture.is_valid() and not value.is_empty():
		sprite.texture = _pixel_texture.call(value, color) as Texture2D
	else:
		sprite.texture = null


func clear_texts() -> void:
	for sprite in _slot_texts + _candidate_texts + _description_texts + _summary_texts + _bonus_texts + _command_texts + _confirm_texts:
		sprite.texture = null
		sprite.visible = false
	if navigation_text != null:
		navigation_text.texture = null
		navigation_text.visible = false


func set_command_labels(labels: Array[String], colors: Array[Color] = []) -> void:
	for index in _command_texts.size():
		var label := labels[index] if index < labels.size() else ""
		var color := colors[index] if index < colors.size() else Color.WHITE
		set_text(_command_texts[index], label, color)


func set_command_enabled(index: int, enabled: bool) -> void:
	if index < 0 or index >= command_buttons.size():
		return
	command_buttons[index].disabled = not enabled


func set_summary(name_text: String, stat_values: Array[String], name_color: Color = Color.WHITE, stat_colors: Array[Color] = []) -> void:
	if _summary_texts.is_empty(): return
	set_text(_summary_texts[0], name_text, name_color)
	for index in range(1, _summary_texts.size()):
		var color := stat_colors[index - 1] if index - 1 < stat_colors.size() else Color.WHITE
		set_text(_summary_texts[index], stat_values[index - 1] if index - 1 < stat_values.size() else "", color)


func set_slot_grid(labels: Array[String], colors: Array[Color] = [], locked: Array[bool] = []) -> void:
	for index in _slot_texts.size():
		var value := labels[index] if index < labels.size() else ""
		var color := colors[index] if index < colors.size() else Color.WHITE
		set_text(_slot_texts[index], value, color)
		if index < slot_buttons.size():
			slot_buttons[index].disabled = index < locked.size() and locked[index]
			slot_buttons[index].visible = not read_only
		if index < _slot_icons.size():
			_slot_icons[index].modulate = DIM_CURSOR_MODULATE if index < locked.size() and locked[index] else Color.WHITE


func set_candidates(labels: Array[String], colors: Array[Color] = [], selected_index: int = -1) -> void:
	for index in _candidate_texts.size():
		var value := labels[index] if index < labels.size() else ""
		var color := colors[index] if index < colors.size() else Color8(150, 156, 170)
		set_text(_candidate_texts[index], value, color)
		if index < candidate_buttons.size():
			candidate_buttons[index].visible = not read_only and not value.is_empty()


func set_description(lines: Array[String], color: Color = Color.WHITE) -> void:
	for index in _description_texts.size():
		set_text(_description_texts[index], lines[index] if index < lines.size() else "", color)


func set_bonuses(lines: Array[String], colors: Array[Color] = []) -> void:
	for index in _bonus_texts.size():
		var value := lines[index] if index < lines.size() else ""
		var color := colors[index] if index < colors.size() else Color.WHITE
		set_text(_bonus_texts[index], value, color)


func set_icons_visible(value: bool = true) -> void:
	for icon in _slot_icons:
		icon.visible = value


func stop_cursor_motion() -> void:
	# Route changes hide this authored view rather than freeing it. Stop every
	# cursor's tween at that boundary so a later reopen starts from one clean
	# finite cursor layer instead of inheriting a stale bob.
	for cursor in [command_cursor, slot_cursor, candidate_cursor, confirm_cursor, confirm_locked_cursor]:
		if cursor == null:
			continue
		cursor.visible = false
		if cursor.has_method("stop_motion"):
			cursor.call("stop_motion")


func set_confirm_prompt(lines: Array[String], selected_index: int = 1) -> void:
	for index in _confirm_texts.size():
		set_text(_confirm_texts[index], lines[index] if index < lines.size() else "", Color.WHITE if index == selected_index else DIM_CURSOR_MODULATE)


func _position_cursor(cursor: Sprite2D, target: Vector2, active: bool, visible := true) -> void:
	if cursor == null:
		return
	cursor.visible = visible
	if not visible:
		return
	cursor.modulate = ACTIVE_CURSOR_MODULATE if active else DIM_CURSOR_MODULATE
	# The authored scene is @tool, but menu_cursor.gd intentionally remains a
	# runtime script. Godot exposes that script as a placeholder while the scene
	# is open in the editor, so calling its tween helpers there emits a tool-time
	# error. Direct placement is enough for the editor preview; runtime keeps the
	# bobbing/locking behavior below.
	if Engine.is_editor_hint():
		cursor.position = target
		return
	if cursor.has_method("move_to"):
		cursor.call("move_to", target, active)
		if not active and cursor.has_method("lock_at"):
			cursor.call("lock_at", target)
	else:
		cursor.position = target


func render_cursors(mode: int, action_index: int, slot_index: int, candidate_index: int, confirm_index: int = 1) -> void:
	if read_only:
		for cursor in [command_cursor, slot_cursor, candidate_cursor, confirm_cursor, confirm_locked_cursor]:
			if cursor != null: cursor.visible = false
		return
	# The authored action rail begins immediately after the one-pixel gutter.
	# Keep the hand in that gutter (rather than applying the legacy 10px list
	# gap), which is what gives EQUIP its compact, mockup-matched separation.
	# Cursor positions are the 16x16 sprite's top-left origin, not its visible
	# pointer tip.  This offset puts that tip one pixel left of and level with the
	# rendered command glyphs in the mockup.
	var command_target := Vector2(4, 4)
	# Index zero is the EQUIPMENT title; command labels begin at index one.
	if _command_texts.size() > 1:
		var command_text := _command_texts[clampi(action_index + 1, 1, _command_texts.size() - 1)]
		if command_text != null:
			command_target = command_text.position - Vector2(20.0, 3.0)
	# Anchor the hand to the authored slot button geometry.  This keeps the
	# cursor in the button's left gutter and preserves the actual 10px row
	# spacing (the previous hard-coded 20px spacing drifted far below the slot).
	var slot_target := Vector2(4.0, 4.0)
	if not slot_buttons.is_empty():
		var slot_button := slot_buttons[clampi(slot_index, 0, slot_buttons.size() - 1)] as Button
		if slot_button != null:
			# Slot hand: four pixels farther left and three pixels higher than the
			# previous placement, aligned to the slot-type gutter.
			slot_target = slot_button.position - Vector2(7.0, 0.0)
	var candidate_row := clampi(candidate_index / 2, 0, 3)
	var candidate_col := posmod(candidate_index, 2)
	var candidate_target := Vector2(23.0 + float(candidate_col) * 108.0, 90.0 + float(candidate_row) * 9.0)
	# Remove All confirmation reuses the command's existing position: the
	# grey locked cursor and the live bobbing cursor stack there in place.
	var confirm_target := command_target if mode == MODE_REMOVE_ALL_CONFIRM else Vector2(74.0 if confirm_index == 0 else 110.0, 110.0)
	_position_cursor(command_cursor, command_target, mode == MODE_COMMAND, mode != MODE_REMOVE_ALL_CONFIRM)
	_position_cursor(slot_cursor, slot_target, mode == MODE_SLOT_EQUIP or mode == MODE_SLOT_REMOVE, mode == MODE_SLOT_EQUIP or mode == MODE_SLOT_REMOVE or mode == MODE_CANDIDATE)
	_position_cursor(candidate_cursor, candidate_target, mode == MODE_CANDIDATE, mode == MODE_CANDIDATE)
	_position_cursor(confirm_locked_cursor, confirm_target, false, mode == MODE_REMOVE_ALL_CONFIRM)
	_position_cursor(confirm_cursor, confirm_target, true, mode == MODE_REMOVE_ALL_CONFIRM)


func render_mode(mode: int, action_index: int, slot_index: int, candidate_index: int, confirm_index: int = 1) -> void:
	_cache_nodes()
	var command_visible := mode == MODE_COMMAND or mode == MODE_REMOVE_ALL_CONFIRM
	var slot_visible := mode == MODE_SLOT_EQUIP or mode == MODE_SLOT_REMOVE or mode == MODE_CANDIDATE
	var candidate_visible := mode == MODE_CANDIDATE
	# Candidate textures are prepared on every render so the controller can keep
	# its selection data warm, but they belong to the description replacement
	# state only. Never let the hidden candidate layer sit over the equipped-item
	# description or Remove All prompt.
	for text in _candidate_texts:
		text.visible = candidate_visible and text.texture != null
	for button in command_buttons:
		button.visible = command_visible and not read_only
	for button in slot_buttons:
		button.visible = slot_visible and not read_only
	for button in candidate_buttons:
		button.visible = candidate_visible and not read_only and button.visible
	for button in confirm_buttons:
		button.visible = mode == MODE_REMOVE_ALL_CONFIRM and not read_only
	if navigation_panel != null:
		navigation_panel.visible = true
	if navigation_back_button != null:
		# The navigation cell is the touch-only Back affordance. It remains
		# available in Pause's read-only shared view while the transaction
		# buttons stay suppressed by the active depth.
		navigation_back_button.visible = true
	var confirm_panel := get_node_or_null("ConfirmPanel") as Control
	if confirm_panel != null: confirm_panel.visible = mode == MODE_REMOVE_ALL_CONFIRM
	render_cursors(mode, action_index, slot_index, candidate_index, confirm_index)
