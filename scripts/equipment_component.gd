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

## Declared effects are kept as data for the action/effect owners. This avoids
## making the equipment component guess behavior from a display name while
## still giving Status and comparison screens one complete read model.
var declared_effects: Dictionary = {}
## Only effects whose contract is active are exposed to runtime owners. The
## declared map remains complete so an old save or a catalogue review can show
## an authored future effect without accidentally enabling it in combat.
var active_effects: Dictionary = {}
var elemental_resonances: Array[Dictionary] = []
var elemental_wards: Array[Dictionary] = []

var weapon_name := "BASIC SWORD"
var head_name := "BASIC HOOD"
var body_name := "BASIC TUNIC"
var arm_name := "BASIC WRAPS"
var armor_name:
	get:
		return body_name
	set(value):
		body_name = str(value)
var shield_name := "BASIC SHIELD"
var accessory_name := "BASIC CHARM"
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
		var instance_id := profile.get_equipped_instance_id(slot)
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
	var canonical_override := ItemCatalog.canonical_slot(override_slot)
	var preview_locks_head := canonical_override == &"body" and override_item != null and override_item.definition_id == &"demon_cloak"
	for slot: StringName in ItemCatalog.SLOTS:
		var instance: ItemInstance
		if slot == canonical_override:
			instance = override_item
		elif slot == &"head" and preview_locks_head:
			# Demon Cloak occupies Body and Head together. Mirror PlayerProfile's
			# equip rule in the temporary menu read model so its stat comparison does
			# not incorrectly retain the equipped helm.
			instance = null
		else:
			var instance_id := profile.get_equipped_instance_id(slot)
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
	declared_effects.clear()
	active_effects.clear()
	elemental_resonances.clear()
	elemental_wards.clear()
	equipped_transmutations.clear()
	weapon_name = "BASIC SWORD"
	head_name = "BASIC HOOD"
	body_name = "BASIC TUNIC"
	arm_name = "BASIC WRAPS"
	shield_name = "NO SHIELD"
	accessory_name = "BASIC CHARM"


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
	_register_effects(slot, instance, items.definition_effects(instance.definition_id), items, "definition")
	if items.transmutation_is_eligible(instance.definition_id, instance.transmutation_id, instance.rarity):
		equipped_transmutations[String(slot)] = String(instance.transmutation_id)
		var transmutation_effects := items.transmutation_effects(instance.transmutation_id)
		_register_effects(slot, instance, transmutation_effects, items, "transmutation")
		core_health_rate_bonus += float(transmutation_effects.get("core_health_rate", 0.0))
		vit_health_multiplier_bonus += float(transmutation_effects.get("vit_health_multiplier", 0.0))
	var shown_name: String = str(items.gear_name(instance))
	match slot:
		&"weapon": weapon_name = shown_name
		&"head": head_name = shown_name
		&"body": body_name = shown_name
		&"arm": arm_name = shown_name
		&"shield": shield_name = shown_name
		&"accessory": accessory_name = shown_name


func _register_effects(slot: StringName, instance: ItemInstance, effects: Dictionary, items: ItemCatalog, effect_source: String) -> void:
	for effect_id: Variant in effects:
		var id := StringName(str(effect_id))
		var effect_value: Variant = effects[effect_id]
		var entry := {"slot": String(slot), "instance_id": instance.instance_id, "definition_id": String(instance.definition_id), "source": effect_source, "status": items.effect_status(effect_value), "active": items.effect_is_runtime_active(effect_value), "value": effect_value}
		if not declared_effects.has(String(id)):
			declared_effects[String(id)] = []
		declared_effects[String(id)].append(entry)
		if not bool(entry["active"]):
			continue
		if not active_effects.has(String(id)):
			active_effects[String(id)] = []
		active_effects[String(id)].append(entry)
		if id == &"imbue_resonance":
			elemental_resonances.append(entry)
		elif id == &"elemental_ward":
			elemental_wards.append(entry)


func effect_entries(effect_id: StringName) -> Array:
	var entries: Variant = declared_effects.get(String(effect_id), [])
	return entries.duplicate(true) if entries is Array else []


func active_effect_entries(effect_id: StringName) -> Array:
	var entries: Variant = active_effects.get(String(effect_id), [])
	return entries.duplicate(true) if entries is Array else []
