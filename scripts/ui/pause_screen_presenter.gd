extends RefCounted
class_name PauseScreenPresenter

signal debug_page_requested
signal debug_action_requested(action: StringName, amount: int)

const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/menus/pause/pause_menu.tscn")
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")
const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")
const PauseMenuStateScript = preload("res://scripts/ui/pause_menu_state.gd")
const PauseItemsPresenterScript = preload("res://scripts/ui/pause_items_presenter.gd")
const PausePageDataPresenterScript = preload("res://scripts/ui/pause_page_data_presenter.gd")
const DebugMenuLayoutScript = preload("res://scripts/editor/debug_menu_layout.gd")
const PauseDebugMenuContextScript = preload("res://scripts/ui/pause_debug_menu_context.gd")
const SoulVisualsScript = preload("res://scripts/runtime/services/soul_visuals.gd")
const STATUS_LEFT_ROW_COUNT := 10

var overlay: ColorRect = null
var title_text: Sprite2D = null
var menu_buttons: Array[Button] = []
var cursor_text: Sprite2D = null
var root_page: Control = null
var page_roots: Dictionary = {}
var player_card_texts: Array[Sprite2D] = []
var player_portrait: Sprite2D = null
var gold_icon: Sprite2D = null
var gold_text: Sprite2D = null
var soul_text: Sprite2D = null
var resource_icon: Sprite2D = null
var status_texts: Array[Sprite2D] = []
var equipment_texts: Array[Sprite2D] = []
var items_presenter: PauseItemsPresenter = null
var _page_data_presenter: PausePageDataPresenter = PausePageDataPresenterScript.new() as PausePageDataPresenter
var description_text: Sprite2D = null
var back_button: Button = null
var status_button: Button = null
var equipment_button: Button = null
var items_button: Button = null
var settings_button: Button = null
var debug_button: Button = null
var quit_button: Button = null

var items_model: PauseItemsModel:
	get: return items_presenter.model if items_presenter != null else null
var equipment_menu: EquipmentMenuLayout = null
var debug_menu_layout: DebugMenuLayout = null
var debug_menu_buttons: Array[Button] = []
var _widget_factory: MenuWidgetFactory = null
var _prompt_texture_factory: MenuPromptTextureFactory = null
var _cursor_animator: MenuCursorAnimator = null


func build(
	parent: Node,
	view_size: Vector2,
	pixel_texture: Callable,
	actions: HubScreenActions,
	widget_factory: MenuWidgetFactory,
	prompt_texture_factory: MenuPromptTextureFactory,
	cursor_animator: MenuCursorAnimator,
	set_hub_action_column: Callable
) -> void:
	_widget_factory = widget_factory
	_prompt_texture_factory = prompt_texture_factory
	_cursor_animator = cursor_animator
	var built_overlay := PAUSE_MENU_SCENE.instantiate() as ColorRect
	if built_overlay == null:
		return
	built_overlay.name = "PauseOverlay"
	built_overlay.position = Vector2.ZERO
	built_overlay.size = view_size
	built_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	built_overlay.z_index = 4
	built_overlay.visible = false
	built_overlay.set_meta("display_full_view", true)
	parent.add_child(built_overlay)
	var pause_title := built_overlay.get_node_or_null("PauseTitle") as Sprite2D
	root_page = built_overlay.get_node_or_null("PauseRootPage") as Control
	var status_page := built_overlay.get_node_or_null("PauseStatusPage") as Control
	var equipment_page := built_overlay.get_node_or_null("PauseEquipmentPage") as Control
	var items_page := built_overlay.get_node_or_null("PauseItemsPage") as Control
	equipment_menu = equipment_page.get_node_or_null("EquipmentMenu") as EquipmentMenuLayout if equipment_page != null else null
	if equipment_menu != null:
		equipment_menu.visible = false
		equipment_menu.set_read_only(false)
		equipment_menu.set_pixel_texture(pixel_texture)
		if equipment_menu.has_signal("navigation_back_pressed"):
			if actions.pause_equipment_back.is_valid(): equipment_menu.navigation_back_pressed.connect(actions.pause_equipment_back)
			elif actions.pause_back.is_valid(): equipment_menu.navigation_back_pressed.connect(actions.pause_back)
		if equipment_menu.has_signal("command_pressed"):
			equipment_menu.command_pressed.connect(func(index: int):
				set_hub_action_column.call(index)
				if index == 0 and actions.item_action.is_valid(): actions.item_action.call()
				elif index == 1 and actions.equipment_remove.is_valid(): actions.equipment_remove.call()
				elif index == 2 and actions.equipment_remove_all.is_valid(): actions.equipment_remove_all.call())
		if equipment_menu.has_signal("slot_pressed") and actions.select_gear_slot.is_valid():
			equipment_menu.slot_pressed.connect(func(index: int): actions.select_gear_slot.call(index))
		if equipment_menu.has_signal("candidate_pressed") and actions.select_gear_candidate.is_valid():
			equipment_menu.candidate_pressed.connect(func(index: int): actions.select_gear_candidate.call(index))
		if equipment_menu.has_signal("remove_all_confirmed"):
			equipment_menu.remove_all_confirmed.connect(func(accepted: bool):
				if accepted and actions.equipment_remove_all.is_valid(): actions.equipment_remove_all.call()
				elif not accepted and actions.equipment_remove_all_cancel.is_valid(): actions.equipment_remove_all_cancel.call())
	var status_title := status_page.get_node_or_null("Title") as Sprite2D
	var equipment_title := equipment_page.get_node_or_null("Title") as Sprite2D
	var items_title := items_page.get_node_or_null("Title") as Sprite2D
	if status_title != null: status_title.texture = pixel_texture.call("STATUS", Color.WHITE) as Texture2D
	if equipment_title != null: equipment_title.texture = pixel_texture.call("EQUIPMENT", Color.WHITE) as Texture2D
	if items_title != null: items_title.texture = pixel_texture.call("ITEMS", Color.WHITE) as Texture2D
	page_roots = {
		PauseMenuStateScript.COMMAND_PAGE: root_page,
		PauseMenuStateScript.STATUS_PAGE: status_page,
		PauseMenuStateScript.EQUIPMENT_PAGE: equipment_page,
		PauseMenuStateScript.ITEMS_PAGE: items_page,
	}
	player_portrait = built_overlay.get_node_or_null("PauseRootPage/PausePlayerPortrait") as Sprite2D
	gold_icon = built_overlay.get_node_or_null("PauseGoldIcon") as Sprite2D
	resource_icon = built_overlay.get_node_or_null("PauseResourceIcon") as Sprite2D
	player_card_texts.clear()
	for index in PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.size():
		player_card_texts.append(widget_factory.create_sprite(root_page, "PauseCardText%d" % index, null, PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[index], false))
	status_texts.clear()
	for index in 16:
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		status_texts.append(widget_factory.create_sprite(status_page, "PauseStatus%d" % index, null, Vector2(14 + column * 108, 28 + row * 10), false))
	equipment_texts.clear()
	for index in 8:
		equipment_texts.append(widget_factory.create_sprite(equipment_page, "PauseEquipment%d" % index, null, Vector2(14, 28 + index * 12), false))
	items_presenter = PauseItemsPresenterScript.new() as PauseItemsPresenter
	items_presenter.build(items_page, view_size, pixel_texture, widget_factory)
	description_text = widget_factory.create_sprite(built_overlay, "PauseDescription", null, PauseMenuLayoutScript.select_prompt_position(view_size), false)
	gold_text = widget_factory.create_sprite(built_overlay, "PauseGoldText", null, PauseMenuLayoutScript.resource_text_position(view_size, 0.0, false), false)
	soul_text = widget_factory.create_sprite(built_overlay, "PauseSoulText", null, PauseMenuLayoutScript.resource_text_position(view_size, 0.0, true), false)
	menu_buttons.clear()
	var labels := ["STATUS", "EQUIPMENT", "ITEMS", "SETTINGS", "DEBUG", "QUIT TITLE"]
	for index in labels.size():
		var button := widget_factory.make_menu_command_button(labels[index], PauseMenuLayoutScript.command_button_position(view_size, index), PauseMenuLayoutScript.COMMAND_BUTTON_SIZE, pixel_texture)
		button.name = "Pause%s" % labels[index].replace(" ", "").capitalize()
		button.focus_mode = Control.FOCUS_NONE
		if index == 0:
			if actions.pause_status.is_valid(): button.pressed.connect(actions.pause_status)
			elif actions.pause_set_page.is_valid(): button.pressed.connect(actions.pause_set_page.bind(PauseMenuStateScript.STATUS_PAGE))
		elif index == 1:
			if actions.pause_equipment.is_valid(): button.pressed.connect(actions.pause_equipment)
			elif actions.pause_set_page.is_valid(): button.pressed.connect(actions.pause_set_page.bind(PauseMenuStateScript.EQUIPMENT_PAGE))
		elif index == 2:
			if actions.pause_items.is_valid(): button.pressed.connect(actions.pause_items)
			elif actions.pause_set_page.is_valid(): button.pressed.connect(actions.pause_set_page.bind(PauseMenuStateScript.ITEMS_PAGE))
		elif index == 3 and actions.pause_settings.is_valid(): button.pressed.connect(actions.pause_settings)
		elif index == 4: button.pressed.connect(_request_debug_page)
		elif index == 5 and actions.pause_quit.is_valid(): button.pressed.connect(actions.pause_quit)
		root_page.add_child(button)
		menu_buttons.append(button)
	back_button = widget_factory.make_menu_command_button("BACK", PauseMenuLayoutScript.back_button_position(view_size), PauseMenuLayoutScript.BACK_BUTTON_SIZE, pixel_texture)
	back_button.name = "PauseBack"
	back_button.focus_mode = Control.FOCUS_NONE
	if actions.pause_back.is_valid(): back_button.pressed.connect(actions.pause_back)
	built_overlay.add_child(back_button)
	cursor_text = widget_factory.create_sprite(root_page, "PauseCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false)
	cursor_text.visible = false
	debug_menu_layout = DebugMenuLayoutScript.new() as DebugMenuLayout
	var debug_controls := debug_menu_layout.build(built_overlay, pixel_texture, Callable(widget_factory, "make_menu_command_button"), MENU_CURSOR_TEXTURE)
	debug_menu_layout.action_requested.connect(_forward_debug_action_requested)
	page_roots[PauseMenuStateScript.DEBUG_PAGE] = debug_controls["page"] as Control
	debug_menu_buttons = debug_controls["buttons"] as Array[Button]
	overlay = built_overlay
	title_text = pause_title
	status_button = menu_buttons[0] if menu_buttons.size() > 0 else null
	equipment_button = menu_buttons[1] if menu_buttons.size() > 1 else null
	items_button = menu_buttons[2] if menu_buttons.size() > 2 else null
	settings_button = menu_buttons[3] if menu_buttons.size() > 3 else null
	debug_button = menu_buttons[4] if menu_buttons.size() > 4 else null
	quit_button = menu_buttons[5] if menu_buttons.size() > 5 else null


func update_items(profile: PlayerProfile, pixel_texture: Callable, highlight: Color) -> void:
	if items_presenter != null:
		items_presenter.update(profile, pixel_texture, highlight)


func move_items_selection(direction: int) -> bool:
	return items_presenter != null and items_presenter.move_selection(direction)


func move_items_filter(direction: int) -> bool:
	return items_presenter != null and items_presenter.move_filter(direction)


func toggle_items_sort() -> void:
	if items_presenter != null:
		items_presenter.toggle_sort()


func position_controls(view_size: Vector2) -> void:
	if overlay == null:
		return
	var width := view_size.x
	var height := view_size.y
	overlay.position = Vector2.ZERO
	overlay.size = view_size
	for page_root: Control in page_roots.values():
		page_root.position = Vector2.ZERO
		page_root.size = view_size
		var page_background := page_root.get_node_or_null("Background") as NinePatchRect
		if page_background != null: page_background.size = view_size
		var page_title_rule := page_root.get_node_or_null("TitleRule") as ColorRect
		if page_title_rule != null: page_title_rule.size.x = maxf(width - 16.0, 16.0)
	var divider_x := PauseMenuLayoutScript.divider_x(width)
	PauseMenuLayoutScript.apply_panel_layout(overlay, view_size)
	var command_divider := overlay.get_node_or_null("CommandDivider") as ColorRect
	if command_divider != null:
		command_divider.position = Vector2(divider_x - 1.0, 2.0)
		command_divider.size = Vector2(1.0, maxf(PauseMenuLayoutScript.upper_rail_height(height) - 2.0, 1.0))
	var resource_divider := overlay.get_node_or_null("ResourceDivider") as ColorRect
	if resource_divider != null:
		resource_divider.position = Vector2(divider_x, height - PauseMenuLayoutScript.RESOURCE_PANEL_HEIGHT)
		resource_divider.size = Vector2(maxf(width - divider_x - 1.0, 1.0), 1.0)
	var visible_command_index := 0
	for index in menu_buttons.size():
		if menu_buttons[index].visible:
			menu_buttons[index].position = PauseMenuLayoutScript.command_button_position(view_size, visible_command_index)
			visible_command_index += 1
		else:
			menu_buttons[index].position = PauseMenuLayoutScript.command_button_position(view_size, index)
	if debug_menu_layout != null: debug_menu_layout.apply_layout(view_size)
	if items_presenter != null:
		items_presenter.position_controls(view_size)
	if back_button != null: back_button.position = PauseMenuLayoutScript.back_button_position(view_size)
	if player_portrait != null:
		player_portrait.position = Vector2(PauseMenuLayoutScript.left_field_x(PauseMenuLayoutScript.PLAYER_PORTRAIT_POSITION.x, width), PauseMenuLayoutScript.PLAYER_PORTRAIT_POSITION.y)
	for index in player_card_texts.size():
		var authored_position: Vector2 = PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[index] if index < PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.size() else PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.back()
		player_card_texts[index].position = Vector2(PauseMenuLayoutScript.left_field_x(authored_position.x, width), authored_position.y)
	for index in status_texts.size():
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		var authored_x := 14.0 if column == 0 else 122.0
		status_texts[index].position = Vector2(PauseMenuLayoutScript.left_field_x(authored_x, width), 28 + row * 10)
	for index in equipment_texts.size(): equipment_texts[index].position = Vector2(14, 28 + index * 12)
	if equipment_menu != null:
		equipment_menu.position = Vector2.ZERO
		equipment_menu.size = view_size
	if description_text != null: description_text.position = PauseMenuLayoutScript.select_prompt_position(view_size)
	if gold_icon != null: gold_icon.position = PauseMenuLayoutScript.resource_icon_position(view_size, false)
	if resource_icon != null: resource_icon.position = PauseMenuLayoutScript.resource_icon_position(view_size, true)
	position_resource_texts(view_size)


func update_page_visibility(page: int, debug_menu_enabled: bool, pixel_texture: Callable) -> bool:
	for page_root: Control in page_roots.values():
		page_root.visible = false
	var active_page := page_roots.get(page) as Control
	if active_page != null:
		active_page.visible = true
	var showing_root := page == PauseMenuStateScript.COMMAND_PAGE
	var equipment_view_active := page == PauseMenuStateScript.EQUIPMENT_PAGE and equipment_menu != null
	if equipment_menu != null:
		equipment_menu.visible = equipment_view_active
		equipment_menu.stop_cursor_motion()
		if equipment_view_active:
			equipment_menu.set_pixel_texture(pixel_texture)
	var equipment_page_root := page_roots.get(PauseMenuStateScript.EQUIPMENT_PAGE) as Control
	if equipment_page_root != null:
		for chrome_name in ["Background", "TitleTab", "Title", "TitleRule"]:
			var chrome := equipment_page_root.get_node_or_null(chrome_name) as CanvasItem
			if chrome != null:
				chrome.visible = not equipment_view_active
	var root_panel := overlay.get_node_or_null("PausePanel8Piece") as Control
	if root_panel != null:
		root_panel.visible = false
	for index in menu_buttons.size():
		var debug_command_hidden := index == 4 and not debug_menu_enabled
		menu_buttons[index].visible = showing_root and not debug_command_hidden
		menu_buttons[index].disabled = debug_command_hidden
	if back_button != null:
		back_button.visible = not equipment_view_active
	for node in status_texts:
		node.visible = page == PauseMenuStateScript.STATUS_PAGE
	for node in equipment_texts:
		node.visible = page == PauseMenuStateScript.EQUIPMENT_PAGE and not equipment_view_active
	if description_text != null:
		description_text.visible = not equipment_view_active
	if gold_icon != null:
		gold_icon.visible = showing_root
	if resource_icon != null:
		resource_icon.visible = showing_root
	if gold_text != null:
		gold_text.visible = showing_root
	if soul_text != null:
		soul_text.visible = showing_root
	return equipment_view_active


func update_navigation_prompts(
	highlight: Color,
	equipment_view_active: bool,
	back_prompt: String,
	confirm_prompt: String,
	pixel_texture: Callable
) -> void:
	for button in menu_buttons:
		# The command rail is text-only; the cursor is its selected-state treatment.
		_widget_factory.set_archetype_button_state(button, false, highlight)
		_prompt_texture_factory.set_menu_button_icon(button, null, false)
	if back_button != null:
		back_button.visible = not equipment_view_active
		_widget_factory.set_archetype_button_state(back_button, false, highlight)
		_prompt_texture_factory.set_button_text(back_button, back_prompt, pixel_texture, PauseMenuLayoutScript.MUTED_TEXT_COLOR)
	if description_text != null:
		description_text.texture = _prompt_texture_factory.pixel_prompt_texture(pixel_texture, confirm_prompt, PauseMenuLayoutScript.MUTED_TEXT_COLOR)


func update_selected_cursor(page: int, selected_row: int, cursor_left_gap: float, tween_owner: Node) -> void:
	if cursor_text != null and not menu_buttons.is_empty():
		var cursor_index := clampi(selected_row, 0, menu_buttons.size() - 1)
		cursor_text.visible = page == PauseMenuStateScript.COMMAND_PAGE
		var button := menu_buttons[cursor_index]
		_cursor_animator.move_menu_cursor(
			cursor_text,
			Vector2(button.position.x - cursor_left_gap, button.position.y + 3.0),
			true,
			tween_owner
		)


func position_resource_texts(view_size: Vector2) -> void:
	if gold_text != null and gold_text.texture != null:
		gold_text.position = PauseMenuLayoutScript.resource_text_position(view_size, gold_text.texture.get_width(), false)
	if soul_text != null and soul_text.texture != null:
		soul_text.position = PauseMenuLayoutScript.resource_text_position(view_size, soul_text.texture.get_width(), true)


func update_player_info(context: MenuPlayerContext, pixel_texture: Callable, view_size: Vector2) -> void:
	if player_card_texts.is_empty() or context == null or not context.is_valid():
		return
	var profile: PlayerProfile = context.profile
	var values := [
		PlayerProfile.normalize_player_name(profile.player_name),
		context.element_display_name(),
		"HP",
		"%d/%d" % [context.current_health(), context.max_health()],
		"CHR",
		"%d/%d" % [context.chroma(), context.max_chroma()],
		"LV %d" % profile.level,
	]
	for index in player_card_texts.size():
		var text := player_card_texts[index]
		text.visible = true
		var label: String = str(values[index]) if index < values.size() else ""
		var label_color := PauseMenuLayoutScript.MUTED_TEXT_COLOR if index == 1 else Color.WHITE
		text.texture = pixel_texture.call(label, label_color) as Texture2D
	if player_portrait != null:
		var portrait_texture := context.portrait_texture()
		if portrait_texture != null:
			player_portrait.texture = portrait_texture
	update_resources(profile, pixel_texture, view_size)


func update_resources(profile: PlayerProfile, pixel_texture: Callable, view_size: Vector2) -> void:
	if profile == null:
		return
	if gold_icon != null:
		gold_icon.visible = true
	if resource_icon != null:
		resource_icon.visible = true
		resource_icon.texture = SoulVisualsScript.texture()
	if gold_text != null:
		gold_text.texture = pixel_texture.call(str(profile.gold), PauseMenuLayoutScript.GOLD_TEXT_COLOR) as Texture2D
	if soul_text != null:
		soul_text.texture = pixel_texture.call(str(profile.souls), SoulVisualsScript.SOUL_HIGHLIGHT_COLOR) as Texture2D
	position_resource_texts(view_size)


func update_status(context: MenuPlayerContext, pixel_texture: Callable) -> void:
	_page_data_presenter.update_status(context, pixel_texture, status_texts, description_text)


func update_equipment(profile: PlayerProfile, pixel_texture: Callable) -> void:
	_page_data_presenter.update_equipment(profile, pixel_texture, equipment_texts, description_text)


func refresh_debug_menu(context: PauseDebugMenuContext, pixel_texture: Callable) -> void:
	_page_data_presenter.refresh_debug_menu(debug_menu_layout, context, pixel_texture)


func _request_debug_page() -> void:
	debug_page_requested.emit()


func _forward_debug_action_requested(action: StringName, amount: int) -> void:
	debug_action_requested.emit(action, amount)
