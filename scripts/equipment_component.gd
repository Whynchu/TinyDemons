extends Node
class_name EquipmentComponent

## Runtime snapshot of bonuses supplied by the profile's equipped item instances.
var defense_bonus := 0.0
var strength_bonus := 0.0
var vitality_bonus := 0.0
var speed_bonus := 0.0
var defense_rate_bonus := 0.0
var strength_rate_bonus := 0.0
var vitality_rate_bonus := 0.0
var speed_rate_bonus := 0.0
var core_health_rate_bonus := 0.0
var vit_health_multiplier_bonus := 0.0
var guard_durability_bonus := 0.0
var guard_damage_reduction_bonus := 0.0
var has_shield := false

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
	defense_bonus = 0.0
	strength_bonus = 0.0
	vitality_bonus = 0.0
	speed_bonus = 0.0
	defense_rate_bonus = 0.0
	strength_rate_bonus = 0.0
	vitality_rate_bonus = 0.0
	speed_rate_bonus = 0.0
	core_health_rate_bonus = 0.0
	vit_health_multiplier_bonus = 0.0
	guard_durability_bonus = 0.0
	guard_damage_reduction_bonus = 0.0
	has_shield = false
	equipped_transmutations.clear()
	weapon_name = "BASIC SWORD"
	armor_name = "BASIC TUNIC"
	shield_name = "NO SHIELD"
	accessory_name = "BANGLE"
	if profile == null:
		return
	for slot: StringName in ItemCatalog.SLOTS:
		var instance_id := str(profile.equipped_instance_ids.get(String(slot), ""))
		var instance := profile.find_item(instance_id)
		if instance == null:
			continue
		var primary_points := items.combat_primary_points(instance)
		var player_stat_rates := items.player_stat_rates(instance)
		# Primary equipment stats are deterministic flat points. Rarity rates are
		# accumulated separately and applied to the affected player stats in the
		# combat snapshot.
		defense_bonus += float(primary_points.get("defense", 0.0))
		strength_bonus += float(primary_points.get("strength", 0.0))
		vitality_bonus += float(primary_points.get("vitality", 0.0))
		speed_bonus += float(primary_points.get("speed", 0.0))
		defense_rate_bonus += float(player_stat_rates.get("defense", 0.0))
		strength_rate_bonus += float(player_stat_rates.get("strength", 0.0))
		vitality_rate_bonus += float(player_stat_rates.get("vitality", 0.0))
		speed_rate_bonus += float(player_stat_rates.get("speed", 0.0))
		if slot == &"shield":
			has_shield = true
			var shield_bonuses := items.shield_bonuses(instance)
			guard_durability_bonus += float(shield_bonuses.get("guard_durability", 0.0))
			guard_damage_reduction_bonus += float(shield_bonuses.get("guard_reduction", 0.0)) * 0.01
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
