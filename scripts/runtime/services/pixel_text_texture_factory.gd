extends RefCounted
class_name PixelTextTextureFactory

const GEAR_PLUS_TEXTURE: Texture2D = preload("res://assets/artwork/gearplus3x5.png")

var damage_number_texture_cache: Dictionary = {}
var critical_outline_texture_cache: Dictionary = {}
var name_texture_cache: Dictionary = {}
var keyboard_prompt_texture_cache: Dictionary = {}

func number_texture(text: String, color: Color) -> Texture2D:
	var cache_key := "%s:%s" % [text, _rgb_key(color)]
	if damage_number_texture_cache.has(cache_key):
		return damage_number_texture_cache[cache_key]
	if text.contains("\n"):
		var multiline_texture := _multiline_number_texture(text, color)
		damage_number_texture_cache[cache_key] = multiline_texture
		return multiline_texture
	var patterns := {
		"+": ["000", "010", "111", "010", "000"], "-": ["000", "000", "111", "000", "000"], "_": ["000", "000", "000", "000", "111"], ":": ["0", "1", "0", "1", "0"], ";": ["0", "1", "0", "1", "1"], "!": ["010", "010", "010", "000", "010"], ".": ["0", "0", "0", "0", "1"], ",": ["0", "0", "0", "1", "1"], "'": ["1", "1", "0", "0", "0"], "\"": ["101", "101", "000", "000", "000"], "(": ["001", "010", "100", "010", "001"], ")": ["100", "010", "001", "010", "100"], "/": ["001", "001", "010", "100", "100"],
		"R": ["110", "101", "110", "101", "101"], "S": ["111", "100", "111", "001", "111"], "T": ["111", "010", "010", "010", "010"], "I": ["111", "010", "010", "010", "111"], "Y": ["101", "101", "010", "010", "010"],
		"N": ["1001", "1101", "1011", "1001", "1001"], "D": ["110", "101", "101", "101", "110"], "F": ["111", "100", "110", "100", "100"], "C": ["111", "100", "100", "100", "111"], "U": ["101", "101", "101", "101", "111"], "L": ["100", "100", "100", "100", "111"],
		"0": ["111", "101", "101", "101", "111"], "1": ["010", "110", "010", "010", "111"], "2": ["111", "001", "111", "100", "111"], "3": ["111", "001", "111", "001", "111"], "4": ["101", "101", "111", "001", "001"], "5": ["111", "100", "111", "001", "111"], "6": ["111", "100", "111", "101", "111"], "7": ["111", "001", "010", "010", "010"], "8": ["111", "101", "111", "101", "111"], "9": ["111", "101", "111", "001", "111"],
		"G": ["111", "100", "101", "101", "111"], "H": ["101", "101", "111", "101", "101"], "K": ["101", "110", "100", "110", "101"], "P": ["110", "101", "110", "100", "100"], "W": ["10101", "10101", "10101", "11011", "01010"], "A": ["010", "101", "111", "101", "101"], "B": ["110", "101", "110", "101", "110"], "M": ["10001", "11011", "10101", "10001", "10001"], "E": ["111", "100", "110", "100", "111"], "O": ["111", "101", "101", "101", "111"], "V": ["101", "101", "101", "101", "010"], "X": ["101", "101", "010", "101", "101"], "?": ["110", "001", "010", "000", "010"], "<": ["001", "010", "100", "010", "001"], ">": ["100", "010", "001", "010", "100"], "%": ["11001", "11010", "00100", "01011", "10011"], " ": ["0", "0", "0", "0", "0"]
	}
	patterns["J"] = ["001", "001", "001", "101", "010"]
	patterns["Q"] = ["111", "101", "111", "001", "001"]
	patterns["Z"] = ["111", "001", "010", "100", "111"]
	# Lowercase uses the same five-pixel cap as the combat glyphs, but the
	# previous set was a collection of partially drawn three-pixel shapes. In
	# descriptions that made o/e read like broken boxes and g/y lose their
	# identity. Keep a shared baseline and give the curved/descending letters
	# enough horizontal room to survive nearest-neighbour scaling.
	patterns["a"] = ["000", "010", "101", "111", "101"]
	patterns["b"] = ["100", "100", "110", "101", "110"]
	patterns["c"] = ["000", "011", "100", "100", "011"]
	patterns["d"] = ["001", "001", "011", "101", "011"]
	patterns["e"] = ["0000", "0110", "1001", "1111", "1000"]
	patterns["f"] = ["011", "100", "110", "100", "100"]
	patterns["g"] = ["0000", "0110", "1001", "0111", "0001"]
	patterns["h"] = ["100", "100", "110", "101", "101"]
	patterns["i"] = ["010", "000", "110", "010", "111"]
	patterns["j"] = ["001", "000", "001", "101", "010"]
	patterns["k"] = ["100", "100", "101", "110", "101"]
	patterns["l"] = ["100", "100", "100", "100", "110"]
	patterns["m"] = ["00000", "00000", "11011", "10101", "10101"]
	patterns["n"] = ["000", "000", "110", "101", "101"]
	patterns["o"] = ["0000", "0110", "1001", "1001", "0110"]
	patterns["p"] = ["000", "110", "101", "110", "100"]
	patterns["q"] = ["000", "011", "101", "011", "001"]
	patterns["r"] = ["000", "110", "101", "100", "100"]
	patterns["s"] = ["000", "011", "100", "010", "110"]
	patterns["t"] = ["010", "010", "111", "010", "011"]
	patterns["u"] = ["000", "101", "101", "101", "011"]
	patterns["v"] = ["000", "101", "101", "010", "010"]
	patterns["w"] = ["00000", "00000", "10101", "10101", "01010"]
	patterns["x"] = ["000", "101", "010", "101", "101"]
	patterns["y"] = ["0000", "1001", "1001", "0111", "0010"]
	patterns["z"] = ["000", "111", "010", "100", "111"]
	var compact_patterns: Dictionary = {}
	for character in patterns:
		compact_patterns[character] = _compact_glyph_pattern(patterns[character] as Array)
	var image_width := 0
	for digit in text:
		image_width += (compact_patterns.get(digit, compact_patterns[" "])[0] as String).length() + 1
	image_width = maxi(image_width - 1, 1)
	var image := Image.create(image_width, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var plus_image := GEAR_PLUS_TEXTURE.get_image()
	var x_offset := 0
	for digit in text:
		var pattern: Array = compact_patterns.get(digit, compact_patterns[" "])
		if digit == "+" and plus_image.get_width() == pattern[0].length() and plus_image.get_height() == 5:
			for y in plus_image.get_height():
				for x in plus_image.get_width():
					var source_pixel := plus_image.get_pixel(x, y)
					if source_pixel.a > 0.0:
						image.set_pixel(x_offset + x, y, Color(color.r, color.g, color.b, color.a * source_pixel.a))
			x_offset += (pattern[0] as String).length() + 1
			continue
		for y in 5:
			var row := pattern[y] as String
			for x in row.length():
				if row[x] == "1":
					image.set_pixel(x_offset + x, y, color)
		x_offset += (pattern[0] as String).length() + 1
	var texture := ImageTexture.create_from_image(image)
	damage_number_texture_cache[cache_key] = texture
	return texture


func _multiline_number_texture(text: String, color: Color) -> Texture2D:
	var lines := text.split("\n")
	var line_textures: Array[Texture2D] = []
	var width := 1
	for line in lines:
		var line_texture := number_texture(String(line), color)
		line_textures.append(line_texture)
		width = maxi(width, line_texture.get_width())
	var line_spacing := 2
	var image := Image.create(width, maxi(1, line_textures.size() * 5 + (line_textures.size() - 1) * line_spacing), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var y_offset := 0
	for line_texture in line_textures:
		var line_image := line_texture.get_image()
		image.blit_rect(line_image, Rect2i(Vector2i.ZERO, line_image.get_size()), Vector2i(0, y_offset))
		y_offset += 5 + line_spacing
	return ImageTexture.create_from_image(image)


func critical_outline_texture(text: String, pixel_number: Callable, outline_color: Color = Color.WHITE) -> Texture2D:
	var cache_key := "%s:%s" % [text, _rgb_key(outline_color)]
	if critical_outline_texture_cache.has(cache_key):
		return critical_outline_texture_cache[cache_key]
	var source := pixel_number.call(text, outline_color) as Texture2D
	if source == null:
		return null
	var source_image := source.get_image()
	var image := Image.create(source_image.get_width() + 2, source_image.get_height() + 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for y in source_image.get_height():
		for x in source_image.get_width():
			if source_image.get_pixel(x, y).a <= 0.0:
				continue
			for offset_y in range(-1, 2):
				for offset_x in range(-1, 2):
					image.set_pixel(x + 1 + offset_x, y + 1 + offset_y, outline_color)
	var texture := ImageTexture.create_from_image(image)
	critical_outline_texture_cache[cache_key] = texture
	return texture


func prompt_texture(text: String, color: Color) -> Texture2D:
	return name_texture(text.to_upper(), color)


func keyboard_prompt_texture(text: String) -> Texture2D:
	var normalized := text.to_upper()
	if keyboard_prompt_texture_cache.has(normalized):
		return keyboard_prompt_texture_cache[normalized]
	var glyph_texture := name_texture(normalized, Color.WHITE)
	if glyph_texture == null:
		return null
	var glyph_image := glyph_texture.get_image()
	var padding := 2
	var image := Image.create(glyph_image.get_width() + padding * 2, glyph_image.get_height() + padding * 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	for y in glyph_image.get_height():
		for x in glyph_image.get_width():
			var glyph_color := glyph_image.get_pixel(x, y)
			if glyph_color.a > 0.0:
				image.set_pixel(x + padding, y + padding, glyph_color)
	var texture := ImageTexture.create_from_image(image)
	keyboard_prompt_texture_cache[normalized] = texture
	return texture


func name_texture(text: String, color: Color) -> Texture2D:
	var cache_key := "%s:%s" % [text, _rgb_key(color)]
	if name_texture_cache.has(cache_key):
		return name_texture_cache[cache_key]
	var glyphs := {"B": ["11110", "10001", "10001", "11110", "10001", "10001", "11110"], "E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"], "G": ["01110", "10001", "10000", "10111", "10001", "10001", "01110"], "N": ["10001", "11001", "10101", "10011", "10001", "10001", "10001"], "O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"], "R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"], "S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"], "T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"], "L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"], "V": ["10001", "10001", "10001", "10001", "01010", "01010", "00100"], "X": ["10001", "01010", "00100", "00100", "01010", "10001", "10001"], "Y": ["10001", "10001", "01010", "00100", "00100", "00100", "00100"], "?": ["01110", "10001", "00010", "00100", "00100", "00000", "00100"], "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"], "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"], "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"], "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"], "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"], "5": ["11111", "10000", "10000", "11110", "00001", "00001", "11110"], "6": ["01110", "10000", "10000", "11110", "10001", "10001", "01110"], "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"], "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"], "9": ["01110", "10001", "10001", "01111", "00001", "00001", "01110"], ".": ["0", "0", "0", "0", "0", "0", "1"], "d": ["00001", "00001", "01101", "10011", "10001", "10011", "01101"], "i": ["010", "000", "110", "010", "010", "010", "111"], "l": ["110", "010", "010", "010", "010", "010", "111"], "r": ["000", "000", "101", "110", "100", "100", "100"], "u": ["000", "000", "101", "101", "101", "111", "101"], "e": ["000", "000", "010", "101", "111", "100", "011"], "o": ["000", "000", "111", "101", "101", "101", "111"], "g": ["000", "000", "111", "101", "101", "111", "100"], "n": ["000", "000", "110", "101", "101", "101", "101"], "m": ["00000", "00000", "11011", "10101", "10101", "10101", "10101"], " ": ["0", "0", "0", "0", "0", "0", "0"]}
	glyphs["v"] = ["00000", "00000", "10001", "10001", "01010", "01010", "00100"]
	glyphs[":"] = ["0", "1", "0", "0", "0", "1", "0"]
	glyphs["-"] = ["000", "000", "000", "111", "000", "000", "000"]
	glyphs["A"] = ["00100", "01010", "10001", "10001", "11111", "10001", "10001"]
	glyphs["C"] = ["01110", "10001", "10000", "10000", "10000", "10001", "01110"]
	glyphs["D"] = ["11110", "10001", "10001", "10001", "10001", "10001", "11110"]
	glyphs["F"] = ["11111", "10000", "10000", "11110", "10000", "10000", "10000"]
	glyphs["H"] = ["10001", "10001", "10001", "11111", "10001", "10001", "10001"]
	glyphs["I"] = ["11111", "00100", "00100", "00100", "00100", "00100", "11111"]
	glyphs["J"] = ["00111", "00010", "00010", "00010", "10010", "10010", "01100"]
	glyphs["K"] = ["10001", "10010", "10100", "11000", "10100", "10010", "10001"]
	glyphs["M"] = ["10001", "11011", "10101", "10101", "10001", "10001", "10001"]
	glyphs["P"] = ["11110", "10001", "10001", "11110", "10000", "10000", "10000"]
	glyphs["Q"] = ["01110", "10001", "10001", "10001", "10101", "10010", "01101"]
	glyphs["U"] = ["10001", "10001", "10001", "10001", "10001", "10001", "01110"]
	glyphs["W"] = ["10001", "10001", "10001", "10101", "10101", "11011", "10001"]
	glyphs["Z"] = ["11111", "00001", "00010", "00100", "01000", "10000", "11111"]
	glyphs["a"] = ["00000", "00000", "01110", "00001", "01111", "10001", "01111"]
	glyphs["b"] = ["10000", "10000", "10110", "11001", "10001", "11001", "10110"]
	glyphs["c"] = ["00000", "00000", "01110", "10001", "10000", "10001", "01110"]
	glyphs["d"] = ["00001", "00001", "01101", "10011", "10001", "10011", "01101"]
	glyphs["e"] = ["00000", "00000", "01110", "10001", "11111", "10000", "01110"]
	glyphs["f"] = ["00110", "01001", "01000", "11100", "01000", "01000", "01000"]
	glyphs["g"] = ["00000", "00000", "01110", "10001", "01111", "00001", "01110"]
	glyphs["h"] = ["10000", "10000", "10110", "11001", "10001", "10001", "10001"]
	glyphs["i"] = ["00100", "00000", "01100", "00100", "00100", "00100", "01110"]
	glyphs["j"] = ["00010", "00000", "00110", "00010", "00010", "10010", "01100"]
	glyphs["k"] = ["10000", "10000", "10010", "10100", "11000", "10100", "10010"]
	glyphs["l"] = ["11000", "01000", "01000", "01000", "01000", "01000", "11100"]
	glyphs["m"] = ["00000", "00000", "11010", "10101", "10101", "10101", "10101"]
	glyphs["n"] = ["00000", "00000", "10110", "11001", "10001", "10001", "10001"]
	glyphs["o"] = ["00000", "00000", "01110", "10001", "10001", "10001", "01110"]
	glyphs["p"] = ["00000", "00000", "10110", "11001", "10001", "11001", "10110"]
	glyphs["q"] = ["00000", "00000", "01101", "10011", "10001", "10011", "01101"]
	glyphs["r"] = ["00000", "00000", "10110", "11001", "10000", "10000", "10000"]
	glyphs["s"] = ["00000", "00000", "01111", "10000", "01110", "00001", "11110"]
	glyphs["t"] = ["01000", "01000", "11100", "01000", "01001", "01001", "00110"]
	glyphs["u"] = ["00000", "00000", "10001", "10001", "10001", "10011", "01101"]
	glyphs["v"] = ["00000", "00000", "10001", "10001", "01010", "01010", "00100"]
	glyphs["w"] = ["00000", "00000", "10001", "10001", "10101", "10101", "01010"]
	glyphs["x"] = ["00000", "00000", "10001", "01010", "00100", "01010", "10001"]
	glyphs["y"] = ["00000", "00000", "10001", "10001", "01111", "00001", "01110"]
	glyphs["z"] = ["00000", "00000", "11111", "00010", "00100", "01000", "11111"]
	var compact_glyphs: Dictionary = {}
	for character in glyphs:
		compact_glyphs[character] = _compact_glyph_pattern(glyphs[character] as Array)
	var width := 0
	for character in text:
		width += (compact_glyphs.get(character, compact_glyphs[" "])[0] as String).length() + 1
	width = maxi(width - 1, 1)
	var image := Image.create(width, 7, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for character in text:
		var pattern: Array = compact_glyphs.get(character, compact_glyphs[" "])
		for y in 7:
			var row := pattern[y] as String
			for x in row.length():
				if row[x] == "1":
					image.set_pixel(x_offset + x, y, color)
		x_offset += (pattern[0] as String).length() + 1
	var texture := ImageTexture.create_from_image(image)
	name_texture_cache[cache_key] = texture
	return texture


func _compact_glyph_pattern(pattern: Array) -> Array:
	var min_x := 999
	var max_x := -1
	for row_value in pattern:
		var row := row_value as String
		for x in row.length():
			if row[x] == "1":
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
	if max_x < min_x:
		var empty_pattern: Array = []
		for _row in pattern.size():
			empty_pattern.append("0")
		return empty_pattern
	var compacted: Array = []
	for row_value in pattern:
		var row := row_value as String
		compacted.append(row.substr(min_x, max_x - min_x + 1))
	return compacted

func _rgb_key(color: Color) -> String:
	return "%02x%02x%02x%02x" % [roundi(color.r * 255.0), roundi(color.g * 255.0), roundi(color.b * 255.0), roundi(color.a * 255.0)]
