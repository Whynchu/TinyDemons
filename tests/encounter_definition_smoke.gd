extends SceneTree

const CatalogScript = preload("res://scripts/slime_variant_catalog.gd")
const EnemyFactoryScript = preload("res://scripts/enemy_factory.gd")

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
	rooms.progression_run_rank = 1
	var skeleton_before_r5 := false
	var skeleton_at_r5 := false
	for seed in range(1, 65):
		var early_encounter := rooms._generate_enemy_encounter(seed, 4)
		var r5_encounter := rooms._generate_enemy_encounter(seed, 5)
		for variant in early_encounter["variants"] as Array:
			skeleton_before_r5 = skeleton_before_r5 or EnemyFactoryScript.variant_is_type(StringName(variant), &"skeleton")
		for variant in r5_encounter["variants"] as Array:
			skeleton_at_r5 = skeleton_at_r5 or EnemyFactoryScript.variant_is_type(StringName(variant), &"skeleton")
	_expect(not skeleton_before_r5, "skeletons do not enter the regular pool before R5", failures)
	_expect(skeleton_at_r5, "registered skeletons can roll into regular R5 encounters", failures)
	rooms.free()

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


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
