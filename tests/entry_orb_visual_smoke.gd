extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var library := SpriteFrameLibrary.new()
	var source := library.slice_frames("res://assets/artwork/entrance_orb.png", Vector2i(9, 9))
	_expect(source.size() == 6, "orb sheet contains six 9x9 source frames", failures)
	if source.is_empty():
		_finish(failures)
		return
	var recolored := library.recolor_orb_frames(source, "grey")
	_expect(recolored.size() == 6, "orb recolor preserves one texture per animation frame", failures)
	if recolored.size() == 6:
		var first := recolored[0].get_image()
		var authored_first := source[0].get_image()
		var twinkle := recolored[3].get_image()
		_expect(_images_equal(first, authored_first), "grey orb uses the authored artwork without an added tint", failures)
		_expect(_images_different(first, twinkle), "orb animation retains its twinkle frame changes", failures)
		var renderer := OcclusionRenderer.new()
		var highlighted := renderer.make_orb_highlighted_effect_image(first)
		_expect(highlighted.get_size() == Vector2i(22, 22), "orb highlight adds a one-pixel border around the 9x9 art", failures)
		_expect(highlighted.get_pixel(0, 8).a > 0.05, "orb highlight reaches the left silhouette", failures)
		_expect(highlighted.get_pixel(21, 8).a > 0.05, "orb highlight reaches the right silhouette", failures)
		_expect(highlighted.get_pixel(10, 0).a > 0.05, "orb highlight reaches the top silhouette", failures)
		_expect(highlighted.get_pixel(10, 21).a > 0.05, "orb highlight reaches the bottom silhouette", failures)
	_finish(failures)


func _images_equal(left: Image, right: Image) -> bool:
	if left.get_size() != right.get_size():
		return false
	for y in left.get_height():
		for x in left.get_width():
			if left.get_pixel(x, y) != right.get_pixel(x, y):
				return false
	return true


func _images_different(left: Image, right: Image) -> bool:
	if left.get_size() != right.get_size():
		return true
	for y in left.get_height():
		for x in left.get_width():
			if left.get_pixel(x, y) != right.get_pixel(x, y):
				return true
	return false


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENTRY_ORB_VISUAL_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
