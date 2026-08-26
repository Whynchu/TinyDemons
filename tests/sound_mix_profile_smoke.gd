extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var manager := SoundManager.new()
	root.add_child(manager)
	await process_frame

	var profile := manager.get_mix_profile()
	_expect(profile != null, "sound mix profile loads", failures)
	if profile != null:
		_expect(profile.resource_path.ends_with("sound_mix_profile.tres"), "runtime uses the editor profile resource", failures)
		for sound_name in SoundManager.CLIPS.keys():
			_expect(bool(profile.call("has_volume_entry", StringName(sound_name))), "profile contains %s" % sound_name, failures)
		_expect(bool(profile.call("has_volume_entry", &"title_music")), "profile contains title music", failures)
		_expect(bool(profile.call("has_volume_entry", &"run_music")), "profile contains run music", failures)
		_expect(_in_slider_range(float(profile.get("title_music_db"))), "title music level stays inside the editor slider range", failures)
		_expect(_in_slider_range(float(profile.get("run_music_db"))), "run music level stays inside the editor slider range", failures)
		_expect(_in_slider_range(float(profile.get("ui_pause_db"))), "pause level stays inside the editor slider range", failures)
		_expect(_in_slider_range(float(profile.get("ui_unpause_db"))), "unpause level stays inside the editor slider range", failures)

	manager.free()
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _in_slider_range(value: float) -> bool:
	return is_finite(value) and value >= -80.0 and value <= 6.0


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SOUND_MIX_PROFILE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
