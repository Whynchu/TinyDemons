extends SceneTree

const ProgressionControllerScript = preload("res://scripts/progression_controller.gd")
const FrameControllerScript = preload("res://scripts/gameplay_frame_controller.gd")
const HubProgressionDraftScript = preload("res://scripts/hub_progression_draft.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var tuning := ProgressionTuning.new()
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
	settlement_run.mark_settled(&"complete")
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
	_expect(snapshot.vit == 7, "starter gear grants 2 flat VIT", failures)
	_expect(snapshot.strength == 4, "starter gear grants 1 net STR after shield penalty", failures)
	_expect(snapshot.def == 6, "starter gear grants 3 DEF", failures)
	_expect(snapshot.speed == 2, "starter gear grants 1 flat SPD", failures)
	_expect(snapshot.gear_vit == 2 and snapshot.gear_strength == 1 and snapshot.gear_def == 3, "starter flat primary gear snapshot", failures)
	var tall_stats := StatsComponent.new()
	tall_stats.configure_manual_growth(50, 50, 50, 50, 0, 0, 0, 0)
	var tall_snapshot := CombatStatSnapshot.from_components(tall_stats, equipment)
	_expect(tall_snapshot.gear_vit == 2, "gear VIT remains flat at scale", failures)
	_expect(tall_snapshot.gear_strength == 1, "gear STR remains flat at scale", failures)
	_expect(tall_snapshot.gear_def == 3, "gear DEF remains flat at scale", failures)
	_expect(tall_snapshot.gear_speed == 1, "gear SPD remains flat at scale", failures)
	_expect(tall_snapshot.strength == 51, "flat equipment STR enters effective snapshot", failures)
	_expect(tall_snapshot.def == 53, "flat shield DEF enters effective snapshot", failures)
	_expect(tall_snapshot.speed == 51, "equipment SPD enters effective snapshot", failures)
	var bloodwoven := ItemInstance.new(); bloodwoven.instance_id = "bloodwoven-test"; bloodwoven.definition_id = &"bloodwoven_tunic"; bloodwoven.rarity = &"epic"; bloodwoven.transmutation_id = &"bloodwoven_core"
	var bloodwoven_profile := PlayerProfile.new(); bloodwoven_profile.ensure_starter_items(); bloodwoven_profile.grant_item(bloodwoven); bloodwoven_profile.equip_item(bloodwoven.instance_id)
	var bloodwoven_equipment := EquipmentComponent.new(); bloodwoven_equipment.configure_from_profile(bloodwoven_profile)
	var bloodwoven_snapshot := CombatStatSnapshot.from_components(stats, bloodwoven_equipment)
	_expect(is_equal_approx(bloodwoven_snapshot.core_health_rate_bonus, 0.12), "bloodwoven adds Core HP scaling", failures)
	_expect(is_equal_approx(bloodwoven_snapshot.vit_health_multiplier_bonus, 0.20), "bloodwoven improves VIT health", failures)
	var plain_snapshot := CombatStatSnapshot.from_components(stats, equipment)
	var plain_health := CombatCalculator.max_health_for_snapshot(plain_snapshot)
	var bloodwoven_health := CombatCalculator.max_health_for_snapshot(bloodwoven_snapshot)
	_expect(bloodwoven_health > plain_health, "bloodwoven raises real maximum health", failures)
	_expect(is_equal_approx(CombatCalculator.max_health_for_snapshot(bloodwoven_snapshot), bloodwoven_health), "ordinary gear does not add HP rate", failures)
	var generated_bloodwoven_found := false
	var catalog := ItemCatalog.new()
	for seed in 256:
		var generated_armor := catalog.generate_item(&"armor", seed, 20, &"epic")
		if generated_armor.definition_id == &"bloodwoven_tunic":
			generated_bloodwoven_found = true
			_expect(generated_armor.transmutation_id == &"bloodwoven_core", "epic Bloodwoven generates its authored transmutation", failures)
			break
	_expect(generated_bloodwoven_found, "seed sample reaches Bloodwoven definition", failures)
	var generated_duelist_found := false
	for seed in 256:
		var generated_accessory := catalog.generate_item(&"accessory", seed, 20, &"epic")
		if generated_accessory.definition_id == &"duelist_seal":
			generated_duelist_found = true
			_expect(generated_accessory.transmutation_id == &"duelist_focus", "epic Duelist Seal generates its authored transmutation", failures)
			break
	_expect(generated_duelist_found, "seed sample reaches Duelist Seal definition", failures)
	var generated_gathering_found := false
	for seed in 256:
		var generated_weapon := catalog.generate_item(&"weapon", seed, 20, &"epic")
		if generated_weapon.definition_id == &"soldier_sword":
			generated_gathering_found = true
			_expect(generated_weapon.transmutation_id == &"gathering_edge", "epic Soldier Sword generates its authored transmutation", failures)
			break
	_expect(generated_gathering_found, "seed sample reaches Soldier Sword definition", failures)
	stats.free()
	tall_stats.free()
	equipment.free()
	bloodwoven_equipment.free()
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
