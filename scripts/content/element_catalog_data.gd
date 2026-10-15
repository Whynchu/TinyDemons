@tool
extends Resource
class_name ElementCatalogData

## Editor-inspectable element and player-aspect lookup tables. Stable combat
## and save-facing enum ordinals stay in code; their IDs, names, palette keys,
## starter order, and fusion recipes are authored here.

@export var ids: Dictionary = {}
@export var display_names: Dictionary = {}
@export var palette_keys: Dictionary = {}
## Player aspect ramps are a separate visual domain from combat palette keys.
## Ice intentionally uses `ice` here and `aquamarine` in palette_keys.
@export var aspect_palette_keys: Dictionary = {}
@export var starter_flames: Array[StringName] = []
@export var fusion_recipes: Dictionary = {}
@export var matchup_table: Array = []
@export var status_effects: Array[Resource] = []
@export var status_mixtures: Array[Resource] = []
@export var damage_number_color_boost := 1.10
@export var default_element := -1
@export var element_count := 0


func validate() -> Array[String]:
	var problems: Array[String] = []
	if element_count <= 0:
		problems.append("element_count must be positive")
	if default_element < 0 or default_element >= element_count:
		problems.append("default_element must reference a registered element")
	_validate_indexed_mapping(ids, "ids", problems)
	_validate_indexed_mapping(display_names, "display_names", problems)
	_validate_indexed_mapping(palette_keys, "palette_keys", problems)
	_validate_aspect_palette_keys(problems)
	var seen_element_ids: Dictionary = {}
	var seen_palette_keys: Dictionary = {}
	for index in range(maxi(element_count, 0)):
		if not ids.has(index) or not display_names.has(index) or not palette_keys.has(index):
			continue
		var raw_element_id: Variant = ids[index]
		if not raw_element_id is StringName:
			problems.append("element id %d must be a StringName" % index)
		var element_id := str(raw_element_id).strip_edges()
		if element_id.is_empty():
			problems.append("element id %d must not be empty" % index)
		elif seen_element_ids.has(element_id):
			problems.append("duplicate element id '%s'" % element_id)
		seen_element_ids[element_id] = true
		var display_name: Variant = display_names[index]
		if not display_name is String:
			problems.append("element display name %d must be a String" % index)
		if str(display_name).strip_edges().is_empty():
			problems.append("element display name %d must not be empty" % index)
		var raw_palette_key: Variant = palette_keys[index]
		if not raw_palette_key is String:
			problems.append("element palette key %d must be a String" % index)
		var palette_key := str(raw_palette_key).strip_edges().to_lower()
		if palette_key.is_empty():
			problems.append("element palette key %d must not be empty" % index)
		elif seen_palette_keys.has(palette_key):
			problems.append("duplicate element palette key '%s'" % palette_key)
		seen_palette_keys[palette_key] = true
	_validate_starter_flames(problems)
	_validate_fusion_recipes(problems)
	if matchup_table.size() != element_count:
		problems.append("matchup_table row count must equal element_count")
	for attacker in mini(matchup_table.size(), maxi(element_count, 0)):
		var row: Variant = matchup_table[attacker]
		if not row is Array:
			problems.append("matchup row %d must be an array" % attacker)
			continue
		if row.size() != element_count:
			problems.append("matchup row %d column count must equal element_count" % attacker)
		for defender in mini(row.size(), maxi(element_count, 0)):
			var multiplier: Variant = row[defender]
			if not multiplier is int and not multiplier is float:
				problems.append("matchup %d -> %d must be numeric" % [attacker, defender])
			elif not is_finite(float(multiplier)) or float(multiplier) < 0.0:
				problems.append("matchup %d -> %d must be finite and non-negative" % [attacker, defender])
	var seen_ids: Dictionary = {}
	var seen_elements: Dictionary = {}
	for index in status_effects.size():
		var definition := status_effects[index] as StatusEffectDefinition
		if definition == null:
			problems.append("status effect %d is null or has an unsupported resource type" % index)
			continue
		for problem in definition.validate():
			problems.append("status '%s': %s" % [String(definition.id), problem])
		if seen_ids.has(definition.id):
			problems.append("duplicate status id '%s'" % String(definition.id))
		seen_ids[definition.id] = true
		if not StatusEffectDefinition.AUXILIARY_STATUS_IDS.has(definition.id) and seen_elements.has(definition.element):
			problems.append("multiple passive status effects use element %d" % definition.element)
		if not StatusEffectDefinition.AUXILIARY_STATUS_IDS.has(definition.id):
			seen_elements[definition.element] = true
	for required_id in StatusEffectDefinition.STATUS_IDS:
		if not seen_ids.has(required_id):
			problems.append("missing status definition '%s'" % String(required_id))
	for registered_id: StringName in seen_ids.keys():
		if not StatusEffectDefinition.STATUS_IDS.has(registered_id) and not StatusEffectDefinition.AUXILIARY_STATUS_IDS.has(registered_id):
			problems.append("status registry contains unexpected id '%s'" % String(registered_id))
	var seen_pairs: Dictionary = {}
	for index in status_mixtures.size():
		var mixture := status_mixtures[index] as StatusMixtureDefinition
		if mixture == null:
			problems.append("status mixture %d is null or has an unsupported resource type" % index)
			continue
		for problem in mixture.validate(StatusEffectDefinition.AUXILIARY_STATUS_IDS + StatusEffectDefinition.STATUS_IDS, element_count):
			problems.append("status mixture %d: %s" % [index, problem])
		if not StatusEffectDefinition.AUXILIARY_STATUS_IDS.has(mixture.result_status_id):
			problems.append("status mixture %d result must be an auxiliary status" % index)
		for ingredient_element in [mixture.first_element, mixture.second_element]:
			var has_ingredient_status := false
			for status_resource in status_effects:
				var status_definition := status_resource as StatusEffectDefinition
				if status_definition != null and status_definition.element == ingredient_element and not StatusEffectDefinition.AUXILIARY_STATUS_IDS.has(status_definition.id):
					has_ingredient_status = true
					break
			if not has_ingredient_status:
				problems.append("status mixture %d ingredient element %d has no element status" % [index, ingredient_element])
		var first := mini(mixture.first_element, mixture.second_element)
		var second := maxi(mixture.first_element, mixture.second_element)
		var pair_key := "%d:%d" % [first, second]
		if seen_pairs.has(pair_key):
			problems.append("duplicate status mixture pair '%s'" % pair_key)
		seen_pairs[pair_key] = true
	return problems


func _validate_aspect_palette_keys(problems: Array[String]) -> void:
	if aspect_palette_keys.size() != maxi(element_count - 1, 0):
		problems.append("aspect_palette_keys entry count must equal the elemental count")
	var seen: Dictionary = {}
	for index in range(1, maxi(element_count, 1)):
		if not aspect_palette_keys.has(index):
			problems.append("aspect_palette_keys is missing element index %d" % index)
	for raw_index: Variant in aspect_palette_keys:
		if not raw_index is int or int(raw_index) <= 0 or int(raw_index) >= element_count:
			problems.append("aspect_palette_keys contains invalid element index '%s'" % str(raw_index))
			continue
		var value: Variant = aspect_palette_keys[raw_index]
		if not value is String:
			problems.append("aspect palette key %d must be a String" % int(raw_index))
		var palette_key := str(value).strip_edges().to_lower()
		if palette_key.is_empty():
			problems.append("aspect palette key %d must not be empty" % int(raw_index))
		elif seen.has(palette_key):
			problems.append("duplicate aspect palette key '%s'" % palette_key)
		seen[palette_key] = true
		for raw_combat_index: Variant in palette_keys:
			if not raw_combat_index is int:
				continue
			var combat_palette_key := str(palette_keys[raw_combat_index]).strip_edges().to_lower()
			if combat_palette_key == palette_key and int(raw_combat_index) != int(raw_index):
				problems.append("aspect palette key '%s' conflicts with combat element %d" % [palette_key, int(raw_combat_index)])


func _validate_starter_flames(problems: Array[String]) -> void:
	if starter_flames.is_empty():
		problems.append("starter_flames must not be empty")
	var seen: Dictionary = {}
	for flame in starter_flames:
		var element_index := _element_index_for_id(flame)
		if element_index <= 0:
			problems.append("starter flame '%s' must reference an elemental id" % String(flame))
		if seen.has(flame):
			problems.append("duplicate starter flame '%s'" % String(flame))
		seen[flame] = true


func _validate_fusion_recipes(problems: Array[String]) -> void:
	var seen_pairs: Dictionary = {}
	for raw_pair: Variant in fusion_recipes:
		if not raw_pair is String:
			problems.append("fusion recipe key must be a String")
			continue
		var ingredients := String(raw_pair).split("|", false)
		if ingredients.size() != 2:
			problems.append("fusion recipe '%s' must contain exactly two flame ids" % String(raw_pair))
			continue
		var first := StringName(ingredients[0])
		var second := StringName(ingredients[1])
		if first == second:
			problems.append("fusion recipe '%s' must use two different flames" % String(raw_pair))
		if String(first) >= String(second):
			problems.append("fusion recipe '%s' must use canonical sorted flame ids" % String(raw_pair))
		if _element_index_for_id(first) <= 0 or _element_index_for_id(second) <= 0:
			problems.append("fusion recipe '%s' must reference elemental ids" % String(raw_pair))
		var pair_key := "%s|%s" % [String(first), String(second)] if String(first) < String(second) else "%s|%s" % [String(second), String(first)]
		if seen_pairs.has(pair_key):
			problems.append("duplicate fusion recipe pair '%s'" % pair_key)
		seen_pairs[pair_key] = true
		var result: Variant = fusion_recipes[raw_pair]
		if not result is StringName:
			problems.append("fusion recipe '%s' result must be a StringName" % String(raw_pair))
		if _element_index_for_id(result as StringName if result is StringName else &"") <= 0:
			problems.append("fusion recipe '%s' result must reference an elemental id" % String(raw_pair))


func _element_index_for_id(element_id: StringName) -> int:
	for raw_index: Variant in ids:
		if raw_index is int and int(raw_index) > 0 and ids[raw_index] == element_id:
			return int(raw_index)
	return -1


func _validate_indexed_mapping(mapping: Dictionary, label: String, problems: Array[String]) -> void:
	if mapping.size() != element_count:
		problems.append("%s entry count must equal element_count" % label)
	for index in range(maxi(element_count, 0)):
		if not mapping.has(index):
			problems.append("%s is missing element index %d" % [label, index])
	for raw_index: Variant in mapping:
		if not raw_index is int or int(raw_index) < 0 or int(raw_index) >= element_count:
			problems.append("%s contains invalid element index '%s'" % [label, str(raw_index)])
