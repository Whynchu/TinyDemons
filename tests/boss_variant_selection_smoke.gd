extends SceneTree

const CatalogScript = preload("res://scripts/slime_variant_catalog.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const RoomControllerScript = preload("res://scripts/room_controller.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var rooms := RoomControllerScript.new()
	rooms.progression_run_rank = 2
	var expected_elements := {
		&"grey": ElementCatalogScript.Element.NEUTRAL, &"red": ElementCatalogScript.Element.FIRE,
		&"blue": ElementCatalogScript.Element.WATER, &"yellow": ElementCatalogScript.Element.ELECTRIC,
		&"green": ElementCatalogScript.Element.GRASS, &"purple": ElementCatalogScript.Element.SHADOW,
		&"orange": ElementCatalogScript.Element.GROUND, &"aquamarine": ElementCatalogScript.Element.ICE,
	}
	for variant in CatalogScript.VARIANTS:
		rooms.boss_variant_selection = variant
		var encounter := rooms._generate_boss_encounter(1000, 12)
		var variants := encounter["variants"] as Array
		_expect(StringName(variants[0]) == variant, "%s is the explicit lead boss variant" % variant, failures)
		_expect(CatalogScript.display_name_for_variant(variant) != "", "%s has an identity name" % variant, failures)
		_expect(CatalogScript.element_for_variant(variant) == expected_elements[variant], "%s keeps its catalog element" % variant, failures)
		for index in range(1, variants.size()):
			_expect(StringName(variants[index]) == variant, "%s support wave inherits lead variant" % variant, failures)
	rooms.boss_variant_selection = &""
	rooms.progression_run_rank = 2
	var seen: Dictionary = {}
	for seed in 512:
		seen[StringName((rooms._generate_boss_encounter(seed, 12)["variants"] as Array)[0])] = true
	_expect(seen.size() == CatalogScript.VARIANTS.size(), "seeded selection reaches every catalog variant", failures)
	rooms.progression_run_rank = 1
	var run_one_encounter := rooms._generate_boss_encounter(1000, 12)
	for run_one_variant in run_one_encounter["variants"] as Array:
		_expect(String(run_one_variant) != "purple", "Run 1 boss rooms exclude Shadow slimes", failures)
	rooms.free()
	if failures.is_empty():
		print("BOSS_VARIANT_SELECTION_SMOKE_OK")
		quit(0)
	for failure in failures:
		push_error(failure)
	quit(1)

func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
