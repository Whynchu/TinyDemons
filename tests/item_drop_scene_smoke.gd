extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for item-drop placement", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 30:
		await process_frame
	var item := ItemCatalog.new().generate_item(&"weapon", 9101, 1, &"common")
	item.instance_id = "item-drop-smoke"
	var items: Array[ItemInstance] = [item]
	gameplay.call("_spawn_chest_item_drops", items)
	var drops := gameplay.get("world_item_drops") as Array
	_expect(drops.size() == 1, "chest creates one world item drop", failures)
	if drops.size() == 1:
		var drop := drops[0] as Dictionary
		var sprite := drop.get("sprite") as Sprite2D
		var label := drop.get("label") as Sprite2D
		_expect(sprite != null and is_instance_valid(sprite), "item drop sprite is present", failures)
		_expect(sprite != null and bool(gameplay.call("_is_slime_walkable_point", sprite.global_position)), "item drop starts in walkable space", failures)
		var outline := gameplay.get("walkable_outline") as PackedVector2Array
		if sprite != null and not outline.is_empty():
			var edge_position: Vector2 = gameplay.call("_nearest_slime_walkable_point", outline[0]) as Vector2
			if bool(gameplay.call("_is_slime_walkable_point", edge_position)):
				sprite.global_position = edge_position
				drop["last_valid_position"] = edge_position
				drop["velocity"] = Vector2(-30, -30)
				drop["air_time"] = 0.38
			var previous_position := sprite.global_position
			var largest_step := 0.0
			for _air_frame in 10:
				gameplay.call("_update_world_item_drops", 0.05)
				if is_instance_valid(sprite):
					largest_step = maxf(largest_step, sprite.global_position.distance_to(previous_position))
					previous_position = sprite.global_position
			_expect(largest_step <= 8.0, "item drop does not teleport while constrained", failures)
			if label != null and is_instance_valid(label) and sprite != null:
				_expect(label.global_position.is_equal_approx(sprite.global_position + Vector2(0, -10)), "item label follows the constrained drop", failures)
	gameplay.call("_clear_world_item_drops")
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ITEM_DROP_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
