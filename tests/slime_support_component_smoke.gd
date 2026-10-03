extends SceneTree

const HEALER_DEFINITION := preload("res://resources/definitions/healer_slime.tres")
const PREVIEW_SCENE := preload("res://scenes/authoring/previews/enemy_preview_workbench.tscn")
const FRAME_LIBRARY_SCRIPT := preload("res://scripts/sprite_frame_library.gd")
const SLIME_TUNING := preload("res://resources/tuning/slime_default.tres")


class SupportAttackTestRoot:
	extends Node
	var slime_tuning: SlimeTuning = SLIME_TUNING.duplicate(true) as SlimeTuning
	var actor_collision_system: ActorCollisionSystem
	var player: Sprite2D
	var player_dead := false
	var slimes: Array[Sprite2D] = []
	var attack_started_count := 0

	func _slime_combat(actor: Sprite2D) -> SlimeCombatComponent:
		return actor.get_node("Combat") as SlimeCombatComponent

	func _slime_visual(actor: Sprite2D) -> SlimeVisualComponent:
		return actor.get_node("Visual") as SlimeVisualComponent

	func _is_slime_dead(_actor: Sprite2D) -> bool:
		return false

	func _is_slime_aggroed(_actor: Sprite2D) -> bool:
		return true

	func _actor_foot(actor: Sprite2D) -> Vector2:
		return actor.position

	func _can_slime_attack_player(_actor: Sprite2D) -> bool:
		return true

	func _start_slime_attack(actor: Sprite2D) -> void:
		attack_started_count += 1
		_slime_combat(actor).begin()

	func _set_slime_attack_frame(_actor: Sprite2D, _frame: int) -> void:
		pass

	func _set_actor_base_texture(_actor: Sprite2D, _texture: Texture2D) -> void:
		pass

	func _apply_slime_attack_lunge(_actor: Sprite2D, _progress: float) -> void:
		pass

	func _apply_slime_attack_hit(_actor: Sprite2D) -> void:
		pass

	func _restore_slime_idle_texture(_actor: Sprite2D) -> void:
		pass

	func _capture_slime_attack(_actor: Sprite2D) -> void:
		pass

var finished := false


func _initialize() -> void:
	create_timer(10.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var failures_ok: bool = HEALER_DEFINITION.validate().is_empty()
	_expect(failures_ok, "healer slime definition validates", failures)
	_expect(HEALER_DEFINITION.type_id == &"slime", "healer resolves to the slime actor family", failures)
	_expect(EnemyFactory.family_geometry_profile(HEALER_DEFINITION.type_id) == EnemyFactory.family_geometry_profile(&"slime"), "healer edits and uses the canonical Slime family geometry profile", failures)
	_expect(HEALER_DEFINITION.behavior_id == &"support_caster", "healer selects support caster behavior in data", failures)
	_expect(HEALER_DEFINITION.encounter_role == &"support", "healer is authored under the support encounter role", failures)
	_expect(EnemyFactory.definition(&"healer_slime") == HEALER_DEFINITION, "healer resolves from the enemy definition registry", failures)
	var actor := EnemyFactory.assemble(HEALER_DEFINITION)
	root.add_child(actor)
	_expect(actor is SlimeActor, "factory builds healer as a SlimeActor", failures)
	_expect(actor.get_node_or_null("Support") != null, "factory composes the support component from behavior_id", failures)
	_expect(bool(actor.get_node("Support").get("enabled")), "factory enables the selected support behavior", failures)
	_expect(actor.get_meta("enemy_type_id") == &"slime", "family identity remains slime", failures)
	var runtime_copy := HEALER_DEFINITION.duplicate(true) as EnemyDefinition
	runtime_copy.id = &"healer_slime_runtime_copy"
	EnemyFactory.configure_actor(actor, runtime_copy)
	_expect(actor.get_node_or_null("Support") != null and bool(actor.get_node("Support").get("enabled")), "another support definition opts in through the same data field", failures)
	var variants := EnemyFactory.weighted_variants_for_role(&"slime", &"support", 1)
	_expect(variants.any(func(entry: Dictionary) -> bool: return entry.get("variant") == "healer_slime"), "rank-one encounters can roll the healer as a support companion", failures)
	var run_one_rooms := RoomController.new()
	run_one_rooms.progression_run_rank = 1
	run_one_rooms.progression_run_number = 1
	var healer_seen_in_run_one := false
	var healer_roll_successes := 0
	var support_roll_opportunities := 0
	var every_healer_is_paired := true
	for seed in range(1, 513):
		var encounter := run_one_rooms._generate_enemy_encounter(seed, 1)
		var encounter_variants := encounter.get("variants", []) as Array
		var normal_slime_count := 0
		var room_healer_count := 0
		var has_non_support := false
		for variant in encounter_variants:
			var variant_definition := EnemyFactory.definition(StringName(variant))
			if variant_definition == null:
				continue
			if variant_definition.encounter_role == &"support":
				room_healer_count += 1
			else:
				has_non_support = true
				if variant_definition.type_id == &"slime":
					normal_slime_count += 1
		var room_roll_count := run_one_rooms._room_definition().support_companion_roll_count(normal_slime_count)
		support_roll_opportunities += room_roll_count
		healer_roll_successes += room_healer_count
		if room_healer_count > 0:
			healer_seen_in_run_one = true
			_expect(encounter_variants.size() >= 2, "healer adds an enemy slot beyond the regular lineup", failures)
			every_healer_is_paired = every_healer_is_paired and has_non_support
	_expect(every_healer_is_paired, "every generated healer has a non-support enemy in the room", failures)
	_expect(healer_seen_in_run_one, "seeded run-one encounters include healer companions", failures)
	var observed_healer_chance := float(healer_roll_successes) / float(maxi(support_roll_opportunities, 1))
	_expect(observed_healer_chance >= 0.45 and observed_healer_chance <= 0.55, "run-one healer companion rolls track the authored 50 percent chance per three Slimes (observed %.1f%%)" % (observed_healer_chance * 100.0), failures)
	for seed in range(1, 65):
		var boss_encounter := run_one_rooms._generate_boss_encounter(seed, 1)
		var boss_variants := boss_encounter.get("variants", []) as Array
		var boss_definition := EnemyFactory.definition(StringName(boss_variants[0])) if not boss_variants.is_empty() else null
		_expect(boss_definition != null and boss_definition.encounter_role != &"support", "support variants never become the primary boss", failures)
	run_one_rooms.free()
	var attack_root := SupportAttackTestRoot.new()
	attack_root.actor_collision_system = ActorCollisionSystem.new()
	attack_root.add_child(attack_root.actor_collision_system)
	root.add_child(attack_root)
	var solo_healer := EnemyFactory.assemble(HEALER_DEFINITION) as SlimeActor
	attack_root.add_child(solo_healer)
	var runtime_controller := SlimeRuntimeController.new()
	var attack_result: bool = runtime_controller.update_slime_attack(attack_root, solo_healer, 0.016)
	_expect(attack_result and (solo_healer.get_node("Combat") as SlimeCombatComponent).active and attack_root.attack_started_count == 1, "healer with no damaged ally starts a regular slime attack", failures)
	attack_root.free()
	runtime_controller.free()
	var preview := PREVIEW_SCENE.instantiate()
	root.add_child(preview)
	await process_frame
	var preview_actor := preview.get("preview_actor") as Sprite2D
	var cast_frames: Dictionary = SlimeVisualComponent.build_authored_support_animation_frames(FRAME_LIBRARY_SCRIPT.new(), Vector2i(16, 16), Callable(preview, "_ignore_warm_texture"))
	SlimeVisualComponent.assign_support_animation_frames([preview_actor], cast_frames)
	preview.set("_selected_definition", HEALER_DEFINITION)
	preview.set("preview_state", 7)
	await process_frame
	var preview_summary := preview.call("get_preview_summary") as Dictionary
	_expect(String(preview_summary.get("preview_state", "")) == "Support Casting", "healer preview exposes the looping support casting state", failures)
	_expect(int(preview_summary.get("frame_count", 0)) >= 2, "healer preview has its authored casting animation selected", failures)
	var preview_visual := preview_actor.get_node_or_null("Visual") as SlimeVisualComponent if preview_actor != null else null
	_expect(cast_frames.get("casting", []).size() >= 2 and cast_frames.get("spell", []).size() >= 2, "cast frame loader resolves separate casting and spell sheets", failures)
	preview.set("preview_state", 8)
	await process_frame
	preview_summary = preview.call("get_preview_summary") as Dictionary
	_expect(String(preview_summary.get("preview_state", "")) == "Support Spell", "healer preview exposes the one-shot spell animation", failures)
	_expect(int(preview_summary.get("frame_count", 0)) >= 2, "healer preview has its authored spell animation selected", failures)
	preview.queue_free()
	var regular := EnemyFactory.assemble(EnemyFactory.definition(&"green"))
	root.add_child(regular)
	_expect(regular.get_node_or_null("Support") == null, "ordinary slime does not gain support behavior", failures)
	actor.queue_free()
	regular.queue_free()
	finished = true
	await process_frame
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if not finished:
		push_error("TEST_ABORTED: slime support component fixture timed out")
		quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SLIME_SUPPORT_COMPONENT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
