extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/player_hud.tscn") as PackedScene
	_expect(packed != null, "player HUD scene loads with the authored artwork", failures)
	if packed == null:
		_finish(failures)
		return
	var hud := packed.instantiate() as Node2D
	root.add_child(hud)
	await process_frame

	_expect(hud.position.is_equal_approx(Vector2.ZERO), "player HUD root keeps the logical origin", failures)
	var player_status := hud.get_node_or_null("PlayerStatus") as Node2D
	_expect(player_status != null and player_status.position.is_equal_approx(Vector2.ZERO), "player status stays flush to the frame origin", failures)
	for path in ["UIFrame", "Portrait", "LevelNumberBackground", "LevelLabel", "LevelNumber"]:
		var layer := player_status.get_node_or_null(path) as Sprite2D if player_status != null else null
		_expect(layer != null and layer.position.is_equal_approx(Vector2.ZERO), "%s layer keeps its authored origin" % path, failures)
		if layer != null and path != "LevelNumber":
			_expect(layer.texture != null and layer.texture.get_size().is_equal_approx(Vector2(82, 16)), "%s layer is an 82x16 export" % path, failures)

	var fills := [
		hud.get_node_or_null("PlayerStatus/LevelXp/XpBarFill") as Sprite2D,
		hud.get_node_or_null("PlayerStatus/Health/HpBarFill") as Sprite2D,
		hud.get_node_or_null("PlayerStatus/Mana/MpBarFill") as Sprite2D,
	]
	for fill in fills:
		_expect(fill != null and fill.texture != null and fill.texture.get_size().is_equal_approx(Vector2(82, 16)), "player bar uses the full-strip fill source", failures)
		_expect(fill != null and fill.region_enabled and fill.region_rect.size.is_equal_approx(Vector2(82, 16)), "player bar clips within the full authored strip", failures)

	for path in [
		"PlayerStatus/LevelXp/LevelTextAnchor/LevelText",
		"PlayerStatus/LevelXp/XpText",
		"PlayerStatus/Health/HpLabel",
		"PlayerStatus/Health/HpText",
		"PlayerStatus/Mana/MpLabel",
		"PlayerStatus/Mana/MpText",
	]:
		var legacy := hud.get_node_or_null(path) as CanvasItem
		_expect(legacy != null and not legacy.visible, "%s stays out of the gameplay HUD" % path, failures)

	var atlas := load("res://assets/artwork/player_UI_lvlnumbers.png") as Texture2D
	_expect(atlas != null and atlas.get_size().is_equal_approx(Vector2(40, 7)), "level number atlas contains ten 4x7 digits", failures)
	hud.call("set_static_text", "lv. 21", Color.WHITE)
	var level_sprite := hud.get_node_or_null("PlayerStatus/LevelNumber") as Sprite2D
	var level_image := level_sprite.get_texture().get_image() if level_sprite != null and level_sprite.texture != null else null
	_expect(level_image != null and level_image.get_pixel(71, 8).is_equal_approx(PaletteLibrary.WHITE), "level 2 begins in the middle number slot", failures)
	_expect(level_image != null and level_image.get_pixel(74, 9).is_equal_approx(PaletteLibrary.WHITE), "level 2 keeps its pinball shoulder", failures)
	_expect(level_image != null and level_image.get_pixel(78, 8).is_equal_approx(PaletteLibrary.WHITE), "level 1 is right-weighted in its slot", failures)
	_expect(level_image != null and level_image.get_pixel(79, 14).is_equal_approx(PaletteLibrary.WHITE), "level 1 reaches the bottom of its 4x7 glyph", failures)
	_expect(level_image != null and is_zero_approx(level_image.get_pixel(66, 8).a), "unused level slots remain transparent over the silhouette", failures)

	var xp_fill := fills[0] as Sprite2D
	var mp_fill := fills[2] as Sprite2D
	_expect(xp_fill != null and _contains_color(xp_fill.texture.get_image(), PaletteLibrary.NORMAL["yellow"]), "XP fill uses the yellow progression color", failures)
	_expect(mp_fill != null and _contains_color(mp_fill.texture.get_image(), PaletteLibrary.ACCENT["blue"]), "Chroma fill starts with the active blue accent", failures)
	hud.call("apply_bar_colors", PaletteLibrary.NORMAL["red"], PaletteLibrary.ACCENT["orange"])
	_expect(xp_fill != null and _contains_color(xp_fill.texture.get_image(), PaletteLibrary.NORMAL["yellow"]), "XP remains yellow when the player palette changes", failures)
	_expect(mp_fill != null and _contains_color(mp_fill.texture.get_image(), PaletteLibrary.ACCENT["orange"]), "Chroma fill follows the active Chroma accent", failures)

	hud.queue_free()
	await process_frame
	_finish(failures)


func _contains_color(image: Image, expected: Color) -> bool:
	if image == null:
		return false
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).is_equal_approx(expected):
				return true
	return false


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PLAYER_HUD_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
