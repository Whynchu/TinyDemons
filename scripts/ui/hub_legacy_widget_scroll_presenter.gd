extends RefCounted
class_name HubLegacyWidgetScrollPresenter

func position_item_rows(widgets: HubResponsiveLayoutPresenter, scroll: float, pitch: float) -> void:
	var fraction: float = scroll - floor(scroll)
	for index in widgets.hub_item_list_texts.size():
		widgets.hub_item_list_texts[index].position.y = 4.0 + index * pitch - fraction * pitch
		if index < widgets.hub_item_row_buttons.size():
			widgets.hub_item_row_buttons[index].position.y = index * pitch - fraction * pitch
		if index < widgets.hub_shop_price_texts.size():
			widgets.hub_shop_price_texts[index].position.y = 39.0 + index * pitch - fraction * pitch


func position_gear_choices(widgets: HubResponsiveLayoutPresenter, scroll: float, pitch: float) -> void:
	var fraction: float = scroll - floor(scroll)
	for index in widgets.hub_gear_choice_texts.size():
		widgets.hub_gear_choice_texts[index].position.y = 4.0 + index * pitch - fraction * pitch
		if index < widgets.hub_gear_choice_buttons.size():
			widgets.hub_gear_choice_buttons[index].position.y = index * pitch - fraction * pitch
