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
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var router := gameplay.get("input_router") as InputRouter
	var touch := gameplay.get("touch_controls_layer") as TouchControlsLayer
	_expect(screens != null and router != null and touch != null, "menu route owners are composed", failures)
	if screens != null and router != null and touch != null:
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
		_expect(touch.call("_active_menu_root") == screens.pause_overlay, "touch hit-testing is scoped to the active pause overlay", failures)
		screens.pause_status_button.pressed.emit()
		await process_frame
		_expect(not screens.pause_root_page.is_visible_in_tree() and screens.pause_page_roots[1].is_visible_in_tree(), "pause Status replaces the command root", failures)
		_expect(screens.pause_menu_buttons.all(func(button: Button) -> bool: return not button.is_visible_in_tree()), "pause commands are unavailable on Status", failures)
		_set_menu_edge(router, false, true)
		gameplay.call("_update_pause_input")
		_clear_menu_edge(router)
		await process_frame
		_expect(screens.pause_page == 0 and screens.pause_root_page.is_visible_in_tree(), "pause BACK returns from read-only Status", failures)
		screens.pause_settings_button.pressed.emit()
		await process_frame
		_expect(screens.settings_overlay.is_visible_in_tree() and not screens.pause_overlay.is_visible_in_tree() and not screens.hub_overlay.is_visible_in_tree(), "Settings replaces pause without an overlay stack", failures)
		_expect(touch.call("_active_menu_root") == screens.settings_overlay, "touch hit-testing is scoped to the active Settings overlay", failures)
		_expect(screens.settings_back_button.is_visible_in_tree() and screens.settings_option_buttons[1].size() == 4, "Settings exposes a rendered BACK and all aspect choices", failures)
		_set_menu_edge(router, false, true)
		gameplay.call("_update_settings_input")
		_clear_menu_edge(router)
		await process_frame
		_expect(screens.pause_overlay.is_visible_in_tree() and not screens.settings_overlay.is_visible_in_tree(), "Settings BACK restores only pause", failures)
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
		_expect(not screens.pause_overlay.is_visible_in_tree() and not screens.hub_overlay.is_visible_in_tree() and not screens.settings_overlay.is_visible_in_tree(), "game over hides every source overlay", failures)
		_expect(screens.game_over_footer_text != null and screens.game_over_footer_text.visible, "game over exposes a back footer", failures)
		_expect(gameplay.get_viewport().gui_get_focus_owner() == null, "game over does not leave native focus on a hidden control", failures)
		screens.menu_input_release_lock = false
		router.set("_previous", {&"menu_confirm": false, &"menu_back": false})
		router.set("_current", {&"menu_confirm": false, &"menu_back": false})
		router.set("_previous_menu_directions", {&"ui_down": false})
		router.set("_menu_directions", {&"ui_down": true})
		gameplay.call("_update_game_over_input")
		_expect(screens.game_over_row == 1, "game over accepts directional controller navigation", failures)
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
