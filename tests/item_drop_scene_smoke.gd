extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for item-drop placement", failures)
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
	_expect(boot_ready, "gameplay bootstrap is ready for item-drop presentation", failures)
	if not boot_ready:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return
	var item := ItemCatalog.new().generate_item(&"weapon", 9101, 1, &"common")
	item.instance_id = "item-drop-smoke"
	var shield := ItemCatalog.new().generate_item(&"shield", 9102, 1, &"common")
	shield.instance_id = "item-drop-shield-smoke"
	var items: Array[ItemInstance] = [item, shield]
	gameplay.call("_spawn_chest_item_drops", items)
	var drops := gameplay.get("world_item_drops") as Array
	_expect(drops.size() == 2, "chest creates both world item drops", failures)
	if drops.size() >= 1:
		var drop := drops[0] as Dictionary
		var sprite := drop.get("sprite") as Sprite2D
		var label := drop.get("label") as Sprite2D
		_expect(sprite != null and is_instance_valid(sprite), "item drop sprite is present", failures)
		_expect(label != null and not label.visible, "item name stays hidden until its drop is interactable", failures)
		_expect(label != null and String(label.get_meta("item_type", "")) == "SWORD", "weapon drop label keeps the item type", failures)
		if sprite != null:
			var chest_rect: Rect2 = gameplay.call("_collision_rect", gameplay.get("chest")) as Rect2
			var landing_position: Vector2 = drop.get("landing_position", Vector2.ZERO) as Vector2
			_expect(sprite.global_position.distance_to(chest_rect.get_center()) < 6.0, "item drop launches from the chest opening", failures)
			_expect(StringName(drop.get("trajectory_mode", &"")) == &"chest_arc", "chest drop uses its chest-relative arc", failures)
			_expect(bool(gameplay.call("_is_slime_walkable_point", landing_position)), "item drop landing is walkable", failures)
			_expect(landing_position.distance_to(chest_rect.get_center()) < 24.0, "item drop landing stays beside the chest", failures)
			var previous_launch_position := sprite.global_position
			var launch_largest_step := 0.0
			for _flight_frame in 10:
				gameplay.call("_update_world_item_drops", 0.05)
				if is_instance_valid(sprite):
					launch_largest_step = maxf(launch_largest_step, sprite.global_position.distance_to(previous_launch_position))
					previous_launch_position = sprite.global_position
			_expect(launch_largest_step <= 8.0, "chest item follows a smooth launch arc", failures)
			_expect(sprite != null and sprite.global_position.is_equal_approx(landing_position), "chest item settles at its nearby landing point", failures)
		var outline := gameplay.get("walkable_outline") as PackedVector2Array
		if sprite != null and not outline.is_empty():
			var edge_position: Vector2 = gameplay.call("_nearest_slime_walkable_point", outline[0]) as Vector2
			if bool(gameplay.call("_is_slime_walkable_point", edge_position)):
				drop["trajectory_mode"] = &"physics"
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
	if drops.size() == 2:
		var player := gameplay.get("player") as Sprite2D
		var player_foot: Vector2 = gameplay.call("_actor_foot", player) as Vector2
		var right_drop := drops[0] as Dictionary
		var left_drop := drops[1] as Dictionary
		var right_sprite := right_drop.get("sprite") as Sprite2D
		var left_sprite := left_drop.get("sprite") as Sprite2D
		var right_label := right_drop.get("label") as Sprite2D
		var left_label := left_drop.get("label") as Sprite2D
		var pickup_controller := gameplay.get("pickup_runtime_controller") as Node
		var right_position := player_foot + Vector2(8, 0)
		var left_position := player_foot + Vector2(-8, 0)
		for positioned_drop in [[right_drop, right_sprite, right_position], [left_drop, left_sprite, left_position]]:
			var positioned := positioned_drop[0] as Dictionary
			var positioned_sprite := positioned_drop[1] as Sprite2D
			var positioned_position: Vector2 = positioned_drop[2]
			positioned_sprite.global_position = positioned_position
			positioned["last_valid_position"] = positioned_position
			positioned["air_time"] = 0.0
			positioned["trajectory_mode"] = &"landed"
			positioned["velocity"] = Vector2.ZERO
		gameplay.set("player_is_moving", false)
		player.flip_h = false
		pickup_controller.call("_update_world_item_labels", gameplay)
		_expect(bool(gameplay.call("_can_interact_with_world_item")), "nearest item in front of the player is interactable", failures)
		_expect(right_label != null and right_label.visible and left_label != null and not left_label.visible, "only the front item shows its equipment name", failures)
		_expect(right_label != null and right_sprite != null and right_label.global_position.is_equal_approx(right_sprite.global_position + Vector2(0, -10)), "front item name stays attached to its drop", failures)
		player.flip_h = true
		pickup_controller.call("_update_world_item_labels", gameplay)
		_expect(bool(gameplay.call("_can_interact_with_world_item")), "nearest item in front after turning is interactable", failures)
		_expect(left_label != null and left_label.visible and right_label != null and not right_label.visible, "turning swaps the one visible equipment name", failures)
		right_sprite.global_position = player_foot + Vector2(32, 0)
		right_drop["last_valid_position"] = right_sprite.global_position
		player.flip_h = false
		pickup_controller.call("_update_world_item_labels", gameplay)
		_expect(not bool(gameplay.call("_can_interact_with_world_item")), "an item behind the player is not interactable", failures)
		_expect(left_label != null and not left_label.visible and right_label != null and not right_label.visible, "behind items do not show an equipment name", failures)
		_expect(pickup_controller != null and String(pickup_controller.call("item_acquired_text", item)) == "SWORD ACQUIRED!", "weapon collection uses the concise type acquired message", failures)
		right_sprite.global_position = player_foot + Vector2(8, 0)
		right_drop["last_valid_position"] = right_sprite.global_position
		pickup_controller.call("_update_world_item_labels", gameplay)
		var collected := bool(gameplay.call("_collect_world_item_drop"))
		_expect(collected, "interactable item is collected into the profile", failures)
		var effects := gameplay.get("effects_spawner") as EffectsSpawner
		var registry := gameplay.get("feedback_animation_registry") as FeedbackAnimationRegistry
		_expect(effects != null and effects.pickup_flights.size() == 1, "item collection starts one HUD delivery flight", failures)
		_expect(registry != null and registry.active_count() >= 1, "item delivery is owned by the shared feedback registry", failures)
		_expect((gameplay.get("world_item_drops") as Array).size() == 1, "collecting one item leaves the other world drop intact", failures)
		if registry != null and effects != null:
			for _delivery_frame in 6:
				registry.tick(0.05)
				effects.update_pixel_particles_from_root(gameplay, 0.05)
			_expect(effects.pickup_flights.is_empty(), "item delivery flight completes", failures)
		var hud_controller := gameplay.get("hud_controller") as HudController
		_expect(hud_controller != null and hud_controller.inventory_chest_reaction_id > 0, "inventory chest acknowledges the delivered item", failures)
		if registry != null and effects != null and hud_controller != null:
			for _reaction_frame in 6:
				registry.tick(0.05)
			var chroma := gameplay.get("player_chroma_component") as Node
			var chroma_controller := gameplay.get("chroma_pickup_controller") as Node
			if chroma != null and chroma_controller != null:
				chroma.call("begin_new_run")
				gameplay.call("_spawn_chroma_pickup", player_foot, 20, 771, Vector2.ZERO)
				if chroma_controller.get("air_times").size() > 0:
					chroma_controller.get("air_times")[0] = 0.0
					var chroma_pickup := chroma_controller.get("sprites")[0] as Sprite2D
					chroma_pickup.global_position = player_foot
					gameplay.call("_update_chroma_pickups", 0.01)
					_expect(effects.pickup_flights.size() == 1, "Chroma collection starts one HUD delivery flight", failures)
					_expect(int(chroma.get("current_chroma")) == 20, "Chroma collection updates the bar before presentation", failures)
					for _delivery_frame in 6:
						registry.tick(0.05)
						effects.update_pixel_particles_from_root(gameplay, 0.05)
					_expect(effects.pickup_flights.is_empty(), "Chroma delivery flight completes", failures)
					_expect(hud_controller.chroma_reaction_id > 0, "Chroma HUD acknowledges the delivered pickup", failures)
					var chroma_highlight := hud_controller.chroma_highlight_target
					_expect(hud_controller.chroma_reaction_color.is_equal_approx(PaletteLibrary.ACCENT["grey"]), "Chroma delivery carries the neutral highlight color into the HUD", failures)
					_expect(chroma_highlight != null and chroma_highlight.visible and chroma_highlight.texture != null and _contains_color(chroma_highlight.texture.get_image(), PaletteLibrary.ACCENT["grey"]), "Chroma delivery reveals the colored MP highlight layer", failures)
					for _reaction_frame in 6:
						registry.tick(0.05)
			var soul_controller := gameplay.get("soul_pickup_controller") as Node
			var profile := gameplay.get("player_profile") as PlayerProfile
			if soul_controller != null and profile != null:
				var souls_before := profile.souls
				gameplay.call("_spawn_soul_pickup", player_foot, 2, 772, Vector2.ZERO)
				if soul_controller.get("air_times").size() > 0:
					soul_controller.get("air_times")[0] = 0.0
					var soul_pickup := soul_controller.get("sprites")[0] as Sprite2D
					soul_pickup.global_position = player_foot
					gameplay.call("_update_soul_pickups", 0.01)
					_expect(effects.pickup_flights.size() == 1, "Soul collection starts one HUD delivery flight", failures)
					_expect(profile.souls == souls_before + 2, "Soul collection updates the profile before presentation", failures)
					for _delivery_frame in 6:
						registry.tick(0.05)
						effects.update_pixel_particles_from_root(gameplay, 0.05)
					_expect(effects.pickup_flights.is_empty(), "Soul delivery flight completes", failures)
					_expect(hud_controller.soul_reaction_id > 0, "Soul HUD acknowledges the delivered pickup", failures)
	gameplay.call("_clear_world_item_drops")
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _contains_color(image: Image, expected: Color) -> bool:
	if image == null:
		return false
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).is_equal_approx(expected):
				return true
	return false


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ITEM_DROP_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
