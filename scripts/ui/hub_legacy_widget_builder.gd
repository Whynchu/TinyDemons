extends RefCounted
class_name HubLegacyWidgetBuilder

## Builds the compatibility widgets used by Hub inventory and equipment routes.
## The responsive layout presenter remains their typed reference owner.
const HubResponsiveLayoutPresenterScript = preload("res://scripts/ui/hub_responsive_layout_presenter.gd")


func build_item_and_equipment_widgets(
	items_page: Control,
	pixel_texture: Callable,
	actions: HubScreenActions,
	widgets: HubResponsiveLayoutPresenter,
	widget_factory: MenuWidgetFactory,
	view_size: Vector2,
	cursor_texture: Texture2D,
	select_shop_mode: Callable
) -> void:
	widgets.hub_item_name_text = widget_factory.create_sprite(items_page, "HubItemName", null, Vector2(14, 25), false)
	widgets.hub_item_list_panel = widget_factory.make_menu_card(items_page, "HubItemListPanel", Vector2(14, 35), Vector2(150, 66))
	widgets.hub_item_content_clip = Control.new()
	widgets.hub_item_content_clip.name = "HubItemContentClip"
	widgets.hub_item_content_clip.position = Vector2(14, 35)
	widgets.hub_item_content_clip.size = Vector2(150, 66)
	widgets.hub_item_content_clip.clip_contents = true
	widgets.hub_item_content_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_page.add_child(widgets.hub_item_content_clip)
	widgets.hub_item_list_texts.clear()
	for row in HubResponsiveLayoutPresenterScript.LEGACY_ITEM_VISIBLE_ROWS:
		widgets.hub_item_list_texts.append(widget_factory.create_sprite(widgets.hub_item_content_clip, "HubItemList%d" % row, null, Vector2(6, 4 + row * 10), false))
	widgets.hub_item_row_buttons.clear()
	for row in HubResponsiveLayoutPresenterScript.LEGACY_ITEM_VISIBLE_ROWS:
		widgets.hub_item_row_buttons.append(widget_factory.make_transparent_touch_button(widgets.hub_item_content_clip, "HubItemRow%d" % row, Vector2(0, row * 10), Vector2(150, 10), actions.select_item_row, row))
	widgets.hub_shop_price_texts.clear()
	for row in HubResponsiveLayoutPresenterScript.LEGACY_ITEM_VISIBLE_ROWS:
		widgets.hub_shop_price_texts.append(widget_factory.create_sprite(items_page, "HubShopPrice%d" % row, null, Vector2(174, 39 + row * 10), false))
	widgets.hub_gear_slot_buttons.clear()
	for slot in ItemCatalog.SLOTS.size():
		widgets.hub_gear_slot_buttons.append(widget_factory.make_transparent_touch_button(widgets.hub_item_content_clip, "HubGearSlot%d" % slot, Vector2(0, slot * 12), Vector2(150, 12), actions.select_gear_slot, slot))

	# Keep equipped slots and the temporary candidate picker in separate clips.
	widgets.hub_gear_choice_panel = widget_factory.make_menu_card(items_page, "HubGearChoicePanel", Vector2(14, 91), Vector2(150, 42))
	widgets.hub_gear_choice_panel.visible = false
	widgets.hub_gear_choice_content_clip = Control.new()
	widgets.hub_gear_choice_content_clip.name = "HubGearChoiceContentClip"
	widgets.hub_gear_choice_content_clip.position = Vector2(14, 91)
	widgets.hub_gear_choice_content_clip.size = Vector2(150, 42)
	widgets.hub_gear_choice_content_clip.clip_contents = true
	widgets.hub_gear_choice_content_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widgets.hub_gear_choice_content_clip.visible = false
	items_page.add_child(widgets.hub_gear_choice_content_clip)
	widgets.hub_gear_choice_texts.clear()
	widgets.hub_gear_choice_buttons.clear()
	for choice in HubResponsiveLayoutPresenterScript.LEGACY_GEAR_CHOICE_VISIBLE_ROWS:
		widgets.hub_gear_choice_texts.append(widget_factory.create_sprite(widgets.hub_gear_choice_content_clip, "HubGearChoice%d" % choice, null, Vector2(6, 4 + choice * 10), false))
		widgets.hub_gear_choice_buttons.append(widget_factory.make_transparent_touch_button(widgets.hub_gear_choice_content_clip, "HubGearChoiceButton%d" % choice, Vector2(0, choice * 10), Vector2(150, 10), actions.select_gear_candidate, choice))
	widgets.hub_gear_stat_panel = Panel.new()
	widgets.hub_gear_stat_panel.name = "HubGearStatPanel"
	widgets.hub_gear_stat_panel.position = Vector2(174, 35)
	widgets.hub_gear_stat_panel.size = Vector2(maxf(view_size.x - 188.0, 48.0), 66)
	widgets.hub_gear_stat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widgets.hub_gear_stat_panel.add_theme_stylebox_override("panel", widget_factory.menu_card_style())
	items_page.add_child(widgets.hub_gear_stat_panel)
	widgets.hub_gear_stat_texts.clear()
	for stat in 6:
		widgets.hub_gear_stat_texts.append(widget_factory.create_sprite(items_page, "HubGearStat%d" % stat, null, Vector2(180, 41 + stat * 9), false))

	widgets.hub_item_detail_panel = widget_factory.make_menu_card(
		items_page,
		"HubItemDetailPanel",
		Vector2(14, HubResponsiveLayoutPresenterScript.HUB_ITEM_DETAIL_PANEL_TOP),
		Vector2(maxf(view_size.x - 28.0, 80.0), HubResponsiveLayoutPresenterScript.HUB_ITEM_DETAIL_PANEL_HEIGHT)
	)
	widgets.hub_item_detail_panel.visible = false
	widgets.hub_item_detail_texts.clear()
	for detail in 6:
		widgets.hub_item_detail_texts.append(widget_factory.create_sprite(
			items_page,
			"HubItemDetail%d" % detail,
			null,
			Vector2(20, HubResponsiveLayoutPresenterScript.HUB_ITEM_DETAIL_TOP + detail * HubResponsiveLayoutPresenterScript.HUB_ITEM_DETAIL_PITCH),
			false
		))
	widgets.hub_item_action_button = widget_factory.make_retro_button("BUY", Vector2(maxf(96.0, view_size.x - 70.0), 119), Vector2(52, 13), pixel_texture)
	widgets.hub_item_action_button.focus_mode = Control.FOCUS_NONE
	widgets.hub_item_action_button.pressed.connect(actions.item_action)
	items_page.add_child(widgets.hub_item_action_button)
	widgets.hub_shop_mode_buttons.clear()
	for mode in 2:
		var mode_button := widget_factory.make_retro_button("BUY" if mode == 0 else "SELL", Vector2(132 + mode * 42, 21), Vector2(36, 13), pixel_texture)
		mode_button.focus_mode = Control.FOCUS_NONE
		mode_button.pressed.connect(select_shop_mode.bind(mode))
		items_page.add_child(mode_button)
		widgets.hub_shop_mode_buttons.append(mode_button)

	widgets.hub_equipment_action_buttons.clear()
	var equip_action := widget_factory.make_retro_button("EQUIP", Vector2(14, 22), Vector2(42, 12), pixel_texture)
	equip_action.name = "HubEquipmentEquip"
	equip_action.focus_mode = Control.FOCUS_NONE
	equip_action.pressed.connect(actions.item_action)
	items_page.add_child(equip_action)
	widgets.hub_equipment_action_buttons.append(equip_action)
	var remove_action := widget_factory.make_retro_button("REMOVE", Vector2(64, 22), Vector2(50, 12), pixel_texture)
	remove_action.name = "HubEquipmentRemove"
	remove_action.focus_mode = Control.FOCUS_NONE
	if actions.equipment_remove.is_valid():
		remove_action.pressed.connect(actions.equipment_remove)
	items_page.add_child(remove_action)
	widgets.hub_equipment_action_buttons.append(remove_action)
	var remove_all_action := widget_factory.make_retro_button("REMOVE ALL", Vector2(122, 22), Vector2(62, 12), pixel_texture)
	remove_all_action.name = "HubEquipmentRemoveAll"
	remove_all_action.focus_mode = Control.FOCUS_NONE
	if actions.equipment_remove_all.is_valid():
		remove_all_action.pressed.connect(actions.equipment_remove_all)
	items_page.add_child(remove_all_action)
	widgets.hub_equipment_action_buttons.append(remove_all_action)

	widgets.hub_fusion_decrease_button = widget_factory.make_retro_button("<", Vector2(14, 119), Vector2(22, 13), pixel_texture)
	widgets.hub_fusion_decrease_button.name = "HubFusionDecrease"
	widgets.hub_fusion_decrease_button.focus_mode = Control.FOCUS_NONE
	if actions.adjust_fusion_count.is_valid():
		widgets.hub_fusion_decrease_button.pressed.connect(actions.adjust_fusion_count.bind(-1))
	items_page.add_child(widgets.hub_fusion_decrease_button)
	widgets.hub_fusion_increase_button = widget_factory.make_retro_button(">", Vector2(39, 119), Vector2(22, 13), pixel_texture)
	widgets.hub_fusion_increase_button.name = "HubFusionIncrease"
	widgets.hub_fusion_increase_button.focus_mode = Control.FOCUS_NONE
	if actions.adjust_fusion_count.is_valid():
		widgets.hub_fusion_increase_button.pressed.connect(actions.adjust_fusion_count.bind(1))
	items_page.add_child(widgets.hub_fusion_increase_button)

	widgets.hub_list_cursor = widget_factory.create_sprite(items_page, "HubListCursor", cursor_texture, Vector2.ZERO, false)
	widgets.hub_list_cursor.visible = false
	widgets.hub_shop_cursor = widget_factory.create_sprite(items_page, "HubShopCursor", cursor_texture, Vector2.ZERO, false)
	widgets.hub_shop_cursor.visible = false
	widgets.hub_slot_cursor = widget_factory.create_sprite(items_page, "HubSlotCursor", cursor_texture, Vector2.ZERO, false)
	widgets.hub_slot_cursor.visible = false
	widgets.hub_choice_cursor = widget_factory.create_sprite(items_page, "HubChoiceCursor", cursor_texture, Vector2.ZERO, false)
	widgets.hub_choice_cursor.visible = false


func build_bind_widgets(
	bind_page: Control,
	pixel_texture: Callable,
	actions: HubScreenActions,
	widgets: HubResponsiveLayoutPresenter,
	widget_factory: MenuWidgetFactory,
	view_size: Vector2
) -> void:
	widgets.hub_binding_panel = Panel.new()
	widgets.hub_binding_panel.name = "HubBindingPanel"
	widgets.hub_binding_panel.position = Vector2(14, 33)
	widgets.hub_binding_panel.size = Vector2(maxf(view_size.x - 28.0, 80.0), 72)
	widgets.hub_binding_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	widgets.hub_binding_panel.add_theme_stylebox_override("panel", widget_factory.menu_card_style())
	bind_page.add_child(widgets.hub_binding_panel)
	widgets.hub_binding_texts.clear()
	var entries: Array[String] = ["Current", "Bound", "Souls", "Cost", "Message"]
	var positions: Array[Vector2] = [Vector2(22, 41), Vector2(22, 53), Vector2(22, 65), Vector2(22, 77), Vector2(22, 91)]
	for index in entries.size():
		widgets.hub_binding_texts.append(widget_factory.create_sprite(bind_page, "HubBinding%s" % entries[index], null, positions[index], false))
	widgets.hub_binding_action_button = widget_factory.make_retro_button("BIND", Vector2(view_size.x - 78.0, 119), Vector2(64, 13), pixel_texture)
	widgets.hub_binding_action_button.focus_mode = Control.FOCUS_NONE
	if actions.bind_element.is_valid():
		widgets.hub_binding_action_button.pressed.connect(actions.bind_element)
	bind_page.add_child(widgets.hub_binding_action_button)
