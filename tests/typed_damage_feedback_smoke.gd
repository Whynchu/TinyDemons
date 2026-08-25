extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var effects := EffectsSpawner.new()
	var parent := Node.new()
	var pixel_number := Callable(effects, "number_texture")
	var snap_position := Callable(self, "_identity")

	for element in range(ElementCatalogScript.ELEMENT_COUNT):
		var color := ElementCatalogScript.damage_number_color(element)
		var texture := effects.number_texture("7", color)
		_expect(_contains_color(texture, color), "element %s damage glyph uses its accent color" % ElementCatalogScript.id(element), failures)

	effects.spawn_health_number(parent, Vector2.ZERO, 7, Vector2.ZERO, true, false, PaletteLibrary.accent("red"), pixel_number, snap_position, 1.0, 0.1)
	var critical_entry := effects.damage_numbers[0] as Dictionary
	var critical_sprite := critical_entry["sprite"] as Sprite2D
	var critical_outline := critical_entry["outline"] as Sprite2D
	_expect(critical_sprite != null and _contains_color(critical_sprite.texture, PaletteLibrary.accent("red")), "critical interior keeps the original Fire color", failures)
	_expect(critical_outline != null and _contains_color(critical_outline.texture, Color.WHITE), "critical number creates a white outline", failures)
	_expect(critical_sprite != null and critical_outline != null and critical_sprite.texture.get_width() < critical_outline.texture.get_width(), "critical outline extends beyond the glyph", failures)

	var normal_critical_color := ElementCatalogScript.damage_number_color(ElementCatalogScript.Element.NEUTRAL, true)
	effects.spawn_health_number(parent, Vector2.ZERO, 7, Vector2.ZERO, true, false, normal_critical_color, pixel_number, snap_position, 1.0, 0.1)
	var normal_critical_entry := effects.damage_numbers[1] as Dictionary
	var normal_critical_sprite := normal_critical_entry["sprite"] as Sprite2D
	var normal_critical_outline := normal_critical_entry["outline"] as Sprite2D
	_expect(normal_critical_sprite != null and _contains_color(normal_critical_sprite.texture, Color.BLACK), "Normal critical interior is black", failures)
	_expect(normal_critical_outline != null and _contains_color(normal_critical_outline.texture, Color.WHITE), "Normal critical keeps the white outline", failures)

	effects.spawn_health_number(parent, Vector2.ZERO, 0, Vector2.ZERO, false, false, PaletteLibrary.accent("blue"), pixel_number, snap_position, 1.0, 0.1, "immune")
	var immune_entry := effects.damage_numbers[2] as Dictionary
	var immune_sprite := immune_entry["sprite"] as Sprite2D
	_expect(immune_sprite != null and _contains_color(immune_sprite.texture, PaletteLibrary.accent("blue")), "immune floater uses the attack element color", failures)
	_expect((immune_entry.get("outline") as Sprite2D) == null, "immune floater is not marked critical", failures)

	var healing_color := Color8(177, 62, 83)
	effects.spawn_health_number(parent, Vector2.ZERO, 3, Vector2.ZERO, false, true, healing_color, pixel_number, snap_position, 1.0, 0.1)
	var healing_entry := effects.damage_numbers[3] as Dictionary
	var healing_sprite := healing_entry["sprite"] as Sprite2D
	_expect(healing_sprite != null and _contains_color(healing_sprite.texture, healing_color), "healing keeps its existing color channel", failures)

	parent.free()
	effects.free()
	_finished = true
	call_deferred("_finish", failures)


func _contains_color(texture: Texture2D, expected: Color) -> bool:
	if texture == null:
		return false
	var image := texture.get_image()
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0 and color.is_equal_approx(expected):
				return true
	return false


func _identity(value: Vector2) -> Vector2:
	return value


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: typed damage feedback smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TYPED_DAMAGE_FEEDBACK_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
