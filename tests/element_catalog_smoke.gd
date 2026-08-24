extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var e := ElementCatalogScript.Element
	var expected := [
		[1.0, 1.0, 1.0, 1.0, 1.0, 0.0],
		[1.0, 0.8, 0.8, 1.0, 1.25, 1.0],
		[1.0, 1.25, 0.8, 1.0, 0.8, 1.0],
		[1.0, 1.0, 1.25, 0.8, 0.8, 1.0],
		[1.0, 0.8, 1.25, 1.0, 0.8, 1.0],
		[0.0, 1.0, 1.0, 1.0, 1.0, 1.25],
	]
	for attacker in ElementCatalogScript.ELEMENT_COUNT:
		for defender in ElementCatalogScript.ELEMENT_COUNT:
			_expect(is_equal_approx(ElementCatalogScript.effectiveness(attacker, defender), expected[attacker][defender]), "matchup %d -> %d" % [attacker, defender], failures)
	_expect(ElementCatalogScript.effectiveness(e.NEUTRAL, e.SHADOW) == 0.0, "Neutral is immune into Shadow", failures)
	_expect(ElementCatalogScript.effectiveness(e.SHADOW, e.NEUTRAL) == 0.0, "Shadow is immune into Neutral", failures)
	_expect(is_equal_approx(ElementCatalogScript.effectiveness(e.SHADOW, e.SHADOW), 1.25), "Shadow is weak to Shadow", failures)
	_expect(ElementCatalogScript.element_for_aspect(0) == e.NEUTRAL, "Gray aspect maps to Neutral", failures)
	_expect(ElementCatalogScript.element_for_aspect(1) == e.FIRE, "Fire aspect maps to Fire", failures)
	_expect(ElementCatalogScript.element_for_aspect(2) == e.WATER, "Water aspect maps to Water", failures)
	_expect(ElementCatalogScript.element_for_aspect(3) == e.ELECTRIC, "Electric aspect maps to Electric", failures)
	_expect(ElementCatalogScript.element_for_palette("grey") == e.NEUTRAL, "grey palette maps to Neutral", failures)
	_expect(ElementCatalogScript.element_for_palette("gray") == e.NEUTRAL, "gray palette maps to Neutral", failures)
	_expect(ElementCatalogScript.element_for_palette("red") == e.FIRE, "red palette maps to Fire", failures)
	_expect(ElementCatalogScript.element_for_palette("blue") == e.WATER, "blue palette maps to Water", failures)
	_expect(ElementCatalogScript.element_for_palette("yellow") == e.ELECTRIC, "yellow palette maps to Electric", failures)
	_expect(ElementCatalogScript.element_for_palette("green") == e.GRASS, "green palette maps to Grass", failures)
	_expect(ElementCatalogScript.element_for_palette("purple") == e.SHADOW, "purple palette maps to Shadow", failures)
	_expect(ElementCatalogScript.palette_key(e.NEUTRAL) == "grey", "Neutral uses grey palette", failures)
	_expect(ElementCatalogScript.palette_key(e.SHADOW) == "purple", "Shadow uses purple palette", failures)
	_expect(ElementCatalogScript.damage_number_color(e.FIRE).is_equal_approx(PaletteLibrary.accent("red")), "Fire uses the red accent color", failures)
	_expect(ElementCatalogScript.damage_number_color(e.GRASS).is_equal_approx(PaletteLibrary.accent("green")), "Grass falls back to its readable palette color", failures)
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: element catalog smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ELEMENT_CATALOG_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
