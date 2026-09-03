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
