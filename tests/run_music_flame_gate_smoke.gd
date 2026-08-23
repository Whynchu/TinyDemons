extends SceneTree

const GameplayScript = preload("res://scripts/gameplay.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var gameplay := GameplayScript.new()
	var manager := SoundManager.new()
	root.add_child(manager)
	await process_frame

	gameplay.sound_manager = manager
	var run_state := RunState.new()
	run_state.active = true
	gameplay.run_state = run_state
	gameplay.starter_flame_attuned_this_run = false
	gameplay.call("_update_music_state")

	_expect(gameplay.music_track_wanted == &"", "run music remains gated before starter flame pickup", failures)
	_expect(manager.get_node_or_null("Music_Theme") == null, "Dungeon-Crawl does not create a music player before pickup", failures)

	gameplay.starter_flame_attuned_this_run = true
	gameplay.call("_update_music_state")
	var music_player := manager.get_node_or_null("Music_Theme") as AudioStreamPlayer
	_expect(gameplay.music_track_wanted == &"run", "run music becomes wanted after starter flame pickup", failures)
	_expect(music_player != null and music_player.stream != null and music_player.stream.resource_path.ends_with("Dungeon-Crawl.wav"), "Dungeon-Crawl starts after starter flame pickup", failures)

	gameplay.free()
	manager.free()
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN_MUSIC_FLAME_GATE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
