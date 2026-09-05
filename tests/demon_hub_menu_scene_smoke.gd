extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Demon Hub menu coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var input_router := gameplay.get("input_router") as InputRouter
	_expect(screens != null and input_router != null, "hub and input owners are composed", failures)
	if screens != null and input_router != null:
		gameplay.call("_show_hub", true, false)
		await process_frame
		_expect(screens.hub_overlay.visible and not screens.pause_overlay.visible and screens.hub_pause_mode == false, "Demon interaction opens only the preparation overlay", failures)
		_expect(screens.hub_overlay.size == screens.display_view_size and screens.hub_overlay.position == Vector2.ZERO and screens.hub_overlay.get_node_or_null("HubRootPage/HubPlayerCard") != null, "Demon Hub owns the full-screen authored shell", failures)
		var hub_panel := screens.hub_overlay.get_node_or_null("HubContentPanel") as Control
		var hub_title := screens.hub_overlay.get_node_or_null("HubRootPage/Title") as Sprite2D
		_expect(hub_panel != null and hub_panel.size == Vector2(240, 115) and hub_title != null and hub_title.texture != null, "Demon Hub root uses the scene-authored content frame and upper-left title card", failures)
		_expect(screens.hub_overlay.get_node_or_null("HubCommandStart") == null, "Demon Hub does not construct a hidden Start Run button", failures)
		_expect(screens.hub_page_buttons.all(func(button: Button) -> bool: return button.get_meta("hub_page_target", -1) >= 0), "hub commands use explicit page targets", failures)
		_expect(screens.hub_page_buttons.size() == 4 and screens.hub_page_buttons[0].name == "HubCommandStats" and screens.hub_page_buttons[3].name == "HubCommandBind", "Demon Hub exposes only STATS, SHOP, FUSION, and BIND", failures)
		for command_button in screens.hub_page_buttons:
			command_button.pressed.emit()
			await process_frame
			var route_page := screens.hub_page_roots.get(screens.hub_page) as Control
			var route_background := route_page.get_node_or_null("Background") as NinePatchRect if route_page != null else null
			var route_title := route_page.get_node_or_null("Title") as Sprite2D if route_page != null else null
			_expect(screens.hub_root_page.visible and route_background != null and route_title != null, "Demon Hub route %d keeps the shared shell and content owner" % screens.hub_page, failures)
			gameplay.call("_hub_back_or_close")
			await process_frame

		# Shop is a dedicated authored child scene. Verify its native geometry,
		# responsive cursor ownership, and the nested sell quantity route here so
		# a legacy list presenter cannot silently regress underneath it.
		gameplay.call("_set_hub_page", screens.HUB_PAGE_SHOP)
		await process_frame
		var shop_view := screens.hub_shop_menu as Control
		var profile := gameplay.get("player_profile") as PlayerProfile
		_expect(shop_view != null and shop_view.visible and not screens.hub_list_cursor.visible and not screens.hub_slot_cursor.visible and not screens.hub_choice_cursor.visible, "Shop receives its authored scene after Equipment", failures)
		if shop_view != null and profile != null:
			var shop_top_cursor := shop_view.get_node_or_null("ShopTopCursor") as Sprite2D
			var shop_mode_cursor := shop_view.get_node_or_null("ShopModeCursor") as Sprite2D
			var shop_item_cursor := shop_view.get_node_or_null("ShopItemCursor") as Sprite2D
			var shop_amount_cursor := shop_view.get_node_or_null("ShopAmountCursor") as Sprite2D
			_expect(shop_top_cursor != null and shop_mode_cursor != null and shop_item_cursor != null and shop_amount_cursor != null and screens.hub_cursor_text != null and screens.hub_cursor_text.position == Vector2(122, 5) and not shop_top_cursor.visible and shop_mode_cursor.position == Vector2(73, 26) and shop_mode_cursor.visible and not shop_item_cursor.visible and not shop_amount_cursor.visible, "Shop cursor ownership and anchors match the authored 240x160 mockup", failures)
			var mode_panel := shop_view.get_node_or_null("ShopModePanel") as NinePatchRect
			var list_panel := shop_view.get_node_or_null("ShopListPanel") as NinePatchRect
			var stats_panel := shop_view.get_node_or_null("ShopStatsPanel") as NinePatchRect
			var list_clip := shop_view.get_node_or_null("ListClip") as Control
			_expect(mode_panel != null and list_panel != null and stats_panel != null and list_clip != null and mode_panel.position == Vector2(0, 21) and mode_panel.size == Vector2(240, 21) and list_panel.position == Vector2(0, 42) and list_panel.size == Vector2(146, 94) and stats_panel.position == Vector2(148, 42) and stats_panel.size == Vector2(92, 94) and list_clip.position == Vector2(0, 46) and list_clip.size == Vector2(146, 87), "Shop scene keeps the authored frame and panel geometry", failures)
			_expect(shop_view.get_node_or_null("ContentPanel") == null and shop_view.get_node_or_null("DetailPanel") == null and shop_view.get_node_or_null("FooterPanel") == null, "Shop does not duplicate the shared shell panels", failures)
			_expect(shop_view.get_node_or_null("ListClip/ItemText7") != null and shop_view.get_node_or_null("ListClip/PriceText7") != null and shop_view.get_node_or_null("StatLabel5") != null, "Shop scene exposes all authored item and stat rows", failures)
			var native_shop_size := shop_view.size
			shop_view.size = Vector2(284, 160)
			for _frame in 20:
				await process_frame
			_expect(shop_mode_cursor != null and shop_mode_cursor.has_method("is_bobbing") and bool(shop_mode_cursor.call("is_bobbing")) and shop_top_cursor != null and not shop_top_cursor.visible and screens.hub_cursor_text != null and not bool(screens.hub_cursor_text.call("is_bobbing")), "Shop only animates the active cursor depth", failures)
			_expect(shop_mode_cursor != null and shop_mode_cursor.position.x > 75.0 and screens.hub_cursor_text != null and screens.hub_cursor_text.position.x > 122.0, "Shop cursor anchors reflow with the logical width", failures)
			_expect(mode_panel != null and mode_panel.size == Vector2(284, 21) and list_panel != null and list_panel.position.x == 0.0 and list_panel.size.x > 146.0 and list_panel.size.y == 94.0 and stats_panel != null and stats_panel.position.x > 148.0 and list_clip != null and list_clip.size.x > 146.0, "Shop preserves authored height while reflowing its logical width", failures)
			shop_view.size = native_shop_size
			await process_frame

			# Two identical unequipped copies verify that sell quantity starts at
			# one and can be increased before one atomic transaction removes both.
			var sale_one := ItemInstance.new()
			sale_one.instance_id = "shop-smoke-rune-1"
			sale_one.definition_id = &"rune_accessory"
			sale_one.rarity = &"common"
			sale_one.quality = 1.01
			sale_one.random_stat_points = {"mnd": 2}
			var sale_two := ItemInstance.new()
			sale_two.instance_id = "shop-smoke-rune-2"
			sale_two.definition_id = &"rune_accessory"
			sale_two.rarity = &"common"
			sale_two.quality = 1.01
			sale_two.random_stat_points = {"mnd": 2}
			profile.grant_item(sale_one)
			profile.grant_item(sale_two)
			gameplay.call("_shop_mode_pressed", 1)
			await process_frame
			var sellable: Array = gameplay.call("_hub_shop_sellable_items") as Array
			for index in sellable.size():
				var candidate := sellable[index] as ItemInstance
				if candidate != null and candidate.instance_id == sale_one.instance_id:
					screens.hub_item_index = index
					break
			screens.update_hub_ui(gameplay, Callable(gameplay, "_pixel_text_texture"))
			await process_frame
			_expect(screens.hub_shop_sell_mode and screens.hub_shop_state == 1, "Shop Sell enters the authored item browse state", failures)
			gameplay.call("_hub_item_action")
			await process_frame
			var sell_quantity := shop_view.get_node_or_null("SellQuantityValue") as Sprite2D
			var sell_plus_button := shop_view.get_node_or_null("SellPlusButton") as Button
			var sell_cancel_button := shop_view.get_node_or_null("SellCancelButton") as Button
			var shop_back_button := shop_view.get_node_or_null("ShopBackButton") as Button
			var sell_gold_icon := shop_view.get_node_or_null("ListClip/SellRowGoldIcon0") as Sprite2D
			var sell_soul_amount := shop_view.get_node_or_null("ListClip/SellRowSoulAmount0") as Sprite2D
			var sell_soul_icon := shop_view.get_node_or_null("ListClip/SellRowSoulIcon0") as Sprite2D
			_expect(screens.hub_shop_state == 2 and screens.hub_shop_sell_amount == 1 and screens.hub_shop_sell_amount_max >= 2 and sell_quantity != null and sell_quantity.texture != null and sell_plus_button != null and not sell_plus_button.disabled and sell_cancel_button != null and sell_cancel_button.visible and shop_back_button != null and not shop_back_button.visible and sell_gold_icon != null and sell_gold_icon.visible and sell_soul_amount != null and sell_soul_amount.visible and sell_soul_amount.texture != null and sell_soul_icon != null and sell_soul_icon.visible and sell_soul_icon.texture != null, "Sell amount opens at x1 with the authored price and plus/cancel controls", failures)
			gameplay.call("_shop_amount_changed", 1)
			await process_frame
			_expect(screens.hub_shop_sell_amount == 2, "Controller right increases the sell amount", failures)
			var starting_gold := profile.gold
			gameplay.call("_hub_item_action")
			await process_frame
			_expect(profile.find_item(sale_one.instance_id) == null and profile.find_item(sale_two.instance_id) == null and profile.gold > starting_gold and screens.hub_shop_state == 1, "Confirming the sell quantity performs one batch sale and returns to browse", failures)
			# Returning to the command rail keeps the selected SHOP preview visible,
			# but no nested cursor or transaction control may remain owned. A direct
			# touch-style mode callback must then enter SELL from that preview cleanly.
			gameplay.call("_hub_back_or_close")
			await process_frame
			gameplay.call("_hub_back_or_close")
			await process_frame
			var shop_mode_button := shop_view.get_node_or_null("ModeSellButton") as Button
			_expect(screens.hub_is_root and shop_view.visible and not shop_mode_cursor.visible and not shop_item_cursor.visible and not shop_amount_cursor.visible and screens.hub_cursor_text.visible and shop_mode_button != null and not shop_mode_button.disabled, "Shop root preview keeps contents without nested cursor ownership", failures)
			gameplay.call("_shop_mode_pressed", 1)
			await process_frame
			_expect(not screens.hub_is_root and screens.hub_shop_sell_mode and screens.hub_shop_state == 1 and shop_mode_cursor.visible and shop_item_cursor.visible, "Touching SELL from the root preview enters the sell browser", failures)
		gameplay.call("_close_hub_to_run")

		gameplay.call("_open_pause_menu")
		await process_frame
		_expect(screens.pause_overlay.visible and not screens.hub_overlay.visible and screens.state == &"pause", "pause opens a distinct overlay and state", failures)
		_expect(screens.pause_overlay.size == screens.display_view_size and screens.pause_overlay.position == Vector2.ZERO and screens.pause_menu_buttons.size() == 4, "pause uses its own four-command full-screen shell", failures)
		_expect(gameplay.call("_input_context") == InputRouter.Context.PAUSE, "pause routes through the dedicated input context", failures)
		if screens.pause_status_button != null:
			screens.pause_status_button.pressed.emit()
		_expect(screens.pause_page == 1 and not screens.hub_overlay.visible and screens.pause_status_texts[0].visible, "pause Status stays read-only and cannot expose hub transactions", failures)
		if screens.pause_back_button != null:
			screens.pause_back_button.pressed.emit()
		_expect(screens.pause_page == 0 and screens.pause_description_text.visible, "pause BACK returns from a read-only subpage", failures)
		if screens.pause_settings_button != null:
			screens.pause_settings_button.pressed.emit()
		await process_frame
		_expect(screens.settings_overlay.visible and not screens.pause_overlay.visible and not screens.hub_overlay.visible, "pause Settings replaces pause without overlay overlap", failures)
		gameplay.call("_close_settings")
		_expect(screens.pause_overlay.visible and not screens.settings_overlay.visible and not screens.hub_overlay.visible and screens.state == &"pause", "closing pause Settings restores only pause", failures)
		gameplay.call("_close_hub_to_run")
		_expect(not screens.pause_overlay.visible and not screens.hub_overlay.visible and screens.state == &"gameplay", "pause cancellation returns to gameplay", failures)
	gameplay.queue_free()
	await process_frame
	_finished = true
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Demon Hub menu scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("DEMON_HUB_MENU_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
