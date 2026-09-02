extends RefCounted
class_name MenuResponsiveLayout

## Pixel-menu horizontal resolution shared by authored menu presenters.
## Artwork stays at its native scale; only its integer logical origin/edges are
## redistributed when the active logical surface is wider than the mockup.

const NATIVE_WIDTH := 240.0


static func proportional_x(native_x: float, view_width: float, authored_width: float = NATIVE_WIDTH) -> float:
	var extra_width := maxf(view_width - authored_width, 0.0)
	var weight := clampf(native_x / maxf(authored_width, 1.0), 0.0, 1.0)
	return roundf(native_x + extra_width * weight)


static func map_edge(native_edge: float, view_width: float, authored_width: float = NATIVE_WIDTH) -> float:
	return proportional_x(native_edge, view_width, authored_width)


static func map_rect(native_rect: Rect2, view_width: float, authored_width: float = NATIVE_WIDTH) -> Rect2:
	var left := map_edge(native_rect.position.x, view_width, authored_width)
	var right := map_edge(native_rect.end.x, view_width, authored_width)
	return Rect2(left, native_rect.position.y, maxf(right - left, 1.0), native_rect.size.y)
