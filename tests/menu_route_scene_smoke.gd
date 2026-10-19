extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for routed menu coverage", failures)
	if packed == null:
		_finish(failures)
		return
	# Routed hub/pause/game-over coverage requires the deferred gameplay phase.
	# Request the deterministic benchmark room so this smoke does not depend on
	# whatever profile route happens to exist in the local user data directory.
	ProjectSettings.set_setting("debug/benchmark_start_in_boss_room", true)
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var router := gameplay.get("input_router") as InputRouter
	var touch := gameplay.get("touch_controls_layer") as TouchControlsLayer
	_expect(screens != null and router != null and touch != null, "menu route owners are composed", failures)
	if screens != null and router != null and touch != null:
		var card_style := screens._menu_widget_factory.menu_card_style()
		_expect(card_style.texture == MenuWindow.FRAME_TEXTURE, "compatibility Panel cards share the menu frame artwork", failures)
		_expect(not (screens.title_presenter.overlay is MenuScreen) and screens.title_presenter.overlay.get_node_or_null("TitleWindow") == null, "main title screen preserves its original splash presentation", failures)
		for menu in [screens.settings_presenter.overlay, screens.name_entry_controller.widgets.overlay, screens.save_select_presenter.overlay, screens.archetype_presenter.overlay, screens.run_complete_presenter.overlay, screens._game_over_screen_presenter.overlay]:
			_check_menu_shell(menu as ColorRect, failures)
		gameplay.call("_show_hub", true, false)
		await process_frame
		_expect(screens.hub_overlay.is_visible_in_tree() and screens.state == &"hub", "hub root is the active full-screen route", failures)
		_expect(screens.hub_overlay.position == Vector2.ZERO and screens.hub_overlay.size == screens.display_view_size, "hub route fills the logical viewport", failures)
		_expect(screens.hub_root_page.is_visible_in_tree() and screens.hub_page_buttons.all(func(button: Button) -> bool: return button.is_visible_in_tree()), "hub root exposes only its command rail", failures)
		_expect(touch.call("_active_menu_root") == screens.hub_overlay, "touch hit-testing is scoped to the active hub overlay", failures)

		# The four commands keep the authored top shell visible while replacing the
		# content preview underneath it.
		for command_button in screens.hub_page_buttons:
			var target_page := int(command_button.get_meta("hub_page_target", -1))
			command_button.pressed.emit()
			await process_frame
			var active_page := screens.hub_page_roots.get(target_page) as Control
			_expect(screens.hub_root_page.is_visible_in_tree(), "hub shell remains visible while child page %d is active" % target_page, failures)
			_expect(active_page != null and active_page.is_visible_in_tree(), "hub child page %d replaces the root" % target_page, failures)
			for page_root: Control in screens.hub_page_roots.values():
				if page_root != active_page:
					_expect(not page_root.is_visible_in_tree(), "inactive hub page stays hidden", failures)
			_expect(screens.hub_page_buttons.all(func(button: Button) -> bool: return button.is_visible_in_tree()), "hub command rail remains available on child pages", failures)
			_expect(touch.call("_active_menu_root") == screens.hub_overlay, "child hub touch hit-testing remains on the hub route", failures)
			_set_menu_edge(router, false, true)
			gameplay.call("_update_hub_input")
			_clear_menu_edge(router)
			await process_frame
			_expect(screens.hub_is_root and screens.hub_root_page.is_visible_in_tree(), "hub BACK returns to the command root", failures)

		# Pause has its own root and child page stack; it must not expose hub
		# controls or leave a source overlay visible underneath Settings.
		gameplay.call("_close_hub_to_run")
		gameplay.call("_open_pause_menu")
		await process_frame
		_expect(screens.pause_overlay.is_visible_in_tree() and not screens.hub_overlay.is_visible_in_tree(), "pause replaces hub with its own overlay", failures)
		_expect(screens.pause_root_page.is_visible_in_tree() and screens.pause_menu_buttons.all(func(button: Button) -> bool: return button.is_visible_in_tree()), "pause root exposes only its command rail", failures)
		_expect(screens.pause_gold_icon.is_visible_in_tree() and screens.pause_resource_icon.is_visible_in_tree(), "pause root shows currency in its resource panel", failures)
		_expect(touch.call("_active_menu_root") == screens.pause_overlay, "touch hit-testing is scoped to the active pause overlay", failures)
		router.set("_menu_direction_events", {&"ui_down": true})
		gameplay.call("_update_pause_input")
		router.set("_menu_direction_events", {})
		_expect(screens.pause_menu_row == 1, "Pause command input moves to the next enabled row", failures)
		_set_menu_edge(router, true, false)
		gameplay.call("_update_pause_input")
		_clear_menu_edge(router)
		await process_frame
		_expect(screens.pause_page == 1 and not screens.pause_root_page.is_visible_in_tree() and screens.pause_page_roots[1].is_visible_in_tree(), "Pause command input activates Status and replaces the command root", failures)
		var stats_page := screens.pause_page_roots[1] as MenuScreen
		if stats_page != null:
			var stats_heading := stats_page.get_node_or_null("Title") as Sprite2D
			_expect(is_equal_approx(stats_page.title_width, 90.0), "Pause Stats uses the standard title panel width", failures)
			_expect(stats_heading != null and stats_heading.texture != null, "Pause Stats heading has a rendered texture", failures)
			if stats_heading != null and stats_heading.texture != null:
				var expected_right := minf(stats_page.title_width, stats_page.size.x) - 4.0
				_expect(is_equal_approx(stats_heading.position.x + stats_heading.texture.get_width(), expected_right), "Pause Stats heading shares the menu right inset", failures)
		_expect(screens.pause_menu_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()), "pause commands are unavailable on Status", failures)
		_expect(not screens.pause_gold_icon.is_visible_in_tree() and not screens.pause_resource_icon.is_visible_in_tree() and not screens.pause_gold_text.is_visible_in_tree() and not screens.pause_soul_text.is_visible_in_tree(), "Status hides currency icons and counts after player data refresh", failures)
		_set_menu_edge(router, false, true)
		gameplay.call("_update_pause_input")
		_clear_menu_edge(router)
		await process_frame
		_expect(screens.pause_page == 0 and screens.pause_root_page.is_visible_in_tree(), "pause BACK returns from read-only Status", failures)
		_expect(screens.pause_gold_icon.is_visible_in_tree() and screens.pause_resource_icon.is_visible_in_tree(), "returning to pause root restores currency icons", failures)
		screens.pause_settings_button.pressed.emit()
		await process_frame
		_expect(screens.settings_presenter.overlay.is_visible_in_tree() and not screens.pause_overlay.is_visible_in_tree() and not screens.hub_overlay.is_visible_in_tree(), "Settings replaces pause without an overlay stack", failures)
		_expect(touch.call("_active_menu_root") == screens.settings_presenter.overlay, "touch hit-testing is scoped to the active Settings overlay", failures)
		_expect(screens.settings_presenter.back_button.is_visible_in_tree() and screens.settings_presenter.option_buttons[1].size() == 4, "Settings exposes a rendered BACK and all aspect choices", failures)
		_set_menu_edge(router, false, true)
		gameplay.call("_update_settings_input")
		_clear_menu_edge(router)
		await process_frame
		_expect(screens.pause_overlay.is_visible_in_tree() and not screens.settings_presenter.overlay.is_visible_in_tree(), "Settings BACK restores only pause", failures)
		_set_menu_edge(router, false, true)
		gameplay.call("_update_pause_input")
		_clear_menu_edge(router)
		await process_frame
		_expect(not screens.pause_overlay.is_visible_in_tree() and not screens.hub_overlay.is_visible_in_tree() and screens.state == &"gameplay", "pause BACK closes the menu route", failures)

		# Game over is a terminal full-screen route too: it must not retain a
		# source menu, steal native focus, or lose controller row navigation.
		gameplay.call("_show_game_over")
		await process_frame
		var game_over := gameplay.get("game_over_overlay") as ColorRect
		_expect(game_over != null and game_over.is_visible_in_tree() and screens.state == &"game_over", "game over is the active full-screen route", failures)
		_expect(not screens.pause_overlay.is_visible_in_tree() and not screens.hub_overlay.is_visible_in_tree() and not screens.settings_presenter.overlay.is_visible_in_tree(), "game over hides every source overlay", failures)
		_expect(screens.game_over_presenter.footer_text != null and screens.game_over_presenter.footer_text.visible, "game over exposes a back footer", failures)
		_expect(gameplay.get_viewport().gui_get_focus_owner() == null, "game over does not leave native focus on a hidden control", failures)
		screens.menu_input_release_lock = false
		router.set("_previous", {&"menu_confirm": false, &"menu_back": false})
		router.set("_current", {&"menu_confirm": false, &"menu_back": false})
		# update_game_over_input reads menu_direction_just_pressed(), which is
		# backed by _menu_direction_events (populated by poll()). Inject that
		# field directly, matching how the other routed-menu checks inject their
		# current/previous edge state.
		router.set("_menu_direction_events", {&"ui_down": true})
		gameplay.call("_update_game_over_input")
		_expect(screens.game_over_presenter.row == 1, "game over accepts directional controller navigation", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _set_menu_edge(router: InputRouter, confirm: bool, back: bool) -> void:
	router.set("_previous", {&"menu_confirm": false, &"menu_back": false})
	router.set("_current", {&"menu_confirm": confirm, &"menu_back": back})
	router.set("_previous_menu_directions", {})
	router.set("_menu_directions", {})


func _clear_menu_edge(router: InputRouter) -> void:
	router.set("_previous", {&"menu_confirm": false, &"menu_back": false})
	router.set("_current", {&"menu_confirm": false, &"menu_back": false})
	router.set("_previous_menu_directions", {})
	router.set("_menu_directions", {})


func _check_menu_shell(overlay: ColorRect, failures: Array[String]) -> void:
	_expect(overlay is MenuScreen, "standard menu uses the shared screen shell", failures)
	var menu := overlay as MenuScreen
	if menu == null:
		return
	_expect(is_equal_approx(menu.title_width, 90.0), "shared menu titles use the standard panel width", failures)
	for window_name in ["TitleWindow", "HeaderWindow", "ContentWindow", "FooterWindow"]:
		var window := menu.get_node_or_null(NodePath(window_name)) as NinePatchRect
		_expect(window != null, "%s provides %s" % [menu.name, window_name], failures)
		if window == null:
			continue
		_expect(window.texture != null and window.texture.resource_path == "res://assets/artwork/frame 16x16.png", "menu window consumes the canonical frame asset", failures)
		_expect(window.mouse_filter == Control.MOUSE_FILTER_IGNORE, "decorative windows leave input to the screen controls", failures)
		_expect(window.patch_margin_left == 3 and window.axis_stretch_horizontal == NinePatchRect.AXIS_STRETCH_MODE_TILE, "menu window tiles native pixel borders", failures)
	var original_size := menu.size
	var original_header_visibility := menu.show_header_window
	var child_count := menu.get_child_count()
	for width in [320.0, 240.0]:
		menu.size = Vector2(width, 160)
		menu.apply_layout()
		var header := menu.get_node("HeaderWindow") as Control
		var content := menu.get_node("ContentWindow") as Control
		var footer := menu.get_node("FooterWindow") as Control
		var title := menu.get_node("TitleWindow") as Control
		var heading := menu.get_node_or_null("Heading") as Sprite2D
		if heading == null:
			heading = menu.get_node_or_null("Title") as Sprite2D
		_expect(header.visible == original_header_visibility, "resize preserves the screen's optional header visibility", failures)
		_expect(title.visible and title.position == Vector2.ZERO, "the title remains in the top-left window", failures)
		if heading != null and heading.texture != null:
			var heading_right := heading.position.x + heading.texture.get_width()
			_expect(is_equal_approx(heading_right, minf(menu.title_width, width) - 4.0), "menu heading keeps the shared right inset", failures)
		_expect(header.position.x == menu.title_width and header.position.x + header.size.x == width, "header expands beside the fixed title window", failures)
		_expect(content.size.x == width and content.position.y == menu.header_height, "content window follows the logical viewport", failures)
		if menu.footer_height > 0.0:
			_expect(footer.visible and footer.position.y + footer.size.y == 160.0, "footer remains bottom anchored", failures)
		else:
			_expect(not footer.visible, "screens can omit the footer without adding a different shell", failures)
		_expect(menu.get_child_count() == child_count, "resize preserves existing controls", failures)
	menu.show_header_window = true
	_expect((menu.get_node("HeaderWindow") as Control).visible, "screens with header controls can enable the right-hand window", failures)
	menu.show_header_window = false
	_expect(not (menu.get_node("HeaderWindow") as Control).visible, "empty header windows can be removed without changing the title", failures)
	menu.show_header_window = original_header_visibility
	menu.size = original_size
	menu.apply_layout()


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: routed menu scene smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("MENU_ROUTE_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
