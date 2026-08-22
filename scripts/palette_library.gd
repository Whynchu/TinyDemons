extends RefCounted
class_name PaletteLibrary

const PALETTE_NAMES := ["blue", "orange", "green", "red", "yellow", "grey", "purple", "aquamarine"]

## Palettes the player may choose for their character.  Grey is excluded so the
## grey player-state (empty MP) is never a selectable identity.
const SELECTABLE_PALETTES := ["blue", "orange", "green", "red", "yellow", "purple", "aquamarine"]

## Palettes a rest fire may be assigned.  Grey is excluded so the grey flame no
## longer spawns.
const REST_FIRE_PALETTES := ["blue", "orange", "green", "red", "yellow", "purple", "aquamarine"]

const SHADOW := {
	"blue": Color8(41, 54, 111), "orange": Color8(171, 82, 54),
	"green": Color8(37, 113, 121), "red": Color8(93, 39, 93),
	"yellow": Color8(181, 97, 55), "grey": Color8(59, 63, 82),
	"purple": Color8(67, 47, 102), "aquamarine": Color8(39, 84, 116),
}

const NORMAL := {
	"blue": Color8(59, 93, 201), "orange": Color8(239, 125, 87),
	"green": Color8(56, 183, 100), "red": Color8(177, 62, 83),
	"yellow": Color8(255, 205, 117), "grey": Color8(86, 108, 134),
	"purple": Color8(118, 78, 142), "aquamarine": Color8(58, 138, 151),
}

const ACCENT := {
	"blue": Color8(65, 166, 246), "red": Color8(239, 125, 87),
	"purple": Color8(200, 184, 210), "grey": Color8(148, 176, 194),
}

const ARCHETYPE_HIGHLIGHTS := [
	Color8(65, 166, 246), Color8(255, 205, 117), Color8(167, 240, 112),
	Color8(239, 125, 87), Color8(255, 240, 150), Color8(148, 176, 194),
	Color8(118, 78, 142), Color8(58, 138, 151),
]

const WHITE := Color8(244, 244, 244)

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