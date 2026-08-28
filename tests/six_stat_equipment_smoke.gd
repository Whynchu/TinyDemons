extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var catalog := ItemCatalog.new()
	var profile := PlayerProfile.new()
	profile.ensure_starter_items(catalog)
	var talisman := ItemInstance.new()
	talisman.instance_id = "test-chroma-talisman"
	talisman.definition_id = &"chroma_talisman"
	talisman.rarity = &"rare"
	var robe := ItemInstance.new()
	robe.instance_id = "test-mindweave-robe"
	robe.definition_id = &"mindweave_robe"
	robe.rarity = &"common"
	_expect(profile.grant_item(talisman) and profile.grant_item(robe), "INT/MND test equipment enters the inventory", failures)
	_expect(profile.equip_item(talisman.instance_id, catalog) and profile.equip_item(robe.instance_id, catalog), "INT/MND test equipment equips through normal slot ownership", failures)

	var equipment := EquipmentComponent.new()
	equipment.configure_from_profile(profile, catalog)
	_expect(is_equal_approx(equipment.intelligence_bonus, 5.0) and is_equal_approx(equipment.mnd_bonus, 3.0), "equipment exposes authored INT/MND flat bonuses", failures)
	_expect(is_equal_approx(equipment.intelligence_rate_bonus, 0.05) and is_equal_approx(equipment.mnd_rate_bonus, 0.05), "rarity rates apply independently to positive supplied stats", failures)
	var stats := StatsComponent.new()
	stats.configure_manual_growth(3, 2, 2, 1, 0, 0, 0, 0, 1, 1, 0, 0)
	var snapshot := CombatStatSnapshot.from_components(stats, equipment)
	_expect(is_equal_approx(snapshot.intelligence, 6.3) and is_equal_approx(snapshot.mnd, 4.2), "snapshot applies flat INT/MND gear before additive rates", failures)
	_expect(is_equal_approx(snapshot.gear_intelligence, 5.0) and is_equal_approx(snapshot.gear_mnd, 3.0), "snapshot retains canonical INT/MND gear contributions", failures)
	_expect(is_equal_approx(snapshot.agi, 0.0) and is_equal_approx(snapshot.vit, 4.0), "existing six-stat snapshot channels remain independent", failures)

	var talisman_bonuses := catalog.bonuses(talisman)
	var robe_bonuses := catalog.bonuses(robe)
	_expect(is_equal_approx(float(talisman_bonuses.get("intelligence", 0.0)), 4.0) and is_equal_approx(float(talisman_bonuses.get("mnd", 0.0)), 1.0), "talisman preview reports its INT/MND package", failures)
	_expect(is_equal_approx(float(robe_bonuses.get("mnd", 0.0)), 2.0) and is_equal_approx(float(robe_bonuses.get("intelligence", 0.0)), 1.0), "robe preview reports its MND/INT package", failures)
	_expect(catalog.player_stat_rate_text(talisman).contains("INT +5%"), "INT rarity rate is visible in item presentation", failures)

	var draft := HubProgressionDraft.new()
	draft.intelligence = 2
	draft.mnd = 3
	var draft_values := draft.as_dictionary()
	_expect(draft_values.get("INT") == 2 and draft_values.get("MND") == 3 and draft_values.get("SPD") == draft_values.get("AGI"), "hub draft carries canonical magical stats with compatibility output", failures)
	draft.clear()
	_expect(draft.intelligence == 0 and draft.mnd == 0, "hub draft clears INT/MND transaction state", failures)

	equipment.free()
	stats.free()
	# Catalog, profile, draft, and item instances are RefCounted.
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: six-stat equipment smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SIX_STAT_EQUIPMENT_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
