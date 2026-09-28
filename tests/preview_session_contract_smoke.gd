extends SceneTree

## Pure contract checks for the versioned, isolated enemy preview payload.

const PreviewSessionScript := preload("res://scripts/preview_session.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var failures: Array[String] = []
	var session := PreviewSessionScript.create_enemy(&"guard_slime", 8675309) as RefCounted
	_expect((session.call("validation_errors") as Array).is_empty(), "factory-created session is valid", failures)
	_expect(int(session.get("seed")) == 8675309, "explicit seed is preserved", failures)
	var session_loadout: Dictionary = session.get("loadout") as Dictionary
	_expect(session_loadout.get("preset") == "starter", "starter loadout is explicit", failures)

	var decoded := PreviewSessionScript.from_record(session.to_record()) as Dictionary
	var round_trip := decoded.get("session") as RefCounted
	_expect(round_trip != null, "versioned record round-trips", failures)
	if round_trip != null:
		_expect(round_trip.get("content_id") == session.get("content_id"), "stable enemy ID is preserved", failures)
		_expect(round_trip.get("requested_mode") == session.get("requested_mode"), "preview route is preserved", failures)
		_expect(round_trip.get("seed") == session.get("seed"), "round-trip seed is preserved", failures)
		_expect(round_trip.get("loadout") == session.get("loadout"), "loadout is preserved", failures)
	var payload_path := "user://preview_session_contract_smoke.json"
	var payload_file := FileAccess.open(payload_path, FileAccess.WRITE)
	_expect(payload_file != null, "temporary payload fixture opens", failures)
	if payload_file != null:
		payload_file.store_string(JSON.stringify(session.call("to_record")))
		payload_file.close()
		var parsed_args := PreviewSessionScript.from_user_args(PackedStringArray([
			"--unrelated-argument",
			PreviewSessionScript.COMMAND_PREFIX + ProjectSettings.globalize_path(payload_path),
		])) as Dictionary
		var parsed_session := parsed_args.get("session") as RefCounted
		_expect(bool(parsed_args.get("present", false)), "session argument is detected", failures)
		_expect(parsed_session != null and parsed_args.get("payload_path") == ProjectSettings.globalize_path(payload_path), "argument payload loads from disk", failures)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(payload_path))

	var session_record: Dictionary = session.call("to_record") as Dictionary
	var bad_schema := session_record.duplicate(true)
	bad_schema["schema_version"] = 99
	_expect((PreviewSessionScript.from_record(bad_schema) as Dictionary).get("session") == null, "unknown schema version is rejected", failures)
	var fractional_seed := session_record.duplicate(true)
	fractional_seed["seed"] = 4.5
	_expect((PreviewSessionScript.from_record(fractional_seed) as Dictionary).get("session") == null, "fractional seed is rejected", failures)
	var oversized_seed := session_record.duplicate(true)
	oversized_seed["seed"] = 2147483648
	_expect((PreviewSessionScript.from_record(oversized_seed) as Dictionary).get("session") == null, "out-of-range seed is rejected", failures)
	var unstable_id := session_record.duplicate(true)
	unstable_id["content_id"] = "Guard Slime"
	_expect((PreviewSessionScript.from_record(unstable_id) as Dictionary).get("session") == null, "unstable content ID is rejected", failures)

	var missing_path := PreviewSessionScript.from_user_args(PackedStringArray([PreviewSessionScript.COMMAND_PREFIX])) as Dictionary
	_expect(bool(missing_path.get("present", false)), "empty command-line payload is recognized", failures)
	_expect(not (missing_path.get("errors", []) as Array).is_empty(), "empty payload is rejected", failures)
	var duplicate_args := PackedStringArray([
		PreviewSessionScript.COMMAND_PREFIX + "one.json",
		PreviewSessionScript.COMMAND_PREFIX + "two.json",
	])
	var duplicate_result := PreviewSessionScript.from_user_args(duplicate_args) as Dictionary
	_expect(not (duplicate_result.get("errors", []) as Array).is_empty(), "duplicate payload arguments are rejected", failures)
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("PREVIEW_SESSION_CONTRACT_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
