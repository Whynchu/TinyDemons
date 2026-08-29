extends SceneTree

var _finished := false


func _initialize() -> void:
	create_timer(15.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for fire exchange coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var profile := gameplay.get("player_profile") as PlayerProfile
	var health := gameplay.get("player_health_component") as HealthComponent
	var chroma := gameplay.get("player_chroma_component") as Node
	var npc := gameplay.get("npc_controller") as NpcController
	var chest_controller := gameplay.get("chest_controller") as ChestController
	_expect(profile != null and health != null and chroma != null and npc != null and chest_controller != null, "fire exchange owners are composed", failures)
	if profile != null and health != null and chroma != null and npc != null and chest_controller != null:
		profile.has_started = true
		profile.completed_runs = 0
		profile.starter_flame = &"fire"
		profile.palette_name = "red"
		profile.souls = 0
		profile.starter_soul_gift_claimed = false
		profile.has_bound_element = false
		profile.bound_element = &""
		gameplay.set("starter_flame_attuned_this_run", false)
		chroma.call("clear_bound_aspect")
		gameplay.call("_begin_new_run")
		npc.show_dialogue(gameplay)
		_expect(profile.souls == 5 and profile.starter_soul_gift_claimed, "Cloaked Demon grants the 5-Soul starter gift", failures)
		_expect(String(npc.full_message).contains("5 SOULS"), "starter gift is explained in Cloaked Demon dialogue", failures)
		npc.hide_dialogue(gameplay)
		# The gift is conditional on being out of Souls, not a one-time start-of-
		# game grant: a veteran with zero Souls receives it again.
		profile.souls = 0
		profile.completed_runs = 3
		npc.show_dialogue(gameplay)
		_expect(profile.souls == 5, "Cloaked Demon re-offers Souls whenever the player is out", failures)
		_expect(String(npc.full_message).contains("5 SOULS"), "the re-offer is explained in Cloaked Demon dialogue", failures)
		npc.hide_dialogue(gameplay)
		profile.completed_runs = 0
		var player := gameplay.get("player") as Sprite2D
		player.global_position += (gameplay.call("_fire_anchor") as Vector2) - (gameplay.call("_actor_foot", player) as Vector2)
		gameplay.call("_update_interact_prompt", 0.0)
		var interact_prompt := gameplay.get("interact_prompt") as Sprite2D
		var fire_cost := interact_prompt.get_node_or_null("FireCost") as Sprite2D if interact_prompt != null else null
		_expect(fire_cost != null and fire_cost.visible and fire_cost.texture != null and fire_cost.position.y < 0.0, "fire interaction shows the Soul cost above the circle prompt", failures)
		profile.souls = 0
		_expect(bool(gameplay.call("_can_interact_with_fire")), "starter fire remains interactable without Souls", failures)
		_hold_flame(gameplay, chest_controller)
		_expect(chroma.call("aspect_name") == &"gray" and profile.souls == 0, "a held flame without a recipe does not fall back to Swap", failures)
		_tap_flame(gameplay, chest_controller)
		_expect(not bool(gameplay.get("starter_flame_attuned_this_run")) and chroma.call("aspect_name") == &"gray", "starter fire refuses an unpaid use", failures)
		profile.souls = 5
		health.apply_damage(1.0)
		var damaged_health := health.current_health
		for _frame in 90:
			await process_frame
		_expect(is_equal_approx(health.current_health, damaged_health), "fire rooms do not passively heal without a fire use", failures)
		_tap_flame(gameplay, chest_controller)
		_expect(bool(gameplay.get("starter_flame_attuned_this_run")) and chroma.call("aspect_name") == &"fire", "first starter attunement costs 5 Souls", failures)
		_expect(profile.souls == 0 and health.current_health == health.maximum_health and chroma.get("current_chroma") == 100, "one fire use restores HP and active Chroma", failures)
		_expect(not bool(gameplay.call("_can_interact_with_fire")), "a full-health, full-Chroma same-color flame is unavailable", failures)

		health.apply_damage(1.0)
		chroma.call("spend_elemental_ability")
		_tap_flame(gameplay, chest_controller)
		_expect(health.current_health < health.maximum_health and chroma.get("current_chroma") < 100 and profile.souls == 0, "fire refuses a second use without Souls", failures)
		profile.souls = 5
		_tap_flame(gameplay, chest_controller)
		_expect(health.current_health == health.maximum_health and chroma.get("current_chroma") == 100 and profile.souls == 0, "each fire use costs one fixed 5-Soul transaction", failures)

		# Force an earned alternate palette through the legacy fallback path so the
		# test isolates the same atomic transaction while changing elements.
		gameplay.set("dungeon_map_controller", null)
		gameplay.set("run_start_palette_name", "blue")
		gameplay.set("current_fire_palette_name", "blue")
		(gameplay.get("screen_state_controller") as Node).set("player_palette_name", "red")
		profile.souls = 5
		_tap_flame(gameplay, chest_controller)
		_expect((gameplay.get("screen_state_controller") as Node).get("player_palette_name") == "blue", "fire exchanges 5 Souls for an earned element change", failures)
		_expect(chroma.call("aspect_name") == &"water" and chroma.get("current_chroma") == 100 and profile.souls == 0, "the fixed fire cost also covers an element change", failures)
		# A quick press swaps even when a recipe exists. Holding the same input
		# through the gesture threshold fuses the current element instead.
		chroma.call("attune_flame", &"fire")
		gameplay.set("current_fire_palette_name", "yellow")
		gameplay.set("run_start_palette_name", "yellow")
		profile.souls = 5
		_tap_flame(gameplay, chest_controller)
		_expect(chroma.call("aspect_name") == &"electric" and profile.souls == 0, "a quick flame press swaps instead of fusing", failures)
		chroma.call("attune_flame", &"fire")
		profile.souls = 5
		_hold_flame(gameplay, chest_controller)
		_expect(chroma.call("aspect_name") == &"ground" and profile.souls == 0, "fusion produces the current unbound result for 5 Souls", failures)
		_expect(not profile.has_bound_element and profile.palette_name == "red", "temporary fusion does not mutate the profile identity", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: fire exchange smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("FIRE_EXCHANGE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)


func _interaction_values(gameplay: Node) -> Array[Variant]:
	return [int(gameplay.get("CHEST_REWARD_GOLD")), float(gameplay.get("CHEST_COLLECT_FLASH_TIME"))]


func _tap_flame(gameplay: Node, chest_controller: ChestController) -> void:
	var values := _interaction_values(gameplay)
	chest_controller.update_interaction(gameplay, true, false, int(values[0]), float(values[1]), 0.0)
	chest_controller.update_interaction(gameplay, false, true, int(values[0]), float(values[1]), 1.0 / 60.0)


func _hold_flame(gameplay: Node, chest_controller: ChestController) -> void:
	var values := _interaction_values(gameplay)
	chest_controller.update_interaction(gameplay, true, false, int(values[0]), float(values[1]), 0.0)
	for _frame in 30:
		chest_controller.update_interaction(gameplay, true, true, int(values[0]), float(values[1]), 1.0 / 60.0)
	chest_controller.update_interaction(gameplay, false, true, int(values[0]), float(values[1]), 1.0 / 60.0)
