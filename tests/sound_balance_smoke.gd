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
	_expect(music_player != null and music_player.stream != null and (music_player.stream.resource_path.ends_with("Dungeon-Crawl.wav") or music_player.stream.resource_path.ends_with("Dungeon-Crawl.ogg")), "Dungeon-Crawl run track loads from the source or compact web variant", failures)
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
	var expected_menu_clips := {
		"ui_pause": "Blip.wav",
		"ui_hover": "CursorMove.wav",
		"ui_confirm": "Confirm.wav",
		"ui_decline": "BACK.wav",
		"ui_no_input": "NOINPUT.wav",
		"charge_attack": "ChargedAttackwav.wav",
		"use_flame": "UseFlame.wav",
		"slime_spawn": "SlimeSpawn.wav",
		"slime_move": "SlimeMove.wav",
	}
	for sound_name in expected_menu_clips:
		var expected_filename: String = String(expected_menu_clips[sound_name])
		var clip_path: String = String(SoundManager.CLIPS.get(sound_name, ""))
		_expect(clip_path.ends_with(expected_filename), "%s routes to %s" % [sound_name, expected_filename], failures)
		if sound_name not in ["ui_no_input", "use_flame", "slime_spawn", "slime_move"]:
			_expect(clip_path.contains("Selfmade FX/Reverb/"), "%s routes through the reverb selfmade set" % sound_name, failures)
		manager.play(sound_name)
		var player := manager.get_node_or_null("SFX_%s" % sound_name) as AudioStreamPlayer
		_expect(player != null and player.stream != null, "%s loads its selfmade stream" % sound_name, failures)
		if profile != null and profile.has_method("get") and profile.get("%s_db" % sound_name) != null:
			_expect(player != null and is_equal_approx(player.volume_db, float(profile.get("%s_db" % sound_name))), "%s uses the editor profile level" % sound_name, failures)
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
