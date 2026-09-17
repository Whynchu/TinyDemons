extends RefCounted
class_name PaletteLibrary

## Editor-inspectable palette color tables. The authored colors live in
## resources/definitions/palette_library.tres; the static lookup API and the
## const-style accessors are backed by that resource so there is one source of
## truth and the editor can inspect and retune presentation tones.

const DATA := preload("res://resources/definitions/palette_library.tres") as PaletteLibraryData

static var PALETTE_NAMES: Array = DATA.palette_names
static var SELECTABLE_PALETTES: Array = DATA.selectable_palettes
static var REST_FIRE_PALETTES: Array = DATA.rest_fire_palettes
static var SHADOW: Dictionary = _normalize_color_dict(DATA.shadow)
static var NORMAL: Dictionary = _normalize_color_dict(DATA.normal)
static var ACCENT: Dictionary = _normalize_color_dict(DATA.accent)
static var ARCHETYPE_HIGHLIGHTS: Array = _normalize_color_array(DATA.archetype_highlights)
static var WHITE: Color = _normalize_color(DATA.white)


## .tres serialization stores floats that can sit one ULP below the authored
## 8-bit value (e.g. Color8(181, 97, 55) loads as g=0.380392, which truncates
## to 96 in an RGBA8 image). Snap every color to its nearest 8-bit value so the
## runtime palette is byte-exact with the original Color8 constants.
static func _normalize_color(c: Color) -> Color:
	return Color8(roundi(clampf(c.r, 0.0, 1.0) * 255.0), roundi(clampf(c.g, 0.0, 1.0) * 255.0), roundi(clampf(c.b, 0.0, 1.0) * 255.0), roundi(clampf(c.a, 0.0, 1.0) * 255.0))


static func _normalize_color_dict(values: Dictionary) -> Dictionary:
	var result := {}
	for key in values:
		result[key] = _normalize_color(values[key] as Color)
	return result


static func _normalize_color_array(values: Array) -> Array:
	var result: Array = []
	for value in values:
		result.append(_normalize_color(value as Color))
	return result

static func palette_names() -> Array:
	return DATA.palette_names

static func selectable_palettes() -> Array:
	return DATA.selectable_palettes

static func rest_fire_palettes() -> Array:
	return DATA.rest_fire_palettes

static func white() -> Color:
	return DATA.white

static func archetype_highlights() -> Array:
	return DATA.archetype_highlights


static func shadow(name: String) -> Color:
	return SHADOW.get(name, SHADOW["blue"])


static func normal(name: String) -> Color:
	return NORMAL.get(name, NORMAL["blue"])


static func accent(name: String) -> Color:
	return ACCENT.get(name, NORMAL.get(name, NORMAL["blue"]))


static func pair(name: String) -> Array[Color]:
	return [shadow(name), normal(name)]


static func triple(name: String) -> Array[Color]:
	return [shadow(name), normal(name), WHITE]


## Flame recolor palette: [darkest, mid, brightest].  Flames are bright, so they
## skip the palette's dark shadow and use the NORMAL tone as their darkest part
## ("the mid tone is the darkest in the fire's case").  The mid is the palette's
## ACCENT (its own defined highlight), and the brightest tip is that accent
## brightened with the warm hue-shift (orange -> yellow) that the red flame uses,
## so every flame keeps the palette's accent highlight while still glowing
## brighter toward the tip.  Colors without a defined ACCENT get a calculated mid.
static func fire_triple(name: String) -> Array[Color]:
	var normal_col := normal(name)
	var mid: Color
	if ACCENT.has(name):
		mid = ACCENT[name]
	else:
		mid = Color.from_hsv(fposmod(normal_col.h + 0.072, 1.0), normal_col.s, clampf(normal_col.v + 0.24, 0.0, 1.0))
	var tip := Color.from_hsv(fposmod(mid.h + 0.065, 1.0), mid.s, clampf(mid.v + 0.12, 0.0, 1.0))
	# Palettes whose tone is already near-white lose brightness when hue-shifted,
	# so nudge each tone toward white until it strictly out-brightens the previous
	# one.  Keeps the ascending three-tone gradient for every color.
	mid = _raise_to_luma(mid, _luma(normal_col))
	tip = _raise_to_luma(tip, _luma(mid))
	return [normal_col, mid, tip]


static func _luma(c: Color) -> float:
	return c.r * 0.299 + c.g * 0.587 + c.b * 0.114


static func _raise_to_luma(color: Color, min_luma: float) -> Color:
	var result := color
	for i in 40:
		if _luma(result) > min_luma:
			break
		result = result.lerp(WHITE, 0.05)
	return result


static func archetype_highlight(index: int) -> Color:
	return ARCHETYPE_HIGHLIGHTS[posmod(index, ARCHETYPE_HIGHLIGHTS.size())]