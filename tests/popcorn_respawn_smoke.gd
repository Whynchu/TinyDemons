extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/boss_room_debug.tscn") as PackedScene
	_expect(packed != null, "boss debug scene loads for popcorn respawn coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 90:
		await process_frame

	var rooms := gameplay.get("room_controller") as RoomController
	var room_id: StringName = gameplay.get("current_room_id")
	var state: Dictionary = rooms.room_states.get(room_id, {}) as Dictionary
	var flags := state.get("enemy_popcorn", []) as Array
	var variants := state.get("enemy_variants", []) as Array
	var scales := state.get("enemy_scales", []) as Array
	var slimes := gameplay.get("slimes") as Array[Sprite2D]
	var supports: Array[Sprite2D] = []
	var boss: Sprite2D = null
	var big_threats: Array[Sprite2D] = []
	var regular_enemies: Array[Sprite2D] = []
	for slot in slimes.size():
		if slot < scales.size() and float(scales[slot]) > 1.0:
			boss = slimes[slot]
			big_threats.append(slimes[slot])
		elif slot < variants.size() and String(variants[slot]) == "purple":
			big_threats.append(slimes[slot])
		if slot < flags.size() and bool(flags[slot]):
			supports.append(slimes[slot])
		elif not big_threats.has(slimes[slot]):
			regular_enemies.append(slimes[slot])
	_expect(boss != null, "boss encounter exposes a scaled big threat", failures)
	_expect(supports.size() >= 2, "boss encounter exposes at least two popcorn support slots", failures)
	var profile := gameplay.get("player_profile") as PlayerProfile
	var expected_popcorn_level := maxi(1, profile.level - 5) if profile != null else 1
	for support in supports:
		var support_stats := gameplay.call("_slime_stats", support) as StatsComponent
		_expect(support_stats != null and support_stats.level == expected_popcorn_level, "initial popcorn support is five levels below the player", failures)

	if boss != null and supports.size() >= 2:
		for support in supports:
			gameplay.call("_kill_slime", support)
		state = rooms.room_states.get(room_id, {}) as Dictionary
		var waiting := state.get("popcorn_respawn_waiting", {}) as Dictionary
		_expect(waiting.size() == supports.size(), "defeated popcorn slots wait for room clear before scheduling", failures)
		_expect(not state.has("popcorn_respawn_slots"), "popcorn slots are not scheduled before room clear", failures)
		_expect(not bool(gameplay.get("entrance_open")), "defeating popcorn does not open the boss arrival entrance", failures)
		rooms.update_popcorn_respawns(gameplay, 5.0)
		for support in supports:
			_expect(not support.visible and bool(gameplay.call("_is_slime_dead", support)), "popcorn slots stay defeated before the room is cleared", failures)

		# Popcorn belongs to the completed room's replay loop. Once the remaining
		# threats are defeated, the room clear schedules each waiting slot with a
		# seeded 30-45 second delay.
		for threat in big_threats:
			if not bool(gameplay.call("_is_slime_dead", threat)):
				gameplay.call("_kill_slime", threat)
		for regular in regular_enemies:
			if not bool(gameplay.call("_is_slime_dead", regular)):
				gameplay.call("_kill_slime", regular)
		state = rooms.room_states.get(room_id, {}) as Dictionary
		var pending := state.get("popcorn_respawn_slots", {}) as Dictionary
		_expect(bool(state.get("finished", false)), "room clear marks the boss room finished", failures)
		_expect(pending.size() == supports.size(), "room clear schedules every defeated popcorn slot", failures)
		var earliest_delay := 45.0
		var latest_delay := 30.0
		for delay_value in pending.values():
			var delay := float(delay_value)
			earliest_delay = minf(earliest_delay, delay)
			latest_delay = maxf(latest_delay, delay)
		_expect(earliest_delay >= 30.0 and latest_delay <= 45.0, "popcorn delays stay inside the 30-45 second contract", failures)
		rooms.update_popcorn_respawns(gameplay, maxf(earliest_delay - 0.01, 0.0))
		for support in supports:
			_expect(not support.visible and bool(gameplay.call("_is_slime_dead", support)), "popcorn slots wait until their seeded delay expires", failures)
		rooms.update_popcorn_respawns(gameplay, latest_delay + 0.1)
		for support in supports:
			_expect(support.visible and not bool(gameplay.call("_is_slime_dead", support)), "popcorn slots respawn after their seeded delays", failures)
			var respawned_stats := gameplay.call("_slime_stats", support) as StatsComponent
			_expect(respawned_stats != null and respawned_stats.level == expected_popcorn_level, "respawned popcorn support remains five levels below the player", failures)
		_expect(not bool(gameplay.get("entrance_open")), "popcorn respawn keeps the boss arrival entrance sealed", failures)

		for support in supports:
			gameplay.call("_kill_slime", support)
		_expect(not bool(gameplay.get("entrance_open")), "boss arrival entrance stays sealed after a respawned support dies", failures)
		for slime in slimes:
			if not bool(gameplay.call("_is_slime_dead", slime)):
				gameplay.call("_kill_slime", slime)
		_expect(bool(gameplay.get("final_exit_open")), "the final exit remains available after the full boss encounter is defeated", failures)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("POPCORN_RESPAWN_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
