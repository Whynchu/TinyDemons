@tool
extends Resource
class_name ItemDefinition

## Typed, standalone equipment content contract. ItemCatalog converts this
## record into its compatibility dictionary at load time so existing item
## instances, saves, shops, and drop paths keep their current API.

@export var id: StringName = &""
@export var display_name := ""
@export var slot: StringName = &""
@export var gear_tier: StringName = &"basic"
@export var tier_stat: StringName = &""
@export var tier_stats: Array[String] = []
@export var bonuses: Dictionary = {}
@export var description := ""
@export var price := 0
@export var source_tags: Array[String] = []
@export var minimum_run_rank := 1
@export var minimum_player_level := 1
@export var rarity_floor: StringName = &"common"
@export var rarity_ceiling: StringName = &"mythic"
@export var shop_eligible := false
@export var starter_only := false
@export var live := true
@export var family: StringName = &"authored"
@export var role: StringName = &"stat"
@export var role_tags: Array[String] = []
@export var effects: Dictionary = {}
@export var shield: Dictionary = {}
@export var fusion_group: StringName = &""
@export var visual_id: StringName = &""
@export var set_id: StringName = &""
@export var set_name := ""
@export var passive_id: StringName = &""
@export var designer_notes := ""


func validate() -> Array[String]:
	var problems: Array[String] = []
	if id.is_empty():
		problems.append("id must not be empty")
	if display_name.is_empty():
		problems.append("display_name must not be empty")
	if slot not in [&"weapon", &"head", &"body", &"arm", &"shield", &"accessory"]:
		problems.append("slot must be one of the six canonical equipment slots")
	if gear_tier not in [&"plain", &"basic", &"set", &"legacy", &"expansion"]:
		problems.append("unknown gear_tier '%s'" % gear_tier)
	for stat: String in tier_stats:
		if stat not in ["vitality", "strength", "defense", "agi", "intelligence", "mnd"]:
			problems.append("unknown tier_stats entry '%s'" % stat)
	if price < 0:
		problems.append("price must be non-negative")
	if minimum_run_rank < 1:
		problems.append("minimum_run_rank must be >= 1")
	if minimum_player_level < 1:
		problems.append("minimum_player_level must be >= 1")
	if live and source_tags.is_empty():
		problems.append("live definitions must declare at least one source tag")
	for stat: Variant in bonuses:
		if not bonuses[stat] is int and not bonuses[stat] is float:
			problems.append("bonus '%s' must be numeric" % stat)
	return problems


func to_record() -> Dictionary:
	return {
		"id": String(id),
		"name": display_name,
		"description": description,
		"slot": slot,
		"gear_tier": gear_tier,
		"tier_stat": tier_stat,
		"tier_stats": tier_stats.duplicate(),
		"bonuses": bonuses.duplicate(true),
		"price": price,
		"source_tags": source_tags.duplicate(),
		"minimum_run_rank": minimum_run_rank,
		"minimum_player_level": minimum_player_level,
		"rarity_floor": rarity_floor,
		"rarity_ceiling": rarity_ceiling,
		"shop_eligible": shop_eligible,
		"starter_only": starter_only,
		"family": family,
		"role": role,
		"role_tags": role_tags.duplicate(),
		"effects": effects.duplicate(true),
		"shield": shield.duplicate(true),
		"fusion_group": fusion_group if not fusion_group.is_empty() else family,
		"visual_id": visual_id if not visual_id.is_empty() else id,
		"set_id": set_id,
		"set_name": set_name,
		"passive_id": passive_id,
		"designer_notes": designer_notes,
	}
