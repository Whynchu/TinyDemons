extends RefCounted
class_name SaveSelectScreenPresenter

const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")

var overlay: ColorRect = null
var footer_text: Sprite2D = null
var _slot_buttons: Array[Button] = []
var _title_text: Sprite2D = null
var _cursor_text: Sprite2D = null
var _overwrite_prompt: Sprite2D = null
var _overwrite_cursor: Sprite2D = null
var _overwrite_yes: Button = null
var _overwrite_no: Button = null
var _nav_back: Button = null
var _selected_slot := 0

func slot_button(index: int) -> Button:
	return _slot_buttons[index] if index >= 0 and index < _slot_buttons.size() else null

func set_selected_slot(index: int) -> void:
	if not _slot_buttons.is_empty():
		_selected_slot = clampi(index, 0, _slot_buttons.size() - 1)
		_update_cursor_anchor()


func build(parent: Node, view_size: Vector2, pixel_texture: Callable, select_callback: Callable, overwrite_yes: Callable, overwrite_no: Callable, portrait_texture: Callable, back_callback: Callable, widget_factory: MenuWidgetFactory) -> ColorRect:
	overlay = widget_factory.create_overlay(parent, "SaveSelectOverlay", view_size, Color.BLACK, 4, false)
	overlay.set_meta("display_full_view", true)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_title_text = widget_factory.create_sprite(overlay, "SaveSelectTitle", pixel_texture.call("CHOOSE SAVE", Color.WHITE) as Texture2D, Vector2((view_size.x - 64.0) * 0.5, 42), false)
	_cursor_text = widget_factory.create_sprite(overlay, "SaveSelectCursor", MENU_CURSOR_TEXTURE, Vector2((view_size.x - 130.0) * 0.5, 70), false)
	_overwrite_prompt = widget_factory.create_sprite(overlay, "OverwritePrompt", pixel_texture.call("OVERWRITE?  YES / NO", Color.WHITE) as Texture2D, Vector2((view_size.x - 100.0) * 0.5, 126), false)
	var prompt := _overwrite_prompt
	prompt.visible = false
	_overwrite_cursor = widget_factory.create_sprite(overlay, "OverwriteCursor", MENU_CURSOR_TEXTURE, Vector2((view_size.x - 42.0) * 0.5, 140), false)
	var prompt_cursor := _overwrite_cursor
	prompt_cursor.visible = false
	var yes := widget_factory.make_retro_button("YES", Vector2((view_size.x - 30.0) * 0.5, 137), Vector2(24, 12), pixel_texture)
	_overwrite_yes = yes
	yes.name = "OverwriteYes"
	yes.visible = false
	yes.pressed.connect(overwrite_yes)
	overlay.add_child(yes)
	var no := widget_factory.make_retro_button("NO", Vector2((view_size.x + 30.0) * 0.5, 137), Vector2(20, 12), pixel_texture)
	_overwrite_no = no
	no.name = "OverwriteNo"
	no.visible = false
	no.pressed.connect(overwrite_no)
	overlay.add_child(no)
	for slot in ProfileSaveService.SLOT_COUNT:
		var profile := ProfileSaveService.load_profile_for_slot(slot)
		var label := "SAVE %d  EMPTY" % (slot + 1)
		var palette_name := "blue"
		if profile != null and profile.has_started:
			label = "SAVE %d  %s" % [slot + 1, PlayerProfile.normalize_player_name(profile.player_name)]
			var flame := profile.starter_flame
			palette_name = AspectCatalog.palette_for_flame(flame)
			if palette_name == "grey" and not profile.palette_name.is_empty():
				palette_name = profile.palette_name
			if profile.has_bound_element:
				palette_name = AspectCatalog.palette_for_flame(profile.bound_element)
		var button := widget_factory.make_retro_button(label, Vector2((view_size.x - 112.0) * 0.5, 66 + slot * 20), Vector2(112, 18), pixel_texture)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = false
		button.set_meta("save_slot", slot)
		button.pressed.connect(select_callback.bind(slot))
		overlay.add_child(button)
		_slot_buttons.append(button)
		var label_sprite := button.get_child(0) as Sprite2D
		if label_sprite != null:
			label_sprite.position = Vector2(67, 9)
		if profile != null and profile.has_started and portrait_texture.is_valid():
			var portrait := Sprite2D.new()
			portrait.name = "Save%dPortrait" % slot
			portrait.texture = portrait_texture.call(palette_name, profile.has_demon_cloak_equipped()) as Texture2D
			portrait.position = Vector2(1, 1)
			portrait.centered = false
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.z_index = 1
			button.add_child(portrait)
	var nav_back := widget_factory.make_retro_button("BACK", Vector2(12, view_size.y - 23.0), Vector2(42, 18), pixel_texture)
	_nav_back = nav_back
	nav_back.name = "SaveNavBack"
	nav_back.focus_mode = Control.FOCUS_NONE
	if back_callback.is_valid():
		nav_back.pressed.connect(back_callback)
	overlay.add_child(nav_back)
	footer_text = widget_factory.create_sprite(overlay, "SaveSelectFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(view_size.x - 64.0, view_size.y - 18.0), false)
	for child in overlay.get_children():
		if child is Button and (child as Button).name in [&"OverwriteYes", &"OverwriteNo"]:
			(child as Button).focus_mode = Control.FOCUS_NONE
	return overlay


func position_controls(view_size: Vector2) -> void:
	if _title_text != null:
		_title_text.position.x = (view_size.x - _title_text.texture.get_width()) * 0.5 if _title_text.texture != null else (view_size.x - 64.0) * 0.5
	for index in _slot_buttons.size():
		_slot_buttons[index].position.x = (view_size.x - _slot_buttons[index].size.x) * 0.5
	_update_cursor_anchor()
	if _overwrite_prompt != null:
		_overwrite_prompt.position.x = (view_size.x - (_overwrite_prompt.texture.get_width() if _overwrite_prompt.texture != null else 100.0)) * 0.5
	if _overwrite_cursor != null:
		_overwrite_cursor.position.x = (view_size.x - 42.0) * 0.5
	if _overwrite_yes != null:
		_overwrite_yes.position.x = (view_size.x - 30.0) * 0.5
	if _overwrite_no != null:
		_overwrite_no.position.x = (view_size.x + 30.0) * 0.5
	if _nav_back != null:
		_nav_back.position.y = view_size.y - 23.0
	if footer_text != null:
		footer_text.position = Vector2(view_size.x - 64.0, view_size.y - 18.0)


func _update_cursor_anchor() -> void:
	if _cursor_text == null or _slot_buttons.is_empty():
		return
	var selected := _slot_buttons[clampi(_selected_slot, 0, _slot_buttons.size() - 1)]
	_cursor_text.position = Vector2(selected.position.x - 10.0, selected.position.y + 5.0)
