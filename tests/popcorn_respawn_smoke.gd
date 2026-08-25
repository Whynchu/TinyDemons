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
	for slot in slimes.size():
		if slot < scales.size() and float(scales[slot]) > 1.0:
			boss = slimes[slot]
			big_threats.append(slimes[slot])
		elif slot < variants.size() and String(variants[slot]) == "purple":
			big_threats.append(slimes[slot])
		if slot < flags.size() and bool(flags[slot]):
			supports.append(slimes[slot])
	_expect(boss != null, "boss encounter exposes a scaled big threat", failures)
	_expect(supports.size() >= 2, "boss encounter exposes at least two popcorn support slots", failures)

	if boss != null and supports.size() >= 2:
		for support in supports:
			gameplay.call("_kill_slime", support)
		state = rooms.room_states.get(room_id, {}) as Dictionary
		_expect(state.has("popcorn_respawn_slots"), "defeated popcorn slot enters the respawn queue", failures)
		_expect(not bool(gameplay.get("entrance_open")), "defeating popcorn does not open the boss arrival entrance", failures)
		rooms.update_popcorn_respawns(gameplay, 4.99)
		for support in supports:
			_expect(not support.visible and bool(gameplay.call("_is_slime_dead", support)), "popcorn slots wait before the five-second respawn", failures)
		rooms.update_popcorn_respawns(gameplay, 0.02)
		for support in supports:
			_expect(support.visible and not bool(gameplay.call("_is_slime_dead", support)), "popcorn slots respawn while the boss is alive", failures)
		_expect(not bool(gameplay.get("entrance_open")), "popcorn respawn keeps the boss arrival entrance sealed", failures)

		for threat in big_threats:
			gameplay.call("_kill_slime", threat)
		for support in supports:
			gameplay.call("_kill_slime", support)
		for _frame in 30:
			await process_frame
		for support in supports:
			_expect(not support.visible and bool(gameplay.call("_is_slime_dead", support)), "popcorn slots stay defeated after every big threat is gone", failures)
		state = rooms.room_states.get(room_id, {}) as Dictionary
		_expect(not state.has("popcorn_respawn_slots"), "big-threat defeat clears pending popcorn respawns", failures)
		_expect(not bool(gameplay.get("entrance_open")), "the boss entrance stays sealed while regular enemies remain", failures)
		for slime in slimes:
			if not bool(gameplay.call("_is_slime_dead", slime)):
				gameplay.call("_kill_slime", slime)
		_expect(bool(gameplay.get("entrance_open")), "the boss entrance opens only after the full encounter is defeated", failures)

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
