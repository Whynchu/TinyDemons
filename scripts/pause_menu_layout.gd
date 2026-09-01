extends RefCounted
class_name PauseMenuLayout

## Canonical 240x160 pause-menu geometry. The display system may widen the
## logical surface in FULL mode, but the left content and the 64px right rail
## retain these authored margins and rows.
const NATIVE_WIDTH: float = 240.0
const NATIVE_HEIGHT: float = 160.0
const LEFT_PANEL_WIDTH: float = 176.0
const FIXED_RAIL_WIDTH: float = 64.0
const RESOURCE_PANEL_HEIGHT: float = 24.0

const PLAYER_PORTRAIT_POSITION := Vector2(10.0, 26.0)
const PLAYER_CARD_TEXT_POSITIONS: Array[Vector2] = [
	Vector2(43.0, 29.0),
	Vector2(88.0, 29.0),
	Vector2(88.0, 37.0),
	Vector2(138.0, 37.0),
	Vector2(88.0, 45.0),
	Vector2(138.0, 45.0),
	Vector2(138.0, 29.0),
]

const COMMAND_BUTTON_SIZE := Vector2(54.0, 12.0)
const COMMAND_FIRST_BUTTON_Y: float = 7.0
const COMMAND_ROW_PITCH: float = 14.0
const COMMAND_RAIL_INSET_X: float = 5.0

const SELECT_PROMPT_X: float = 104.0
const FOOTER_TEXT_BOTTOM_INSET: float = 11.0
const BACK_BUTTON_SIZE := Vector2(48.0, 13.0)
const BACK_BUTTON_POSITION_X: float = 128.0
const BACK_BUTTON_BOTTOM_INSET: float = 15.0
## The bottom prompt pair is anchored to the right rail (divider) so it keeps
## its native relative spacing as the logical width widens. SELECT sits on the
## left and the framed BACK button on the right, matching the mockup, and the
## pair stays just left of the resource rail.
const SELECT_LEFT_OF_RAIL: float = 72.0
const BACK_LEFT_OF_RAIL: float = 48.0

const RESOURCE_ICON_INSET_X: float = 6.0
const RESOURCE_TEXT_RIGHT_INSET: float = 6.0
const GOLD_ROW_BOTTOM_INSET: float = 18.0
const SOUL_ROW_BOTTOM_INSET: float = 11.0

const MUTED_TEXT_COLOR := Color8(148, 176, 194)
const GOLD_TEXT_COLOR := Color8(255, 205, 117)


static func divider_x(view_width: float) -> float:
	return maxf(view_width - FIXED_RAIL_WIDTH, LEFT_PANEL_WIDTH)


static func rail_width(view_width: float) -> float:
	return maxf(view_width - divider_x(view_width), 1.0)


static func upper_rail_height(view_height: float) -> float:
	return maxf(view_height - RESOURCE_PANEL_HEIGHT, 1.0)


static func command_button_position(view_size: Vector2, index: int) -> Vector2:
	return Vector2(divider_x(view_size.x) + COMMAND_RAIL_INSET_X, COMMAND_FIRST_BUTTON_Y + index * COMMAND_ROW_PITCH)


static func command_center_x(view_width: float) -> float:
	return divider_x(view_width) + rail_width(view_width) * 0.5


static func command_label_position(view_size: Vector2, index: int, texture_width: float) -> Vector2:
	var center_x := command_center_x(view_size.x)
	return Vector2(floorf(center_x - (texture_width - 1.0) * 0.5), COMMAND_FIRST_BUTTON_Y + index * COMMAND_ROW_PITCH + 3.0)


static func select_prompt_position(view_size: Vector2) -> Vector2:
	return Vector2(divider_x(view_size.x) - SELECT_LEFT_OF_RAIL, view_size.y - FOOTER_TEXT_BOTTOM_INSET)


static func back_button_position(view_size: Vector2) -> Vector2:
	var divider := divider_x(view_size.x)
	return Vector2(divider - BACK_LEFT_OF_RAIL, view_size.y - BACK_BUTTON_BOTTOM_INSET)


static func resource_icon_position(view_size: Vector2, soul: bool) -> Vector2:
	var bottom_inset := SOUL_ROW_BOTTOM_INSET if soul else GOLD_ROW_BOTTOM_INSET
	return Vector2(divider_x(view_size.x) + RESOURCE_ICON_INSET_X, view_size.y - bottom_inset)


static func resource_text_position(view_size: Vector2, texture_width: float, soul: bool) -> Vector2:
	var bottom_inset := SOUL_ROW_BOTTOM_INSET if soul else GOLD_ROW_BOTTOM_INSET
	return Vector2(view_size.x - texture_width - RESOURCE_TEXT_RIGHT_INSET, view_size.y - bottom_inset)
