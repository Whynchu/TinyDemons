@tool
extends Resource
class_name ElementCatalogData

## Editor-inspectable element lookup tables. The stable Element enum and
## matchup policy stay in element_catalog.gd; the id/name/palette lookups are
## authored here so the editor can inspect and tune presentation keys.

@export var ids: Dictionary = {}
@export var display_names: Dictionary = {}
@export var palette_keys: Dictionary = {}
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


func _validate_indexed_mapping(mapping: Dictionary, label: String, problems: Array[String]) -> void:
	if mapping.size() != element_count:
		problems.append("%s entry count must equal element_count" % label)
	for index in range(maxi(element_count, 0)):
		if not mapping.has(index):
			problems.append("%s is missing element index %d" % [label, index])
	for raw_index: Variant in mapping:
		if not raw_index is int or int(raw_index) < 0 or int(raw_index) >= element_count:
			problems.append("%s contains invalid element index '%s'" % [label, str(raw_index)])
