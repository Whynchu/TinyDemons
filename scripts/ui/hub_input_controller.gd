extends RefCounted
class_name HubInputController

## Routes Hub input using typed menu state and the screen's focused presentation owners.
const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")
const EquipmentMenuLayoutScript = preload("res://scripts/ui/equipment_menu_layout.gd")
const ShopMenuLayoutScript = preload("res://scripts/ui/shop_menu_layout.gd")
const HubLegacyWidgetActionPresenterScript = preload("res://scripts/ui/hub_legacy_widget_action_presenter.gd")

var stats: HubStatsScreenPresenter
var widgets: HubResponsiveLayoutPresenter
var _legacy_widget_action_presenter: HubLegacyWidgetActionPresenterScript = HubLegacyWidgetActionPresenterScript.new() as HubLegacyWidgetActionPresenterScript


func bind(stats_presenter: HubStatsScreenPresenter, responsive_layout: HubResponsiveLayoutPresenter) -> void:
	stats = stats_presenter
	widgets = responsive_layout

func update(root: GameplayState, state: HubMenuState, refresh_hub_ui: Callable, scroll_content: Callable) -> void:
	var page := state.hub_page
	var touch_scroll := root._input_touch_scroll_y() as float
	if not is_zero_approx(touch_scroll) and not (page == HubMenuStateScript.HUB_PAGE_SHOP and state.hub_shop_state == ShopMenuLayoutScript.SELL_AMOUNT):
		scroll_content.call(root, touch_scroll)
		refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
	if bool(root._is_menu_back_just_pressed()):
		_handle_back_input(root, state, page, refresh_hub_ui)
		return
	if _handle_command_rail_input(root, state, page):
		return
	state.hub_content_focus = true
	if _handle_status_input(root, page):
		return
	if _handle_binding_input(root, state, page, refresh_hub_ui):
		return
	if _handle_fusion_input(root, state, page, refresh_hub_ui):
		return
	if _handle_allocation_input(root, state, page, refresh_hub_ui):
		return
	if _handle_equipment_input(root, state, page):
		return
	if _handle_shop_input(root, state, page, refresh_hub_ui):
		return
	_handle_inventory_input(root, state, page)


# --- Shared navigation routes ---
func _handle_back_input(root: GameplayState, state: HubMenuState, page: int, refresh_hub_ui: Callable) -> void:
	if page == HubMenuStateScript.HUB_PAGE_SHOP:
		root._shop_back_pressed()
		return
	if page == HubMenuStateScript.HUB_PAGE_FUSION:
		if state.hub_fusion_state == 2:
			state.hub_fusion_state = 1
			state.hub_fusion_item_selected = false
			refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
			root._play_sound("ui_decline", 0.0, 1.0)
		else:
			root._hub_back_or_close()
		return
	if page == HubMenuStateScript.HUB_PAGE_BIND and state.hub_binding_state == 1:
		state.hub_binding_state = 0
		state.hub_is_root = true
		state.hub_content_focus = false
		refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
		root._play_sound("ui_decline", 0.0, 1.0)
		return
	if page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and state.hub_equipment_mode == EquipmentMenuLayoutScript.MODE_REMOVE_ALL_CONFIRM:
		root._cancel_hub_remove_all()
	elif page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and state.hub_gear_browsing:
		# Item picker -> slot list.
		root._close_hub_gear_browse()
	elif page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and not state.hub_equipment_action_focus:
		# Slot list -> Equipment command row.
		state.hub_equipment_action_focus = true
		state.hub_equipment_mode = EquipmentMenuLayoutScript.MODE_COMMAND
		state.hub_gear_browsing = false
		state.hub_content_focus = true
		refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
		root._play_sound("ui_decline", 0.0, 1.0)
	else:
		# Command row -> Demon Hub root (or the normal back route for other pages).
		root._hub_back_or_close()


func _handle_command_rail_input(root: GameplayState, state: HubMenuState, page: int) -> bool:
	# The top command rail is horizontal: Left/Right changes commands and Confirm
	# enters the selected command.
	if not state.hub_is_root and (state.hub_content_focus or page != HubMenuStateScript.HUB_PAGE_ALLOCATE):
		return false
	if bool(root._is_menu_direction_just_pressed(&"ui_left")):
		root._select_hub_menu_row(state.hub_menu_row - 1)
		root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_right")):
		root._select_hub_menu_row(state.hub_menu_row + 1)
		root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_confirm_just_pressed()):
		if state.hub_menu_row >= 0 and state.hub_menu_row < HubMenuStateScript.HUB_COMMAND_PAGE_TARGETS.size():
			root._set_hub_page(HubMenuStateScript.HUB_COMMAND_PAGE_TARGETS[state.hub_menu_row])
		else:
			root._play_sound("ui_no_input", 0.0, 1.0)
	return true


# --- Page routes ---
func _handle_status_input(root: GameplayState, page: int) -> bool:
	if page != HubMenuStateScript.HUB_PAGE_STATUS:
		return false
	if bool(root._is_menu_confirm_just_pressed()):
		root._play_sound("ui_no_input", 0.0, 1.0)
	return true


func _handle_binding_input(root: GameplayState, state: HubMenuState, page: int, refresh_hub_ui: Callable) -> bool:
	if page != HubMenuStateScript.HUB_PAGE_BIND:
		return false
	if bool(root._is_menu_confirm_just_pressed()):
		if state.hub_binding_state == 0:
			state.hub_binding_state = 1
			state.hub_content_focus = true
			refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
			root._play_sound("ui_confirm", 0.0, 1.0)
			return true
		var binding_action := widgets.hub_binding_action_button
		if binding_action != null and not binding_action.disabled:
			binding_action.pressed.emit()
		else:
			root._play_sound("ui_no_input", 0.0, 1.0)
	return true


func _handle_fusion_input(root: GameplayState, state: HubMenuState, page: int, refresh_hub_ui: Callable) -> bool:
	if page != HubMenuStateScript.HUB_PAGE_FUSION:
		return false
	if state.hub_fusion_state == 1:
		if bool(root._is_menu_direction_just_pressed(&"ui_up")):
			root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
			root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()):
			var fusion_candidates := root._hub_fusion_candidates() as Array
			if fusion_candidates.is_empty():
				root._play_sound("ui_no_input", 0.0, 1.0)
				return true
			# Route through the transaction owner so the selected item identity and
			# amount-state transition stay in one place for controller and touch.
			root._hub_item_action()
		return true
	if state.hub_fusion_state == 2:
		if bool(root._is_menu_direction_just_pressed(&"ui_left")):
			var previous_count := state.hub_fusion_count
			root._shift_hub_fusion_count(-1)
			root._play_sound("ui_hover" if state.hub_fusion_count != previous_count else "ui_no_input", -6.0 if state.hub_fusion_count != previous_count else 0.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")):
			var previous_count := state.hub_fusion_count
			root._shift_hub_fusion_count(1)
			root._play_sound("ui_hover" if state.hub_fusion_count != previous_count else "ui_no_input", -6.0 if state.hub_fusion_count != previous_count else 0.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()):
			root._hub_item_action()
		return true
	return false


func _handle_allocation_input(root: GameplayState, state: HubMenuState, page: int, refresh_hub_ui: Callable) -> bool:
	if page != HubMenuStateScript.HUB_PAGE_ALLOCATE:
		return false
	if state.hub_stat_row == 6:
		if bool(root._is_menu_direction_just_pressed(&"ui_up")):
			state.hub_stat_row = 5
			refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
			root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
			root._play_sound("ui_no_input", 0.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_left")) or bool(root._is_menu_direction_just_pressed(&"ui_right")):
			var utility_direction := -1 if bool(root._is_menu_direction_just_pressed(&"ui_left")) else 1
			root._shift_hub_action_column(utility_direction); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()):
			_activate_allocation_utility(root, state.hub_action_column)
		return true
	if bool(root._is_menu_direction_just_pressed(&"ui_up")):
		var previous_row := state.hub_stat_row
		state.hub_stat_row = maxi(state.hub_stat_row - 1, 0)
		refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
		root._play_sound("ui_hover" if state.hub_stat_row != previous_row else "ui_no_input", -6.0 if state.hub_stat_row != previous_row else 0.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
		var previous_row := state.hub_stat_row
		state.hub_stat_row = mini(state.hub_stat_row + 1, 6)
		refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
		root._play_sound("ui_hover" if state.hub_stat_row != previous_row else "ui_no_input", -6.0 if state.hub_stat_row != previous_row else 0.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_left")) or bool(root._is_menu_direction_just_pressed(&"ui_right")):
		var direction := -1 if bool(root._is_menu_direction_just_pressed(&"ui_left")) else 1
		root._hub_adjust_stat([&"VIT", &"STR", &"DEF", &"AGI", &"INT", &"MND"][state.hub_stat_row], direction)
		root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_confirm_just_pressed()):
		_activate_allocation_utility(root, state.hub_action_column)
	return true


func _activate_allocation_utility(root: GameplayState, action_column: int) -> void:
	if action_column < 4:
		var utility_buttons: Array[Button] = [stats.apply_button, stats.cancel_button, stats.auto_button, stats.respec_button]
		var utility_button := utility_buttons[action_column]
		if utility_button != null and not utility_button.disabled:
			utility_button.pressed.emit()
		else:
			root._play_sound("ui_no_input", 0.0, 1.0)
	else:
		root._play_sound("ui_no_input", 0.0, 1.0)


func _handle_equipment_input(root: GameplayState, state: HubMenuState, page: int) -> bool:
	if page != HubMenuStateScript.HUB_PAGE_EQUIPMENT:
		return false
	if state.hub_equipment_mode == EquipmentMenuLayoutScript.MODE_REMOVE_ALL_CONFIRM:
		# The locked cursor is the modal affordance; Confirm accepts it.
		if bool(root._is_menu_confirm_just_pressed()):
			root._remove_all_hub_gear()
		return true
	if state.hub_gear_browsing:
		if bool(root._is_menu_direction_just_pressed(&"ui_up")): root._shift_hub_gear_candidate_grid(0, -1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")): root._shift_hub_gear_candidate_grid(0, 1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_gear_candidate_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_gear_candidate_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()): root._hub_item_action()
		return true
	if state.hub_equipment_action_focus:
		if bool(root._is_menu_direction_just_pressed(&"ui_left")) or bool(root._is_menu_direction_just_pressed(&"ui_right")):
			var action_direction := -1 if bool(root._is_menu_direction_just_pressed(&"ui_left")) else 1
			root._shift_hub_action_column(action_direction); root._play_sound("ui_hover", -6.0, 1.0)
		# Down must never silently change menu depth or open Remove All.
		elif bool(root._is_menu_confirm_just_pressed()):
			if not _legacy_widget_action_presenter.trigger_equipment_action(widgets, state.hub_action_column):
				root._play_sound("ui_no_input", 0.0, 1.0)
		return true
	if state.hub_equipment_mode == EquipmentMenuLayoutScript.MODE_SLOT_REMOVE:
		if bool(root._is_menu_direction_just_pressed(&"ui_up")): root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")): root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_slot_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_slot_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()): root._remove_hub_gear()
		return true
	if bool(root._is_menu_direction_just_pressed(&"ui_up")):
		root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
		root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_slot_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_slot_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_confirm_just_pressed()):
		# Slot confirm descends to the candidate menu.
		root._select_hub_gear_slot(state.hub_item_index)
	return true


func _handle_shop_input(root: GameplayState, state: HubMenuState, page: int, refresh_hub_ui: Callable) -> bool:
	if page != HubMenuStateScript.HUB_PAGE_SHOP:
		return false
	if state.hub_shop_state == ShopMenuLayoutScript.MODE_SELECT:
		if bool(root._is_menu_direction_just_pressed(&"ui_left")):
			state.hub_action_column = 0
			state.hub_shop_sell_mode = false
			refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
			root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")):
			state.hub_action_column = 1
			state.hub_shop_sell_mode = true
			refresh_hub_ui.call(root, Callable(root, "_pixel_text_texture"))
			root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()):
			root._shop_mode_pressed(state.hub_action_column)
		return true
	if state.hub_shop_state == ShopMenuLayoutScript.SELL_AMOUNT:
		if bool(root._is_menu_direction_just_pressed(&"ui_left")):
			root._shop_amount_changed(-1)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")):
			root._shop_amount_changed(1)
		elif bool(root._is_menu_confirm_just_pressed()):
			root._hub_item_action()
		return true
	if state.hub_shop_state == ShopMenuLayoutScript.ITEM_BROWSE:
		# The authored ShopMenu confirm always reaches its transaction owner.
		if bool(root._is_menu_direction_just_pressed(&"ui_up")):
			root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
			root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()):
			root._hub_item_action()
		return true
	return false


func _handle_inventory_input(root: GameplayState, state: HubMenuState, page: int) -> void:
	if bool(root._is_menu_direction_just_pressed(&"ui_up")):
		root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
		root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
	elif page == HubMenuStateScript.HUB_PAGE_FUSION and bool(root._is_menu_direction_just_pressed(&"ui_left")):
		root._shift_hub_fusion_count(-1); root._play_sound("ui_hover", -6.0, 1.0)
	elif page == HubMenuStateScript.HUB_PAGE_FUSION and bool(root._is_menu_direction_just_pressed(&"ui_right")):
		root._shift_hub_fusion_count(1); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_confirm_just_pressed()):
		if not _legacy_widget_action_presenter.trigger_item_action(widgets):
			root._play_sound("ui_no_input", 0.0, 1.0)
