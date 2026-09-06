extends RefCounted
class_name PuzzleMapGrid

## Data-first authoring support for the small isometric route-map images.
##
## A plan deliberately describes only pixels and marker meaning.  It does not
## create game rooms yet: that keeps map composition independently testable
## while the room/topology compiler is still being designed.

const COLOR_BACKGROUND := Color8(17, 19, 24)
const COLOR_GRID := Color8(26, 28, 44)
const COLOR_COMBAT := Color8(86, 108, 134)
const COLOR_INACTIVE_ROOM_DARK := Color8(43, 50, 68)
## Keep the construction grid darker than room tiles, but above the void
## background so its connector path remains visible in the design preview.
const COLOR_GRID_DARK := Color8(22, 25, 38)
const COLOR_GATE_GREY := Color8(51, 60, 87)
const COLOR_FLAME_A_GATE := Color8(59, 93, 201)
const COLOR_FLAME_B_GATE := Color8(56, 183, 100)
const COLOR_TRANSITION := Color8(148, 176, 194)
const COLOR_TREASURE := Color8(255, 205, 117)
const COLOR_FLAME_B := Color8(239, 125, 87)
const COLOR_CLOAKED := Color8(93, 39, 93)
const COLOR_ORB := Color8(115, 239, 247)
const COLOR_HUB := Color8(244, 244, 244)
const COLOR_BOSS := Color8(177, 62, 83)

const MARKER_GATE_GREY: StringName = &"gate_grey"
const MARKER_GATE_ORB_GREY: StringName = &"gate_orb_grey"
const MARKER_GATE_FLAME_A: StringName = &"gate_flame_a"
const MARKER_GATE_FLAME_B: StringName = &"gate_flame_b"
const MARKER_TREASURE_ROOM: StringName = &"treasure_room"
const MARKER_FLAME_B_ROOM: StringName = &"flame_b_room"
const MARKER_CLOAKED_ROOM: StringName = &"cloaked_room"
const MARKER_ORB_ROOM: StringName = &"orb_room"
const MARKER_HUB_ROOM: StringName = &"hub_room"
const MARKER_BOSS_ROOM: StringName = &"boss_room"

const MARKER_COLORS: Dictionary = {
	MARKER_GATE_GREY: COLOR_GATE_GREY,
	MARKER_GATE_ORB_GREY: COLOR_TRANSITION,
	MARKER_GATE_FLAME_A: COLOR_FLAME_A_GATE,
	MARKER_GATE_FLAME_B: COLOR_FLAME_B_GATE,
	MARKER_TREASURE_ROOM: COLOR_TREASURE,
	MARKER_FLAME_B_ROOM: COLOR_FLAME_B,
	MARKER_CLOAKED_ROOM: COLOR_CLOAKED,
	MARKER_ORB_ROOM: COLOR_ORB,
	MARKER_HUB_ROOM: COLOR_HUB,
	MARKER_BOSS_ROOM: COLOR_BOSS,
}

const COLOR_MARKERS: Dictionary = {
	COLOR_GATE_GREY: MARKER_GATE_GREY,
	COLOR_FLAME_A_GATE: MARKER_GATE_FLAME_A,
	COLOR_FLAME_B_GATE: MARKER_GATE_FLAME_B,
	COLOR_TRANSITION: MARKER_GATE_ORB_GREY,
	COLOR_TREASURE: MARKER_TREASURE_ROOM,
	COLOR_FLAME_B: MARKER_FLAME_B_ROOM,
	COLOR_CLOAKED: MARKER_CLOAKED_ROOM,
	COLOR_ORB: MARKER_ORB_ROOM,
	COLOR_HUB: MARKER_HUB_ROOM,
	COLOR_BOSS: MARKER_BOSS_ROOM,
}


class MapMarker:
	var coordinate: Vector2i
	var kind: StringName

	func _init(next_coordinate: Vector2i, next_kind: StringName) -> void:
		coordinate = next_coordinate
		kind = next_kind


class MapPlan:
	var id: StringName
	var markers: Array[MapMarker] = []
	## Plain active points are deliberately separate from the template's dark
	## connector lattice. The R3 image already carries its regular room/path
	## points in the original combat-grey swatch; future topology plans can add
	## explicit points here without brightening the whole construction grid.
	var active_tiles: Array[Vector2i] = []

	func _init(next_id: StringName = &"") -> void:
		id = next_id

	func add_marker(coordinate: Vector2i, kind: StringName) -> void:
		markers.append(MapMarker.new(coordinate, kind))

	func add_active_tile(coordinate: Vector2i) -> void:
		active_tiles.append(coordinate)

	func duplicate_plan(next_id: StringName = &"") -> MapPlan:
		var copy := MapPlan.new(next_id if not next_id.is_empty() else id)
		for coordinate in active_tiles:
			copy.add_active_tile(coordinate)
		for marker in markers:
			copy.add_marker(marker.coordinate, marker.kind)
		return copy

	func marker_count(kind: StringName) -> int:
		var count := 0
		for marker in markers:
			if marker.kind == kind:
				count += 1
		return count

	func has_marker(coordinate: Vector2i, kind: StringName) -> bool:
		for marker in markers:
			if marker.coordinate == coordinate and marker.kind == kind:
				return true
		return false


static func marker_color(kind: StringName) -> Color:
	var color: Color = MARKER_COLORS.get(kind, Color.TRANSPARENT)
	return color


static func marker_kind(color: Color) -> StringName:
	var kind: StringName = COLOR_MARKERS.get(color, &"")
	return kind


static func gate_requirement(kind: StringName) -> StringName:
	## This is presentation metadata for the later topology compiler. The dark
	## grey entrance and light-grey Orb door are intentionally different gates.
	if kind == MARKER_GATE_ORB_GREY:
		return &"orb_grey"
	if kind == MARKER_GATE_FLAME_A:
		return &"flame_a"
	if kind == MARKER_GATE_FLAME_B:
		return &"flame_b"
	return &""


static func is_gate_marker(kind: StringName) -> bool:
	return kind == MARKER_GATE_GREY or kind == MARKER_GATE_ORB_GREY or kind == MARKER_GATE_FLAME_A or kind == MARKER_GATE_FLAME_B


static func gate_endpoints(coordinate: Vector2i) -> Array[Vector2i]:
	return _gate_endpoints(coordinate)


static func active_room_coordinates(plan: MapPlan) -> Dictionary:
	var active: Dictionary = {}
	if plan == null:
		return active
	for coordinate in plan.active_tiles:
		active[coordinate] = true
	for marker in plan.markers:
		if marker == null:
			continue
		if is_gate_marker(marker.kind):
			var endpoints: Array[Vector2i] = _gate_endpoints(marker.coordinate)
			for endpoint in endpoints:
				active[endpoint] = true
		else:
			# A colored room marker is populated by definition, even if its
			# future topology edge is authored in a separate connection list.
			active[marker.coordinate] = true
	return active


static func render(plan: MapPlan, template: Image) -> Image:
	if plan == null or template == null:
		return null
	var map_image := template.duplicate()
	for marker in plan.markers:
		if marker == null or not _contains(map_image, marker.coordinate):
			continue
		var color := marker_color(marker.kind)
		if color.a == 0.0:
			continue
		map_image.set_pixelv(marker.coordinate, color)
	return map_image


static func render_preview(plan: MapPlan, template: Image) -> Image:
	## Preview mode makes the authored route read clearly: only the construction
	## connector lattice is dimmed. Regular room/path tiles retain their original
	## combat-grey swatch, and authored gate/room markers draw above everything.
	if plan == null or template == null:
		return null
	var map_image := template.duplicate()
	var active_rooms: Dictionary = active_room_coordinates(plan)
	var marker_coordinates: Dictionary = {}
	for marker in plan.markers:
		if marker != null:
			marker_coordinates[marker.coordinate] = true
	for y in map_image.get_height():
		for x in map_image.get_width():
			var pixel: Color = map_image.get_pixel(x, y)
			if pixel == COLOR_GRID:
				map_image.set_pixel(x, y, COLOR_GRID_DARK)
			elif pixel == COLOR_COMBAT and not active_rooms.has(Vector2i(x, y)):
				map_image.set_pixel(x, y, COLOR_INACTIVE_ROOM_DARK)
	for coordinate in plan.active_tiles:
		if _contains(map_image, coordinate):
			map_image.set_pixelv(coordinate, COLOR_COMBAT)
	# Active room slots that are not themselves authored markers are endpoints of
	# an authored connection; they keep the original combat-grey swatch instead
	# of the dimmed placeholder. Marker coordinates are drawn on top below.
	for coordinate in active_rooms:
		if marker_coordinates.has(coordinate):
			continue
		if _contains(map_image, coordinate):
			map_image.set_pixelv(coordinate, COLOR_COMBAT)
	for marker in plan.markers:
		if marker == null or not _contains(map_image, marker.coordinate):
			continue
		var color := marker_color(marker.kind)
		if color.a > 0.0:
			map_image.set_pixelv(marker.coordinate, color)
	return map_image


static func parse(reference: Image, template: Image, plan_id: StringName = &"") -> MapPlan:
	if reference == null or template == null or reference.get_size() != template.get_size():
		return null
	var plan := MapPlan.new(plan_id)
	for y in reference.get_height():
		for x in reference.get_width():
			var coordinate := Vector2i(x, y)
			var reference_color: Color = reference.get_pixelv(coordinate)
			if reference_color == template.get_pixelv(coordinate):
				continue
			var kind := marker_kind(reference_color)
			if not kind.is_empty():
				plan.add_marker(coordinate, kind)
	return plan


static func validate(plan: MapPlan, template: Image) -> PackedStringArray:
	var failures := PackedStringArray()
	if plan == null:
		failures.append("Map plan is missing.")
		return failures
	if template == null:
		failures.append("Map template is missing.")
		return failures
	var occupied: Dictionary = {}
	var active_tiles: Dictionary = {}
	for coordinate in plan.active_tiles:
		if not _contains(template, coordinate):
			failures.append("Active tile %s is outside the %s template." % [coordinate, template.get_size()])
			continue
		if active_tiles.has(coordinate):
			failures.append("Multiple active tiles occupy %s." % coordinate)
			continue
		active_tiles[coordinate] = true
		if template.get_pixelv(coordinate) == COLOR_BACKGROUND:
			failures.append("Active tile %s is not placed on the map grid." % coordinate)
	for marker in plan.markers:
		if marker == null:
			failures.append("Map plan contains an empty marker.")
			continue
		if not MARKER_COLORS.has(marker.kind):
			failures.append("Unknown marker kind '%s' at %s." % [marker.kind, marker.coordinate])
			continue
		if not _contains(template, marker.coordinate):
			failures.append("Marker %s is outside the %s template." % [marker.coordinate, template.get_size()])
			continue
		if occupied.has(marker.coordinate):
			failures.append("Multiple markers occupy %s." % marker.coordinate)
			continue
		occupied[marker.coordinate] = true
		if template.get_pixelv(marker.coordinate) == COLOR_BACKGROUND:
			failures.append("Marker %s is not placed on the map grid." % marker.coordinate)
	return failures


static func _contains(image: Image, coordinate: Vector2i) -> bool:
	return coordinate.x >= 0 and coordinate.y >= 0 and coordinate.x < image.get_width() and coordinate.y < image.get_height()


static func _gate_endpoints(coordinate: Vector2i) -> Array[Vector2i]:
	## The 35 x 35 construction grid alternates room slots every other row.
	## A gate occupies the diagonal midpoint between the two valid room slots.
	var first_pair: Array[Vector2i] = [Vector2i(coordinate.x - 1, coordinate.y - 1), Vector2i(coordinate.x + 1, coordinate.y + 1)]
	if _is_room_slot(first_pair[0]) and _is_room_slot(first_pair[1]):
		return first_pair
	var second_pair: Array[Vector2i] = [Vector2i(coordinate.x - 1, coordinate.y + 1), Vector2i(coordinate.x + 1, coordinate.y - 1)]
	if _is_room_slot(second_pair[0]) and _is_room_slot(second_pair[1]):
		return second_pair
	return []


static func _is_room_slot(coordinate: Vector2i) -> bool:
	return coordinate.x % 2 != 0 and coordinate.y % 2 != 0 and posmod(coordinate.x - coordinate.y, 4) == 0
