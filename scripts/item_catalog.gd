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

# Primary item stats use two flat points for each rarity step. This keeps a
# full rarity/enhancement ladder small and predictable: a common +0 package
# of STR 2 becomes STR 3 at +10, then STR 4 at rare +0.
const RARITY_FLAT_POINTS_PER_RANK := 2
const RARITY_PLAYER_STAT_RATES := {
	&"common": 0.0,
	&"rare": 0.05,
	&"epic": 0.15,
	&"legendary": 0.45,
	&"mythic": 0.80,
}
const MASTERY_BONUS_PER_LEVEL := 0.10
const OVERFLOW_SALVAGE_RATE := 0.35

const BASIC_GEAR_DROP_WEIGHT := 5.0

const DEFINITIONS := {
	&"basic_sword": {"name": "BASIC SWORD", "slot": &"weapon", "tier_stat": "strength", "bonuses": {"strength": 2.0}, "price": 45},
	&"soldier_sword": {"name": "SOLDIER SWORD", "slot": &"weapon", "tier_stat": "strength", "bonuses": {"strength": 3.0, "speed": -1.0}, "price": 90},
	&"guardian_blade": {"name": "GUARDIAN BLADE", "slot": &"weapon", "tier_stat": "defense", "bonuses": {"defense": 2.0, "speed": -1.0}, "price": 95},
	&"blood_blade": {"name": "BLOOD BLADE", "slot": &"weapon", "tier_stat": "vitality", "bonuses": {"vitality": 2.0, "speed": -1.0}, "price": 115},
	&"iron_maul": {"name": "IRON MAUL", "slot": &"weapon", "tier_stat": "strength", "bonuses": {"strength": 2.0, "speed": -1.0}, "price": 105},
	&"quick_dagger": {"name": "QUICK DAGGER", "slot": &"weapon", "tier_stat": "speed", "bonuses": {"speed": 3.0}, "price": 75},
	&"basic_tunic": {"name": "BASIC TUNIC", "slot": &"armor", "tier_stat": "vitality", "bonuses": {"vitality": 1.0, "defense": 1.0}, "price": 45},
	&"bloodwoven_tunic": {"name": "BLOODWOVEN TUNIC", "slot": &"armor", "tier_stat": "vitality", "bonuses": {"vitality": 2.0, "speed": 1.0}, "price": 110},
	&"iron_cuirass": {"name": "IRON CUIRASS", "slot": &"armor", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 1.0, "speed": -1.0}, "price": 105},
	&"feather_cloak": {"name": "FEATHER CLOAK", "slot": &"armor", "tier_stat": "speed", "bonuses": {"speed": 3.0}, "price": 80},
	&"basic_shield": {"name": "BASIC SHIELD", "slot": &"shield", "tier_stat": "defense", "bonuses": {"vitality": 1.0, "speed": -1.0, "defense": 2.0}, "shield": {"guard_durability": 2.0, "guard_reduction": 1.0}, "price": 45},
	&"living_bulwark": {"name": "LIVING BULWARK", "slot": &"shield", "tier_stat": "defense", "bonuses": {"vitality": 1.0, "speed": -2.0, "defense": 3.0}, "shield": {"guard_durability": 4.0, "guard_reduction": 3.0}, "price": 110},
	&"thorn_guard": {"name": "THORN GUARD", "slot": &"shield", "tier_stat": "vitality", "bonuses": {"vitality": 2.0, "speed": -1.0, "defense": 2.0}, "shield": {"guard_durability": 3.0, "guard_reduction": 2.0}, "price": 105},
	&"parry_buckler": {"name": "PARRY BUCKLER", "slot": &"shield", "tier_stat": "defense", "bonuses": {"vitality": 1.0, "defense": 2.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0}, "price": 50},
	&"bangle": {"name": "BANGLE", "slot": &"accessory", "tier_stat": "strength", "bonuses": {"strength": 1.0, "vitality": 1.0, "speed": 1.0}, "price": 45},
	&"duelist_seal": {"name": "DUELIST SEAL", "slot": &"accessory", "tier_stat": "strength", "bonuses": {"strength": 2.0, "speed": -1.0}, "price": 105},
	&"warrior_charm": {"name": "WARRIOR CHARM", "slot": &"accessory", "tier_stat": "strength", "bonuses": {"strength": 2.0, "defense": 1.0, "speed": -1.0}, "price": 100},
	&"swift_boots": {"name": "SWIFT BOOTS", "slot": &"accessory", "tier_stat": "speed", "bonuses": {"speed": 3.0}, "price": 85},
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

func rarity_stat_rate(rarity: StringName) -> float:
	return float(RARITY_PLAYER_STAT_RATES.get(rarity, 0.0))

func rarity_flat_points(rarity: StringName) -> int:
	return _rarity_rank(rarity) * RARITY_FLAT_POINTS_PER_RANK

func enhancement_flat_points(enhancement_level: int) -> float:
	var level := clampi(enhancement_level, 0, PlayerProfile.MAX_ITEM_ENHANCEMENT)
	# Enhancements advance the authored tier stat by 0.1 each. This keeps the
	# existing +1.0 total at +10 while making every fusion step meaningful.
	return float(level) * MASTERY_BONUS_PER_LEVEL

func rarity_letter_grade(rarity: StringName) -> String:
	return {&"common": "C", &"rare": "R", &"epic": "E", &"legendary": "L", &"mythic": "M"}.get(rarity, "C")

static func next_rarity(rarity: StringName) -> StringName:
	return {&"common": &"rare", &"rare": &"epic", &"epic": &"legendary", &"legendary": &"mythic", &"mythic": &""}.get(rarity, &"")


func definition_slot(definition_id: StringName) -> StringName:
	return DEFINITIONS.get(definition_id, {}).get("slot", &"")


func display_name(item: ItemInstance) -> String:
	var definition: Dictionary = DEFINITIONS.get(item.definition_id, {})
	return "%s %s" % [RARITY_NAMES.get(item.rarity, "COMMON"), definition.get("name", "UNKNOWN ITEM")]

func player_stat_rates(item: ItemInstance) -> Dictionary:
	if item == null:
		return {}
	var rate := rarity_stat_rate(item.rarity)
	if is_zero_approx(rate):
		return {}
	var result: Dictionary = {}
	var package := bonuses(item)
	# A rarity rate is a buff to a stat the item positively supplies. Negative
	# trade-offs remain flat so a higher rarity never turns a penalty into a
	# hidden bonus.
	for stat: String in ["strength", "vitality", "defense", "speed"]:
		if float(package.get(stat, 0.0)) > 0.0:
			result[stat] = rate
	return result

func player_stat_rate_text(item: ItemInstance) -> String:
	var labels := {"strength": "STR", "vitality": "VIT", "defense": "DEF", "speed": "SPD"}
	var parts: Array[String] = []
	var rates := player_stat_rates(item)
	if rates.is_empty() and item != null:
		return "PLAYER +%d%%" % roundi(rarity_stat_rate(item.rarity) * 100.0)
	for stat: String in ["strength", "vitality", "defense", "speed"]:
		if rates.has(stat):
			parts.append("%s +%d%%" % [labels[stat], roundi(float(rates[stat]) * 100.0)])
	return " ".join(parts)


func bonuses(item: ItemInstance, _mastery_level: int = 0) -> Dictionary:
	var definition: Dictionary = DEFINITIONS.get(item.definition_id, {})
	var result: Dictionary = {}
	var base_bonuses: Dictionary = definition.get("bonuses", {})
	var flat_points := float(rarity_flat_points(item.rarity)) + enhancement_flat_points(item.enhancement_level)
	var tier_stat := str(definition.get("tier_stat", ""))
	for stat: String in base_bonuses:
		var base_value := float(base_bonuses[stat])
		var normalized_stat: String = str({"health": "health_rate", "damage": "damage_rate"}.get(stat, stat))
		if normalized_stat in ["health_rate", "damage_rate"]:
			continue
		var flat_value := base_value
		if normalized_stat == tier_stat:
			flat_value += flat_points
		# Legacy affixes remain serialized for save compatibility, but the new
		# tier package is deterministic and no longer adds hidden stat points.
		result[normalized_stat] = flat_value
	return result


func combat_primary_points(item: ItemInstance) -> Dictionary:
	var result: Dictionary = {}
	var displayed_bonuses := bonuses(item)
	for stat in ["strength", "vitality", "defense", "speed"]:
		if displayed_bonuses.has(stat):
			result[stat] = float(displayed_bonuses[stat])
	return result


func shield_bonuses(item: ItemInstance) -> Dictionary:
	if item == null or definition_slot(item.definition_id) != &"shield":
		return {}
	var definition: Dictionary = DEFINITIONS.get(item.definition_id, {})
	var shield_values: Dictionary = definition.get("shield", {})
	var rarity_multiplier := 1.0 + rarity_stat_rate(item.rarity)
	var enhancement_factor := 1.0 + MASTERY_BONUS_PER_LEVEL * float(clampi(item.enhancement_level, 0, PlayerProfile.MAX_ITEM_ENHANCEMENT))
	var result: Dictionary = {}
	for stat: String in shield_values:
		# Guard strength improves with enhancement; primary-stat trade-offs live
		# in the visible bonuses package and are handled separately.
		var mastery_multiplier := enhancement_factor if stat in ["guard_durability", "guard_reduction"] else 1.0
		result[stat] = float(shield_values[stat]) * rarity_multiplier * mastery_multiplier
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
