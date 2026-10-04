extends RefCounted
class_name HubMenuSignalBinder

func bind(
	equipment_menu: EquipmentMenuLayout,
	shop_menu: ShopMenuLayout,
	fusion_menu: FusionMenuLayout,
	bind_menu: BindMenuLayout,
	actions: HubScreenActions,
	set_action_column: Callable
) -> void:
	_bind_equipment(equipment_menu, actions, set_action_column)
	_bind_shop(shop_menu, actions)
	_bind_fusion(fusion_menu, actions)
	_bind_element_binding(bind_menu, actions)


func _bind_equipment(menu: EquipmentMenuLayout, actions: HubScreenActions, set_action_column: Callable) -> void:
	if menu == null:
		return
	menu.command_pressed.connect(func(index: int):
		set_action_column.call(index)
		if index == 0 and actions.item_action.is_valid():
			actions.item_action.call()
		elif index == 1 and actions.equipment_remove.is_valid():
			actions.equipment_remove.call()
		elif index == 2 and actions.equipment_remove_all.is_valid():
			actions.equipment_remove_all.call())
	if actions.select_gear_slot.is_valid():
		menu.slot_pressed.connect(actions.select_gear_slot)
	if actions.select_gear_candidate.is_valid():
		menu.candidate_pressed.connect(actions.select_gear_candidate)
	menu.remove_all_confirmed.connect(func(accepted: bool):
		if accepted and actions.equipment_remove_all.is_valid():
			actions.equipment_remove_all.call()
		elif not accepted and actions.equipment_remove_all_cancel.is_valid():
			actions.equipment_remove_all_cancel.call())
	if actions.hub_back.is_valid():
		menu.navigation_back_pressed.connect(actions.hub_back)
	elif actions.pause_resume.is_valid():
		menu.navigation_back_pressed.connect(actions.pause_resume)


func _bind_shop(menu: ShopMenuLayout, actions: HubScreenActions) -> void:
	if menu == null:
		return
	if actions.shop_mode.is_valid():
		menu.mode_pressed.connect(actions.shop_mode)
	if actions.select_item_row.is_valid():
		menu.item_pressed.connect(actions.select_item_row)
	if actions.item_action.is_valid():
		menu.item_action_pressed.connect(actions.item_action)
		menu.sell_amount_confirmed.connect(actions.item_action)
	if actions.shop_amount.is_valid():
		menu.sell_amount_changed.connect(actions.shop_amount)
	if actions.shop_amount_cancel.is_valid():
		menu.sell_amount_cancelled.connect(actions.shop_amount_cancel)
	if actions.shop_back.is_valid():
		menu.shop_back_pressed.connect(actions.shop_back)


func _bind_fusion(menu: FusionMenuLayout, actions: HubScreenActions) -> void:
	if menu == null:
		return
	if actions.select_item_row.is_valid():
		menu.item_pressed.connect(actions.select_item_row)
	if actions.adjust_fusion_count.is_valid():
		menu.sell_amount_changed.connect(actions.adjust_fusion_count)
	if actions.item_action.is_valid():
		menu.item_action_pressed.connect(actions.item_action)
	if actions.hub_back.is_valid():
		menu.shop_back_pressed.connect(actions.hub_back)


func _bind_element_binding(menu: BindMenuLayout, actions: HubScreenActions) -> void:
	if menu == null:
		return
	if actions.bind_element.is_valid():
		menu.action_pressed.connect(actions.bind_element)
	if actions.hub_back.is_valid():
		menu.back_pressed.connect(actions.hub_back)
