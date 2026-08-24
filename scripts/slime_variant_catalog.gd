extends RefCounted
class_name SlimeVariantCatalog

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

const VARIANTS: Array[StringName] = [
	&"grey",
	&"red",
	&"blue",
	&"yellow",
	&"green",
	&"purple",
]

const DEFINITIONS := {
	&"grey": {
		"variant": &"grey",
		"display_name": "Slime",
		"element": ElementCatalogScript.Element.NEUTRAL,
		"base_stats": {"VIT": 2, "STR": 2, "DEF": 2, "SPD": 2},
		"growth_weights": {"VIT": 0.25, "STR": 0.25, "DEF": 0.25, "SPD": 0.25},
	},
	&"red": {
		"variant": &"red",
		"display_name": "Fire Slime",
		"element": ElementCatalogScript.Element.FIRE,
		"base_stats": {"VIT": 1, "STR": 4, "DEF": 2, "SPD": 1},
		"growth_weights": {"VIT": 0.10, "STR": 0.55, "DEF": 0.20, "SPD": 0.15},
	},
	&"blue": {
		"variant": &"blue",
		"display_name": "Water Slime",
		"element": ElementCatalogScript.Element.WATER,
		"base_stats": {"VIT": 2, "STR": 1, "DEF": 4, "SPD": 1},
		"growth_weights": {"VIT": 0.20, "STR": 0.10, "DEF": 0.55, "SPD": 0.15},
	},
	&"yellow": {
		"variant": &"yellow",
		"display_name": "Electric Slime",
		"element": ElementCatalogScript.Element.ELECTRIC,
		"base_stats": {"VIT": 2, "STR": 2, "DEF": 1, "SPD": 3},
		"growth_weights": {"VIT": 0.20, "STR": 0.15, "DEF": 0.10, "SPD": 0.55},
	},
	&"green": {
		"variant": &"green",
		"display_name": "Grass Slime",
		"element": ElementCatalogScript.Element.GRASS,
		"base_stats": {"VIT": 4, "STR": 1, "DEF": 2, "SPD": 1},
		"growth_weights": {"VIT": 0.55, "STR": 0.10, "DEF": 0.20, "SPD": 0.15},
	},
	&"purple": {
		"variant": &"purple",
		"display_name": "Rogue Slime",
		"element": ElementCatalogScript.Element.SHADOW,
		"base_stats": {"VIT": 1, "STR": 3, "DEF": 1, "SPD": 3},
		"growth_weights": {"VIT": 0.08, "STR": 0.42, "DEF": 0.08, "SPD": 0.42},
	},
}


static func is_variant(variant: StringName) -> bool:
	return DEFINITIONS.has(variant)


static func definition(variant: StringName) -> Dictionary:
	var key := variant if is_variant(variant) else &"grey"
	return (DEFINITIONS[key] as Dictionary).duplicate(true)


static func element_for_variant(variant: StringName) -> int:
	return int(definition(variant)["element"])


static func display_name_for_variant(variant: StringName) -> String:
	return str(definition(variant)["display_name"])
