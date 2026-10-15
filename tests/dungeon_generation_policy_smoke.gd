extends SceneTree

## Slice D characterization: DungeonGenerationPolicy makes generation inputs
## explicit and validated. The generator must read candidate counts from the
## policy (not hardcoded constants), and the policy must reject invalid values.

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []

	var policy := DungeonGenerationPolicy.new()
	_expect(policy.validate().is_empty(), "default generation policy validates", failures)
	_expect(policy.generated_candidate_count == 1 and policy.risk_reward_candidate_count == 3, "defaults keep the authored candidate pool sizes", failures)
	var policy_field_names: Array[String] = []
	for property_info: Dictionary in policy.get_property_list():
		policy_field_names.append(str(property_info.get("name", "")))
	_expect("first_orb_depth" not in policy_field_names and "first_special_depth" not in policy_field_names and "primary_flames" not in policy_field_names, "fixed room anchors and starter flames are not duplicated as policy fields", failures)
	_expect(policy.risk_choice_min_y == 4 and policy.risk_choice_boss_margin == 2, "defaults keep the risk-route depth band", failures)
	_expect(policy.elemental_vault_cap == 2 and policy.risk_route_shortcut_advantage == 1, "defaults keep the vault cap and route advantage", failures)
	_expect(policy.is_valid_risk_choice_y(5, 10), "a room inside the risk band is a valid risk source", failures)
	_expect(not policy.is_valid_risk_choice_y(3, 10), "a room above the risk band is rejected", failures)
	_expect(not policy.is_valid_risk_choice_y(9, 10), "a room at the boss margin is rejected", failures)

	var bad := DungeonGenerationPolicy.new()
	bad.generated_candidate_count = 0
	bad.risk_reward_candidate_count = 0
	bad.risk_choice_min_y = 0
	bad.elemental_vault_cap = -1
	_expect(not bad.validate().is_empty(), "empty/invalid policy is rejected", failures)

	_expect(DungeonLayoutGenerator.policy() != null, "generator exposes the shared generation policy", failures)
	_expect(DungeonLayoutGenerator.policy().generated_candidate_count >= 1, "generator policy supplies a usable candidate count", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: dungeon generation policy failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("DUNGEON_GENERATION_POLICY_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
