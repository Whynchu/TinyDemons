extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var effects := EffectsSpawner.new()
	for character in ["o", "g", "e", "y"]:
		var texture := effects.number_texture(character, Color.WHITE)
		var image := texture.get_image() if texture != null else null
		_expect(image != null and image.get_width() >= 4 and _opaque_pixel_count(image) >= 4, "lowercase %s keeps a readable rounded/descending shape" % character, failures)

	var screen := ScreenStateController.new()
	var catalog := ItemCatalog.new()
	var longest_description := ""
	var longest_line_count := 0
	for definition_id: StringName in catalog.DEFINITIONS:
		var item := ItemInstance.new()
		item.definition_id = definition_id
		item.rarity = &"common"
		var description := catalog.player_description(item)
		var lines := screen.call("_wrap_gear_text", description, 34) as Array
		if lines.size() > longest_line_count:
			longest_line_count = lines.size()
			longest_description = String(definition_id)
		_expect(lines.size() <= 4, "%s description fits the four-line detail viewport" % definition_id, failures)
	var long_word_lines := screen.call("_wrap_gear_text", "A supercalifragilisticexpialidocious effect.", 34) as Array
	_expect(long_word_lines.size() >= 2 and long_word_lines.all(func(line: String) -> bool: return line.length() <= 34), "overlong description words wrap instead of clipping", failures)
	_expect(longest_line_count > 0 and not longest_description.is_empty(), "catalogue descriptions are included in the bounded text audit", failures)

	effects.free()
	screen.free()
	_finished = true
	call_deferred("_finish", failures)


func _opaque_pixel_count(image: Image) -> int:
	var count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				count += 1
	return count


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: menu text smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("MENU_TEXT_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
