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

const PLAIN_GEAR_DROP_WEIGHT := 6.0
const BASIC_GEAR_DROP_WEIGHT := 5.0
const SET_GEAR_DROP_WEIGHT := 0.5
const RANDOM_STAT_KEYS: Array[String] = ["vitality", "strength", "defense", "agi", "intelligence", "mnd"]
const SET_IDS: Array[StringName] = [&"swift", &"soldier", &"guard", &"blood", &"arcane", &"soul", &"edge", &"oath", &"rune"]

## The live catalogue is intentionally small and explicit. The older catalogue
## below remains readable for save compatibility, but only these records can be
## generated, bought, fused, or shown as current design data.
const LIVE_BASE_DEFINITIONS := {
	&"plain_blade": {"name": "PLAIN BLADE", "slot": &"weapon", "gear_tier": "plain", "tier_stat": "", "bonuses": {}, "price": 8, "description": "A plain blade."},
	&"plain_hood": {"name": "PLAIN HOOD", "slot": &"head", "gear_tier": "plain", "tier_stat": "", "bonuses": {}, "price": 8, "description": "A plain hood."},
	&"plain_tunic": {"name": "PLAIN TUNIC", "slot": &"body", "gear_tier": "plain", "tier_stat": "", "bonuses": {}, "price": 8, "description": "A plain tunic."},
	&"plain_wraps": {"name": "PLAIN WRAPS", "slot": &"arm", "gear_tier": "plain", "tier_stat": "", "bonuses": {}, "price": 8, "description": "Plain hand wraps."},
	&"plain_shield": {"name": "PLAIN SHIELD", "slot": &"shield", "gear_tier": "plain", "tier_stat": "", "bonuses": {}, "shield": {"guard_durability": 1.0, "guard_reduction": 0.0}, "price": 8, "description": "A plain shield."},
	&"plain_ring": {"name": "PLAIN RING", "slot": &"accessory", "gear_tier": "plain", "tier_stat": "", "bonuses": {}, "price": 8, "description": "A plain ring."},
	&"basic_sword": {"name": "BASIC SWORD", "slot": &"weapon", "gear_tier": "basic", "tier_stat": "strength", "bonuses": {"strength": 2.0}, "price": 25, "description": "A dependable sword."},
	&"basic_hood": {"name": "BASIC HOOD", "slot": &"head", "gear_tier": "basic", "tier_stat": "vitality", "bonuses": {"vitality": 1.0}, "price": 25, "description": "A dependable hood."},
	&"basic_tunic": {"name": "BASIC TUNIC", "slot": &"body", "gear_tier": "basic", "tier_stat": "vitality", "bonuses": {"vitality": 1.0, "defense": 1.0}, "price": 30, "description": "A dependable tunic."},
	&"basic_wraps": {"name": "BASIC WRAPS", "slot": &"arm", "gear_tier": "basic", "tier_stat": "strength", "bonuses": {"strength": 1.0}, "price": 25, "description": "A dependable pair of wraps."},
	&"basic_shield": {"name": "BASIC SHIELD", "slot": &"shield", "gear_tier": "basic", "tier_stat": "defense", "bonuses": {"vitality": 1.0, "defense": 2.0, "agi": -1.0}, "shield": {"guard_durability": 2.0, "guard_reduction": 1.0}, "price": 30, "description": "A dependable shield."},
	&"basic_charm": {"name": "BASIC CHARM", "slot": &"accessory", "gear_tier": "basic", "tier_stat": "vitality", "bonuses": {"vitality": 1.0, "strength": 1.0}, "price": 25, "description": "A dependable charm."},
}

## Every set has one item in every slot. Secondary stats and penalties are
## deliberately visible in the flat package; only the authored primary lane
## and independent random `+` lanes receive the rarity/fusion ladder.
const SET_DEFINITIONS := {
	&"swift": {
		&"weapon": {"name": "SWIFT BLADE", "tier_stat": "agi", "bonuses": {"agi": 3.0}, "price": 70, "description": "Movement first."},
		&"head": {"name": "SWIFT CAP", "tier_stat": "agi", "bonuses": {"agi": 2.0}, "price": 60, "description": "Light and quick."},
		&"body": {"name": "SWIFT CLOAK", "tier_stat": "agi", "bonuses": {"agi": 3.0}, "price": 75, "description": "Move through danger."},
		&"arm": {"name": "SWIFT GLOVES", "tier_stat": "agi", "bonuses": {"agi": 2.0}, "price": 60, "description": "Keep your hands light."},
		&"shield": {"name": "SWIFT BUCKLER", "tier_stat": "agi", "bonuses": {"agi": 1.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0}, "price": 65, "description": "A shield for active fighters."},
		&"accessory": {"name": "SWIFT BOOTS", "tier_stat": "agi", "bonuses": {"agi": 3.0}, "price": 70, "description": "Movement is the job."},
	},
	&"soldier": {
		&"weapon": {"name": "SOLDIER SWORD", "tier_stat": "strength", "bonuses": {"strength": 3.0}, "price": 80, "description": "Force with a hard mobility cost."},
		&"head": {"name": "SOLDIER HELM", "tier_stat": "strength", "bonuses": {"strength": 2.0, "defense": 1.0}, "price": 70, "description": "A helm for the front line."},
		&"body": {"name": "SOLDIER MAIL", "tier_stat": "strength", "bonuses": {"strength": 3.0, "vitality": 1.0, "agi": -2.0}, "price": 85, "description": "Heavy force, poor mobility."},
		&"arm": {"name": "SOLDIER GLOVES", "tier_stat": "strength", "bonuses": {"strength": 2.0}, "price": 70, "description": "Built for committed blows."},
		&"shield": {"name": "SOLDIER SHIELD", "tier_stat": "strength", "bonuses": {"strength": 2.0, "defense": 1.0, "agi": -2.0}, "shield": {"guard_durability": 2.0, "guard_reduction": 1.0}, "price": 80, "description": "Power with a real speed loss."},
		&"accessory": {"name": "SOLDIER CHARM", "tier_stat": "strength", "bonuses": {"strength": 2.0}, "price": 70, "description": "A simple soldier's charm."},
	},
	&"guard": {
		&"weapon": {"name": "GUARD BLADE", "tier_stat": "defense", "bonuses": {"defense": 2.0, "strength": 1.0}, "price": 80, "description": "Turn defense into pressure."},
		&"head": {"name": "GUARD HELM", "tier_stat": "defense", "bonuses": {"defense": 3.0, "vitality": 1.0, "agi": -1.0}, "price": 75, "description": "Protection with a small speed loss."},
		&"body": {"name": "GUARD PLATE", "tier_stat": "defense", "bonuses": {"defense": 3.0, "vitality": 2.0, "agi": -1.0}, "price": 90, "description": "Hold the line."},
		&"arm": {"name": "GUARD BRACERS", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 1.0}, "price": 70, "description": "Steady defense."},
		&"shield": {"name": "GUARD SHIELD", "tier_stat": "defense", "bonuses": {"defense": 3.0, "vitality": 1.0}, "shield": {"guard_durability": 4.0, "guard_reduction": 3.0}, "price": 95, "description": "The strongest guard."},
		&"accessory": {"name": "GUARD RING", "tier_stat": "defense", "bonuses": {"defense": 1.0, "vitality": 1.0}, "price": 70, "description": "Reliable protection."},
	},
	&"blood": {
		&"weapon": {"name": "BLOOD BLADE", "tier_stat": "vitality", "bonuses": {"vitality": 3.0, "strength": 1.0, "agi": -1.0}, "price": 80, "description": "Health first."},
		&"head": {"name": "BLOOD HOOD", "tier_stat": "vitality", "bonuses": {"vitality": 2.0}, "price": 65, "description": "A deep reserve of health."},
		&"body": {"name": "BLOOD TUNIC", "tier_stat": "vitality", "bonuses": {"vitality": 3.0, "agi": -1.0}, "price": 85, "description": "A sturdy life pool."},
		&"arm": {"name": "BLOOD WRAPS", "tier_stat": "vitality", "bonuses": {"vitality": 2.0}, "price": 65, "description": "Endure the exchange."},
		&"shield": {"name": "BLOOD SHIELD", "tier_stat": "vitality", "bonuses": {"vitality": 2.0, "defense": 1.0, "agi": -1.0}, "shield": {"guard_durability": 2.0, "guard_reduction": 1.0}, "price": 80, "description": "Health with a speed cost."},
		&"accessory": {"name": "BLOOD RING", "tier_stat": "vitality", "bonuses": {"vitality": 2.0}, "price": 70, "description": "Wear the extra life."},
	},
	&"arcane": {
		&"weapon": {"name": "ARCANE SWORD", "tier_stat": "intelligence", "bonuses": {"intelligence": 3.0}, "price": 80, "description": "Spell power in a blade."},
		&"head": {"name": "ARCANE HOOD", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "mnd": 1.0}, "price": 70, "description": "A clear magical focus."},
		&"body": {"name": "ARCANE ROBE", "tier_stat": "intelligence", "bonuses": {"intelligence": 3.0, "mnd": 1.0, "defense": -1.0}, "price": 90, "description": "Power over physical cover."},
		&"arm": {"name": "ARCANE SLEEVES", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "mnd": 1.0}, "price": 70, "description": "Guide the spell."},
		&"shield": {"name": "ARCANE SHIELD", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "defense": 1.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0}, "price": 80, "description": "A shield for a caster."},
		&"accessory": {"name": "ARCANE CHARM", "tier_stat": "intelligence", "bonuses": {"intelligence": 2.0, "mnd": 1.0}, "price": 75, "description": "More magic, less steel."},
	},
	&"soul": {
		&"weapon": {"name": "SOUL BLADE", "tier_stat": "mnd", "bonuses": {"mnd": 3.0, "intelligence": 1.0}, "price": 80, "description": "Mind over force."},
		&"head": {"name": "SOUL HOOD", "tier_stat": "mnd", "bonuses": {"mnd": 2.0}, "price": 70, "description": "A quiet mind."},
		&"body": {"name": "SOUL CLOAK", "tier_stat": "mnd", "bonuses": {"mnd": 3.0, "defense": 1.0, "strength": -1.0}, "price": 90, "description": "Magic defense over physical force."},
		&"arm": {"name": "SOUL WRAPS", "tier_stat": "mnd", "bonuses": {"mnd": 2.0, "intelligence": 1.0}, "price": 70, "description": "Keep the mind steady."},
		&"shield": {"name": "SOUL BUCKLER", "tier_stat": "mnd", "bonuses": {"mnd": 2.0, "defense": 1.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0}, "price": 80, "description": "A small ward of will."},
		&"accessory": {"name": "SOUL SEAL", "tier_stat": "mnd", "bonuses": {"mnd": 2.0, "intelligence": 1.0}, "price": 75, "description": "A seal for the inner fight."},
	},
	&"edge": {
		&"weapon": {"name": "EDGE BLADE", "tier_stat": "agi", "bonuses": {"agi": 3.0, "strength": 1.0}, "price": 80, "description": "Speed with a sharp finish."},
		&"head": {"name": "EDGE CAP", "tier_stat": "agi", "bonuses": {"agi": 2.0}, "price": 65, "description": "Light and precise."},
		&"body": {"name": "EDGE CLOAK", "tier_stat": "agi", "bonuses": {"agi": 3.0, "strength": 1.0, "defense": -2.0}, "price": 85, "description": "Precision over protection."},
		&"arm": {"name": "EDGE GLOVES", "tier_stat": "agi", "bonuses": {"agi": 2.0, "strength": 1.0}, "price": 70, "description": "Keep the attack clean."},
		&"shield": {"name": "EDGE BUCKLER", "tier_stat": "agi", "bonuses": {"agi": 1.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0}, "price": 70, "description": "A shield that stays out of the way."},
		&"accessory": {"name": "EDGE BOOTS", "tier_stat": "agi", "bonuses": {"agi": 3.0}, "price": 75, "description": "Take the opening."},
	},
	&"oath": {
		&"weapon": {"name": "OATH SWORD", "tier_stat": "defense", "bonuses": {"strength": 2.0, "defense": 1.0}, "price": 80, "description": "A balanced combat promise."},
		&"head": {"name": "OATH HELM", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 1.0}, "price": 70, "description": "Stand firm."},
		&"body": {"name": "OATH MAIL", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 2.0}, "price": 85, "description": "A broad middle path."},
		&"arm": {"name": "OATH BRACERS", "tier_stat": "defense", "bonuses": {"defense": 1.0, "strength": 1.0}, "price": 70, "description": "Force and guard together."},
		&"shield": {"name": "OATH SHIELD", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 1.0}, "shield": {"guard_durability": 2.0, "guard_reduction": 2.0}, "price": 85, "description": "A dependable shield."},
		&"accessory": {"name": "OATH CHARM", "tier_stat": "defense", "bonuses": {"defense": 2.0, "vitality": 2.0, "strength": 1.0}, "price": 80, "description": "A little of everything, built around standing firm."},
	},
	&"rune": {
		&"weapon": {"name": "RUNE BLADE", "tier_stat": "strength", "bonuses": {"strength": 3.0, "intelligence": 1.0}, "price": 90, "description": "A brutal battle mage's blade."},
		&"head": {"name": "RUNE HOOD", "tier_stat": "strength", "bonuses": {"strength": 1.0, "intelligence": 1.0, "mnd": -1.0}, "price": 75, "description": "Power without calm."},
		&"body": {"name": "RUNE ROBE", "tier_stat": "strength", "bonuses": {"strength": 2.0, "intelligence": 2.0, "defense": -2.0, "mnd": -1.0}, "price": 95, "description": "A brutal robe with poor defense."},
		&"arm": {"name": "RUNE GLOVES", "tier_stat": "strength", "bonuses": {"strength": 1.0, "intelligence": 1.0}, "price": 75, "description": "Strike through the spell."},
		&"shield": {"name": "RUNE SHIELD", "tier_stat": "strength", "bonuses": {"strength": 1.0, "intelligence": 1.0, "defense": -1.0}, "shield": {"guard_durability": 1.0, "guard_reduction": 1.0}, "price": 85, "description": "A battle mage's compromise."},
		&"accessory": {"name": "RUNE CHARM", "tier_stat": "strength", "bonuses": {"strength": 1.0, "intelligence": 1.0, "mnd": -1.0}, "price": 80, "description": "More power, less restraint."},
	},
}

const LIVE_BASE_IDS: Array[StringName] = [&"plain_blade", &"plain_hood", &"plain_tunic", &"plain_wraps", &"plain_shield", &"plain_ring", &"basic_sword", &"basic_hood", &"basic_tunic", &"basic_wraps", &"basic_shield", &"basic_charm"]

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


func live_definition_ids() -> Array[StringName]:
	var result: Array[StringName] = LIVE_BASE_IDS.duplicate()
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
		var set_records: Dictionary = SET_DEFINITIONS.get(set_id, {})
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
	var is_live := LIVE_BASE_DEFINITIONS.has(definition_id) or _is_live_set_definition(definition_id)
	var base: Dictionary = LIVE_BASE_DEFINITIONS.get(definition_id, {}).duplicate(true) if LIVE_BASE_DEFINITIONS.has(definition_id) else _live_set_definition(definition_id)
	if base.is_empty() and DEFINITIONS.has(definition_id):
		base = DEFINITIONS.get(definition_id, {}).duplicate(true)
	if base.is_empty():
		return {}
	if not is_live:
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
	if LIVE_BASE_DEFINITIONS.has(definition_id) or _is_live_set_definition(definition_id):
		return true
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
	var ids := {&"weapon": &"basic_sword", &"head": &"basic_hood", &"body": &"basic_tunic", &"arm": &"basic_wraps", &"shield": &"basic_shield", &"accessory": &"basic_charm"}
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
	var tier := str(definition_data(definition_id).get("gear_tier", "legacy"))
	return tier == "plain" or tier == "basic"


func _is_live_definition(definition_id: StringName) -> bool:
	return LIVE_BASE_DEFINITIONS.has(definition_id) or _is_live_set_definition(definition_id)


func _gear_drop_weight(definition_id: StringName) -> float:
	var tier := str(definition_data(definition_id).get("gear_tier", "legacy"))
	match tier:
		"plain": return PLAIN_GEAR_DROP_WEIGHT
		"basic": return BASIC_GEAR_DROP_WEIGHT
		"set": return SET_GEAR_DROP_WEIGHT
	return 0.0


func _roll_random_stat_points(rarity: StringName, rng: RandomNumberGenerator, plus_rarity_scale: float = 1.0) -> Dictionary:
	var roll := rng.randf()
	var plus_count := 0
	match rarity:
		&"common":
			plus_count = 1 if roll < 0.06 else 0
		&"rare":
			if roll < 0.60:
				plus_count = 0
			elif roll < 0.92:
				plus_count = 1
			else:
				plus_count = 2
		&"epic":
			if roll < 0.38:
				plus_count = 0
			elif roll < 0.72:
				plus_count = 1
			elif roll < 0.93:
				plus_count = 2
			else:
				plus_count = 3
		&"legendary":
			if roll < 0.45:
				plus_count = 1
			elif roll < 0.82:
				plus_count = 2
			else:
				plus_count = 3
		&"mythic":
			if roll < 0.55:
				plus_count = 2
			else:
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
	# Kept as a compatibility seam for old callers. The reworked model is flat;
	# rarity and fusion growth are folded into bonuses() instead of multiplying
	# the player's complete stat sheet.
	return 0.0

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


func player_stat_rates(item: ItemInstance) -> Dictionary:
	# The old percentage-affix API remains readable by callers, but the new gear
	# system intentionally has no hidden player-stat multipliers.
	return {}

func player_stat_rate_text(item: ItemInstance) -> String:
	return ""


func bonuses(item: ItemInstance, _mastery_level: int = 0) -> Dictionary:
	if item == null:
		return {}
	var definition: Dictionary = definition_data(item.definition_id)
	var result: Dictionary = {}
	var base_bonuses: Dictionary = definition.get("bonuses", {}).duplicate(true)
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
		# A random lane is a real stat lane: it grows at the same additive pace as
		# the authored primary, even when its roll lands on a secondary stat.
		if normalized_stat in scaled_stats or random_value > 0:
			flat_value += flat_points
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
	var multiplier: float = float({&"common": 1.0, &"rare": 1.8, &"epic": 3.2, &"legendary": 5.2, &"mythic": 8.0}.get(item.rarity, 1.0))
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
	if item == null or item.fusion_count <= 0:
		return 0
	# Return most of the fusion history while keeping a small sink so selling
	# cannot create a positive-soul loop.
	return maxi(1, roundi(float(item.fusion_count) * 0.75))


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
