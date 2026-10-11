extends RefCounted
class_name NameEntryScreenController

const NameEntryWidgetPresenterScript = preload("res://scripts/ui/name_entry_widget_presenter.gd")
const NAME_ENTRY_COLUMNS := NameEntryWidgetPresenterScript.NAME_ENTRY_COLUMNS
const NAME_ENTRY_ROWS := NameEntryWidgetPresenterScript.NAME_ENTRY_ROWS

var widgets: NameEntryWidgetPresenter = NameEntryWidgetPresenterScript.new() as NameEntryWidgetPresenter
var name := ""
var page := 0
var row := 0
var column := 0
var pending_slot := -1
var lower_case := false
var error := false
var finish_callback := Callable()
var cancel_callback := Callable()

var _pixel_texture: Callable = Callable()
var _palette_name := "blue"
var _confirm_prompt := "B SELECT"
var _back_prompt := "A BACK"
var _prompt_factory: MenuPromptTextureFactory = null
var _cursor_animator: MenuCursorAnimator = null
var _view_size := Vector2.ZERO
var _cursor_left_gap := 10.0
var _tween_owner: Node = null


func build(parent: Node, view_size: Vector2, pixel_texture: Callable, finish: Callable, cancel_action: Callable, preview_texture: Callable, widget_factory: MenuWidgetFactory, prompt_factory: MenuPromptTextureFactory, cursor_animator: MenuCursorAnimator, cursor_left_gap: float, tween_owner: Node) -> Dictionary:
	_pixel_texture = pixel_texture
	finish_callback = finish
	cancel_callback = cancel_action
	_prompt_factory = prompt_factory
	_cursor_animator = cursor_animator
	_cursor_left_gap = cursor_left_gap
	_tween_owner = tween_owner
	_view_size = view_size
	var controls := widgets.build(parent, view_size, pixel_texture, preview_texture, Callable(self, "activate_cell"), widget_factory)
	position_controls(view_size, cursor_animator, tween_owner)
	return controls


func begin(slot: int) -> void:
	pending_slot = clampi(slot, 0, ProfileSaveService.SLOT_COUNT - 1)
	name = ""
	page = 0
	row = 0
	column = 0
	lower_case = false
	error = false


func cancel() -> void:
	if widgets.overlay != null:
		widgets.overlay.visible = false
	pending_slot = -1


func complete() -> void:
	if widgets.overlay != null:
		widgets.overlay.visible = false
	pending_slot = -1


func pending_name_slot() -> int:
	return pending_slot


func page_case_upper() -> bool:
	return not lower_case


func page_characters(for_page: int = page) -> Array[String]:
	var characters: Array[String] = []
	if for_page == 0:
		# Keep the selection on the letter grid while switching case.
		var letters := "ABCDEFGHIJKLMNOPQRSTUVWXYZ" if page_case_upper() else "abcdefghijklmnopqrstuvwxyz"
		for character in letters:
			characters.append(character)
		characters.append(" ")
		characters.append("DELETE")
		characters.append("DONE")
	else:
		for character in "0123456789-'.!?/":
			characters.append(character)
		characters.append(" ")
		characters.append("DELETE")
		characters.append("DONE")
	return characters


func cell_label(token: String) -> String:
	match token:
		" ": return "SPC"
		"DELETE": return "DEL"
		"DONE": return "DONE"
	return token


func update_visuals(pixel_texture: Callable, palette_name: String, confirm_prompt: String, back_prompt: String, prompt_factory: MenuPromptTextureFactory, view_size: Vector2, cursor_animator: MenuCursorAnimator, tween_owner: Node) -> void:
	_pixel_texture = pixel_texture
	_palette_name = palette_name
	_confirm_prompt = confirm_prompt
	_back_prompt = back_prompt
	_prompt_factory = prompt_factory
	_view_size = view_size
	_cursor_animator = cursor_animator
	_tween_owner = tween_owner
	refresh_visuals()


func position_controls(view_size: Vector2, cursor_animator: MenuCursorAnimator, tween_owner: Node) -> void:
	_view_size = view_size
	_cursor_animator = cursor_animator
	_tween_owner = tween_owner
	widgets.position_controls(view_size, row, column, NAME_ENTRY_COLUMNS, _cursor_left_gap, cursor_animator, tween_owner)


func activate_cell(index: int) -> void:
	var characters := page_characters()
	if index < 0 or index >= characters.size():
		return
	var token := characters[index]
	if token == "DELETE":
		if not name.is_empty():
			name = name.left(name.length() - 1)
		error = false
	elif token == "DONE":
		if name.strip_edges().is_empty():
			error = true
			refresh_visuals()
			return
		if finish_callback.is_valid():
			finish_callback.call(PlayerProfile.normalize_player_name(name))
		return
	else:
		if token == " " and name.is_empty():
			error = true
		else:
			if name.length() < PlayerProfile.MAX_PLAYER_NAME_LENGTH:
				name += token
			error = false
	refresh_visuals()


func move_cursor(delta: Vector2i) -> void:
	var characters := page_characters()
	if characters.is_empty():
		return
	var current := row * NAME_ENTRY_COLUMNS + column
	var next := current
	if delta.x != 0:
		next = posmod(current + delta.x, characters.size())
	else:
		next = clampi(current + delta.y * NAME_ENTRY_COLUMNS, 0, characters.size() - 1)
	row = int(float(next) / float(NAME_ENTRY_COLUMNS))
	column = next % NAME_ENTRY_COLUMNS
	refresh_visuals()


func change_page(direction: int) -> void:
	page = posmod(page + direction, 2)
	row = 0
	column = 0
	refresh_visuals()


func toggle_case() -> void:
	lower_case = not page_case_upper()
	refresh_visuals()


func update_input(root: GameplayState) -> void:
	if widgets.overlay == null or not widgets.overlay.visible:
		return
	if root._is_menu_back_just_pressed():
		if cancel_callback.is_valid():
			cancel_callback.call()
		return
	var input_router := root.input_router
	if input_router != null:
		if input_router.just_pressed(&"magic"):
			toggle_case()
			root._play_sound("ui_hover", -6.0, 1.0)
			return
		if input_router.just_pressed(&"attack"):
			name = PlayerProfile.DEFAULT_PLAYER_NAME
			error = false
			refresh_visuals()
			root._play_sound("ui_confirm", 0.0, 1.0)
			return
		if input_router.just_pressed(&"guard"):
			change_page(-1)
			root._play_sound("ui_hover", -6.0, 1.0)
			return
		if input_router.just_pressed(&"target"):
			change_page(1)
			root._play_sound("ui_hover", -6.0, 1.0)
			return
	if root._is_menu_direction_just_pressed(&"ui_up"):
		move_cursor(Vector2i(0, -1))
		root._play_sound("ui_hover", -6.0, 1.0)
	elif root._is_menu_direction_just_pressed(&"ui_down"):
		move_cursor(Vector2i(0, 1))
		root._play_sound("ui_hover", -6.0, 1.0)
	elif root._is_menu_direction_just_pressed(&"ui_left"):
		move_cursor(Vector2i(-1, 0))
		root._play_sound("ui_hover", -6.0, 1.0)
	elif root._is_menu_direction_just_pressed(&"ui_right"):
		move_cursor(Vector2i(1, 0))
		root._play_sound("ui_hover", -6.0, 1.0)
	elif root._is_menu_confirm_just_pressed():
		activate_cell(row * NAME_ENTRY_COLUMNS + column)
		root._play_sound("ui_confirm", 0.0, 1.0)


func refresh_visuals() -> void:
	if widgets.overlay == null:
		return
	var highlight := PaletteLibrary.accent(_palette_name)
	var characters := page_characters()
	if widgets.name_text != null:
		widgets.name_text.texture = _pixel_texture.call(name + "_", Color.WHITE) as Texture2D
	if widgets.page_text != null:
		widgets.page_text.texture = _pixel_texture.call("UPPER CASE" if page == 0 and page_case_upper() else "LOWER CASE" if page == 0 else "NUMBERS / SYMBOLS", Color8(148, 220, 255)) as Texture2D
	if widgets.message_text != null:
		widgets.message_text.texture = _pixel_texture.call("NAME REQUIRED" if name.is_empty() and error else "MAX 8 CHARACTERS", Color8(255, 105, 105) if error else Color8(148, 220, 255)) as Texture2D
	if widgets.actions_text != null:
		widgets.actions_text.texture = _prompt_factory.pixel_prompt_sequence_texture(_pixel_texture, ["L/R PAGE", "TRIANGLE CASE", "SQUARE DEFAULT"], Color8(148, 220, 255)) as Texture2D
	if widgets.confirm_text != null:
		widgets.confirm_text.texture = _prompt_factory.pixel_prompt_texture(_pixel_texture, _confirm_prompt, highlight)
	if widgets.back_text != null:
		widgets.back_text.texture = _prompt_factory.pixel_prompt_texture(_pixel_texture, _back_prompt, Color8(148, 220, 255))
	var selected_index := clampi(row * NAME_ENTRY_COLUMNS + column, 0, maxi(characters.size() - 1, 0))
	row = int(float(selected_index) / float(NAME_ENTRY_COLUMNS))
	column = selected_index % NAME_ENTRY_COLUMNS
	for index in widgets.cell_buttons.size():
		var active := index < characters.size()
		var button := widgets.cell_buttons[index]
		var label := widgets.cell_texts[index]
		button.visible = active
		button.mouse_filter = Control.MOUSE_FILTER_STOP if active else Control.MOUSE_FILTER_IGNORE
		label.visible = active
		if active:
			var cell_color := highlight if index == selected_index else Color.WHITE
			label.texture = _pixel_texture.call(cell_label(characters[index]), cell_color) as Texture2D
	if widgets.cursor_text != null:
		widgets.cursor_text.texture = NameEntryWidgetPresenterScript.MENU_CURSOR_TEXTURE
		widgets.cursor_text.visible = not characters.is_empty()
	position_controls(_view_size, _cursor_animator, _tween_owner)
