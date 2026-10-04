extends RefCounted
class_name HubResponsiveLayoutPresenter

const HubResponsiveLayoutContextScript = preload("res://scripts/ui/hub_responsive_layout_context.gd")
const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")
const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")
const HubStatsScreenPresenterScript = preload("res://scripts/ui/hub_stats_screen_presenter.gd")
const MenuCursorAnimatorScript = preload("res://scripts/ui/menu_cursor_animator.gd")
const MenuPromptTextureFactoryScript = preload("res://scripts/ui/menu_prompt_texture_factory.gd")

const CURSOR_LEFT_GAP := 10.0
const CURSOR_VERTICAL_RAISE := MenuCursorAnimatorScript.CURSOR_VERTICAL_RAISE
const LEGACY_ITEM_VISIBLE_ROWS := 6
const LEGACY_GEAR_CHOICE_VISIBLE_ROWS := 4
const HUB_ITEM_DETAIL_TOP := 105.0
const HUB_ITEM_DETAIL_PITCH := 7.0
const HUB_ITEM_DETAIL_PANEL_TOP := 103.0
const HUB_ITEM_DETAIL_PANEL_HEIGHT := 42.0
const HUB_GEAR_BROWSE_DETAIL_TOP := 136.0
const HUB_COMMAND_BUTTON_Y := 5.0
const STATUS_LEFT_ROW_COUNT := HubStatsScreenPresenterScript.STATUS_LEFT_ROW_COUNT
const STAT_VALUE_RIGHT_ANCHOR := HubStatsScreenPresenterScript.STAT_VALUE_RIGHT_ANCHOR
const STAT_LABEL_X := HubStatsScreenPresenterScript.STAT_LABEL_X
const STAT_LABEL_TOP := HubStatsScreenPresenterScript.STAT_LABEL_TOP
const STAT_ROW_PITCH := HubStatsScreenPresenterScript.STAT_ROW_PITCH
const STAT_SUBTRACT_MARKER_X := HubStatsScreenPresenterScript.STAT_SUBTRACT_MARKER_X
const STAT_ADD_MARKER_X := HubStatsScreenPresenterScript.STAT_ADD_MARKER_X
const DERIVED_LABEL_X := HubStatsScreenPresenterScript.DERIVED_LABEL_X
const DERIVED_LABEL_TOP := HubStatsScreenPresenterScript.DERIVED_LABEL_TOP
const DERIVED_ROW_PITCH := HubStatsScreenPresenterScript.DERIVED_ROW_PITCH
const DERIVED_VALUE_RIGHT_ANCHOR := HubStatsScreenPresenterScript.DERIVED_VALUE_RIGHT_ANCHOR
const STAT_CURSOR_X := HubStatsScreenPresenterScript.STAT_CURSOR_X
const STAT_UTILITY_Y := HubStatsScreenPresenterScript.STAT_UTILITY_Y

var hub_gold_text: Sprite2D = null
var hub_soul_text: Sprite2D = null
var hub_gold_icon: Sprite2D = null
var hub_soul_icon: Sprite2D = null
var hub_list_cursor: Sprite2D = null
var hub_shop_cursor: Sprite2D = null
var hub_slot_cursor: Sprite2D = null
var hub_choice_cursor: Sprite2D = null
var hub_gear_choice_texts: Array[Sprite2D] = []
var hub_gear_choice_buttons: Array[Button] = []
var hub_gear_slot_buttons: Array[Button] = []
var hub_gear_stat_texts: Array[Sprite2D] = []
var hub_gear_stat_panel: Panel = null
var hub_item_list_panel: Panel = null
var hub_item_content_clip: Control = null
var hub_gear_choice_panel: Panel = null
var hub_gear_choice_content_clip: Control = null
var hub_back_prompt_text: Sprite2D = null
var hub_footer_select_glyph: Sprite2D = null
var hub_footer_select_text: Sprite2D = null
var hub_footer_back_glyph: Sprite2D = null
var hub_footer_back_text: Sprite2D = null
var hub_player_card_panel: Panel = null
var hub_player_card_texts: Array[Sprite2D] = []
var hub_context_text: Sprite2D = null
var hub_binding_panel: Panel = null
var hub_binding_texts: Array[Sprite2D] = []
var hub_binding_action_button: Button = null
var hub_fusion_menu: Control = null
var hub_bind_menu: Control = null
var hub_item_name_text: Sprite2D = null
var hub_item_list_texts: Array[Sprite2D] = []
var hub_item_row_buttons: Array[Button] = []
var hub_shop_price_texts: Array[Sprite2D] = []
var hub_item_detail_texts: Array[Sprite2D] = []
var hub_item_detail_panel: Panel = null
var hub_item_action_button: Button = null
var hub_shop_mode_buttons: Array[Button] = []
var hub_shop_menu: Control = null
var hub_equipment_action_buttons: Array[Button] = []
var hub_equipment_menu: Control = null
var hub_fusion_decrease_button: Button = null
var hub_fusion_increase_button: Button = null


func build_shell_chrome(
	root_page: Control,
	overlay: ColorRect,
	widget_factory: MenuWidgetFactory,
	gold_texture: Texture2D,
	soul_texture: Texture2D
) -> Sprite2D:
	hub_player_card_panel = widget_factory.make_menu_card(root_page, "HubPlayerCard", Vector2(10, 27), Vector2(136, 72))
	hub_player_card_texts.clear()
	for index in 7:
		hub_player_card_texts.append(widget_factory.create_sprite(root_page, "HubCardText%d" % index, null, Vector2(16, 33 + index * 10), false))
	var summary := widget_factory.create_sprite(root_page, "HubSummary", null, Vector2(16, 106), false)
	hub_context_text = widget_factory.create_sprite(overlay, "HubContext", null, Vector2(136, 151), false)
	hub_back_prompt_text = widget_factory.create_sprite(overlay, "HubBackPrompt", null, Vector2(136, 141), false)
	hub_back_prompt_text.visible = false
	# Keep the shared footer aligned with the authored Shop and Stats anchors.
	hub_footer_select_glyph = widget_factory.create_sprite(overlay, "HubFooterSelectGlyph", MenuPromptTextureFactoryScript.MENU_CIRCLE_TEXTURE, Vector2(107, 146), false)
	hub_footer_select_text = widget_factory.create_sprite(overlay, "HubFooterSelectText", null, Vector2(114, 146), false)
	hub_footer_back_glyph = widget_factory.create_sprite(overlay, "HubFooterBackGlyph", MenuPromptTextureFactoryScript.MENU_X_TEXTURE, Vector2(146, 146), false)
	hub_footer_back_text = widget_factory.create_sprite(overlay, "HubFooterBackText", null, Vector2(153, 146), false)
	var gold_icon := Sprite2D.new()
	gold_icon.name = "HubGoldIcon"
	gold_icon.centered = false
	gold_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gold_icon.texture = gold_texture
	gold_icon.region_enabled = true
	gold_icon.region_rect = Rect2(0, 0, 5, 5)
	gold_icon.position = Vector2(182, 142)
	gold_icon.z_index = 2
	overlay.add_child(gold_icon)
	hub_gold_icon = gold_icon
	var soul_icon := Sprite2D.new()
	soul_icon.name = "HubSoulIcon"
	soul_icon.centered = false
	soul_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	soul_icon.texture = soul_texture
	soul_icon.position = Vector2(182, 149)
	soul_icon.z_index = 2
	overlay.add_child(soul_icon)
	hub_soul_icon = soul_icon
	hub_gold_text = widget_factory.create_sprite(overlay, "HubGoldText", null, Vector2(229, 139), false)
	hub_soul_text = widget_factory.create_sprite(overlay, "HubSoulText", null, Vector2(229, 149), false)
	return summary


func update_footer_content(
	page: int,
	equipment_view_active: bool,
	confirm_prompt_texture: Texture2D,
	back_prompt_texture: Texture2D,
	pixel_texture: Callable
) -> void:
	if hub_context_text != null:
		hub_context_text.visible = page != HubMenuStateScript.HUB_PAGE_SHOP
		hub_context_text.texture = confirm_prompt_texture
		if equipment_view_active:
			hub_context_text.visible = true
	if hub_back_prompt_text != null:
		hub_back_prompt_text.visible = false
		hub_back_prompt_text.texture = back_prompt_texture
	if hub_context_text != null:
		hub_context_text.visible = false
	var footer_visible := page != HubMenuStateScript.HUB_PAGE_SHOP and page != HubMenuStateScript.HUB_PAGE_FUSION
	if hub_footer_select_glyph != null:
		hub_footer_select_glyph.visible = footer_visible
		hub_footer_select_glyph.texture = MenuPromptTextureFactoryScript.MENU_CIRCLE_TEXTURE
	if hub_footer_select_text != null:
		hub_footer_select_text.visible = footer_visible
		hub_footer_select_text.texture = pixel_texture.call("FUSE" if page == HubMenuStateScript.HUB_PAGE_FUSION else "SELECT", Color.WHITE) as Texture2D
	if hub_footer_back_glyph != null:
		hub_footer_back_glyph.visible = footer_visible
		hub_footer_back_glyph.texture = MenuPromptTextureFactoryScript.MENU_X_TEXTURE
	if hub_footer_back_text != null:
		hub_footer_back_text.visible = footer_visible
		hub_footer_back_text.texture = pixel_texture.call("BACK", Color.WHITE) as Texture2D


func position_controls(context: HubResponsiveLayoutContext) -> void:
	var overlay := context.overlay
	if overlay == null:
		return
	var view_size := context.view_size
	overlay.position = Vector2.ZERO
	overlay.size = view_size
	_position_frame_and_navigation(context, view_size)
	_position_player_card_and_prompts(context, view_size.x)
	_position_stats(context, view_size.x)
	_position_inventory(context, view_size.x)
	_position_child_menus(view_size)
	context.commands.position_cursor(
		context.menu_row,
		context.is_root,
		context.animate_cursor,
		context.preserve_cursor_motion,
		context.cursor_animator,
		context.tween_owner
	)
	_reanchor_legacy_cursors(context)

func _position_frame_and_navigation(context: HubResponsiveLayoutContext, view_size: Vector2) -> void:
	var overlay := context.overlay
	var width := view_size.x
	# Native hub geometry is authored at 240x160. Keep command/resource cells
	# edge-anchored while content labels spread across wider logical viewports.
	var resource_left := maxf(width - 63.0, 177.0)
	var command_left := maxf(resource_left - 87.0, 90.0)
	var title_panel := overlay.get_node_or_null("HubTitlePanel") as Control
	if title_panel != null:
		title_panel.position = Vector2.ZERO
		title_panel.size = Vector2(maxf(command_left - 1.0, 1.0), 21)
	var command_panel := overlay.get_node_or_null("HubCommandPanel") as Control
	if command_panel != null:
		command_panel.position = Vector2(command_left, 0)
		command_panel.size = Vector2(maxf(width - command_left, 1.0), 21)
	var content_panel := overlay.get_node_or_null("HubContentPanel") as Control
	if content_panel != null:
		content_panel.position = Vector2(0, 21)
		content_panel.size = Vector2(maxf(width, 1.0), 115)
	var footer_panel := overlay.get_node_or_null("HubFooterPanel") as Control
	if footer_panel != null:
		footer_panel.position = Vector2(0, 136)
		footer_panel.size = Vector2(maxf(resource_left - 2.0, 1.0), 24)
	var resource_panel := overlay.get_node_or_null("HubResourcePanel") as Control
	if resource_panel != null:
		resource_panel.position = Vector2(resource_left, 136)
		resource_panel.size = Vector2(maxf(width - resource_left, 1.0), 24)
	var root_panel := overlay.get_node_or_null("HubPanel8Piece") as Control
	if root_panel != null:
		root_panel.position = Vector2.ZERO
		root_panel.size = view_size
		root_panel.visible = false
	if hub_gold_icon != null: hub_gold_icon.position = Vector2(resource_left + 5.0, 142)
	if hub_soul_icon != null: hub_soul_icon.position = Vector2(resource_left + 5.0, 149)
	if hub_gold_text != null:
		var gold_width := float(hub_gold_text.texture.get_width()) if hub_gold_text.texture != null else 0.0
		hub_gold_text.position = Vector2(width - gold_width - 6.0, 142)
	if hub_soul_text != null:
		var soul_width := float(hub_soul_text.texture.get_width()) if hub_soul_text.texture != null else 0.0
		hub_soul_text.position = Vector2(width - soul_width - 6.0, 149)
	for page_root: Control in context.pages.page_roots.values():
		page_root.position = Vector2.ZERO
		page_root.size = view_size
		var page_background := page_root.get_node_or_null("Background") as NinePatchRect
		if page_background != null: page_background.size = view_size
		var page_title_rule := page_root.get_node_or_null("TitleRule") as ColorRect
		if page_title_rule != null: page_title_rule.size.x = maxf(width - 16.0, 16.0)
	var root_title_rule := context.pages.root_page.get_node_or_null("TitleRule") as ColorRect if context.pages.root_page != null else null
	if root_title_rule != null: root_title_rule.size.x = 0.0
	for index in context.commands.page_buttons.size():
		var authored_x: float = [99.0, 132.0, 166.0, 202.0][clampi(index, 0, 3)]
		var authored_width: float = [27.0, 28.0, 31.0, 31.0][clampi(index, 0, 3)]
		var ratio: float = (authored_x - 90.0) / 150.0
		var button_x: float = command_left + ratio * maxf(width - command_left, 1.0)
		context.commands.page_buttons[index].position = Vector2(floorf(button_x), HUB_COMMAND_BUTTON_Y)
		context.commands.page_buttons[index].size = Vector2(authored_width, 12.0)
	if context.commands.back_button != null:
		context.commands.back_button.position = PauseMenuLayoutScript.back_button_position(view_size)

func _position_player_card_and_prompts(context: HubResponsiveLayoutContext, width: float) -> void:
	var overlay := context.overlay
	if hub_player_card_panel != null:
		hub_player_card_panel.position = Vector2(_left_field_x(10.0, width), 27)
		hub_player_card_panel.size = Vector2(minf(150.0, maxf(136.0, width - 100.0)), 72)
	for index in hub_player_card_texts.size():
		hub_player_card_texts[index].position = Vector2(_left_field_x(16.0, width), 33 + index * 10)
	var summary := overlay.get_node_or_null("HubRootPage/HubSummary") as Sprite2D
	if summary != null:
		summary.position = Vector2(_left_field_x(16.0, width), 106)
		summary.texture = null
		summary.visible = false
	if context.stats.points_text != null: context.stats.points_text.position = Vector2(_left_field_x(14.0, width), 27)
	if hub_back_prompt_text != null: hub_back_prompt_text.position = Vector2(_left_field_x(136.0, width), 141)
	if hub_context_text != null: hub_context_text.position = Vector2(_left_field_x(136.0, width), 151)
	if hub_footer_select_glyph != null: hub_footer_select_glyph.position = Vector2(_left_field_x(107.0, width), 146)
	if hub_footer_select_text != null: hub_footer_select_text.position = Vector2(_left_field_x(114.0, width), 146)
	if hub_footer_back_glyph != null: hub_footer_back_glyph.position = Vector2(_left_field_x(146.0, width), 146)
	if hub_footer_back_text != null: hub_footer_back_text.position = Vector2(_left_field_x(153.0, width), 146)

func _position_stats(context: HubResponsiveLayoutContext, width: float) -> void:
	var allocation_preview_x := maxf(132.0, width - 108.0)
	var allocation_left_width := maxf(108.0, allocation_preview_x - 24.0)
	if context.stats.allocate_panel != null:
		context.stats.allocate_panel.position = Vector2(_left_field_x(14.0, width), 35)
		context.stats.allocate_panel.size = Vector2(allocation_left_width, 72)
	if context.stats.allocate_preview_panel != null:
		context.stats.allocate_preview_panel.position = Vector2(allocation_preview_x, 35)
		context.stats.allocate_preview_panel.size = Vector2(maxf(82.0, width - allocation_preview_x - 14.0), 72)
	if context.stats.allocate_preview_title != null: context.stats.allocate_preview_title.position = Vector2(allocation_preview_x + 6.0, 40)
	for index in context.stats.allocate_preview_texts.size(): context.stats.allocate_preview_texts[index].position = Vector2(allocation_preview_x + 6.0, 47 + index * 8)
	for index in context.stats.derived_texts.size():
		context.stats.derived_texts[index].position = Vector2(_left_field_x(DERIVED_LABEL_X, width), DERIVED_LABEL_TOP + index * DERIVED_ROW_PITCH)
		if index < context.stats.derived_value_texts.size():
			var derived_texture_width: float = float(context.stats.derived_value_texts[index].texture.get_width()) if context.stats.derived_value_texts[index].texture != null else 40.0
			context.stats.derived_value_texts[index].position = Vector2(_left_field_x(DERIVED_VALUE_RIGHT_ANCHOR, width) - derived_texture_width, DERIVED_LABEL_TOP + index * DERIVED_ROW_PITCH)
	for index in context.stats.stat_texts.size():
		var y := STAT_LABEL_TOP + index * STAT_ROW_PITCH
		context.stats.stat_texts[index].position = Vector2(_left_field_x(STAT_LABEL_X, width), y)
		if index < context.stats.stat_value_texts.size():
			var stat_texture_width: float = float(context.stats.stat_value_texts[index].texture.get_width()) if context.stats.stat_value_texts[index].texture != null else 4.0
			context.stats.stat_value_texts[index].position = Vector2(_left_field_x(STAT_VALUE_RIGHT_ANCHOR, width) - stat_texture_width, y)
		if index < context.stats.stat_row_buttons.size():
			context.stats.stat_row_buttons[index].position = Vector2(_left_field_x(STAT_CURSOR_X, width), y - 5.0)
			context.stats.stat_row_buttons[index].size = Vector2(maxf(18.0, _left_field_x(HubStatsScreenPresenterScript.STAT_ROW_RIGHT_ARROW_X + 9.0, width) - _left_field_x(STAT_CURSOR_X, width)), 12)
		var marker_center_y := STAT_LABEL_TOP + 2.5 + index * STAT_ROW_PITCH
		if index < context.stats.stat_left_buttons.size():
			var left_button := context.stats.stat_left_buttons[index]
			left_button.position = Vector2(_left_field_x(STAT_SUBTRACT_MARKER_X, width) - left_button.size.x * 0.5, marker_center_y - left_button.size.y * 0.5)
		if index < context.stats.stat_right_buttons.size():
			var right_button := context.stats.stat_right_buttons[index]
			right_button.position = Vector2(_left_field_x(STAT_ADD_MARKER_X, width) - right_button.size.x * 0.5, marker_center_y - right_button.size.y * 0.5)
	context.stats.position_markers(context.stat_row, context.page == HubMenuStateScript.HUB_PAGE_ALLOCATE and context.content_focus, context.view_size)
	var utility_x := [44.0, 79.0, 114.0, 149.0]
	var utility_buttons: Array[Button] = [context.stats.apply_button, context.stats.cancel_button, context.stats.auto_button, context.stats.respec_button]
	for index in utility_buttons.size():
		if utility_buttons[index] != null: utility_buttons[index].position = Vector2(_left_field_x(utility_x[index], width), STAT_UTILITY_Y)
	for index in context.stats.status_texts.size():
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		var authored_x: float = 14.0 if column == 0 else 122.0
		context.stats.status_texts[index].position = Vector2(_left_field_x(authored_x, width), 42 + row * 10)

func _position_inventory(context: HubResponsiveLayoutContext, width: float) -> void:
	# Keep the item list and gear card separated by a ten-pixel gutter.
	var gear_x: float = maxf(_left_field_x(174.0, width), width * 0.58)
	var list_left: float = _left_field_x(14.0, width)
	var list_width: float = maxf(120.0, gear_x - list_left - 10.0)
	var equipment_page := context.page == HubMenuStateScript.HUB_PAGE_EQUIPMENT
	var list_height := 54.0 if equipment_page else 62.0
	var item_row_pitch := 9.0 if equipment_page else 10.0
	if hub_item_list_panel != null:
		hub_item_list_panel.position = Vector2(list_left, 35)
		hub_item_list_panel.size = Vector2(list_width, list_height)
	if hub_item_content_clip != null:
		hub_item_content_clip.position = Vector2(list_left, 35)
		hub_item_content_clip.size = Vector2(list_width, list_height)
	for index in hub_item_list_texts.size():
		hub_item_list_texts[index].position = Vector2(6, 4 + index * item_row_pitch)
		if index < hub_item_row_buttons.size():
			hub_item_row_buttons[index].position = Vector2(0, index * item_row_pitch)
			hub_item_row_buttons[index].size = Vector2(list_width, item_row_pitch)
		if index < hub_shop_price_texts.size(): hub_shop_price_texts[index].position = Vector2(maxf(gear_x, width - 62.0), 39 + index * item_row_pitch)
	var gear_row_pitch := 9.0
	for index in hub_gear_slot_buttons.size():
		hub_gear_slot_buttons[index].position = Vector2(0, index * gear_row_pitch)
		hub_gear_slot_buttons[index].size = Vector2(list_width, gear_row_pitch)
	for index in hub_gear_choice_texts.size():
		hub_gear_choice_texts[index].position = Vector2(6, 4 + index * 10)
		if index < hub_gear_choice_buttons.size():
			hub_gear_choice_buttons[index].position = Vector2(0, index * 10)
			hub_gear_choice_buttons[index].size = Vector2(list_width, 10)
	if hub_gear_choice_panel != null:
		hub_gear_choice_panel.position = Vector2(list_left, 91)
		hub_gear_choice_panel.size = Vector2(list_width, 42)
	if hub_gear_choice_content_clip != null:
		hub_gear_choice_content_clip.position = Vector2(list_left, 91)
		hub_gear_choice_content_clip.size = Vector2(list_width, 42)
	if hub_gear_stat_panel != null:
		hub_gear_stat_panel.position = Vector2(gear_x, 35)
		hub_gear_stat_panel.size = Vector2(maxf(48.0, width - gear_x - 10.0), 66)
	var gear_stat_y := 40.0 if equipment_page else 41.0
	var gear_stat_pitch := 8.0 if equipment_page else 9.0
	for index in hub_gear_stat_texts.size(): hub_gear_stat_texts[index].position = Vector2(gear_x + 6.0, gear_stat_y + index * gear_stat_pitch)
	var gear_browse_details := equipment_page and context.gear_browsing
	if hub_item_detail_panel != null:
		hub_item_detail_panel.position = Vector2(14, HUB_GEAR_BROWSE_DETAIL_TOP - 2.0 if gear_browse_details else HUB_ITEM_DETAIL_PANEL_TOP)
		hub_item_detail_panel.size = Vector2(maxf(width - 28.0, 80.0), 11.0 if gear_browse_details else HUB_ITEM_DETAIL_PANEL_HEIGHT)
	var detail_top := HUB_GEAR_BROWSE_DETAIL_TOP if gear_browse_details else HUB_ITEM_DETAIL_TOP
	if hub_item_detail_panel != null:
		hub_item_detail_panel.position.x = list_left
		hub_item_detail_panel.size.x = maxf(width - list_left - 14.0, 80.0)
	for index in hub_item_detail_texts.size(): hub_item_detail_texts[index].position = Vector2(_left_field_x(20.0, width), detail_top + index * HUB_ITEM_DETAIL_PITCH)
	if hub_item_name_text != null: hub_item_name_text.position = Vector2(_left_field_x(14.0, width), 25)
	if hub_item_action_button != null: hub_item_action_button.position = Vector2(maxf(96.0, width - 144.0), 21)
	for index in hub_equipment_action_buttons.size():
		hub_equipment_action_buttons[index].position = Vector2(_left_field_x([14.0, 64.0, 122.0][mini(index, 2)], width), 22)
	if hub_fusion_decrease_button != null: hub_fusion_decrease_button.position = Vector2(_left_field_x(14.0, width), 119)
	if hub_fusion_increase_button != null: hub_fusion_increase_button.position = Vector2(_left_field_x(39.0, width), 119)
	if hub_binding_panel != null:
		hub_binding_panel.position = Vector2(_left_field_x(14.0, width), 33)
		hub_binding_panel.size = Vector2(maxf(width - hub_binding_panel.position.x - 14.0, 80.0), 72)
	for index in hub_binding_texts.size(): hub_binding_texts[index].position = Vector2(_left_field_x(22.0, width), 41 + index * (12 if index < 4 else 14))
	if hub_binding_action_button != null: hub_binding_action_button.position = Vector2(width - 78.0, 119)

func _position_child_menus(view_size: Vector2) -> void:
	for menu: Control in [hub_equipment_menu, hub_shop_menu, hub_fusion_menu, hub_bind_menu]:
		if menu != null:
			menu.position = Vector2.ZERO
			menu.size = view_size

func _reanchor_legacy_cursors(context: HubResponsiveLayoutContext) -> void:
	context.stats.position_cursor(
		context.stat_row,
		context.action_column,
		context.view_size,
		context.animate_cursor,
		context.preserve_cursor_motion,
		context.cursor_animator,
		context.tween_owner
	)
	var list_cursor_x: float = _left_field_x(20.0, context.view_size.x) - CURSOR_LEFT_GAP
	for cursor in [hub_list_cursor, hub_slot_cursor, hub_choice_cursor]:
		if cursor == null or not cursor.visible:
			continue
		# Keep the existing vertical position while replacing the stale native x
		# origin, compensating for the shared cursor raise during reanchoring.
		context.cursor_animator.position_menu_cursor(
			cursor,
			Vector2(list_cursor_x, cursor.position.y + CURSOR_VERTICAL_RAISE),
			context.animate_cursor,
			context.preserve_cursor_motion,
			context.tween_owner
		)


func _left_field_x(native_x: float, viewport_width: float) -> float:
	return PauseMenuLayoutScript.left_field_x(native_x, viewport_width)
