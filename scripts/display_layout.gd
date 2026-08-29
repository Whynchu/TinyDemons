extends RefCounted
class_name DisplayLayout

## Shared logical display geometry. A supported wide mode adds horizontal
## content only; the native 240×160 frame remains the zero-offset baseline.

const NATIVE_SIZE := Vector2i(240, 160)
const FULL_ASPECT := "FULL"
const ASPECT_SIZES := {
	"3:2": Vector2i(240, 160),
	"16:10": Vector2i(256, 160),
	"16:9": Vector2i(284, 160),
}

const ANCHOR_LEFT := &"left"
const ANCHOR_CENTER := &"center"
const ANCHOR_RIGHT := &"right"

const HUD_ANCHORS := {
	"player_status": ANCHOR_LEFT,
	"minimap": ANCHOR_LEFT,
	"room_number": ANCHOR_LEFT,
	"dungeon_run": ANCHOR_LEFT,
	"gold": ANCHOR_RIGHT,
	"souls": ANCHOR_RIGHT,
	"run_timer": ANCHOR_RIGHT,
	"ability_icons": ANCHOR_LEFT,
	# Compatibility alias for older callers; ability indicators now live beside
	# the authored PlayerStatus strip instead of in the old right-side rows.
	"cooldowns": ANCHOR_LEFT,
	"combo": ANCHOR_CENTER,
	"input_prompts": ANCHOR_RIGHT,
	"hp_mp": ANCHOR_CENTER,
	"target": ANCHOR_CENTER,
	"target_name": ANCHOR_CENTER,
	"focus": ANCHOR_CENTER,
}


static func view_size(aspect: String = "3:2", full_width: int = 0) -> Vector2i:
	if aspect == FULL_ASPECT:
		return Vector2i(maxi(full_width, NATIVE_SIZE.x), NATIVE_SIZE.y)
	return ASPECT_SIZES.get(aspect, NATIVE_SIZE) as Vector2i


static func is_full_aspect(aspect: String) -> bool:
	return aspect == FULL_ASPECT


static func extra_width(view_width: float) -> float:
	return maxf(view_width - float(NATIVE_SIZE.x), 0.0)


static func visible_size_for_window(window_size: Vector2, content_size: Vector2, preserve_height: bool) -> Vector2:
	if not preserve_height or window_size.x <= 0.0 or window_size.y <= 0.0:
		return content_size
	var expanded_width := content_size.y * window_size.x / window_size.y
	return Vector2(maxf(content_size.x, roundf(expanded_width)), content_size.y)


static func centered_origin(visible_size: Vector2, content_size: Vector2) -> Vector2:
	return Vector2(
		maxf((visible_size.x - content_size.x) * 0.5, 0.0),
		maxf((visible_size.y - content_size.y) * 0.5, 0.0))


static func left_x(_view_width: float) -> float:
	return 0.0


static func center_x(view_width: float) -> float:
	return extra_width(view_width) * 0.5


static func right_x(view_width: float) -> float:
	return extra_width(view_width)


static func top_y(_view_height: float) -> float:
	return 0.0


static func bottom_y(view_height: float) -> float:
	return maxf(view_height - float(NATIVE_SIZE.y), 0.0)


static func anchor_for(element: StringName) -> StringName:
	return HUD_ANCHORS.get(String(element), ANCHOR_LEFT) as StringName


static func offset_for_anchor(anchor: StringName, view_size_value: Vector2) -> Vector2:
	var width_offset := 0.0
	match anchor:
		ANCHOR_CENTER:
			width_offset = center_x(view_size_value.x)
		ANCHOR_RIGHT:
			width_offset = right_x(view_size_value.x)
	return Vector2(width_offset, 0.0)


static func offset_for(element: StringName, view_size_value: Vector2) -> Vector2:
	return offset_for_anchor(anchor_for(element), view_size_value)


static func position_for(base_position: Vector2, element: StringName, view_size_value: Vector2) -> Vector2:
	return base_position + offset_for(element, view_size_value)
