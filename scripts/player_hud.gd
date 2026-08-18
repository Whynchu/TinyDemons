@tool
extends Node2D

const BAR_SIZE := Vector2(48, 16)
const XP_COLOR := Color8(59, 93, 201)
const HP_COLOR := Color8(190, 55, 65)
const HP_HIGHLIGHT := Color8(239, 125, 87)
const MP_COLOR := Color8(65, 166, 246)
const GOLD_COLOR := Color8(255, 205, 117)

var _source_fill: Texture2D


func _ready() -> void:
	_source_fill = ($PlayerStatus/LevelXp/XpBarFill as Sprite2D).texture
	($PreviewContext as Node2D).visible = Engine.is_editor_hint()
	_configure_sprites()
	set_static_text("lv. 1")
	if Engine.is_editor_hint():
		_set_text($PlayerStatus/Health/HpText, "10/10", Color.WHITE)
		_set_text($RoomNumber, "D1", Color.WHITE)
		_set_text($DungeonRun, "SLIMEY DEPTHS R1", Color.WHITE)
		_set_text($RunTimer, "TIME 00:00", Color.WHITE)
	else:
		_set_text($PlayerStatus/Health/HpText, "0/0", Color.WHITE)
	_set_text($PlayerStatus/LevelXp/XpText, "0/100", Color.WHITE)
	_set_text($PlayerStatus/Mana/MpText, "0/100", Color.WHITE)
	_set_text($GoldDisplay/GoldAmount, "0", GOLD_COLOR)
	apply_bar_colors(XP_COLOR)


func _configure_sprites() -> void:
	var gold := $GoldDisplay/Gold as Sprite2D
	gold.hframes = 4
	gold.vframes = 1
	gold.frame = 0
	for fill in [$PlayerStatus/LevelXp/XpBarFill, $PlayerStatus/Health/HpBarFill, $PlayerStatus/Mana/MpBarFill]:
		var sprite := fill as Sprite2D
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, BAR_SIZE)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func set_static_text(level_text: String, _player_color: Color = XP_COLOR) -> void:
	var level_sprite := $PlayerStatus/LevelXp/LevelTextAnchor/LevelText as Sprite2D
	_set_text(level_sprite, level_text, Color.WHITE)
	level_sprite.position.x = -float(level_sprite.texture.get_width())
	_set_text($PlayerStatus/Health/HpLabel, "hp", Color.WHITE)
	_set_text($PlayerStatus/Mana/MpLabel, "mp", Color.WHITE)


func apply_bar_colors(player_color: Color = XP_COLOR) -> void:
	if _source_fill == null:
		_source_fill = ($PlayerStatus/LevelXp/XpBarFill as Sprite2D).texture
	($PlayerStatus/LevelXp/XpBarFill as Sprite2D).texture = _solid_texture(_source_fill, player_color)
	($PlayerStatus/Health/HpBarFill as Sprite2D).texture = _solid_texture(_source_fill, HP_COLOR)
	($PlayerStatus/Mana/MpBarFill as Sprite2D).texture = _solid_texture(_source_fill, MP_COLOR)
	for frame in [$PlayerStatus/LevelXp/XpBar, $PlayerStatus/Health/HpBar, $PlayerStatus/Mana/MpBar]:
		(frame as Sprite2D).self_modulate = Color.WHITE


func hp_highlight_texture() -> Texture2D:
	return _solid_texture(_source_fill, HP_HIGHLIGHT)


func _solid_texture(source: Texture2D, color: Color) -> Texture2D:
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return source
	for y in image.get_height():
		for x in image.get_width():
			var alpha := image.get_pixel(x, y).a
			if alpha > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)


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
		"L": ["100", "100", "100", "100", "111"], "v": ["000", "000", "101", "101", "010"],
		"l": ["10", "10", "10", "10", "11"], "h": ["100", "100", "110", "101", "101"],
		"p": ["000", "110", "101", "110", "100"], "m": ["00000", "11011", "10101", "10101", "10101"],
		"S": ["011", "100", "010", "001", "110"], "T": ["111", "010", "010", "010", "010"],
		"A": ["010", "101", "111", "101", "101"], "R": ["110", "101", "110", "101", "101"],
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
