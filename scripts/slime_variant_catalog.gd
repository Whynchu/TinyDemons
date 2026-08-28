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
	&"orange",
	&"aquamarine",
]

const DEFINITIONS := {
	&"grey": {
		"variant": &"grey",
		"display_name": "Normal Slime",
		"element": ElementCatalogScript.Element.NEUTRAL,
		"damage_contract": &"physical",
		"base_stats": {"VIT": 2, "STR": 2, "DEF": 2, "AGI": 2, "INT": 0, "MND": 1},
		"growth_weights": {"VIT": 0.24, "STR": 0.24, "DEF": 0.24, "AGI": 0.20, "INT": 0.0, "MND": 0.08},
	},
	&"red": {
		"variant": &"red",
		"display_name": "Fire Slime",
		"element": ElementCatalogScript.Element.FIRE,
		"damage_contract": &"elemental_slime",
		"base_stats": {"VIT": 1, "STR": 4, "DEF": 2, "AGI": 1, "INT": 2, "MND": 1},
		"growth_weights": {"VIT": 0.08, "STR": 0.48, "DEF": 0.16, "AGI": 0.12, "INT": 0.12, "MND": 0.04},
	},
	&"blue": {
		"variant": &"blue",
		"display_name": "Water Slime",
		"element": ElementCatalogScript.Element.WATER,
		"damage_contract": &"elemental_slime",
		"base_stats": {"VIT": 2, "STR": 1, "DEF": 4, "AGI": 1, "INT": 2, "MND": 3},
		"growth_weights": {"VIT": 0.16, "STR": 0.08, "DEF": 0.44, "AGI": 0.10, "INT": 0.08, "MND": 0.14},
	},
	&"yellow": {
		"variant": &"yellow",
		"display_name": "Electric Slime",
		"element": ElementCatalogScript.Element.ELECTRIC,
		"damage_contract": &"elemental_slime",
		"base_stats": {"VIT": 2, "STR": 2, "DEF": 1, "AGI": 3, "INT": 3, "MND": 1},
		"growth_weights": {"VIT": 0.16, "STR": 0.12, "DEF": 0.08, "AGI": 0.44, "INT": 0.16, "MND": 0.04},
	},
	&"green": {
		"variant": &"green",
		"display_name": "Grass Slime",
		"element": ElementCatalogScript.Element.GRASS,
		"damage_contract": &"elemental_slime",
		"base_stats": {"VIT": 4, "STR": 1, "DEF": 2, "AGI": 1, "INT": 2, "MND": 2},
		"growth_weights": {"VIT": 0.44, "STR": 0.08, "DEF": 0.16, "AGI": 0.12, "INT": 0.10, "MND": 0.10},
	},
	&"purple": {
		"variant": &"purple",
		"display_name": "Shadow Slime",
		"element": ElementCatalogScript.Element.SHADOW,
		"damage_contract": &"elemental_slime",
		"base_stats": {"VIT": 1, "STR": 3, "DEF": 1, "AGI": 3, "INT": 3, "MND": 1},
		"growth_weights": {"VIT": 0.06, "STR": 0.36, "DEF": 0.06, "AGI": 0.36, "INT": 0.12, "MND": 0.04},
	},
	&"orange": {
		"variant": &"orange",
		"display_name": "Ground Slime",
		"element": ElementCatalogScript.Element.GROUND,
		"damage_contract": &"elemental_slime",
		"base_stats": {"VIT": 3, "STR": 1, "DEF": 3, "AGI": 1, "INT": 2, "MND": 2},
		"growth_weights": {"VIT": 0.28, "STR": 0.08, "DEF": 0.38, "AGI": 0.08, "INT": 0.10, "MND": 0.08},
	},
	&"aquamarine": {
		"variant": &"aquamarine",
		"display_name": "Ice Slime",
		"element": ElementCatalogScript.Element.ICE,
		"damage_contract": &"elemental_slime",
		"base_stats": {"VIT": 2, "STR": 2, "DEF": 1, "AGI": 3, "INT": 3, "MND": 2},
		"growth_weights": {"VIT": 0.10, "STR": 0.14, "DEF": 0.08, "AGI": 0.50, "INT": 0.10, "MND": 0.08},
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


static func damage_contract_for_variant(variant: StringName) -> StringName:
	return StringName(str(definition(variant).get("damage_contract", "physical")))


static func is_elemental_variant(variant: StringName) -> bool:
	return damage_contract_for_variant(variant) == &"elemental_slime"
