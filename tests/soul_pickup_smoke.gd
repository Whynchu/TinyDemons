extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Soul pickup coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var pickup_runtime := gameplay.get("pickup_runtime_controller") as Node
	var soul_controller := gameplay.get("soul_pickup_controller") as Node
	var profile := gameplay.get("player_profile") as PlayerProfile
	var texture := pickup_runtime.call("soul_pickup_texture") as Texture2D if pickup_runtime != null else null
	_expect(texture != null and texture.get_width() == 9 and texture.get_height() == 9, "Soul stand-in is exactly 9x9", failures)
	_expect(soul_controller != null, "Soul pickup controller is composed", failures)
	if soul_controller != null and profile != null:
		var before := profile.souls
		var player := gameplay.get("player") as Sprite2D
		var player_foot: Vector2 = gameplay.call("_actor_foot", player) as Vector2
		gameplay.call("_spawn_soul_pickup", player_foot, 2, 777, Vector2.ZERO)
		if soul_controller.get("air_times").size() > 0:
			soul_controller.get("air_times")[0] = 0.0
			var pickup := soul_controller.get("sprites")[0] as Sprite2D
			pickup.global_position = player_foot
			gameplay.call("_update_soul_pickups", 0.01)
		_expect(profile.souls == before + 2, "Soul pickup adds its value to the persistent profile currency", failures)
		_expect(soul_controller.get("sprites").is_empty(), "Soul pickup is removed after collection", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Soul pickup smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("SOUL_PICKUP_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
