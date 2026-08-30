extends RefCounted
class_name ElementCatalog

## Stable combat elements. These are deliberately separate from the player's
## Chroma aspect enum and from PaletteLibrary's presentation keys.
enum Element {
	NEUTRAL,
	FIRE,
	WATER,
	ELECTRIC,
	GRASS,
	SHADOW,
	GROUND,
	ICE,
}

const ELEMENT_COUNT := 8
const DEFAULT_ELEMENT := Element.NEUTRAL
const DAMAGE_NUMBER_COLOR_BOOST := 1.10

const IDS := {
	Element.NEUTRAL: &"neutral",
	Element.FIRE: &"fire",
	Element.WATER: &"water",
	Element.ELECTRIC: &"electric",
	Element.GRASS: &"grass",
	Element.SHADOW: &"shadow",
	Element.GROUND: &"ground",
	Element.ICE: &"ice",
}

const DISPLAY_NAMES := {
	Element.NEUTRAL: "GRAY",
	Element.FIRE: "FIRE",
	Element.WATER: "WATER",
	Element.ELECTRIC: "ELECTRIC",
	Element.GRASS: "GRASS",
	Element.SHADOW: "SHADOW",
	Element.GROUND: "GROUND",
	Element.ICE: "ICE",
}

const PALETTE_KEYS := {
	Element.NEUTRAL: "grey",
	Element.FIRE: "red",
	Element.WATER: "blue",
	Element.ELECTRIC: "yellow",
	Element.GRASS: "green",
	Element.SHADOW: "purple",
	Element.GROUND: "orange",
	Element.ICE: "aquamarine",
}

## Rows are attacking elements; columns are defending elements. The values
## are the Tiny Demons-scaled Generation III relationships: resistance 0.8,
## weakness 1.25, immunity 0.0, neutral 1.0. Ground and Ice are appended to
## the original catalog so the existing serialized element values stay stable.
const MATCHUP_TABLE := [
	[1.00, 1.00, 1.00, 1.00, 1.00, 0.00, 1.00, 1.00],
	[1.00, 0.80, 0.80, 1.00, 1.25, 1.00, 1.00, 1.25],
	[1.00, 1.25, 0.80, 1.00, 0.80, 1.00, 1.25, 1.00],
	[1.00, 1.00, 1.25, 0.80, 0.80, 1.00, 0.00, 1.00],
	[1.00, 0.80, 1.25, 1.00, 0.80, 1.00, 1.25, 1.00],
	[1.00, 1.00, 1.00, 1.00, 1.00, 1.25, 1.00, 1.00],
	[1.00, 1.25, 1.00, 1.25, 0.80, 1.00, 0.80, 1.00],
	[1.00, 0.80, 0.80, 1.00, 1.25, 1.00, 1.25, 0.80],
]


static func is_valid(element: int) -> bool:
	return element >= Element.NEUTRAL and element < ELEMENT_COUNT


static func normalize(element: int) -> int:
	return element if is_valid(element) else DEFAULT_ELEMENT


static func id(element: int) -> StringName:
	return IDS.get(normalize(element), IDS[DEFAULT_ELEMENT]) as StringName


static func display_name(element: int) -> String:
	return str(DISPLAY_NAMES.get(normalize(element), DISPLAY_NAMES[DEFAULT_ELEMENT]))


static func palette_key(element: int) -> String:
	return str(PALETTE_KEYS.get(normalize(element), PALETTE_KEYS[DEFAULT_ELEMENT]))


static func effectiveness(attacker: int, defender: int) -> float:
	var normalized_attacker := normalize(attacker)
	var normalized_defender := normalize(defender)
	return float(MATCHUP_TABLE[normalized_attacker][normalized_defender])


static func is_immune(attacker: int, defender: int) -> bool:
	return is_zero_approx(effectiveness(attacker, defender))


static func damage_number_color(element: int, was_critical: bool = false) -> Color:
	var normalized_element := normalize(element)
	if normalized_element == Element.NEUTRAL:
		# Neutral damage uses a clean white glyph. On a critical hit the existing
		# white outline needs a dark interior to stay legible.
		return Color.BLACK if was_critical else Color.WHITE
	var accent := PaletteLibrary.accent(palette_key(normalized_element))
	var boosted := Color.from_hsv(accent.h, clampf(accent.s * DAMAGE_NUMBER_COLOR_BOOST, 0.0, 1.0), clampf(accent.v * DAMAGE_NUMBER_COLOR_BOOST, 0.0, 1.0), accent.a)
	return Color8(roundi(boosted.r * 255.0), roundi(boosted.g * 255.0), roundi(boosted.b * 255.0), roundi(boosted.a * 255.0))


## PlayerChromaComponent.Aspect values are NONE=0, FIRE=1, WATER=2,
## ELECTRIC=3. Keeping this adapter numeric avoids a dependency cycle between
## the player state owner and the stateless combat catalog.
static func element_for_aspect(aspect: int) -> int:
	# PlayerChromaComponent.Aspect intentionally mirrors this enum's stable
	# numeric ids. The adapter keeps the combat catalog independent of the
	# player component while allowing fusion aspects 4..7 to flow through.
	return normalize(aspect)


static func element_for_id(element_id: StringName) -> int:
	for element: int in IDS:
		if IDS[element] == element_id:
			return element
	return Element.NEUTRAL


static func is_valid_id(element_id: StringName) -> bool:
	return element_id in IDS.values() and element_id != IDS[Element.NEUTRAL]


static func element_for_palette(palette: String) -> int:
	match palette.to_lower():
		"red":
			return Element.FIRE
		"blue":
			return Element.WATER
		"yellow":
			return Element.ELECTRIC
		"green":
			return Element.GRASS
		"purple":
			return Element.SHADOW
		"orange":
			return Element.GROUND
		"aquamarine":
			return Element.ICE
		"grey", "gray":
			return Element.NEUTRAL
	return Element.NEUTRAL
