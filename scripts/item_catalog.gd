extends RefCounted
class_name ItemCatalog

## Canonical equipment order. `armor` is accepted only as a compatibility
## alias at the catalog/profile boundary; all new state and UI uses `body`.
const SLOTS: Array[StringName] = [&"weapon", &"head", &"body", &"arm", &"shield", &"accessory"]
const SLOT_LABELS := {
	&"weapon": "WEAPON",
	&"head": "HEAD",
	&"body": "BODY",
	&"arm": "ARM",
	&"shield": "SHIELD",
	&"accessory": "ACCESSORY",
}
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
	&"rare": 0.0,
	&"epic": 0.0,
	&"legendary": 0.0,
	&"mythic": 0.0,
}
const MASTERY_BONUS_PER_LEVEL := 0.10
const OVERFLOW_SALVAGE_RATE := 0.35
const SELL_RATE := 0.25
const PLUS_PACKAGE_THRESHOLDS := {"one": 0.90, "two": 0.97, "three": 0.995}

const PLAIN_GEAR_DROP_WEIGHT := 6.0
const BASIC_GEAR_DROP_WEIGHT := 5.0
const SET_GEAR_DROP_WEIGHT := 0.5
const RANDOM_STAT_KEYS: Array[String] = ["vitality", "strength", "defense", "agi", "intelligence", "mnd"]
const SET_IDS: Array[StringName] = [&"swift", &"soldier", &"guard", &"blood", &"arcane", &"soul", &"edge", &"oath", &"rune"]

## Authoring data loads from resources/definitions/item_catalog.tres so the full
## catalogue (live bases, sets, expansion records, metadata, transmutations) is
## editor-inspectable. Instance fields keep the legacy bare-identifier call sites
## working without a static rewrite.
const DATA_PATH := "res://resources/definitions/item_catalog.tres"

var live_base_ids: Array[StringName] = []
var live_base_definitions: Dictionary = {}
var set_definitions: Dictionary = {}
var definitions: Dictionary = {}
var definition_metadata: Dictionary = {}
var transmutations: Dictionary = {}


func _init() -> void:
	var data := load(DATA_PATH) as ItemCatalogData
	if data == null:
		return
	live_base_ids = data.live_base_ids
	live_base_definitions = data.live_base_definitions
	set_definitions = data.set_definitions
	definitions = data.definitions
	definition_metadata = data.definition_metadata
	transmutations = data.transmutations

static func canonical_slot(slot: Variant) -> StringName:
	var normalized := str(slot).to_lower()
	if normalized == "armor":
		return &"body"
	if normalized in ["weapon", "head", "body", "arm", "shield", "accessory"]:
		return StringName(normalized)
	return &""


func slot_label(slot: Variant) -> String:
	return str(SLOT_LABELS.get(canonical_slot(slot), "ITEM"))


func live_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = live_base_ids.duplicate()
	for set_id: StringName in SET_IDS:
		for slot: StringName in SLOTS:
			result.append(StringName("%s_%s" % [String(set_id), String(slot)]))
	return result


func definition_exists(definition_id: StringName) -> bool:
	return not definition_data(definition_id).is_empty()


func _is_live_set_definition(definition_id: StringName) -> bool:
	var value := String(definition_id)
	for set_id: StringName in SET_IDS:
		if value.begins_with("%s_" % String(set_id)):
			var slot_text := value.substr(String(set_id).length() + 1)
			return canonical_slot(slot_text) in SLOTS
	return false


func _live_set_definition(definition_id: StringName) -> Dictionary:
	var value := String(definition_id)
	for set_id: StringName in SET_IDS:
		var prefix := "%s_" % String(set_id)
		if not value.begins_with(prefix):
			continue
		var slot := canonical_slot(value.substr(prefix.length()))
		var set_records: Dictionary = set_definitions.get(set_id, {})
		var record: Dictionary = set_records.get(slot, {}).duplicate(true)
		if record.is_empty():
			return {}
		record["slot"] = slot
		record["gear_tier"] = "set"
		record["set_id"] = String(set_id)
		record["set_name"] = String(set_id).to_upper()
		record["source_tags"] = ["shop", "chest", "clear_reward", "boss"]
		record["minimum_run_rank"] = 1
		record["minimum_player_level"] = 1
		record["rarity_floor"] = "common"
		record["rarity_ceiling"] = "mythic"
		record["shop_eligible"] = true
		record["family"] = String(set_id)
		record["role_tags"] = [String(set_id), str(record.get("tier_stat", "stat"))]
		record["primary_stat"] = str(record.get("tier_stat", ""))
		record["effects"] = {}
		record["fusion_group"] = String(set_id)
		record["visual_id"] = String(set_id)
		return record
	return {}


func definition_data(definition_id: StringName) -> Dictionary:
	var is_live := live_base_definitions.has(definition_id) or _is_live_set_definition(definition_id)
	var base: Dictionary = live_base_definitions.get(definition_id, {}).duplicate(true) if live_base_definitions.has(definition_id) else _live_set_definition(definition_id)
	if base.is_empty() and definitions.has(definition_id):
		base = definitions.get(definition_id, {}).duplicate(true)
	if base.is_empty():
		return {}
	# Metadata is the authored source of non-stat fields for both the compact
	# live baseline records and the legacy catalogue. Keeping this merge
	# unconditional prevents a live starter alias from silently losing its
	# starter-only/source restrictions.
	var metadata: Dictionary = definition_metadata.get(definition_id, {})
	for key: Variant in metadata:
		base[key] = metadata[key]
	base["slot"] = canonical_slot(base.get("slot", &""))
	if not base.has("primary_stat"):
		base["primary_stat"] = base.get("tier_stat", "")
	if not base.has("family"):
		base["family"] = "unknown"
	if not base.has("role"):
		var role_tags: Array = base.get("role_tags", [])
		base["role"] = str(role_tags[0]) if not role_tags.is_empty() else "stat"
	if not base.has("role_tags"):
		base["role_tags"] = []
	if not base.has("effects"):
		base["effects"] = {}
	if not base.has("base_bonuses"):
		base["base_bonuses"] = base.get("bonuses", {}).duplicate(true)
	if not base.has("tradeoffs"):
		var tradeoffs: Dictionary = {}
		for stat: Variant in base.get("bonuses", {}):
			if float(base["bonuses"][stat]) < 0.0:
				tradeoffs[_normalize_stat_key(str(stat))] = float(base["bonuses"][stat])
		base["tradeoffs"] = tradeoffs
	if not base.has("derived_effects"):
		base["derived_effects"] = base.get("effects", {}).duplicate(true)
	if not base.has("passive_id"):
		base["passive_id"] = ""
	if not base.has("transmutation_pool"):
		base["transmutation_pool"] = transmutations_for_definition(definition_id)
	if not base.has("elemental_behavior"):
		base["elemental_behavior"] = _infer_elemental_behavior(base.get("effects", {}))
	if not base.has("source_tags"):
		base["source_tags"] = ["shop", "chest", "clear_reward", "boss"] if is_live else []
	if not base.has("minimum_run_rank"):
		base["minimum_run_rank"] = 1
	if not base.has("minimum_player_level"):
		base["minimum_player_level"] = 1
	if not base.has("rarity_floor"):
		base["rarity_floor"] = "common"
	if not base.has("rarity_ceiling"):
		base["rarity_ceiling"] = "mythic"
	if not base.has("shop_eligible"):
		base["shop_eligible"] = false
	if not base.has("fusion_group"):
		base["fusion_group"] = str(base.get("family", "unknown"))
	if not base.has("visual_id"):
		base["visual_id"] = str(definition_id)
	if not base.has("description"):
		base["description"] = ""
	base["id"] = String(definition_id)
	if not base.has("gear_tier"):
		base["gear_tier"] = "legacy"
	if not base.has("set_id"):
		base["set_id"] = ""
	if not base.has("set_name"):
		base["set_name"] = ""
	base["display_name"] = str(base.get("name", "UNKNOWN ITEM"))
	base["designer_notes"] = str(base.get("designer_notes", ""))
	base["salvage_policy"] = str(base.get("salvage_policy", "price * %.0f%%" % (OVERFLOW_SALVAGE_RATE * 100.0)))
	base["implementation_status"] = "starter" if bool(base.get("starter_only", false)) else "ready" if definition_is_runtime_ready(definition_id) else "future"
	base["drop_eligible"] = definition_is_runtime_ready(definition_id) and not bool(base.get("starter_only", false))
	base["player_description"] = base.get("description", "")
	return base


func definitions_for_slot(slot: StringName, source_tag: StringName = &"", run_rank: int = 1, player_level: int = 1, include_starter_only := false, include_future_effects := false) -> Array[StringName]:
	var canonical := canonical_slot(slot)
	var result: Array[StringName] = []
	for definition_id: StringName in live_definition_ids():
		if definition_slot(definition_id) != canonical:
			continue
		var definition := definition_data(definition_id)
		if bool(definition.get("starter_only", false)) and not include_starter_only:
			continue
		if not include_future_effects and not definition_is_runtime_ready(definition_id):
			continue
		if not source_tag.is_empty() and not String(source_tag) in definition.get("source_tags", []):
			continue
		if run_rank < int(definition.get("minimum_run_rank", 1)) or player_level < int(definition.get("minimum_player_level", 1)):
			continue
		if source_tag == &"shop" and not bool(definition.get("shop_eligible", false)):
			continue
		result.append(definition_id)
	return result


func select_slot_for_source(profile: PlayerProfile, generation_seed: int, player_level: int = 1, source_tag: StringName = &"", run_rank: int = 1, avoid_slots: Array = []) -> StringName:
	## Deterministic source policy shared by chests and clear rewards. A Head or
	## Arm that is still empty or only has its zero-power starter receives a
	## strong early weight, while the complete six-slot loadout remains eligible.
	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed
	var weights: Array[float] = []
	for slot: StringName in SLOTS:
		var weight := 1.0
		var needs_introduction := slot_needs_introduction(profile, slot) if slot == &"head" or slot == &"arm" else false
		if needs_introduction:
			weight = 8.0
		if definitions_for_slot(slot, source_tag, run_rank, player_level).is_empty():
			weight = 0.0
		elif String(slot) in avoid_slots and not needs_introduction:
			# Clear rewards use the last few slots as a deterministic anti-repeat
			# window. An introduction roll for the new Head/Arm still wins over the
			# avoidance window so early catalogue coverage is not delayed.
			weight = 0.0
		weights.append(weight)
	var available_slots: Array[StringName] = []
	var available_weights: Array[float] = []
	for index in SLOTS.size():
		if weights[index] > 0.0:
			available_slots.append(SLOTS[index])
			available_weights.append(weights[index])
	if available_slots.is_empty():
		return &""
	var selected := _pick_weighted_definition(available_slots, available_weights, rng)
	return selected


func definition_effects(definition_id: StringName) -> Dictionary:
	var definition := definition_data(definition_id)
	return definition.get("effects", {}).duplicate(true)


func definition_is_runtime_ready(definition_id: StringName) -> bool:
	if live_base_definitions.has(definition_id) or _is_live_set_definition(definition_id):
		return true
	if not definitions.has(definition_id):
		return false
	var base: Dictionary = definitions.get(definition_id, {})
	var metadata: Dictionary = definition_metadata.get(definition_id, {})
	var effects: Variant = metadata.get("effects", base.get("effects", {}))
	if not effects is Dictionary:
		return true
	for effect_id: Variant in effects:
		if not effect_is_runtime_active(effects[effect_id]):
			return false
	return true


func effect_is_runtime_active(effect_value: Variant) -> bool:
	if not effect_value is Dictionary:
		return true
	var status := str((effect_value as Dictionary).get("status", "active")).to_lower()
	return status not in ["future", "reserved", "disabled"]


func effect_status(effect_value: Variant) -> String:
	if not effect_value is Dictionary:
		return "active"
	return str((effect_value as Dictionary).get("status", "active"))


func slot_needs_introduction(profile: PlayerProfile, slot: Variant) -> bool:
	var canonical := canonical_slot(slot)
	if canonical.is_empty() or profile == null:
		return true
	var equipped := profile.find_item(profile.get_equipped_instance_id(canonical))
	# Plain pieces are now ordinary chest drops, so "only the zero-power
	# starter" is a tier check rather than a starter-only flag. A slot that is
	# empty, still carries its legacy starter alias, or only has a Plain piece
	# counts as needing introduction.
	if equipped == null:
		return true
	return bool(definition_data(equipped.definition_id).get("starter_only", false)) or str(definition_data(equipped.definition_id).get("gear_tier", "")) == "plain"


func _infer_elemental_behavior(effects: Variant) -> String:
	if not effects is Dictionary:
		return "none"
	var effect_map: Dictionary = effects
	if effect_map.has("imbue_resonance"):
		var resonance: Variant = effect_map["imbue_resonance"]
		if resonance is Dictionary:
			return "imbue_resonance:%s" % str((resonance as Dictionary).get("element", "match"))
		return "imbue_resonance"
	if effect_map.has("elemental_ward"):
		var ward: Variant = effect_map["elemental_ward"]
		if ward is Dictionary:
			return "elemental_ward:%s" % str((ward as Dictionary).get("element", "any"))
		return "elemental_ward"
	return "none"


func _format_effect_line(effect_id: StringName, effect_value: Variant) -> String:
	var values: Dictionary = effect_value if effect_value is Dictionary else {}
	var scalar_value := float(effect_value) if effect_value is float or effect_value is int else 0.0
	match str(effect_id):
		"imbue_resonance":
			var element := str(values.get("element", "active aspect")).to_upper().replace("ACTIVE_ASPECT", "ACTIVE ASPECT")
			var multiplier := float(values.get("magic_multiplier", 0.0))
			return "%s IMBUE: MAGIC +%d%%" % [element, roundi(multiplier * 100.0)]
		"elemental_ward":
			var ward_element := str(values.get("element", "element")).to_upper()
			var ward_multiplier := float(values.get("multiplier", 1.0))
			return "ELEMENTAL WARD %s -%d%% AFTER MATCHUP" % [ward_element, roundi((1.0 - ward_multiplier) * 100.0)]
		"recovery_multiplier":
			return "RECOVERY x%.2f" % float(values.get("multiplier", 1.0))
		"pickup_radius":
			return "PICKUP RADIUS +%d%%" % roundi((float(values.get("multiplier", 1.0)) - 1.0) * 100.0)
		"combo_window":
			return "COMBO WINDOW +%.2fs" % float(values.get("seconds", 0.0))
		"attack_lunge":
			return "ATTACK LUNGE +%d%%" % roundi((float(values.get("multiplier", 1.0)) - 1.0) * 100.0)
		"charge_profile":
			return "CHARGE LUNGE +%d%%" % roundi((float(values.get("lunge_multiplier", 1.0)) - 1.0) * 100.0)
		"running_attack_profile":
			return "RUN ATTACK LUNGE +%d%%" % roundi((float(values.get("lunge_multiplier", 1.0)) - 1.0) * 100.0)
		"spin_profile":
			return "SPIN PROFILE"
		"guard_reduction":
			return "GUARD REDUCTION +%d" % roundi(float(values.get("flat_points", 0.0)))
		"knockback_resistance":
			return "KNOCKBACK RESIST +%d%%" % roundi(float(values.get("multiplier", 0.0)) * 100.0)
		"core_health_rate":
			return "CORE HP +%d%%" % roundi(float(values.get("value", scalar_value)) * 100.0)
		"vit_health_multiplier":
			return "VIT HEALTH +%d%%" % roundi(float(values.get("value", scalar_value)) * 100.0)
		"max_health_rate":
			return "MAX HP +%d%%" % roundi(float(values.get("value", scalar_value)) * 100.0)
		"flat_health":
			return "HP +%d" % roundi(float(values.get("value", scalar_value)))
	return str(effect_id).to_upper().replace("_", " ")


func effect_display_lines(item: ItemInstance, include_future_status := true) -> Array[String]:
	var lines: Array[String] = []
	if item == null:
		return lines
	for effect_id: StringName in effect_ids(item):
		var effect_value: Variant = definition_effects(item.definition_id).get(String(effect_id), null)
		if effect_value == null and not item.transmutation_id.is_empty():
			effect_value = transmutation_effects(item.transmutation_id).get(String(effect_id), null)
		var line := _format_effect_line(effect_id, effect_value)
		if line.is_empty():
			continue
		if include_future_status and not effect_is_runtime_active(effect_value):
			line = "PLANNED: %s" % line
		lines.append(line)
	return lines


func effect_ids(item: ItemInstance) -> Array[StringName]:
	if item == null:
		return []
	var result: Array[StringName] = []
	for effect_id: Variant in definition_effects(item.definition_id):
		result.append(StringName(str(effect_id)))
	if not item.transmutation_id.is_empty():
		for effect_id: Variant in transmutation_effects(item.transmutation_id):
			var id := StringName(str(effect_id))
			if id not in result:
				result.append(id)
	return result


func player_description(item: ItemInstance) -> String:
	if item == null:
		return ""
	return str(definition_data(item.definition_id).get("description", ""))


func source_eligible(definition_id: StringName, source_tag: StringName, run_rank: int, player_level: int) -> bool:
	return definition_id in definitions_for_slot(definition_slot(definition_id), source_tag, run_rank, player_level)


func starter_item(slot: StringName) -> ItemInstance:
	var canonical := canonical_slot(slot)
	var ids := {&"weapon": &"plain_blade", &"head": &"plain_hood", &"body": &"plain_tunic", &"arm": &"plain_wraps", &"shield": &"plain_shield", &"accessory": &"plain_ring"}
	var item := ItemInstance.new()
	if canonical.is_empty():
		return item
	item.instance_id = "starter-armor" if str(slot).to_lower() == "armor" else "starter-%s" % String(canonical)
	item.definition_id = ids[canonical]
	return item


func generate_item(slot: StringName, generation_seed: int, level: int = 1, minimum_rarity: StringName = &"", prefer_non_basic: bool = false, source_tag: StringName = &"", run_rank: int = -1, plus_rarity_scale: float = 1.0) -> ItemInstance:
	var rng := RandomNumberGenerator.new()
	rng.seed = generation_seed
	var candidates: Array[StringName] = []
	var weights: Array[float] = []
	var canonical := canonical_slot(slot)
	var effective_run_rank := level if run_rank < 0 else run_rank
	for definition_id: StringName in definitions_for_slot(canonical, source_tag, effective_run_rank, level):
		if prefer_non_basic and _is_basic_gear(definition_id):
			continue
		candidates.append(definition_id)
		weights.append(_gear_drop_weight(definition_id))
	var item := ItemInstance.new()
	if candidates.is_empty():
		return item
	item.definition_id = _pick_weighted_definition(candidates, weights, rng)
	item.rarity = minimum_rarity if not minimum_rarity.is_empty() else roll_run_rarity(rng.randf(), level)
	item.rarity = _clamp_rarity_to_definition(item.rarity, item.definition_id)
	item.quality = snappedf(rng.randf_range(0.9, 1.1), 0.01)
	item.random_stat_points = _roll_random_stat_points(item.rarity, rng, plus_rarity_scale)
	if item.rarity in [&"epic", &"legendary", &"mythic"] and not _is_live_definition(item.definition_id):
		var available_transmutations := transmutations_for_definition(item.definition_id)
		if not available_transmutations.is_empty():
			var eligible: Array[StringName] = []
			for transmutation_id: StringName in available_transmutations:
				var min_rarity := StringName(transmutations[transmutation_id].get("min_rarity", &"epic"))
				if _rarity_rank(item.rarity) >= _rarity_rank(min_rarity):
					eligible.append(transmutation_id)
			if not eligible.is_empty():
				item.transmutation_id = eligible[rng.randi_range(0, eligible.size() - 1)]
	return item


func _rarity_rank(rarity: StringName) -> int:
	return {&"common": 0, &"rare": 1, &"epic": 2, &"legendary": 3, &"mythic": 4}.get(rarity, 0)


func _clamp_rarity_to_definition(rarity: StringName, definition_id: StringName) -> StringName:
	var definition := definition_data(definition_id)
	if definition.is_empty():
		return rarity
	var rank := clampi(_rarity_rank(rarity), _rarity_rank(StringName(str(definition.get("rarity_floor", "common")))), _rarity_rank(StringName(str(definition.get("rarity_ceiling", "mythic")))))
	var ladder: Array[StringName] = [&"common", &"rare", &"epic", &"legendary", &"mythic"]
	return ladder[rank]


func _is_basic_gear(definition_id: StringName) -> bool:
	var tier := str(definition_data(definition_id).get("gear_tier", "legacy"))
	return tier == "plain" or tier == "basic"


func _is_live_definition(definition_id: StringName) -> bool:
	return live_base_definitions.has(definition_id) or _is_live_set_definition(definition_id)


func _gear_drop_weight(definition_id: StringName) -> float:
	var tier := str(definition_data(definition_id).get("gear_tier", "legacy"))
	match tier:
		"plain": return PLAIN_GEAR_DROP_WEIGHT
		"basic": return BASIC_GEAR_DROP_WEIGHT
		"set": return SET_GEAR_DROP_WEIGHT
	return 0.0


func _roll_random_stat_points(_rarity: StringName, rng: RandomNumberGenerator, plus_rarity_scale: float = 1.0) -> Dictionary:
	var roll := rng.randf()
	var plus_count := 0
	if roll >= float(PLUS_PACKAGE_THRESHOLDS["one"]):
		plus_count = 1
		if roll >= float(PLUS_PACKAGE_THRESHOLDS["two"]):
			plus_count = 2
		if roll >= float(PLUS_PACKAGE_THRESHOLDS["three"]):
			plus_count = 3
	# Special sources (for example the Cloaked Demon's premium slot) may pass a
	# scale below 1.0 to make + gear genuinely rare instead of the default
	# distribution. Rolling a fresh uniform threshold keeps the distribution
	# stable when the source is the normal loot path.
	if plus_rarity_scale < 1.0 and plus_count > 0:
		plus_count = rng.randi_range(0, plus_count) if rng.randf() >= plus_rarity_scale else plus_count
	var result: Dictionary = {}
	for _roll_index in plus_count:
		var stat := RANDOM_STAT_KEYS[rng.randi_range(0, RANDOM_STAT_KEYS.size() - 1)]
		result[stat] = int(result.get(stat, 0)) + 1
	return result


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
	for transmutation_id: StringName in transmutations:
		var definition: Dictionary = transmutations[transmutation_id]
		if definition_id in definition.get("definitions", []):
			result.append(transmutation_id)
	return result


func transmutation_is_eligible(definition_id: StringName, transmutation_id: StringName, rarity: StringName) -> bool:
	var transmutation: Dictionary = transmutations.get(transmutation_id, {})
	if transmutation.is_empty() or definition_id not in transmutation.get("definitions", []):
		return false
	var minimum_rarity := StringName(str(transmutation.get("min_rarity", "common")))
	return _rarity_rank(rarity) >= _rarity_rank(minimum_rarity)


func transmutation_name(transmutation_id: StringName) -> String:
	return str(transmutations.get(transmutation_id, {}).get("name", ""))


func transmutation_description(transmutation_id: StringName) -> String:
	return str(transmutations.get(transmutation_id, {}).get("description", ""))


func transmutation_effects(transmutation_id: StringName) -> Dictionary:
	return transmutations.get(transmutation_id, {}).get("effects", {}).duplicate(true)


func rarity_color(rarity: StringName) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

func rarity_stat_rate(_rarity: StringName) -> float:
	# Kept as a compatibility seam for old callers. The reworked model is flat;
	# rarity and fusion growth are folded into bonuses() instead of multiplying
	# the player's complete stat sheet.
	return 0.0

func rarity_flat_points(rarity: StringName) -> int:
	return _rarity_rank(rarity) * RARITY_FLAT_POINTS_PER_RANK

func enhancement_flat_points(enhancement_level: int) -> float:
	var level := clampi(enhancement_level, 0, PlayerProfile.MAX_ITEM_ENHANCEMENT)
	return float(level) * MASTERY_BONUS_PER_LEVEL

func rarity_letter_grade(rarity: StringName) -> String:
	return {&"common": "C", &"rare": "R", &"epic": "E", &"legendary": "L", &"mythic": "M"}.get(rarity, "C")

static func next_rarity(rarity: StringName) -> StringName:
	return {&"common": &"rare", &"rare": &"epic", &"epic": &"legendary", &"legendary": &"mythic", &"mythic": &""}.get(rarity, &"")


func definition_slot(definition_id: StringName) -> StringName:
	return canonical_slot(definition_data(definition_id).get("slot", &""))


func random_plus_count(item: ItemInstance) -> int:
	if item == null:
		return 0
	var count := 0
	for value: Variant in item.random_stat_points.values():
		count += maxi(int(value), 0)
	return count


func plus_marker(item: ItemInstance) -> String:
	var count := mini(random_plus_count(item), 3)
	var marker := ""
	for _index in count:
		marker += "+"
	return marker


func gear_name(item: ItemInstance) -> String:
	if item == null:
		return "UNKNOWN ITEM"
	var definition: Dictionary = definition_data(item.definition_id)
	var name := str(definition.get("name", "UNKNOWN ITEM"))
	var marker := plus_marker(item)
	return "%s %s" % [name, marker] if not marker.is_empty() else name


func random_stat_text(item: ItemInstance) -> String:
	if item == null or random_plus_count(item) <= 0:
		return ""
	var labels := {"vitality": "VIT", "strength": "STR", "defense": "DEF", "agi": "AGI", "intelligence": "INT", "mnd": "MND"}
	var parts: Array[String] = []
	for stat: String in RANDOM_STAT_KEYS:
		var points := maxi(int(item.random_stat_points.get(stat, 0)), 0)
		if points > 0:
			parts.append("%s +%d" % [labels[stat], points])
	return "RANDOM %s" % " ".join(parts) if not parts.is_empty() else ""


func display_name(item: ItemInstance) -> String:
	if item == null:
		return "UNKNOWN ITEM"
	return "%s %s" % [RARITY_NAMES.get(item.rarity, "COMMON"), gear_name(item)]


func player_stat_rates(_item: ItemInstance) -> Dictionary:
	# The old percentage-affix API remains readable by callers, but the new gear
	# system intentionally has no hidden player-stat multipliers.
	return {}

func player_stat_rate_text(_item: ItemInstance) -> String:
	return ""


func bonuses(item: ItemInstance, _mastery_level: int = 0) -> Dictionary:
	if item == null:
		return {}
	var definition: Dictionary = definition_data(item.definition_id)
	var result: Dictionary = {}
	var base_bonuses: Dictionary = definition.get("bonuses", {}).duplicate(true)
	var rarity_points := float(rarity_flat_points(item.rarity))
	# Enhancement is measured on the current rarity track only. `enhancement_level`
	# is the visible +0..+10 position and resets to 0 on promotion; the rarity
	# rank already carries the accumulated value across the jump. `fusion_stat_points`
	# is the monotonic total across promotions and must not be re-added here, or a
	# promoted item would receive its prior-track levels twice.
	var fusion_enhancement_points := enhancement_flat_points(item.enhancement_level)
	var tier_stat := _normalize_stat_key(str(definition.get("tier_stat", "")))
	# The primary `tier_stat` scales with rarity/enhancement. `tier_stats`
	# lists additional stats that scale alongside it (premium dual-lane items).
	var scaled_stats: Array = []
	for raw_stat: Variant in definition.get("tier_stats", []):
		scaled_stats.append(_normalize_stat_key(str(raw_stat)))
	if tier_stat.is_empty():
		pass
	elif scaled_stats.is_empty():
		scaled_stats.append(tier_stat)
	elif tier_stat not in scaled_stats:
		scaled_stats.append(tier_stat)
	var random_points: Dictionary = item.random_stat_points if item.random_stat_points is Dictionary else {}
	var stat_keys: Array[String] = []
	for stat: Variant in base_bonuses.keys():
		var normalized := _normalize_stat_key(str(stat))
		if normalized not in ["health_rate", "damage_rate"] and normalized not in stat_keys:
			stat_keys.append(normalized)
	for stat: Variant in random_points.keys():
		var normalized := _normalize_stat_key(str(stat))
		if normalized in RANDOM_STAT_KEYS and normalized not in stat_keys:
			stat_keys.append(normalized)
	for normalized_stat: String in stat_keys:
		var authored_value := float(base_bonuses.get(normalized_stat, base_bonuses.get(_legacy_stat_key(normalized_stat), 0.0)))
		var random_value := maxi(int(random_points.get(normalized_stat, 0)), 0)
		var flat_value := authored_value + float(random_value)
		if normalized_stat in scaled_stats:
			flat_value += rarity_points
			if normalized_stat == tier_stat:
				flat_value += fusion_enhancement_points
		if random_value > 1:
			flat_value += float(random_value - 1) * float(_rarity_rank(item.rarity))
		# A random lane is a real stat lane: it grows at the same additive pace as
		# the authored primary, even when its roll lands on a secondary stat.
		if random_value > 0 and normalized_stat not in scaled_stats:
			flat_value += rarity_points + fusion_enhancement_points
		result[normalized_stat] = flat_value
		if normalized_stat == "agi":
			result["speed"] = flat_value
	return result


static func _legacy_stat_key(normalized_stat: String) -> String:
	return {"agi": "agility", "intelligence": "int", "mnd": "mind"}.get(normalized_stat, normalized_stat)


func combat_primary_points(item: ItemInstance) -> Dictionary:
	var result: Dictionary = {}
	var displayed_bonuses := bonuses(item)
	for stat in ["strength", "vitality", "defense", "agi", "intelligence", "mnd"]:
		if displayed_bonuses.has(stat):
			result[stat] = float(displayed_bonuses[stat])
	if displayed_bonuses.has("agi"):
		result["speed"] = float(displayed_bonuses["agi"])
	return result


func stat_allocation_total(item: ItemInstance) -> float:
	## Fusion ordering uses the six authored primary stat lanes. `combat_primary_points`
	## also exposes derived speed as an AGI alias for combat callers, so sum the
	## canonical lanes explicitly to avoid counting AGI twice.
	var primary := combat_primary_points(item)
	var total := 0.0
	for stat in ["strength", "vitality", "defense", "agi", "intelligence", "mnd"]:
		total += float(primary.get(stat, 0.0))
	return total


static func _normalize_stat_key(stat: String) -> String:
	return {
		"speed": "agi",
		"agility": "agi",
		"int": "intelligence",
		"mind": "mnd",
	}.get(stat, stat)


func shield_bonuses(item: ItemInstance) -> Dictionary:
	if item == null or definition_slot(item.definition_id) != &"shield":
		return {}
	var definition: Dictionary = definition_data(item.definition_id)
	var shield_values: Dictionary = definition.get("shield", {})
	var enhancement_factor := 1.0 + MASTERY_BONUS_PER_LEVEL * float(clampi(item.enhancement_level, 0, PlayerProfile.MAX_ITEM_ENHANCEMENT))
	var result: Dictionary = {}
	for stat: String in shield_values:
		# Guard values are the shield's simple fixed package. Fusion may improve
		# them with the same small additive enhancement factor, but rarity adds no
		# hidden percentage multiplier.
		var mastery_multiplier := enhancement_factor if stat in ["guard_durability", "guard_reduction"] else 1.0
		result[stat] = float(shield_values[stat]) * mastery_multiplier
	return result


func price(item: ItemInstance) -> int:
	var base := int(definition_data(item.definition_id).get("price", 50))
	var multiplier: float = float({&"common": 1.0, &"rare": 2.2, &"epic": 4.84, &"legendary": 10.65, &"mythic": 23.43}.get(item.rarity, 1.0))
	# The + package and enhancement are the real investment in a piece of gear.
	# A single + is a meaningful surcharge; ++ and +++ escalate steeply so an
	# enhanced drop or shop find reads as a genuinely premium purchase.
	var plus_count := mini(random_plus_count(item), 3)
	var plus_multiplier := 1.0 + float(plus_count) * (1.6 if plus_count <= 1 else 2.2 if plus_count == 2 else 3.4)
	var enhancement := clampi(item.enhancement_level, 0, PlayerProfile.MAX_ITEM_ENHANCEMENT)
	var enhancement_multiplier := 1.0 + float(enhancement) * 0.22
	return maxi(1, roundi(base * multiplier * plus_multiplier * enhancement_multiplier * item.quality))


func overflow_salvage_value(item: ItemInstance) -> int:
	return maxi(1, roundi(price(item) * OVERFLOW_SALVAGE_RATE))


func sell_value(item: ItemInstance) -> int:
	return maxi(1, roundi(price(item) * SELL_RATE))


func sell_soul_value(item: ItemInstance) -> int:
	if item == null or (item.fusion_count <= 0 and item.enhancement_level <= 0):
		return 0
	var invested := item.fusion_souls_invested
	if invested <= 0:
		# Compatibility for enhanced items saved before the investment ledger was
		# introduced. Their current rarity/enhancement reconstructs the minimum
		# known investment without inventing promoted-rarity history.
		var rarity_rank: int = int({&"common": 0, &"rare": 1, &"epic": 2, &"legendary": 3, &"mythic": 4}.get(item.rarity, 0))
		for enhancement in item.enhancement_level:
			invested += PlayerProfile.FUSION_START_COST + rarity_rank * PlayerProfile.FUSION_RARITY_STEP_COST + enhancement
	return floori(float(invested) * 0.5)


func roll_run_rarity(roll: float, rank: int, performance_bonus: float = 0.0, rarity_multipliers: Array = []) -> StringName:
	var band_index := mini(maxi(floori(float(maxi(rank, 1) - 1) / 10.0), 0), 5)
	var band_progress := 0.0 if band_index == 0 else float((maxi(rank, 1) - 1) % 10) / 10.0
	var rates: Array = [[0.12, 0.0075, 0.001, 0.00005], [0.12, 0.0125, 0.0015, 0.0001], [0.12, 0.0175, 0.003, 0.0002], [0.12, 0.025, 0.005, 0.0005], [0.12, 0.0325, 0.008, 0.001], [0.12, 0.04, 0.012, 0.002]]
	var current: Array = rates[band_index]
	var next: Array = rates[mini(band_index + 1, 5)]
	var rare_chance := lerpf(float(current[0]), float(next[0]), band_progress)
	var epic_chance := lerpf(float(current[1]), float(next[1]), band_progress)
	var legendary_chance := lerpf(float(current[2]), float(next[2]), band_progress)
	var mythic_chance := lerpf(float(current[3]), float(next[3]), band_progress)
	if rarity_multipliers.size() >= 4:
		rare_chance *= clampf(float(rarity_multipliers[0]), 0.0, 1.0)
		epic_chance *= clampf(float(rarity_multipliers[1]), 0.0, 1.0)
		legendary_chance *= clampf(float(rarity_multipliers[2]), 0.0, 1.0)
		mythic_chance *= clampf(float(rarity_multipliers[3]), 0.0, 1.0)
	# Quality is intentionally bounded to the current rank band.
	var quality_shift := clampf(performance_bonus * 0.001, -0.002, 0.002)
	epic_chance = maxf(0.0, epic_chance + quality_shift)
	legendary_chance = maxf(0.0, legendary_chance + quality_shift * 0.35)
	mythic_chance = maxf(0.0, mythic_chance + quality_shift * 0.1)
	if roll < mythic_chance: return &"mythic"
	if roll < mythic_chance + legendary_chance: return &"legendary"
	if roll < mythic_chance + legendary_chance + epic_chance: return &"epic"
	if roll < mythic_chance + legendary_chance + epic_chance + rare_chance: return &"rare"
	return &"common"
