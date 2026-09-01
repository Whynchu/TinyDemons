extends Node
class_name HubFlowController

const ProgressionControllerScript = preload("res://scripts/progression_controller.gd")
const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")

const HUB_PAGE_COUNT := 6
const HUB_PAGE_ALLOCATE := 0
const HUB_PAGE_EQUIPMENT := 1
const HUB_PAGE_SHOP := 2
const HUB_PAGE_FUSION := 3
const HUB_PAGE_BIND := 4
const HUB_PAGE_STATUS := 5
const HUB_COMMAND_PAGE_TARGETS := [5, 0, 1, 2, 3, 4]

const EQUIPMENT_MODE_COMMAND := 0
const EQUIPMENT_MODE_SLOT_EQUIP := 1
const EQUIPMENT_MODE_SLOT_REMOVE := 2
const EQUIPMENT_MODE_CANDIDATE := 3
const EQUIPMENT_MODE_REMOVE_ALL_CONFIRM := 4


func _set_equipment_mode(screen: Object, mode: int) -> void:
	## One transition point keeps the legacy booleans synchronized with the
	## explicit route state consumed by the authored Equipment scene.
	screen.hub_equipment_mode = mode
	screen.hub_equipment_action_focus = mode == EQUIPMENT_MODE_COMMAND
	screen.hub_gear_browsing = mode == EQUIPMENT_MODE_CANDIDATE
	screen.hub_remove_all_confirm_index = clampi(int(screen.hub_remove_all_confirm_index), 0, 1)


func build_hub_ui(root: Object) -> void:
	var controls: Dictionary = root.screen_state_controller.build_hub(root.ui, Callable(root, "_pixel_text_texture"), Callable(root, "_hub_adjust_stat"), Callable(root, "_hub_confirm_stats"), Callable(root, "_hub_cancel_stats"), Callable(root, "_hub_auto_allocate"), Callable(root, "_hub_respec"), Callable(root, "_start_from_hub"), Callable(root, "_return_to_title"), Callable(root, "_set_hub_page"), Callable(root, "_hub_item_action"), Callable(root, "_select_hub_gear_slot"), Callable(root, "_hub_bind_current_element"), Callable(root, "_select_hub_gear_candidate"), Callable(root, "_select_hub_stat_row"), Callable(root, "_select_hub_item_row"), Callable(root, "_shift_hub_fusion_count"), Callable(root, "_close_hub_to_run"), Callable(root, "_open_settings_from_pause"), Callable(root, "_quit_to_title_from_pause"), Callable(root, "_set_pause_status_page"), Callable(root, "_set_pause_equipment_page"), Callable(root, "_pause_back"), Callable(root, "_remove_hub_gear"), Callable(root, "_remove_all_hub_gear"), Callable(root, "_hub_back_or_close"), Callable(root, "_cancel_hub_remove_all"), Callable(root, "_pause_equipment_back"))
	root.screen_state_controller.hub_overlay = controls["overlay"] as ColorRect
	root.screen_state_controller.hub_summary_text = controls["summary"] as Sprite2D
	root.screen_state_controller.hub_points_text = controls["points"] as Sprite2D
	root.screen_state_controller.hub_stat_texts = controls["stats"] as Array[Sprite2D]
	root.screen_state_controller.hub_stat_buttons = controls["stat_buttons"] as Array[Button]
	root.screen_state_controller.hub_stat_left_buttons = controls["stat_left"] as Array[Button]
	root.screen_state_controller.hub_stat_right_buttons = controls["stat_right"] as Array[Button]
	root.screen_state_controller.hub_stat_row_buttons = controls["stat_rows"] as Array[Button]
	root.screen_state_controller.hub_respec_button = controls["respec"] as Button
	root.screen_state_controller.hub_start_button = controls["start"] as Button
	root.screen_state_controller.hub_title_button = controls["title"] as Button
	root.screen_state_controller.hub_derived_texts = controls["derived"] as Array[Sprite2D]
	root.screen_state_controller.hub_apply_button = controls["apply"] as Button
	root.screen_state_controller.hub_cancel_button = controls["cancel"] as Button
	root.screen_state_controller.hub_auto_button = controls["auto"] as Button
	root.screen_state_controller.hub_page_buttons = controls["pages"] as Array[Button]
	root.screen_state_controller.hub_back_button = controls["back"] as Button
	root.screen_state_controller.hub_player_card_texts = controls["card"] as Array[Sprite2D]
	root.screen_state_controller.hub_status_texts = controls["status"] as Array[Sprite2D]
	root.screen_state_controller.hub_context_text = controls["context"] as Sprite2D
	root.screen_state_controller.hub_currency_icon = controls.get("currency_icon") as Sprite2D
	root.screen_state_controller.hub_item_name_text = controls["item_name"] as Sprite2D
	root.screen_state_controller.hub_item_list_texts = controls["item_list"] as Array[Sprite2D]
	root.screen_state_controller.hub_item_row_buttons = controls["item_rows"] as Array[Button]
	root.screen_state_controller.hub_shop_price_texts = controls["shop_prices"] as Array[Sprite2D]
	root.screen_state_controller.hub_gear_choice_texts = controls["gear_choices"] as Array[Sprite2D]
	root.screen_state_controller.hub_gear_choice_buttons = controls["gear_choice_buttons"] as Array[Button]
	root.screen_state_controller.hub_gear_slot_buttons = controls["gear_slot_buttons"] as Array[Button]
	root.screen_state_controller.hub_gear_stat_texts = controls["gear_stats"] as Array[Sprite2D]
	root.screen_state_controller.hub_gear_stat_panel = controls["gear_stat_panel"] as Panel
	root.screen_state_controller.hub_gear_choice_panel = controls["gear_choice_panel"] as Panel
	root.screen_state_controller.hub_gear_choice_content_clip = controls["gear_choice_content_clip"] as Control
	root.screen_state_controller.hub_binding_panel = controls["binding_panel"] as Panel
	root.screen_state_controller.hub_binding_texts = controls["binding_texts"] as Array[Sprite2D]
	root.screen_state_controller.hub_binding_action_button = controls["binding_action"] as Button
	root.screen_state_controller.hub_cursor_text = controls["cursor"] as Sprite2D
	root.screen_state_controller.hub_list_cursor = controls["list_cursor"] as Sprite2D
	root.screen_state_controller.hub_slot_cursor = controls["slot_cursor"] as Sprite2D
	root.screen_state_controller.hub_choice_cursor = controls["choice_cursor"] as Sprite2D
	root.screen_state_controller.hub_equipment_menu = controls.get("equipment_menu") as Control
	root.screen_state_controller.hub_item_detail_texts = controls["item_details"] as Array[Sprite2D]
	root.screen_state_controller.hub_item_action_button = controls["item_action"] as Button
	root.screen_state_controller.hub_equipment_action_buttons = controls["equipment_actions"] as Array[Button]
	root.screen_state_controller.hub_fusion_decrease_button = controls["fusion_decrease"] as Button
	root.screen_state_controller.hub_fusion_increase_button = controls["fusion_increase"] as Button
	root.screen_state_controller.pause_menu_buttons = controls["pause_buttons"] as Array[Button]
	root.screen_state_controller.pause_overlay = controls["pause_overlay"] as ColorRect
	root.screen_state_controller.pause_title_text = controls["pause_title"] as Sprite2D
	root.screen_state_controller.pause_cursor_text = controls["pause_cursor"] as Sprite2D
	root.screen_state_controller.pause_player_card_texts = controls["pause_card"] as Array[Sprite2D]
	root.screen_state_controller.pause_status_texts = controls["pause_status"] as Array[Sprite2D]
	root.screen_state_controller.pause_equipment_texts = controls["pause_equipment"] as Array[Sprite2D]
	root.screen_state_controller.pause_equipment_menu = controls.get("pause_equipment_menu") as Control
	root.screen_state_controller.pause_description_text = controls["pause_description"] as Sprite2D
	root.screen_state_controller.pause_back_button = controls["pause_back"] as Button
	root.screen_state_controller.pause_status_button = controls["pause_status_button"] as Button
	root.screen_state_controller.pause_equipment_button = controls["pause_equipment_button"] as Button
	root.screen_state_controller.pause_resume_button = null
	if root.screen_state_controller.pause_menu_buttons.size() >= 4:
		root.screen_state_controller.pause_settings_button = root.screen_state_controller.pause_menu_buttons[2]
		root.screen_state_controller.pause_quit_button = root.screen_state_controller.pause_menu_buttons[3]


func show_hub(root: Object, from_npc: bool = false, pause_mode: bool = false) -> void:
	if root.screen_state_controller.hub_overlay == null:
		return
	if pause_mode:
		open_pause_menu(root)
		return
	# Inventory and equipped-slot state can change while the hub is closed. The
	# fusion page is intentionally cached for UI reads, so refresh its eligibility
	# whenever the hub is opened instead of showing a stale duplicate list.
	invalidate_hub_fusion_candidates(root)
	root.screen_state_controller.hub_opened_from_npc = from_npc
	root.screen_state_controller.hub_pause_mode = false
	root.screen_state_controller.hub_is_root = true
	root.screen_state_controller.hub_interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	root.screen_state_controller.hub_cancel_input_was_down = bool(root.call("_is_menu_cancel_input_pressed"))
	root.screen_state_controller.hub_page_previous_input_was_down = bool(root.call("_is_hub_previous_page_input_pressed"))
	root.screen_state_controller.hub_page_next_input_was_down = bool(root.call("_is_hub_next_page_input_pressed"))
	if root.screen_state_controller.title_overlay != null: root.screen_state_controller.title_overlay.visible = false
	if root.screen_state_controller.archetype_overlay != null: root.screen_state_controller.archetype_overlay.visible = false
	if root.loading_screen_overlay != null: root.loading_screen_overlay.visible = false
	if root.game_over_overlay != null: root.game_over_overlay.visible = false
	root.screen_state_controller.hub_overlay.visible = true
	if root.screen_state_controller.pause_overlay != null: root.screen_state_controller.pause_overlay.visible = false
	root.screen_state_controller.hub_page = root.screen_state_controller.HUB_PAGE_STATUS
	root.screen_state_controller.hub_item_index = 0
	root.screen_state_controller.hub_content_focus = false
	root.screen_state_controller.hub_binding_message = ""
	root.call("_hub_cancel_stats")
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	root.screen_state_controller.set_state(&"hub")
	root.call("_select_hub_menu_row", 0)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func open_pause_menu(root: Object) -> void:
	if root.player_dead or root.player_death_pending or root.screen_state_controller.pause_overlay == null or root.screen_state_controller.pause_overlay.visible or (root.screen_state_controller.hub_overlay != null and root.screen_state_controller.hub_overlay.visible):
		return
	root.screen_state_controller.pause_input_was_down = true
	root.screen_state_controller.hub_pause_mode = true
	root.screen_state_controller.hub_item_index = 0
	_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	root.screen_state_controller.pause_page = 0
	root.screen_state_controller.hub_is_root = true
	root.screen_state_controller.pause_menu_row = 0
	root.screen_state_controller.pause_interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	root.screen_state_controller.pause_cancel_input_was_down = bool(root.call("_is_menu_cancel_input_pressed"))
	root.screen_state_controller.hub_overlay.visible = false
	if root.screen_state_controller.title_overlay != null: root.screen_state_controller.title_overlay.visible = false
	if root.screen_state_controller.archetype_overlay != null: root.screen_state_controller.archetype_overlay.visible = false
	root.screen_state_controller.pause_overlay.visible = true
	root.screen_state_controller.set_state(&"pause")
	root.screen_state_controller.update_pause_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_pause", 0.0, 1.0)


func open_hub_from_cloaked_demon(root: Object) -> void:
	if root.player_dead or root.screen_state_controller.hub_overlay == null:
		return
	if root.npc_controller.dialogue_box != null and root.npc_controller.dialogue_box.visible:
		root.npc_controller.hide_dialogue(root)
	root.player_is_moving = false
	root.player_is_attacking = false
	root.player_is_rolling = false
	root.player_is_backflipping = false
	root.player_attack_visual.visible = false
	root.interact_prompt.visible = false
	show_hub(root, true)


func close_hub_to_run(root: Object) -> void:
	if root.screen_state_controller.hub_overlay == null and root.screen_state_controller.pause_overlay == null:
		return
	var was_pause: bool = bool(root.screen_state_controller.hub_pause_mode) or (root.screen_state_controller.pause_overlay != null and root.screen_state_controller.pause_overlay.visible)
	root.call("_hub_cancel_stats")
	_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	root.screen_state_controller.menu_input_release_lock = bool(root.call("_is_menu_cancel_input_pressed"))
	if root.screen_state_controller.hub_overlay != null: root.screen_state_controller.hub_overlay.visible = false
	if root.screen_state_controller.pause_overlay != null: root.screen_state_controller.pause_overlay.visible = false
	root.screen_state_controller.hub_opened_from_npc = false
	root.screen_state_controller.hub_pause_mode = false
	root.screen_state_controller.hub_is_root = true
	root.screen_state_controller.pause_page = 0
	root.screen_state_controller.pause_interact_input_was_down = false
	root.screen_state_controller.pause_cancel_input_was_down = false
	root.interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	root.screen_state_controller.set_state(&"gameplay")
	root.call("_play_sound", "ui_unpause", 0.0, 1.0)
	if was_pause:
		return


func update_hub_input(root: Object) -> void:
	root.screen_state_controller.update_hub_input(root)


func set_hub_page(root: Object, page: int) -> void:
	var screen: Object = root.screen_state_controller
	if page < 0:
		_set_screen_property_if_available(screen, &"hub_is_root", true)
		screen.hub_content_focus = false
		_set_equipment_mode(screen, EQUIPMENT_MODE_COMMAND)
		screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
		return
	_set_screen_property_if_available(screen, &"hub_is_root", false)
	screen.hub_page = posmod(page, HUB_PAGE_COUNT)
	var command_index: int = int(HUB_COMMAND_PAGE_TARGETS.find(screen.hub_page))
	if command_index >= 0: _set_screen_property_if_available(screen, &"hub_menu_row", command_index)
	screen.hub_item_index = 0
	screen.hub_list_scroll = 0.0
	screen.hub_choice_scroll = 0.0
	# Equipment has a deliberate three-step route. Entering the page always
	# lands on its top command row; Equip then descends into slots and finally
	# into the item list. Other transaction pages retain their normal content
	# focus behavior.
	var equipment_page: bool = screen.hub_page == HUB_PAGE_EQUIPMENT
	_set_screen_property_if_available(screen, &"hub_content_focus", equipment_page)
	_set_equipment_mode(screen, EQUIPMENT_MODE_COMMAND if equipment_page else EQUIPMENT_MODE_SLOT_EQUIP)
	_set_screen_property_if_available(screen, &"hub_action_column", 0)
	screen.hub_fusion_message = ""
	screen.hub_binding_message = ""
	screen.hub_fusion_count = 1
	if screen.hub_page == HUB_PAGE_FUSION:
		invalidate_hub_fusion_candidates(root)
	if root.run_state != null and screen.hub_page == HUB_PAGE_SHOP:
		root.run_state.ensure_shop_stock(root.player_profile)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	# Entering Equipment is a deliberate command-rail selection, so it gets the
	# confirm open tone rather than the quiet hover used for simple page turns.
	root.call("_play_sound", "ui_confirm" if equipment_page else "ui_hover", -6.0, 1.0)


func back_to_hub_root(root: Object) -> void:
	var screen: Object = root.screen_state_controller
	if screen.hub_is_root:
		close_hub_to_run(root)
		return
	screen.hub_is_root = true
	# Keep the page state consistent with the visible root. Otherwise Cancel
	# enters the stale submenu branch before the root-state branch can close the
	# hub, producing one or more phantom presses after nested menus.
	screen.hub_page = screen.HUB_PAGE_STATUS
	screen.hub_content_focus = false
	_set_equipment_mode(screen, EQUIPMENT_MODE_COMMAND)
	screen.hub_binding_message = ""
	screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func back_from_hub_route(root: Object) -> void:
	# The native footer BACK button must follow the same nested Equipment route
	# as controller/keyboard input. Previously it always jumped to the hub root,
	# which made touch navigation disagree with the visible menu hierarchy.
	var screen: Object = root.screen_state_controller
	if screen.hub_page == HUB_PAGE_EQUIPMENT:
		if screen.hub_equipment_mode == EQUIPMENT_MODE_REMOVE_ALL_CONFIRM:
			cancel_remove_all_hub_gear(root)
			return
		if screen.hub_gear_browsing:
			close_hub_gear_browse(root)
			return
		if not screen.hub_equipment_action_focus:
			_set_equipment_mode(screen, EQUIPMENT_MODE_COMMAND)
			screen.hub_content_focus = true
			screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
			root.call("_play_sound", "ui_decline", 0.0, 1.0)
			return
	back_to_hub_root(root)


func _set_screen_property_if_available(screen: Object, property_name: StringName, value: Variant) -> void:
	for property: Dictionary in screen.get_property_list():
		if StringName(str(property.get("name", ""))) == property_name:
			screen.set(property_name, value)
			return


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


func shift_hub_item(root: Object, direction: int) -> void:
	var count: int = 0
	if root.screen_state_controller.hub_page == 1 or root.screen_state_controller.is_pause_equipment_active():
		count = ItemCatalog.SLOTS.size()
	elif root.screen_state_controller.hub_page == 2:
		count = root.run_state.shop_stock.size() if root.run_state != null else 0
	elif root.screen_state_controller.hub_page == 3:
		count = hub_fusion_candidates(root).size()
		root.screen_state_controller.hub_fusion_count = 1
	if count > 0:
		var target := posmod(root.screen_state_controller.hub_item_index + direction, count)
		if root.player_profile != null and ItemCatalog.SLOTS[target] == &"head" and root.player_profile._head_locked_by_body(ItemCatalog.new()):
			target = posmod(target + (1 if direction >= 0 else -1), count)
		root.screen_state_controller.hub_item_index = target
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
	root.screen_state_controller.refresh_equipment_menu(root)


func select_hub_item_row(root: Object, row: int) -> void:
	var page: int = int(root.screen_state_controller.hub_page)
	if page != 2 and page != 3:
		return
	var count := 0
	if page == 2 and root.run_state != null:
		root.run_state.ensure_shop_stock(root.player_profile)
		count = root.run_state.shop_stock.size()
	elif page == 3:
		count = hub_fusion_candidates(root).size()
	if count <= 0:
		return
	var visible_rows := maxi(root.screen_state_controller.hub_item_row_buttons.size(), 1)
	var window_start := int(root.screen_state_controller.hub_list_scroll)
	var target := window_start + row
	if row < 0 or row >= visible_rows or target < 0 or target >= count:
		return
	root.screen_state_controller.hub_item_index = target
	root.screen_state_controller.hub_content_focus = true
	root.screen_state_controller.hub_equipment_action_focus = false
	if page == 3:
		root.screen_state_controller.hub_fusion_count = 1
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


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
	for data: Dictionary in root.player_profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		if catalog.definition_slot(item.definition_id) == slot: candidates.append(item)
	return candidates


func shift_hub_gear_candidate(root: Object, direction: int) -> void:
	if root.screen_state_controller.hub_page != 1 or not root.screen_state_controller.hub_gear_browsing: return
	var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var candidates := hub_gear_candidates(root, slot)
	if candidates.is_empty(): return
	var key := String(slot)
	root.screen_state_controller.hub_gear_candidate_indices[key] = posmod(int(root.screen_state_controller.hub_gear_candidate_indices.get(key, 0)) + direction, candidates.size())
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
	var row := current / columns
	column = posmod(column + column_direction, columns)
	row = posmod(row + row_direction, rows)
	var target := row * columns + column
	# A ragged final row wraps to its last real entry instead of selecting an
	# empty cell in the two-column candidate grid.
	if target >= candidates.size():
		target = candidates.size() - 1
	root.screen_state_controller.hub_gear_candidate_indices[key] = target
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
	root.screen_state_controller.hub_content_focus = true
	var remove_mode: bool = root.screen_state_controller.hub_equipment_mode == EQUIPMENT_MODE_SLOT_REMOVE
	_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_REMOVE if remove_mode else EQUIPMENT_MODE_SLOT_EQUIP)
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
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)


func select_hub_gear_candidate(root: Object, choice_row: int) -> void:
	if (root.screen_state_controller.hub_page != 1 and not root.screen_state_controller.is_pause_equipment_active()) or not root.screen_state_controller.hub_gear_browsing:
		return
	var selected_slot_index := clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var slot: StringName = ItemCatalog.SLOTS[selected_slot_index]
	var candidates := hub_gear_candidates(root, slot)
	if candidates.is_empty():
		return
	var visible_choice_count := 8 if root.screen_state_controller.hub_equipment_menu != null else maxi(root.screen_state_controller.hub_gear_choice_buttons.size(), 1)
	var window_start := int(root.screen_state_controller.hub_choice_scroll)
	var candidate_index := window_start + choice_row
	if choice_row < 0 or choice_row >= visible_choice_count or candidate_index < 0 or candidate_index >= candidates.size():
		return
	# A touch row is an explicit selection, so commit it immediately. Controller
	# navigation still keeps the browse-then-accept flow for precise selection.
	root.screen_state_controller.hub_gear_candidate_indices[String(slot)] = candidate_index
	hub_item_action(root)


func close_hub_gear_browse(root: Object) -> void:
	# BACK from the item list returns to the slot list, not the top command row.
	_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_EQUIP)
	root.screen_state_controller.refresh_equipment_menu(root)
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func refresh_hub_fusion_candidates(root: Object) -> void:
	root.screen_state_controller.hub_fusion_candidates.clear()
	root.screen_state_controller.hub_fusion_candidates_dirty = false
	if root.player_profile == null: return
	var catalog := ItemCatalog.new()
	for data: Dictionary in root.player_profile.inventory:
		var item := ItemInstance.from_dictionary(data)
		if root.player_profile.fusion_material_count(item.instance_id, catalog) > 0 or root.player_profile.can_salvage_overflow(item.instance_id, catalog):
			root.screen_state_controller.hub_fusion_candidates.append(item)


func invalidate_hub_fusion_candidates(root: Object) -> void:
	root.screen_state_controller.hub_fusion_candidates_dirty = true


func hub_fusion_candidates(root: Object) -> Array[ItemInstance]:
	if root.screen_state_controller.hub_fusion_candidates_dirty:
		refresh_hub_fusion_candidates(root)
	return root.screen_state_controller.hub_fusion_candidates


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
	var candidates := hub_fusion_candidates(root)
	if candidates.is_empty(): return
	var index: int = clampi(root.screen_state_controller.hub_item_index, 0, candidates.size() - 1)
	var target: ItemInstance = candidates[index]
	if root.player_profile.can_salvage_overflow(target.instance_id): return
	var material_count: int = root.player_profile.fusion_material_count(target.instance_id)
	if material_count <= 0: return
	root.screen_state_controller.hub_fusion_count = clampi(int(root.screen_state_controller.hub_fusion_count) + direction, 1, material_count)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func salvage_profile_overflow(root: Object, instance_id: String) -> int:
	if root.player_profile == null: return 0
	var value: int = root.player_profile.salvage_overflow(instance_id)
	if value <= 0: return 0
	invalidate_hub_fusion_candidates(root)
	root.call("_save_player_profile")
	root.call("_update_gold_indicator")
	return value


func hub_item_action(root: Object) -> void:
	if root.player_profile == null: return
	if root.screen_state_controller.hub_page == 1 or root.screen_state_controller.is_pause_equipment_active():
		# The visible EQUIP command is a route transition. It must not silently
		# select the first slot or open an item picker beneath the command row.
		if root.screen_state_controller.hub_equipment_mode == EQUIPMENT_MODE_COMMAND or root.screen_state_controller.hub_equipment_action_focus:
			_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_EQUIP)
			root.screen_state_controller.hub_content_focus = true
			root.screen_state_controller.hub_item_index = clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
			root.screen_state_controller.refresh_equipment_menu(root)
			root.call("_play_sound", "ui_confirm", 0.0, 1.0)
			return
		var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var candidates := hub_gear_candidates(root, slot)
		if not candidates.is_empty():
			var candidate_index: int = posmod(int(root.screen_state_controller.hub_gear_candidate_indices.get(String(slot), 0)), candidates.size())
			if root.screen_state_controller.hub_equipment_mode != EQUIPMENT_MODE_CANDIDATE and not root.screen_state_controller.hub_gear_browsing:
				var equipped_id: String = root.player_profile.get_equipped_instance_id(slot)
				for index in candidates.size():
					if candidates[index].instance_id == equipped_id:
						root.screen_state_controller.hub_gear_candidate_indices[String(slot)] = index
						break
				_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_CANDIDATE)
			else:
				var selected: ItemInstance = candidates[candidate_index]
				var equipped_id: String = root.player_profile.get_equipped_instance_id(slot)
				if selected.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID or (slot == &"shield" and selected.instance_id == equipped_id):
					root.call("_unequip_profile_slot", slot)
				else:
					root.call("_equip_profile_item", selected.instance_id)
				# Equipping or unequipping changes which copies may be used as
				# materials, so the cached target list must be rebuilt.
				invalidate_hub_fusion_candidates(root)
				# Confirming an item returns to the slot list. The selected slot and
				# candidate cursor are preserved for quick successive changes.
				_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_EQUIP)
			root.screen_state_controller.refresh_equipment_menu(root)
		return
	elif root.screen_state_controller.hub_page == 2 and root.run_state != null and not root.run_state.shop_stock.is_empty():
		var index: int = clampi(root.screen_state_controller.hub_item_index, 0, root.run_state.shop_stock.size() - 1)
		var entry: Dictionary = root.run_state.shop_stock[index]
		if bool(entry.get("permanent", false)):
			# Demon Cloak: always in stock, never sold out, price escalates per purchase.
			var cloak_item := root.player_profile.purchase_demon_cloak() as ItemInstance
			if cloak_item != null:
				var cloak_catalog := ItemCatalog.new()
				var body_was_empty := cloak_catalog.slot_needs_introduction(root.player_profile, &"body")
				if root.run_state != null:
					root.run_state.record_gear_reward(&"shop", cloak_item, root.player_profile.difficulty_rank, root.player_profile.level, -1, "", body_was_empty, false, &"purchased")
				entry["price"] = root.player_profile.demon_cloak_price()
				root.run_state.shop_stock[index] = entry; invalidate_hub_fusion_candidates(root); root.call("_save_player_profile"); root.call("_update_gold_indicator"); root.call("_play_sound", "ui_confirm", 0.0, 1.0); root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
			else:
				root.call("_play_sound", "ui_denied", 0.0, 1.0)
		elif not bool(entry.get("sold", false)):
			var item := ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary)
			var catalog := ItemCatalog.new()
			var slot_was_empty := catalog.slot_needs_introduction(root.player_profile, catalog.definition_slot(item.definition_id))
			if root.player_profile.purchase_item(item, int(entry.get("price", 0))):
				if root.run_state != null:
					root.run_state.record_gear_reward(&"shop", item, root.player_profile.difficulty_rank, root.player_profile.level, -1, "", slot_was_empty, false, &"purchased")
				entry["sold"] = true; root.run_state.shop_stock[index] = entry; invalidate_hub_fusion_candidates(root); root.call("_save_player_profile"); root.call("_update_gold_indicator"); root.call("_play_sound", "ui_confirm", 0.0, 1.0); root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
			else:
				root.call("_play_sound", "ui_denied", 0.0, 1.0)
	elif root.screen_state_controller.hub_page == 3:
		var fusion_candidates := hub_fusion_candidates(root)
		if not fusion_candidates.is_empty():
			var index: int = clampi(root.screen_state_controller.hub_item_index, 0, fusion_candidates.size() - 1)
			var target: ItemInstance = fusion_candidates[index]
			if root.player_profile.fusion_material_count(target.instance_id) > 0:
				var material_count: int = root.player_profile.fusion_material_count(target.instance_id)
				var count: int = clampi(int(root.screen_state_controller.hub_fusion_count), 1, material_count)
				var batch_cost: int = root.player_profile.fusion_batch_cost(target, count)
				if root.player_profile.souls < batch_cost:
					root.screen_state_controller.hub_fusion_message = "NEED %dS" % batch_cost
					root.call("_play_sound", "ui_denied", 0.0, 1.0)
				else:
					var family_name := str(ItemCatalog.DEFINITIONS.get(target.definition_id, {}).get("name", "ITEM"))
					if fuse_profile_target(root, target.instance_id, count):
						root.screen_state_controller.hub_fusion_message = "%s ENHANCED" % family_name
						root.call("_play_sound", "ui_confirm", 0.0, 1.0)
						root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
			elif root.player_profile.can_salvage_overflow(target.instance_id):
				var salvage_value: int = salvage_profile_overflow(root, target.instance_id)
				if salvage_value > 0:
					root.screen_state_controller.hub_fusion_message = "SALVAGED %dG" % salvage_value
					root.call("_play_sound", "ui_buy_sell", -16.0, 1.0)
			if not root.screen_state_controller.hub_fusion_message.is_empty():
				invalidate_hub_fusion_candidates(root)
				root.screen_state_controller.hub_item_index = clampi(root.screen_state_controller.hub_item_index, 0, maxi(hub_fusion_candidates(root).size() - 1, 0))
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func remove_hub_gear(root: Object) -> void:
	if root.player_profile == null or (root.screen_state_controller.hub_page != root.screen_state_controller.HUB_PAGE_EQUIPMENT and not root.screen_state_controller.is_pause_equipment_active()):
		return
	if root.screen_state_controller.hub_equipment_mode == EQUIPMENT_MODE_COMMAND or root.screen_state_controller.hub_equipment_action_focus:
		# REMOVE descends into the same six-panel slot grid as EQUIP. A second
		# confirm on a slot performs the actual unequip.
		_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_REMOVE)
		root.screen_state_controller.hub_content_focus = true
		root.screen_state_controller.refresh_equipment_menu(root)
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		return
	var slot: StringName = ItemCatalog.SLOTS[clampi(root.screen_state_controller.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
	if bool(root.call("_unequip_profile_slot", slot)):
		_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_SLOT_REMOVE)
		invalidate_hub_fusion_candidates(root)
		root.call("_save_player_profile")
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	root.screen_state_controller.refresh_equipment_menu(root)


func remove_all_hub_gear(root: Object) -> void:
	if root.player_profile == null or (root.screen_state_controller.hub_page != root.screen_state_controller.HUB_PAGE_EQUIPMENT and not root.screen_state_controller.is_pause_equipment_active()):
		return
	if root.screen_state_controller.hub_equipment_mode == EQUIPMENT_MODE_COMMAND or root.screen_state_controller.hub_equipment_action_focus:
		_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_REMOVE_ALL_CONFIRM)
		root.screen_state_controller.hub_remove_all_confirm_index = 1
		root.screen_state_controller.hub_content_focus = true
		root.screen_state_controller.refresh_equipment_menu(root)
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		return
	var changed := false
	for slot in ItemCatalog.SLOTS:
		changed = bool(root.call("_unequip_profile_slot", slot)) or changed
	_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	root.screen_state_controller.hub_action_column = 2
	if changed:
		invalidate_hub_fusion_candidates(root)
		root.call("_save_player_profile")
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	root.screen_state_controller.refresh_equipment_menu(root)


func cancel_remove_all_hub_gear(root: Object) -> void:
	if root.screen_state_controller.hub_page != root.screen_state_controller.HUB_PAGE_EQUIPMENT and not root.screen_state_controller.is_pause_equipment_active():
		return
	_set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	root.screen_state_controller.hub_action_column = 2
	root.screen_state_controller.refresh_equipment_menu(root)
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func select_hub_menu_row(root: Object, row: int) -> void:
	root.screen_state_controller.hub_menu_row = posmod(row, 6)
	root.screen_state_controller.hub_content_focus = false
	root.screen_state_controller.hub_equipment_action_focus = false
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func select_hub_stat_row(root: Object, row: int) -> void:
	if root.screen_state_controller.hub_page != root.screen_state_controller.HUB_PAGE_ALLOCATE:
		return
	root.screen_state_controller.hub_stat_row = posmod(row, 6)
	root.screen_state_controller.hub_content_focus = true
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


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
	if root.player_profile == null: return
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	ProgressionControllerScript.allocate_stats(root.player_profile, {"VIT": root.screen_state_controller.hub_pending_vit, "STR": root.screen_state_controller.hub_pending_str, "DEF": root.screen_state_controller.hub_pending_def, "AGI": root.screen_state_controller.hub_pending_agi, "INT": root.screen_state_controller.hub_pending_int, "MND": root.screen_state_controller.hub_pending_mnd})
	root.screen_state_controller.hub_pending_vit = 0; root.screen_state_controller.hub_pending_str = 0; root.screen_state_controller.hub_pending_def = 0; root.screen_state_controller.hub_pending_agi = 0; root.screen_state_controller.hub_pending_int = 0; root.screen_state_controller.hub_pending_mnd = 0
	root.call("_apply_profile_to_runtime"); root.call("_apply_player_level"); root.call("_sync_runtime_progression_to_profile")
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_cancel_stats(root: Object) -> void:
	root.screen_state_controller.hub_pending_vit = 0; root.screen_state_controller.hub_pending_str = 0; root.screen_state_controller.hub_pending_def = 0; root.screen_state_controller.hub_pending_agi = 0; root.screen_state_controller.hub_pending_int = 0; root.screen_state_controller.hub_pending_mnd = 0
	if root.screen_state_controller != null and root.screen_state_controller.hub_overlay != null: root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func hub_auto_allocate(root: Object) -> void:
	if root.player_profile == null: return
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
	hub_cancel_stats(root)
	if int(root.call("_respec_player_stats")) > 0: root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func start_from_hub(root: Object) -> void:
	if root.screen_state_controller.hub_opened_from_npc:
		root.call("_close_hub_to_run")
		return
	if root.screen_state_controller.hub_overlay != null: root.screen_state_controller.hub_overlay.visible = false
	if root.player_profile != null:
		root.player_profile.open_hub_on_load = false
		root.player_profile.pending_route = "run"
		root.call("_save_player_profile")
	root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	root.call("_begin_scene_transition")
