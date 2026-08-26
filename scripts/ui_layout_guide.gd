@tool
extends Node2D

@export var show_preview := true:
	set(value):
		show_preview = value
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
	# Runtime: HpBarFill (14, 0) + 48x16 / 2 + (0, -1).
	_add_pixel_sprite("EditorPlayerHealth", Vector2(38, 7), "12/15", Color.WHITE, true)
	# Runtime: EnemyHp (81, 147) + 80x16 / 2.
	_add_pixel_sprite("EditorTargetHealth", Vector2(121, 155), "8/13", Color.WHITE, true)
	_add_pixel_sprite("EditorGoldAmount", Vector2(72, 4), "0", Color("#ffcd75"), false)
	_add_pixel_sprite("EditorRoomNumber", Vector2(208, 4), "R1", Color("#f4f4f4"), false)
	_add_texture_sprite("EditorGold", "res://assets/artwork/GoldFresh2.png", Vector2(64, 4), Vector2(0, 0), Vector2(5, 5))
	_add_texture_sprite("EditorTriangle", "res://assets/artwork/triangle55.png", Vector2(224, 64))
	_add_texture_sprite("EditorSquare", "res://assets/artwork/square55.png", Vector2(219, 69))
	_add_texture_sprite("EditorX", "res://assets/artwork/x55.png", Vector2(224, 74))
	_add_texture_sprite("EditorCircle", "res://assets/artwork/circle55.png", Vector2(229, 69))


func _add_texture_sprite(node_name: String, path: String, sprite_position: Vector2, region_position := Vector2.ZERO, region_size := Vector2.ZERO) -> void:
	var texture := load(path) as Texture2D
	if texture == null:
		return
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = texture
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
