extends RefCounted
class_name HubLegacyWidgetActionPresenter

func trigger_equipment_action(widgets: HubResponsiveLayoutPresenter, index: int) -> bool:
	if index < 0 or index >= widgets.hub_equipment_action_buttons.size():
		return false
	var button := widgets.hub_equipment_action_buttons[index]
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true


func trigger_item_action(widgets: HubResponsiveLayoutPresenter) -> bool:
	var button := widgets.hub_item_action_button
	if button == null or button.disabled:
		return false
	button.pressed.emit()
	return true
