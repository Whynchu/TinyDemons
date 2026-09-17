extends RefCounted
class_name ElementCatalog

## Stable combat elements. These are deliberately separate from the player's
## Chroma aspect enum and from PaletteLibrary's presentation keys. The lookup
## tables and matchup policy are authored in resources/definitions/element_catalog.tres
## so the editor can inspect them; the enum and the static API stay in code.

const DATA := preload("res://resources/definitions/element_catalog.tres") as ElementCatalogData

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

static func element_count() -> int:
	return int(DATA.element_count)

static func default_element() -> int:
	return int(DATA.default_element)

static func damage_number_color_boost() -> float:
	return float(DATA.damage_number_color_boost)

static func ids() -> Dictionary:
	return DATA.ids

static func display_names() -> Dictionary:
	return DATA.display_names

static func palette_keys() -> Dictionary:
	return DATA.palette_keys

static func matchup_table() -> Array:
	return DATA.matchup_table


static func is_valid(element: int) -> bool:
	return element >= Element.NEUTRAL and element < element_count()


static func normalize(element: int) -> int:
	return element if is_valid(element) else default_element()


static func id(element: int) -> StringName:
	return ids().get(normalize(element), ids()[default_element()]) as StringName


static func display_name(element: int) -> String:
	return str(display_names().get(normalize(element), display_names()[default_element()]))


static func palette_key(element: int) -> String:
	return str(palette_keys().get(normalize(element), palette_keys()[default_element()]))


static func effectiveness(attacker: int, defender: int) -> float:
	var normalized_attacker := normalize(attacker)
	var normalized_defender := normalize(defender)
	return float(matchup_table()[normalized_attacker][normalized_defender])


static func is_immune(attacker: int, defender: int) -> bool:
	return is_zero_approx(effectiveness(attacker, defender))


static func damage_number_color(element: int, was_critical: bool = false) -> Color:
	var normalized_element := normalize(element)
	if normalized_element == Element.NEUTRAL:
		# Neutral damage uses a clean white glyph. On a critical hit the existing
		# white outline needs a dark interior to stay legible.
		return Color.BLACK if was_critical else Color.WHITE
	var accent := PaletteLibrary.accent(palette_key(normalized_element))
	var boosted := Color.from_hsv(accent.h, clampf(accent.s * damage_number_color_boost(), 0.0, 1.0), clampf(accent.v * damage_number_color_boost(), 0.0, 1.0), accent.a)
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
	var lookup := ids()
	for element: int in lookup:
		if lookup[element] == element_id:
			return element
	return Element.NEUTRAL


static func is_valid_id(element_id: StringName) -> bool:
	var lookup := ids()
	return element_id in lookup.values() and element_id != lookup[Element.NEUTRAL]


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
