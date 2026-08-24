extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Chroma ownership characterization", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	get_root().add_child(gameplay)
	for _frame in 30:
		await process_frame
	var chroma := gameplay.get("player_chroma_component") as Node
	var ability := gameplay.get("player_aspect_ability_component") as Node
	var projectile_controller := gameplay.get_node_or_null("MagicProjectileController") as Node
	var pickup_controller := gameplay.get_node_or_null("ChromaPickupController") as Node
	var player_hud := gameplay.get_node_or_null("InterfaceCanvas/UI/PlayerHud") as Node
	_expect(chroma != null, "player Chroma component is installed", failures)
	_expect(ability != null, "aspect ability component is installed", failures)
	_expect(projectile_controller != null, "projectile lifecycle owner is installed", failures)
	_expect(pickup_controller != null, "Chroma pickup lifecycle owner is installed", failures)
	if chroma != null:
		_expect(int(chroma.get("current_chroma")) == 0, "new runtime starts at zero Chroma", failures)
		_expect(int(chroma.call("ability_mode")) == 0, "new runtime resolves the Gray ability mode", failures)
	var chroma_label: Sprite2D = player_hud.get_node_or_null("PlayerStatus/Mana/MpLabel") as Sprite2D if player_hud != null else null
	_expect(chroma_label != null and chroma_label.texture != null, "Chroma HUD label is rendered", failures)
	if chroma_label != null and chroma_label.texture != null:
		_expect(chroma_label.texture.get_width() == 7, "Chroma HUD label reads CH", failures)
	var mp_fill: Sprite2D = player_hud.get_node_or_null("PlayerStatus/Mana/MpBarFill") as Sprite2D if player_hud != null else null
	_expect(mp_fill != null and mp_fill.texture != null, "Chroma HUD bar is rendered", failures)
	if mp_fill != null and mp_fill.texture != null:
		var mp_image: Image = mp_fill.texture.get_image()
		var mp_color_found := false
		for y in mp_image.get_height():
			for x in mp_image.get_width():
				if mp_image.get_pixel(x, y).a > 0.0 and mp_image.get_pixel(x, y).is_equal_approx(PaletteLibrary.ACCENT["blue"]):
					mp_color_found = true
		_expect(mp_color_found, "Chroma bar uses the light-blue MP accent", failures)
	if pickup_controller != null:
		gameplay.call("_spawn_chroma_pickup", Vector2(-10000.0, -10000.0), 25, 123, Vector2.ZERO)
		var pickup_sprites: Array = pickup_controller.get("sprites") as Array
		_expect(pickup_sprites.size() == 1, "Chroma pickup spawns in the scene", failures)
		if pickup_sprites.size() == 1:
			var pickup: Sprite2D = pickup_sprites[0] as Sprite2D
			_expect(bool(gameplay.call("_is_slime_walkable_point", pickup.global_position)), "Chroma pickup stays inside walkable space", failures)
			var pickup_image: Image = pickup.texture.get_image() if pickup.texture != null else null
			_expect(pickup_image != null and pickup_image.get_pixel(0, 0).is_equal_approx(PaletteLibrary.ACCENT["blue"]), "Chroma pickup matches the light-blue bar", failures)
			var chroma_light: PointLight2D = pickup.get_node_or_null("ChromaLight") as PointLight2D
			_expect(chroma_light != null and chroma_light.texture != null and chroma_light.energy > 0.0 and chroma_light.energy <= 0.20, "Chroma pickup uses a subtle light", failures)
			if chroma_light != null:
				_expect(chroma_light.color.is_equal_approx(PaletteLibrary.ACCENT["blue"]), "Chroma pickup light uses the bar color", failures)
				_expect(is_equal_approx(chroma_light.texture_scale, 0.70), "Chroma pickup light matches the fire scale", failures)
			var chroma_tuning := gameplay.get("chroma_tuning") as ChromaTuning
			var pickup_index: int = 0
			var pickup_air_times: Array = pickup_controller.get("air_times") as Array
			chroma_tuning.pickup_collection_distance = 0.0
			pickup_air_times[pickup_index] = 0.38
			var airborne_bounds_ok := true
			var previous_airborne_position := pickup.global_position
			var largest_airborne_step := 0.0
			for _air_frame in 10:
				gameplay.call("_update_chroma_pickups", 0.05)
				if is_instance_valid(pickup) and not bool(gameplay.call("_is_slime_walkable_point", pickup.global_position)):
					airborne_bounds_ok = false
				if is_instance_valid(pickup):
					largest_airborne_step = maxf(largest_airborne_step, pickup.global_position.distance_to(previous_airborne_position))
					previous_airborne_position = pickup.global_position
			_expect(airborne_bounds_ok, "Chroma pickup remains bounded during its launch", failures)
			_expect(largest_airborne_step <= 8.0, "Chroma pickup does not teleport while constrained", failures)
			pickup_air_times[pickup_index] = 0.0
			chroma_tuning.pickup_collection_distance = 0.0
			var bob_positions: Array[float] = []
			for _bob_frame in 8:
				gameplay.call("_update_chroma_pickups", 0.1)
				bob_positions.append(pickup.global_position.y)
			var bob_range := 0.0
			for bob_position in bob_positions:
				bob_range = maxf(bob_range, absf(bob_position - bob_positions[0]))
			_expect(bob_range > 0.01, "Chroma pickup bobs while resting", failures)
			var player_chroma: Node = gameplay.get("player_chroma_component") as Node
			player_chroma.call("attune", 1)
			player_chroma.call("spend_elemental_ability")
			chroma_tuning.pickup_collection_distance = 10.0
			var player_foot: Vector2 = gameplay.call("_actor_foot", gameplay.get("player")) as Vector2
			pickup.global_position = player_foot
			pickup.set_meta("chroma_base_position", player_foot)
			pickup_air_times[pickup_index] = 0.0
			var effects: Node = gameplay.get("effects_spawner") as Node
			var particle_count_before: int = (effects.get("pixel_particles") as Array).size()
			gameplay.call("_update_chroma_pickups", 0.01)
			var particle_count_after: int = (effects.get("pixel_particles") as Array).size()
			_expect(particle_count_after > particle_count_before, "Chroma pickup creates a splash burst on collection", failures)
	if ability != null:
		_expect(is_equal_approx(float(ability.get("cooldown_duration")), 2.0), "elemental triangle spell uses a 2 second cooldown", failures)
		_expect(is_equal_approx(float(ability.get("grey_cooldown_duration")), 2.5), "gray triangle spell uses a 2.5 second cooldown", failures)
	var player_animation := gameplay.get("player_animation_component") as PlayerAnimationComponent
	var equipment_visual := gameplay.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	var magic_runtime := gameplay.get("magic_runtime_controller") as MagicRuntimeController
	_expect(player_animation != null and player_animation.magic_frames.size() == 4, "triangle cast loads four body magic frames", failures)
	if equipment_visual != null:
		var magic_equipment_frames: Dictionary = equipment_visual.get("frames") as Dictionary
		_expect((magic_equipment_frames.get("sword_magic", []) as Array).size() == 4 and (magic_equipment_frames.get("shield_magic", []) as Array).size() == 4, "triangle cast loads four sword and shield magic frames", failures)
	if magic_runtime != null and player_animation != null and projectile_controller != null:
		var attack_tuning := gameplay.get("player_tuning") as PlayerTuning
		var magic_frame_time := float(magic_runtime.call("magic_frame_time", gameplay))
		var attack_multiplier := attack_tuning.attack_multiplier(float(gameplay.get("player_spd")))
		_expect(magic_frame_time > attack_tuning.attack_frame_time / attack_multiplier, "triangle magic animation is slower than attack animation", failures)
		_expect(bool(gameplay.call("_execute_current_aspect_ability", 0)), "triangle cast starts its visual animation", failures)
		if equipment_visual != null:
			equipment_visual.tick(gameplay, 0.0)
			var equipment_layers: Dictionary = equipment_visual.get("layers") as Dictionary
			var sword_back := equipment_layers.get("EquipmentSwordBack") as Sprite2D
			var sword_front := equipment_layers.get("EquipmentSwordFront") as Sprite2D
			_expect(sword_back != null and sword_back.visible and String(sword_back.get_meta("mp_grey_key", "")) == "sword_magic", "triangle magic sword uses the behind layer", failures)
			_expect(sword_front != null and not sword_front.visible, "triangle magic does not use the front sword layer", failures)
		_expect(bool(gameplay.get("player_is_magic_casting")) and int(gameplay.get("player_anim_frame")) == 0 and projectile_controller.projectiles.is_empty(), "triangle cast begins on frame 1 without firing", failures)
		magic_runtime.call("tick_magic_animation", gameplay, magic_frame_time * 1.01)
		_expect(int(gameplay.get("player_anim_frame")) == 1 and projectile_controller.projectiles.is_empty(), "triangle cast advances to frame 2 without firing", failures)
		magic_runtime.call("tick_magic_animation", gameplay, magic_frame_time * 1.01)
		_expect(int(gameplay.get("player_anim_frame")) == 2 and projectile_controller.projectiles.size() == 1, "triangle projectile fires on frame 3", failures)
		magic_runtime.call("tick_magic_animation", gameplay, magic_frame_time * 2.01)
		_expect(not bool(gameplay.get("player_is_magic_casting")), "triangle cast returns to the normal animation after frame 4", failures)
		magic_runtime.call("begin_magic_animation", gameplay, Vector2.LEFT, null, 0)
		if equipment_visual != null:
			equipment_visual.tick(gameplay, 0.0)
			var left_equipment_layers: Dictionary = equipment_visual.get("layers") as Dictionary
			var left_sword_back := left_equipment_layers.get("EquipmentSwordBack") as Sprite2D
			var left_shield_front := left_equipment_layers.get("EquipmentShieldFront") as Sprite2D
			var left_player := gameplay.get("player") as Sprite2D
			_expect(left_player != null and left_player.flip_h and left_player.texture == player_animation.magic_frames[0], "left-facing triangle uses the normal body frame with one horizontal flip", failures)
			_expect(left_sword_back != null and left_sword_back.flip_h, "left-facing triangle reverses the behind sword", failures)
			_expect(left_shield_front != null and left_shield_front.flip_h, "left-facing triangle reverses the shield", failures)
		magic_runtime.call("cancel_magic_animation", gameplay)
	if chroma != null:
		chroma.call("begin_new_run")
		_expect(int(chroma.get("current_chroma")) == 0, "new runtime starts at zero Chroma", failures)
		_expect(int(chroma.call("ability_mode")) == 0, "new runtime resolves the Gray ability mode", failures)
	_expect(gameplay.get("player_mp") == null, "coordinator no longer mirrors MP state", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CHROMA_PROJECTILE_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
