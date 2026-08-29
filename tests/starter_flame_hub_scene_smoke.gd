extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for starter-flame hub persistence coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var profile := gameplay.get("player_profile") as PlayerProfile
	_expect(profile != null, "starter-flame persistence has a live profile", failures)
	if profile != null:
		var original_profile := profile.to_dictionary()
		profile.has_started = true
		profile.completed_runs = 0
		profile.starter_flame = &"electric"
		profile.palette_name = "yellow"
		profile.bound_element = &""
		profile.has_bound_element = false
		profile.souls = 0
		gameplay.call("_begin_new_run")
		_expect(profile.hub_flame() == &"electric", "the selected starter remains the hub flame before binding", failures)
		_expect(String(gameplay.get("run_start_palette_name")) == "yellow", "the first run records the selected starter palette", failures)
		_expect(String(gameplay.get("current_fire_palette_name")) == "yellow", "the starter fire uses the selected starter palette", failures)
		_expect(bool(gameplay.get("rest_fire").visible), "the selected starter fire remains visible in the start room", failures)

		# Completing/starting another run must not turn the temporary grey player
		# start or a previous run's active element into the hub flame identity.
		profile.completed_runs = 1
		gameplay.call("_begin_new_run")
		_expect(profile.hub_flame() == &"electric", "a later run still resolves the original starter as the hub flame", failures)
		_expect(String(gameplay.get("current_fire_palette_name")) == "yellow", "a later run keeps the original starter fire", failures)

		profile.souls = PlayerProfile.ELEMENT_BIND_SOUL_COST
		_expect(profile.bind_element(&"water"), "an explicit element bind succeeds for the persistence check", failures)
		gameplay.call("_begin_new_run")
		_expect(profile.starter_flame == &"electric", "binding does not overwrite the original starter choice", failures)
		_expect(profile.hub_flame() == &"water", "an explicit bind becomes the new hub flame", failures)
		_expect(String(gameplay.get("current_fire_palette_name")) == "blue", "the newly bound flame updates the hub fire", failures)
		profile.load_dictionary(original_profile)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: starter-flame hub smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("STARTER_FLAME_HUB_SCENE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
