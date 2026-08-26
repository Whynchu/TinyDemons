extends SceneTree

const GRAPH_SCRIPT = preload("res://scripts/dungeon_graph.gd")
const Elements = preload("res://scripts/element_catalog.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Orb Room interaction coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var graph := gameplay.get("dungeon_graph") as DungeonGraph
	var map := gameplay.get("dungeon_map_controller") as Node
	var rooms := gameplay.get("room_controller") as RoomController
	var puzzle := gameplay.get("room_puzzle_controller") as RoomPuzzleController
	_expect(graph != null and map != null and rooms != null and puzzle != null, "Orb Room interaction owners are composed", failures)
	if graph != null and map != null and rooms != null and puzzle != null:
		map.call("begin_run", graph, 44017, 0, &"fire")
		rooms.room_states.clear()
		var orb_room_id: StringName = &"room_-1_1"
		gameplay.set("current_room_id", orb_room_id)
		gameplay.call("_sync_current_room_metadata")
		rooms.set_current_room(orb_room_id, gameplay.get("current_room_type"))
		gameplay.call("_collect_dungeon_sockets")
		gameplay.call("_ensure_current_room_layout")
		gameplay.call("_apply_room_state")
		var orbs := gameplay.get("puzzle_torches") as Array[Sprite2D]
		_expect(orbs.size() == 1, "Orb Room creates one targetable orb", failures)
		var tutorial_prompt := gameplay.get("orb_tutorial_prompt") as Sprite2D
		_expect(tutorial_prompt != null and tutorial_prompt.texture != null and tutorial_prompt.texture.resource_path.ends_with("triangle55.png"), "first Orb Room begins with the floating triangle lesson prompt", failures)
		_expect(tutorial_prompt != null and tutorial_prompt.get_node_or_null("FirstOrbTutorialPromptOutline") != null, "first Orb triangle prompt has a white outline layer", failures)
		if orbs.size() == 1:
			var orb := orbs[0]
			gameplay.call("_set_current_target", orb, false)
			var motor := gameplay.get("player_motor") as ActorMotor
			motor.knockback_remaining = 0.0
			puzzle.call("activate_puzzle_torch", gameplay, orb, orb.global_position, "red", false)
			_expect(is_zero_approx(motor.knockback_remaining), "ranged orb magic does not apply player knockback", failures)
			_expect(gameplay.get("current_target") == orb, "orb remains targeted after its color/state changes", failures)
			_expect(tutorial_prompt != null and tutorial_prompt.texture != null and tutorial_prompt.texture.resource_path.ends_with("square55.png"), "first Orb Room changes to the floating square lesson prompt after activation", failures)
			_expect(tutorial_prompt != null and tutorial_prompt.get_node_or_null("FirstOrbTutorialPromptOutline") != null and (tutorial_prompt.get_node("FirstOrbTutorialPromptOutline") as Sprite2D).texture != null, "first Orb square prompt keeps the white outline layer", failures)
			motor.knockback_remaining = 0.0
			puzzle.call("activate_puzzle_torch", gameplay, orb, orb.global_position, "grey", true)
			_expect(motor.knockback_remaining > 0.0, "physical orb activation retains its close-range reaction", failures)
			# A weapon carrying an element must pass that palette through the same
			# physical-hit path instead of reverting the orb to grey.
			var attack := gameplay.get("player_attack_component") as PlayerAttackComponent
			var player := gameplay.get("player") as Sprite2D
			if attack != null and player != null:
				player.global_position = orb.global_position - Vector2(10.0, 10.0)
				player.flip_h = false
				gameplay.set("player_attack_flip_h", false)
				attack.variant = 1
				attack.attack_element = Elements.Element.FIRE
				attack.hit_targets.clear()
				attack.apply_hitbox(gameplay)
				_expect(str(orb.get_meta("puzzle_torch_palette", "")) == "red", "imbued physical hit changes the Orb Room orb to its weapon element", failures)
			for fusion_palette in ["green", "aquamarine", "orange", "purple"]:
				puzzle.call("activate_puzzle_torch", gameplay, orb, orb.global_position, fusion_palette, false)
				_expect(str(orb.get_meta("puzzle_torch_palette", "")) == fusion_palette, "%s elemental energy recolors the Orb Room orb" % fusion_palette, failures)
				_expect(str(map.call("orb_display_palette")) == fusion_palette, "%s elemental energy persists across the shared Orb Room state" % fusion_palette, failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ORB_INTERACTION_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
