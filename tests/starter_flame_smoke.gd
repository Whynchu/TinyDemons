extends SceneTree

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")
const Profile = preload("res://scripts/player_profile.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	_expect(AspectCatalogScript.STARTER_FLAMES == [&"fire", &"water", &"electric"], "starter flame order is canonical", failures)
	_expect(AspectCatalogScript.palette_for_flame(&"fire") == "red", "Fire maps to red", failures)
	_expect(AspectCatalogScript.palette_for_flame(&"water") == "blue", "Water maps to blue", failures)
	_expect(AspectCatalogScript.palette_for_flame(&"electric") == "yellow", "Electric maps to yellow", failures)

	var profile := Profile.new()
	profile.has_started = true
	profile.starter_flame = &"electric"
	profile.palette_name = "yellow"
	var restored := Profile.new()
	restored.load_dictionary(profile.to_dictionary())
	_expect(restored.has_started, "starter flame profile round-trips as started", failures)
	_expect(restored.starter_flame == &"electric", "starter flame persists", failures)
	_expect(restored.palette_name == "yellow", "starter palette persists with flame", failures)

	var old_data: Dictionary = profile.to_dictionary()
	old_data["schema_version"] = 6
	var expired := Profile.new()
	expired.load_dictionary(old_data)
	_expect(not expired.has_started, "pre-Chroma profile is intentionally reset", failures)
	_expect(expired.starter_flame == &"fire", "reset profile uses the default starter flame", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: starter flame smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("STARTER_FLAME_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
