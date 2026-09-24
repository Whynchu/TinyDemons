extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for gold pickup presentation", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	gameplay.set("debug_start_in_boss_room", true)
	root.add_child(gameplay)
	var boot_ready := false
	for _frame in 600:
		await process_frame
		if not bool(gameplay.get("boot_active")) and gameplay.get("chest_gray_texture") != null:
			boot_ready = true
			break
	_expect(boot_ready, "gameplay bootstrap is ready for gold pickup presentation", failures)
	if not boot_ready:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return

	var pickup_runtime := gameplay.get("pickup_runtime_controller") as PickupRuntimeController
	var gold_controller := pickup_runtime.gold_pickup_controller if pickup_runtime != null else null
	var profile := gameplay.get("player_profile") as PlayerProfile
	var effects := gameplay.get("effects_spawner") as EffectsSpawner
	var hud := gameplay.get("hud_controller") as HudController
	var registry := gameplay.get("feedback_animation_registry") as FeedbackAnimationRegistry
	_expect(pickup_runtime != null and gold_controller != null and profile != null, "gold pickup services are composed", failures)
	if pickup_runtime == null or gold_controller == null or profile == null:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return

	var reward_total := 100
	var denomination_values := pickup_runtime.decompose_gold(reward_total)
	var denomination_sum := 0
	for value in denomination_values:
		denomination_sum += value
		_expect([50, 25, 10, 5, 1].has(value), "gold uses an authored denomination", failures)
	_expect(denomination_sum == reward_total, "gold decomposition preserves the chest payout exactly", failures)
	_expect(denomination_values.size() >= 4 and denomination_values.size() <= 16, "gold decomposition stays inside the readable coin budget", failures)

	var gold_before := profile.gold
	pickup_runtime.spawn_chest_gold_drops(gameplay, reward_total)
	_expect(gold_controller.sprites.size() == denomination_values.size(), "chest spawns one world coin per denomination", failures)
	if not gold_controller.sprites.is_empty():
		var chest_rect: Rect2 = gameplay.call("_collision_rect", gameplay.get("chest")) as Rect2
		var first_coin := gold_controller.sprites[0]
		_expect(first_coin.texture != null and first_coin.hframes == 4, "gold coins use the authored spin frames", failures)
		_expect(first_coin.global_position.distance_to(chest_rect.get_center()) < 6.0, "gold launches from the chest opening", failures)
		_expect(first_coin.modulate.is_equal_approx(pickup_runtime.gold_color(gold_controller.values[0])), "gold coin carries its denomination color", failures)

	var player := gameplay.get("player") as Sprite2D
	var player_foot: Vector2 = gameplay.call("_actor_foot", player) as Vector2
	for index in gold_controller.sprites.size():
		var coin := gold_controller.sprites[index]
		coin.global_position = player_foot
		coin.set_meta("gold_base_position", player_foot)
		coin.set_meta("gold_last_valid_position", player_foot)
		gold_controller.air_times[index] = 0.0
	var display_before := hud.displayed_gold if hud != null else -1
	pickup_runtime.update_gold_pickups(gameplay, 0.01)
	_expect(gold_controller.sprites.is_empty(), "gold auto-collects on proximity without an interact press", failures)
	_expect(profile.gold == gold_before + reward_total, "collecting all coins grants the exact chest payout", failures)
	_expect(hud == null or hud.displayed_gold == display_before, "gold counter waits for HUD delivery before counting up", failures)
	_expect(effects != null and effects.pickup_flights.size() == denomination_values.size(), "each coin starts a HUD delivery flight", failures)

	if registry != null and effects != null:
		for _delivery_frame in 8:
			registry.tick(0.05)
			effects.update_pixel_particles_from_root(gameplay, 0.05)
		_expect(effects.pickup_flights.is_empty(), "gold delivery flights complete", failures)
		if hud != null:
			for _counter_frame in 8:
				hud.call("_tick_gold_counter", gameplay, 0.05)
			_expect(hud.displayed_gold == gold_before + reward_total, "gold counter counts up to the delivered total", failures)
			_expect(hud.gold_reaction_id > 0, "gold HUD acknowledges the delivered reward", failures)

	pickup_runtime.spawn_chest_gold_drops(gameplay, reward_total)
	var settled_before := profile.gold
	var settled := pickup_runtime.settle_gold_pickups(gameplay)
	_expect(settled == reward_total, "room-exit settlement resolves every remaining coin", failures)
	_expect(profile.gold == settled_before + reward_total, "room-exit settlement grants uncollected gold", failures)
	_expect(gold_controller.sprites.is_empty(), "room-exit settlement clears the world coins", failures)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GOLD_PICKUP_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
