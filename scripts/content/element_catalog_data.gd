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
@export var damage_number_color_boost := 1.10
@export var default_element := 0
@export var element_count := 8


func validate() -> Array[String]:
	var problems: Array[String] = []
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
		if seen_elements.has(definition.element):
			problems.append("multiple passive status effects use element %d" % definition.element)
		seen_elements[definition.element] = true
	for required_id in StatusEffectDefinition.STATUS_IDS:
		if not seen_ids.has(required_id):
			problems.append("missing status definition '%s'" % String(required_id))
	for registered_id: StringName in seen_ids.keys():
		if not StatusEffectDefinition.STATUS_IDS.has(registered_id) and not StatusEffectDefinition.AUXILIARY_STATUS_IDS.has(registered_id):
			problems.append("status registry contains unexpected id '%s'" % String(registered_id))
	return problems
