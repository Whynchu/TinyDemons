extends RefCounted
class_name HubLegacyWidgetVisibilityPresenter

func hide_equipment_legacy(widgets: HubResponsiveLayoutPresenter) -> void:
	var legacy_nodes: Array[CanvasItem] = [
		widgets.hub_item_name_text,
		widgets.hub_item_list_panel,
		widgets.hub_item_content_clip,
		widgets.hub_gear_choice_panel,
		widgets.hub_gear_choice_content_clip,
		widgets.hub_gear_stat_panel,
		widgets.hub_item_detail_panel,
		widgets.hub_item_action_button,
	]
	legacy_nodes.append_array(widgets.hub_item_list_texts)
	legacy_nodes.append_array(widgets.hub_item_row_buttons)
	legacy_nodes.append_array(widgets.hub_shop_price_texts)
	legacy_nodes.append_array(widgets.hub_gear_slot_buttons)
	legacy_nodes.append_array(widgets.hub_gear_choice_texts)
	legacy_nodes.append_array(widgets.hub_gear_choice_buttons)
	legacy_nodes.append_array(widgets.hub_gear_stat_texts)
	legacy_nodes.append_array(widgets.hub_item_detail_texts)
	legacy_nodes.append_array(widgets.hub_equipment_action_buttons)
	_hide_nodes(legacy_nodes, false)
	var equipment_buttons: Array[Button] = []
	equipment_buttons.append_array(widgets.hub_gear_slot_buttons)
	equipment_buttons.append_array(widgets.hub_gear_choice_buttons)
	equipment_buttons.append_array(widgets.hub_equipment_action_buttons)
	for button: Button in equipment_buttons:
		if button == null:
			continue
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE


func hide_shop_legacy(widgets: HubResponsiveLayoutPresenter) -> void:
	var legacy_nodes: Array[CanvasItem] = [
		widgets.hub_item_name_text,
		widgets.hub_item_list_panel,
		widgets.hub_item_content_clip,
		widgets.hub_gear_choice_panel,
		widgets.hub_gear_choice_content_clip,
		widgets.hub_gear_stat_panel,
		widgets.hub_item_detail_panel,
		widgets.hub_item_action_button,
		widgets.hub_fusion_decrease_button,
		widgets.hub_fusion_increase_button,
		widgets.hub_list_cursor,
		widgets.hub_slot_cursor,
		widgets.hub_choice_cursor,
		widgets.hub_shop_cursor,
	]
	legacy_nodes.append_array(widgets.hub_item_list_texts)
	legacy_nodes.append_array(widgets.hub_item_row_buttons)
	legacy_nodes.append_array(widgets.hub_shop_price_texts)
	legacy_nodes.append_array(widgets.hub_gear_slot_buttons)
	legacy_nodes.append_array(widgets.hub_gear_choice_texts)
	legacy_nodes.append_array(widgets.hub_gear_choice_buttons)
	legacy_nodes.append_array(widgets.hub_gear_stat_texts)
	legacy_nodes.append_array(widgets.hub_item_detail_texts)
	legacy_nodes.append_array(widgets.hub_equipment_action_buttons)
	legacy_nodes.append_array(widgets.hub_shop_mode_buttons)
	_hide_nodes(legacy_nodes, true)
	if widgets.hub_shop_cursor != null and widgets.hub_shop_cursor.has_method("stop_motion"):
		widgets.hub_shop_cursor.call("stop_motion")


func _hide_nodes(nodes: Array[CanvasItem], ignore_control_input: bool) -> void:
	for node: CanvasItem in nodes:
		if node == null:
			continue
		node.visible = false
		if ignore_control_input and node is Control:
			(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
