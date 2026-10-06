extends RefCounted
class_name HubEconomyController

const ProgressionControllerScript = preload("res://scripts/runtime/controllers/progression_controller.gd")
const AspectCatalogScript = preload("res://scripts/content/aspect_catalog.gd")
const ShopMenuLayoutScript = preload("res://scripts/ui/shop_menu_layout.gd")
const FusionMenuLayoutScript = preload("res://scripts/ui/fusion_menu_layout.gd")
const EquipmentMenuLayoutScript = preload("res://scripts/ui/equipment_menu_layout.gd")
const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")
const HubResponsiveLayoutPresenterScript = preload("res://scripts/ui/hub_responsive_layout_presenter.gd")

const HUB_PAGE_COUNT := HubMenuStateScript.HUB_PAGE_COUNT
const HUB_PAGE_ALLOCATE := HubMenuStateScript.HUB_PAGE_ALLOCATE
const HUB_PAGE_STATS := HubMenuStateScript.HUB_PAGE_STATS
const HUB_PAGE_EQUIPMENT := HubMenuStateScript.HUB_PAGE_EQUIPMENT
const HUB_PAGE_SHOP := HubMenuStateScript.HUB_PAGE_SHOP
const HUB_PAGE_FUSION := HubMenuStateScript.HUB_PAGE_FUSION
const HUB_PAGE_BIND := HubMenuStateScript.HUB_PAGE_BIND
const HUB_PAGE_STATUS := HubMenuStateScript.HUB_PAGE_STATUS
const HUB_COMMAND_PAGE_TARGETS := HubMenuStateScript.HUB_COMMAND_PAGE_TARGETS

const EQUIPMENT_MODE_COMMAND := HubMenuStateScript.EQUIPMENT_MODE_COMMAND
const EQUIPMENT_MODE_SLOT_EQUIP := HubMenuStateScript.EQUIPMENT_MODE_SLOT_EQUIP
const EQUIPMENT_MODE_SLOT_REMOVE := HubMenuStateScript.EQUIPMENT_MODE_SLOT_REMOVE
const EQUIPMENT_MODE_CANDIDATE := HubMenuStateScript.EQUIPMENT_MODE_CANDIDATE
const EQUIPMENT_MODE_REMOVE_ALL_CONFIRM := HubMenuStateScript.EQUIPMENT_MODE_REMOVE_ALL_CONFIRM

const SHOP_STATE_MODE_SELECT := HubMenuStateScript.SHOP_STATE_MODE_SELECT
const SHOP_STATE_ITEM_BROWSE := HubMenuStateScript.SHOP_STATE_ITEM_BROWSE
const SHOP_STATE_SELL_AMOUNT := HubMenuStateScript.SHOP_STATE_SELL_AMOUNT

var _shop_cache_profile: PlayerProfile = null
var _shop_cache_signature := ""
var _shop_cache_items: Array[ItemInstance] = []
var _shop_cache_groups: Array[Dictionary] = []
var _shop_cache_group_by_key: Dictionary = {}
var _fusion_details_by_root: Dictionary = {}
var _fusion_profile_instance_by_root: Dictionary = {}
var _fusion_inventory_revision_by_root: Dictionary = {}
var _fusion_equipment_signature_by_root: Dictionary = {}


# Hub return routing and current-element binding.
func back_from_hub_route(root: Object) -> void:
	# The native footer BACK button must follow the same nested Equipment route
	# as controller/keyboard input. Previously it always jumped to the hub root,
	# which made touch navigation disagree with the visible menu hierarchy.
	var screen: Object = root.screen_state_controller
	if screen.hub_page == HUB_PAGE_FUSION and screen.hub_fusion_state == 2:
		screen.hub_fusion_state = 1
		screen.hub_fusion_item_selected = false
		screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
		root.call("_play_sound", "ui_decline", 0.0, 1.0)
		return
	if screen.hub_page == HUB_PAGE_EQUIPMENT:
		if screen.hub_equipment_mode == EQUIPMENT_MODE_REMOVE_ALL_CONFIRM:
			cancel_remove_all_hub_gear(root)
			return
		if screen.hub_gear_browsing:
			close_hub_gear_browse(root)
			return
		if not screen.hub_equipment_action_focus:
			HubMenuStateScript.set_equipment_mode(screen, EQUIPMENT_MODE_COMMAND)
			screen.hub_content_focus = true
			HubMenuStateScript.clear_touch_candidate(screen)
			screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
			root.call("_play_sound", "ui_decline", 0.0, 1.0)
			return
	root.call("_back_to_hub_root")


func hub_bind_current_element(root: Object) -> bool:
	if root.player_profile == null:
		return false
	var chroma := root.get("player_chroma_component") as Node
	var current_aspect := chroma.call("aspect_name") as StringName if chroma != null else &"gray"
	var current := AspectCatalogScript.display_name(current_aspect)
	var success := bool(root.call("_bind_current_element"))
	if success:
		root.screen_state_controller.hub_binding_message = "BOUND %s" % current
	else:
		root.screen_state_controller.hub_binding_message = "NEED 50 SOULS" if current_aspect != &"gray" and root.player_profile.souls < PlayerProfile.ELEMENT_BIND_SOUL_COST else "BIND UNAVAILABLE"
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	return success


# Shop inventory, sell values, and transaction modes.
func shop_sellable_items(root: Object) -> Array[ItemInstance]:
	var profile := root.player_profile as PlayerProfile
	if profile == null:
		return []
	_ensure_shop_cache(profile)
	return _shop_cache_items.duplicate()


func shop_items_match(left: ItemInstance, right: ItemInstance) -> bool:
	if left == null or right == null:
		return false
	return left.inventory_stack_key() == right.inventory_stack_key()


func shop_matching_count(items: Array[ItemInstance], target: ItemInstance) -> int:
	var count := 0
	for item: ItemInstance in items:
		if shop_items_match(item, target):
			count += 1
	return count


func shop_owned_matching_count(root: Object, target: ItemInstance) -> int:
	if root == null or root.player_profile == null or target == null:
		return 0
	_ensure_shop_cache(root.player_profile as PlayerProfile)
	var group: Dictionary = _shop_cache_group_by_key.get(target.inventory_stack_key(), {}) as Dictionary
	return (group.get("instance_ids", []) as Array).size()


func shop_batch_value(root: Object, target: ItemInstance, quantity: int) -> Dictionary:
	## A functional stack can contain different economic quality/history values.
	## Price the same concrete IDs that sell_profile_items() will consume so the
	## amount screen never promises a different payout from the transaction.
	if root == null or root.player_profile == null or target == null or quantity <= 0:
		return {"gold": 0, "souls": 0}
	var matching_ids := shop_matching_ids(root, target)
	var catalog := ItemCatalog.new()
	var total_gold := 0
	var total_souls := 0
	for index in range(mini(quantity, matching_ids.size())):
		var item: ItemInstance = root.player_profile.find_item(matching_ids[index])
		if item == null:
			continue
		total_gold += catalog.sell_value(item)
		total_souls += catalog.sell_soul_value(item)
	return {"gold": total_gold, "souls": total_souls}


func _ensure_shop_cache(profile: PlayerProfile) -> void:
	if profile == null:
		return
	var signature := "%d|%s" % [int(profile.inventory_revision), str(profile.equipped_instance_ids)]
	if _shop_cache_profile == profile and _shop_cache_signature == signature:
		return
	_shop_cache_profile = profile
	_shop_cache_signature = signature
	_shop_cache_items.clear()
	_shop_cache_groups.clear()
	_shop_cache_group_by_key.clear()
	var equipped_ids := profile.equipped_instance_ids.values()
	for data: Dictionary in profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		if equipped_ids.has(item.instance_id):
			continue
		var key: String = item.inventory_stack_key()
		if not _shop_cache_group_by_key.has(key):
			var new_group: Dictionary = {"key": key, "representative": item, "instance_ids": []}
			_shop_cache_group_by_key[key] = new_group
			_shop_cache_groups.append(new_group)
		var group: Dictionary = _shop_cache_group_by_key[key] as Dictionary
		(group["instance_ids"] as Array).append(item.instance_id)
	var catalog := ItemCatalog.new()
	_shop_cache_groups.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_item := left["representative"] as ItemInstance
		var right_item := right["representative"] as ItemInstance
		var left_value := catalog.sell_value(left_item)
		var right_value := catalog.sell_value(right_item)
		if left_value != right_value:
			return left_value < right_value
		if left_item.definition_id != right_item.definition_id:
			return String(left_item.definition_id) < String(right_item.definition_id)
		return left_item.inventory_stack_key() < right_item.inventory_stack_key()
	)
	for group_value: Dictionary in _shop_cache_groups:
		_shop_cache_items.append(group_value["representative"] as ItemInstance)


func shop_matching_ids(root: Object, target: ItemInstance) -> Array[String]:
	if root == null or root.player_profile == null or target == null:
		return []
	_ensure_shop_cache(root.player_profile as PlayerProfile)
	var group: Dictionary = _shop_cache_group_by_key.get(target.inventory_stack_key(), {}) as Dictionary
	var result: Array[String] = []
	for instance_id: Variant in group.get("instance_ids", []):
		result.append(str(instance_id))
	return result


## Shop mode transitions are kept in the hub flow owner so every input path
## reaches the same browse/sell transaction state.
func shop_mode_pressed(root: Object, mode_index: int) -> void:
	var screen: Object = root.screen_state_controller
	if screen.hub_page != HUB_PAGE_SHOP:
		return
	# Touch can enter BUY/SELL directly from the root preview. Controller flow
	# still reaches this function only after explicitly entering SHOP.
	screen.hub_is_root = false
	screen.hub_action_column = clampi(mode_index, 0, 1)
	screen.hub_shop_sell_mode = screen.hub_action_column == 1
	screen.hub_shop_state = SHOP_STATE_ITEM_BROWSE
	screen.hub_shop_sell_confirm_pending = false
	screen.hub_shop_sell_amount = 1
	screen.hub_shop_sell_amount_max = 1
	screen.hub_shop_sell_target_key = ""
	screen.hub_shop_command_focus = false
	screen.hub_content_focus = true
	screen.hub_item_index = 0
	screen.hub_list_scroll = 0.0
	screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)


func shop_amount_changed(root: Object, direction: int) -> void:
	var screen: Object = root.screen_state_controller
	if screen.hub_page != HUB_PAGE_SHOP or not screen.hub_shop_sell_mode or screen.hub_shop_state != SHOP_STATE_SELL_AMOUNT:
		return
	var sellable := shop_sellable_items(root)
	if sellable.is_empty():
		return
	var selected := sellable[clampi(screen.hub_item_index, 0, sellable.size() - 1)]
	var maximum := shop_owned_matching_count(root, selected)
	screen.hub_shop_sell_amount_max = maxi(maximum, 1)
	var next_amount := clampi(int(screen.hub_shop_sell_amount) + direction, 1, screen.hub_shop_sell_amount_max)
	if next_amount == screen.hub_shop_sell_amount:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	screen.hub_shop_sell_amount = next_amount
	screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_hover", -6.0, 1.0)


func shop_amount_cancelled(root: Object) -> void:
	var screen: Object = root.screen_state_controller
	if screen.hub_page != HUB_PAGE_SHOP or screen.hub_shop_state != SHOP_STATE_SELL_AMOUNT:
		return
	screen.hub_shop_state = SHOP_STATE_ITEM_BROWSE
	screen.hub_shop_sell_target_key = ""
	screen.hub_shop_sell_confirm_pending = false
	screen.hub_shop_sell_amount = 1
	screen.hub_shop_sell_amount_max = 1
	screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func shop_back_pressed(root: Object) -> void:
	var screen: Object = root.screen_state_controller
	if screen.hub_page != HUB_PAGE_SHOP:
		return
	if screen.hub_shop_state == SHOP_STATE_SELL_AMOUNT:
		shop_amount_cancelled(root)
		return
	if screen.hub_shop_state == SHOP_STATE_ITEM_BROWSE:
		screen.hub_shop_state = SHOP_STATE_MODE_SELECT
		screen.hub_shop_sell_target_key = ""
		screen.hub_shop_sell_confirm_pending = false
		screen.hub_shop_sell_amount = 1
		screen.hub_shop_sell_amount_max = 1
		screen.hub_shop_command_focus = true
		screen.hub_content_focus = false
		screen.hub_action_column = 1 if screen.hub_shop_sell_mode else 0
		screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
		root.call("_play_sound", "ui_decline", 0.0, 1.0)
		return
	root.call("_back_to_hub_root")


# Inventory and equipment browsing.
func shift_hub_item(root: Object, direction: int) -> void:
	var count: int = 0
	if root.screen_state_controller.hub_page == 1 or root.screen_state_controller.is_pause_equipment_active():
		count = ItemCatalog.SLOTS.size()
	elif root.screen_state_controller.hub_page == 2:
		if root.screen_state_controller.hub_shop_sell_mode:
			count = shop_sellable_items(root).size()
		else:
			count = root.run_state.shop_stock.size() if root.run_state != null else 0
	elif root.screen_state_controller.hub_page == 3:
		count = hub_fusion_candidates(root).size()
		root.screen_state_controller.hub_fusion_count = 1
		root.screen_state_controller.hub_fusion_message = ""
	var on_equipment_page: bool = root.screen_state_controller.hub_page == 1 or root.screen_state_controller.is_pause_equipment_active()
	if count > 0:
		var target := posmod(root.screen_state_controller.hub_item_index + direction, count)
		if on_equipment_page and root.player_profile != null and ItemCatalog.SLOTS[target] == &"head" and root.player_profile._head_locked_by_body(ItemCatalog.new()):
			target = posmod(target + (1 if direction >= 0 else -1), count)
		root.screen_state_controller.hub_item_index = target
		if root.screen_state_controller.hub_page == HUB_PAGE_FUSION:
			var fusion_items := hub_fusion_candidates(root)
			root.screen_state_controller.hub_fusion_target_instance_id = fusion_items[target].instance_id if target < fusion_items.size() else ""
		if root.screen_state_controller.hub_page == 1 or root.screen_state_controller.is_pause_equipment_active():
			HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.snap_hub_list_scroll_to_selection(root)
	root.screen_state_controller.refresh_equipment_menu(root)


func shift_hub_slot_grid(root: Object, column_direction: int, row_direction: int) -> void:
	if (root.screen_state_controller.hub_page != HUB_PAGE_EQUIPMENT and not root.screen_state_controller.is_pause_equipment_active()) or root.screen_state_controller.hub_gear_browsing:
		return
	var current := clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var column := 0 if current < 3 else 1
	var row := current % 3
	column = posmod(column + column_direction, 2)
	row = posmod(row + row_direction, 3)
	var target := column * 3 + row
	var catalog := ItemCatalog.new()
	if ItemCatalog.SLOTS[target] == &"head" and root.player_profile != null and root.player_profile._head_locked_by_body(catalog):
		# Head is intentionally greyed out while Demon Cloak occupies the shared
		# body/head identity. Continue in the requested direction to the next
		# usable panel instead of parking the active cursor on a disabled cell.
		row = posmod(row + (1 if row_direction >= 0 else -1), 3)
		target = column * 3 + row
	root.screen_state_controller.hub_item_index = target
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.refresh_equipment_menu(root)


func select_hub_item_row(root: Object, row: int) -> void:
	var page: int = int(root.screen_state_controller.hub_page)
	if page != 2 and page != 3:
		return
	var count := 0
	if page == 2:
		if root.screen_state_controller.hub_shop_sell_mode:
			count = shop_sellable_items(root).size()
		elif root.run_state != null:
			root.run_state.ensure_shop_stock(root.player_profile)
			count = root.run_state.shop_stock.size()
	elif page == 3:
		count = hub_fusion_candidates(root).size()
	if count <= 0:
		return
	var visible_rows := ShopMenuLayoutScript.VISIBLE_ROWS if page == HUB_PAGE_SHOP and root.screen_state_controller.hub_shop_menu != null else FusionMenuLayoutScript.FUSION_VISIBLE_ROWS if page == HUB_PAGE_FUSION and root.screen_state_controller.hub_fusion_menu != null else HubResponsiveLayoutPresenterScript.LEGACY_ITEM_VISIBLE_ROWS
	var window_start := int(root.screen_state_controller.hub_list_scroll)
	var target := window_start + row
	if row < 0 or row >= visible_rows or target < 0 or target >= count:
		return
	# A second touch on the already-selected row is the touch equivalent of
	# pressing the controller action button. The first touch still only selects
	# the row, including when entering from the SHOP root preview.
	var shop_row_is_confirm: bool = page == HUB_PAGE_SHOP and not root.screen_state_controller.hub_is_root and root.screen_state_controller.hub_shop_state == SHOP_STATE_ITEM_BROWSE
	if shop_row_is_confirm and target == root.screen_state_controller.hub_item_index:
		root.call("_hub_item_action")
		return
	root.screen_state_controller.hub_item_index = target
	if page == HUB_PAGE_SHOP:
		# A visible item is a direct touch entry point from the SHOP root preview.
		root.screen_state_controller.hub_is_root = false
	root.screen_state_controller.hub_content_focus = true
	root.screen_state_controller.hub_equipment_action_focus = false
	if page == 2:
		root.screen_state_controller.hub_shop_state = SHOP_STATE_ITEM_BROWSE
		root.screen_state_controller.hub_shop_sell_target_key = ""
		root.screen_state_controller.hub_shop_sell_confirm_pending = false
		root.screen_state_controller.hub_shop_sell_amount = 1
		root.screen_state_controller.hub_shop_sell_amount_max = 1
	if page == 3:
		var fusion_items := hub_fusion_candidates(root)
		root.screen_state_controller.hub_fusion_target_instance_id = fusion_items[target].instance_id if target < fusion_items.size() else ""
		root.screen_state_controller.hub_is_root = false
		root.screen_state_controller.hub_fusion_state = 1
		root.screen_state_controller.hub_fusion_item_selected = false
		root.screen_state_controller.hub_fusion_count = 1
		root.screen_state_controller.hub_fusion_message = ""
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_hover", -6.0, 1.0)


func hub_gear_candidates(root: Object, slot: StringName) -> Array[ItemInstance]:
	var candidates: Array[ItemInstance] = []
	if root.player_profile == null:
		return candidates
	var catalog := ItemCatalog.new()
	slot = ItemCatalog.canonical_slot(slot)
	if slot == &"shield":
		var unequip := ItemInstance.new()
		unequip.instance_id = ItemCatalog.UNEQUIP_SHIELD_ID
		candidates.append(unequip)
	var grouped: Dictionary = {}
	var group_order: Array[String] = []
	var equipped_ids: Array = root.player_profile.equipped_instance_ids.values()
	for data: Dictionary in root.player_profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		if catalog.definition_slot(item.definition_id) != slot:
			continue
		var key := item.inventory_stack_key()
		if not grouped.has(key):
			grouped[key] = item
			group_order.append(key)
			continue
		var current := grouped[key] as ItemInstance
		# Keep the equipped copy as the representative. Equipping an exact
		# duplicate has the same result, but this keeps the selection tied to the
		# currently worn instance and avoids an unnecessary state change.
		if equipped_ids.has(item.instance_id) and not equipped_ids.has(current.instance_id):
			grouped[key] = item
	for key: String in group_order:
		candidates.append(grouped[key] as ItemInstance)
	return candidates


func shift_hub_gear_candidate(root: Object, direction: int) -> void:
	if root.screen_state_controller.hub_page != 1 or not root.screen_state_controller.hub_gear_browsing: return
	var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var candidates := hub_gear_candidates(root, slot)
	if candidates.is_empty(): return
	var key := String(slot)
	root.screen_state_controller.hub_gear_candidate_indices[key] = posmod(int(root.screen_state_controller.hub_gear_candidate_indices.get(key, 0)) + direction, candidates.size())
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.snap_hub_list_scroll_to_selection(root)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func shift_hub_gear_candidate_grid(root: Object, column_direction: int, row_direction: int) -> void:
	if (root.screen_state_controller.hub_page != HUB_PAGE_EQUIPMENT and not root.screen_state_controller.is_pause_equipment_active()) or not root.screen_state_controller.hub_gear_browsing:
		return
	var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var candidates := hub_gear_candidates(root, slot)
	if candidates.is_empty():
		return
	var key := String(slot)
	var current := posmod(int(root.screen_state_controller.hub_gear_candidate_indices.get(key, 0)), candidates.size())
	var columns := 2
	var rows := maxi(int(ceil(float(candidates.size()) / float(columns))), 1)
	var column := current % columns
	var row := floori(float(current) / float(columns))
	column = posmod(column + column_direction, columns)
	row = posmod(row + row_direction, rows)
	var target := row * columns + column
	# A ragged final row wraps to its last real entry instead of selecting an
	# empty cell in the two-column candidate grid.
	if target >= candidates.size():
		target = candidates.size() - 1
	root.screen_state_controller.hub_gear_candidate_indices[key] = target
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	var max_start := maxi(0, int(ceil(float(candidates.size()) / 2.0)) * 2 - 8)
	var start := int(root.screen_state_controller.hub_choice_scroll)
	start = clampi(start - (start % 2), 0, max_start)
	if target < start: start = target - (target % 2)
	elif target >= start + 8: start = target - 6 if target % 2 == 0 else target - 7
	root.screen_state_controller.hub_choice_scroll = clampf(float(clampi(start, 0, max_start)), 0.0, float(max_start))
	root.screen_state_controller.refresh_equipment_menu(root)


func select_hub_gear_slot(root: Object, slot_index: int) -> void:
	if root.screen_state_controller.hub_page != 1 and not root.screen_state_controller.is_pause_equipment_active(): return
	var locked_slot: StringName = ItemCatalog.SLOTS[clampi(slot_index, 0, ItemCatalog.SLOTS.size() - 1)]
	if locked_slot == &"head" and root.player_profile._head_locked_by_body(ItemCatalog.new()):
		return
	root.screen_state_controller.hub_item_index = clampi(slot_index, 0, ItemCatalog.SLOTS.size() - 1)
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.hub_content_focus = true
	var remove_mode: bool = root.screen_state_controller.hub_equipment_mode == EQUIPMENT_MODE_SLOT_REMOVE
	HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_REMOVE if remove_mode else EQUIPMENT_MODE_SLOT_EQUIP)
	var slot: StringName = ItemCatalog.SLOTS[root.screen_state_controller.hub_item_index]
	var candidates := hub_gear_candidates(root, slot)
	# A slot selection is the parent state of the item picker. Empty slots remain
	# selectable so the player can move through the six-piece list, but only a
	# slot with candidates can descend into the item state.
	if not remove_mode:
		root.screen_state_controller.hub_gear_browsing = not candidates.is_empty()
		root.screen_state_controller.hub_equipment_mode = EQUIPMENT_MODE_CANDIDATE if not candidates.is_empty() else EQUIPMENT_MODE_SLOT_EQUIP
	else:
		root.screen_state_controller.hub_gear_browsing = false
	if not candidates.is_empty():
		var equipped_id: String = root.player_profile.get_equipped_instance_id(slot)
		for index in candidates.size():
			if candidates[index].instance_id == equipped_id:
				root.screen_state_controller.hub_gear_candidate_indices[String(slot)] = index
				break
	root.screen_state_controller.snap_hub_list_scroll_to_selection(root)
	root.screen_state_controller.refresh_equipment_menu(root)
	root.call("_play_sound", "ui_confirm" if not candidates.is_empty() else "ui_no_input", 0.0, 1.0)


func select_hub_gear_candidate(root: Object, choice_row: int) -> void:
	if (root.screen_state_controller.hub_page != 1 and not root.screen_state_controller.is_pause_equipment_active()) or not root.screen_state_controller.hub_gear_browsing:
		return
	var selected_slot_index := clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var slot: StringName = ItemCatalog.SLOTS[selected_slot_index]
	var candidates := hub_gear_candidates(root, slot)
	if candidates.is_empty():
		return
	var visible_choice_count := EquipmentMenuLayoutScript.CANDIDATE_VISIBLE_COUNT if root.screen_state_controller.hub_equipment_menu != null else HubResponsiveLayoutPresenterScript.LEGACY_GEAR_CHOICE_VISIBLE_ROWS
	var window_start := int(floor(float(root.screen_state_controller.hub_choice_scroll) / 2.0)) * 2
	var candidate_index := window_start + choice_row
	if choice_row < 0 or choice_row >= visible_choice_count or candidate_index < 0 or candidate_index >= candidates.size():
		return
	root.screen_state_controller.hub_gear_candidate_indices[String(slot)] = candidate_index
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	hub_item_action(root)


func tap_hub_gear_candidate(root: Object, choice_row: int) -> void:
	if (root.screen_state_controller.hub_page != 1 and not root.screen_state_controller.is_pause_equipment_active()) or not root.screen_state_controller.hub_gear_browsing:
		return
	var selected_slot_index := clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var slot: StringName = ItemCatalog.SLOTS[selected_slot_index]
	var candidates := hub_gear_candidates(root, slot)
	if candidates.is_empty():
		return
	var visible_choice_count := EquipmentMenuLayoutScript.CANDIDATE_VISIBLE_COUNT if root.screen_state_controller.hub_equipment_menu != null else HubResponsiveLayoutPresenterScript.LEGACY_GEAR_CHOICE_VISIBLE_ROWS
	var window_start := int(floor(float(root.screen_state_controller.hub_choice_scroll) / 2.0)) * 2
	var candidate_index := window_start + choice_row
	if choice_row < 0 or choice_row >= visible_choice_count or candidate_index < 0 or candidate_index >= candidates.size():
		return
	var selected_by_slot: Dictionary = root.screen_state_controller.hub_gear_candidate_indices
	var current_index := posmod(int(selected_by_slot.get(String(slot), 0)), candidates.size())
	if current_index == candidate_index:
		HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
		hub_item_action(root)
		return
	selected_by_slot[String(slot)] = candidate_index
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.refresh_equipment_menu(root)
	root.call("_play_sound", "ui_hover", -6.0, 1.0)


func close_hub_gear_browse(root: Object) -> void:
	# BACK from the item list returns to the slot list, not the top command row.
	HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_EQUIP)
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.refresh_equipment_menu(root)
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


# Fusion candidate cache, item sales, and salvage.
func refresh_hub_fusion_candidates(root: Object) -> void:
	var screen: Object = root.screen_state_controller
	screen.hub_fusion_candidates.clear()
	screen.hub_fusion_candidates_dirty = false
	_fusion_details_by_root[root.get_instance_id()] = {}
	if root.player_profile == null:
		_fusion_profile_instance_by_root.erase(root.get_instance_id())
		_fusion_inventory_revision_by_root.erase(root.get_instance_id())
		_fusion_equipment_signature_by_root.erase(root.get_instance_id())
		return
	_fusion_profile_instance_by_root[root.get_instance_id()] = root.player_profile.get_instance_id()
	_fusion_inventory_revision_by_root[root.get_instance_id()] = root.player_profile.inventory_revision
	_fusion_equipment_signature_by_root[root.get_instance_id()] = _fusion_equipment_signature(root.player_profile)
	var catalog := ItemCatalog.new()
	var equipped_ids: Dictionary = {}
	for equipped_id: Variant in root.player_profile.equipped_instance_ids.values():
		equipped_ids[str(equipped_id)] = true
	var unequipped_count_by_fusion_key: Dictionary = {}
	var grouped_by_stack_key: Dictionary = {}
	for data: Dictionary in root.player_profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		var slot := catalog.definition_slot(item.definition_id)
		if slot not in ItemCatalog.SLOTS:
			continue
		var item_equipped: bool = equipped_ids.has(item.instance_id)
		var fusion_key := _fusion_material_key(item)
		if not item_equipped:
			unequipped_count_by_fusion_key[fusion_key] = int(unequipped_count_by_fusion_key.get(fusion_key, 0)) + 1
		var stack_key := item.inventory_stack_key()
		if not grouped_by_stack_key.has(stack_key):
			grouped_by_stack_key[stack_key] = {"representative": item, "equipped": item_equipped, "fusion_key": fusion_key}
		elif item_equipped and not bool(grouped_by_stack_key[stack_key]["equipped"]):
			grouped_by_stack_key[stack_key]["representative"] = item
			grouped_by_stack_key[stack_key]["equipped"] = true
	var equipped_candidates: Array[ItemInstance] = []
	var unequipped_candidates: Array[ItemInstance] = []
	var candidate_details: Dictionary = {}
	for group_value: Variant in grouped_by_stack_key.values():
		var group: Dictionary = group_value
		var item := group["representative"] as ItemInstance
		var item_equipped := bool(group["equipped"])
		var unequipped_count := int(unequipped_count_by_fusion_key.get(str(group["fusion_key"]), 0))
		var available_materials := maxi(unequipped_count - (0 if item_equipped else 1), 0)
		var material_count := mini(available_materials, root.player_profile.fusion_steps_to_next_rank(item))
		var can_salvage: bool = not item_equipped and item.rarity == &"mythic" and item.enhancement_level >= PlayerProfile.MAX_ITEM_ENHANCEMENT
		if material_count < 1 and not can_salvage:
			continue
		candidate_details[item.instance_id] = {
			"owned_count": unequipped_count,
			"material_count": material_count,
			"can_salvage": can_salvage,
		}
		(equipped_candidates if item_equipped else unequipped_candidates).append(item)
	_sort_fusion_candidates(equipped_candidates, catalog)
	_sort_fusion_candidates(unequipped_candidates, catalog)
	screen.hub_fusion_candidates.append_array(equipped_candidates)
	screen.hub_fusion_candidates.append_array(unequipped_candidates)
	_fusion_details_by_root[root.get_instance_id()] = candidate_details


func _fusion_material_key(item: ItemInstance) -> String:
	return "%s::%s" % [String(item.definition_id), String(item.rarity)]


func _fusion_equipment_signature(profile: PlayerProfile) -> String:
	var slots: Array[String] = []
	for slot: Variant in profile.equipped_instance_ids:
		slots.append("%s=%s" % [str(slot), str(profile.equipped_instance_ids[slot])])
	slots.sort()
	return ";".join(slots)


func _sort_fusion_candidates(candidates: Array[ItemInstance], catalog: ItemCatalog) -> void:
	var sort_values: Dictionary = {}
	for item: ItemInstance in candidates:
		sort_values[item.instance_id] = {
			"total": catalog.stat_allocation_total(item),
			"name": catalog.gear_name(item),
			"definition": String(item.definition_id),
		}
	candidates.sort_custom(func(left: ItemInstance, right: ItemInstance) -> bool:
		var left_values: Dictionary = sort_values[left.instance_id]
		var right_values: Dictionary = sort_values[right.instance_id]
		var left_total := float(left_values["total"])
		var right_total := float(right_values["total"])
		if not is_equal_approx(left_total, right_total):
			return left_total > right_total
		var left_name := str(left_values["name"])
		var right_name := str(right_values["name"])
		if left_name != right_name:
			return left_name < right_name
		var left_definition := str(left_values["definition"])
		var right_definition := str(right_values["definition"])
		if left_definition != right_definition:
			return left_definition < right_definition
		return left.instance_id < right.instance_id
	)


func invalidate_hub_fusion_candidates(root: Object) -> void:
	root.screen_state_controller.hub_fusion_candidates_dirty = true
	_fusion_details_by_root.erase(root.get_instance_id())
	_fusion_profile_instance_by_root.erase(root.get_instance_id())
	_fusion_inventory_revision_by_root.erase(root.get_instance_id())
	_fusion_equipment_signature_by_root.erase(root.get_instance_id())


func sell_profile_item(root: Object, instance_id: String) -> bool:
	if root.player_profile == null:
		return false
	var sale: Dictionary = root.player_profile.sell_item(instance_id, ItemCatalog.new())
	if sale.is_empty():
		return false
	root.player_equipment.configure_from_profile(root.player_profile)
	root.call("_configure_equipment_transmutations")
	root.call("_save_player_profile")
	root.call("_update_gold_indicator")
	root.call("_update_soul_indicator")
	root.screen_state_controller.hub_item_index = 0
	root.screen_state_controller.hub_list_scroll = 0.0
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	invalidate_hub_fusion_candidates(root)
	return true


func sell_profile_items(root: Object, selected: ItemInstance, quantity: int, selected_index: int) -> bool:
	if root.player_profile == null or selected == null or quantity <= 0:
		return false
	var sellable := shop_sellable_items(root)
	var previous_scroll: float = float(root.screen_state_controller.hub_list_scroll)
	var matching_ids := shop_matching_ids(root, selected)
	if matching_ids.size() < quantity:
		return false
	matching_ids = matching_ids.slice(0, quantity)
	var sale: Dictionary = root.player_profile.sell_items(matching_ids, ItemCatalog.new())
	if sale.is_empty():
		return false
	root.player_equipment.configure_from_profile(root.player_profile)
	root.call("_configure_equipment_transmutations")
	root.call("_save_player_profile")
	root.call("_update_gold_indicator")
	root.call("_update_soul_indicator")
	invalidate_hub_fusion_candidates(root)
	var remaining_sellable := shop_sellable_items(root)
	var remaining_count := remaining_sellable.size()
	# Preserve the visible list position after the inventory rebuild. If a sold item
	# variant disappears before the selected row, both the selected index and the
	# logical window move left by the same amount. A partial sale leaves its exact
	# variant row in place, so count rows by stack identity rather than by IDs.
	var removed_before := 0
	for index in range(mini(selected_index, sellable.size())):
		var old_item := sellable[index] as ItemInstance
		var still_present := false
		for remaining_item: ItemInstance in remaining_sellable:
			if shop_items_match(old_item, remaining_item):
				still_present = true
				break
		if not still_present:
			removed_before += 1
	var selected_after := selected_index - removed_before
	for index in remaining_sellable.size():
		if shop_items_match(remaining_sellable[index], selected):
			selected_after = index
			break
	root.screen_state_controller.hub_item_index = clampi(selected_after, 0, maxi(remaining_count - 1, 0))
	var max_scroll := maxf(0.0, float(remaining_count - ShopMenuLayoutScript.VISIBLE_ROWS))
	var restored_scroll := clampf(previous_scroll - float(removed_before), 0.0, max_scroll)
	var restored_start := int(floor(restored_scroll))
	if root.screen_state_controller.hub_item_index < restored_start:
		restored_scroll = float(root.screen_state_controller.hub_item_index)
	elif root.screen_state_controller.hub_item_index >= restored_start + ShopMenuLayoutScript.VISIBLE_ROWS:
		restored_scroll = float(root.screen_state_controller.hub_item_index - ShopMenuLayoutScript.VISIBLE_ROWS + 1)
	root.screen_state_controller.hub_list_scroll = clampf(restored_scroll, 0.0, max_scroll)
	root.screen_state_controller.hub_shop_state = SHOP_STATE_ITEM_BROWSE
	root.screen_state_controller.hub_shop_sell_target_key = ""
	root.screen_state_controller.hub_shop_sell_amount = 1
	root.screen_state_controller.hub_shop_sell_amount_max = 1
	root.screen_state_controller.hub_shop_sell_confirm_pending = false
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	return true


func hub_fusion_candidates(root: Object) -> Array[ItemInstance]:
	var root_id := root.get_instance_id()
	var profile := root.player_profile as PlayerProfile
	var profile_changed := profile == null
	if profile != null:
		profile_changed = (
			int(_fusion_profile_instance_by_root.get(root_id, -1)) != profile.get_instance_id()
			or int(_fusion_inventory_revision_by_root.get(root_id, -1)) != profile.inventory_revision
			or str(_fusion_equipment_signature_by_root.get(root_id, "")) != _fusion_equipment_signature(profile)
		)
	if root.screen_state_controller.hub_fusion_candidates_dirty or profile_changed:
		refresh_hub_fusion_candidates(root)
	_reconcile_fusion_selection(root)
	return root.screen_state_controller.hub_fusion_candidates


func _reconcile_fusion_selection(root: Object) -> void:
	var screen: Object = root.screen_state_controller
	var selected_id := str(screen.hub_fusion_target_instance_id)
	if selected_id.is_empty():
		return
	var candidates: Array[ItemInstance] = screen.hub_fusion_candidates
	for index in candidates.size():
		if candidates[index].instance_id != selected_id:
			continue
		screen.hub_item_index = index
		var visible_rows := FusionMenuLayoutScript.FUSION_VISIBLE_ROWS if screen.hub_fusion_menu != null else HubResponsiveLayoutPresenterScript.LEGACY_ITEM_VISIBLE_ROWS
		var max_scroll := maxi(0, candidates.size() - visible_rows)
		var window_start := clampi(int(floor(float(screen.hub_list_scroll))), 0, max_scroll)
		if index < window_start:
			window_start = index
		elif index >= window_start + visible_rows:
			window_start = index - visible_rows + 1
		screen.hub_list_scroll = float(clampi(window_start, 0, max_scroll))
		return
	screen.hub_fusion_target_instance_id = ""
	screen.hub_fusion_count = 1
	if screen.hub_fusion_state == 2:
		screen.hub_fusion_state = 1
		screen.hub_fusion_item_selected = false
	screen.hub_item_index = clampi(screen.hub_item_index, 0, maxi(candidates.size() - 1, 0))


func fusion_candidate_details(root: Object, item: ItemInstance) -> Dictionary:
	if item == null or root.player_profile == null:
		return {}
	var live_target: ItemInstance = root.player_profile.find_item(item.instance_id)
	if live_target == null:
		return {}
	var catalog := ItemCatalog.new()
	return {
		"owned_count": root.player_profile.fusion_owned_count(live_target.instance_id, catalog),
		"material_count": root.player_profile.fusion_material_count(live_target.instance_id, catalog),
		"can_salvage": root.player_profile.can_salvage_overflow(live_target.instance_id, catalog),
	}


func fuse_profile_target(root: Object, instance_id: String, count: int) -> bool:
	if root.player_profile == null or count <= 0 or not root.player_profile.fuse_duplicates(instance_id, count, ItemCatalog.new()):
		return false
	root.player_equipment.configure_from_profile(root.player_profile)
	root.call("_configure_equipment_transmutations")
	root.call("_apply_player_level")
	root.call("_save_player_profile")
	root.call("_update_soul_indicator")
	invalidate_hub_fusion_candidates(root)
	return true


func shift_hub_fusion_count(root: Object, direction: int) -> void:
	if root.screen_state_controller.hub_page != 3: return
	# The amount controls are only live after the target confirmation has entered
	# the quantity step. On the browse/preview page, +/- must not implicitly pick
	# an item or look like a failed action.
	if root.screen_state_controller.hub_fusion_state != 2: return
	var candidates := hub_fusion_candidates(root)
	if candidates.is_empty(): return
	var selected_id := str(root.screen_state_controller.hub_fusion_target_instance_id)
	if selected_id.is_empty():
		return
	var index := -1
	for candidate_index in candidates.size():
		if candidates[candidate_index].instance_id == selected_id:
			index = candidate_index
			break
	if index < 0:
		return
	var target: ItemInstance = candidates[index]
	var target_details := fusion_candidate_details(root, target)
	var material_count := int(target_details.get("material_count", 0))
	if material_count <= 0: return
	var previous_count := clampi(int(root.screen_state_controller.hub_fusion_count), 1, material_count)
	var next_count := clampi(previous_count + direction, 1, material_count)
	if next_count == previous_count: return
	root.screen_state_controller.hub_fusion_count = next_count
	root.screen_state_controller.hub_fusion_message = ""
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func salvage_profile_overflow(root: Object, instance_id: String) -> int:
	if root.player_profile == null: return 0
	var value: int = root.player_profile.salvage_overflow(instance_id)
	if value <= 0: return 0
	invalidate_hub_fusion_candidates(root)
	root.call("_save_player_profile")
	root.call("_update_gold_indicator")
	return value


# Contextual shop, fusion, and equipment actions.
func hub_item_action(root: Object) -> void:
	if root.player_profile == null:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	if root.screen_state_controller.hub_page == 1 or root.screen_state_controller.is_pause_equipment_active():
		# The visible EQUIP command is a route transition. It must not silently
		# select the first slot or open an item picker beneath the command row.
		if root.screen_state_controller.hub_equipment_mode == EQUIPMENT_MODE_COMMAND or root.screen_state_controller.hub_equipment_action_focus:
			root.screen_state_controller.hub_is_root = false
			HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_EQUIP)
			root.screen_state_controller.hub_content_focus = true
			root.screen_state_controller.hub_item_index = clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
			root.screen_state_controller.refresh_equipment_menu(root)
			root.call("_play_sound", "ui_confirm", 0.0, 1.0)
			return
		var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var candidates := hub_gear_candidates(root, slot)
		if candidates.is_empty():
			# Empty equipment slots are intentionally selectable, but confirming
			# one cannot descend into an item picker.
			root.call("_play_sound", "ui_no_input", 0.0, 1.0)
			return
		var candidate_index: int = posmod(int(root.screen_state_controller.hub_gear_candidate_indices.get(String(slot), 0)), candidates.size())
		if root.screen_state_controller.hub_equipment_mode != EQUIPMENT_MODE_CANDIDATE and not root.screen_state_controller.hub_gear_browsing:
			var equipped_id: String = root.player_profile.get_equipped_instance_id(slot)
			for index in candidates.size():
				if candidates[index].instance_id == equipped_id:
					root.screen_state_controller.hub_gear_candidate_indices[String(slot)] = index
					break
			HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_CANDIDATE)
		else:
			var selected: ItemInstance = candidates[candidate_index]
			var equipped_id: String = root.player_profile.get_equipped_instance_id(slot)
			if selected.instance_id == equipped_id and not equipped_id.is_empty():
				# Confirming the item already occupying this slot has no state change.
				# Close the picker as a completed browse, but use the explicit no-op
				# cue instead of replaying the equip transaction sound.
				HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_EQUIP)
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
				HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
				root.screen_state_controller.refresh_equipment_menu(root)
				return
			var changed := false
			if selected.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID or (slot == &"shield" and selected.instance_id == equipped_id):
				changed = bool(root.call("_unequip_profile_slot", slot))
			else:
				changed = bool(root.call("_equip_profile_item", selected.instance_id))
			if not changed:
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
			else:
				# Equipping or unequipping changes which copies may be used as
				# materials, so the cached target list must be rebuilt.
				invalidate_hub_fusion_candidates(root)
				# Confirming an item returns to the slot list. The selected slot and
			# candidate cursor are preserved for quick successive changes.
			HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_EQUIP)
			HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
			root.screen_state_controller.refresh_equipment_menu(root)
		return
	elif root.screen_state_controller.hub_page == 2:
		if root.screen_state_controller.hub_shop_sell_mode:
			var sellable := shop_sellable_items(root)
			if sellable.is_empty():
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
				return
			var sell_index := clampi(root.screen_state_controller.hub_item_index, 0, sellable.size() - 1)
			var selected_sell := sellable[sell_index]
			if root.screen_state_controller.hub_shop_state != SHOP_STATE_SELL_AMOUNT:
				root.screen_state_controller.hub_shop_state = SHOP_STATE_SELL_AMOUNT
				root.screen_state_controller.hub_shop_sell_target_key = selected_sell.inventory_stack_key()
				root.screen_state_controller.hub_shop_sell_amount = 1
				root.screen_state_controller.hub_shop_sell_amount_max = maxi(shop_owned_matching_count(root, selected_sell), 1)
				root.screen_state_controller.hub_shop_sell_confirm_pending = false
				root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
				root.call("_play_sound", "ui_confirm", 0.0, 1.0)
				return
			if root.screen_state_controller.hub_shop_sell_target_key != selected_sell.inventory_stack_key():
				shop_amount_cancelled(root)
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
				return
			if sell_profile_items(root, selected_sell, root.screen_state_controller.hub_shop_sell_amount, sell_index):
				root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
			else:
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
			return
		if root.run_state == null or root.run_state.shop_stock.is_empty():
			# Shop can be opened before its stock is generated. Confirming an empty
			# shop has no transaction to perform.
			root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		else:
			var index: int = clampi(root.screen_state_controller.hub_item_index, 0, root.run_state.shop_stock.size() - 1)
			var entry: Dictionary = root.run_state.shop_stock[index]
			if bool(entry.get("permanent", false)):
				# Demon Cloak: always in stock, never sold out, price escalates per purchase.
				var cloak_item := root.player_profile.purchase_demon_cloak() as ItemInstance
				if cloak_item != null:
					var cloak_catalog := ItemCatalog.new()
					var body_was_empty := cloak_catalog.slot_needs_introduction(root.player_profile, &"body")
					root.run_state.record_gear_reward(&"shop", cloak_item, root.player_profile.difficulty_rank, root.player_profile.level, -1, "", body_was_empty, false, &"purchased")
					entry["price"] = root.player_profile.demon_cloak_price()
					root.run_state.shop_stock[index] = entry; invalidate_hub_fusion_candidates(root); root.call("_save_player_profile"); root.call("_update_gold_indicator"); root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture")); root.call("_play_sound", "ui_confirm", 0.0, 1.0); root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
				else:
					root.call("_play_sound", "ui_no_input", 0.0, 1.0)
			elif not bool(entry.get("sold", false)):
				var item := ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary)
				var catalog := ItemCatalog.new()
				var slot_was_empty := catalog.slot_needs_introduction(root.player_profile, catalog.definition_slot(item.definition_id))
				if root.player_profile.purchase_item(item, int(entry.get("price", 0))):
					root.run_state.record_gear_reward(&"shop", item, root.player_profile.difficulty_rank, root.player_profile.level, -1, "", slot_was_empty, false, &"purchased")
					entry["sold"] = true; root.run_state.shop_stock[index] = entry; invalidate_hub_fusion_candidates(root); root.call("_save_player_profile"); root.call("_update_gold_indicator"); root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture")); root.call("_play_sound", "ui_confirm", 0.0, 1.0); root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
				else:
					root.call("_play_sound", "ui_no_input", 0.0, 1.0)
			else:
				# Reconfirming a sold item has no transaction to perform.
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
	elif root.screen_state_controller.hub_page == 3:
		if root.screen_state_controller.hub_fusion_state == 1:
			var available_targets := hub_fusion_candidates(root)
			if available_targets.is_empty():
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
				return
			var selected_target := _selected_fusion_target(root, available_targets)
			if selected_target == null:
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
				return
			root.screen_state_controller.hub_fusion_target_instance_id = selected_target.instance_id
			root.screen_state_controller.hub_fusion_item_selected = true
			root.screen_state_controller.hub_fusion_state = 2
			root.screen_state_controller.hub_is_root = false
			root.screen_state_controller.hub_content_focus = true
			root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
			root.call("_play_sound", "ui_confirm", 0.0, 1.0)
			return
		var confirmed_target_id := str(root.screen_state_controller.hub_fusion_target_instance_id)
		if confirmed_target_id.is_empty():
			root.call("_play_sound", "ui_no_input", 0.0, 1.0)
			return
		var fusion_candidates := hub_fusion_candidates(root)
		if root.screen_state_controller.hub_fusion_state != 2 or str(root.screen_state_controller.hub_fusion_target_instance_id) != confirmed_target_id:
			root.call("_play_sound", "ui_no_input", 0.0, 1.0)
			root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
			return
		var fusion_changed := false
		var fusion_feedback_played := false
		if not fusion_candidates.is_empty():
			var target := _selected_fusion_target(root, fusion_candidates)
			if target == null:
				root.screen_state_controller.hub_fusion_state = 1
				root.screen_state_controller.hub_fusion_item_selected = false
				root.screen_state_controller.hub_fusion_count = 1
				root.screen_state_controller.hub_fusion_target_instance_id = ""
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
				root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
				return
			var target_details := fusion_candidate_details(root, target)
			var material_count := int(target_details.get("material_count", 0))
			if material_count > 0:
				var count: int = clampi(int(root.screen_state_controller.hub_fusion_count), 1, material_count)
				var batch_cost: int = root.player_profile.fusion_batch_cost(target, count)
				if root.player_profile.souls < batch_cost:
					root.screen_state_controller.hub_fusion_message = "NEED %dS" % batch_cost
					root.call("_play_sound", "ui_no_input", 0.0, 1.0)
					fusion_feedback_played = true
				else:
					var family_name := str(ItemCatalog.new().definition_data(target.definition_id).get("name", "ITEM"))
					if fuse_profile_target(root, target.instance_id, count):
						root.screen_state_controller.hub_fusion_message = "%s ENHANCED" % family_name
						fusion_changed = true
						root.call("_play_sound", "ui_confirm", 0.0, 1.0)
						root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
					else:
						root.screen_state_controller.hub_fusion_message = "MATERIALS CHANGED"
						root.call("_play_sound", "ui_no_input", 0.0, 1.0)
						fusion_feedback_played = true
			elif bool(target_details.get("can_salvage", false)):
				var salvage_value: int = salvage_profile_overflow(root, target.instance_id)
				if salvage_value > 0:
					root.screen_state_controller.hub_fusion_message = "SALVAGED %dG" % salvage_value
					fusion_changed = true
					root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
				else:
					root.call("_play_sound", "ui_no_input", 0.0, 1.0)
					fusion_feedback_played = true
			else:
				root.call("_play_sound", "ui_no_input", 0.0, 1.0)
				fusion_feedback_played = true
		if not fusion_feedback_played and not fusion_changed:
			root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		if not root.screen_state_controller.hub_fusion_message.is_empty():
			invalidate_hub_fusion_candidates(root)
			root.screen_state_controller.hub_item_index = clampi(root.screen_state_controller.hub_item_index, 0, maxi(hub_fusion_candidates(root).size() - 1, 0))
			root.screen_state_controller.hub_fusion_target_instance_id = ""
			root.screen_state_controller.hub_fusion_state = 1
			root.screen_state_controller.hub_fusion_item_selected = false
			root.screen_state_controller.hub_fusion_count = 1
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func _selected_fusion_target(root: Object, candidates: Array[ItemInstance]) -> ItemInstance:
	var profile := root.player_profile as PlayerProfile
	var selected_id := str(root.screen_state_controller.hub_fusion_target_instance_id)
	if not selected_id.is_empty():
		for candidate: ItemInstance in candidates:
			if candidate.instance_id == selected_id:
				return profile.find_item(selected_id)
		return null
	var index := clampi(root.screen_state_controller.hub_item_index, 0, candidates.size() - 1)
	return profile.find_item(candidates[index].instance_id) if not candidates.is_empty() else null


# Equipment removal and confirmation.
func remove_hub_gear(root: Object) -> void:
	if root.player_profile == null or (root.screen_state_controller.hub_page != root.screen_state_controller.HUB_PAGE_EQUIPMENT and not root.screen_state_controller.is_pause_equipment_active()):
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	# The command row is the entry point.  Once the modal cursor is active, a
	# second Confirm must perform the transaction; checking action_focus here
	# would reopen the modal forever because that flag intentionally stays true.
	if root.screen_state_controller.hub_equipment_mode == EQUIPMENT_MODE_COMMAND:
		# REMOVE descends into the same six-panel slot grid as EQUIP. A second
		# confirm on a slot performs the actual unequip.
		root.screen_state_controller.hub_is_root = false
		HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
		HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_REMOVE)
		root.screen_state_controller.hub_content_focus = true
		root.screen_state_controller.refresh_equipment_menu(root)
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		return
	var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
	if bool(root.call("_unequip_profile_slot", slot)):
		HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_REMOVE)
		invalidate_hub_fusion_candidates(root)
		root.call("_save_player_profile")
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	else:
		# The slot grid remains navigable when a slot is empty. Confirming that
		# cell has no transaction to perform.
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
	root.screen_state_controller.refresh_equipment_menu(root)


func remove_all_hub_gear(root: Object) -> void:
	if root.player_profile == null or (root.screen_state_controller.hub_page != root.screen_state_controller.HUB_PAGE_EQUIPMENT and not root.screen_state_controller.is_pause_equipment_active()):
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	if root.screen_state_controller.hub_equipment_mode == EQUIPMENT_MODE_COMMAND or root.screen_state_controller.hub_equipment_action_focus:
		var any_equipped := false
		for slot in ItemCatalog.SLOTS:
			if not root.player_profile.get_equipped_instance_id(slot).is_empty():
				any_equipped = true
				break
		if not any_equipped:
			root.call("_play_sound", "ui_no_input", 0.0, 1.0)
			return
		HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
		root.screen_state_controller.hub_is_root = false
		HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_REMOVE_ALL_CONFIRM)
		# Confirmation is direct: Confirm accepts and Back cancels.  The index is
		# retained only for compatibility with the old hidden Yes/No controls.
		root.screen_state_controller.hub_remove_all_confirm_index = 0
		root.screen_state_controller.hub_content_focus = true
		root.screen_state_controller.refresh_equipment_menu(root)
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		return
	var changed := false
	for slot in ItemCatalog.SLOTS:
		changed = bool(root.call("_unequip_profile_slot", slot)) or changed
	HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.hub_action_column = 2
	if changed:
		invalidate_hub_fusion_candidates(root)
		root.call("_save_player_profile")
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	else:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
	root.screen_state_controller.refresh_equipment_menu(root)


func cancel_remove_all_hub_gear(root: Object) -> void:
	if root.screen_state_controller.hub_page != root.screen_state_controller.HUB_PAGE_EQUIPMENT and not root.screen_state_controller.is_pause_equipment_active():
		return
	HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.hub_action_column = 2
	root.screen_state_controller.refresh_equipment_menu(root)
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


# Hub command focus, stat allocation, and run launch.
func select_hub_menu_row(root: Object, row: int) -> void:
	var screen: Object = root.screen_state_controller
	screen.hub_menu_row = posmod(row, HUB_COMMAND_PAGE_TARGETS.size())
	# The top shell is a live preview: moving across STATS/SHOP/FUSION/BIND
	# swaps the framed content underneath without entering it. Confirm is still
	# the only operation that changes hub_content_focus.
	var target_page: int = HUB_COMMAND_PAGE_TARGETS[screen.hub_menu_row]
	screen.hub_page = target_page
	screen.hub_item_index = 0
	screen.hub_stat_row = 0
	# The command rail is a preview while the hub is at root. Preserve the last
	# BUY/SELL choice instead of silently changing the action that Confirm will
	# enter after the player returns to SHOP.
	screen.hub_action_column = 1 if target_page == HUB_PAGE_SHOP and screen.hub_shop_sell_mode else 0
	HubMenuStateScript.clear_touch_candidate(screen)
	screen.hub_fusion_message = ""
	screen.hub_binding_message = ""
	screen.hub_fusion_state = 1 if target_page == HUB_PAGE_FUSION else 0
	screen.hub_fusion_item_selected = false
	screen.hub_fusion_target_instance_id = ""
	screen.hub_binding_state = 0
	if target_page == HUB_PAGE_FUSION:
		invalidate_hub_fusion_candidates(root)
	if target_page == HUB_PAGE_SHOP and root.run_state != null:
		root.run_state.ensure_shop_stock(root.player_profile)
	screen.hub_is_root = true
	root.screen_state_controller.hub_content_focus = false
	HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func select_hub_stat_row(root: Object, row: int) -> void:
	if root.screen_state_controller.hub_page != root.screen_state_controller.HUB_PAGE_ALLOCATE:
		return
	var previous_row: int = root.screen_state_controller.hub_stat_row
	root.screen_state_controller.hub_stat_row = posmod(row, 6)
	root.screen_state_controller.hub_content_focus = true
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	if root.screen_state_controller.hub_stat_row != previous_row:
		root.call("_play_sound", "ui_hover", -6.0, 1.0)


func shift_hub_action_column(root: Object, direction: int) -> void:
	var page: int = int(root.screen_state_controller.hub_page)
	var count: int = 3 if page == 1 or root.screen_state_controller.is_pause_equipment_active() else 4 if page == 0 else 2
	root.screen_state_controller.hub_action_column = posmod(root.screen_state_controller.hub_action_column + direction, count)
	root.screen_state_controller.refresh_equipment_menu(root)


func hub_adjust_stat(root: Object, stat_name: StringName, direction: int) -> void:
	if direction > 0:
		hub_allocate_stat(root, stat_name)
		return
	match stat_name:
		&"VIT": root.screen_state_controller.hub_pending_vit = maxi(root.screen_state_controller.hub_pending_vit - 1, 0)
		&"STR": root.screen_state_controller.hub_pending_str = maxi(root.screen_state_controller.hub_pending_str - 1, 0)
		&"DEF": root.screen_state_controller.hub_pending_def = maxi(root.screen_state_controller.hub_pending_def - 1, 0)
		&"AGI", &"SPD": root.screen_state_controller.hub_pending_agi = maxi(root.screen_state_controller.hub_pending_agi - 1, 0)
		&"INT": root.screen_state_controller.hub_pending_int = maxi(root.screen_state_controller.hub_pending_int - 1, 0)
		&"MND": root.screen_state_controller.hub_pending_mnd = maxi(root.screen_state_controller.hub_pending_mnd - 1, 0)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_allocate_stat(root: Object, stat_name: StringName) -> void:
	if root.player_profile == null or hub_points_remaining(root) <= 0: return
	match stat_name:
		&"VIT": root.screen_state_controller.hub_pending_vit += 1
		&"STR": root.screen_state_controller.hub_pending_str += 1
		&"DEF": root.screen_state_controller.hub_pending_def += 1
		&"AGI", &"SPD": root.screen_state_controller.hub_pending_agi += 1
		&"INT": root.screen_state_controller.hub_pending_int += 1
		&"MND": root.screen_state_controller.hub_pending_mnd += 1
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_points_remaining(root: Object) -> int:
	return ProgressionControllerScript.points_remaining(root.player_profile, {"VIT": root.screen_state_controller.hub_pending_vit, "STR": root.screen_state_controller.hub_pending_str, "DEF": root.screen_state_controller.hub_pending_def, "AGI": root.screen_state_controller.hub_pending_agi, "INT": root.screen_state_controller.hub_pending_int, "MND": root.screen_state_controller.hub_pending_mnd})


func hub_confirm_stats(root: Object) -> void:
	if root.player_profile == null:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	var pending_total: int = int(root.screen_state_controller.hub_pending_vit) + int(root.screen_state_controller.hub_pending_str) + int(root.screen_state_controller.hub_pending_def) + int(root.screen_state_controller.hub_pending_agi) + int(root.screen_state_controller.hub_pending_int) + int(root.screen_state_controller.hub_pending_mnd)
	if pending_total <= 0:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	ProgressionControllerScript.allocate_stats(root.player_profile, {"VIT": root.screen_state_controller.hub_pending_vit, "STR": root.screen_state_controller.hub_pending_str, "DEF": root.screen_state_controller.hub_pending_def, "AGI": root.screen_state_controller.hub_pending_agi, "INT": root.screen_state_controller.hub_pending_int, "MND": root.screen_state_controller.hub_pending_mnd})
	root.screen_state_controller.hub_pending_vit = 0; root.screen_state_controller.hub_pending_str = 0; root.screen_state_controller.hub_pending_def = 0; root.screen_state_controller.hub_pending_agi = 0; root.screen_state_controller.hub_pending_int = 0; root.screen_state_controller.hub_pending_mnd = 0
	root.call("_apply_profile_to_runtime"); root.call("_apply_player_level"); root.call("_sync_runtime_progression_to_profile")
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_cancel_stats(root: Object, play_feedback: bool = true) -> void:
	root.screen_state_controller.hub_pending_vit = 0; root.screen_state_controller.hub_pending_str = 0; root.screen_state_controller.hub_pending_def = 0; root.screen_state_controller.hub_pending_agi = 0; root.screen_state_controller.hub_pending_int = 0; root.screen_state_controller.hub_pending_mnd = 0
	if root.screen_state_controller != null and root.screen_state_controller.hub_overlay != null: root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	if play_feedback:
		root.call("_play_sound", "ui_decline", 0.0, 1.0)


func hub_auto_allocate(root: Object) -> void:
	if root.player_profile == null or hub_points_remaining(root) <= 0:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)
		return
	var patterns: Array = [[&"VIT", &"STR", &"DEF", &"AGI", &"INT", &"MND"], [&"VIT", &"VIT", &"STR", &"VIT", &"DEF", &"AGI", &"MND"], [&"STR", &"STR", &"VIT", &"STR", &"DEF", &"AGI", &"INT"], [&"DEF", &"DEF", &"VIT", &"DEF", &"STR", &"MND", &"AGI"], [&"STR", &"DEF", &"STR", &"DEF", &"AGI", &"INT", &"MND"]]
	var pattern: Array = patterns[clampi(root.player_profile.allocation_profile, 0, patterns.size() - 1)]
	var index: int = 0
	while hub_points_remaining(root) > 0:
		match pattern[index % pattern.size()]:
			&"VIT": root.screen_state_controller.hub_pending_vit += 1
			&"STR": root.screen_state_controller.hub_pending_str += 1
			&"DEF": root.screen_state_controller.hub_pending_def += 1
			&"AGI", &"SPD": root.screen_state_controller.hub_pending_agi += 1
			&"INT": root.screen_state_controller.hub_pending_int += 1
			&"MND": root.screen_state_controller.hub_pending_mnd += 1
		index += 1
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_respec(root: Object) -> void:
	hub_cancel_stats(root, false)
	var refunded := int(root.call("_respec_player_stats"))
	if refunded > 0:
		root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	else:
		root.call("_play_sound", "ui_no_input", 0.0, 1.0)


func start_from_hub(root: Object) -> void:
	if root.screen_state_controller.hub_opened_from_npc:
		root.call("_close_hub_to_run")
		return
	if root.screen_state_controller.hub_overlay != null: root.screen_state_controller.hub_overlay.visible = false
	root.screen_state_controller.set_menu_world_hidden(root, false)
	if root.player_profile != null:
		root.player_profile.open_hub_on_load = false
		root.player_profile.pending_route = "run"
		root.call("_save_player_profile")
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	root.call("_begin_scene_transition")
