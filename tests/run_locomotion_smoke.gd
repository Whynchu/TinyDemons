extends SceneTree

## Characterizes the hold-to-run roll continuation:
## after a roll dodge, keeping the roll button held while moving runs instead
## of walking, at a speed nearly as fast as rolling, using the TINYDEMON run
## sheet with no sword/shield equipment layers.

var _captured_motion := Vector2.ZERO


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for run locomotion coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame

	var anim := gameplay.get("player_animation_component") as PlayerAnimationComponent
	var player := gameplay.get("player") as Sprite2D
	_expect(anim != null and player != null, "player animation component and sprite are composed", failures)
	if anim == null or player == null:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return
	_expect((anim.run_frames as Array[Texture2D]).size() == 4, "TinyDemon-run sheet slices into four 36x36 frames", failures)
	if (anim.run_frames as Array[Texture2D]).is_empty():
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return

	# Locomotion resolution priority: defend > run > walk > idle.
	gameplay.set("player_is_running", true)
	gameplay.set("player_is_moving", true)
	gameplay.set("player_is_defending", false)
	_expect(anim.movement_anim_name(gameplay) == "run", "holding roll while moving after a dodge resolves the run animation", failures)
	gameplay.set("player_is_running", false)
	_expect(anim.movement_anim_name(gameplay) == "walk", "moving without the run latch resolves the walk animation", failures)
	gameplay.set("player_is_running", true)
	gameplay.set("player_is_defending", true)
	_expect(anim.movement_anim_name(gameplay) == "defend", "defending takes priority over the run animation", failures)
	gameplay.set("player_is_defending", false)

	# apply_frame renders the authored run frame on the base player sprite.
	gameplay.set("player_anim_name", "run")
	gameplay.set("player_anim_frame", 1)
	gameplay.set("player_is_rolling", false)
	gameplay.set("player_is_attacking", false)
	anim.apply_frame(gameplay)
	_expect(player.texture == (anim.run_frames as Array[Texture2D])[1], "apply_frame renders the requested run frame", failures)

	var motor := gameplay.get("player_motor") as ActorMotor
	var router := gameplay.get("input_router") as InputRouter
	var tuning := gameplay.get("player_tuning") as PlayerTuning
	_expect(motor != null and router != null and tuning != null, "motor, input router, and tuning are composed", failures)
	if motor != null and router != null and tuning != null:
		router.set("_movement", Vector2.RIGHT)
		motor.knockback_remaining = 0.0
		gameplay.set("player_hitstun_timer", 0.0)
		gameplay.set("player_death_pending", false)
		gameplay.set("player_is_attacking", false)
		gameplay.set("player_is_magic_casting", false)
		gameplay.set("player_is_rolling", false)
		gameplay.set("player_is_defending", false)
		gameplay.set("player_is_targeting", false)
		var on_motion := func(motion: Vector2) -> void: _captured_motion = motion
		motor.motion_requested.connect(on_motion)
		gameplay.set("player_roll_input_held", true)
		gameplay.set("player_roll_hold_armed", true)
		motor.move_player(gameplay, 0.5)
		_expect(bool(gameplay.get("player_is_running")), "roll held after a dodge with movement input becomes a run", failures)
		var speed_multiplier := float(gameplay.get("player_speed_multiplier"))
		var expected := gameplay.call("_perspective_movement", Vector2.RIGHT * tuning.run_speed * speed_multiplier * 0.5) as Vector2
		_expect(_captured_motion.is_equal_approx(expected), "run moves at run_speed, nearly as fast as rolling", failures)
		gameplay.set("player_is_targeting", true)
		motor.move_player(gameplay, 0.5)
		_expect(not bool(gameplay.get("player_is_running")), "lock-on targeting suppresses the run", failures)
		gameplay.set("player_is_targeting", false)
		motor.move_player(gameplay, 0.5)
		_expect(bool(gameplay.get("player_is_running")), "releasing the lock-on restores the run", failures)
		gameplay.set("player_roll_input_held", false)
		motor.move_player(gameplay, 0.5)
		_expect(not bool(gameplay.get("player_is_running")), "releasing the roll button returns to walking", failures)
		router.set("_movement", Vector2.ZERO)
		gameplay.set("player_roll_input_held", true)
		motor.move_player(gameplay, 0.5)
		_expect(not bool(gameplay.get("player_is_running")), "roll held without movement does not run", failures)
		motor.motion_requested.disconnect(on_motion)

	# Roll-input latch: an accepted roll arms the hold, releasing disarms it.
	var frame_controller := gameplay.get("gameplay_frame_controller") as GameplayFrameController
	_expect(frame_controller != null, "frame controller is composed", failures)
	if frame_controller != null:
		gameplay.set("player_roll_input_was_down", false)
		router.set("_current", {})
		router.get("_current")[&"roll"] = true
		frame_controller.update_player_input(gameplay, 0.016)
		_expect(bool(gameplay.get("player_roll_hold_armed")), "accepted roll arms the run continuation latch", failures)
		_expect(bool(gameplay.get("player_roll_input_held")), "roll input held flag tracks the pressed button", failures)
		router.get("_current")[&"roll"] = false
		gameplay.set("player_roll_input_was_down", true)
		frame_controller.update_player_input(gameplay, 0.016)
		_expect(not bool(gameplay.get("player_roll_hold_armed")), "releasing the roll button disarms the run latch", failures)

	# Backflip: the target-lock retreat dodge with i-frames and a landing step.
	var backflip_frames := anim.backflip_frames as Array[Texture2D]
	_expect(backflip_frames.size() == 8, "TinyDemon-backflip sheet slices into eight 36x36 frames", failures)
	var roll := gameplay.get("player_roll_component") as PlayerRollComponent
	_expect(roll != null, "roll component is composed for the backflip", failures)
	if roll != null and not backflip_frames.is_empty():
		gameplay.set("player_is_targeting", false)
		router.set("_movement", Vector2.LEFT)
		_expect(not roll.should_backflip(gameplay), "backflip requires the lock-on input", failures)
		gameplay.set("player_is_targeting", true)
		player.flip_h = false
		gameplay.set("player_facing_left_before_target", false)
		router.set("_movement", Vector2.LEFT)
		_expect(roll.should_backflip(gameplay), "no-target backflip activates when holding away from facing", failures)
		router.set("_movement", Vector2.RIGHT)
		_expect(not roll.should_backflip(gameplay), "pushing toward the facing does not backflip", failures)
		router.set("_movement", Vector2.LEFT)
		var equipment_visual := gameplay.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
		var equipment_fixture := gameplay.get("player_equipment") as EquipmentComponent
		if equipment_visual != null and equipment_fixture != null:
			var shield_was_equipped := equipment_fixture.has_shield
			equipment_fixture.has_shield = true
			gameplay.set("player_is_rolling", false)
			gameplay.set("player_is_backflipping", false)
			gameplay.set("player_is_attacking", false)
			gameplay.set("player_is_defending", false)
			gameplay.set("player_is_magic_casting", false)
			gameplay.set("player_anim_name", "idle")
			equipment_visual.begin_attack_visual(gameplay)
			var equipment_layers: Dictionary = equipment_visual.get("layers") as Dictionary
			var sword_before := equipment_layers.get("EquipmentSwordBack") as Sprite2D
			var shield_before := equipment_layers.get("EquipmentShieldFront") as Sprite2D
			_expect(sword_before != null and sword_before.visible and shield_before != null and shield_before.visible, "backflip test starts with visible sword and shield layers", failures)
			gameplay.set("player_is_backflipping", true)
			equipment_visual.tick(gameplay, 0.0)
			_expect(not equipment_visual.active and equipment_visual.roll_fizzle_active and equipment_visual.fade_timer > 0.0, "backflip starts the same equipment fizzle as a roll", failures)
			gameplay.set("player_is_backflipping", false)
			equipment_visual.tick(gameplay, 0.20)
			_expect(not sword_before.visible and not shield_before.visible, "backflip equipment breakup clears sword and shield layers", failures)
			equipment_fixture.has_shield = shield_was_equipped
		roll.start_backflip_from_root(gameplay)
		_expect(bool(gameplay.get("player_is_backflipping")), "backflip input starts the retreat dodge", failures)
		_expect(not bool(player.flip_h), "backflip keeps the pre-target facing", failures)
		for _tick in 60:
			roll.update_from_root(gameplay, 1.0 / 60.0)
			if not bool(gameplay.get("player_is_backflipping")):
				break
		_expect(not bool(gameplay.get("player_is_backflipping")), "backflip completes and clears its state", failures)
		router.set("_movement", Vector2.ZERO)
		gameplay.set("player_is_targeting", false)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RUN_LOCOMOTION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
