extends SceneTree


var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var player := Sprite2D.new()
	var attack_visual := Sprite2D.new()
	root.add_child(player)
	root.add_child(attack_visual)
	var context := PlayerAnimationContext.new()
	context.player = player
	context.player_attack_visual = attack_visual
	var is_dead := true
	context.player_dead_get = func() -> Variant: return is_dead
	var animation := PlayerAnimationComponent.new()
	player.visible = true
	attack_visual.visible = true
	animation.apply_frame(context)
	_expect(not player.visible and not attack_visual.visible, "palette/frame refresh cannot reveal the player after death begins", failures)
	player.visible = true
	attack_visual.visible = true
	animation.tick_coordinator_animation(context, 0.016)
	_expect(not player.visible and not attack_visual.visible, "a delayed animation tick keeps both player render layers hidden after death", failures)
	animation.free()
	root.free()
	_finish(failures)


func _watchdog() -> void:
	if not _finished:
		push_error("TEST_ABORTED: player death visibility smoke timed out")
		quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("PLAYER_DEATH_VISIBILITY_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
