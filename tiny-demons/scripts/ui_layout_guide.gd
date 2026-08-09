@tool
extends Node2D

@export var show_guides := true:
	set(value):
		show_guides = value
		queue_redraw()
@export var title_rect := Rect2(0, 0, 240, 160):
	set(value):
		title_rect = value
		queue_redraw()
@export var game_over_rect := Rect2(0, 0, 240, 160):
	set(value):
		game_over_rect = value
		queue_redraw()
@export var top_hud_rect := Rect2(0, 0, 240, 14):
	set(value):
		top_hud_rect = value
		queue_redraw()
@export var target_hud_rect := Rect2(72, 140, 96, 20):
	set(value):
		target_hud_rect = value
		queue_redraw()
@export var action_buttons_rect := Rect2(210, 56, 28, 32):
	set(value):
		action_buttons_rect = value
		queue_redraw()

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
	queue_redraw()

func _draw() -> void:
	if not show_guides:
		return
	_draw_region(title_rect, Color(0.4, 0.7, 1.0, 0.18), "TITLE / ARCHETYPE")
	_draw_region(game_over_rect, Color(1.0, 0.35, 0.35, 0.18), "GAME OVER")
	_draw_top_hud_preview()
	_draw_target_hud_preview()
	_draw_action_buttons_preview()
	_draw_region(Rect2(0, 0, 240, 160), Color(0.8, 0.8, 0.8, 0.12), "GAME VIEW 240 x 160")

func _draw_region(rect: Rect2, color: Color, label: String) -> void:
	draw_rect(rect, color, false, 1.0)
	draw_string(ThemeDB.fallback_font, rect.position + Vector2(1, 7), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, color.lightened(0.35))


func _draw_top_hud_preview() -> void:
	# These are editor-only stand-ins for the code-generated HUD sprites.
	_draw_bar(Rect2(14, 4, 42, 5), Color("#5a2732"), Color("#d84f5b"), 0.78)
	_draw_pixel_text(Vector2(27, 5), "12/15", Color.WHITE, 1)
	_draw_pixel_text(Vector2(64, 5), "0", Color("#ffcd75"), 1)
	var coin := load("res://assets/artwork/GoldFresh2.png") as Texture2D
	if coin != null:
		draw_texture_rect_region(coin, Rect2(56, 4, 5, 5), Rect2(0, 0, 5, 5))
	_draw_pixel_text(Vector2(208, 4), "R1", Color("#f4f4f4"), 1)


func _draw_target_hud_preview() -> void:
	_draw_bar(Rect2(72, 140, 96, 6), Color("#25202b"), Color("#4ab36b"), 0.62)
	_draw_pixel_text(Vector2(103, 141), "BLUE SLIME", Color.WHITE, 1)
	_draw_pixel_text(Vector2(109, 148), "8/13", Color.WHITE, 1)


func _draw_action_buttons_preview() -> void:
	var button_data := [
		["triangle55.png", Vector2(224, 64)],
		["square55.png", Vector2(219, 69)],
		["x55.png", Vector2(224, 74)],
		["circle55.png", Vector2(229, 69)],
	]
	for data in button_data:
		var texture := load("res://assets/artwork/" + data[0]) as Texture2D
		if texture != null:
			draw_texture(texture, data[1])


func _draw_bar(rect: Rect2, background: Color, fill: Color, ratio: float) -> void:
	draw_rect(rect, background)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * ratio, rect.size.y)), fill)
	draw_rect(rect, Color.WHITE, false, 1.0)


func _draw_pixel_text(position: Vector2, value: String, color: Color, scale: int) -> void:
	var x := position.x
	for character in value:
		var glyph: Array = _glyph(character)
		for y in glyph.size():
			var row := glyph[y] as String
			for pixel_x in row.length():
				if row[pixel_x] == "1":
					draw_rect(Rect2(x + pixel_x * scale, position.y + y * scale, scale, scale), color)
		x += (glyph[0] as String).length() * scale + scale


func _glyph(character: String) -> Array:
	return {
		"A": ["010", "101", "111", "101", "101"],
		"B": ["110", "101", "110", "101", "110"],
		"C": ["111", "100", "100", "100", "111"],
		"D": ["110", "101", "101", "101", "110"],
		"E": ["111", "100", "110", "100", "111"],
		"L": ["100", "100", "100", "100", "111"],
		"M": ["10001", "11011", "10101", "10001", "10001"],
		"N": ["1001", "1101", "1011", "1001", "1001"],
		"P": ["110", "101", "110", "100", "100"],
		"R": ["110", "101", "110", "101", "101"],
		"S": ["111", "100", "111", "001", "111"],
		"U": ["101", "101", "101", "101", "111"],
		"0": ["111", "101", "101", "101", "111"],
		"1": ["010", "110", "010", "010", "111"],
		"2": ["110", "001", "010", "100", "111"],
		"3": ["110", "001", "010", "001", "110"],
		"/": ["001", "001", "010", "100", "100"],
		" ": ["0", "0", "0", "0", "0"],
	}.get(character, ["0", "0", "0", "0", "0"])
