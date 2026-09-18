extends RefCounted
class_name SlimeVariantCatalog

## Editor-inspectable slime variant definitions. The authored data lives in
## resources/definitions/slime_variant_catalog.tres as the single source of
## truth; this class keeps the static lookup API over that resource.

const DATA := preload("res://resources/definitions/slime_variant_catalog.tres") as SlimeVariantCatalogData

const VARIANTS: Array[StringName] = [
	&"grey",
	&"red",
	&"blue",
	&"yellow",
	&"green",
	&"purple",
	&"orange",
	&"aquamarine",
	&"crimson",
]


static func definitions() -> Dictionary:
	return DATA.definitions


static func is_variant(variant: StringName) -> bool:
	return definitions().has(variant)


static func definition(variant: StringName) -> Dictionary:
	var key := variant if is_variant(variant) else &"grey"
	return (definitions()[key] as Dictionary).duplicate(true)


static func element_for_variant(variant: StringName) -> int:
	return int(definition(variant)["element"])


static func display_name_for_variant(variant: StringName) -> String:
	return str(definition(variant)["display_name"])


static func damage_contract_for_variant(variant: StringName) -> StringName:
	return StringName(str(definition(variant).get("damage_contract", "physical")))


static func is_elemental_variant(variant: StringName) -> bool:
	return damage_contract_for_variant(variant) == &"elemental_slime"