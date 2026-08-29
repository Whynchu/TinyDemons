extends RefCounted
class_name SoulVisuals

## The authored soul is a tiny indexed sprite. Keep its expressive pixels
## intact while adapting the neutral grey body and light outline to the soul
## currency colour used by the rest of the game.
const SOURCE_PATH := "res://assets/artwork/Souls.png"
const SOURCE_BODY_COLOR := Color8(86, 108, 134)
const SOURCE_OUTLINE_COLOR := Color8(148, 176, 194)
const SOURCE_EYE_COLOR := Color8(244, 244, 244)
const SOUL_COLOR := Color8(167, 59, 167)
const SOUL_HIGHLIGHT_COLOR := Color8(234, 122, 197)

static var _texture: Texture2D = null


static func texture() -> Texture2D:
	if _texture != null:
		return _texture
	var source := load(SOURCE_PATH) as Texture2D
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return source
	image = image.duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			if pixel.is_equal_approx(SOURCE_BODY_COLOR):
				image.set_pixel(x, y, Color(SOUL_COLOR.r, SOUL_COLOR.g, SOUL_COLOR.b, pixel.a))
			elif pixel.is_equal_approx(SOURCE_OUTLINE_COLOR):
				image.set_pixel(x, y, Color(SOUL_HIGHLIGHT_COLOR.r, SOUL_HIGHLIGHT_COLOR.g, SOUL_HIGHLIGHT_COLOR.b, pixel.a))
			elif pixel.is_equal_approx(SOURCE_EYE_COLOR):
				image.set_pixel(x, y, Color.WHITE)
	_texture = ImageTexture.create_from_image(image)
	return _texture
