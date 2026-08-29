extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var manager := SoundManager.new()
	root.add_child(manager)
	await process_frame
	var profile := manager.get_mix_profile()
	_expect(profile != null, "live test loads the sound mix profile", failures)
	if profile == null:
		manager.free()
		_finish(failures)
		return

	var original_pause_db := float(profile.get("ui_pause_db"))
	manager.play("ui_pause")
	var pause_player := manager.get_node_or_null("SFX_ui_pause") as AudioStreamPlayer
	profile.set("ui_pause_db", original_pause_db - 3.0)
	await _wait_for_profile_poll()
	_expect(pause_player != null and is_equal_approx(pause_player.volume_db, original_pause_db - 3.0), "editing a SFX slider updates an active player", failures)
	profile.set("ui_pause_db", original_pause_db)

	manager.start_run_music()
	var original_run_music_db := float(profile.get("run_music_db"))
	profile.set("run_music_db", original_run_music_db - 3.0)
	await _wait_for_profile_poll()
	var music_player := manager.get_node_or_null("Music_Theme") as AudioStreamPlayer
	_expect(music_player != null and is_equal_approx(music_player.volume_db, original_run_music_db - 3.0), "editing the music slider updates active music", failures)
	profile.set("run_music_db", original_run_music_db)
	var fade_start_db := music_player.volume_db if music_player != null else 0.0
	manager.fade_out_music(0.60)
	await create_timer(0.15).timeout
	var fade_mid_db := music_player.volume_db if music_player != null else fade_start_db
	_expect(music_player != null and fade_mid_db < fade_start_db, "music fade lowers the active player before stopping", failures)
	_expect(music_player != null and music_player.playing, "music remains active during the fade", failures)
	await create_timer(0.60).timeout
	_expect(music_player != null and not music_player.playing, "music fade stops only after its duration", failures)

	manager.free()
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _wait_for_profile_poll() -> void:
	for _frame in 20:
		await process_frame


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SOUND_MIX_LIVE_RELOAD_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
