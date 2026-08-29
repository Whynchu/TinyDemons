@tool
extends Node2D

const SoulVisualsScript = preload("res://scripts/soul_visuals.gd")

@export var show_preview := true:
	set(value):
		show_preview = value
		_rebuild_preview()

@export_enum("FULL", "3:2", "16:10", "16:9") var preview_aspect := "3:2":
	set(value):
		preview_aspect = value
		_rebuild_preview()

@export_range(240, 800, 1) var full_preview_width := 346:
	set(value):
		full_preview_width = maxi(value, 240)
		_rebuild_preview()

var preview_nodes: Array[Node2D] = []

func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
		return
	_rebuild_preview()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and preview_nodes.is_empty():
		_rebuild_preview()


func _rebuild_preview() -> void:
	for child in preview_nodes:
		if is_instance_valid(child):
			child.free()
	preview_nodes.clear()
	if not show_preview:
		return

	# These are editor-only Sprite2D nodes. Runtime gameplay hides this guide node.
	# Keep every preview coordinate routed through DisplayLayout so an editor
	# screenshot and the live fixed/adaptive presentation agree. The default
	# FULL sample is 346×160, matching a 2532×1170 iPhone landscape surface.
	var view_size := Vector2(DisplayLayout.view_size(preview_aspect, full_preview_width))
	_add_pixel_sprite("EditorPlayerHealth", DisplayLayout.position_for(Vector2(38, 7), &"hp_mp", view_size), "12/15", Color.WHITE, true)
	_add_pixel_sprite("EditorTargetHealth", DisplayLayout.position_for(Vector2(121, 155), &"target", view_size), "8/13", Color.WHITE, true)
	_add_pixel_sprite("EditorGoldAmount", DisplayLayout.position_for(Vector2(212, 4), &"gold", view_size), "0", Color("#ffcd75"), false)
	_add_pixel_sprite("EditorSoulAmount", DisplayLayout.position_for(Vector2(212, 11), &"souls", view_size), "0", Color("#d3a7ff"), false)
	_add_pixel_sprite("EditorRoomNumber", Vector2(5, 146), "R1", Color("#f4f4f4"), false)
	_add_pixel_sprite("EditorDungeonRun", Vector2(5, 153), "DUNGEON R1", Color("#f4f4f4"), false)
	_add_pixel_sprite("EditorRunTimer", DisplayLayout.position_for(Vector2(199, 153), &"run_timer", view_size), "TIME 00:00", Color("#f4f4f4"), false)
	_add_texture_sprite("EditorGold", "res://assets/artwork/GoldFresh2.png", DisplayLayout.position_for(Vector2(205, 2), &"gold", view_size), Vector2(0, 0), Vector2(5, 5))
	_add_texture_sprite("EditorSoul", "res://assets/artwork/Souls.png", DisplayLayout.position_for(Vector2(205, 9), &"souls", view_size))
	_add_texture_sprite("EditorMagicCooldown", "res://assets/artwork/magic button 16x16.png", DisplayLayout.position_for(Vector2(84, 0), &"ability_icons", view_size))
	_add_texture_sprite("EditorImbueCooldown", "res://assets/artwork/imbue button 16x16.png", DisplayLayout.position_for(Vector2(102, 0), &"ability_icons", view_size))
	_add_texture_sprite("EditorTriangle", "res://assets/artwork/triangle55.png", DisplayLayout.position_for(Vector2(224, 64), &"input_prompts", view_size))
	_add_texture_sprite("EditorSquare", "res://assets/artwork/square55.png", DisplayLayout.position_for(Vector2(219, 69), &"input_prompts", view_size))
	_add_texture_sprite("EditorX", "res://assets/artwork/x55.png", DisplayLayout.position_for(Vector2(224, 74), &"input_prompts", view_size))
	_add_texture_sprite("EditorCircle", "res://assets/artwork/circle55.png", DisplayLayout.position_for(Vector2(229, 69), &"input_prompts", view_size))


func _add_texture_sprite(node_name: String, path: String, sprite_position: Vector2, region_position := Vector2.ZERO, region_size := Vector2.ZERO) -> void:
	var texture := load(path) as Texture2D
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
	if node_name == "EditorSoul":
		var soul_texture := SoulVisualsScript.texture()
		if soul_texture != null:
			sprite.texture = soul_texture
	sprite.position = sprite_position
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 4
	if region_size != Vector2.ZERO:
		sprite.region_enabled = true
		sprite.region_rect = Rect2(region_position, region_size)
	add_child(sprite)
	preview_nodes.append(sprite)


func _add_pixel_sprite(node_name: String, sprite_position: Vector2, value: String, color: Color, centered: bool) -> void:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = _pixel_number_texture(value, color)
	sprite.position = sprite_position
	sprite.centered = centered
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = 4
	add_child(sprite)
	preview_nodes.append(sprite)


func _pixel_number_texture(value: String, color: Color) -> Texture2D:
	var glyphs := {
		"0": ["111", "101", "101", "101", "111"],
		"1": ["010", "110", "010", "010", "111"],
		"2": ["110", "001", "010", "100", "111"],
		"3": ["110", "001", "010", "001", "110"],
		"4": ["101", "101", "111", "001", "001"],
		"5": ["111", "100", "110", "001", "110"],
		"6": ["011", "100", "111", "101", "111"],
		"7": ["111", "001", "010", "010", "010"],
		"8": ["111", "101", "111", "101", "111"],
		"9": ["111", "101", "111", "001", "110"],
		"/": ["001", "001", "010", "100", "100"],
		"R": ["110", "101", "110", "101", "101"],
		" ": ["0", "0", "0", "0", "0"],
	}
	var width := 0
	for character in value:
		width += ((glyphs.get(character, glyphs[" "]) as Array)[0] as String).length() + 1
	width = maxi(width - 1, 1)
	var image := Image.create(width, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for character in value:
		var glyph: Array = glyphs.get(character, glyphs[" "])
		for y in glyph.size():
			var row := glyph[y] as String
			for x in row.length():
				if row[x] == "1":
					image.set_pixel(x_offset + x, y, color)
		x_offset += (glyph[0] as String).length() + 1
	return ImageTexture.create_from_image(image)
