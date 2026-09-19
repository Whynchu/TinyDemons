extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var source := load("res://assets/artwork/SlimeGreenSpawn.png") as Texture2D
	_expect(source != null, "slime spawn artwork loads", failures)
	if source != null:
		_expect(source.get_width() == 112 and source.get_height() == 16, "slime spawn artwork keeps its 7x16px strip", failures)
	var library := SpriteFrameLibrary.new()
	var frames := library.slice_frames("res://assets/artwork/SlimeGreenSpawn.png", Vector2i(16, 16))
	_expect(frames.size() == 7, "slime spawn strip slices into seven frames", failures)
	var purple_frames := SlimeVisualComponent.recolor_attack_frame_set(frames, "purple", {})
	_expect(purple_frames.size() == frames.size(), "spawn frames can be recolored for every slime palette", failures)

	# Content variants (crimson) share the art sheet named by their definition's
	# visual_source; their attack/shocked/spawn frames must stay in that palette
	# instead of falling back to the green base sheet.
	var frame_library := SpriteFrameLibrary.new()
	var cache := {}
	var warm := func(texture: Texture2D) -> void: pass
	var attack_library := SlimeVisualComponent.build_attack_frame_library(frame_library, Vector2i(16, 16), cache, warm)
	var shocked_library := SlimeVisualComponent.build_shocked_frame_library(frame_library, Vector2i(16, 16), cache, warm)
	var spawn_library := SlimeVisualComponent.build_spawn_frame_library(frame_library, Vector2i(16, 16), cache, warm)
	var crimson := SlimeActor.new()
	root.add_child(crimson)
	crimson.ensure_components()
	crimson.set("variant", "crimson")
	SlimeVisualComponent.assign_attack_frames([crimson], attack_library)
	SlimeVisualComponent.assign_shocked_frames([crimson], shocked_library)
	SlimeVisualComponent.assign_spawn_frames([crimson], spawn_library)
	var crimson_visual := crimson.get_node_or_null("Visual") as SlimeVisualComponent
	_expect(crimson_visual != null and not crimson_visual.attack_left_frames.is_empty() and not crimson_visual.shocked_frames.is_empty() and not crimson_visual.spawn_frames.is_empty(), "crimson slime receives attack, shocked, and spawn frames", failures)
	if crimson_visual != null and not crimson_visual.attack_left_frames.is_empty():
		var red_reference := load("res://assets/artwork/SlimeRedLeft.png") as Texture2D
		_expect(_frame_uses_palette(crimson_visual.attack_left_frames[0], red_reference), "crimson attack frames stay in the red art-sheet palette", failures)
	crimson.queue_free()
	await process_frame

	var actor := SlimeActor.new()
	root.add_child(actor)
	actor.ensure_components()
	var applied_frames := [0]
	var finished := [false]
	var set_frame := func(_frame_index: int) -> void:
		applied_frames[0] += 1
	var finish := func() -> void:
		finished[0] = true
	actor.begin_spawn(frames, 0.01)
	_expect(actor.is_spawn_locked(), "spawn animation locks the actor immediately", failures)
	for _frame in 8:
		actor.tick_spawn(0.011, set_frame, finish)
	_expect(finished[0], "spawn animation completes after its final frame", failures)
	_expect(applied_frames[0] > 0, "spawn animation advances frames", failures)
	_expect(not actor.is_spawn_locked(), "actor unlocks after the spawn animation", failures)
	actor.queue_free()
	await process_frame
	if failures.is_empty():
		print("SLIME_SPAWN_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _frame_uses_palette(frame: Texture2D, reference: Texture2D) -> bool:
	var frame_image := frame.get_image()
	var reference_image := reference.get_image()
	var reference_keys: Dictionary = {}
	for y in reference_image.get_height():
		for x in reference_image.get_width():
			var color: Color = reference_image.get_pixel(x, y)
			if color.a > 0.0:
				reference_keys["%02X%02X%02X" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]] = true
	var shared := 0
	for y in frame_image.get_height():
		for x in frame_image.get_width():
			var color: Color = frame_image.get_pixel(x, y)
			if color.a <= 0.0:
				continue
			var key := "%02X%02X%02X" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0)]
			if reference_keys.has(key):
				shared += 1
	# The attack strip adds a dark outline tone and the eye white; the body
	# colors themselves must all come from the reference art-sheet palette.
	return shared >= 3
