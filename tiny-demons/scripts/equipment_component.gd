extends Node
class_name EquipmentComponent

## Flat bonuses supplied by the currently equipped items.
@export var health_bonus := 0.0
@export var damage_bonus := 0.0
@export var defense_bonus := 0.0

@export var weapon_name := ""
@export var armor_name := ""


func equip_default_loadout() -> void:
	weapon_name = "Basic Sword"
	armor_name = "Basic Tunic"
	damage_bonus = 1.0
	health_bonus = 15.0
	defense_bonus = 0.0
