extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/boss_room_debug.tscn") as PackedScene
	_expect(packed != null, "boss debug scene loads for jump/slam coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	var boss: Sprite2D = null
	for _frame in 120:
		await process_frame
		for slime in gameplay.get("slimes") as Array[Sprite2D]:
			if float(slime.get_meta("encounter_scale", 1.0)) > 1.0:
				boss = slime
				break
		if boss != null and not bool(gameplay.get("boot_active")):
			break
	_expect(boss != null, "debug room creates a boss", failures)
	if boss != null:
		_expect(String(boss.get("variant")) == "grey", "debug boss keeps its selected Normal variant", failures)
		var boss_visual := boss.get_node_or_null("Visual") as SlimeVisualComponent
		_expect(boss_visual != null and boss_visual.left_texture != null and boss_visual.left_texture.get_size().is_equal_approx(Vector2(32, 32)), "debug boss uses native boss directional artwork", failures)
		_expect((gameplay.get("room_controller") as RoomController).boss_jump_phase_pool.size() == 3, "boss support actors are preallocated before the phase", failures)
	if boss != null:
		var component := boss.get_node_or_null("BossJumpSlam") as BossJumpSlamComponent
		_expect(component != null, "boss has a jump/slam component", failures)
		if component != null:
			_expect(is_equal_approx(component.cooldown, BossJumpSlamComponent.INITIAL_COOLDOWN_SECONDS), "boss first jump waits ten seconds", failures)
			var idle_shadow := boss.get_node_or_null("SlimeFloorShadow") as Sprite2D
			_expect(idle_shadow != null and not idle_shadow.centered and idle_shadow.global_position.is_equal_approx(boss.global_position), "boss walking shadow uses the sprite canvas origin", failures)
			_expect(idle_shadow != null and is_equal_approx(idle_shadow.self_modulate.a, 0.25), "boss shadow matches player floor-shadow opacity", failures)
			var visual := boss.get_node_or_null("Visual") as SlimeVisualComponent
			_expect(visual != null and not visual.shadow_attack_left_frames.is_empty() and not visual.shadow_attack_right_frames.is_empty(), "boss loads both directional attack shadow animations", failures)
			_expect(visual != null and not visual.shadow_shocked_frames.is_empty(), "boss loads its shocked shadow animation", failures)
			component.cooldown = 0.0
			var saw_active := false
			var saw_launch_protection := false
			var saw_popcorn := false
			var targeted_player_foot := Vector2.INF
			for _frame in 600:
				await process_frame
				if component.is_active():
					if not saw_active:
						targeted_player_foot = gameplay.call("_actor_foot", gameplay.get("player")) as Vector2
					saw_active = true
				var combat := boss.get_node_or_null("Combat") as SlimeCombatComponent
				if combat != null and combat.boss_jump_phase_invulnerable and combat.boss_jump_phase_stun_resistant:
					saw_launch_protection = true
				var wave := (gameplay.get("room_controller") as RoomController).boss_jump_phase_waves.get(boss.get_instance_id(), []) as Array
				if wave.size() == 3:
					saw_popcorn = true
				if saw_launch_protection and boss.offset.y < component.base_sprite_offset.y:
					break
			_expect(saw_active, "boss enters the jump/slam phase", failures)
			_expect(saw_popcorn, "jump phase creates three SlimeBossJumpPhasePopcorn enemies", failures)
			_expect(saw_launch_protection, "boss becomes invulnerable and stun-resistant after launch", failures)
			_expect(saw_launch_protection and boss.offset.y < component.base_sprite_offset.y, "boss remains visibly airborne after launch", failures)
			_expect(component.frame >= 5, "boss airborne movement begins only at launch frame", failures)
			if saw_active:
				_expect(component.landing_anchor.distance_to(targeted_player_foot) < 1.0, "boss targets the player's landing point", failures)
				component.tick(gameplay, boss, BossJumpSlamComponent.BOSS_JUMP_FRAME_TIME * BossJumpSlamComponent.JUMP_FRAME_COUNT)
				var shadow := boss.get_node_or_null("BossFloorShadow") as Sprite2D
				_expect(shadow != null and not shadow.visible, "boss jump phase hides its floor shadow while airborne", failures)
				if shadow != null:
					_expect(visual != null and shadow.texture == visual.boss_shadow_jump_frames.back(), "boss jump shadow advances with the jump animation", failures)
				_expect(bool(boss.get_meta("boss_airborne", false)) and boss.offset.y <= component.base_sprite_offset.y - boss.get_viewport_rect().size.y, "boss physically clears the visible arena after its launch animation", failures)
				_expect(idle_shadow != null and not idle_shadow.visible, "ordinary boss shadow is hidden while the animated landing shadow is active", failures)
				_expect(bool(boss.get_meta("boss_jump_ui_suppressed", false)), "boss health UI is suppressed during flight", failures)
				# Clear the temporary wave and allow the component to reach the slam.
				for popcorn in (gameplay.get("room_controller") as RoomController).boss_jump_phase_waves.get(boss.get_instance_id(), []) as Array:
					if is_instance_valid(popcorn):
						gameplay.call("_kill_slime", popcorn)
				component.tick(gameplay, boss, BossJumpSlamComponent.AIRBORNE_FAILSAFE_SECONDS)
				component.tick(gameplay, boss, BossJumpSlamComponent.BOSS_JUMP_FRAME_TIME * BossJumpSlamComponent.SLAM_FRAME_COUNT)
				_expect(not component.is_active(), "boss descends and clears the jump/slam phase", failures)
				_expect((gameplay.get("room_controller") as RoomController).boss_jump_phase_pool.size() == 3, "boss support actors return to the pool after cleanup", failures)
				_expect(component.cooldown >= BossJumpSlamComponent.REPEAT_COOLDOWN_MIN_SECONDS and component.cooldown <= BossJumpSlamComponent.REPEAT_COOLDOWN_MAX_SECONDS, "boss repeat jump waits between thirty and forty-five seconds", failures)
				_expect(not bool(boss.get_meta("boss_jump_ui_suppressed", true)), "boss health UI suppression restores after recovery", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PASS boss_jump_slam_smoke")
	else:
		for failure in failures:
			push_error(failure)
	quit(1 if not failures.is_empty() else 0)
