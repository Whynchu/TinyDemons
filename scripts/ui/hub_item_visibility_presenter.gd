extends RefCounted
class_name HubItemVisibilityPresenter

## Applies route visibility and hit filtering to legacy item, equipment, shop, and fusion widgets.
const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")
const HubResponsiveLayoutPresenterScript = preload("res://scripts/ui/hub_responsive_layout_presenter.gd")
const CURSOR_LEFT_GAP := HubResponsiveLayoutPresenterScript.CURSOR_LEFT_GAP

# The responsive presenter creates and positions these legacy controls. This
# presenter applies their route visibility and input state.
var widgets: HubResponsiveLayoutPresenter
var shop_cursor: Sprite2D
var widget_factory: MenuWidgetFactory
var prompt_texture_factory: MenuPromptTextureFactory
var cursor_animator: MenuCursorAnimator
var tween_owner: Node


func bind(
	responsive_layout: HubResponsiveLayoutPresenter,
	shop_menu_cursor: Sprite2D,
	menu_widget_factory: MenuWidgetFactory,
	menu_prompt_texture_factory: MenuPromptTextureFactory,
	menu_cursor_animator: MenuCursorAnimator,
	owner: Node
) -> void:
	widgets = responsive_layout
	shop_cursor = shop_menu_cursor
	widget_factory = menu_widget_factory
	prompt_texture_factory = menu_prompt_texture_factory
	cursor_animator = menu_cursor_animator
	tween_owner = owner


func update(context: HubItemVisibilityContext) -> void:
	if context == null or widgets == null:
		return
	var page := context.page
	var profile := context.profile
	var gear_browsing := page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and context.gear_browsing
	var equipment_action_state := page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and context.equipment_action_focus and not gear_browsing
	var equipment_content_state := page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and not equipment_action_state
	for button in widgets.hub_gear_choice_buttons:
		button.visible = gear_browsing
	for equipment_action_index in widgets.hub_equipment_action_buttons.size():
		var equipment_action := widgets.hub_equipment_action_buttons[equipment_action_index]
		# Hide inactive route controls so stale buttons cannot take controller or
		# touch input while the command row, slots, and picker replace one another.
		equipment_action.visible = equipment_action_state
		equipment_action.mouse_filter = Control.MOUSE_FILTER_STOP if equipment_action_state else Control.MOUSE_FILTER_IGNORE
		var action_active := page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and context.content_focus and context.equipment_action_focus and equipment_action_index == context.action_column
		widget_factory.set_archetype_button_state(equipment_action, action_active, context.highlight_color)
		prompt_texture_factory.set_menu_button_icon(equipment_action, null, false)
	if page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and widgets.hub_equipment_action_buttons.size() >= 3 and profile != null:
		var selected_slot: StringName = ItemCatalog.SLOTS[clampi(context.item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var equipped_item := profile.find_item(profile.get_equipped_instance_id(selected_slot))
		widgets.hub_equipment_action_buttons[1].disabled = equipped_item == null
		widgets.hub_equipment_action_buttons[2].disabled = profile.equipped_instance_ids.values().all(func(id: String) -> bool: return str(id).is_empty())
	for button in widgets.hub_item_row_buttons:
		button.visible = false
	if widgets.hub_fusion_decrease_button != null:
		widgets.hub_fusion_decrease_button.visible = page == HubMenuStateScript.HUB_PAGE_FUSION
		widgets.hub_fusion_decrease_button.disabled = true
	if widgets.hub_fusion_increase_button != null:
		widgets.hub_fusion_increase_button.visible = page == HubMenuStateScript.HUB_PAGE_FUSION
		widgets.hub_fusion_increase_button.disabled = true
	var item_page := page >= HubMenuStateScript.HUB_PAGE_EQUIPMENT and page <= HubMenuStateScript.HUB_PAGE_FUSION
	if widgets.hub_item_name_text != null:
		widgets.hub_item_name_text.visible = item_page and not equipment_action_state
	for node in widgets.hub_item_list_texts:
		node.visible = item_page and not equipment_action_state
	for node in widgets.hub_shop_price_texts:
		node.visible = page == HubMenuStateScript.HUB_PAGE_SHOP
	for node in widgets.hub_gear_choice_texts:
		node.visible = gear_browsing
	for button in widgets.hub_gear_slot_buttons:
		button.visible = equipment_content_state
		button.mouse_filter = Control.MOUSE_FILTER_STOP if page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and not context.equipment_action_focus and not gear_browsing else Control.MOUSE_FILTER_IGNORE
	var inventory_page := (page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and not equipment_action_state) or page == HubMenuStateScript.HUB_PAGE_SHOP or page == HubMenuStateScript.HUB_PAGE_FUSION
	if widgets.hub_item_list_panel != null:
		widgets.hub_item_list_panel.visible = inventory_page
	if widgets.hub_item_content_clip != null:
		widgets.hub_item_content_clip.visible = inventory_page
	if widgets.hub_gear_choice_panel != null:
		widgets.hub_gear_choice_panel.visible = gear_browsing
	if widgets.hub_gear_choice_content_clip != null:
		widgets.hub_gear_choice_content_clip.visible = gear_browsing
	var show_gear_stats := (page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and not equipment_action_state) or page == HubMenuStateScript.HUB_PAGE_FUSION
	for node in widgets.hub_gear_stat_texts:
		node.visible = show_gear_stats
	# Equipment and Fusion share the right-hand comparison card; the slot list
	# remains on the left so long item names cannot draw through the stat column.
	if widgets.hub_gear_stat_panel != null:
		widgets.hub_gear_stat_panel.visible = show_gear_stats
	if widgets.hub_item_detail_panel != null:
		widgets.hub_item_detail_panel.visible = item_page and not equipment_action_state
	for node in widgets.hub_item_detail_texts:
		node.visible = item_page and not equipment_action_state
	if widgets.hub_item_action_button != null:
		widgets.hub_item_action_button.visible = item_page and page != HubMenuStateScript.HUB_PAGE_EQUIPMENT and context.content_focus and not context.is_root
		widgets.hub_item_action_button.mouse_filter = Control.MOUSE_FILTER_STOP if widgets.hub_item_action_button.visible else Control.MOUSE_FILTER_IGNORE
	for mode_index in widgets.hub_shop_mode_buttons.size():
		var mode_button := widgets.hub_shop_mode_buttons[mode_index]
		mode_button.visible = page == HubMenuStateScript.HUB_PAGE_SHOP and widgets.hub_shop_menu == null
		mode_button.mouse_filter = Control.MOUSE_FILTER_STOP if mode_button.visible else Control.MOUSE_FILTER_IGNORE
		var mode_color := context.highlight_color if context.action_column == mode_index and not context.content_focus else Color8(100, 105, 120)
		widget_factory.set_archetype_button_state(mode_button, true, mode_color)
	if shop_cursor != null:
		shop_cursor.visible = page == HubMenuStateScript.HUB_PAGE_SHOP and context.shop_command_focus
		if shop_cursor.visible and not widgets.hub_shop_mode_buttons.is_empty():
			var selected_shop_button := widgets.hub_shop_mode_buttons[clampi(context.action_column, 0, widgets.hub_shop_mode_buttons.size() - 1)]
			cursor_animator.move_menu_cursor(shop_cursor, Vector2(selected_shop_button.position.x - CURSOR_LEFT_GAP, selected_shop_button.position.y + 3.0), false, tween_owner)
