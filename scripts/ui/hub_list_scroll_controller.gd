extends RefCounted
class_name HubListScrollController

## Owns fractional scrolling and cursor tween cleanup for legacy Hub lists.
var screen: ScreenStateController

func bind(owner: Variant) -> void:
	screen = owner

# --- Hub-list scrolling and cursor tween cleanup ---
func scroll_hub_content(root: Object, delta_px: float) -> void:
	var equipment_active: Variant = screen.hub_page == screen.HUB_PAGE_EQUIPMENT or screen.is_pause_equipment_active()
	if is_zero_approx(delta_px) or (screen.hub_page < 0 and not equipment_active):
		return
	var pitch := 9.0 if equipment_active and screen.hub_equipment_menu != null else 10.0
	var count: Variant = screen._hub_active_list_count(root)
	if count <= 0:
		return
	if equipment_active and screen.hub_gear_browsing:
		var equipment_scroll_count := 8 if screen.hub_equipment_menu != null else maxi(screen.hub_gear_choice_texts.size(), 1)
		var max_start := EquipmentMenuLayout.candidate_max_scroll(count) if screen.hub_equipment_menu != null else maxi(0, count - equipment_scroll_count)
		screen.hub_choice_scroll = clampf(screen.hub_choice_scroll - delta_px / pitch, 0.0, float(max_start))
		# A drag can move the visible window without changing the selected
		# candidate. Disarm the touch confirmation so a later tap cannot commit
		# an item the player has not just previewed in the current window.
		screen.hub_touch_candidate_slot = ""
		screen.hub_touch_candidate_index = -1
	else:
		# The authored Shop scene has eight visible rows; the legacy presenter keeps
		# its compatibility rows for other routes. Match the active presenter so a
		# drag never leaves the selected row below the visible shop window.
		var list_scroll_count: Variant = screen.ShopMenuLayoutScript.VISIBLE_ROWS if screen.hub_page == screen.HUB_PAGE_SHOP and screen.hub_shop_menu != null else screen.FusionMenuLayoutScript.FUSION_VISIBLE_ROWS if screen.hub_page == screen.HUB_PAGE_FUSION and screen.hub_fusion_menu != null else maxi(screen.hub_item_list_texts.size(), 1)
		screen.hub_list_scroll = clampf(screen.hub_list_scroll - delta_px / pitch, 0.0, maxf(0.0, float(count - list_scroll_count)))
		if screen.hub_page == screen.HUB_PAGE_SHOP:
			screen.hub_shop_sell_confirm_pending = false


func _hub_active_list_count(root: Object) -> int:
	if screen.hub_page == screen.HUB_PAGE_SHOP:
		var run_state := root.get("run_state") as RunState
		if screen.hub_shop_sell_mode:
			var profile := root.get("player_profile") as PlayerProfile
			if profile == null:
				return 0
			var count := 0
			for data: Dictionary in profile.inventory:
				var item := ItemInstance.from_dictionary(data)
				if not profile.equipped_instance_ids.values().has(item.instance_id):
					count += 1
			return count
		if run_state == null:
			return 0
		run_state.ensure_shop_stock(root.get("player_profile"))
		return run_state.shop_stock.size()
	if screen.hub_page == screen.HUB_PAGE_FUSION:
		return (root.call("_hub_fusion_candidates") as Array).size()
	if (screen.hub_page == screen.HUB_PAGE_EQUIPMENT or screen.is_pause_equipment_active()) and screen.hub_gear_browsing:
		var selected_slot := ItemCatalog.SLOTS[clampi(screen.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		return (root.call("_hub_gear_candidates", selected_slot) as Array).size()
	return 0


## Controller/confirm selection changes re-center the content so the selected
## row stays visible; touch drags leave the cursor where it is.
func snap_hub_list_scroll_to_selection(root: Object) -> void:
	if (screen.hub_page == screen.HUB_PAGE_EQUIPMENT or screen.is_pause_equipment_active()) and screen.hub_gear_browsing:
		var selected_slot := ItemCatalog.SLOTS[clampi(screen.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var candidates := root.call("_hub_gear_candidates", selected_slot) as Array
		var current_index := int(screen.hub_gear_candidate_indices.get(String(selected_slot), 0))
		var equipment_visible_count := 8 if screen.hub_equipment_menu != null else maxi(screen.hub_gear_choice_texts.size(), 1)
		var max_start := EquipmentMenuLayout.candidate_max_scroll(candidates.size()) if screen.hub_equipment_menu != null else maxi(0, candidates.size() - equipment_visible_count)
		var start := current_index - 2 if screen.hub_equipment_menu != null else current_index - 1
		if screen.hub_equipment_menu != null: start -= start % 2
		screen.hub_choice_scroll = clampf(float(start), 0.0, float(max_start))
		return
	var count: Variant = screen._hub_active_list_count(root)
	if count <= 0:
		return
	var list_visible_count: Variant = screen.ShopMenuLayoutScript.VISIBLE_ROWS if screen.hub_page == screen.HUB_PAGE_SHOP and screen.hub_shop_menu != null else screen.FusionMenuLayoutScript.FUSION_VISIBLE_ROWS if screen.hub_page == screen.HUB_PAGE_FUSION and screen.hub_fusion_menu != null else maxi(screen.hub_item_list_texts.size(), 1)
	# Controller browsing keeps the viewport fixed until the selection crosses
	# an edge: moving down past the final visible row advances the window, while
	# moving up past the first visible row retreats it. This prevents the list
	# from drifting as soon as the cursor moves away from the bottom.
	var max_scroll := maxf(0.0, float(count - list_visible_count))
	var window_start := int(floor(screen.hub_list_scroll))
	if screen.hub_item_index >= window_start + list_visible_count:
		window_start = screen.hub_item_index - list_visible_count + 1
	elif screen.hub_item_index < window_start:
		window_start = screen.hub_item_index
	screen.hub_list_scroll = clampf(float(window_start), 0.0, max_scroll)


## Applies the fractional item-list scroll to the row/button/price y positions.
func _apply_hub_item_scroll(pitch: float) -> void:
	screen._hub_legacy_widget_scroll_presenter.position_item_rows(screen._hub_responsive_layout_presenter, screen.hub_list_scroll, pitch)


## Applies the fractional gear-choice scroll to the picker row positions.
func _apply_hub_choice_scroll(pitch: float) -> void:
	screen._hub_legacy_widget_scroll_presenter.position_gear_choices(screen._hub_responsive_layout_presenter, screen.hub_choice_scroll, pitch)


## Resting idle for the hand cursor: it glides a few pixels to the right, then
## quickly flicks back left, looping forever. Horizontal only.
func _start_cursor_bob(cursor: Sprite2D) -> void:
	screen._menu_cursor_animator.start_cursor_bob(cursor, screen)


func _kill_cursor_tween(cursor: Sprite2D) -> void:
	screen._menu_cursor_animator.kill_cursor_tween(cursor)
