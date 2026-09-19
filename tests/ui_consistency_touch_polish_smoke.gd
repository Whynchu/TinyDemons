extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/shop_menu.tscn") as PackedScene
	_expect(packed != null, "authored shop scene loads for touch geometry coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var hub_overlay := Control.new()
	hub_overlay.name = "HubOverlay"
	hub_overlay.size = Vector2(240.0, 160.0)
	root.add_child(hub_overlay)
	var shop := packed.instantiate() as ShopMenuLayout
	hub_overlay.add_child(shop)
	var labels: Array[String] = ["HEAD", "BODY", "ARM", "SHIELD", "RING", "WEAPON", "CLOAK", "ORB"]
	var colors: Array[Color] = [Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE]
	var prices: Array[String] = ["100", "110", "120", "130", "140", "150", "160", "170"]
	var souls: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
	var slots: Array[StringName] = [&"head", &"body", &"arm", &"shield", &"accessory", &"weapon", &"head", &"weapon"]
	shop.render_shop(ShopMenuLayout.ITEM_BROWSE, false, 0, labels, colors, prices, souls, slots, [], 1, 1, 3, Callable(self, "_pixel_texture"))
	await process_frame
	var layer := TouchControlsLayer.new()
	root.add_child(layer)
	layer.build()
	layer.set_last_input_device(InputDeviceTracker.Device.TOUCH)
	layer.set_input_context(InputRouter.Context.HUB)
	_expect(shop.item_buttons.size() >= 2 and shop.item_texts.size() >= 2, "shop exposes authored item rows", failures)
	_expect(_touch_hits_button(layer, shop.item_buttons[0]), "BUY item row is touchable at its visible center", failures)
	_expect(is_equal_approx(shop.item_buttons[0].position.y, shop.item_texts[0].position.y - 2.0), "BUY hitbox is centered on the item row origin", failures)

	shop.render_shop(ShopMenuLayout.ITEM_BROWSE, true, 0, labels, colors, prices, souls, slots, [], 1, 1, 3, Callable(self, "_pixel_texture"))
	await process_frame
	_expect(_touch_hits_button(layer, shop.item_buttons[1]), "SELL item row is touchable at its visible center", failures)

	for width in [240.0, 284.0, 320.0]:
		hub_overlay.size = Vector2(width, 160.0)
		shop.size = Vector2(width, 160.0)
		shop.refresh_layout_preserving_state()
		_expect(_touch_hits_button(layer, shop.item_buttons[0]), "shop row hitbox survives responsive width %d" % int(width), failures)
		_expect(is_equal_approx(shop.item_buttons[0].position.y, shop.item_texts[0].position.y - 2.0), "shop row and hitbox stay vertically aligned at width %d" % int(width), failures)

	var map_controller := DungeonMinimapController.new()
	var native_footer := map_controller.map_footer_prompt_positions(Vector2(240.0, 160.0))
	var wide_footer := map_controller.map_footer_prompt_positions(Vector2(320.0, 160.0))
	_expect(wide_footer["back_button"].x > native_footer["back_button"].x and wide_footer["select_button"].x > native_footer["select_button"].x, "map footer touch targets follow the right rail", failures)
	_expect(is_equal_approx(native_footer["back_button"].x - native_footer["select_button"].x, wide_footer["back_button"].x - wide_footer["select_button"].x), "map SELECT keeps its spacing from BACK across widths", failures)
	map_controller.free()

	layer.free()
	hub_overlay.free()
	_finished = true
	_finish(failures)


func _touch_hits_button(layer: TouchControlsLayer, button: Button) -> bool:
	return button != null and button.visible and not button.disabled and layer.call("_menu_button_at", button.get_global_rect().get_center()) == button


func _pixel_texture(_text: String, color: Color) -> Texture2D:
	var image := Image.create(3, 5, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: UI consistency touch polish smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("UI_CONSISTENCY_TOUCH_POLISH_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
