extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var library := PaletteLibrary
	_expect(library.PALETTE_NAMES.size() == 8, "palette library exposes all eight palettes", failures)
	_expect(library.NORMAL["blue"] == Color8(59, 93, 201), "blue normal is the canonical player blue", failures)
	_expect(library.SHADOW["blue"] == Color8(41, 54, 111), "blue shadow is the canonical dark blue", failures)
	_expect(library.ACCENT["blue"] == Color8(65, 166, 246), "blue accent is the canonical bright blue", failures)
	_expect(library.ARCHETYPE_HIGHLIGHTS[0] == Color8(65, 166, 246), "archetype highlight blue is the accent blue", failures)
	for name: String in library.PALETTE_NAMES:
		_expect(library.NORMAL.has(name) and library.SHADOW.has(name), "palette %s has shadow and normal" % name, failures)
		var pair: Array[Color] = library.pair(name)
		var triple: Array[Color] = library.triple(name)
		_expect(pair[0] == library.SHADOW[name] and pair[1] == library.NORMAL[name], "pair() returns shadow/normal for %s" % name, failures)
		_expect(triple[0] == library.SHADOW[name] and triple[1] == library.NORMAL[name] and triple[2] == PaletteLibrary.WHITE, "triple() returns shadow/normal/white for %s" % name, failures)
	for palette_name in ["red", "blue", "purple"]:
		var original := Color8(56, 183, 100)
		var shadow_mapped := SlimeVisualComponent._palette_color(original, "257179", palette_name)
		var normal_mapped := SlimeVisualComponent._palette_color(original, "38B764", palette_name)
		var accent_mapped := SlimeVisualComponent._palette_color(original, "A7F070", palette_name)
		_expect(shadow_mapped == library.shadow(palette_name), "slime shadow key maps to canonical shadow for %s" % palette_name, failures)
		_expect(normal_mapped == library.normal(palette_name), "slime normal key maps to canonical normal for %s" % palette_name, failures)
		_expect(accent_mapped == library.accent(palette_name), "slime accent key maps to canonical accent for %s" % palette_name, failures)
	var unknown_palette := SlimeVisualComponent._palette_color(Color8(56, 183, 100), "38B764", "green")
	_expect(unknown_palette == Color8(56, 183, 100), "slime palette mapping leaves undefined palettes untouched", failures)
	var sprite_library := SpriteFrameLibrary.new()
	var source := ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	var recolored := sprite_library.recolor_texture(source, "red")
	_expect(recolored != null, "sprite library recolors from the canonical palette", failures)
	var equip := PlayerEquipmentVisualComponent.new()
	var art := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	art.set_pixel(0, 0, Color8(255, 205, 117))
	art.set_pixel(0, 1, Color8(59, 93, 201))
	art.set_pixel(0, 2, Color8(148, 176, 194))
	art.set_pixel(0, 3, Color8(86, 108, 134))
	var art_texture := ImageTexture.create_from_image(art)
	var recolored_equip := equip._recolor_frame(art_texture, library.shadow("red"), library.normal("red"), "red")
	var result_image := recolored_equip.get_image()
	_expect(result_image.get_pixel(0, 0) == Color8(255, 205, 117), "sword gold gem is left alone", failures)
	_expect(result_image.get_pixel(0, 1) == library.normal("red"), "sword blue gem maps to player color", failures)
	var light_result: Color = result_image.get_pixel(0, 2)
	var light_original := Color8(148, 176, 194)
	_expect(light_result.r + light_result.g + light_result.b > light_original.r + light_original.g + light_original.b, "sword light grey highlight brightens", failures)
	var mid_result: Color = result_image.get_pixel(0, 3)
	var mid_original := Color8(86, 108, 134)
	_expect(mid_result != mid_original, "sword mid grey is tinted toward the player color", failures)
	equip.queue_free()
	art_texture = null
	recolored_equip = null
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: palette smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PALETTE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)