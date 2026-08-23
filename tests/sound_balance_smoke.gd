extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var manager := SoundManager.new()
	root.add_child(manager)
	await process_frame
	manager.play("ui_pause")
	var pause_player := manager.get_node_or_null("SFX_ui_pause") as AudioStreamPlayer
	_expect(pause_player != null and is_equal_approx(pause_player.volume_db, -8.0), "pause cue receives its mastering trim", failures)
	manager.play("ui_unpause")
	var unpause_player := manager.get_node_or_null("SFX_ui_unpause") as AudioStreamPlayer
	_expect(unpause_player != null and is_equal_approx(unpause_player.volume_db, -6.0), "unpause cue receives its mastering trim", failures)
	manager.play("ui_hover")
	var hover_player := manager.get_node_or_null("SFX_ui_hover") as AudioStreamPlayer
	_expect(hover_player != null and is_equal_approx(hover_player.volume_db, 0.0), "quiet UI cues keep their requested level", failures)
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
