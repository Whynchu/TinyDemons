@tool
extends NinePatchRect
class_name MenuWindow

## Shared pixel-art window. Layout and content belong to the composing screen.
const FRAME_TEXTURE: Texture2D = preload("res://assets/artwork/frame 16x16.png")
const FRAME_MARGIN := 3


static func panel_style() -> StyleBoxTexture:
	# Older Panel widgets can share the skin while preserving their node types.
	var style := StyleBoxTexture.new()
	style.texture = FRAME_TEXTURE
	style.texture_margin_left = FRAME_MARGIN
	style.texture_margin_top = FRAME_MARGIN
	style.texture_margin_right = FRAME_MARGIN
	style.texture_margin_bottom = FRAME_MARGIN
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	return style


func _init() -> void:
	apply_skin()


func _ready() -> void:
	apply_skin()


func apply_skin() -> void:
	texture = FRAME_TEXTURE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch_margin_left = FRAME_MARGIN
	patch_margin_top = FRAME_MARGIN
	patch_margin_right = FRAME_MARGIN
	patch_margin_bottom = FRAME_MARGIN
	axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
