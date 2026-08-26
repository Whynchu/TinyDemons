extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := PlayerTuning.new()
	var m := CombatMomentumComponent.new()
	m.configure(tuning)

	_expect(is_equal_approx(m.focus_multiplier(false), 1.0), "no target is baseline", failures)
	m.on_target_changed(true)
	_expect(m.focus_active, "locking a target activates focus", failures)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_bonus), "focus bonus inside window", failures)
	m.tick(1.0, true)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_bonus), "focus still active before window elapses", failures)
	m.tick(tuning.focus_window - 1.0, true)
	_expect(not m.focus_active, "focus lost once window elapses", failures)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_penalty), "focus penalty after window", failures)
	m.on_target_changed(false)
	_expect(not m.focus_active, "untargeting clears focus", failures)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_penalty), "penalty persists when no target locked", failures)
	m.on_target_changed(true)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_bonus), "retarget resets the focus window", failures)
	m.tick(999.0, true)
	_expect(is_equal_approx(m.focus_multiplier(true), 1.0 + tuning.focus_penalty), "long hold falls to penalty", failures)
	m.on_target_changed(false)
	m.on_target_changed(true)

	_expect(is_equal_approx(m.combo_multiplier(), 1.0), "combo starts neutral", failures)
	m.register_hit()
	_expect(is_equal_approx(m.combo_multiplier(), 1.0 + tuning.combo_damage_per_hit), "one hit grants one step", failures)
	for i in 8:
		m.register_hit()
	_expect(is_equal_approx(m.combo_multiplier(), 1.0 + tuning.combo_damage_cap), "combo caps at configured ceiling", failures)
	m.tick(tuning.combo_hit_window, true)
	_expect(is_equal_approx(m.combo_multiplier(), 1.0), "combo decays to neutral after window", failures)
	m.register_hit()
	m.register_hit()
	m.reset_combo()
	_expect(is_equal_approx(m.combo_multiplier(), 1.0), "reset clears the combo", failures)

	var spawner := EffectsSpawner.new()
	var focus_texture := spawner.number_texture("FOCUS", Color.WHITE)
	_expect(focus_texture != null, "FOCUS renders through the pixel text glyph set", failures)
	if focus_texture != null:
		var focus_image := focus_texture.get_image()
		var has_pixel := false
		for y in focus_image.get_height():
			for x in focus_image.get_width():
				if focus_image.get_pixel(x, y).a > 0.0:
					has_pixel = true
					break
			if has_pixel:
				break
		_expect(has_pixel, "FOCUS texture is not blank (all letters have glyphs)", failures)
	spawner.free()

	var renderer := OcclusionRenderer.new()
	renderer.resolution_scale = 1
	var src := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	src.fill(Color(0, 0, 0, 0))
	for y in [1, 2]:
		for x in [1, 2]:
			src.set_pixel(x, y, Color(1, 1, 1, 1))
	var white_img := renderer.make_highlighted_effect_image(src)
	var grey_img := renderer.make_grey_highlighted_effect_image(src)
	var white_outline_found := false
	var grey_outline_found := false
	for y in 4:
		for x in 4:
			var wp: Color = white_img.get_pixel(x, y)
			var gp: Color = grey_img.get_pixel(x, y)
			if wp.a > 0.0 and wp.r > 0.9 and wp.g > 0.9 and wp.b > 0.9:
				white_outline_found = true
			if gp.a > 0.0 and gp.r < 0.7 and gp.g < 0.7 and gp.b < 0.7:
				grey_outline_found = true
	_expect(white_outline_found, "white highlight outline is white", failures)
	_expect(grey_outline_found, "focus-lost highlight outline is grey", failures)
	renderer.free()

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: combat momentum smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("COMBAT_MOMENTUM_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
