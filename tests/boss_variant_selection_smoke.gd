extends SceneTree

const CatalogScript = preload("res://scripts/content/slime_variant_catalog.gd")
const ElementCatalogScript = preload("res://scripts/content/element_catalog.gd")
const RoomControllerScript = preload("res://scripts/runtime/controllers/room_controller.gd")

func _initialize() -> void:
	var failures: Array[String] = []
	var rooms := RoomControllerScript.new()
	rooms.progression_run_rank = 2
	for variant in CatalogScript.variants():
		var element := CatalogScript.element_for_variant(variant)
		rooms.set_run_element_theme([element] if element > ElementCatalogScript.Element.NEUTRAL else [])
		rooms.progression_run_number = 10
		rooms.boss_variant_selection = variant
		var encounter := rooms._generate_boss_encounter(1000, 12)
		var variants := encounter["variants"] as Array
		_expect(StringName(variants[0]) == variant, "%s is the explicit lead boss variant" % variant, failures)
		_expect(CatalogScript.display_name_for_variant(variant) != "", "%s has an identity name" % variant, failures)
		_expect(ElementCatalogScript.is_valid(CatalogScript.element_for_variant(variant)), "%s keeps a valid catalog element" % variant, failures)
		for index in range(1, variants.size()):
			_expect(StringName(variants[index]) == variant, "%s support wave inherits lead variant" % variant, failures)
	rooms.boss_variant_selection = &""
	rooms.progression_run_rank = 2
	rooms.progression_run_number = 10
	var seen: Dictionary = {}
	for element in range(ElementCatalogScript.Element.FIRE, ElementCatalogScript.element_count()):
		rooms.set_run_element_theme([element])
		for seed in 64:
			seen[StringName((rooms._generate_boss_encounter(seed + element * 512, 12)["variants"] as Array)[0])] = true
	_expect(seen.size() == CatalogScript.variants().size(), "seeded selection reaches every catalog variant", failures)
	rooms.progression_run_rank = 1
	rooms.progression_run_number = 1
	rooms.set_run_element_theme([])
	var run_one_encounter := rooms._generate_boss_encounter(1000, 12)
	for run_one_variant in run_one_encounter["variants"] as Array:
		_expect(String(run_one_variant) != "purple", "Run 1 boss rooms exclude Shadow slimes", failures)
	if failures.is_empty():
		print("BOSS_VARIANT_SELECTION_SMOKE_OK")
		call_deferred("_finish", 0)
		return
	for failure in failures:
		push_error(failure)
	call_deferred("_finish", 1)

func _finish(exit_code: int) -> void:
	quit(exit_code)

func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
