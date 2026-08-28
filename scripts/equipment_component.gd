extends Node
class_name EquipmentComponent

## Runtime snapshot of bonuses supplied by the profile's equipped item instances.
var defense_bonus := 0.0
var strength_bonus := 0.0
var vitality_bonus := 0.0
var agi_bonus := 0.0
var intelligence_bonus := 0.0
var mnd_bonus := 0.0
## Temporary compatibility aliases for pre-AGI snapshot consumers.
var speed_bonus:
	get:
		return agi_bonus
	set(value):
		agi_bonus = float(value)
var defense_rate_bonus := 0.0
var strength_rate_bonus := 0.0
var vitality_rate_bonus := 0.0
var agi_rate_bonus := 0.0
var intelligence_rate_bonus := 0.0
var mnd_rate_bonus := 0.0
var speed_rate_bonus:
	get:
		return agi_rate_bonus
	set(value):
		agi_rate_bonus = float(value)
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
	_reset_runtime_state()
	if profile == null:
		return
	for slot: StringName in ItemCatalog.SLOTS:
		var instance_id := str(profile.equipped_instance_ids.get(String(slot), ""))
		_apply_equipped_instance(slot, profile.find_item(instance_id), items)


func configure_preview_from_profile(profile: PlayerProfile, catalog: ItemCatalog, override_slot: StringName, override_item: ItemInstance) -> void:
	## Build an equipment read model for a candidate without mutating the saved
	## profile or live equipment node. Menu comparison code can pass this through
	## CombatStatSnapshot so previews use exactly the same flat-before-rate path as
	## combat and the status page.
	var items := catalog if catalog != null else ItemCatalog.new()
	_reset_runtime_state()
	if profile == null:
		return
	for slot: StringName in ItemCatalog.SLOTS:
		var instance: ItemInstance
		if slot == override_slot:
			instance = override_item
		else:
			var instance_id := str(profile.equipped_instance_ids.get(String(slot), ""))
			instance = profile.find_item(instance_id)
		_apply_equipped_instance(slot, instance, items)


func _reset_runtime_state() -> void:
	defense_bonus = 0.0
	strength_bonus = 0.0
	vitality_bonus = 0.0
	agi_bonus = 0.0
	intelligence_bonus = 0.0
	mnd_bonus = 0.0
	defense_rate_bonus = 0.0
	strength_rate_bonus = 0.0
	vitality_rate_bonus = 0.0
	agi_rate_bonus = 0.0
	intelligence_rate_bonus = 0.0
	mnd_rate_bonus = 0.0
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


func _apply_equipped_instance(slot: StringName, instance: ItemInstance, items: ItemCatalog) -> void:
	if instance == null or items.definition_slot(instance.definition_id) != slot:
		return
	var primary_points := items.combat_primary_points(instance)
	var player_stat_rates := items.player_stat_rates(instance)
	# Primary equipment stats are deterministic flat points. Rarity rates are
	# accumulated separately and applied to the affected player stats in the
	# combat snapshot.
	defense_bonus += float(primary_points.get("defense", 0.0))
	strength_bonus += float(primary_points.get("strength", 0.0))
	vitality_bonus += float(primary_points.get("vitality", 0.0))
	agi_bonus += float(primary_points.get("agi", primary_points.get("speed", 0.0)))
	intelligence_bonus += float(primary_points.get("intelligence", 0.0))
	mnd_bonus += float(primary_points.get("mnd", 0.0))
	defense_rate_bonus += float(player_stat_rates.get("defense", 0.0))
	strength_rate_bonus += float(player_stat_rates.get("strength", 0.0))
	vitality_rate_bonus += float(player_stat_rates.get("vitality", 0.0))
	agi_rate_bonus += float(player_stat_rates.get("agi", player_stat_rates.get("speed", 0.0)))
	intelligence_rate_bonus += float(player_stat_rates.get("intelligence", 0.0))
	mnd_rate_bonus += float(player_stat_rates.get("mnd", 0.0))
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
