extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/boss_room_debug.tscn") as PackedScene
	_expect(packed != null, "boss debug scene loads for resource-drop motion coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 90:
		await process_frame

	var chroma_tuning := gameplay.get("chroma_tuning") as ChromaTuning
	var chroma_controller := gameplay.get("chroma_pickup_controller") as Node
	var soul_controller := gameplay.get("soul_pickup_controller") as Node
	_expect(chroma_tuning != null, "Chroma tuning is available for resource drops", failures)
	_expect(chroma_controller != null and soul_controller != null, "both resource pickup controllers are composed", failures)
	if chroma_tuning == null or chroma_controller == null or soul_controller == null:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return

	# Force the normal Chroma roll for this fixture, then use the real death path
	# so the spacing contract is covered where it is authored.
	chroma_tuning.enemy_drop_chance = 1.0
	var slimes := gameplay.get("slimes") as Array[Sprite2D]
	var slime: Sprite2D = null
	for candidate in slimes:
		if candidate != null and is_instance_valid(candidate) and not bool(gameplay.call("_is_slime_dead", candidate)):
			slime = candidate
			break
	_expect(slime != null, "boss debug scene exposes a live slime for the drop fixture", failures)
	if slime != null:
		gameplay.call("_kill_slime", slime)
	var chroma_sprites := chroma_controller.get("sprites") as Array
	var soul_sprites := soul_controller.get("sprites") as Array
	_expect(chroma_sprites.size() == 1, "the forced slime death creates one Chroma pickup", failures)
	_expect(soul_sprites.size() == 1, "the slime death creates one Soul pickup", failures)
	if chroma_sprites.size() == 1 and soul_sprites.size() == 1:
		var chroma := chroma_sprites[0] as Sprite2D
		var soul := soul_sprites[0] as Sprite2D
		var initial_separation := chroma.global_position.distance_to(soul.global_position)
		_expect(initial_separation >= 4.0, "Chroma and Soul pickups start visibly separated", failures)
		var chroma_velocity := (chroma_controller.get("velocities") as Array)[0] as Vector2
		var soul_velocity := (soul_controller.get("velocities") as Array)[0] as Vector2
		_expect(chroma_velocity.length() <= 18.01 and soul_velocity.length() <= 18.01, "resource launch speed stays at the softer 18px/s ceiling", failures)
		var previous_chroma_position := chroma.global_position
		var previous_soul_position := soul.global_position
		var largest_step := 0.0
		for _air_frame in 8:
			gameplay.call("_update_chroma_pickups", 0.05)
			gameplay.call("_update_soul_pickups", 0.05)
			if is_instance_valid(chroma):
				largest_step = maxf(largest_step, previous_chroma_position.distance_to(chroma.global_position))
				previous_chroma_position = chroma.global_position
			if is_instance_valid(soul):
				largest_step = maxf(largest_step, previous_soul_position.distance_to(soul.global_position))
				previous_soul_position = soul.global_position
		_expect(largest_step <= 4.0, "resource drops move in smooth bounded steps", failures)

	var bounce_probe := _find_horizontal_bounce_probe(gameplay)
	_expect(not bounce_probe.is_empty(), "room geometry exposes a horizontal edge bounce probe", failures)
	if not bounce_probe.is_empty():
		var pickup_runtime := gameplay.get("pickup_runtime_controller") as Node
		var probe_position: Vector2 = bounce_probe[0]
		var outward: Vector2 = bounce_probe[1]
		var result := pickup_runtime.call("_advance_resource_drop_position", gameplay, probe_position, outward * 18.0, 0.05) as Dictionary
		var result_position: Vector2 = result.get("position", probe_position) as Vector2
		var result_velocity: Vector2 = result.get("velocity", Vector2.ZERO) as Vector2
		_expect(bool(gameplay.call("_is_slime_walkable_point", result_position)), "resource bounce remains inside the walkable room", failures)
		_expect(result_velocity.dot(outward) < -0.1, "resource bounce reverses the wall-facing velocity", failures)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _find_horizontal_bounce_probe(gameplay: Node) -> Array:
	var outline := gameplay.get("walkable_outline") as PackedVector2Array
	var directions := [Vector2.RIGHT, Vector2.LEFT]
	for outline_point in outline:
		for outward in directions:
			for inset in [0.5, 1.0, 2.0, 3.0, 4.0, 6.0]:
				var probe_position: Vector2 = outline_point - outward * inset
				if not bool(gameplay.call("_is_slime_walkable_point", probe_position)):
					continue
				if bool(gameplay.call("_is_slime_walkable_point", probe_position + outward * 1.0)):
					continue
				return [probe_position, outward]
	return []


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("RESOURCE_DROP_MOTION_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
