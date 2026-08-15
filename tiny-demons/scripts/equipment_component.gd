extends Node
class_name EquipmentComponent

## Runtime snapshot of bonuses supplied by the profile's equipped item instances.
var health_rate_bonus := 0.0
var damage_rate_bonus := 0.0
var defense_bonus := 0.0
var strength_bonus := 0.0
var vitality_bonus := 0.0
var core_health_rate_bonus := 0.0
var vit_health_multiplier_bonus := 0.0

var weapon_name := "BASIC SWORD"
var armor_name := "BASIC TUNIC"
var shield_name := "BASIC SHIELD"
var accessory_name := "BANGLE"
var equipped_transmutations: Dictionary = {}


func _ready() -> void:
	equip_default_loadout()


func equip_default_loadout() -> void:
	var profile := PlayerProfile.new()
	profile.ensure_starter_items()
	configure_from_profile(profile)


func configure_from_profile(profile: PlayerProfile, catalog: ItemCatalog = null) -> void:
	var items := catalog if catalog != null else ItemCatalog.new()
	health_rate_bonus = 0.0
	damage_rate_bonus = 0.0
	defense_bonus = 0.0
	strength_bonus = 0.0
	vitality_bonus = 0.0
	core_health_rate_bonus = 0.0
	vit_health_multiplier_bonus = 0.0
	equipped_transmutations.clear()
	if profile == null:
		return
	for slot: StringName in ItemCatalog.SLOTS:
		var instance_id := str(profile.equipped_instance_ids.get(String(slot), ""))
		var instance := profile.find_item(instance_id)
		if instance == null:
			continue
		var item_bonuses := items.bonuses(instance, profile.mastery_level(instance.definition_id))
		var health_rate_points := float(item_bonuses.get("health_rate", 0.0))
		var damage_rate_points := float(item_bonuses.get("damage_rate", 0.0))
		if health_rate_points > 0.0: health_rate_bonus += maxf(health_rate_points, 1.0) * 0.01
		if damage_rate_points > 0.0: damage_rate_bonus += maxf(damage_rate_points, 1.0) * 0.01
		defense_bonus += float(item_bonuses.get("defense", 0.0))
		strength_bonus += float(item_bonuses.get("strength", 0.0))
		vitality_bonus += float(item_bonuses.get("vitality", 0.0))
		if not instance.transmutation_id.is_empty():
			equipped_transmutations[String(slot)] = String(instance.transmutation_id)
			var transmutation_effects := items.transmutation_effects(instance.transmutation_id)
			core_health_rate_bonus += float(transmutation_effects.get("core_health_rate", 0.0))
			vit_health_multiplier_bonus += float(transmutation_effects.get("vit_health_multiplier", 0.0))
		var shown_name := str(ItemCatalog.DEFINITIONS.get(instance.definition_id, {}).get("name", ""))
		match slot:
			&"weapon": weapon_name = shown_name
			&"armor": armor_name = shown_name
			&"shield": shield_name = shown_name
			&"accessory": accessory_name = shown_name


func has_transmutation(transmutation_id: StringName) -> bool:
	return String(transmutation_id) in equipped_transmutations.values()
