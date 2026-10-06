extends RefCounted
class_name HubScreenActions

## Named callbacks connected while the Hub and Pause scenes are assembled.
## Keeping these in a typed record prevents callers from depending on a long
## positional argument list.

var adjust_stat: Callable = Callable()
var apply_stats: Callable = Callable()
var cancel_stats: Callable = Callable()
var auto_allocate: Callable = Callable()
var respec: Callable = Callable()
var set_page: Callable = Callable()
var item_action: Callable = Callable()
var select_gear_slot: Callable = Callable()
var bind_element: Callable = Callable()
var select_gear_candidate: Callable = Callable()
var select_stat_row: Callable = Callable()
var select_item_row: Callable = Callable()
var adjust_fusion_count: Callable = Callable()

var pause_resume: Callable = Callable()
var pause_settings: Callable = Callable()
var pause_quit: Callable = Callable()
var pause_status: Callable = Callable()
var pause_equipment: Callable = Callable()
var pause_set_page: Callable = Callable()
var pause_back: Callable = Callable()
var pause_equipment_back: Callable = Callable()

var equipment_remove: Callable = Callable()
var equipment_remove_all: Callable = Callable()
var equipment_remove_all_cancel: Callable = Callable()
var hub_back: Callable = Callable()

var shop_mode: Callable = Callable()
var shop_amount: Callable = Callable()
var shop_amount_cancel: Callable = Callable()
var shop_back: Callable = Callable()


static func from_gameplay_root(root: Node) -> HubScreenActions:
	var actions := HubScreenActions.new() as HubScreenActions
	actions.adjust_stat = Callable(root, "_hub_adjust_stat")
	actions.apply_stats = Callable(root, "_hub_confirm_stats")
	actions.cancel_stats = Callable(root, "_hub_cancel_stats")
	actions.auto_allocate = Callable(root, "_hub_auto_allocate")
	actions.respec = Callable(root, "_hub_respec")
	actions.set_page = Callable(root, "_set_hub_page")
	actions.item_action = Callable(root, "_hub_item_action")
	actions.select_gear_slot = Callable(root, "_select_hub_gear_slot")
	actions.bind_element = Callable(root, "_hub_bind_current_element")
	actions.select_gear_candidate = Callable(root, "_select_hub_gear_candidate")
	actions.select_stat_row = Callable(root, "_select_hub_stat_row")
	actions.select_item_row = Callable(root, "_select_hub_item_row")
	actions.adjust_fusion_count = Callable(root, "_shift_hub_fusion_count")
	actions.pause_resume = Callable(root, "_close_hub_to_run")
	actions.pause_settings = Callable(root, "_open_settings_from_pause")
	actions.pause_quit = Callable(root, "_quit_to_title_from_pause")
	actions.pause_status = Callable(root, "_set_pause_status_page")
	actions.pause_equipment = Callable(root, "_set_pause_equipment_page")
	actions.pause_back = Callable(root, "_pause_back")
	actions.equipment_remove = Callable(root, "_remove_hub_gear")
	actions.equipment_remove_all = Callable(root, "_remove_all_hub_gear")
	actions.equipment_remove_all_cancel = Callable(root, "_cancel_hub_remove_all")
	actions.hub_back = Callable(root, "_hub_back_or_close")
	actions.pause_equipment_back = Callable(root, "_pause_equipment_back")
	actions.shop_mode = Callable(root, "_shop_mode_pressed")
	actions.shop_amount = Callable(root, "_shop_amount_changed")
	actions.shop_amount_cancel = Callable(root, "_shop_amount_cancelled")
	actions.shop_back = Callable(root, "_shop_back_pressed")
	return actions
