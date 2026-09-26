extends SceneTree

const CatalogScript = preload("res://scripts/slime_variant_catalog.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")
const EnemySpawnServicesScript = preload("res://scripts/room_enemy_spawn_services.gd")

var rebound_enemy_damage_count := 0

## Slice C characterization: EncounterDefinition captures the rank-gated enemy
## pool as validated, editor-inspectable data. It must reject bad weights/policy,
## gate late families by run rank, and reproduce the authored shadow-bound
## composition contract.

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []

	var definition := EncounterDefinition.new()
	_expect(definition.validate().is_empty(), "default encounter definition validates", failures)
	_expect(definition.grey_weight == 1.0 and definition.shadow_weight == 0.12, "defaults keep the authored neutral/shadow weights", failures)

	var late_rank_1 := definition.late_pool_entries(1)
	_expect(late_rank_1.is_empty(), "no late elemental families below rank five", failures)
	var late_rank_5 := definition.late_pool_entries(5)
	var authored_late_count := 0
	for variant in CatalogScript.variants():
		var authored_definition := CatalogScript.definition_resource(variant)
		if authored_definition != null and authored_definition.encounter_role == &"late" and authored_definition.encounter_min_rank <= 5 and authored_definition.encounter_weight > 0.0:
			authored_late_count += 1
	_expect(late_rank_5.size() == authored_late_count, "rank five includes every authored late definition", failures)
	var late_names: Array[String] = []
	for entry in late_rank_5: late_names.append(str(entry["variant"]))
	_expect("yellow" in late_names and "orange" in late_names and "aquamarine" in late_names and "crimson" in late_names, "rank five pool includes yellow/ground/ice/crimson", failures)
	for entry in late_rank_5:
		_expect(float(entry["weight"]) > 0.0, "%s late entry carries a positive weight" % str(entry["variant"]), failures)

	var skeleton_entries := EnemyFactoryScript.weighted_variants_for_type(&"skeleton")
	_expect(skeleton_entries.size() == 8, "catalog registers the normal and seven elemental skeleton variants", failures)
	var rooms := RoomController.new()
	rooms.progression_run_rank = 4
	var skeleton_before_r5 := false
	var skeleton_slots_at_r5 := 0
	var total_slots_at_r5 := 0
	for seed in range(1, 513):
		var early_encounter := rooms._generate_enemy_encounter(seed, 1)
		for variant in early_encounter["variants"] as Array:
			skeleton_before_r5 = skeleton_before_r5 or EnemyFactoryScript.variant_is_type(StringName(variant), &"skeleton")
	rooms.progression_run_rank = 5
	for seed in range(1, 513):
		var r5_encounter := rooms._generate_enemy_encounter(seed, 1)
		for variant in r5_encounter["variants"] as Array:
			total_slots_at_r5 += 1
			if EnemyFactoryScript.variant_is_type(StringName(variant), &"skeleton"):
				skeleton_slots_at_r5 += 1
	_expect(not skeleton_before_r5, "skeletons do not enter the regular pool before run rank five", failures)
	var skeleton_share_at_r5 := float(skeleton_slots_at_r5) / float(maxi(total_slots_at_r5, 1))
	_expect(skeleton_share_at_r5 >= 0.45 and skeleton_share_at_r5 <= 0.55, "run rank five and later enemy slots split evenly between skeletons and slimes at every room depth (observed %.1f%%)" % (skeleton_share_at_r5 * 100.0), failures)
	rooms.free()
	var actor_parent := Node2D.new()
	root.add_child(actor_parent)
	var actor_slot := EnemyFactoryScript.assemble(EnemyFactoryScript.definition(&"grey"))
	actor_slot.name = "EnemySlot1"
	actor_parent.add_child(actor_slot)
	var actor_pool: Array[Sprite2D] = [actor_slot]
	var actor_sprites: Array[Sprite2D] = [actor_slot]
	var collision_sprites: Array[Sprite2D] = [actor_slot]
	var hud := HudController.new()
	root.add_child(hud)
	var actor_hp_frame := Sprite2D.new()
	actor_hp_frame.name = "HpOverhead"
	actor_slot.add_child(actor_hp_frame)
	var actor_aggro_marker := Sprite2D.new()
	actor_aggro_marker.name = "AggroMarker"
	actor_slot.add_child(actor_aggro_marker)
	var last_valid_positions: Dictionary = {actor_slot: Vector2(42.0, 84.0)}
	hud.target_overhead_frames[actor_slot] = actor_hp_frame
	hud.target_overhead_aggro_markers[actor_slot] = actor_aggro_marker
	var spawn_services := EnemySpawnServicesScript.new() as RoomEnemySpawnServices
	spawn_services.slimes = actor_pool
	spawn_services.actor_sprites = actor_sprites
	spawn_services.collision_sprites = collision_sprites
	spawn_services.last_valid_positions = last_valid_positions
	spawn_services.hud_controller = hud
	spawn_services.enemy_health_damaged_callback = Callable(self, "_on_test_enemy_damaged")
	spawn_services.enemy_health_healed_callback = Callable(self, "_on_test_enemy_healed")
	spawn_services.enemy_health_changed_callback = Callable(self, "_on_test_enemy_health_changed")
	spawn_services.configure_slime_variant(actor_slot, "skeleton")
	_expect(actor_pool[0] is SkeletonActor, "selected skeleton definition replaces the pooled slime actor family", failures)
	_expect(actor_sprites[0] is SkeletonActor and collision_sprites[0] is SkeletonActor, "actor and collision lists follow family replacement", failures)
	_expect(actor_hp_frame.get_parent() == actor_pool[0] and hud.target_overhead_frames.has(actor_pool[0]), "enemy HP bar remains attached and registered after family replacement", failures)
	_expect(actor_aggro_marker.get_parent() == actor_pool[0] and hud.target_overhead_aggro_markers.has(actor_pool[0]), "aggro marker remains attached and registered after family replacement", failures)
	_expect(not last_valid_positions.has(actor_slot) and last_valid_positions.get(actor_pool[0]) == Vector2(42.0, 84.0), "last valid walkable position follows the replacement actor", failures)
	var replacement_health := actor_pool[0].get_node("Health") as HealthComponent
	replacement_health.reset(1.0)
	replacement_health.apply_damage(0.5)
	_expect(rebound_enemy_damage_count == 1, "replacement actors retain enemy health signal presentation wiring", failures)
	var skeleton_slot := actor_pool[0]
	spawn_services.configure_slime_variant(skeleton_slot, "grey")
	_expect(actor_pool[0] is SlimeActor and not actor_pool[0] is SkeletonActor, "slime variant restores the slime actor family", failures)
	actor_parent.free()

	var bad := EncounterDefinition.new()
	bad.matchup_policy = "not_a_policy"
	_expect(not bad.validate().is_empty(), "unknown matchup policy is rejected", failures)
	var bad_weight := EncounterDefinition.new()
	bad_weight.grey_weight = -1.0
	_expect(not bad_weight.validate().is_empty(), "negative weight is rejected", failures)

	var shadow := EncounterDefinition.new()
	shadow.matchup_policy = EncounterDefinition.POLICY_SHADOW_BOUND
	_expect(shadow.is_shadow_bound(), "shadow-bound policy is recognized", failures)
	_expect(shadow.shadow_bound_normal_weight == 0.20 and shadow.shadow_bound_variant_weight == 0.80, "shadow-bound relief contract is preserved", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: encounter definition failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENCOUNTER_DEFINITION_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _on_test_enemy_damaged(_amount: float, _actor: Sprite2D) -> void:
	rebound_enemy_damage_count += 1


func _on_test_enemy_healed(_amount: float, _actor: Sprite2D) -> void:
	pass


func _on_test_enemy_health_changed(_current: float, _maximum: float, _actor: Sprite2D) -> void:
	pass


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
