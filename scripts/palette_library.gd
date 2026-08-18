extends RefCounted
class_name PaletteLibrary

const PALETTE_NAMES := ["blue", "orange", "green", "red", "yellow", "grey", "purple", "aquamarine"]

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

static func archetype_highlight(index: int) -> Color:
	return ARCHETYPE_HIGHLIGHTS[posmod(index, ARCHETYPE_HIGHLIGHTS.size())]