extends RefCounted
class_name ItemCatalog

const SLOTS: Array[StringName] = [&"weapon", &"armor", &"shield", &"accessory"]
const UNEQUIP_SHIELD_ID := "__unequip_shield__"
const RARITY_NAMES := {&"common": "COMMON", &"rare": "RARE", &"epic": "EPIC", &"legendary": "LEGENDARY", &"mythic": "MYTHIC"}
const RARITY_COLORS := {
	&"common": Color.WHITE,
	&"rare": Color8(103, 196, 255),
	&"epic": Color8(185, 110, 255),
	&"legendary": Color8(255, 205, 117),
	&"mythic": Color8(239, 125, 87),
}
const MASTERY_BONUS_PER_LEVEL := 0.10
const OVERFLOW_SALVAGE_RATE := 0.35
const RARITY_POWER_MULTIPLIERS := {
	&"common": 1.0,
	&"rare": 2.2,
	&"epic": 4.84,
	&"legendary": 10.648,
	&"mythic": 23.4256,
}

const BASIC_GEAR_DROP_WEIGHT := 5.0

const DEFINITIONS := {
	&"basic_sword": {"name": "BASIC SWORD", "slot": &"weapon", "bonuses": {"damage_rate": 5.0, "strength": 1.0}, "price": 45},
	&"soldier_sword": {"name": "SOLDIER SWORD", "slot": &"weapon", "bonuses": {"damage_rate": 7.0, "strength": 2.0, "speed": -1.0}, "price": 90},
	&"guardian_blade": {"name": "GUARDIAN BLADE", "slot": &"weapon", "bonuses": {"damage_rate": 7.0, "defense": 2.0, "speed": -1.0}, "price": 95},
	&"blood_blade": {"name": "BLOOD BLADE", "slot": &"weapon", "bonuses": {"damage_rate": 7.0, "vitality": 2.0, "speed": -1.0}, "price": 115},
	&"iron_maul": {"name": "IRON MAUL", "slot": &"weapon", "bonuses": {"damage_rate": 8.0, "strength": 1.0, "speed": -1.0}, "price": 105},
	&"quick_dagger": {"name": "QUICK DAGGER", "slot": &"weapon", "bonuses": {"damage_rate": 3.0, "speed": 5.0}, "price": 75},
	&"basic_tunic": {"name": "BASIC TUNIC", "slot": &"armor", "bonuses": {"health_rate": 5.0, "strength": 1.0, "vitality": 1.0, "defense": 1.0, "speed": 1.0}, "price": 45},
	&"bloodwoven_tunic": {"name": "BLOODWOVEN TUNIC", "slot": &"armor", "bonuses": {"health_rate": 8.0, "vitality": 2.0, "speed": 1.0}, "price": 110},
	&"iron_cuirass": {"name": "IRON CUIRASS", "slot": &"armor", "bonuses": {"health_rate": 6.0, "defense": 2.0, "vitality": 1.0, "speed": -2.0}, "price": 105},
	&"feather_cloak": {"name": "FEATHER CLOAK", "slot": &"armor", "bonuses": {"health_rate": 4.0, "speed": 5.0}, "price": 80},
	&"basic_shield": {"name": "BASIC SHIELD", "slot": &"shield", "bonuses": {"health_rate": 5.0, "defense": 1.0}, "shield": {"guard_durability": 2.0, "guard_reduction": 1.0, "strength_penalty": 1.0, "damage_penalty": 2.0, "speed_penalty": 1.0}, "price": 45},
	&"living_bulwark": {"name": "LIVING BULWARK", "slot": &"shield", "bonuses": {"health_rate": 7.0, "defense": 2.0}, "shield": {"guard_durability": 4.0, "guard_reduction": 3.0, "strength_penalty": 2.0, "damage_penalty": 5.0, "speed_penalty": 2.0}, "price": 110},
	&"thorn_guard": {"name": "THORN GUARD", "slot": &"shield", "bonuses": {"health_rate": 6.0, "defense": 2.0, "vitality": 1.0}, "shield": {"guard_durability": 3.0, "guard_reduction": 2.0, "strength_penalty": 2.0, "damage_penalty": 4.0, "speed_penalty": 2.0}, "price": 105},
	&"parry_buckler": {"name": "PARRY BUCKLER", "slot": &"shield", "bonuses": {"health_rate": 3.0, "defense": 1.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0, "strength_penalty": 0.0, "damage_penalty": 1.0, "speed_penalty": 0.0}, "price": 50},
	&"bangle": {"name": "BANGLE", "slot": &"accessory", "bonuses": {"strength": 1.0, "health_rate": 5.0, "speed": 1.0}, "price": 45},
	&"duelist_seal": {"name": "DUELIST SEAL", "slot": &"accessory", "bonuses": {"damage_rate": 7.0, "strength": 2.0, "speed": -1.0}, "price": 105},
	&"warrior_charm": {"name": "WARRIOR CHARM", "slot": &"accessory", "bonuses": {"strength": 2.0, "defense": 1.0, "health_rate": 4.0, "speed": -1.0}, "price": 100},
	&"swift_boots": {"name": "SWIFT BOOTS", "slot": &"accessory", "bonuses": {"speed": 8.0}, "price": 85},
}

const AFFIXES := {
	&"keen": {"name": "KEEN", "slots": [&"weapon"], "stat": "damage_rate", "min": 1, "max": 2},
	&"savage": {"name": "SAVAGE", "slots": [&"weapon"], "stat": "damage_rate", "min": 1, "max": 3},
	&"mighty": {"name": "MIGHTY", "slots": [&"weapon", &"accessory"], "stat": "strength", "min": 1, "max": 2},
	&"sturdy": {"name": "STURDY", "slots": [&"armor", &"shield", &"accessory"], "stat": "health_rate", "min": 2, "max": 5},
	&"warded": {"name": "WARDED", "slots": [&"armor", &"shield"], "stat": "defense", "min": 1, "max": 2},
	&"vital": {"name": "VITAL", "slots": [&"armor", &"accessory"], "stat": "vitality", "min": 1, "max": 2},
	&"swift": {"name": "SWIFT", "slots": [&"weapon", &"armor", &"accessory"], "stat": "speed", "min": 1, "max": 2},
}

const TRANSMUTATIONS := {
	&"gathering_edge": {
		"name": "GATHERING EDGE",
		"slot": &"weapon",
		"definitions": [&"soldier_sword"],
		"description": "ATTACK 1 HITTING 2+ TARGETS IMPROVES ATTACK 2 SHARE.",
	},
	&"duelist_focus": {
		"name": "DUELIST FOCUS",
		"slot": &"accessory",
		"definitions": [&"duelist_seal"],
		"description": "LOCKED TARGET DMG SCALES WITH STR. OTHER TARGETS -20%.",
	},
	&"bloodwoven_core": {
		"name": "BLOODWOVEN CORE",
		"slot": &"armor",
		"definitions": [&"bloodwoven_tunic"],
		"description": "CORE HP +12%. VIT-DERIVED HEALTH +20%.",
		"effects": {"core_health_rate": 0.12, "vit_health_multiplier": 0.20},
	},
	&"blood_feed": {
		"name": "BLOOD FEED",
		"slot": &"weapon",
		"definitions": [&"blood_blade"],
		"min_rarity": &"legendary",
		"description": "DAMAGE DEALT HEALS 20% OF THE HIT.",
	},
	&"bastion_core": {
		"name": "BASTION CORE",
		"slot": &"shield",
		"definitions": [&"living_bulwark"],
		"description": "DEF RAISES GUARD. BLOCKS CHARGE ATTACK 2 KNOCKBACK.",
	},
}


func starter_item(slot: StringName) -> ItemInstance:
	var ids := {&"weapon": &"basic_sword", &"armor": &"basic_tunic", &"shield": &"basic_shield", &"accessory": &"bangle"}
	var item := ItemInstance.new()
	item.instance_id = "starter-%s" % String(slot)
	item.definition_id = ids.get(slot, &"basic_sword")
	return item


func generate_item(slot: StringName, generation_seed: int, level: int = 1, minimum_rarity: StringName = &"", prefer_non_basic: bool = false) -> ItemInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed
	var candidates: Array[StringName] = []
	var weights: Array[float] = []
	for definition_id: StringName in DEFINITIONS:
		if definition_slot(definition_id) != slot:
			continue
		if prefer_non_basic and _is_basic_gear(definition_id):
			continue
		candidates.append(definition_id)
		weights.append(BASIC_GEAR_DROP_WEIGHT if _is_basic_gear(definition_id) else 1.0)
	var item := ItemInstance.new()
	item.definition_id = _pick_weighted_definition(candidates, weights, rng)
	item.rarity = minimum_rarity if not minimum_rarity.is_empty() else roll_run_rarity(rng.randf(), level)
	item.quality = snappedf(rng.randf_range(0.9, 1.1), 0.01)
	var available: Array[StringName] = []
	for affix_id: StringName in AFFIXES:
		if slot in AFFIXES[affix_id]["slots"]:
			available.append(affix_id)
	var count := _affix_count_for_rarity(item.rarity)
	for index in range(mini(count, available.size())):
		var selected_index := rng.randi_range(0, available.size() - 1)
		var affix_id: StringName = available.pop_at(selected_index)
		var definition: Dictionary = AFFIXES[affix_id]
		item.affixes[String(affix_id)] = rng.randi_range(int(definition["min"]), int(definition["max"]))
	if item.rarity in [&"epic", &"legendary", &"mythic"]:
		var available_transmutations := transmutations_for_definition(item.definition_id)
		if not available_transmutations.is_empty():
			var eligible: Array[StringName] = []
			for transmutation_id: StringName in available_transmutations:
				var min_rarity := StringName(TRANSMUTATIONS[transmutation_id].get("min_rarity", &"epic"))
				if _rarity_rank(item.rarity) >= _rarity_rank(min_rarity):
					eligible.append(transmutation_id)
			if not eligible.is_empty():
				item.transmutation_id = eligible[rng.randi_range(0, eligible.size() - 1)]
	return item


func _rarity_rank(rarity: StringName) -> int:
	return {&"common": 0, &"rare": 1, &"epic": 2, &"legendary": 3, &"mythic": 4}.get(rarity, 0)


func _is_basic_gear(definition_id: StringName) -> bool:
	return definition_id in [&"basic_sword", &"basic_tunic", &"basic_shield", &"bangle"]


func _pick_weighted_definition(candidates: Array[StringName], weights: Array[float], rng: RandomNumberGenerator) -> StringName:
	var total_weight := 0.0
	for weight in weights:
		total_weight += weight
	var roll := rng.randf_range(0.0, total_weight)
	for index in candidates.size():
		roll -= weights[index]
		if roll <= 0.0:
			return candidates[index]
	return candidates.back()


func transmutations_for_definition(definition_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for transmutation_id: StringName in TRANSMUTATIONS:
		var definition: Dictionary = TRANSMUTATIONS[transmutation_id]
		if definition_id in definition.get("definitions", []):
			result.append(transmutation_id)
	return result


func transmutation_name(transmutation_id: StringName) -> String:
	return str(TRANSMUTATIONS.get(transmutation_id, {}).get("name", ""))


func transmutation_description(transmutation_id: StringName) -> String:
	return str(TRANSMUTATIONS.get(transmutation_id, {}).get("description", ""))


func transmutation_effects(transmutation_id: StringName) -> Dictionary:
	return TRANSMUTATIONS.get(transmutation_id, {}).get("effects", {}).duplicate(true)


func rarity_color(rarity: StringName) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

func rarity_letter_grade(rarity: StringName) -> String:
	return {&"common": "C", &"rare": "R", &"epic": "E", &"legendary": "L", &"mythic": "M"}.get(rarity, "C")

static func next_rarity(rarity: StringName) -> StringName:
	return {&"common": &"rare", &"rare": &"epic", &"epic": &"legendary", &"legendary": &"mythic", &"mythic": &""}.get(rarity, &"")


func definition_slot(definition_id: StringName) -> StringName:
	return DEFINITIONS.get(definition_id, {}).get("slot", &"")


func display_name(item: ItemInstance) -> String:
	var definition: Dictionary = DEFINITIONS.get(item.definition_id, {})
	return "%s %s" % [RARITY_NAMES.get(item.rarity, "COMMON"), definition.get("name", "UNKNOWN ITEM")]


func bonuses(item: ItemInstance, _mastery_level: int = 0) -> Dictionary:
	var definition: Dictionary = DEFINITIONS.get(item.definition_id, {})
	var result: Dictionary = {}
	var enhancement_level := clampi(item.enhancement_level, 0, PlayerProfile.MAX_ITEM_ENHANCEMENT)
	var enhancement_factor := 1.0 + MASTERY_BONUS_PER_LEVEL * float(enhancement_level)
	var base_bonuses: Dictionary = definition.get("bonuses", {})
	var rarity_multiplier := float(RARITY_POWER_MULTIPLIERS.get(item.rarity, 1.0))
	for stat: String in base_bonuses:
		var base_value := float(base_bonuses[stat])
		var normalized_stat: String = str({"health": "health_rate", "damage": "damage_rate"}.get(stat, stat))
		# Each tier is 2.2x the previous (RARITY_POWER_MULTIPLIERS). Enhancement
		# then adds 10% of that tier's package per level, capping at +10 = 2.0x.
		# Because 2.0 < 2.2, a +10 item always stays below the next tier's +0,
		# so higher rarity is always worth more than more enhancement.
		var tier_base := base_value * rarity_multiplier
		result[normalized_stat] = tier_base * enhancement_factor
	for affix_key: String in item.affixes:
		var affix: Dictionary = AFFIXES.get(StringName(affix_key), {})
		var stat := str(affix.get("stat", ""))
		stat = {"health": "health_rate", "damage": "damage_rate"}.get(stat, stat)
		if not stat.is_empty():
			# Affixes scale with enhancement too, so every modified stat grows.
			result[stat] = float(result.get(stat, 0.0)) + float(item.affixes[affix_key]) * enhancement_factor
	return result


func shield_bonuses(item: ItemInstance) -> Dictionary:
	if item == null or definition_slot(item.definition_id) != &"shield":
		return {}
	var definition: Dictionary = DEFINITIONS.get(item.definition_id, {})
	var shield_values: Dictionary = definition.get("shield", {})
	var rarity_multiplier := float(RARITY_POWER_MULTIPLIERS.get(item.rarity, 1.0))
	var enhancement_factor := 1.0 + MASTERY_BONUS_PER_LEVEL * float(clampi(item.enhancement_level, 0, PlayerProfile.MAX_ITEM_ENHANCEMENT))
	var result: Dictionary = {}
	for stat: String in shield_values:
		result[stat] = float(shield_values[stat]) * rarity_multiplier * enhancement_factor
	return result


func price(item: ItemInstance) -> int:
	var base := int(DEFINITIONS.get(item.definition_id, {}).get("price", 50))
	var multiplier: float = float({&"common": 1.0, &"rare": 1.8, &"epic": 3.2, &"legendary": 5.2, &"mythic": 8.0}.get(item.rarity, 1.0))
	return maxi(1, roundi(base * multiplier * item.quality))


func overflow_salvage_value(item: ItemInstance) -> int:
	return maxi(1, roundi(price(item) * OVERFLOW_SALVAGE_RATE))


func roll_run_rarity(roll: float, rank: int, performance_bonus: float = 0.0) -> StringName:
	var rank_bonus := float(maxi(rank, 1) - 1)
	# Every item-drop source has a real legendary/mythic chance at R1. Rank and
	# performance improve the odds rather than acting as hard rarity gates.
	var mythic_chance := clampf(0.0005 + rank_bonus * 0.0005 + performance_bonus * 0.0005, 0.0005, 0.010)
	var legendary_chance := clampf(0.003 + rank_bonus * 0.0015 + performance_bonus * 0.0015, 0.003, 0.025)
	var epic_chance := clampf(0.015 + rank_bonus * 0.004 + performance_bonus * 0.004, 0.015, 0.070)
	var rare_chance := clampf(0.120 + rank_bonus * 0.012 + performance_bonus * 0.010, 0.120, 0.280)
	if roll < mythic_chance: return &"mythic"
	if roll < mythic_chance + legendary_chance: return &"legendary"
	if roll < mythic_chance + legendary_chance + epic_chance: return &"epic"
	if roll < mythic_chance + legendary_chance + epic_chance + rare_chance: return &"rare"
	return &"common"


func _affix_count_for_rarity(rarity: StringName) -> int:
	return {&"common": 0, &"rare": 1, &"epic": 2, &"legendary": 3, &"mythic": 3}.get(rarity, 0)
