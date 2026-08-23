extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var manager := SoundManager.new()
	root.add_child(manager)
	await process_frame
	_expect(SoundManager.TITLE_MUSIC_PATH.ends_with("digital_forever.mp3"), "title music uses digital_forever", failures)
	var profile := manager.get_mix_profile()
	manager.start_music()
	var music_player := manager.get_node_or_null("Music_Theme") as AudioStreamPlayer
	_expect(music_player != null and music_player.stream != null, "digital_forever title track loads", failures)
	_expect(music_player != null and profile != null and is_equal_approx(music_player.volume_db, float(profile.get("title_music_db"))), "digital_forever title track uses the editor profile level", failures)
	manager.start_run_music()
	_expect(SoundManager.RUN_MUSIC_PATH.ends_with("Dungeon-Crawl.wav"), "run music uses Dungeon-Crawl", failures)
	_expect(music_player != null and music_player.stream != null and music_player.stream.resource_path.ends_with("Dungeon-Crawl.wav"), "Dungeon-Crawl run track loads", failures)
	_expect(music_player != null and profile != null and is_equal_approx(music_player.volume_db, float(profile.get("run_music_db"))), "Dungeon-Crawl uses the editor profile level", failures)
	manager.stop_music()
	manager.play("ui_pause")
	var pause_player := manager.get_node_or_null("SFX_ui_pause") as AudioStreamPlayer
	_expect(pause_player != null and profile != null and is_equal_approx(pause_player.volume_db, float(profile.get("ui_pause_db"))), "pause cue uses the editor profile level", failures)
	manager.play("ui_unpause")
	var unpause_player := manager.get_node_or_null("SFX_ui_unpause") as AudioStreamPlayer
	_expect(unpause_player != null and profile != null and is_equal_approx(unpause_player.volume_db, float(profile.get("ui_unpause_db"))), "unpause cue uses the editor profile level", failures)
	manager.play("ui_hover")
	var hover_player := manager.get_node_or_null("SFX_ui_hover") as AudioStreamPlayer
	_expect(hover_player != null and profile != null and is_equal_approx(hover_player.volume_db, float(profile.get("ui_hover_db"))), "hover cue uses the editor profile level", failures)
	manager.free()
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SOUND_BALANCE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
