extends RefCounted
class_name MenuPromptTextureFactory

const MENU_CIRCLE_TEXTURE: Texture2D = preload("res://assets/artwork/circle55.png")
const MENU_X_TEXTURE: Texture2D = preload("res://assets/artwork/x55.png")
const MENU_TRIANGLE_TEXTURE: Texture2D = preload("res://assets/artwork/triangle55.png")
const MENU_SQUARE_TEXTURE: Texture2D = preload("res://assets/artwork/square55.png")

var _prompt_texture_cache: Dictionary = {}


func set_button_text(button: Button, label: String, pixel_texture: Callable, color: Color = Color.WHITE) -> void:
	if button == null:
		return
	var text := button.get_child(0) as Sprite2D
	if text == null:
		return
	var icon_texture: Texture2D = menu_face_texture_for_prompt(label)
	var shown_label: String = menu_face_label_without_icon(label) if icon_texture != null else label
	text.texture = pixel_texture.call(shown_label, color) as Texture2D
	set_menu_button_icon(button, icon_texture, icon_texture != null)


func menu_face_texture_for_prompt(label: String) -> Texture2D:
	if label.begins_with("O "):
		return MENU_CIRCLE_TEXTURE
	if label.begins_with("X "):
		return MENU_X_TEXTURE
	if label.begins_with("TRIANGLE "):
		return MENU_TRIANGLE_TEXTURE
	if label.begins_with("SQUARE "):
		return MENU_SQUARE_TEXTURE
	return null


## Composes a face-button glyph with its action label for pixel-sprite prompts.
func pixel_prompt_texture(pixel_texture: Callable, label: String, color: Color) -> Texture2D:
	var glyph := menu_face_texture_for_prompt(label)
	if glyph == null:
		return pixel_texture.call(label, color) as Texture2D
	var cache_key := "%s:%s" % [label, color.to_html(false)]
	if _prompt_texture_cache.has(cache_key):
		return _prompt_texture_cache[cache_key] as Texture2D
	var text_texture := pixel_texture.call(menu_face_label_without_icon(label), color) as Texture2D
	var glyph_image := glyph.get_image()
	var text_image := text_texture.get_image()
	var gap := 1
	var image := Image.create(glyph_image.get_width() + gap + text_image.get_width(), maxi(glyph_image.get_height(), text_image.get_height()), false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	image.blit_rect(glyph_image, Rect2i(Vector2i.ZERO, glyph_image.get_size()), Vector2i.ZERO)
	image.blit_rect(text_image, Rect2i(Vector2i.ZERO, text_image.get_size()), Vector2i(glyph_image.get_width() + gap, 0))
	var texture := ImageTexture.create_from_image(image)
	_prompt_texture_cache[cache_key] = texture
	return texture


func pixel_prompt_sequence_texture(pixel_texture: Callable, labels: Array[String], color: Color, gap: int = 5, glyph_gap: int = 1) -> Texture2D:
	if labels.is_empty():
		return null
	var cache_key := "sequence:%s:%s:%d:%d" % ["|".join(labels), color.to_html(false), gap, glyph_gap]
	if _prompt_texture_cache.has(cache_key):
		return _prompt_texture_cache[cache_key] as Texture2D
	var parts: Array[Dictionary] = []
	var total_width := 0
	var max_height := 1
	for label in labels:
		var glyph := menu_face_texture_for_prompt(label)
		var text_label := menu_face_label_without_icon(label) if glyph != null else label
		var text_texture := pixel_texture.call(text_label, color) as Texture2D
		if text_texture == null:
			continue
		var glyph_image: Image = glyph.get_image() if glyph != null else null
		var text_image := text_texture.get_image()
		var part_width := text_image.get_width()
		var part_height := text_image.get_height()
		if glyph_image != null:
			part_width += glyph_gap + glyph_image.get_width()
			part_height = maxi(part_height, glyph_image.get_height())
		parts.append({"glyph": glyph_image, "text": text_image, "width": part_width, "height": part_height})
		total_width += part_width
		max_height = maxi(max_height, part_height)
	if parts.is_empty():
		return null
	total_width += maxi(parts.size() - 1, 0) * gap
	var image := Image.create(total_width, max_height, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var x_offset := 0
	for part: Dictionary in parts:
		var glyph_image := part["glyph"] as Image
		var text_image := part["text"] as Image
		var part_height := int(part["height"])
		var y_offset := int(float(max_height - part_height) / 2.0)
		var text_x := x_offset
		if glyph_image != null:
			image.blit_rect(glyph_image, Rect2i(Vector2i.ZERO, glyph_image.get_size()), Vector2i(x_offset, y_offset))
			text_x += glyph_image.get_width() + glyph_gap
		image.blit_rect(text_image, Rect2i(Vector2i.ZERO, text_image.get_size()), Vector2i(text_x, y_offset))
		x_offset += int(part["width"]) + gap
	var texture := ImageTexture.create_from_image(image)
	_prompt_texture_cache[cache_key] = texture
	return texture


func menu_face_label_without_icon(label: String) -> String:
	if label.begins_with("O ") or label.begins_with("X "):
		return label.substr(2)
	if label.begins_with("TRIANGLE "):
		return label.substr(9)
	if label.begins_with("SQUARE "):
		return label.substr(7)
	return label


func set_menu_button_icon(button: Button, icon_texture: Texture2D, visible: bool) -> void:
	if button == null:
		return
	var text := button.get_child(0) as Sprite2D
	if text == null:
		return
	var icon: Sprite2D = button.get_node_or_null("MenuFaceIcon") as Sprite2D
	if icon == null:
		icon = Sprite2D.new()
		icon.name = "MenuFaceIcon"
		icon.centered = false
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.add_child(icon)
	icon.texture = icon_texture
	icon.visible = visible and icon_texture != null
	# Face art keeps its authored color while the surrounding button changes state.
	icon.modulate = Color.WHITE
	if icon.visible:
		var text_width: float = float(text.texture.get_width()) if text.texture != null else 0.0
		var group_width: float = 5.0 + 3.0 + text_width
		var start_x: float = floorf((button.size.x - group_width) * 0.5)
		icon.position = Vector2(start_x, floor((button.size.y - 5.0) * 0.5))
		text.centered = false
		text.position = Vector2(start_x + 8.0, floor((button.size.y - float(text.texture.get_height())) * 0.5))
	else:
		text.centered = true
		text.position = button.size * 0.5
