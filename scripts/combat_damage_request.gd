extends RefCounted
class_name CombatDamageRequest

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

enum DamageCategory {
	PHYSICAL,
	MAGIC,
	IMBUED_WEAPON,
	ELEMENTAL_SLIME,
}

const CONTRACT_PHYSICAL: StringName = &"physical"
const CONTRACT_MAGIC: StringName = &"magic"
const CONTRACT_IMBUE: StringName = &"imbue"
const CONTRACT_ELEMENTAL_SLIME: StringName = &"elemental_slime"

## A typed description of one damaging action. The calculator owns resolution;
## callers only choose a category and provide the authored contract values.
## Composite requests intentionally carry independent physical and magic
## portions so DEF and M.DEF can be applied before the packet is combined.
var category: DamageCategory = DamageCategory.PHYSICAL
var contract_id: StringName = CONTRACT_PHYSICAL
var physical_base := 0.0
var physical_stat_scale := 0.0
var magic_base := 0.0
var magic_stat_scale := 0.0
var defense_bonus := 0.0
var magic_defense_bonus := 0.0
var attack_element := ElementCatalogScript.Element.NEUTRAL
var defense_element := ElementCatalogScript.Element.NEUTRAL
var critical_eligible := false


static func physical(
	base_power: float,
	strength_scale: float,
	attack_element_value: int = ElementCatalogScript.Element.NEUTRAL,
	defense_element_value: int = ElementCatalogScript.Element.NEUTRAL,
	can_critical := false
) -> RefCounted:
	var request := new()
	request.category = DamageCategory.PHYSICAL
	request.contract_id = CONTRACT_PHYSICAL
	request.physical_base = base_power
	request.physical_stat_scale = strength_scale
	request.attack_element = attack_element_value
	request.defense_element = defense_element_value
	request.critical_eligible = can_critical
	return request


static func magic(
	base_power: float,
	intelligence_scale: float,
	attack_element_value: int = ElementCatalogScript.Element.NEUTRAL,
	defense_element_value: int = ElementCatalogScript.Element.NEUTRAL,
	can_critical := false
) -> RefCounted:
	var request := new()
	request.category = DamageCategory.MAGIC
	request.contract_id = CONTRACT_MAGIC
	request.magic_base = base_power
	request.magic_stat_scale = intelligence_scale
	request.attack_element = attack_element_value
	request.defense_element = defense_element_value
	request.critical_eligible = can_critical
	return request


static func imbued_weapon(
	physical_base_power: float,
	strength_scale: float,
	imbue_base_power: float,
	intelligence_scale: float,
	attack_element_value: int,
	defense_element_value: int = ElementCatalogScript.Element.NEUTRAL,
	can_critical := false
) -> RefCounted:
	var request := new()
	request.category = DamageCategory.IMBUED_WEAPON
	request.contract_id = CONTRACT_IMBUE
	request.physical_base = physical_base_power
	request.physical_stat_scale = strength_scale
	request.magic_base = imbue_base_power
	request.magic_stat_scale = intelligence_scale
	request.attack_element = attack_element_value
	request.defense_element = defense_element_value
	request.critical_eligible = can_critical
	return request


static func elemental_slime(
	physical_base_power: float,
	strength_scale: float,
	magic_base_power: float,
	intelligence_scale: float,
	attack_element_value: int,
	defense_element_value: int = ElementCatalogScript.Element.NEUTRAL,
	can_critical := false
) -> RefCounted:
	var request := new()
	request.category = DamageCategory.ELEMENTAL_SLIME
	request.contract_id = CONTRACT_ELEMENTAL_SLIME
	request.physical_base = physical_base_power
	request.physical_stat_scale = strength_scale
	request.magic_base = magic_base_power
	request.magic_stat_scale = intelligence_scale
	request.attack_element = attack_element_value
	request.defense_element = defense_element_value
	request.critical_eligible = can_critical
	return request


func is_composite() -> bool:
	return category == DamageCategory.IMBUED_WEAPON or category == DamageCategory.ELEMENTAL_SLIME


func has_magic_portion() -> bool:
	return not is_zero_approx(magic_base) or not is_zero_approx(magic_stat_scale)
