extends RefCounted
class_name ActorPaletteMaterial

## Shared GPU palette materials for actor sprites. One ShaderMaterial per
## palette, so every sprite using the same palette shares a material and stays
## batch-friendly. This mirrors SpriteFrameLibrary._recolor_player_palette_texture
## for actor frames (the portrait shadow-base rule is a separate path):
##
##   source shadow("blue")  -> target shadow(palette)
##   source normal("blue")  -> target normal(palette)
##   source white           -> white (unchanged)
##   source eye highlight   -> target shadow(palette) for green/yellow, else normal
##
## Actor frames never use the shadow-as-base rule; only portraits do.

const SHADER := preload("res://shaders/palette_swap.gdshader")
const SOURCE_PALETTE := "blue"
const SLIME_SOURCE_SHADOW := Color8(37, 113, 121)
const SLIME_SOURCE_NORMAL := Color8(56, 183, 100)
const SLIME_SOURCE_ACCENT := Color8(167, 240, 112)

static var _materials: Dictionary = {}
static var _slime_materials: Dictionary = {}


static func for_palette(palette_name: String) -> ShaderMaterial:
	if _materials.has(palette_name):
		return _materials[palette_name] as ShaderMaterial
	var pairs := color_pairs(palette_name)
	var material := _material_from_pairs(pairs)
	_materials[palette_name] = material
	return material


## Slime animation sheets are authored from the green slime source art. Keep
## those sheets shared and recolor them in the fragment shader instead of
## creating a CPU ImageTexture for every palette/frame combination.
static func for_slime_palette(palette_name: String) -> ShaderMaterial:
	var palette := palette_name if PaletteLibrary.PALETTE_NAMES.has(palette_name) else "green"
	if _slime_materials.has(palette):
		return _slime_materials[palette] as ShaderMaterial
	var material := _material_from_pairs(slime_color_pairs(palette))
	material.set_meta("palette_source", "slime_green")
	material.set_meta("actor_palette", palette)
	_slime_materials[palette] = material
	return material


## Applies the palette swap uniforms to an arbitrary material (for example the
## player's combined palette-swap + MP-desaturation shader).
static func apply_to(material: ShaderMaterial, palette_name: String) -> void:
	if material == null:
		return
	var pairs := color_pairs(palette_name)
	material.set_shader_parameter("from_color", pairs["from"])
	material.set_shader_parameter("to_color", pairs["to"])


static func _material_from_pairs(pairs: Dictionary) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("from_color", pairs["from"])
	material.set_shader_parameter("to_color", pairs["to"])
	return material


## Returns the source/target color pairs for a palette as {from: PackedColorArray,
## to: PackedColorArray}. Unknown palettes fall back to the blue source set.
static func color_pairs(palette_name: String) -> Dictionary:
	var palette := palette_name if PaletteLibrary.PALETTE_NAMES.has(palette_name) else SOURCE_PALETTE
	var source_colors: Array[Color] = PaletteLibrary.triple(SOURCE_PALETTE)
	var target_colors: Array[Color] = PaletteLibrary.triple(palette)
	var eye_is_shadow := palette == "green" or palette == "yellow"
	return {
		"from": PackedColorArray([
			source_colors[0],
			source_colors[1],
			source_colors[2],
			SpriteFrameLibrary.PLAYER_EYE_HIGHLIGHT_COLOR,
		]),
		"to": PackedColorArray([
			target_colors[0],
			target_colors[1],
			target_colors[2],
			target_colors[0] if eye_is_shadow else target_colors[1],
		]),
	}


static func slime_color_pairs(palette_name: String) -> Dictionary:
	var palette := palette_name if PaletteLibrary.PALETTE_NAMES.has(palette_name) else "green"
	return {
		"from": PackedColorArray([
			SLIME_SOURCE_SHADOW,
			SLIME_SOURCE_NORMAL,
			SLIME_SOURCE_ACCENT,
			Color.WHITE,
		]),
		"to": PackedColorArray([
			PaletteLibrary.shadow(palette),
			PaletteLibrary.normal(palette),
			PaletteLibrary.accent(palette),
			Color.WHITE,
		]),
	}


## Clears the shared material cache. Tests use this to avoid cross-run state.
static func clear_cache() -> void:
	_materials.clear()
	_slime_materials.clear()
