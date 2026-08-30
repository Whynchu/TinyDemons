extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for title boot characterization", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 120:
		await process_frame
	var screens := gameplay.get("screen_state_controller") as ScreenStateController
	_expect(screens != null, "screen state owner is composed during boot", failures)
	if screens != null:
		_expect(screens.title_overlay != null, "title overlay is built during boot", failures)
		_expect(screens.title_overlay != null and screens.title_overlay.visible, "title overlay is visible after boot", failures)
		_expect(screens.title_cloud_button != null, "title screen exposes the Cloud Save button", failures)
		if screens.title_cloud_button != null:
			screens.title_cloud_button.pressed.emit()
			var cloud_panel := gameplay.get("cloud_save_panel") as CloudSavePanel
			_expect(cloud_panel != null and cloud_panel.overlay != null and cloud_panel.overlay.visible, "Cloud Save button opens the management window", failures)
			if cloud_panel != null: cloud_panel.close()
		var version := screens.title_overlay.get_node_or_null("TitleVersion") as Sprite2D
		_expect(version != null and version.texture != null and version.position.is_equal_approx(Vector2(4, screens.display_view_size.y - 8.0)), "title screen shows the game version in the bottom-left", failures)
		_expect(screens.state == &"title", "screen state settles on title after boot", failures)
	_expect(not bool(gameplay.get("boot_active")), "boot sequence completes", failures)
	var loading := gameplay.get("loading_screen_overlay") as CanvasItem
	_expect(loading == null or not loading.visible, "loading cover releases after title boot", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TITLE_BOOT_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
