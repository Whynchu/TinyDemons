extends SceneTree

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	_expect(PlayerProfile.supports_schema_version(8), "save service accepts the oldest supported migration schema", failures)
	_expect(PlayerProfile.supports_schema_version(9), "save service accepts the six-stat migration schema", failures)
	_expect(PlayerProfile.supports_schema_version(10), "save service accepts the demon-cloak migration schema", failures)
	_expect(PlayerProfile.supports_schema_version(PlayerProfile.CURRENT_SCHEMA_VERSION), "save service accepts the current schema", failures)
	_expect(not PlayerProfile.supports_schema_version(PlayerProfile.CURRENT_SCHEMA_VERSION + 1), "save service rejects an unknown future schema", failures)
	var legacy_data := {
		"schema_version": 8,
		"has_started": true,
		"pending_route": "hub",
		"starter_flame": "fire",
		"palette_name": "red",
		"level": 12,
		"xp": 7,
		"unspent_stat_points": 9,
		"base_vit": 5,
		"base_str": 4,
		"base_def": 3,
		"base_spd": 6,
		"allocated_vit": 2,
		"allocated_str": 4,
		"allocated_def": 1,
		"allocated_spd": 3,
		"gold": 250,
		"souls": 14,
	}
	var profile := PlayerProfile.new()
	profile.load_dictionary(legacy_data)
	_expect(profile.schema_version == PlayerProfile.CURRENT_SCHEMA_VERSION, "schema 8 loads as schema 13", failures)
	_expect(profile.base_vit == 2 and profile.base_str == 2 and profile.base_def == 2 and profile.base_agi == 2 and profile.base_int == 2 and profile.base_mnd == 2, "pre-baseline saves migrate to the even 2/2/2/2/2/2 base", failures)
	_expect(profile.allocated_vit == 2 and profile.allocated_str == 4 and profile.allocated_def == 1 and profile.allocated_agi == 3, "schema 8 allocations retain every invested point", failures)
	_expect(profile.allocated_int == 0 and profile.allocated_mnd == 0, "schema 8 INT/MND carry no invested points", failures)
	_expect(profile.unspent_stat_points == 9 and profile.level == 12 and profile.xp == 7, "schema 8 banked points and progression are preserved", failures)

	var saved := profile.to_dictionary()
	_expect(saved.get("schema_version") == PlayerProfile.CURRENT_SCHEMA_VERSION and saved.has("base_agi") and saved.has("base_int") and saved.has("base_mnd"), "normal save emits canonical six-stat fields", failures)
	var round_trip := PlayerProfile.new()
	round_trip.load_dictionary(saved)
	_expect(round_trip.base_agi == 2 and round_trip.allocated_agi == 3 and round_trip.base_int == 2 and round_trip.base_mnd == 2, "schema 13 round trip preserves canonical stats on the even baseline", failures)
	_expect(round_trip.unspent_stat_points == 9, "schema 9 round trip preserves banked points", failures)

	var allocation_profile := PlayerProfile.new()
	allocation_profile.unspent_stat_points = 6
	for stat_name: StringName in [&"VIT", &"STR", &"DEF", &"AGI", &"INT", &"MND"]:
		_expect(allocation_profile.allocate_stat(stat_name), "six-stat allocation accepts %s" % stat_name, failures)
	_expect(allocation_profile.unspent_stat_points == 0 and allocation_profile.allocated_vit == 1 and allocation_profile.allocated_str == 1 and allocation_profile.allocated_def == 1 and allocation_profile.allocated_agi == 1 and allocation_profile.allocated_int == 1 and allocation_profile.allocated_mnd == 1, "allocation spends exactly one point in each canonical stat", failures)
	_expect(not allocation_profile.allocate_stat(&"BAD") and not allocation_profile.allocate_stat(&"INT", -1), "invalid and negative allocations do not consume points", failures)
	allocation_profile.gold = 0
	var refunded := allocation_profile.reset_allocated_stats()
	_expect(refunded == 6 and allocation_profile.unspent_stat_points == 6 and allocation_profile.allocated_int == 0 and allocation_profile.allocated_mnd == 0, "respec refunds all six stat destinations", failures)

	var stats := StatsComponent.new()
	stats.configure_manual_growth(3, 2, 2, 1, 1, 2, 3, 4, 5, 6, 7, 8)
	var stat_values := stats.get_stats()
	_expect(stats.vit == 4 and stats.strength == 4 and stats.def == 5 and stats.agi == 5 and stats.intelligence == 12 and stats.mnd == 14, "runtime stats recalculate all six manual channels", failures)
	_expect(stat_values.get("AGI") == 5 and stat_values.get("INT") == 12 and stat_values.get("MND") == 14 and stat_values.get("SPD") == 5, "runtime stat reads expose canonical names with a temporary SPD alias", failures)

	# PlayerProfile is RefCounted; let local references release naturally.
	stats.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: six-stat profile migration smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SIX_STAT_PROFILE_MIGRATION_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
