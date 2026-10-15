extends RefCounted
class_name AspectCatalog

const ELEMENT_CATALOG_SCRIPT = preload("res://scripts/content/element_catalog.gd")
const ELEMENT_DATA = preload("res://resources/definitions/element_catalog.tres")

## The player-facing API projects aspect policy from the authored element data.
## Fusion keys are canonicalized here so contact order never matters.


static func starter_flames() -> Array[StringName]:
	var result: Array[StringName] = []
	for flame: StringName in ELEMENT_DATA.starter_flames:
		result.append(flame)
	return result


static func elemental_flames() -> Array[StringName]:
	var result: Array[StringName] = []
	# The player aspect enum is a save-facing ordinal range. Combat-only catalog
	# additions are not exposed as player flames until that save contract moves.
	var last_supported_element := mini(ELEMENT_CATALOG_SCRIPT.Element.ICE, ELEMENT_CATALOG_SCRIPT.element_count() - 1)
	for element in range(1, last_supported_element + 1):
		result.append(ELEMENT_CATALOG_SCRIPT.id(element))
	return result


static func is_starter_flame(flame: StringName) -> bool:
	return flame in ELEMENT_DATA.starter_flames


static func is_elemental_flame(flame: StringName) -> bool:
	var element := ELEMENT_CATALOG_SCRIPT.element_for_id(flame)
	return element > ELEMENT_CATALOG_SCRIPT.Element.NEUTRAL and element <= ELEMENT_CATALOG_SCRIPT.Element.ICE


static func palette_for_flame(flame: StringName) -> String:
	if not is_elemental_flame(flame):
		return "grey"
	var element := ELEMENT_CATALOG_SCRIPT.element_for_id(flame)
	return str(ELEMENT_DATA.aspect_palette_keys.get(element, "grey"))


static func display_name(flame: StringName) -> String:
	if not is_elemental_flame(flame):
		return "NORMAL"
	return ELEMENT_CATALOG_SCRIPT.display_name(ELEMENT_CATALOG_SCRIPT.element_for_id(flame))


static func flame_for_palette(palette: String) -> StringName:
	var normalized_palette := palette.to_lower()
	if normalized_palette == "gray":
		normalized_palette = "grey"
	for flame: StringName in elemental_flames():
		if palette_for_flame(flame) == normalized_palette:
			return flame
	# Keep profiles and palette selections created before the brighter Ice swatch
	# was introduced compatible with the Ice flame identity.
	if normalized_palette == "aquamarine":
		return &"ice"
	return &""


static func fusion_result(first_flame: StringName, second_flame: StringName) -> StringName:
	if not is_elemental_flame(first_flame) or not is_elemental_flame(second_flame) or first_flame == second_flame:
		return &""
	var pair: Array[String] = [String(first_flame), String(second_flame)]
	pair.sort()
	return ELEMENT_DATA.fusion_recipes.get("%s|%s" % [pair[0], pair[1]], &"") as StringName


static func fusion_recipes() -> Dictionary:
	return ELEMENT_DATA.fusion_recipes.duplicate()


static func flames_available_for_run(completed_runs: int, starter_flame: StringName) -> Array[StringName]:
	var starters := starter_flames()
	var selected_starter := starter_flame if is_starter_flame(starter_flame) else starters[0]
	var available: Array[StringName] = [selected_starter]
	var target_count := clampi(completed_runs + 1, 1, starters.size())
	for flame: StringName in starters:
		if flame == selected_starter:
			continue
		if available.size() >= target_count:
			break
		available.append(flame)
	return available


static func alternate_flames_for_run(completed_runs: int, starter_flame: StringName) -> Array[StringName]:
	var available := flames_available_for_run(completed_runs, starter_flame)
	if available.size() <= 1:
		return []
	var alternates: Array[StringName] = []
	for index in range(1, available.size()):
		alternates.append(available[index])
	return alternates
