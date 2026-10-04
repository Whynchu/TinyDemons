extends RefCounted
class_name HubMenuState

const EquipmentMenuLayoutScript = preload("res://scripts/ui/equipment_menu_layout.gd")
const ShopMenuLayoutScript = preload("res://scripts/ui/shop_menu_layout.gd")

const HUB_PAGE_COUNT := HUB_PAGE_STATUS + 1
const HUB_PAGE_ALLOCATE := 0
const HUB_PAGE_STATS := HUB_PAGE_ALLOCATE
const HUB_PAGE_EQUIPMENT := 1
const HUB_PAGE_SHOP := 2
const HUB_PAGE_FUSION := 3
const HUB_PAGE_BIND := 4
const HUB_PAGE_STATUS := 5
const HUB_COMMAND_PAGE_TARGETS := [HUB_PAGE_STATS, HUB_PAGE_SHOP, HUB_PAGE_FUSION, HUB_PAGE_BIND]

const EQUIPMENT_MODE_COMMAND := EquipmentMenuLayoutScript.MODE_COMMAND
const EQUIPMENT_MODE_SLOT_EQUIP := EquipmentMenuLayoutScript.MODE_SLOT_EQUIP
const EQUIPMENT_MODE_SLOT_REMOVE := EquipmentMenuLayoutScript.MODE_SLOT_REMOVE
const EQUIPMENT_MODE_CANDIDATE := EquipmentMenuLayoutScript.MODE_CANDIDATE
const EQUIPMENT_MODE_REMOVE_ALL_CONFIRM := EquipmentMenuLayoutScript.MODE_REMOVE_ALL_CONFIRM

const SHOP_STATE_MODE_SELECT := ShopMenuLayoutScript.MODE_SELECT
const SHOP_STATE_ITEM_BROWSE := ShopMenuLayoutScript.ITEM_BROWSE
const SHOP_STATE_SELL_AMOUNT := ShopMenuLayoutScript.SELL_AMOUNT

## Mutable route and interaction state shared by Hub flow, economy, and input.
## ScreenStateController keeps typed forwarding properties for compatibility.
var hub_opened_from_npc := false
var hub_pause_mode := false
var hub_is_root := true
var hub_menu_row := 0
var hub_stat_row := 0
var hub_action_column := 0
var hub_content_focus := false
var hub_equipment_action_focus := false
var hub_interact_input_was_down := false
var hub_cancel_input_was_down := false
var hub_page_previous_input_was_down := false
var hub_page_next_input_was_down := false
var hub_page := HUB_PAGE_ALLOCATE
var hub_item_index := 0
var hub_list_scroll := 0.0
var hub_shop_sell_mode := false
var hub_shop_sell_confirm_pending := false
var hub_shop_command_focus := false
var hub_shop_state := SHOP_STATE_MODE_SELECT
var hub_shop_sell_amount := 1
var hub_shop_sell_amount_max := 1
var hub_choice_scroll := 0.0
var hub_gear_candidate_indices: Dictionary = {"weapon": 0, "head": 0, "body": 0, "arm": 0, "shield": 0, "accessory": 0}
var hub_touch_candidate_slot := ""
var hub_touch_candidate_index := -1
var hub_gear_browsing := false
var hub_fusion_count := 1
var hub_fusion_message := ""
var hub_binding_message := ""
var hub_fusion_state := 0
var hub_fusion_item_selected := false
var hub_binding_state := 0
var hub_equipment_mode := 0
var hub_remove_all_confirm_index := 0

## Shared state transitions used by hub routing and hub economy controllers.
## Keep optional-property handling here so lightweight menu test doubles can
## continue to participate without duplicating compatibility checks.


static func set_equipment_mode(screen: Object, mode: int) -> void:
	set_property_if_available(screen, &"hub_equipment_mode", mode)
	set_property_if_available(screen, &"hub_equipment_action_focus", mode == EquipmentMenuLayoutScript.MODE_COMMAND)
	set_property_if_available(screen, &"hub_gear_browsing", mode == EquipmentMenuLayoutScript.MODE_CANDIDATE)
	var confirm_index := int(get_property_if_available(screen, &"hub_remove_all_confirm_index", 0))
	set_property_if_available(screen, &"hub_remove_all_confirm_index", clampi(confirm_index, 0, 1))


static func clear_touch_candidate(screen: Object) -> void:
	set_property_if_available(screen, &"hub_touch_candidate_slot", "")
	set_property_if_available(screen, &"hub_touch_candidate_index", -1)


static func set_property_if_available(screen: Object, property_name: StringName, value: Variant) -> void:
	for property: Dictionary in screen.get_property_list():
		if StringName(str(property.get("name", ""))) == property_name:
			screen.set(property_name, value)
			return


static func get_property_if_available(screen: Object, property_name: StringName, default_value: Variant = null) -> Variant:
	for property: Dictionary in screen.get_property_list():
		if StringName(str(property.get("name", ""))) == property_name:
			return screen.get(property_name)
	return default_value
