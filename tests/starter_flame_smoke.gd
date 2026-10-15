extends SceneTree

const AspectCatalogScript = preload("res://scripts/content/aspect_catalog.gd")
const Profile = preload("res://scripts/runtime/state/player_profile.gd")
const ChromaScript = preload("res://scripts/components/player_chroma_component.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	_expect(AspectCatalogScript.starter_flames() == [&"fire", &"water", &"electric"], "starter flame order is canonical", failures)
	_expect(AspectCatalogScript.palette_for_flame(&"fire") == "red", "Fire maps to red", failures)
	_expect(AspectCatalogScript.palette_for_flame(&"water") == "blue", "Water maps to blue", failures)
	_expect(AspectCatalogScript.palette_for_flame(&"electric") == "yellow", "Electric maps to yellow", failures)
	_expect(AspectCatalogScript.palette_for_flame(&"ice") == "ice", "player Ice uses the bright Ice palette", failures)
	_expect(AspectCatalogScript.flame_for_palette("ice") == &"ice", "bright Ice palette resolves to the Ice flame", failures)
	_expect(AspectCatalogScript.flame_for_palette("aquamarine") == &"ice", "legacy aquamarine palette still resolves to Ice", failures)
	_expect(AspectCatalogScript.flame_for_palette("gray").is_empty(), "gray alias does not invent a flame", failures)
	_expect(AspectCatalogScript.fusion_result(&"water", &"fire") == &"shadow", "authored fusion recipes are order independent", failures)
	_expect(AspectCatalogScript.fusion_result(&"fire", &"electric") == &"ground", "authored Electric/Fire recipe resolves to Ground", failures)
	_expect(AspectCatalogScript.fusion_result(&"water", &"electric") == &"grass", "authored Water/Electric recipe resolves to Grass", failures)
	_expect(AspectCatalogScript.fusion_result(&"water", &"grass") == &"ice", "authored Water/Grass recipe resolves to Ice", failures)
	var chroma := ChromaScript.new()
	root.add_child(chroma)
	for flame: StringName in AspectCatalogScript.elemental_flames():
		var aspect := chroma.aspect_for_flame(flame)
		chroma.change_flame(flame)
		_expect(aspect != ChromaScript.Aspect.NONE, "%s resolves to a save-compatible aspect" % String(flame), failures)
		_expect(chroma.aspect_name() == flame, "%s aspect name comes from the element catalog" % String(flame), failures)
		_expect(AspectCatalogScript.display_name(flame) == String(flame).to_upper(), "%s display label comes from the element catalog" % String(flame), failures)
		_expect(chroma.chroma_palette_name() == AspectCatalogScript.palette_for_flame(flame), "%s pickup color uses the player aspect palette" % String(flame), failures)
		chroma.set_bound_aspect(aspect)
		_expect(chroma.bound_aspect_name() == flame, "%s bound name comes from the element catalog" % String(flame), failures)
		chroma.clear_bound_aspect()
	chroma.free()
	_expect(load("res://assets/artwork/DoorRightFlameshut.png") != null, "hub starter gate art is imported", failures)

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
