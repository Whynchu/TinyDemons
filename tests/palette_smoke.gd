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
	_expect(library.ACCENT["orange"] == Color8(255, 205, 117), "orange has a ground highlight", failures)
	_expect(library.ACCENT["aquamarine"] == Color8(134, 203, 255), "aquamarine has a light ice highlight", failures)
	_expect(library.accent("aquamarine").v > library.normal("aquamarine").v, "ice highlight is brighter than its base color", failures)
	_expect(library.ARCHETYPE_HIGHLIGHTS[0] == Color8(65, 166, 246), "archetype highlight blue is the accent blue", failures)
	for name: String in library.PALETTE_NAMES:
		_expect(library.NORMAL.has(name) and library.SHADOW.has(name), "palette %s has shadow and normal" % name, failures)
		var pair: Array[Color] = library.pair(name)
		var triple: Array[Color] = library.triple(name)
		_expect(pair[0] == library.SHADOW[name] and pair[1] == library.NORMAL[name], "pair() returns shadow/normal for %s" % name, failures)
		_expect(triple[0] == library.SHADOW[name] and triple[1] == library.NORMAL[name] and triple[2] == PaletteLibrary.WHITE, "triple() returns shadow/normal/white for %s" % name, failures)
		var fire: Array[Color] = library.fire_triple(name)
		_expect(fire.size() == 3, "fire_triple() returns three tones for %s" % name, failures)
		_expect(fire[0] == library.NORMAL[name], "fire_triple() uses NORMAL as the darkest flame tone for %s" % name, failures)
		_expect(_luma(fire[0]) < _luma(fire[1]) and _luma(fire[1]) < _luma(fire[2]), "fire_triple() tones ascend in brightness for %s" % name, failures)
		_expect(fire[2].r > fire[1].r or fire[2].g > fire[1].g or fire[2].b > fire[1].b, "fire_triple() brightens the tip for %s" % name, failures)
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
	var ability_art := Image.create(4, 1, false, Image.FORMAT_RGBA8)
	ability_art.set_pixel(0, 0, library.shadow("blue"))
	ability_art.set_pixel(1, 0, library.normal("blue"))
	ability_art.set_pixel(2, 0, library.accent("blue"))
	ability_art.set_pixel(3, 0, Color8(115, 239, 247))
	var ability_source := ImageTexture.create_from_image(ability_art)
	var green_ability := sprite_library.recolor_ability_icon(ability_source, "green")
	var green_ability_image := green_ability.get_image() if green_ability != null else null
	_expect(green_ability_image != null and green_ability_image.get_pixel(0, 0).is_equal_approx(library.shadow("green")), "green ability outline uses the green shadow", failures)
	_expect(green_ability_image != null and green_ability_image.get_pixel(1, 0).is_equal_approx(library.shadow("green")), "green ability base shifts down to the green shadow", failures)
	_expect(green_ability_image != null and green_ability_image.get_pixel(2, 0).is_equal_approx(library.normal("green")), "green ability highlight shifts down to the green normal", failures)
	_expect(green_ability_image != null and green_ability_image.get_pixel(3, 0).is_equal_approx(library.accent("green").lerp(library.WHITE, 0.35)), "green ability cyan highlight keeps the green accent headroom", failures)
	var yellow_ability := sprite_library.recolor_ability_icon(ability_source, "yellow")
	var yellow_ability_image := yellow_ability.get_image() if yellow_ability != null else null
	_expect(yellow_ability_image != null and yellow_ability_image.get_pixel(1, 0).is_equal_approx(library.shadow("yellow")), "yellow ability base shifts down to the yellow shadow", failures)
	_expect(yellow_ability_image != null and yellow_ability_image.get_pixel(2, 0).is_equal_approx(library.normal("yellow")), "yellow ability highlight shifts down to the yellow normal", failures)
	var red_ability := sprite_library.recolor_ability_icon(ability_source, "red")
	var red_ability_image := red_ability.get_image() if red_ability != null else null
	_expect(red_ability_image != null and red_ability_image.get_pixel(1, 0).is_equal_approx(library.normal("red")), "red ability base keeps the existing normal mapping", failures)
	_expect(red_ability_image != null and red_ability_image.get_pixel(2, 0).is_equal_approx(library.accent("red")), "red ability highlight keeps the existing accent mapping", failures)
	var equip := PlayerEquipmentVisualComponent.new()
	var art := Image.create(1, 4, false, Image.FORMAT_RGBA8)
	art.set_pixel(0, 0, Color8(255, 205, 117))
	art.set_pixel(0, 1, Color8(59, 93, 201))
	art.set_pixel(0, 2, Color8(148, 176, 194))
	art.set_pixel(0, 3, Color8(86, 108, 134))
	var art_texture := ImageTexture.create_from_image(art)
	var recolored_equip := equip._recolor_frame(art_texture, library.shadow("red"), library.normal("red"))
	var result_image := recolored_equip.get_image()
	_expect(result_image.get_pixel(0, 0) == Color8(255, 205, 117), "sword gold gem is left alone", failures)
	_expect(result_image.get_pixel(0, 1) == library.normal("red"), "sword blue gem maps to player color", failures)
	var light_result: Color = result_image.get_pixel(0, 2)
	var light_original := Color8(148, 176, 194)
	_expect(light_result.r + light_result.g + light_result.b > light_original.r + light_original.g + light_original.b, "sword light grey highlight brightens", failures)
	_expect(light_result.g > light_original.g and light_result.b > light_original.b, "sword light grey stays grey (no player tint)", failures)
	var mid_result: Color = result_image.get_pixel(0, 3)
	var mid_original := Color8(86, 108, 134)
	_expect(mid_result != mid_original, "sword mid grey is tinted toward the player color", failures)
	equip.queue_free()
	art_texture = null
	recolored_equip = null
	var glyphs := EffectsSpawner.new()
	var o_texture := glyphs.number_texture("o", Color.WHITE) as Texture2D
	var g_texture := glyphs.number_texture("g", Color.WHITE) as Texture2D
	var O_texture := glyphs.number_texture("O", Color.WHITE) as Texture2D
	_expect(o_texture != null and o_texture.get_width() > 0, "lowercase 'o' glyph renders non-empty", failures)
	_expect(g_texture != null and g_texture.get_width() > 0, "lowercase 'g' glyph renders non-empty", failures)
	_expect(o_texture != null and O_texture != null and o_texture.get_image().get_data() != O_texture.get_image().get_data(), "lowercase 'o' differs from uppercase 'O'", failures)
	var name_o := glyphs.name_texture("o", Color.WHITE) as Texture2D
	var name_g := glyphs.name_texture("g", Color.WHITE) as Texture2D
	var name_o_caps := glyphs.name_texture("O", Color.WHITE) as Texture2D
	var name_l := glyphs.name_texture("l", Color.WHITE) as Texture2D
	var name_i := glyphs.name_texture("i", Color.WHITE) as Texture2D
	_expect(name_o != null and name_o.get_width() > 0, "name texture lowercase 'o' renders non-empty", failures)
	_expect(name_g != null and name_g.get_width() > 0, "name texture lowercase 'g' renders non-empty", failures)
	_expect(name_o != null and name_o_caps != null and name_o.get_image().get_data() != name_o_caps.get_image().get_data(), "name texture lowercase 'o' differs from uppercase 'O'", failures)
	_expect(name_l != null and name_l.get_width() <= 3, "name texture lowercase 'l' uses a narrow natural width", failures)
	_expect(name_i != null and name_i.get_width() <= 3, "name texture lowercase 'i' uses a narrow natural width", failures)
	for character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz":
		var damage_glyph := glyphs.number_texture(character, Color.WHITE) as Texture2D
		var name_glyph := glyphs.name_texture(character, Color.WHITE) as Texture2D
		_expect(_has_opaque_pixel(damage_glyph), "damage glyph '%s' renders" % character, failures)
		_expect(_has_opaque_pixel(name_glyph), "name glyph '%s' renders" % character, failures)
	_expect(_has_opaque_pixel(glyphs.number_texture("electric", Color.WHITE)), "lowercase electric text renders without fallback glyphs", failures)
	_expect(_has_opaque_pixel(glyphs.name_texture("Electric Slime", Color.WHITE)), "Electric Slime name renders without fallback glyphs", failures)
	_expect(_has_opaque_pixel(glyphs.name_texture("Water Slime", Color.WHITE)), "Water Slime name renders without fallback glyphs", failures)
	var touch_prompt := glyphs.prompt_texture("TAP", Color.BLACK) as Texture2D
	var compact_prompt := glyphs.number_texture("TAP", Color.WHITE) as Texture2D
	_expect(_has_opaque_pixel(touch_prompt) and touch_prompt.get_height() == 7, "touch prompt uses the readable name glyph height", failures)
	_expect(touch_prompt.get_width() > compact_prompt.get_width(), "touch prompt uses the wider readable glyph set", failures)
	_expect(touch_prompt.get_image().get_pixel(0, 0) == Color.BLACK, "touch prompt uses black glyph fill for a white outline", failures)
	var keyboard_prompt := glyphs.keyboard_prompt_texture("E") as Texture2D
	var keyboard_image := keyboard_prompt.get_image() if keyboard_prompt != null else null
	_expect(keyboard_prompt != null and keyboard_prompt.get_width() > 5 and keyboard_prompt.get_height() == 11, "keyboard prompt adds a readable keycap", failures)
	_expect(keyboard_image != null and keyboard_image.get_pixel(0, 0) == Color.BLACK, "keyboard prompt keycap has a black background", failures)
	_expect(keyboard_image != null and keyboard_image.get_pixel(2, 2) == Color.WHITE, "keyboard prompt keycap keeps white lettering", failures)
	glyphs.free()
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


func _luma(color: Color) -> float:
	return color.r * 0.299 + color.g * 0.587 + color.b * 0.114


func _has_opaque_pixel(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	if image == null:
		return false
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				return true
	return false
