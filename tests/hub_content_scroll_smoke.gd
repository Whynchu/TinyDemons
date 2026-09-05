extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for hub content scroll coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	gameplay.call("_show_hub", true, false)
	await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	var run_state := gameplay.get("run_state") as RunState
	var profile := gameplay.get("player_profile") as PlayerProfile
	_expect(screens != null and run_state != null and profile != null, "hub content scroll owners are composed", failures)
	if screens != null and run_state != null and profile != null:
		screens.hub_page = screens.HUB_PAGE_SHOP
		run_state.ensure_shop_stock(profile)
		_expect(screens.hub_list_scroll == 0.0, "hub list starts at the top", failures)
		if run_state.shop_stock.size() >= 9:
			screens.hub_item_index = 7
			screens.snap_hub_list_scroll_to_selection(gameplay)
			_expect(screens.hub_list_scroll == 0.0, "controller keeps the first eight shop rows fixed", failures)
			screens.hub_item_index = 8
			screens.snap_hub_list_scroll_to_selection(gameplay)
			_expect(screens.hub_list_scroll == 1.0, "controller starts shop scrolling on the ninth row", failures)
			screens.hub_item_index = 0
			screens.hub_list_scroll = 0.0
		var index_before := screens.hub_item_index
		# Dragging up scrolls the content (shows later rows); the cursor stays.
		screens.scroll_hub_content(gameplay, -30.0)
		_expect(screens.hub_list_scroll > 0.0, "a swipe drag scrolls the list content", failures)
		_expect(screens.hub_item_index == index_before, "scrolling the content does not move the cursor", failures)
		# Dragging down returns toward the top and clamps.
		screens.scroll_hub_content(gameplay, 100.0)
		_expect(screens.hub_list_scroll == 0.0, "content scroll clamps at the top", failures)
		# Controller selection still re-centers the content.
		screens.snap_hub_list_scroll_to_selection(gameplay)
		_expect(screens.hub_list_scroll >= 0.0, "selection snap keeps the content within range", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: hub content scroll smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("HUB_CONTENT_SCROLL_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
