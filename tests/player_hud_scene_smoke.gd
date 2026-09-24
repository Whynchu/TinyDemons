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
	var authored_track_widths := [34.0, 62.0, 46.0]
	for index in fills.size():
		var fill := fills[index] as Sprite2D
		_expect(fill != null and fill.texture != null and fill.texture.get_size().is_equal_approx(Vector2(82, 16)), "player bar uses the full-strip fill source", failures)
		var expected_source_width: float = 17.0 + float(authored_track_widths[index])
		_expect(fill != null and fill.region_enabled and is_equal_approx(fill.region_rect.size.x, expected_source_width) and is_equal_approx(fill.region_rect.size.y, 16.0), "player bar clips to its authored active track", failures)
		_expect(fill != null and is_equal_approx(float(fill.get_meta("fill_track_start_x", -1.0)), 17.0) and is_equal_approx(float(fill.get_meta("fill_track_width", -1.0)), authored_track_widths[index]), "player bar exposes its authored track geometry", failures)

	var hud_controller := HudController.new()
	root.add_child(hud_controller)
	var half_widths := [34.0, 48.0, 40.0]
	for index in fills.size():
		var fill := fills[index] as Sprite2D
		hud_controller.set_fill_ratio(fill, Vector2(82, 16), 0.5)
		_expect(fill != null and is_equal_approx(fill.region_rect.size.x, half_widths[index]), "player bar uses a linear half-fill for its authored track", failures)
		hud_controller.set_fill_ratio(fill, Vector2(82, 16), 1.0)
		_expect(fill != null and is_equal_approx(fill.region_rect.size.x, 17.0 + authored_track_widths[index]), "player bar reaches the authored track edge at full", failures)

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

	for path in [
		"SoulDisplay/SoulIcon",
		"SoulDisplay/SoulAmount",
		"PlayerStatus/Mana/MpBarHighlight",
		"InventoryChest",
		"InventoryChestReceiving",
		"InputPrompts/TrianglePrompt",
		"InputPrompts/SquarePrompt",
		"InputPrompts/XPrompt",
		"InputPrompts/CirclePrompt",
		"AbilityIcons/MagicCooldownIcon/TrianglePromptMagic",
		"AbilityIcons/ImbueCooldownIcon/TrianglePromptImbue",
		"AbilityIcons/MagicCooldownIcon",
		"AbilityIcons/MagicCooldownTimerShadow",
		"AbilityIcons/MagicCooldownTimer",
		"AbilityIcons/ImbueCooldownIcon",
		"AbilityIcons/ImbueCooldownTimerShadow",
		"AbilityIcons/ImbueCooldownTimer",
		"ComboHud/ComboLabel",
		"ComboHud/ComboBase",
		"ComboHud/ComboFill",
		"TargetHud/TargetHealthText",
		"TargetHud/FocusLabelBase",
		"TargetHud/FocusLabel",
	]:
		var authored := hud.get_node_or_null(path) as Sprite2D
		_expect(authored != null, "%s is authored in the player HUD scene" % path, failures)
	var inventory_chest := hud.get_node_or_null("InventoryChest") as Sprite2D
	var inventory_chest_receiving := hud.get_node_or_null("InventoryChestReceiving") as Sprite2D
	_expect(inventory_chest != null and inventory_chest.texture != null and inventory_chest.texture.resource_path.ends_with("ChestGrey.png"), "inventory chest starts with the idle artwork", failures)
	_expect(inventory_chest_receiving != null and inventory_chest_receiving.texture != null and inventory_chest_receiving.texture.resource_path.ends_with("Chest.png"), "inventory chest has a receiving artwork layer", failures)
	_expect(inventory_chest_receiving != null and not inventory_chest_receiving.visible, "inventory chest receiving layer starts hidden", failures)
	_expect(inventory_chest != null and inventory_chest.position.is_equal_approx(Vector2(190, 2)), "inventory chest keeps its authored HUD position", failures)
	var mp_highlight := hud.get_node_or_null("PlayerStatus/Mana/MpBarHighlight") as Sprite2D
	_expect(mp_highlight != null and not mp_highlight.visible and mp_highlight.z_index < (fills[2] as Sprite2D).z_index, "Chroma highlight layer starts hidden behind the MP fill", failures)
	if mp_highlight != null and fills[2] != null:
		hud_controller.set_chroma_bar_values(fills[2] as Sprite2D, mp_highlight, Vector2(82, 16), 40.0, 20.0, 100.0)
		_expect(is_equal_approx((fills[2] as Sprite2D).region_rect.size.x, 26.0), "Chroma regular fill stays at the displayed value while gaining", failures)
		_expect(is_equal_approx(mp_highlight.region_rect.size.x, 35.0) and mp_highlight.visible, "Chroma gain highlights only the newly filled segment", failures)
		hud_controller.set_chroma_bar_values(fills[2] as Sprite2D, mp_highlight, Vector2(82, 16), 40.0, 40.0, 100.0)
		_expect(not mp_highlight.visible, "Chroma highlight hides when the regular fill catches up", failures)
	var target_health_text := hud.get_node_or_null("TargetHud/TargetHealthText") as Sprite2D
	_expect(target_health_text != null and target_health_text.z_index > 3, "enemy health text is above the health-bar layers", failures)
	var target := Sprite2D.new()
	var target_bar := Sprite2D.new()
	var target_fill := Sprite2D.new()
	var target_damage_fill := Sprite2D.new()
	var target_name := Sprite2D.new()
	var target_number := Sprite2D.new()
	target_bar.texture = load("res://assets/artwork/EnemyHp.png") as Texture2D
	target_bar.centered = false
	target_bar.position = Vector2(81.0, 147.0)
	target_fill.texture = load("res://assets/artwork/EnemyHpGreenBar.png") as Texture2D
	target_damage_fill.texture = target_fill.texture
	var target_bar_center := target_bar.position + target_bar.texture.get_size() * 0.5
	hud_controller.target_health_fill_textures.clear()
	hud_controller.target_health_damage_fill_textures.clear()
	hud_controller.update_target_ui(
		target,
		target_name,
		target_bar,
		target_damage_fill,
		target_fill,
		target_number,
		Vector2.ZERO,
		Callable(self, "_target_display_name"),
		Callable(self, "_target_max_health"),
		Callable(self, "_target_health"),
		Callable(self, "_target_display_health"),
		Callable(self, "_target_text_texture"),
		Callable(self, "_target_text_texture"),
		Callable(hud_controller, "set_health_bar_values"))
	_expect(target_fill.texture.resource_path.ends_with("EnemyHpRedBar.png"), "a target without a cached entry uses the canonical red health fill", failures)
	_expect(target_damage_fill.texture != null and not target_damage_fill.texture.resource_path.ends_with("EnemyHpGreenBar.png"), "a target without a cached entry uses the canonical damage fill", failures)
	_expect(target_number.centered and target_number.position.is_equal_approx(target_bar_center), "target health text is centered on the visible bar", failures)

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
	var portrait := hud.get_node_or_null("PlayerStatus/Portrait") as Sprite2D
	var portrait_source := portrait.texture if portrait != null else null
	var portrait_library := SpriteFrameLibrary.new()
	hud.call("apply_portrait_palette", "red", portrait_library)
	_expect(portrait != null and portrait.texture != portrait_source, "portrait recolors when the player palette changes", failures)
	_expect(portrait != null and _contains_color(portrait.texture.get_image(), PaletteLibrary.NORMAL["red"]), "portrait uses the active palette color", failures)
	hud.call("apply_portrait_palette", "green", portrait_library)
	_expect(portrait != null and _contains_color(portrait.texture.get_image(), PaletteLibrary.SHADOW["green"]), "green portrait uses the green shadow as its base", failures)
	hud.call("apply_portrait_palette", "yellow", portrait_library)
	_expect(portrait != null and _contains_color(portrait.texture.get_image(), PaletteLibrary.SHADOW["yellow"]), "yellow portrait uses the yellow shadow as its base", failures)

	hud.queue_free()
	hud_controller.queue_free()
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


func _target_display_name(_target: Sprite2D) -> String:
	return "SLIME"


func _target_max_health(_target: Sprite2D) -> float:
	return 10.0


func _target_health(_target: Sprite2D) -> float:
	return 7.0


func _target_display_health(_target: Sprite2D) -> float:
	return 7.0


func _target_text_texture(_text: String, _color: Color) -> Texture2D:
	return load("res://assets/artwork/EnemyHpRedBar.png") as Texture2D
