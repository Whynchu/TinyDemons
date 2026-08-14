extends Node
class_name EquipmentComponent

## Flat bonuses supplied by the currently equipped items.
## These are computed from the item definitions below and are not editor data.
var health_bonus := 0.0
var damage_bonus := 0.0
var defense_bonus := 0.0
var strength_bonus := 0.0

@export var weapon_name := "Basic Sword"
@export var armor_name := "Basic Tunic"
@export var shield_name := "Basic Shield"
@export var accessory_name := "Bangle"


func _ready() -> void:
	_recalculate_bonuses()


func equip_default_loadout() -> void:
	weapon_name = "Basic Sword"
	armor_name = "Basic Tunic"
	shield_name = "Basic Shield"
	accessory_name = "Bangle"
	_recalculate_bonuses()


func _recalculate_bonuses() -> void:
	health_bonus = 0.0
	damage_bonus = 0.0
	defense_bonus = 0.0
	strength_bonus = 0.0
	for item_name in [weapon_name, armor_name, shield_name, accessory_name]:
		var item := _item_definition(item_name)
		health_bonus += float(item.get("health", 0.0))
		damage_bonus += float(item.get("damage", 0.0))
		defense_bonus += float(item.get("defense", 0.0))
		strength_bonus += float(item.get("strength", 0.0))


func _item_definition(item_name: String) -> Dictionary:
	match item_name:
		"Basic Sword":
			return {"damage": 1.0}
		"Basic Tunic":
			return {"health": 9.0}
		"Basic Shield":
			return {"defense": 1.0}
		"Bangle":
			return {"strength": 1.0, "health": 5.0}
	return {}
