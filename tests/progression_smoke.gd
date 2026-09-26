extends SceneTree

const ProgressionControllerScript = preload("res://scripts/progression_controller.gd")
const FrameControllerScript = preload("res://scripts/gameplay_frame_controller.gd")
const HubProgressionDraftScript = preload("res://scripts/hub_progression_draft.gd")
const RunSettlementContextScript = preload("res://scripts/run_settlement_context.gd")
const RunSettlementResultScript = preload("res://scripts/run_settlement_result.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := ProgressionTuning.new()
	_expect(tuning.xp_required_for_level(1) == 100, "level 1 XP threshold remains 100", failures)
	_expect(tuning.xp_required_for_level(10) < 3400, "late XP curve is less steep after pacing pass", failures)
	_expect(tuning.xp_required_for_level(20) < 9000, "high-level XP curve remains attainable", failures)
	var draft = HubProgressionDraftScript.new()
	draft.vit = 2
	_expect(draft.as_dictionary()["VIT"] == 2, "hub draft owns ephemeral stat edits", failures)
	draft.clear()
	_expect(draft.vit == 0 and draft.spd == 0, "hub draft cancel clears edits", failures)
	_expect(FrameControllerScript.phase_order() == [&"input", &"simulation", &"contact_resolution", &"damage_and_progression", &"presentation", &"transitions"], "frame phase order is explicit", failures)
	_expect(tuning.stat_points_for_level(5) == 1, "level 5 point band", failures)
	_expect(tuning.stat_points_for_level(6) == 2, "level 6 point band", failures)
	_expect(tuning.stat_points_for_level(20) == 3, "level 20 point band", failures)
	_expect(tuning.stat_points_for_level(21) == 4, "level 21 point band", failures)
	_expect(tuning.stat_points_for_level(36) == 5, "level 36 point cap", failures)

	var profile := PlayerProfile.new()
	profile.has_started = true
	var xp_grant := tuning.xp_required_for_level(1) + tuning.xp_required_for_level(2) + 3
	var result := profile.award_xp(xp_grant, tuning)
	_expect(profile.level == 3, "multi-level XP grant", failures)
	_expect(profile.xp == 3, "XP overflow retained", failures)
	_expect(profile.unspent_stat_points == 2, "points awarded for every crossed level", failures)
	_expect(int(result["levels"]) == 2, "level result count", failures)
	_expect(profile.allocate_stat(&"VIT", 1), "manual allocation succeeds", failures)
	var domain_profile := PlayerProfile.new()
	domain_profile.unspent_stat_points = 3
	_expect(ProgressionControllerScript.points_remaining(domain_profile, {"VIT": 1, "STR": 1}) == 1, "hub draft points are domain-calculated", failures)
	var domain_allocation: Dictionary = ProgressionControllerScript.allocate_stats(domain_profile, {"VIT": 1, "STR": 1})
	_expect(bool(domain_allocation["changed"]) and domain_profile.unspent_stat_points == 1, "domain allocation applies requested stats", failures)
	_expect(ProgressionControllerScript.apply_run_grade(domain_profile, "A") and domain_profile.difficulty_rank == 2, "run grade applies through domain API", failures)
	var settlement_run := RunState.new()
	settlement_run.begin(42)
	_expect(RunSettlement.can_settle(settlement_run, &"complete"), "active run can settle", failures)
	var settlement_profile := PlayerProfile.new()
	var settlement_context := RunSettlementContextScript.new(settlement_profile, settlement_run, &"complete")
	_expect(settlement_context.is_valid(), "typed settlement context exposes the required durable inputs", failures)
	settlement_run.mark_settled(&"complete")
	var duplicate_settlement := RunSettlement.settle_context(settlement_context)
	_expect(duplicate_settlement.status == RunSettlementResultScript.Status.ALREADY_SETTLED, "typed settlement result reports duplicate settlement", failures)
	_expect(not RunSettlement.can_settle(settlement_run, &"complete"), "settlement is idempotently closed", failures)

	var restored := PlayerProfile.new()
	restored.load_dictionary(profile.to_dictionary())
	_expect(restored.level == profile.level and restored.allocated_vit == 1, "profile serialization round trip", failures)

	var sampled_starter_depths: Dictionary = {}
	var sampled_gray_depths: Dictionary = {}
	for seed in 64:
		var tutorial_graph := DungeonGraph.new()
		tutorial_graph.configure_progression(0)
		tutorial_graph.initialize(seed)
		sampled_starter_depths[tutorial_graph.tutorial_starter_puzzle_depth] = true
		sampled_gray_depths[tutorial_graph.tutorial_gray_puzzle_depth] = true
		_expect(tutorial_graph.tutorial_starter_puzzle_depth >= 2 and tutorial_graph.tutorial_starter_puzzle_depth <= 4, "starter puzzle depth is in the early Run 1 band at seed %d" % seed, failures)
		_expect(tutorial_graph.tutorial_gray_puzzle_depth >= 7 and tutorial_graph.tutorial_gray_puzzle_depth <= 9, "Gray puzzle depth is in the late Run 1 band at seed %d" % seed, failures)
		_expect(tutorial_graph.tutorial_starter_puzzle_depth < tutorial_graph.tutorial_gray_puzzle_depth, "Run 1 puzzle order is stable at seed %d" % seed, failures)
	_expect(sampled_starter_depths.size() > 1 and sampled_gray_depths.size() > 1, "tutorial puzzle depths vary across dungeon seeds", failures)
	var later_graph := DungeonGraph.new()
	later_graph.configure_progression(1)
	later_graph.initialize(101)
	_expect(later_graph.tutorial_starter_puzzle_depth == -1 and later_graph.tutorial_gray_puzzle_depth == -1, "tutorial puzzle milestones are Run 1 only", failures)

	var stats := StatsComponent.new()
	stats.configure_manual_growth(4, 3, 3, 1, 1, 0, 0, 0)
	var equipment := EquipmentComponent.new()
	equipment.equip_default_loadout()
	var snapshot := CombatStatSnapshot.from_components(stats, equipment)
	_expect(snapshot.vit == 5, "Plain starter gear leaves the authored VIT baseline unchanged", failures)
	_expect(snapshot.strength == 3, "Plain starter gear leaves the authored STR baseline unchanged", failures)
	_expect(snapshot.def == 3, "Plain starter gear leaves the authored DEF baseline unchanged", failures)
	_expect(snapshot.speed == 1, "Plain starter gear leaves the authored AGI baseline unchanged", failures)
	_expect(snapshot.gear_vit == 0 and snapshot.gear_strength == 0 and snapshot.gear_def == 0 and snapshot.gear_speed == 0, "Plain starter loadout contributes no flat primary gear points", failures)
	var tall_stats := StatsComponent.new()
	tall_stats.configure_manual_growth(50, 50, 50, 50, 0, 0, 0, 0)
	var tall_snapshot := CombatStatSnapshot.from_components(tall_stats, equipment)
	_expect(tall_snapshot.gear_vit == 0, "Plain starter gear remains flat at scale for VIT", failures)
	_expect(tall_snapshot.gear_strength == 0, "Plain starter gear remains flat at scale for STR", failures)
	_expect(tall_snapshot.gear_def == 0, "Plain starter gear remains flat at scale for DEF", failures)
	_expect(tall_snapshot.gear_speed == 0, "Plain starter gear remains flat at scale for AGI", failures)
	_expect(tall_snapshot.strength == 50, "the authored STR baseline enters the effective snapshot", failures)
	_expect(tall_snapshot.def == 50, "the authored DEF baseline enters the effective snapshot", failures)
	_expect(tall_snapshot.speed == 50, "the authored AGI baseline enters the effective snapshot", failures)

	var health_tuning := CombatTuning.new()
	var level_one_health_snapshot := CombatStatSnapshot.new()
	level_one_health_snapshot.level = 1
	level_one_health_snapshot.vit = 4
	var level_ten_health_snapshot := CombatStatSnapshot.new()
	level_ten_health_snapshot.level = 10
	level_ten_health_snapshot.vit = 4
	var level_one_health := CombatCalculator.max_health_for_snapshot(level_one_health_snapshot, health_tuning)
	var level_ten_health := CombatCalculator.max_health_for_snapshot(level_ten_health_snapshot, health_tuning)
	_expect(is_equal_approx(level_one_health, level_ten_health), "leveling alone does not increase maximum HP", failures)
	var vit_health_snapshot := CombatStatSnapshot.new()
	vit_health_snapshot.level = 10
	vit_health_snapshot.vit = 5
	_expect(CombatCalculator.max_health_for_snapshot(vit_health_snapshot, health_tuning) > level_ten_health, "allocated VIT increases maximum HP", failures)
	var gear_health_snapshot := CombatStatSnapshot.new()
	gear_health_snapshot.level = 10
	gear_health_snapshot.vit = 4
	gear_health_snapshot.core_health_rate_bonus = 0.10
	_expect(CombatCalculator.max_health_for_snapshot(gear_health_snapshot, health_tuning) > level_ten_health, "HP-specific gear increases maximum HP", failures)
	_expect(is_equal_approx(health_tuning.health_per_level, 0.0), "default combat tuning has no level-only HP", failures)
	_expect(is_equal_approx(CombatRuntimeController.enemy_health_factor(0), 0.50), "R1 regular enemy health factor is softened", failures)
	_expect(is_equal_approx(CombatRuntimeController.enemy_health_factor(1), 0.65), "R2 regular enemy health factor is softened", failures)
	_expect(CombatRuntimeController.enemy_health_factor(0) < CombatRuntimeController.enemy_health_factor(1), "enemy health still progresses between runs", failures)

	var shield_catalog := ItemCatalog.new()
	var base_bulwark := ItemInstance.new()
	base_bulwark.definition_id = &"basic_shield"
	base_bulwark.rarity = &"rare"
	var enhanced_bulwark := ItemInstance.from_dictionary(base_bulwark.to_dictionary())
	enhanced_bulwark.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT
	var base_shield_values := shield_catalog.shield_bonuses(base_bulwark)
	var enhanced_shield_values := shield_catalog.shield_bonuses(enhanced_bulwark)
	_expect(is_equal_approx(shield_catalog.combat_primary_points(base_bulwark).get("speed", 0.0), -1.0), "shield speed trade-off is part of the flat package", failures)
	_expect(is_equal_approx(base_shield_values.get("strength_penalty", 0.0), 0.0) and is_equal_approx(base_shield_values.get("speed_penalty", 0.0), 0.0), "shield has no hidden primary-stat penalties", failures)
	_expect(enhanced_shield_values["guard_durability"] > base_shield_values["guard_durability"], "shield guard durability still improves with enhancement", failures)
	_expect(shield_catalog.combat_primary_points(enhanced_bulwark)["defense"] > shield_catalog.combat_primary_points(base_bulwark)["defense"], "shield DEF still improves with enhancement", failures)
	var bloodwoven_catalog := ItemCatalog.new()
	bloodwoven_catalog.definitions[&"test_blood_body"] = {
		"name": "TEST BLOOD BODY", "slot": &"body", "gear_tier": "basic",
		"tier_stat": "vitality", "bonuses": {"vitality": 2.0}, "effects": {},
		"source_tags": ["test_fixture"], "price": 100,
	}
	bloodwoven_catalog.transmutations[&"bloodwoven_core"] = {
		"definitions": [&"test_blood_body"], "min_rarity": "epic",
		"name": "TEST BLOODWOVEN CORE", "slot": &"body",
		"effects": {"core_health_rate": 0.12, "vit_health_multiplier": 0.20},
	}
	var bloodwoven := ItemInstance.new(); bloodwoven.instance_id = "bloodwoven-test"; bloodwoven.definition_id = &"test_blood_body"; bloodwoven.rarity = &"epic"; bloodwoven.transmutation_id = &"bloodwoven_core"
	var bloodwoven_profile := PlayerProfile.new(); bloodwoven_profile.ensure_starter_items(bloodwoven_catalog); bloodwoven_profile.grant_item(bloodwoven); bloodwoven_profile.equip_item(bloodwoven.instance_id, bloodwoven_catalog)
	var bloodwoven_equipment := EquipmentComponent.new(); bloodwoven_equipment.configure_from_profile(bloodwoven_profile, bloodwoven_catalog)
	var bloodwoven_snapshot := CombatStatSnapshot.from_components(stats, bloodwoven_equipment)
	_expect(is_equal_approx(bloodwoven_snapshot.core_health_rate_bonus, 0.12), "bloodwoven adds Core HP scaling", failures)
	_expect(is_equal_approx(bloodwoven_snapshot.vit_health_multiplier_bonus, 0.20), "bloodwoven improves VIT health", failures)
	var plain_snapshot := CombatStatSnapshot.from_components(stats, equipment)
	var plain_health := CombatCalculator.max_health_for_snapshot(plain_snapshot)
	var bloodwoven_health := CombatCalculator.max_health_for_snapshot(bloodwoven_snapshot)
	_expect(bloodwoven_health > plain_health, "bloodwoven raises real maximum health", failures)
	_expect(is_equal_approx(CombatCalculator.max_health_for_snapshot(bloodwoven_snapshot), bloodwoven_health), "ordinary gear does not add HP rate", failures)
	var catalog := ItemCatalog.new()
	for retired_id: StringName in ItemCatalog.RETIRED_DEFINITION_IDS:
		_expect(not catalog.definition_exists(retired_id), "%s is absent after catalog retirement" % retired_id, failures)
	var generated_set_found := false
	for seed in 256:
		var generated_weapon := catalog.generate_item(&"weapon", seed, 20, &"epic")
		var generated_definition := catalog.definition_data(generated_weapon.definition_id)
		generated_set_found = generated_set_found or str(generated_definition.get("gear_tier", "")) == "set"
	_expect(generated_set_found, "seed sample reaches the live set catalogue", failures)
	stats.free()
	tall_stats.free()
	equipment.free()
	bloodwoven_equipment.free()
	bloodwoven_catalog = null
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: progression smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PROGRESSION_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
