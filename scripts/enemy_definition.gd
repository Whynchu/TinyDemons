extends Resource
class_name EnemyDefinition

## Typed, editor-inspectable enemy content contract. Each definition is an
## authored sub-resource in SlimeVariantCatalogData, so the catalog stays the
## single source of truth while runtime assembly reads a typed contract.

@export var id: StringName = &""
@export var display_name := ""
@export var element := 0
@export var damage_contract: StringName = &"physical"
@export var base_stats: Dictionary = {}
@export var growth_weights: Dictionary = {}
## Artwork source name used to resolve direction/spawn/attack textures (for
## example "red" resolves to the shared red palette; recolor-only variants
## explicitly reuse a base art sheet and recolor at runtime.
@export var visual_source := "green"
## Encounter metadata belongs to the enemy definition so adding a variant does
## not require a RoomController branch or a parallel allowlist.
@export var encounter_role: StringName = &"matchup"
@export var encounter_weight := 0.0
@export var encounter_min_rank := 1
@export var matchup_weight := 0.0
@export var preferred_weight := 0.0
@export var allow_preferred := false


static func from_variant(variant: StringName) -> EnemyDefinition:
	var catalog := preload("res://scripts/slime_variant_catalog.gd")
	var definition := catalog.definition_resource(variant)
	if definition != null:
		return definition
	return catalog.definition_resource(&"grey")


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id.is_empty():
		problems.append("id must not be empty")
	if display_name.is_empty():
		problems.append("display_name must not be empty")
	if base_stats.is_empty():
		problems.append("base_stats must not be empty")
	if growth_weights.is_empty():
		problems.append("growth_weights must not be empty")
	if visual_source.is_empty():
		problems.append("visual_source must not be empty")
	if encounter_weight < 0.0:
		problems.append("encounter_weight must be non-negative")
	if encounter_min_rank < 1:
		problems.append("encounter_min_rank must be >= 1")
	if matchup_weight < 0.0:
		problems.append("matchup_weight must be non-negative")
	if preferred_weight < 0.0:
		problems.append("preferred_weight must be non-negative")
	if encounter_role not in [&"baseline", &"matchup", &"late", &"shadow"]:
		problems.append("unknown encounter_role '%s'" % encounter_role)
	return problems


func to_record() -> Dictionary:
	return {
		"variant": id,
		"display_name": display_name,
		"element": element,
		"damage_contract": damage_contract,
		"base_stats": base_stats.duplicate(true),
		"growth_weights": growth_weights.duplicate(true),
		"visual_source": visual_source,
		"encounter_role": encounter_role,
		"encounter_weight": encounter_weight,
		"encounter_min_rank": encounter_min_rank,
		"matchup_weight": matchup_weight,
		"preferred_weight": preferred_weight,
		"allow_preferred": allow_preferred,
	}
