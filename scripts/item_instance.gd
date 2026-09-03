extends RefCounted
class_name ItemInstance

var instance_id := ""
var definition_id: StringName = &""
var rarity: StringName = &"common"
var quality := 1.0
var affixes: Dictionary = {}
## Independent random stat rolls. The keys are canonical stat names and the
## values are the number of `+` rolls assigned when the item dropped. This is
## separate from fusion enhancement, so a plain item can fuse with a + item.
var random_stat_points: Dictionary = {}
var transmutation_id: StringName = &""
var enhancement_level := 0


func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": String(definition_id),
		"rarity": String(rarity),
		"quality": quality,
		"affixes": affixes.duplicate(true),
		"random_stat_points": random_stat_points.duplicate(true),
		"transmutation_id": String(transmutation_id),
		"enhancement_level": enhancement_level,
	}


static func from_dictionary(data: Dictionary) -> ItemInstance:
	var item := ItemInstance.new()
	item.instance_id = str(data.get("instance_id", ""))
	item.definition_id = StringName(str(data.get("definition_id", "")))
	item.rarity = StringName(str(data.get("rarity", "common")))
	item.quality = clampf(float(data.get("quality", 1.0)), 0.8, 1.25)
	var saved_affixes: Variant = data.get("affixes", {})
	item.affixes = saved_affixes.duplicate(true) if saved_affixes is Dictionary else {}
	var saved_random_points: Variant = data.get("random_stat_points", data.get("bonus_stats", {}))
	item.random_stat_points = {}
	if saved_random_points is Dictionary:
		var remaining_points := 3
		for stat_key: Variant in saved_random_points:
			if remaining_points <= 0:
				break
			var canonical_stat := _canonical_random_stat(str(stat_key))
			if canonical_stat.is_empty():
				continue
			var points := mini(clampi(int(saved_random_points[stat_key]), 0, 3), remaining_points)
			if points > 0:
				item.random_stat_points[canonical_stat] = points
				remaining_points -= points
	item.transmutation_id = StringName(str(data.get("transmutation_id", "")))
	item.enhancement_level = clampi(int(data.get("enhancement_level", 0)), 0, PlayerProfile.MAX_ITEM_ENHANCEMENT)
	return item


static func _canonical_random_stat(stat_key: String) -> String:
	return {
		"vitality": "vitality",
		"vit": "vitality",
		"strength": "strength",
		"str": "strength",
		"defense": "defense",
		"def": "defense",
		"agi": "agi",
		"agility": "agi",
		"speed": "agi",
		"intelligence": "intelligence",
		"int": "intelligence",
		"mnd": "mnd",
		"mind": "mnd",
	}.get(stat_key.to_lower(), "")
