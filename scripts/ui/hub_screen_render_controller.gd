extends RefCounted
class_name HubScreenRenderController

# Owner: ScreenStateController composition; coordinates Hub page presentation.
## Owns the Hub frame-to-view projection. ScreenStateController remains the
## stable public route and supplies the typed state and view collaborators.
var owner: ScreenStateController
const MenuPromptTextureFactoryScript = preload("res://scripts/ui/menu_prompt_texture_factory.gd")
const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")

func bind(screen: Node) -> void:
	owner = screen as ScreenStateController
const ASPECT_CATALOG_SCRIPT = preload("res://scripts/content/aspect_catalog.gd")
const SoulVisualsScript = preload("res://scripts/runtime/services/soul_visuals.gd")
const ShopMenuLayoutScript = preload("res://scripts/ui/shop_menu_layout.gd")
const BindMenuModelScript = preload("res://scripts/ui/bind_menu_model.gd")
const MENU_CIRCLE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_CIRCLE_TEXTURE
const CURSOR_LEFT_GAP := 10.0
const HUB_ITEM_DETAIL_TOP := 105.0
const HUB_ITEM_DETAIL_PITCH := 7.0
const HUB_GEAR_BROWSE_DETAIL_TOP := 136.0
const HUB_ITEM_TEXT_WRAP_LENGTH := 34
const HUB_PAGE_ALLOCATE := HubMenuStateScript.HUB_PAGE_ALLOCATE
const HUB_PAGE_EQUIPMENT := HubMenuStateScript.HUB_PAGE_EQUIPMENT
const HUB_PAGE_SHOP := HubMenuStateScript.HUB_PAGE_SHOP
const HUB_PAGE_FUSION := HubMenuStateScript.HUB_PAGE_FUSION
const HUB_PAGE_BIND := HubMenuStateScript.HUB_PAGE_BIND
const HUB_PAGE_STATUS := HubMenuStateScript.HUB_PAGE_STATUS

func update_hub_ui(root: GameplayState, pixel_texture: Callable) -> void:
	var profile := root.player_profile
	if profile == null: return
	# Fusion is a child of the shared Items page, so page-root visibility alone
	# cannot hide it when another route returns early below (notably BIND).
	# Reset this before any page-specific branch to prevent presenter bleed.
	owner._hub_page_visibility_presenter.prepare_fusion_visibility(owner.hub_page, owner.hub_fusion_menu)
	owner._reset_hub_cursor_layer()
	# The reworked hub keeps its title/command shell on screen while the
	# selected command previews its content underneath. Entering a command only
	# changes focus; it no longer swaps away the top shell.
	if owner.hub_page == HUB_PAGE_STATUS:
		# STATUS no longer has a hub presenter. Normalize direct legacy writes to
		# the merged STATS route before any visibility or input decision.
		owner.hub_page = HUB_PAGE_ALLOCATE
	owner._hub_page_visibility_presenter.show_page(owner.hub_overlay, owner.hub_page)
	_update_player_card(root._menu_player_context(), pixel_texture, owner.hub_player_card_texts)
	# The previous root card is no longer part of the hub rework. Keep its data
	# refreshed for compatibility callers, but never let it draw over the live
	# command preview in HubContentPanel.
	if owner.hub_player_card_panel != null: owner.hub_player_card_panel.visible = false
	for card_text in owner.hub_player_card_texts: card_text.visible = false
	var page := owner.hub_page
	var equipment_view_active := owner._hub_page_visibility_presenter.update_transaction_menu_visibility(
		page,
		owner.hub_content_focus,
		owner.hub_is_root,
		owner.hub_equipment_menu,
		owner.hub_shop_menu,
		owner.hub_fusion_menu,
		owner.hub_back_button,
		pixel_texture
	)
	# Page changes alter the height of the shared inventory card (Equipment uses
	# six compact slot rows; Shop/Fusion use the larger inventory rows).
	owner._position_hub_controls()
	var page_buttons := owner.hub_page_buttons
	var highlight_color := PaletteLibrary.accent(owner.player_palette_name)
	highlight_color = root._health_feedback_color(owner.player_palette_name)
	for page_index in page_buttons.size():
		page_buttons[page_index].visible = true
		page_buttons[page_index].mouse_filter = Control.MOUSE_FILTER_STOP
		# The command rail is pure navigation: the hand cursor marks the selected
		# command. No box or text highlight may draw around a command, matching the
		# mockup where only the cursor indicates selection.
		owner.set_archetype_button_state(page_buttons[page_index], false, highlight_color)
		owner._set_menu_button_icon(page_buttons[page_index], null, false)
	# The command cursor stays as a dimmed breadcrumb while a nested route is open.
	owner._hub_command_shell_presenter.update_cursor_for_page(
		page,
		owner.hub_menu_row,
		owner.hub_is_root,
		owner._menu_cursor_animator,
		owner as Node
	)
	owner._hub_stats_interaction_presenter.update_cursor_for_page(
		owner._hub_stats_presenter,
		page,
		owner.hub_content_focus,
		owner.hub_stat_row,
		owner.hub_action_column,
		owner.display_view_size,
		owner._menu_cursor_animator,
		owner as Node
	)
	var title := owner.hub_root_page.get_node_or_null("Title") as Sprite2D if owner.hub_root_page != null else null
	if title != null:
		var title_texture := pixel_texture.call("DEMON HUB", Color.WHITE) as Texture2D
		title.texture = title_texture
	if owner.hub_points_text != null: owner.hub_points_text.visible = page == HUB_PAGE_ALLOCATE
	var confirm_prompt := owner._menu_confirm_prompt_for(root)
	if page == HUB_PAGE_EQUIPMENT:
		confirm_prompt = confirm_prompt.replace("SELECT", "EQUIP")
	var back_prompt := owner._menu_back_prompt_for(root)
	var confirm_prompt_texture := owner._pixel_prompt_texture(pixel_texture, confirm_prompt, Color.WHITE) as Texture2D
	var back_prompt_texture := owner._pixel_prompt_texture(pixel_texture, back_prompt, Color.WHITE) as Texture2D
	owner._hub_responsive_layout_presenter.update_footer_content(
		page,
		equipment_view_active,
		confirm_prompt_texture,
		back_prompt_texture,
		pixel_texture
	)
	if owner.hub_currency_text != null:
		# Legacy single-currency alias: the visible footer now has both rows.
		owner.hub_currency_text.visible = false
		owner.hub_currency_text.texture = null
	if owner.hub_gold_text != null:
		owner.hub_gold_text.visible = true
		owner.hub_gold_text.texture = pixel_texture.call(str(profile.gold), Color8(255, 205, 117)) as Texture2D
	if owner.hub_soul_text != null:
		owner.hub_soul_text.visible = true
		owner.hub_soul_text.texture = pixel_texture.call(str(profile.souls), SoulVisualsScript.SOUL_HIGHLIGHT_COLOR) as Texture2D
	if owner.hub_gold_icon != null: owner.hub_gold_icon.visible = true
	if owner.hub_soul_icon != null: owner.hub_soul_icon.visible = true
	# The counts are regenerated above, so their widths can change (for example
	# when a player reaches a new digit). Re-apply the right edge anchor after the
	# textures exist instead of leaving a newly widened number one pixel off.
	owner._position_hub_controls()
	owner._hub_stats_interaction_presenter.update_page_visibility(
		owner._hub_stats_presenter,
		page,
		owner.hub_is_root,
		owner.hub_content_focus,
		owner.hub_stat_row
	)
	_update_hub_item_visibility(profile, page, highlight_color)
	if owner.hub_binding_panel != null: owner.hub_binding_panel.visible = page == HUB_PAGE_BIND
	for node in owner.hub_binding_texts: node.visible = page == HUB_PAGE_BIND
	if owner.hub_binding_action_button != null:
		owner.hub_binding_action_button.visible = page == HUB_PAGE_BIND and not owner.hub_is_root
		owner.hub_binding_action_button.mouse_filter = Control.MOUSE_FILTER_STOP if owner.hub_content_focus else Control.MOUSE_FILTER_IGNORE
	if owner.hub_bind_menu != null:
		owner.hub_bind_menu.visible = page == HUB_PAGE_BIND
		if page != HUB_PAGE_BIND and owner.hub_bind_menu.has_method("stop_cursor_motion"):
			owner.hub_bind_menu.call("stop_cursor_motion")
	if page == HUB_PAGE_BIND:
		if owner.hub_binding_panel != null: owner.hub_binding_panel.visible = false
		for node in owner.hub_binding_texts: node.visible = false
		if owner.hub_binding_action_button != null:
			owner.hub_binding_action_button.visible = false
			owner.hub_binding_action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if owner.hub_bind_menu != null:
			owner.hub_bind_menu.visible = true
			_render_bind_menu(root, pixel_texture, profile, highlight_color)
			return
		_update_hub_binding_page(root, pixel_texture, profile, highlight_color)
		return
	if page == HUB_PAGE_STATUS:
		_update_hub_status_page(root, pixel_texture, profile, highlight_color)
		return
	if page == HUB_PAGE_EQUIPMENT and owner.hub_equipment_menu != null:
		# Keep the legacy arrays populated for existing callers, but never leave
		# the old inventory presenter visible underneath the authored scene. Its
		# cursors are always hidden by the reset at the top of this render.
		owner._hide_legacy_equipment_presenter()
		for cursor in [owner.hub_list_cursor, owner.hub_slot_cursor, owner.hub_choice_cursor]:
			if cursor != null: cursor.visible = false
		_render_equipment_menu(root, pixel_texture, profile, highlight_color)
		return
	if page == HUB_PAGE_SHOP and owner.hub_shop_menu != null:
		owner._hide_legacy_shop_presenter()
		_render_shop_menu(root, pixel_texture, profile, highlight_color)
		return
	if owner.hub_fusion_menu != null:
		owner.hub_fusion_menu.visible = page == HUB_PAGE_FUSION
		if page != HUB_PAGE_FUSION and owner.hub_fusion_menu.has_method("stop_cursor_motion"):
			owner.hub_fusion_menu.call("stop_cursor_motion")
	if page == HUB_PAGE_FUSION and owner.hub_fusion_menu != null:
		owner._hide_legacy_shop_presenter()
		_render_fusion_menu(root, pixel_texture, profile)
		return
	if page != HUB_PAGE_ALLOCATE:
		owner._hub_legacy_inventory_presenter._update_hub_item_page(root, pixel_texture, profile, page, owner.hub_item_list_texts, owner.hub_item_detail_texts, owner.hub_item_action_button, highlight_color)
		return
	_update_hub_allocation_page(root, pixel_texture, profile, highlight_color)

func _render_fusion_menu(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile) -> void:
	if owner.hub_fusion_menu == null or profile == null:
		return
	var view := owner.hub_fusion_menu
	var context := owner._hub_transaction_menu_context
	context.profile = profile
	context.catalog = ItemCatalog.new()
	context.fusion_candidates = root._hub_fusion_candidates()
	context.fusion_state = 0 if owner.hub_is_root else owner.hub_fusion_state
	context.fusion_item_selected = owner.hub_fusion_item_selected
	context.selected_index = owner.hub_item_index
	context.scroll = owner.hub_list_scroll
	context.fusion_count = owner.hub_fusion_count
	context.fusion_message = owner.hub_fusion_message
	context.fusion_details.clear()
	if not context.fusion_candidates.is_empty():
		var selected := context.fusion_candidates[clampi(owner.hub_item_index, 0, context.fusion_candidates.size() - 1)]
		var economy := root.hub_flow_controller.get("economy_controller") as RefCounted
		context.fusion_details = economy.call("fusion_candidate_details", root, selected) as Dictionary
	var model := owner._hub_transaction_menu_presenter.build_fusion_model(context)
	view.call("set_pixel_texture", pixel_texture)
	view.call("render_fusion", model)

func _fusion_item_label(catalog: ItemCatalog, profile: PlayerProfile, item: ItemInstance) -> String:
	return owner._hub_transaction_menu_presenter.fusion_item_label(catalog, profile, item)

func _render_bind_menu(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, highlight_color: Color) -> void:
	if owner.hub_bind_menu == null or profile == null:
		return
	var view := owner.hub_bind_menu
	var model := BindMenuModelScript.new()
	model.state = 0 if owner.hub_is_root else owner.hub_binding_state
	var chroma := root.player_chroma_component
	var current_aspect := chroma.call("aspect_name") as StringName if chroma != null else &"gray"
	model.current_element = ASPECT_CATALOG_SCRIPT.display_name(current_aspect)
	model.current_is_bound = profile.has_bound_element and profile.bound_element == current_aspect
	model.bound_element = ASPECT_CATALOG_SCRIPT.display_name(profile.bound_element) if profile.has_bound_element else "NONE"
	model.soul_count = profile.souls
	model.bind_cost = PlayerProfile.ELEMENT_BIND_SOUL_COST
	model.can_bind = current_aspect != &"gray" and profile.can_bind_element(current_aspect) and not model.current_is_bound and profile.souls >= model.bind_cost
	model.action_label = "BIND" if not model.current_is_bound else "BOUND"
	model.action_color = highlight_color
	model.status_message = owner.hub_binding_message
	if model.status_message.is_empty():
		model.status_message = "READY TO BIND" if model.can_bind else "BIND UNAVAILABLE"
	view.call("set_pixel_texture", pixel_texture)
	view.call("render", model)

func _render_shop_menu(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, _highlight_color: Color) -> void:
	if owner.hub_shop_menu == null or profile == null:
		return
	var view := owner.hub_shop_menu
	var context := owner._hub_transaction_menu_context
	context.profile = profile
	context.catalog = ItemCatalog.new()
	context.sell_mode = owner.hub_shop_sell_mode
	context.state = owner.hub_shop_state
	context.items.clear()
	context.prices.clear()
	context.soul_values.clear()
	context.sold_flags.clear()
	context.item_slots.clear()
	context.sell_owned_counts.clear()
	if context.sell_mode:
		context.items = root._hub_shop_sellable_items()
		for item: ItemInstance in context.items:
			context.item_slots.append(context.catalog.definition_slot(item.definition_id))
			context.prices.append("%d" % context.catalog.sell_value(item))
			context.soul_values.append(context.catalog.sell_soul_value(item))
			context.sold_flags.append(false)
			context.sell_owned_counts.append(root._hub_shop_owned_matching_count(item))
	else:
		var run_state := root.run_state
		if run_state != null:
			run_state.ensure_shop_stock(profile)
			for entry: Dictionary in run_state.shop_stock:
				var item := ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary)
				context.items.append(item)
				context.item_slots.append(context.catalog.definition_slot(item.definition_id))
				var sold := bool(entry.get("sold", false))
				context.sold_flags.append(sold)
				context.prices.append("SOLD" if sold else "%d" % int(entry.get("price", 0)))
				context.soul_values.append(0)
				context.sell_owned_counts.append(0)
	var count := context.items.size()
	context.selected_index = clampi(owner.hub_item_index, 0, maxi(count - 1, 0))
	owner.hub_item_index = context.selected_index
	context.scroll = clampf(owner.hub_list_scroll, 0.0, float(maxi(0, count - ShopMenuLayoutScript.VISIBLE_ROWS)))
	owner.hub_list_scroll = context.scroll
	context.owned_count = 0
	context.max_quantity = 1
	context.quantity = owner.hub_shop_sell_amount
	context.batch_value.clear()
	if count > 0:
		var selected_item := context.items[context.selected_index]
		if context.sell_mode:
			context.owned_count = root._hub_shop_owned_matching_count(selected_item)
			context.max_quantity = maxi(context.owned_count, 1)
		else:
			for data: Dictionary in profile.inventory:
				if ItemInstance.from_dictionary(data).inventory_stack_key() == selected_item.inventory_stack_key():
					context.owned_count += 1
		if context.sell_mode and owner.hub_shop_state == ShopMenuLayoutScript.SELL_AMOUNT:
			context.batch_value = root._hub_shop_batch_value(selected_item, clampi(context.quantity, 1, maxi(context.owned_count, 1)))
	var model := owner._hub_transaction_menu_presenter.build_shop_model(context)
	owner.hub_shop_sell_amount = model.quantity
	owner.hub_shop_sell_amount_max = model.max_quantity
	view.call("render_model", model, pixel_texture)


# --- Hub page and player-card rendering ---

func _update_hub_item_visibility(profile: PlayerProfile, page: int, highlight_color: Color) -> void:
	var context := owner._hub_item_visibility_context
	context.profile = profile
	context.page = page
	context.content_focus = owner.hub_content_focus
	context.is_root = owner.hub_is_root
	context.equipment_action_focus = owner.hub_equipment_action_focus
	context.gear_browsing = owner.hub_gear_browsing
	context.item_index = owner.hub_item_index
	context.action_column = owner.hub_action_column
	context.shop_command_focus = owner.hub_shop_command_focus
	context.highlight_color = highlight_color
	owner._hub_item_visibility_presenter.update(context)

func _update_hub_allocation_page(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, highlight_color: Color) -> void:
	var pending: Array[int] = [owner.hub_pending_vit, owner.hub_pending_str, owner.hub_pending_def, owner.hub_pending_agi, owner.hub_pending_int, owner.hub_pending_mnd]
	owner._hub_stats_presenter.update_allocation_page(
		root,
		pixel_texture,
		profile,
		pending,
		owner.hub_stat_row,
		owner.hub_content_focus,
		owner.hub_action_column,
		owner.display_view_size,
		highlight_color,
		owner._menu_widget_factory,
		owner._menu_prompt_texture_factory
	)

func _update_player_card(context: MenuPlayerContext, pixel_texture: Callable, texts: Array[Sprite2D], summary: Sprite2D = null) -> void:
	if texts.is_empty() or context == null or not context.is_valid():
		return
	var profile := context.profile
	var max_health := context.max_health()
	var health := context.current_health()
	var xp_required := PlayerProfile.xp_required_for_level(profile.level, context.progression_tuning)
	var values := [
		PlayerProfile.normalize_player_name(profile.player_name),
		context.element_display_name(),
		"LV %d" % profile.level,
		"XP %d/%d" % [profile.xp, xp_required],
		"HP %d/%d" % [health, max_health],
		"CHR %d/%d" % [context.chroma(), context.max_chroma()],
		"READY",
	]
	for index in texts.size():
		var label: String = str(values[index]) if index < values.size() else ""
		var label_color := Color8(255, 205, 117) if index == 3 else Color.WHITE
		if index == 1:
			label_color = PaletteLibrary.accent(context.palette_name)
		texts[index].texture = pixel_texture.call(label, label_color) as Texture2D
	if summary != null:
		summary.visible = true


# --- Hub stats and pause-screen presentation ---

func _update_hub_status_page(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, _highlight_color: Color) -> void:
	var updated := owner._hub_stats_presenter.update_status_page(root, pixel_texture, profile)
	if updated and owner.hub_context_text != null:
		owner.hub_context_text.texture = null

func _update_hub_binding_page(root: Object, pixel_texture: Callable, profile: PlayerProfile, highlight_color: Color) -> void:
	if owner.hub_binding_texts.size() < 5 or profile == null:
		return
	var chroma := root.get("player_chroma_component") as Node
	var current_aspect := &"gray"
	var current_is_bound := false
	if chroma != null:
		current_aspect = chroma.call("aspect_name") as StringName
		current_is_bound = bool(chroma.call("current_is_bound"))
	var current := ASPECT_CATALOG_SCRIPT.display_name(current_aspect)
	var bound := "NONE"
	if profile.has_bound_element:
		bound = String(profile.bound_element).to_upper()
	var cost := PlayerProfile.ELEMENT_BIND_SOUL_COST
	var can_bind := bool(root.call("_can_bind_current_element"))
	var enough_souls := profile.souls >= cost
	var action_enabled := can_bind and enough_souls
	var action_color := highlight_color if action_enabled else Color8(102, 108, 122) if not can_bind or not enough_souls else Color.WHITE
	owner.hub_binding_texts[0].texture = pixel_texture.call("CURRENT %s%s" % [current, " BOUND" if current_is_bound else ""], highlight_color if can_bind else Color.WHITE) as Texture2D
	owner.hub_binding_texts[1].texture = pixel_texture.call("BOUND %s" % bound, Color.WHITE) as Texture2D
	owner.hub_binding_texts[2].texture = pixel_texture.call("SOULS %d" % profile.souls, Color8(211, 167, 255)) as Texture2D
	owner.hub_binding_texts[3].texture = pixel_texture.call("COST %d SOULS" % cost, Color8(255, 205, 117)) as Texture2D
	var status := owner.hub_binding_message
	if status.is_empty():
		if current_aspect == &"gray":
			status = "ATTUNE FIRST"
		elif current_is_bound:
			status = "ALREADY BOUND"
		elif not enough_souls:
			status = "NEED %d SOULS" % cost
		else:
			status = "READY TO BIND"
	owner.hub_binding_texts[4].texture = pixel_texture.call(status, Color8(255, 105, 105) if not action_enabled and current_aspect != &"gray" and not current_is_bound else Color8(167, 240, 112)) as Texture2D
	if owner.hub_binding_action_button != null:
		owner.hub_binding_action_button.disabled = not action_enabled
		var action_label := owner.hub_binding_action_button.get_child(0) as Sprite2D
		if action_label != null:
			var label := "BIND" if action_enabled else "BOUND" if current_is_bound else "NONE" if current_aspect == &"gray" else "NEED 50S"
			action_label.texture = pixel_texture.call(label, action_color) as Texture2D
		owner.set_archetype_button_state(owner.hub_binding_action_button, action_enabled, highlight_color)


## Compatibility facade; the render mode now belongs to HubMenuState.

func _render_equipment_menu(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, _highlight_color: Color, target_view: Control = null, read_only: bool = false) -> void:
	var view := (target_view if target_view != null else owner.hub_equipment_menu) as EquipmentMenuLayout
	if view == null or profile == null:
		return
	var selected_slot_index := clampi(owner._hub_menu_state.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var selected_slot := ItemCatalog.SLOTS[selected_slot_index]
	var confirm_prompt := owner._compact_equipment_navigation_prompt(owner._menu_confirm_prompt_for(root), "SELECT")
	var back_prompt := owner._compact_equipment_navigation_prompt(owner._menu_back_prompt_for(root), "BACK")
	var context := owner._hub_equipment_menu_context
	context.view = view
	context.menu_state = owner._hub_menu_state
	context.profile = profile
	context.pixel_texture = pixel_texture
	context.navigation_texture = owner._pixel_prompt_sequence_texture(pixel_texture, [confirm_prompt, back_prompt], Color.WHITE, 9, 2) as Texture2D
	context.portrait_texture = root._equipment_portrait_texture()
	context.stat_snapshot = root._player_stat_snapshot()
	context.player_stats = root.player_stats
	context.selected_slot_candidates = root._hub_gear_candidates(selected_slot)
	context.legacy_slot_texts = owner.hub_item_list_texts
	context.legacy_candidate_texts = owner.hub_gear_choice_texts
	context.read_only = read_only
	context.show_navigation = target_view != null
	owner._hub_equipment_menu_presenter.render(context)
