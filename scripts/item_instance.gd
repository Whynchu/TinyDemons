extends RefCounted
class_name ItemInstance

var instance_id := ""
var definition_id: StringName = &""
var rarity: StringName = &"common"
var quality := 1.0
var affixes: Dictionary = {}
var transmutation_id: StringName = &""
var enhancement_level := 0


func to_dictionary() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": String(definition_id),
		"rarity": String(rarity),
		"quality": quality,
		"affixes": affixes.duplicate(true),
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
	item.transmutation_id = StringName(str(data.get("transmutation_id", "")))
	item.enhancement_level = clampi(int(data.get("enhancement_level", 0)), 0, PlayerProfile.MAX_ITEM_ENHANCEMENT)
	return item
