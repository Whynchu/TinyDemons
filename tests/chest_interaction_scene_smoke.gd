extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for chest interaction characterization", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 30:
		await process_frame

	gameplay.set("current_room_type", DungeonGraph.ROOM_TREASURE)
	gameplay.set("chest_unlocked", true)
	gameplay.set("chest_claimed", false)
	var player := gameplay.get("player") as Sprite2D
	var chest := gameplay.get("chest") as Sprite2D
	var chest_anchor: Vector2 = (gameplay.call("_collision_rect", chest) as Rect2).get_center()

	for side in [-1.0, 1.0]:
		var desired_foot := chest_anchor + Vector2(side * 20.0, 0.0)
		player.global_position = desired_foot - Vector2(8.0, 15.0)
		player.flip_h = side > 0.0
		# The attack direction is intentionally stale here. Interaction must use
		# the player's current idle facing, not the last swing's snapshot.
		gameplay.set("player_is_attacking", false)
		gameplay.set("player_attack_flip_h", side < 0.0)
		_expect(bool(gameplay.call("_can_interact_with_chest")), "chest interaction works from %s side near its edge" % ("left" if side < 0.0 else "right"), failures)

	player.global_position = chest_anchor - Vector2(20.0, 0.0) - Vector2(8.0, 15.0)
	player.flip_h = true
	_expect(not bool(gameplay.call("_can_interact_with_chest")), "chest interaction still requires facing the chest", failures)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CHEST_INTERACTION_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
