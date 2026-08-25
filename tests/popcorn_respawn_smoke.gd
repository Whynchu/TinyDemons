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
	var scales := state.get("enemy_scales", []) as Array
	var slimes := gameplay.get("slimes") as Array[Sprite2D]
	var support: Sprite2D = null
	var boss: Sprite2D = null
	for slot in slimes.size():
		if slot < scales.size() and float(scales[slot]) > 1.0:
			boss = slimes[slot]
		if slot < flags.size() and bool(flags[slot]):
			support = slimes[slot]
	_expect(boss != null, "boss encounter exposes a scaled big threat", failures)
	_expect(support != null, "boss encounter exposes a popcorn support slot", failures)

	if boss != null and support != null:
		gameplay.call("_kill_slime", support)
		state = rooms.room_states.get(room_id, {}) as Dictionary
		_expect(state.has("popcorn_respawn_slots"), "defeated popcorn slot enters the respawn queue", failures)
		for _frame in 20:
			await process_frame
		_expect(support.visible and not bool(gameplay.call("_is_slime_dead", support)), "popcorn slot respawns while the boss is alive", failures)

		gameplay.call("_kill_slime", boss)
		gameplay.call("_kill_slime", support)
		for _frame in 30:
			await process_frame
		_expect(not support.visible and bool(gameplay.call("_is_slime_dead", support)), "popcorn slot stays defeated after the big threat is gone", failures)
		state = rooms.room_states.get(room_id, {}) as Dictionary
		_expect(not state.has("popcorn_respawn_slots"), "big-threat defeat clears pending popcorn respawns", failures)

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
