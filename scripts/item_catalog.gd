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
	&"rare": 0.05,
	&"epic": 0.15,
	&"legendary": 0.45,
	&"mythic": 0.80,
}
const MASTERY_BONUS_PER_LEVEL := 0.10
const OVERFLOW_SALVAGE_RATE := 0.35

const BASIC_GEAR_DROP_WEIGHT := 5.0

const DEFINITIONS := {
	# Weapon — the original six bases plus the approved expansion identities.
	&"basic_sword": {"name": "BASIC SWORD", "slot": &"weapon", "tier_stat": "strength", "bonuses": {"strength": 2.0}, "price": 45},
	&"soldier_sword": {"name": "SOLDIER SWORD", "slot": &"weapon", "tier_stat": "strength", "bonuses": {"strength": 3.0, "agility": -1.0}, "price": 90},
	&"guardian_blade": {"name": "GUARDIAN BLADE", "slot": &"weapon", "tier_stat": "defense", "bonuses": {"defense": 2.0, "agility": -1.0}, "price": 95},
	&"blood_blade": {"name": "BLOOD BLADE", "slot": &"weapon", "tier_stat": "vitality", "bonuses": {"vitality": 2.0, "agility": -1.0}, "price": 115},
	&"iron_maul": {"name": "IRON MAUL", "slot": &"weapon", "tier_stat": "strength", "bonuses": {"strength": 2.0, "agility": -1.0}, "price": 105},
	&"quick_dagger": {"name": "QUICK DAGGER", "slot": &"weapon", "tier_stat": "agility", "bonuses": {"agility": 3.0}, "price": 75},
	&"emberbrand": {"name": "EMBERBRAND", "slot": &"weapon", "tier_stat": "strength", "bonuses": {"strength": 3.0, "agility": -1.0}, "price": 135},
	&"tideglass_rapier": {"name": "TIDEGLASS RAPIER", "slot": &"weapon", "tier_stat": "agility", "bonuses": {"agility": 2.0, "intelligence": 1.0}, "price": 140},
	&"rootbreaker": {"name": "ROOTBREAKER", "slot": &"weapon", "tier_stat": "strength", "bonuses": {"strength": 2.0, "defense": 1.0, "agility": -1.0}, "price": 145},
	&"mindweave_rod": {"name": "MINDWEAVE ROD", "slot": &"weapon", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "mnd": 1.0}, "price": 140},

	# Head — `plain_hood` is intentionally the only zero-power exception.
	&"plain_hood": {"name": "PLAIN HOOD", "slot": &"head", "tier_stat": "", "bonuses": {}, "price": 1},
	&"iron_helm": {"name": "IRON HELM", "slot": &"head", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 1.0, "agility": -1.0}, "price": 115},
	&"feather_cap": {"name": "FEATHER CAP", "slot": &"head", "tier_stat": "agility", "bonuses": {"agility": 2.0, "mnd": 1.0}, "price": 100},
	&"mind_circlet": {"name": "MIND CIRCLET", "slot": &"head", "tier_stat": "mnd", "bonuses": {"mnd": 2.0, "intelligence": 1.0}, "price": 125},
	&"ember_crown": {"name": "EMBER CROWN", "slot": &"head", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "mnd": 1.0}, "price": 145},
	&"shadow_mask": {"name": "SHADOW MASK", "slot": &"head", "tier_stat": "agility", "bonuses": {"agility": 2.0, "mnd": 1.0}, "price": 135},

	# Body — these entries retain their old IDs; their slot is now canonical.
	&"basic_tunic": {"name": "BASIC TUNIC", "slot": &"body", "tier_stat": "vitality", "bonuses": {"vitality": 1.0, "defense": 1.0}, "price": 45},
	&"bloodwoven_tunic": {"name": "BLOODWOVEN TUNIC", "slot": &"body", "tier_stat": "vitality", "bonuses": {"vitality": 2.0, "agility": 1.0}, "price": 110},
	&"iron_cuirass": {"name": "IRON CUIRASS", "slot": &"body", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 1.0, "agility": -1.0}, "price": 105},
	&"feather_cloak": {"name": "FEATHER CLOAK", "slot": &"body", "tier_stat": "agility", "bonuses": {"agility": 3.0}, "price": 80},
	&"mindweave_robe": {"name": "MINDWEAVE ROBE", "slot": &"body", "tier_stat": "mnd", "bonuses": {"mnd": 2.0, "intelligence": 1.0}, "price": 125},
	&"chainmail": {"name": "CHAINMAIL", "slot": &"body", "tier_stat": "vitality", "bonuses": {"vitality": 2.0, "defense": 1.0}, "price": 95},
	&"ash_mantle": {"name": "ASH MANTLE", "slot": &"body", "tier_stat": "mnd", "bonuses": {"mnd": 2.0, "intelligence": 1.0}, "price": 140},
	&"rootplate": {"name": "ROOTPLATE", "slot": &"body", "tier_stat": "defense", "bonuses": {"defense": 3.0, "vitality": 1.0, "agility": -1.0}, "price": 150},
	&"demon_cloak": {"name": "DEMON CLOAK", "slot": &"body", "tier_stat": "agility", "tier_stats": ["defense"], "bonuses": {"defense": 3.0, "vitality": 2.0, "mnd": 2.0, "agility": 4.0}, "price": 200},

	# Arm — the second new slot is action-facing, not a second accessory.
	&"cloth_wraps": {"name": "CLOTH WRAPS", "slot": &"arm", "tier_stat": "", "bonuses": {}, "price": 1},
	&"iron_gauntlets": {"name": "IRON GAUNTLETS", "slot": &"arm", "tier_stat": "strength", "bonuses": {"strength": 2.0, "agility": -1.0}, "price": 115},
	&"duelist_gloves": {"name": "DUELIST GLOVES", "slot": &"arm", "tier_stat": "agility", "bonuses": {"agility": 2.0, "strength": 1.0}, "price": 125},
	&"sage_sleeves": {"name": "SAGE SLEEVES", "slot": &"arm", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "mnd": 1.0}, "price": 130},
	&"guard_bracers": {"name": "GUARD BRACERS", "slot": &"arm", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 1.0}, "price": 120},
	&"thorn_claws": {"name": "THORN CLAWS", "slot": &"arm", "tier_stat": "strength", "bonuses": {"strength": 2.0, "defense": 1.0}, "price": 135},

	# Shield — guard data stays in the dedicated shield package.
	&"basic_shield": {"name": "BASIC SHIELD", "slot": &"shield", "tier_stat": "defense", "bonuses": {"vitality": 1.0, "agility": -1.0, "defense": 2.0}, "shield": {"guard_durability": 2.0, "guard_reduction": 1.0}, "price": 45},
	&"living_bulwark": {"name": "LIVING BULWARK", "slot": &"shield", "tier_stat": "defense", "bonuses": {"vitality": 1.0, "agility": -2.0, "defense": 3.0}, "shield": {"guard_durability": 4.0, "guard_reduction": 3.0}, "price": 110},
	&"thorn_guard": {"name": "THORN GUARD", "slot": &"shield", "tier_stat": "vitality", "bonuses": {"vitality": 2.0, "agility": -1.0, "defense": 2.0}, "shield": {"guard_durability": 3.0, "guard_reduction": 2.0}, "price": 105},
	&"parry_buckler": {"name": "PARRY BUCKLER", "slot": &"shield", "tier_stat": "defense", "bonuses": {"vitality": 1.0, "defense": 2.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0}, "price": 50},
	&"mirror_ward": {"name": "MIRROR WARD", "slot": &"shield", "tier_stat": "mnd", "bonuses": {"mnd": 2.0, "defense": 1.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0}, "price": 140},
	&"frostwall": {"name": "FROSTWALL", "slot": &"shield", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 1.0, "agility": -1.0}, "shield": {"guard_durability": 3.0, "guard_reduction": 2.0}, "price": 145},

	# Accessory — one flexible slot, with no direct currency multiplier.
	&"bangle": {"name": "BANGLE", "slot": &"accessory", "tier_stat": "strength", "bonuses": {"strength": 1.0, "vitality": 1.0, "agility": 1.0}, "price": 45},
	&"duelist_seal": {"name": "DUELIST SEAL", "slot": &"accessory", "tier_stat": "strength", "bonuses": {"strength": 2.0, "agility": -1.0}, "price": 105},
	&"warrior_charm": {"name": "WARRIOR CHARM", "slot": &"accessory", "tier_stat": "strength", "bonuses": {"strength": 2.0, "defense": 1.0, "agility": -1.0}, "price": 100},
	&"swift_boots": {"name": "SWIFT BOOTS", "slot": &"accessory", "tier_stat": "agility", "bonuses": {"agility": 3.0}, "price": 85},
	&"chroma_talisman": {"name": "CHROMA TALISMAN", "slot": &"accessory", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "mnd": 1.0}, "price": 125},
	&"soul_locket": {"name": "SOUL LOCKET", "slot": &"accessory", "tier_stat": "mnd", "bonuses": {"mnd": 2.0, "vitality": 1.0}, "price": 120},
	&"runebound_knot": {"name": "RUNEBOUND KNOT", "slot": &"accessory", "tier_stat": "agility", "bonuses": {"agility": 2.0, "intelligence": 1.0}, "price": 135},
	&"elemental_knot": {"name": "ELEMENTAL KNOT", "slot": &"accessory", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "mnd": 1.0}, "price": 145},
}

## Non-stat definition data is kept beside the compact legacy records above so
## old callers can continue reading `DEFINITIONS` while new systems consume a
## complete authored record through `definition_data()`.
const DEFINITION_METADATA := {
	&"basic_sword": {"family": "blade", "role_tags": ["physical", "baseline"], "primary_stat": "strength", "effects": {}, "source_tags": ["starter", "shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "blade", "visual_id": "sword", "description": "A dependable blade with no trick."},
	&"soldier_sword": {"family": "blade", "role_tags": ["physical", "multi_target"], "primary_stat": "strength", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "blade", "visual_id": "sword", "description": "Attack 1 against several targets improves the same-target share of Attack 2."},
	&"guardian_blade": {"family": "blade", "role_tags": ["physical", "defense"], "primary_stat": "defense", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "blade", "visual_id": "sword", "description": "A defensive blade that turns DEF into a deliberate offensive choice."},
	&"blood_blade": {"family": "blade", "role_tags": ["physical", "health_risk"], "primary_stat": "vitality", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "blade", "visual_id": "sword", "description": "Damage dealt can return a bounded portion of the hit as health."},
	&"iron_maul": {"family": "maul", "role_tags": ["physical", "charge"], "primary_stat": "strength", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "maul", "visual_id": "maul", "description": "A heavy weapon whose committed timing is the price of its force."},
	&"quick_dagger": {"family": "dagger", "role_tags": ["physical", "mobility"], "primary_stat": "agility", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "dagger", "visual_id": "dagger", "description": "A light blade for movement, running attacks, and follow-ups."},
	&"emberbrand": {"family": "blade", "role_tags": ["physical", "fire", "imbue"], "primary_stat": "strength", "effects": {"imbue_resonance": {"element": "fire", "magic_multiplier": 0.08, "mode": "matching_imbue", "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 2, "minimum_player_level": 5, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "blade", "visual_id": "sword_fire", "description": "Matching Fire Imbue strengthens its magic portion without changing the demon's aspect."},
	&"tideglass_rapier": {"family": "dagger_blade", "role_tags": ["physical", "water", "imbue", "mobility"], "primary_stat": "agility", "effects": {"imbue_resonance": {"element": "water", "magic_multiplier": 0.08, "mode": "matching_imbue", "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 2, "minimum_player_level": 5, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "dagger", "visual_id": "rapier_water", "description": "A mobile precision blade for a matching Water Imbue."},
	&"rootbreaker": {"family": "maul", "role_tags": ["physical", "charge", "knockback"], "primary_stat": "strength", "effects": {"charge_profile": {"lunge_multiplier": 1.10, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 3, "minimum_player_level": 8, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "maul", "visual_id": "maul_root", "description": "A grounded maul for charged openings, lunge control, and knockback decisions."},
	&"mindweave_rod": {"family": "focus_rod", "role_tags": ["magic", "mnd", "imbue"], "primary_stat": "intelligence", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "focus", "visual_id": "rod", "description": "Strengthens Triangle and Imbue magic while leaving the physical STR portion intact."},

	&"plain_hood": {"family": "cloth", "role_tags": ["starter", "zero_power"], "primary_stat": "", "effects": {}, "starter_only": true, "source_tags": ["starter"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "common", "shop_eligible": false, "fusion_group": "starter", "visual_id": "hood", "description": "Fills the Head slot without changing combat power."},
	&"iron_helm": {"family": "helm", "role_tags": ["defense", "heavy"], "primary_stat": "defense", "effects": {"recovery_multiplier": {"multiplier": 1.05, "status": "future"}}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "helm", "visual_id": "helm", "description": "Heavy protection with a visible recovery tradeoff."},
	&"feather_cap": {"family": "light_headgear", "role_tags": ["agility", "magic_defense", "light"], "primary_stat": "agility", "effects": {"recovery_multiplier": {"multiplier": 0.95, "status": "future"}}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "head", "visual_id": "cap", "description": "Light headgear for staying active through clean movement and recovery."},
	&"mind_circlet": {"family": "circlet", "role_tags": ["mnd", "magic", "defense"], "primary_stat": "mnd", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "circlet", "visual_id": "circlet", "description": "Raises M.DEF through MND and supports the magic side of the kit."},
	&"ember_crown": {"family": "elemental_crown", "role_tags": ["intelligence", "fire", "ward"], "primary_stat": "intelligence", "effects": {"elemental_ward": {"element": "fire", "multiplier": 0.90, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 3, "minimum_player_level": 8, "rarity_floor": "epic", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "crown", "visual_id": "crown_fire", "description": "Reduces Fire pressure after the shared elemental matchup step."},
	&"shadow_mask": {"family": "mask", "role_tags": ["agility", "shadow", "ward"], "primary_stat": "agility", "effects": {"elemental_ward": {"element": "shadow", "multiplier": 0.90, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 3, "minimum_player_level": 8, "rarity_floor": "epic", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "mask", "visual_id": "mask_shadow", "description": "Adds Shadow protection without changing the demon's own element."},

	&"basic_tunic": {"family": "tunic", "role_tags": ["vitality", "defense", "baseline"], "primary_stat": "vitality", "effects": {}, "source_tags": ["starter", "shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "tunic", "visual_id": "tunic", "description": "A plain survival baseline for learning rooms and building VIT."},
	&"bloodwoven_tunic": {"family": "tunic", "role_tags": ["vitality", "health_risk"], "primary_stat": "vitality", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "tunic", "visual_id": "tunic_blood", "description": "Core HP and VIT make health-risk choices more forgiving."},
	&"iron_cuirass": {"family": "heavy_armor", "role_tags": ["defense", "vitality", "heavy"], "primary_stat": "defense", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "heavy_armor", "visual_id": "cuirass", "description": "Reliable physical protection that gives up some mobility."},
	&"feather_cloak": {"family": "cloak", "role_tags": ["agility", "light"], "primary_stat": "agility", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "cloak", "visual_id": "cloak", "description": "A mobile body layer for surviving through repositioning."},
	&"mindweave_robe": {"family": "robe", "role_tags": ["mnd", "magic", "defense"], "primary_stat": "mnd", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "robe", "visual_id": "robe", "description": "A magic-defense body layer that supports M.DEF and Triangle."},
	&"chainmail": {"family": "mail", "role_tags": ["vitality", "defense", "balanced"], "primary_stat": "vitality", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "mail", "visual_id": "chainmail", "description": "A dependable middle path with no sharp action requirement."},
	&"ash_mantle": {"family": "mantle", "role_tags": ["mnd", "fire", "imbue"], "primary_stat": "mnd", "effects": {"imbue_resonance": {"element": "fire", "magic_multiplier": 0.06, "mode": "matching_imbue", "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 2, "minimum_player_level": 5, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "mantle", "visual_id": "mantle_ash", "description": "A Fire-attuned layer that improves matching Imbue without assigning Fire to the demon."},
	&"rootplate": {"family": "heavy_plate", "role_tags": ["defense", "vitality", "knockback", "heavy"], "primary_stat": "defense", "effects": {"knockback_resistance": {"multiplier": 0.15, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 3, "minimum_player_level": 8, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "plate", "visual_id": "plate_root", "description": "Holds ground against forceful enemies at a clear mobility cost."},
	&"demon_cloak": {"family": "cloak", "role_tags": ["agility", "defense", "vitality", "mnd", "premium", "dual_slot"], "primary_stat": "agility", "effects": {}, "source_tags": ["cloaked_demon"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "cloak", "visual_id": "cloak_demon", "description": "A living cloak from the Cloaked Demon. It wears over Body and Head together, and only he sells it — each one costs more than the last."},

	&"cloth_wraps": {"family": "wraps", "role_tags": ["starter", "zero_power"], "primary_stat": "", "effects": {}, "starter_only": true, "source_tags": ["starter"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "common", "shop_eligible": false, "fusion_group": "starter", "visual_id": "wraps", "description": "Fills the Arm slot without adding free combat power."},
	&"iron_gauntlets": {"family": "gauntlets", "role_tags": ["strength", "charge", "heavy"], "primary_stat": "strength", "effects": {"charge_profile": {"lunge_multiplier": 1.08, "status": "future"}}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "gauntlets", "visual_id": "gauntlets", "description": "Put weight behind charged attacks and accept a handling cost."},
	&"duelist_gloves": {"family": "gloves", "role_tags": ["agility", "attack_two", "recovery"], "primary_stat": "agility", "effects": {"running_attack_profile": {"lunge_multiplier": 1.06, "status": "future"}}, "source_tags": ["chest", "clear_reward"], "minimum_run_rank": 2, "minimum_player_level": 5, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "gloves", "visual_id": "gloves", "description": "Reward the timing between a roll, a run, and the next attack without awarding Style."},
	&"sage_sleeves": {"family": "sleeves", "role_tags": ["intelligence", "mnd", "magic"], "primary_stat": "intelligence", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "sleeves", "visual_id": "sleeves", "description": "Strengthen Triangle and the magic portion of Imbue."},
	&"guard_bracers": {"family": "bracers", "role_tags": ["defense", "guard", "vitality"], "primary_stat": "defense", "effects": {"guard_reduction": {"flat_points": 1.0, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 2, "minimum_player_level": 5, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "bracers", "visual_id": "bracers", "description": "Make active blocking matter without replacing the Shield slot."},
	&"thorn_claws": {"family": "claws", "role_tags": ["strength", "defense", "knockback"], "primary_stat": "strength", "effects": {"attack_lunge": {"multiplier": 1.06, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 3, "minimum_player_level": 8, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "claws", "visual_id": "claws", "description": "Turn committed contact and knockback into a close-range decision."},

	&"basic_shield": {"family": "shield", "role_tags": ["defense", "guard", "baseline"], "primary_stat": "defense", "effects": {}, "source_tags": ["starter", "shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "shield", "visual_id": "shield", "description": "Teaches the core block contract with a readable guard package."},
	&"living_bulwark": {"family": "bulwark", "role_tags": ["defense", "guard", "heavy"], "primary_stat": "defense", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "bulwark", "visual_id": "bulwark", "description": "Converts DEF and successful blocks into a stronger Attack 2 opening."},
	&"thorn_guard": {"family": "thorn_shield", "role_tags": ["vitality", "defense", "counter"], "primary_stat": "vitality", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "thorn_shield", "visual_id": "shield_thorn", "description": "Absorb pressure and choose when to answer."},
	&"parry_buckler": {"family": "buckler", "role_tags": ["defense", "guard", "recovery"], "primary_stat": "defense", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "buckler", "visual_id": "buckler", "description": "Trade durability for a lighter, more responsive block rhythm."},
	&"mirror_ward": {"family": "ward_shield", "role_tags": ["mnd", "defense", "water", "ward"], "primary_stat": "mnd", "effects": {"elemental_ward": {"element": "water", "multiplier": 0.90, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 3, "minimum_player_level": 8, "rarity_floor": "epic", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "ward_shield", "visual_id": "shield_mirror", "description": "Protect against Water pressure after the shared matchup step."},
	&"frostwall": {"family": "heavy_shield", "role_tags": ["defense", "vitality", "ice", "ward", "heavy"], "primary_stat": "defense", "effects": {"elemental_ward": {"element": "ice", "multiplier": 0.90, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 3, "minimum_player_level": 8, "rarity_floor": "epic", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "heavy_shield", "visual_id": "shield_frost", "description": "A stable wall against Ice pressure with a clear mobility cost."},

	&"bangle": {"family": "bracelet", "role_tags": ["balanced", "baseline"], "primary_stat": "strength", "effects": {}, "source_tags": ["starter", "shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "bracelet", "visual_id": "bangle", "description": "A flexible bracelet with small benefits in several lanes."},
	&"duelist_seal": {"family": "seal", "role_tags": ["strength", "target_lock"], "primary_stat": "strength", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "seal", "visual_id": "seal", "description": "Commit to a locked target for stronger STR scaling and accept the off-target tradeoff."},
	&"warrior_charm": {"family": "charm", "role_tags": ["strength", "defense"], "primary_stat": "strength", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "charm", "visual_id": "charm", "description": "Value force and resilience over speed."},
	&"swift_boots": {"family": "boots", "role_tags": ["agility", "mobility"], "primary_stat": "agility", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "boots", "visual_id": "boots", "description": "Make movement, running, and roll recovery the build's center."},
	&"chroma_talisman": {"family": "talisman", "role_tags": ["intelligence", "mnd", "chroma"], "primary_stat": "intelligence", "effects": {}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "talisman", "visual_id": "talisman", "description": "Support the magic side of Chroma without granting free Souls or changing aspect."},
	&"soul_locket": {"family": "locket", "role_tags": ["mnd", "vitality", "pickup"], "primary_stat": "mnd", "effects": {"pickup_radius": {"multiplier": 1.20, "status": "future"}}, "source_tags": ["shop", "chest", "clear_reward"], "minimum_run_rank": 1, "minimum_player_level": 1, "rarity_floor": "common", "rarity_ceiling": "mythic", "shop_eligible": true, "fusion_group": "locket", "visual_id": "locket", "description": "Collect Souls and Chroma more comfortably without increasing their value."},
	&"runebound_knot": {"family": "knot", "role_tags": ["agility", "intelligence", "combo"], "primary_stat": "agility", "effects": {"combo_window": {"seconds": 0.15, "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 2, "minimum_player_level": 5, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "knot", "visual_id": "knot", "description": "Give sustained contact more room through the visible combo timer, not direct Style."},
	&"elemental_knot": {"family": "knot", "role_tags": ["intelligence", "mnd", "imbue"], "primary_stat": "intelligence", "effects": {"imbue_resonance": {"element": "active_aspect", "magic_multiplier": 0.06, "mode": "matching_imbue", "status": "future"}}, "source_tags": ["chest", "clear_reward", "boss"], "minimum_run_rank": 2, "minimum_player_level": 5, "rarity_floor": "rare", "rarity_ceiling": "mythic", "shop_eligible": false, "fusion_group": "knot", "visual_id": "knot_elemental", "description": "Reward matching the active aspect without overriding it."},
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
		"slot": &"body",
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


static func canonical_slot(slot: Variant) -> StringName:
	var normalized := str(slot).to_lower()
	if normalized == "armor":
		return &"body"
	if normalized in ["weapon", "head", "body", "arm", "shield", "accessory"]:
		return StringName(normalized)
	return &""


func slot_label(slot: Variant) -> String:
	return str(SLOT_LABELS.get(canonical_slot(slot), "ITEM"))


func definition_data(definition_id: StringName) -> Dictionary:
	var base: Dictionary = DEFINITIONS.get(definition_id, {}).duplicate(true)
	if base.is_empty():
		return {}
	var metadata: Dictionary = DEFINITION_METADATA.get(definition_id, {})
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
		base["source_tags"] = []
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
	for definition_id: StringName in DEFINITIONS:
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
	if not DEFINITIONS.has(definition_id):
		return false
	var base: Dictionary = DEFINITIONS.get(definition_id, {})
	var metadata: Dictionary = DEFINITION_METADATA.get(definition_id, {})
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
	return equipped == null or bool(definition_data(equipped.definition_id).get("starter_only", false))


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
	var ids := {&"weapon": &"basic_sword", &"head": &"plain_hood", &"body": &"basic_tunic", &"arm": &"cloth_wraps", &"shield": &"basic_shield", &"accessory": &"bangle"}
	var item := ItemInstance.new()
	if canonical.is_empty():
		return item
	item.instance_id = "starter-armor" if str(slot).to_lower() == "armor" else "starter-%s" % String(canonical)
	item.definition_id = ids[canonical]
	return item


func generate_item(slot: StringName, generation_seed: int, level: int = 1, minimum_rarity: StringName = &"", prefer_non_basic: bool = false, source_tag: StringName = &"", run_rank: int = -1) -> ItemInstance:
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
		weights.append(BASIC_GEAR_DROP_WEIGHT if _is_basic_gear(definition_id) else 1.0)
	var item := ItemInstance.new()
	if candidates.is_empty():
		return item
	item.definition_id = _pick_weighted_definition(candidates, weights, rng)
	item.rarity = minimum_rarity if not minimum_rarity.is_empty() else roll_run_rarity(rng.randf(), level)
	item.rarity = _clamp_rarity_to_definition(item.rarity, item.definition_id)
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


func _clamp_rarity_to_definition(rarity: StringName, definition_id: StringName) -> StringName:
	var definition := definition_data(definition_id)
	if definition.is_empty():
		return rarity
	var rank := clampi(_rarity_rank(rarity), _rarity_rank(StringName(str(definition.get("rarity_floor", "common")))), _rarity_rank(StringName(str(definition.get("rarity_ceiling", "mythic")))))
	var ladder: Array[StringName] = [&"common", &"rare", &"epic", &"legendary", &"mythic"]
	return ladder[rank]


func _is_basic_gear(definition_id: StringName) -> bool:
	return definition_id in [&"basic_sword", &"basic_tunic", &"basic_shield", &"bangle", &"plain_hood", &"cloth_wraps"]


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


func transmutation_is_eligible(definition_id: StringName, transmutation_id: StringName, rarity: StringName) -> bool:
	var transmutation: Dictionary = TRANSMUTATIONS.get(transmutation_id, {})
	if transmutation.is_empty() or definition_id not in transmutation.get("definitions", []):
		return false
	var minimum_rarity := StringName(str(transmutation.get("min_rarity", "common")))
	return _rarity_rank(rarity) >= _rarity_rank(minimum_rarity)


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
	return canonical_slot(definition_data(definition_id).get("slot", &""))


func display_name(item: ItemInstance) -> String:
	if item == null:
		return "UNKNOWN ITEM"
	var definition: Dictionary = definition_data(item.definition_id)
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
	for stat: String in ["strength", "vitality", "defense", "agi", "intelligence", "mnd"]:
		if float(package.get(stat, 0.0)) > 0.0:
			result[stat] = rate
			if stat == "agi":
				result["speed"] = rate
	return result

func player_stat_rate_text(item: ItemInstance) -> String:
	var labels := {"strength": "STR", "vitality": "VIT", "defense": "DEF", "agi": "AGI", "intelligence": "INT", "mnd": "MND"}
	var parts: Array[String] = []
	var rates := player_stat_rates(item)
	if rates.is_empty() and item != null:
		return "PLAYER +%d%%" % roundi(rarity_stat_rate(item.rarity) * 100.0)
	for stat: String in ["strength", "vitality", "defense", "agi", "intelligence", "mnd"]:
		if rates.has(stat):
			parts.append("%s +%d%%" % [labels[stat], roundi(float(rates[stat]) * 100.0)])
	return " ".join(parts)


func bonuses(item: ItemInstance, _mastery_level: int = 0) -> Dictionary:
	var definition: Dictionary = definition_data(item.definition_id)
	var result: Dictionary = {}
	var base_bonuses: Dictionary = definition.get("bonuses", {})
	var flat_points := float(rarity_flat_points(item.rarity)) + enhancement_flat_points(item.enhancement_level)
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
	for stat: String in base_bonuses:
		var base_value := float(base_bonuses[stat])
		var normalized_stat: String = _normalize_stat_key(str({"health": "health_rate", "damage": "damage_rate"}.get(stat, stat)))
		if normalized_stat in ["health_rate", "damage_rate"]:
			continue
		var flat_value := base_value
		if normalized_stat in scaled_stats:
			flat_value += flat_points
		# Legacy affixes remain serialized for save compatibility, but the new
		# tier package is deterministic and no longer adds hidden stat points.
		result[normalized_stat] = flat_value
		if normalized_stat == "agi":
			result["speed"] = flat_value
	return result


func combat_primary_points(item: ItemInstance) -> Dictionary:
	var result: Dictionary = {}
	var displayed_bonuses := bonuses(item)
	for stat in ["strength", "vitality", "defense", "agi", "intelligence", "mnd"]:
		if displayed_bonuses.has(stat):
			result[stat] = float(displayed_bonuses[stat])
	if displayed_bonuses.has("agi"):
		result["speed"] = float(displayed_bonuses["agi"])
	return result


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
	var base := int(definition_data(item.definition_id).get("price", 50))
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
