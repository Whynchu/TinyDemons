@tool
extends Node2D

## The authored player HUD is one 82x16 logical-pixel strip. Keep the layer
## sprites at the strip origin so the artwork can be edited in the scene as a
## single, flush-top-left composition.
const HUD_SIZE := Vector2(82, 16)
const HUD_SIZE_PIXELS := Vector2i(82, 16)
const SOUL_VISUALS_SCRIPT = preload("res://scripts/soul_visuals.gd")
const XP_COLOR := PaletteLibrary.NORMAL["yellow"]
const HP_COLOR := PaletteLibrary.NORMAL["red"]
const HP_HIGHLIGHT := Color8(239, 125, 87)
const MP_COLOR := PaletteLibrary.ACCENT["blue"]
const GOLD_COLOR := PaletteLibrary.NORMAL["yellow"]
const LEVEL_NUMBER_ATLAS: Texture2D = preload("res://assets/artwork/player_UI_lvlnumbers.png")
const LEVEL_NUMBER_COLOR := PaletteLibrary.WHITE
const LEVEL_NUMBER_ORIGIN := Vector2i(66, 8)
const LEVEL_SLOT_ORIGINS := [66, 71, 76]
# The authored bars share an 82px strip but their colored tracks do not. The
# leading pixels are intentional artwork padding; clipping the whole strip by
# ratio makes a half-full XP/Chroma bar look almost full. Keep each source's
# active line as explicit layout data so the scene remains editable.
const BAR_TRACKS := {
	"PlayerStatus/LevelXp/XpBarFill": Vector2(17, 34),
	"PlayerStatus/Health/HpBarFill": Vector2(17, 62),
	"PlayerStatus/Mana/MpBarFill": Vector2(17, 46),
}

var _xp_source: Texture2D
var _hp_source: Texture2D
var _mp_source: Texture2D
var _portrait_source: Texture2D
var _solid_texture_cache: Dictionary = {}
var _level_number_texture_cache: Dictionary = {}


func _ready() -> void:
	_capture_source_textures()
	var preview := get_node_or_null("PreviewContext") as Node2D
	if preview != null:
		preview.visible = Engine.is_editor_hint()
	_configure_sprites()
	set_static_text("lv. 1")
	if Engine.is_editor_hint():
		_set_text(get_node_or_null("PlayerStatus/Health/HpText") as Sprite2D, "10/10", Color.WHITE)
		var soul_icon := get_node_or_null("SoulDisplay/SoulIcon") as Sprite2D
		if soul_icon != null:
			soul_icon.texture = SOUL_VISUALS_SCRIPT.texture()
			soul_icon.centered = false
			soul_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_set_text(get_node_or_null("SoulDisplay/SoulAmount") as Sprite2D, "0", SOUL_VISUALS_SCRIPT.SOUL_HIGHLIGHT_COLOR)
		_set_text(get_node_or_null("RoomNumber") as Sprite2D, "D1", Color.WHITE)
		_set_text(get_node_or_null("DungeonRun") as Sprite2D, "SLIMEY DEPTHS R1", Color.WHITE)
		_set_text(get_node_or_null("RunTimer") as Sprite2D, "TIME 00:00", Color.WHITE)
	else:
		_set_text(get_node_or_null("PlayerStatus/Health/HpText") as Sprite2D, "0/0", Color.WHITE)
	_set_text(get_node_or_null("PlayerStatus/LevelXp/XpText") as Sprite2D, "0/100", Color.WHITE)
	_set_text(get_node_or_null("PlayerStatus/Mana/MpText") as Sprite2D, "0/100", Color.WHITE)
	_set_text(get_node_or_null("GoldDisplay/GoldAmount") as Sprite2D, "0", GOLD_COLOR)
	apply_bar_colors(XP_COLOR, MP_COLOR)


func _capture_source_textures() -> void:
	if _xp_source == null:
		var xp_fill := get_node_or_null("PlayerStatus/LevelXp/XpBarFill") as Sprite2D
		if xp_fill != null:
			_xp_source = xp_fill.texture
	if _hp_source == null:
		var hp_fill := get_node_or_null("PlayerStatus/Health/HpBarFill") as Sprite2D
		if hp_fill != null:
			_hp_source = hp_fill.texture
	if _mp_source == null:
		var mp_fill := get_node_or_null("PlayerStatus/Mana/MpBarFill") as Sprite2D
		if mp_fill != null:
			_mp_source = mp_fill.texture
	if _portrait_source == null:
		var portrait := get_node_or_null("PlayerStatus/Portrait") as Sprite2D
		if portrait != null:
			_portrait_source = portrait.texture


func _configure_sprites() -> void:
	var gold := get_node_or_null("GoldDisplay/Gold") as Sprite2D
	if gold != null:
		gold.hframes = 4
		gold.vframes = 1
		gold.frame = 0
	for path in ["PlayerStatus/LevelXp/XpBarFill", "PlayerStatus/Health/HpBarFill", "PlayerStatus/Mana/MpBarFill"]:
		var fill := get_node_or_null(path) as Sprite2D
		if fill == null:
			continue
		fill.centered = false
		fill.region_enabled = true
		var track: Vector2 = BAR_TRACKS.get(path, Vector2.ZERO)
		if track != Vector2.ZERO:
			fill.set_meta("fill_track_start_x", track.x)
			fill.set_meta("fill_track_width", track.y)
			fill.region_rect = Rect2(Vector2.ZERO, Vector2(track.x + track.y, HUD_SIZE.y))
		else:
			fill.region_rect = Rect2(Vector2.ZERO, HUD_SIZE)
		fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# These nodes remain as compatibility targets for gameplay and pause-menu
	# code, but their old numerical presentation is deliberately absent from
	# the live HUD. Enemy/target numbers are built by HudController separately.
	for path in [
		"PlayerStatus/LevelXp/LevelTextAnchor/LevelText",
		"PlayerStatus/LevelXp/XpText",
		"PlayerStatus/Health/HpLabel",
		"PlayerStatus/Health/HpText",
		"PlayerStatus/Mana/MpLabel",
		"PlayerStatus/Mana/MpText",
		"PlayerStatus/LevelXp/XpBar",
		"PlayerStatus/Health/HpBar",
		"PlayerStatus/Mana/MpBar",
	]:
		var legacy_sprite := get_node_or_null(path) as Sprite2D
		if legacy_sprite != null:
			legacy_sprite.visible = false


func set_static_text(level_text: String, _player_color: Color = XP_COLOR) -> void:
	# Keep the legacy targets populated for callers that still use them in
	# pause/status contexts, while the gameplay HUD uses the dedicated badge.
	var legacy_level := get_node_or_null("PlayerStatus/LevelXp/LevelTextAnchor/LevelText") as Sprite2D
	_set_text(legacy_level, level_text, Color.WHITE)
	if legacy_level != null:
		legacy_level.visible = false
	set_level_number(_level_from_text(level_text))
	var hp_label := get_node_or_null("PlayerStatus/Health/HpLabel") as Sprite2D
	var mp_label := get_node_or_null("PlayerStatus/Mana/MpLabel") as Sprite2D
	_set_text(hp_label, "hp", Color.WHITE)
	_set_text(mp_label, "ch", Color.WHITE)
	if hp_label != null:
		hp_label.visible = false
	if mp_label != null:
		mp_label.visible = false


func set_level_number(level: int) -> void:
	var number_sprite := get_node_or_null("PlayerStatus/LevelNumber") as Sprite2D
	if number_sprite == null:
		return
	number_sprite.texture = _level_number_texture(level)
	number_sprite.centered = false
	number_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	number_sprite.visible = true


func apply_bar_colors(_player_color: Color = XP_COLOR, chroma_color: Color = MP_COLOR) -> void:
	_capture_source_textures()
	var xp_fill := get_node_or_null("PlayerStatus/LevelXp/XpBarFill") as Sprite2D
	var hp_fill := get_node_or_null("PlayerStatus/Health/HpBarFill") as Sprite2D
	var mp_fill := get_node_or_null("PlayerStatus/Mana/MpBarFill") as Sprite2D
	if xp_fill != null:
		xp_fill.texture = _solid_texture(_xp_source, XP_COLOR)
	if hp_fill != null:
		hp_fill.texture = _solid_texture(_hp_source, HP_COLOR)
	if mp_fill != null:
		mp_fill.texture = _solid_texture(_mp_source, chroma_color)
	for frame_path in ["PlayerStatus/LevelXp/XpBar", "PlayerStatus/Health/HpBar", "PlayerStatus/Mana/MpBar"]:
		var frame := get_node_or_null(frame_path) as Sprite2D
		if frame != null:
			frame.self_modulate = Color.WHITE


func apply_portrait_palette(palette_name: String, library: SpriteFrameLibrary) -> void:
	_capture_source_textures()
	var portrait := get_node_or_null("PlayerStatus/Portrait") as Sprite2D
	if portrait == null or _portrait_source == null or library == null:
		return
	portrait.texture = library.recolor_portrait_texture(_portrait_source, palette_name)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func hp_highlight_texture() -> Texture2D:
	_capture_source_textures()
	return _solid_texture(_hp_source, HP_HIGHLIGHT)


func _level_from_text(level_text: String) -> int:
	var digits := ""
	for character in level_text:
		if "0123456789".find(character) >= 0:
			digits += character
	return maxi(int(digits), 0) if not digits.is_empty() else 1


func _level_number_texture(level: int) -> Texture2D:
	var display_level := clampi(level, 0, 999)
	if _level_number_texture_cache.has(display_level):
		return _level_number_texture_cache[display_level] as Texture2D
	var image := Image.create(HUD_SIZE_PIXELS.x, HUD_SIZE_PIXELS.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var atlas_image := LEVEL_NUMBER_ATLAS.get_image()
	if atlas_image == null:
		return null
	var digits := str(display_level)
	var first_slot := maxi(LEVEL_SLOT_ORIGINS.size() - digits.length(), 0)
	var digit_offset := maxi(digits.length() - LEVEL_SLOT_ORIGINS.size(), 0)
	for index in mini(digits.length(), LEVEL_SLOT_ORIGINS.size()):
		var digit := int(digits.substr(index + digit_offset, 1))
		var slot := first_slot + index
		var slot_x: int = LEVEL_SLOT_ORIGINS[slot]
		for y in 7:
			for x in 4:
				var source_pixel := atlas_image.get_pixel(digit * 4 + x, y)
				if source_pixel.a > 0.0:
					image.set_pixel(slot_x + x, LEVEL_NUMBER_ORIGIN.y + y, Color(LEVEL_NUMBER_COLOR.r, LEVEL_NUMBER_COLOR.g, LEVEL_NUMBER_COLOR.b, source_pixel.a))
	var texture := ImageTexture.create_from_image(image)
	_level_number_texture_cache[display_level] = texture
	return texture


func _solid_texture(source: Texture2D, color: Color) -> Texture2D:
	if source == null:
		return null
	var cache_key := "%s:%s" % [source.get_rid(), color.to_html(false)]
	if _solid_texture_cache.has(cache_key):
		return _solid_texture_cache[cache_key] as Texture2D
	var image := source.get_image()
	if image == null:
		return source
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	var texture := ImageTexture.create_from_image(image)
	_solid_texture_cache[cache_key] = texture
	return texture


func _set_text(sprite: Sprite2D, value: String, color: Color) -> void:
	if sprite == null:
		return
	sprite.texture = glyph_texture(value, color)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func glyph_texture(value: String, color: Color) -> Texture2D:
	var glyphs := {
		"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"],
		"2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"],
		"4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"],
		"6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"],
		"8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
		".": ["0", "0", "0", "0", "1"], "-": ["000", "000", "111", "000", "000"], ":": ["0", "1", "0", "1", "0"], "/": ["001", "001", "010", "100", "100"],
		"L": ["100", "100", "100", "100", "111"], "D": ["110", "101", "101", "101", "110"],
		"I": ["111", "010", "010", "010", "111"], "Y": ["101", "101", "010", "010", "010"], "v": ["000", "000", "101", "101", "010"],
		"l": ["10", "10", "10", "10", "11"], "h": ["100", "100", "110", "101", "101"],
		"c": ["000", "000", "111", "100", "111"],
		"p": ["000", "110", "101", "110", "100"], "m": ["00000", "11011", "10101", "10101", "10101"],
		"S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
		"A": ["010", "101", "111", "101", "101"], "M": ["10001", "11011", "10101", "10101", "10101"], "R": ["110", "101", "110", "101", "101"],
		"E": ["111", "100", "110", "100", "111"], " ": ["0", "0", "0", "0", "0"]
	}
	var width := 0
	for character in value:
		width += (glyphs.get(character, glyphs[" "])[0] as String).length() + 1
	var image := Image.create(maxi(width - 1, 1), 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var cursor := 0
	for character in value:
		var pattern: Array = glyphs.get(character, glyphs[" "])
		for y in pattern.size():
			for x in (pattern[y] as String).length():
				if (pattern[y] as String)[x] == "1":
					image.set_pixel(cursor + x, y, color)
		cursor += (pattern[0] as String).length() + 1
	return ImageTexture.create_from_image(image)
