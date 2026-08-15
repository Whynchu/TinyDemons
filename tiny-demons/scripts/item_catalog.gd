extends RefCounted
class_name ItemCatalog

const SLOTS: Array[StringName] = [&"weapon", &"armor", &"shield", &"accessory"]
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

const DEFINITIONS := {
	&"basic_sword": {"name": "BASIC SWORD", "slot": &"weapon", "bonuses": {"damage_rate": 5.0, "strength": 1.0}, "price": 45},
	&"soldier_sword": {"name": "SOLDIER SWORD", "slot": &"weapon", "bonuses": {"damage_rate": 10.0, "strength": 3.0}, "price": 90},
	&"guardian_blade": {"name": "GUARDIAN BLADE", "slot": &"weapon", "bonuses": {"damage_rate": 10.0, "defense": 3.0}, "price": 95},
	&"blood_blade": {"name": "BLOOD BLADE", "slot": &"weapon", "bonuses": {"damage_rate": 10.0, "vitality": 3.0}, "price": 115},
	&"basic_tunic": {"name": "BASIC TUNIC", "slot": &"armor", "bonuses": {"health_rate": 5.0, "strength": 1.0, "vitality": 1.0, "defense": 1.0}, "price": 45},
	&"bloodwoven_tunic": {"name": "BLOODWOVEN TUNIC", "slot": &"armor", "bonuses": {"health_rate": 10.0, "vitality": 3.0}, "price": 110},
	&"basic_shield": {"name": "BASIC SHIELD", "slot": &"shield", "bonuses": {"health_rate": 5.0, "defense": 1.0}, "price": 45},
	&"living_bulwark": {"name": "LIVING BULWARK", "slot": &"shield", "bonuses": {"health_rate": 10.0, "defense": 3.0}, "price": 110},
	&"bangle": {"name": "BANGLE", "slot": &"accessory", "bonuses": {"strength": 1.0, "health_rate": 5.0}, "price": 45},
	&"duelist_seal": {"name": "DUELIST SEAL", "slot": &"accessory", "bonuses": {"damage_rate": 10.0, "strength": 3.0}, "price": 105},
}

const AFFIXES := {
	&"keen": {"name": "KEEN", "slots": [&"weapon"], "stat": "damage_rate", "min": 1, "max": 2},
	&"savage": {"name": "SAVAGE", "slots": [&"weapon"], "stat": "damage_rate", "min": 1, "max": 3},
	&"mighty": {"name": "MIGHTY", "slots": [&"weapon", &"accessory"], "stat": "strength", "min": 1, "max": 2},
	&"sturdy": {"name": "STURDY", "slots": [&"armor", &"shield", &"accessory"], "stat": "health_rate", "min": 2, "max": 5},
	&"warded": {"name": "WARDED", "slots": [&"armor", &"shield"], "stat": "defense", "min": 1, "max": 2},
	&"vital": {"name": "VITAL", "slots": [&"armor", &"accessory"], "stat": "vitality", "min": 1, "max": 2},
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


func generate_item(slot: StringName, generation_seed: int, level: int = 1, minimum_rarity: StringName = &"") -> ItemInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed
	var candidates: Array[StringName] = []
	for definition_id: StringName in DEFINITIONS:
		if definition_slot(definition_id) == slot:
			candidates.append(definition_id)
	var item := ItemInstance.new()
	item.definition_id = candidates[rng.randi_range(0, candidates.size() - 1)]
	item.rarity = minimum_rarity if not minimum_rarity.is_empty() else _roll_rarity(rng, level)
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
			item.transmutation_id = available_transmutations[rng.randi_range(0, available_transmutations.size() - 1)]
	return item


func transmutations_for_definition(definition_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for transmutation_id: StringName in TRANSMUTATIONS:
		var definition: Dictionary = TRANSMUTATIONS[transmutation_id]
		if definition_id in definition.get("definitions", []):
			result.append(transmutation_id)
	return result


func transmutation_name(transmutation_id: StringName) -> String:
	return str(TRANSMUTATIONS.get(transmutation_id, {}).get("name", ""))


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
	var base_bonuses: Dictionary = definition.get("bonuses", {})
	for stat: String in base_bonuses:
		var base_value := float(base_bonuses[stat])
		var normalized_stat: String = str({"health": "health_rate", "damage": "damage_rate"}.get(stat, stat))
		# Health and damage are percentage points. Every enhancement has a real
		# minimum +1 percentage-point effect, even on basic gear.
		var per_level_increase := maxf(1.0, roundf(base_value * MASTERY_BONUS_PER_LEVEL))
		result[normalized_stat] = base_value + per_level_increase * float(enhancement_level)
	for affix_key: String in item.affixes:
		var affix: Dictionary = AFFIXES.get(StringName(affix_key), {})
		var stat := str(affix.get("stat", ""))
		stat = {"health": "health_rate", "damage": "damage_rate"}.get(stat, stat)
		if not stat.is_empty():
			result[stat] = float(result.get(stat, 0.0)) + float(item.affixes[affix_key])
	return result


func price(item: ItemInstance) -> int:
	var base := int(DEFINITIONS.get(item.definition_id, {}).get("price", 50))
	var multiplier: float = float({&"common": 1.0, &"rare": 1.8, &"epic": 3.2, &"legendary": 5.2, &"mythic": 8.0}.get(item.rarity, 1.0))
	return maxi(1, roundi(base * multiplier * item.quality))


func overflow_salvage_value(item: ItemInstance) -> int:
	return maxi(1, roundi(price(item) * OVERFLOW_SALVAGE_RATE))


func _roll_rarity(rng: RandomNumberGenerator, level: int) -> StringName:
	var roll := rng.randf()
	var mythic_chance := minf(0.002 + level * 0.00008, 0.01)
	var legendary_chance := minf(0.008 + level * 0.00025, 0.035)
	var epic_chance := minf(0.04 + level * 0.002, 0.12)
	var rare_chance := minf(0.22 + level * 0.003, 0.38)
	if roll < mythic_chance:
		return &"mythic"
	if roll < mythic_chance + legendary_chance:
		return &"legendary"
	if roll < mythic_chance + legendary_chance + epic_chance:
		return &"epic"
	if roll < mythic_chance + legendary_chance + epic_chance + rare_chance:
		return &"rare"
	return &"common"


func _affix_count_for_rarity(rarity: StringName) -> int:
	return {&"common": 0, &"rare": 1, &"epic": 2, &"legendary": 3, &"mythic": 3}.get(rarity, 0)
