extends Node2D
class_name HubStoneAccentLayer

## Fixed composition for the original Hub room reference and sparse, bounded
## non-Hub room variants.
##
## Positions are texture origins in the 240x160 reference frame. The source
## sprites use authored texture-origin placement. Hub entries show every
## placement exactly; other room entries hide 3 to 5 whole pairs and may move
## the survivors by a few seeded pixels. The Hub is intentionally never passed
## through the procedural candidate search so it remains the visual reference.

const HUB_ROOM_TYPE: StringName = &"START"
const BASE_ALPHA: float = 128.0 / 255.0
const SPECULAR_ALPHA: float = 38.0 / 255.0
const NON_HUB_REMOVAL_MIN: int = 3
const NON_HUB_REMOVAL_MAX: int = 4
const ROOM_VARIATION_SALT: int = 0x53544F4E
const POSITION_VARIATION_SALT: int = 0x504F5349
const ANCHOR_SWAP_SALT: int = 0x53574150
const LAYOUT_VARIATION_SALT: int = 0x4C41594F
const MAX_LAYOUT_VARIANT_ATTEMPTS: int = 32
const MAX_WALL_JITTER: int = 2
const MAX_FLOOR_JITTER: int = 2
const DOOR_CLEARANCE: float = 2.0
const FLOOR_CLEARANCE: int = 2
const WALL_EDGE_BUFFER: float = 2.0
const MIN_SWAPPABLE_GROUP_SIZE: int = 2
const MAX_SAFE_ANCHOR_MAPS: int = 8
const RIGHT_OUTER_WALL_STONE_ID: StringName = &"WallStone_05_right"

## These are the authored wall lanes, inset from the demonstrated room edges.
## Wall pieces only move vertically, so keeping their x ranges fixed preserves
## the reference density while the brick-only inset supplies a two-pixel wall
## solver buffer. Cracks keep the full authored lane because their anchors are
## fixed.
const WALL_SAFE_BOUNDS := {
	&"left": Rect2(50.0, 38.0, 70.0, 48.0),
	&"right": Rect2(138.0, 38.0, 56.0, 48.0),
}

const BLOCKING_SPRITE_PATHS := [
	"FloorTiles/Entrance",
	"FloorTiles/Entrance/Tile 2",
	"FloorTiles/EntranceRight",
	"FloorTiles/EntranceRight/Tile 2",
	"Walls/DoorLeft",
	"Walls/DoorRight",
]
const BLOCKING_GUIDE_PATHS := [
	"FloorTiles/Entrance/EntranceReturnGuide",
	"FloorTiles/EntranceRight/EntranceReturnGuide",
	"Walls/DoorLeft/DoorExitGuide",
	"Walls/DoorRight/DoorExitGuide",
]

const REFERENCE_PLACEMENTS: Array[Dictionary] = [
	{
		"id": &"FloorStone_01",
		"surface": &"floor",
		"side": &"none",
		"texture": "res://assets/artwork/Stone_accents/FloorStone_01.png",
		"position": Vector2(74, 75),
		"specular_texture": "",
		"specular_position": Vector2.ZERO,
	},
	{
		"id": &"FloorStone_02",
		"surface": &"floor",
		"side": &"none",
		"texture": "res://assets/artwork/Stone_accents/FloorStone_02.png",
		"position": Vector2(138, 64),
		"specular_texture": "",
		"specular_position": Vector2.ZERO,
	},
	{
		"id": &"FloorStone_03",
		"surface": &"floor",
		"side": &"none",
		"texture": "res://assets/artwork/Stone_accents/FloorStone_03.png",
		"position": Vector2(130, 94),
		"specular_texture": "",
		"specular_position": Vector2.ZERO,
	},
	{
		"id": &"FloorStone_04",
		"surface": &"floor",
		"side": &"none",
		"texture": "res://assets/artwork/Stone_accents/FloorStone_04.png",
		"position": Vector2(158, 83),
		"specular_texture": "",
		"specular_position": Vector2.ZERO,
	},
	{
		"id": &"WallCrack_01_left",
		"surface": &"wall",
		"side": &"left",
		"texture": "res://assets/artwork/Stone_accents/WallCrack_01_left.png",
		"position": Vector2(87, 40),
		"specular_texture": "res://assets/artwork/Stone_accents/WallCrack_01_Specular_left.png",
		"specular_position": Vector2(87, 39),
	},
	{
		"id": &"WallCrack_02_left",
		"surface": &"wall",
		"side": &"left",
		"texture": "res://assets/artwork/Stone_accents/WallCrack_02_left.png",
		"position": Vector2(112, 44),
		"specular_texture": "",
		"specular_position": Vector2.ZERO,
	},
	{
		"id": &"WallCrack_03_right",
		"surface": &"wall",
		"side": &"right",
		"texture": "res://assets/artwork/Stone_accents/WallCrack_03_right.png",
		"position": Vector2(148, 56),
		"specular_texture": "res://assets/artwork/Stone_accents/WallCrack_03_Specular_right.png",
		"specular_position": Vector2(148, 56),
	},
	{
		"id": &"WallStone_01_left",
		"surface": &"wall",
		"side": &"left",
		"texture": "res://assets/artwork/Stone_accents/WallStone_01_left.png",
		"position": Vector2(71, 47),
		"specular_texture": "res://assets/artwork/Stone_accents/WallStone_01_Specular_left.png",
		"specular_position": Vector2(70, 48),
	},
	{
		"id": &"WallStone_02_left",
		"surface": &"wall",
		"side": &"left",
		"texture": "res://assets/artwork/Stone_accents/WallStone_02_left.png",
		"position": Vector2(113, 38),
		"specular_texture": "res://assets/artwork/Stone_accents/WallStone_02_Specular_left.png",
		"specular_position": Vector2(112, 39),
	},
	{
		"id": &"WallStone_03_right",
		"surface": &"wall",
		"side": &"right",
		"texture": "res://assets/artwork/Stone_accents/WallStone_03_right.png",
		"position": Vector2(145, 40),
		"specular_texture": "res://assets/artwork/Stone_accents/WallStone_03_Specular_right.png",
		"specular_position": Vector2(144, 41),
	},
	{
		"id": &"WallStone_04_right",
		"surface": &"wall",
		"side": &"right",
		"texture": "res://assets/artwork/Stone_accents/WallStone_04_right.png",
		"position": Vector2(159, 59),
		"specular_texture": "res://assets/artwork/Stone_accents/WallStone_04_Specular_right.png",
		"specular_position": Vector2(158, 60),
	},
	{
		"id": &"WallStone_05_right",
		"surface": &"wall",
		"side": &"right",
		"texture": "res://assets/artwork/Stone_accents/WallStone_05_right.png",
		"position": Vector2(177, 68),
		"specular_texture": "res://assets/artwork/Stone_accents/WallStone_05_Specular_right.png",
		"specular_position": Vector2(176, 69),
	},
	{
		"id": &"WallStone_06_left",
		"surface": &"wall",
		"side": &"left",
		"texture": "res://assets/artwork/Stone_accents/WallStone_06_left.png",
		"position": Vector2(58, 69),
		"specular_texture": "res://assets/artwork/Stone_accents/WallStone_06_Specular_left.png",
		"specular_position": Vector2(57, 70),
	},
]

var base_sprites: Array[Sprite2D] = []
var specular_sprites: Array[Sprite2D] = []
var base_sprites_by_id: Dictionary = {}
var specular_sprites_by_id: Dictionary = {}
var placements_by_id: Dictionary = {}
var footprints_by_id: Dictionary = {}
var dungeon_seed: int = 0
var sprites_built: bool = false
var floor_boundary_polygon := PackedVector2Array()
var door_block_points: Array[Vector2] = []
var door_blocked_point_lookup: Dictionary = {}
var door_block_polygons: Array[PackedVector2Array] = []
var opaque_texture_points_cache: Dictionary = {}
var placement_static_fit_cache: Dictionary = {}
var candidate_offsets_cache: Dictionary = {}
var translated_footprint_cache: Dictionary = {}
var current_constraint_signature := ""
var last_room_id: StringName = &""
var last_room_type: StringName = &""
var last_selected_ids: Array[StringName] = []
var last_visible_ids: Array[StringName] = []
var last_anchor_positions: Dictionary = {}
var last_positions: Dictionary = {}
var room_tint := Color.WHITE
var active_layout_variant: int = 0
var pending_layout_variant: int = 0
var pending_room_id: StringName = &""
var pending_room_type: StringName = &""
var pending_placement_ids: Array[StringName] = []
var pending_room_entry := false
var last_committed_room_id: StringName = &""
var last_committed_room_type: StringName = &""
var last_layout_signature := ""
var previous_layout_signature := ""
var previous_layout_positions: Dictionary = {}
var layout_variants_by_room: Dictionary = {}


func _ready() -> void:
	visible = false


func configure_dungeon_seed(seed_value: int) -> void:
	if dungeon_seed == seed_value:
		return
	dungeon_seed = seed_value
	layout_variants_by_room.clear()
	last_committed_room_id = &""
	last_committed_room_type = &""
	last_layout_signature = ""
	previous_layout_signature = ""
	previous_layout_positions.clear()
	pending_room_entry = false


func apply_room_tint(tint: Color) -> void:
	room_tint = tint
	for sprite in base_sprites:
		if sprite != null and is_instance_valid(sprite):
			sprite.self_modulate = _accent_modulate(BASE_ALPHA)
	for sprite in specular_sprites:
		if sprite != null and is_instance_valid(sprite):
				sprite.self_modulate = _accent_modulate(SPECULAR_ALPHA)


func prewarm_current_constraint_candidates() -> void:
	# The candidate space is deliberately tiny and finite. Populate its static
	# edge/door results while the loading screen is visible so room entry only
	# chooses among cached candidates and applies sprite transforms.
	build_reference()
	_refresh_room_constraints()
	for placement in REFERENCE_PLACEMENTS:
		var placement_id: StringName = placement["id"]
		var anchors: Array[Vector2] = [placement["position"] as Vector2]
		if _placement_allows_anchor_swap(placement_id):
			anchors.clear()
			var group_key := _reposition_group_key(placement)
			for destination in REFERENCE_PLACEMENTS:
				var destination_id: StringName = destination["id"]
				if _placement_allows_anchor_swap(destination_id) and _reposition_group_key(destination) == group_key:
					anchors.append(destination["position"] as Vector2)
		for anchor in anchors:
			for offset in _all_candidate_offsets(placement_id):
				_cache_static_fit(placement, anchor + offset)


func _accent_modulate(alpha: float) -> Color:
	return Color(room_tint.r, room_tint.g, room_tint.b, alpha * room_tint.a)


func on_room_entered(room_id: StringName, room_type: StringName) -> void:
	build_reference()
	var same_pending_entry := pending_room_entry and pending_room_id == room_id and pending_room_type == room_type
	if not same_pending_entry:
		var is_same_committed_room := last_committed_room_id == room_id and last_committed_room_type == room_type
		previous_layout_signature = "" if is_same_committed_room else last_layout_signature
		previous_layout_positions = {} if is_same_committed_room else last_positions.duplicate(true)
		pending_room_id = room_id
		pending_room_type = room_type
		pending_layout_variant = int(layout_variants_by_room.get(_room_layout_key(room_id, room_type), active_layout_variant if is_same_committed_room else 0))
		active_layout_variant = pending_layout_variant
		pending_placement_ids = _placement_ids_for_room(room_id, room_type, active_layout_variant)
		pending_room_entry = true
		_apply_provisional_room_placements(pending_placement_ids, room_id, room_type)
	visible = true


## RoomController emits its entry signal before GameplayState applies the
## authored room geometry. GameplayState calls this once more after the floor
## polygon and door positions are live, so non-Hub placement uses the actual
## layout currently on screen.
func refresh_current_room(room_id: StringName, room_type: StringName) -> void:
	build_reference()
	var is_same_committed_room := last_committed_room_id == room_id and last_committed_room_type == room_type
	if not pending_room_entry or pending_room_id != room_id or pending_room_type != room_type:
		previous_layout_signature = "" if is_same_committed_room else last_layout_signature
		previous_layout_positions = {} if is_same_committed_room else last_positions.duplicate(true)
		pending_room_id = room_id
		pending_room_type = room_type
		pending_layout_variant = int(layout_variants_by_room.get(_room_layout_key(room_id, room_type), active_layout_variant if is_same_committed_room else 0))
		active_layout_variant = pending_layout_variant
		pending_placement_ids = _placement_ids_for_room(room_id, room_type, active_layout_variant)
		pending_room_entry = true
	_refresh_room_constraints()
	var placement_ids := pending_placement_ids
	var attempt := 0
	var signature := ""
	while true:
		active_layout_variant = pending_layout_variant
		_apply_room_placements(placement_ids, room_id, room_type)
		signature = _layout_signature()
		var needs_distinct_layout := not is_same_committed_room and room_type != HUB_ROOM_TYPE and not previous_layout_signature.is_empty()
		var density_is_valid := room_type == HUB_ROOM_TYPE or last_visible_ids.size() >= REFERENCE_PLACEMENTS.size() - NON_HUB_REMOVAL_MAX
		var swap_contract_is_valid := room_type == HUB_ROOM_TYPE or anchor_swaps_valid()
		if ((not needs_distinct_layout or signature != previous_layout_signature) and density_is_valid and swap_contract_is_valid) or attempt >= MAX_LAYOUT_VARIANT_ATTEMPTS:
			break
		attempt += 1
		pending_layout_variant += 1
		active_layout_variant = pending_layout_variant
		placement_ids = _placement_ids_for_room(room_id, room_type, active_layout_variant)
		pending_placement_ids = placement_ids
	last_layout_signature = signature
	last_committed_room_id = room_id
	last_committed_room_type = room_type
	layout_variants_by_room[_room_layout_key(room_id, room_type)] = active_layout_variant
	pending_room_entry = false
	visible = true


func _room_layout_key(room_id: StringName, room_type: StringName) -> String:
	return "%s|%s" % [room_id, room_type]


func _apply_provisional_room_placements(placement_ids: Array[StringName], room_id: StringName, room_type: StringName) -> void:
	last_room_id = room_id
	last_room_type = room_type
	last_selected_ids = placement_ids.duplicate()
	last_visible_ids.clear()
	last_anchor_positions.clear()
	last_positions.clear()
	for placement_id in placement_ids:
		last_visible_ids.append(placement_id)
	for placement in REFERENCE_PLACEMENTS:
		var id: StringName = placement["id"]
		var authored_position: Vector2 = placement["position"]
		var base_sprite := base_sprites_by_id.get(id) as Sprite2D
		var specular_sprite := specular_sprites_by_id.get(id) as Sprite2D
		var is_visible := placement_ids.has(id)
		if base_sprite != null:
			base_sprite.position = authored_position
			base_sprite.visible = is_visible
		if specular_sprite != null:
			specular_sprite.position = placement["specular_position"]
			specular_sprite.visible = is_visible
		if is_visible:
			last_anchor_positions[id] = authored_position
			last_positions[id] = authored_position


func build_reference() -> void:
	if sprites_built:
		return

	for placement in REFERENCE_PLACEMENTS:
		placements_by_id[placement["id"]] = placement
		var base_sprite := _make_sprite(
			placement["id"],
			placement["texture"],
			placement["position"],
			BASE_ALPHA,
			0,
		)
		add_child(base_sprite)
		base_sprites.append(base_sprite)
		base_sprites_by_id[placement["id"]] = base_sprite

		var specular_sprite: Sprite2D = null
		var specular_texture: String = placement["specular_texture"]
		if not specular_texture.is_empty():
			specular_sprite = _make_sprite(
				StringName("%s_Specular" % String(placement["id"])),
				specular_texture,
				placement["specular_position"],
				SPECULAR_ALPHA,
				1,
			)
			add_child(specular_sprite)
			specular_sprites.append(specular_sprite)
			specular_sprites_by_id[placement["id"]] = specular_sprite
		footprints_by_id[placement["id"]] = _build_placement_footprint(base_sprite, specular_sprite, placement)

	sprites_built = true


func reference_placement_count() -> int:
	return REFERENCE_PLACEMENTS.size()


func base_sprite_count() -> int:
	return base_sprites.size()


func specular_sprite_count() -> int:
	return specular_sprites.size()


func visible_base_sprite_count() -> int:
	var count := 0
	for sprite in base_sprites:
		if sprite.visible:
			count += 1
	return count


func visible_specular_sprite_count() -> int:
	var count := 0
	for sprite in specular_sprites:
		if sprite.visible:
			count += 1
	return count


func visible_placement_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for placement in REFERENCE_PLACEMENTS:
		var id: StringName = placement["id"]
		var sprite := base_sprites_by_id.get(id) as Sprite2D
		if sprite != null and sprite.visible:
			result.append(id)
	return result


func visible_placement_positions() -> Dictionary:
	return last_positions.duplicate(true)


func visible_placement_anchor_positions() -> Dictionary:
	return last_anchor_positions.duplicate(true)


func anchor_position_for(placement_id: StringName) -> Vector2:
	return last_anchor_positions.get(placement_id, Vector2.ZERO) as Vector2


func position_for(placement_id: StringName) -> Vector2:
	return last_positions.get(placement_id, Vector2.ZERO) as Vector2


func layout_signature() -> String:
	return _layout_signature()


func _layout_signature() -> String:
	var parts := PackedStringArray()
	for placement in REFERENCE_PLACEMENTS:
		var id: StringName = placement["id"]
		if not last_positions.has(id):
			continue
		parts.append("%s@%s#%s" % [id, last_anchor_positions.get(id, placement["position"]), last_positions[id]])
	return "|".join(parts)


func shared_movable_position_change_ratio() -> float:
	var shared_count := 0
	var changed_count := 0
	for placement_id in last_positions:
		if _is_crack_placement(placement_id) or not previous_layout_positions.has(placement_id):
			continue
		shared_count += 1
		if not (last_positions[placement_id] as Vector2).is_equal_approx(previous_layout_positions[placement_id] as Vector2):
			changed_count += 1
	return 1.0 if shared_count == 0 else float(changed_count) / float(shared_count)


func placement_constraints_valid() -> bool:
	if last_room_type == HUB_ROOM_TYPE:
		return true
	var occupied_points: Dictionary = {}
	for placement in REFERENCE_PLACEMENTS:
		var id: StringName = placement["id"]
		if not last_positions.has(id):
			continue
		var position: Vector2 = last_positions[id]
		if not _placement_fits(placement, position, occupied_points):
			return false
		_add_footprint_to_occupancy(id, position, occupied_points)
	return true


func anchor_swaps_valid() -> bool:
	if last_room_type == HUB_ROOM_TYPE:
		return true
	var groups: Dictionary = {}
	for placement_id in last_selected_ids:
		if not _placement_allows_anchor_swap(placement_id):
			continue
		var placement := _placement_for_id(placement_id)
		var group_key := _reposition_group_key(placement)
		if not groups.has(group_key):
			groups[group_key] = []
		(groups[group_key] as Array).append(placement_id)
	for group_ids_value in groups.values():
		var group_ids := group_ids_value as Array
		if group_ids.size() < MIN_SWAPPABLE_GROUP_SIZE:
			return false
		var used_anchors: Array[Vector2] = []
		for placement_id in group_ids:
			if not last_positions.has(placement_id) or not last_anchor_positions.has(placement_id):
				return false
			var placement := _placement_for_id(placement_id)
			var authored_position: Vector2 = placement["position"]
			var anchor_position: Vector2 = last_anchor_positions[placement_id]
			if anchor_position == authored_position or used_anchors.has(anchor_position):
				return false
			used_anchors.append(anchor_position)
	return true


func removed_count_for_room(room_id: StringName, room_type: StringName) -> int:
	if last_room_id == room_id and last_room_type == room_type:
		return REFERENCE_PLACEMENTS.size() - last_visible_ids.size()
	return REFERENCE_PLACEMENTS.size() - _placement_ids_for_room(room_id, room_type).size()


func reference_placements() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for placement in REFERENCE_PLACEMENTS:
		result.append(placement.duplicate(true))
	return result


func _placement_ids_for_room(room_id: StringName, room_type: StringName, layout_variant: int = 0) -> Array[StringName]:
	var candidate_ids: Array[StringName] = []
	for placement in REFERENCE_PLACEMENTS:
		candidate_ids.append(placement["id"])

	if room_type == HUB_ROOM_TYPE:
		return candidate_ids

	var room_rng := RandomNumberGenerator.new()
	room_rng.seed = int(dungeon_seed) ^ String(room_id).hash() ^ String(room_type).hash() ^ ROOM_VARIATION_SALT ^ (layout_variant * LAYOUT_VARIATION_SALT)
	var removal_count := room_rng.randi_range(NON_HUB_REMOVAL_MIN, NON_HUB_REMOVAL_MAX)
	for _index in removal_count:
		var removable_ids: Array[StringName] = []
		for candidate_id in candidate_ids:
			if _can_remove_from_sparse_selection(candidate_ids, candidate_id):
				removable_ids.append(candidate_id)
		if removable_ids.is_empty():
			break
		candidate_ids.erase(removable_ids[room_rng.randi_range(0, removable_ids.size() - 1)])
	return candidate_ids


func _can_remove_from_sparse_selection(candidate_ids: Array[StringName], placement_id: StringName) -> bool:
	if not _placement_allows_reposition(placement_id):
		return true
	var placement := _placement_for_id(placement_id)
	if placement.get("surface", &"") == &"floor":
		# Keep the complete floor group available for a real exchange. The upper
		# floor anchor is intentionally close to the room boundary, so leaving it
		# with only one neighboring survivor can make a mandatory swap impossible.
		return false
	if placement_id == RIGHT_OUTER_WALL_STONE_ID:
		# The outermost right slot is reserved for its authored piece. It may be
		# removed, but no inner right-wall stone may inherit that clipping-prone
		# anchor.
		return true
	var group_key := _reposition_group_key(placement)
	var group_count := 0
	for candidate_id in candidate_ids:
		if not _placement_allows_reposition(candidate_id):
			continue
		if _reposition_group_key(_placement_for_id(candidate_id)) == group_key:
			group_count += 1
	return group_count > MIN_SWAPPABLE_GROUP_SIZE


func _reposition_group_key(placement: Dictionary) -> String:
	var group_key := String(placement.get("surface", &""))
	if placement.get("surface", &"") == &"wall":
		if placement.get("id", &"") == RIGHT_OUTER_WALL_STONE_ID:
			return "wall:right:outer"
		group_key += ":%s" % String(placement.get("side", &"none"))
	return group_key


func _apply_room_placements(placement_ids: Array[StringName], room_id: StringName, room_type: StringName) -> void:
	last_room_id = room_id
	last_room_type = room_type
	last_selected_ids = placement_ids.duplicate()
	last_visible_ids.clear()
	last_anchor_positions.clear()
	last_positions.clear()
	candidate_offsets_cache.clear()
	var occupied_points: Dictionary = {}
	var is_hub := room_type == HUB_ROOM_TYPE
	var anchor_positions := _anchor_positions_for_room(placement_ids, room_id, room_type)
	for placement in REFERENCE_PLACEMENTS:
		var id: StringName = placement["id"]
		var base_sprite := base_sprites_by_id.get(id) as Sprite2D
		var specular_sprite := specular_sprites_by_id.get(id) as Sprite2D
		var authored_position: Vector2 = placement["position"]
		var anchor_position: Vector2 = anchor_positions.get(id, authored_position)
		if base_sprite != null:
			base_sprite.position = authored_position
			base_sprite.visible = false
		if specular_sprite != null:
			specular_sprite.position = placement["specular_position"]
			specular_sprite.visible = false
		if not placement_ids.has(id):
			continue

		var chosen_position := authored_position
		if not is_hub:
			var placement_result := _find_valid_position(placement, anchor_position, room_id, room_type, occupied_points)
			if placement_result.is_empty():
				# A room-specific door or boundary can invalidate an authored slot.
				# Omit that whole group instead of ever forcing an unsafe overlap.
				continue
			chosen_position = placement_result["position"]
			anchor_position = placement_result["anchor"]

		_add_footprint_to_occupancy(id, chosen_position, occupied_points)
		last_visible_ids.append(id)
		last_anchor_positions[id] = anchor_position
		last_positions[id] = chosen_position
		if base_sprite != null:
			base_sprite.position = chosen_position
			base_sprite.visible = true
		if specular_sprite != null:
			var specular_delta: Vector2 = placement["specular_position"] - authored_position
			specular_sprite.position = chosen_position + specular_delta
			specular_sprite.visible = true


func _anchor_positions_for_room(
	placement_ids: Array[StringName],
	room_id: StringName,
	room_type: StringName,
) -> Dictionary:
	var result: Dictionary = {}
	for placement in REFERENCE_PLACEMENTS:
		result[placement["id"]] = placement["position"]
	if room_type == HUB_ROOM_TYPE:
		return result

	var selected_by_group: Dictionary = {}
	for placement_id in placement_ids:
		if not _placement_allows_anchor_swap(placement_id):
			continue
		var placement := _placement_for_id(placement_id)
		var group_key := _reposition_group_key(placement)
		if not selected_by_group.has(group_key):
			selected_by_group[group_key] = []
		(selected_by_group[group_key] as Array).append(placement_id)

	var group_ids_by_key: Array = []
	var permutation_options: Array = []
	for group_key in selected_by_group:
		var selected_ids := selected_by_group[group_key] as Array
		var anchor_ids: Array = []
		for placement in REFERENCE_PLACEMENTS:
			var placement_id: StringName = placement["id"]
			if _placement_allows_anchor_swap(placement_id) and _reposition_group_key(placement) == group_key:
				anchor_ids.append(placement_id)
		if selected_ids.size() < MIN_SWAPPABLE_GROUP_SIZE or anchor_ids.size() < MIN_SWAPPABLE_GROUP_SIZE:
			return {}
		group_ids_by_key.append(selected_ids)
		permutation_options.append(_derangement_permutations_for_selected(selected_ids, anchor_ids, group_key, room_id, room_type))
	var safe_maps: Array[Dictionary] = []
	_collect_safe_anchor_maps(placement_ids, group_ids_by_key, permutation_options, 0, result, room_id, room_type, safe_maps)
	if safe_maps.is_empty():
		return {}
	var map_rng := RandomNumberGenerator.new()
	map_rng.seed = int(dungeon_seed) ^ String(room_id).hash() ^ String(room_type).hash() ^ ANCHOR_SWAP_SALT ^ (active_layout_variant * LAYOUT_VARIATION_SALT)
	return safe_maps[map_rng.randi_range(0, safe_maps.size() - 1)]


func _collect_safe_anchor_maps(
	placement_ids: Array[StringName],
	group_ids_by_key: Array, permutation_options: Array, group_index: int,
	anchor_positions: Dictionary, room_id: StringName, room_type: StringName, output: Array[Dictionary],
) -> void:
	if output.size() >= MAX_SAFE_ANCHOR_MAPS:
		return
	if group_index >= group_ids_by_key.size():
		if _anchor_map_is_safe(placement_ids, anchor_positions, room_id, room_type):
			output.append(anchor_positions)
		return
	var group_ids := group_ids_by_key[group_index] as Array
	for permutation_value in permutation_options[group_index] as Array:
		if output.size() >= MAX_SAFE_ANCHOR_MAPS:
			return
		var permutation := permutation_value as Array
		var candidate_anchors := anchor_positions.duplicate(true)
		for index in group_ids.size():
			var destination := _placement_for_id(permutation[index] as StringName)
			candidate_anchors[group_ids[index]] = destination["position"]
		_collect_safe_anchor_maps(placement_ids, group_ids_by_key, permutation_options, group_index + 1, candidate_anchors, room_id, room_type, output)


func _derangement_permutations(group_ids: Array, group_key: String, room_id: StringName, room_type: StringName) -> Array:
	var working_ids: Array = group_ids.duplicate()
	var permutations: Array = []
	_append_permutations(working_ids, 0, permutations)
	var derangements: Array = []
	for permutation_value in permutations:
		var permutation := permutation_value as Array
		var is_derangement := true
		for index in group_ids.size():
			if permutation[index] == group_ids[index]:
				is_derangement = false
				break
		if is_derangement:
			derangements.append(permutation)
	var swap_rng := RandomNumberGenerator.new()
	swap_rng.seed = int(dungeon_seed) ^ String(room_id).hash() ^ String(room_type).hash() ^ group_key.hash() ^ ANCHOR_SWAP_SALT ^ (active_layout_variant * LAYOUT_VARIATION_SALT)
	for index in range(derangements.size() - 1, 0, -1):
		var swap_index := swap_rng.randi_range(0, index)
		var swap_value: Array = derangements[index]
		derangements[index] = derangements[swap_index]
		derangements[swap_index] = swap_value
	return derangements


func _derangement_permutations_for_selected(selected_ids: Array, anchor_ids: Array, group_key: String, room_id: StringName, room_type: StringName) -> Array:
	var permutations: Array = []
	var working_ids: Array = anchor_ids.duplicate()
	_append_permutations(working_ids, 0, permutations)
	var valid: Array = []
	for permutation_value in permutations:
		var permutation := permutation_value as Array
		var assigned: Array = []
		var valid_assignment := true
		for index in selected_ids.size():
			var anchor_id: StringName = permutation[index]
			if anchor_id == selected_ids[index]:
				valid_assignment = false
				break
			assigned.append(anchor_id)
		if valid_assignment:
			valid.append(assigned)
	var swap_rng := RandomNumberGenerator.new()
	swap_rng.seed = int(dungeon_seed) ^ String(room_id).hash() ^ String(room_type).hash() ^ group_key.hash() ^ ANCHOR_SWAP_SALT ^ (active_layout_variant * LAYOUT_VARIATION_SALT)
	for index in range(valid.size() - 1, 0, -1):
		var swap_index := swap_rng.randi_range(0, index)
		var swap_value: Array = valid[index]
		valid[index] = valid[swap_index]
		valid[swap_index] = swap_value
	return valid


func _append_permutations(values: Array, start_index: int, output: Array) -> void:
	if start_index >= values.size():
		output.append(values.duplicate())
		return
	for index in range(start_index, values.size()):
		var swap_value: Variant = values[start_index]
		values[start_index] = values[index]
		values[index] = swap_value
		_append_permutations(values, start_index + 1, output)
		values[index] = values[start_index]
		values[start_index] = swap_value


func _anchor_map_is_safe(placement_ids: Array[StringName], anchor_positions: Dictionary, room_id: StringName, room_type: StringName) -> bool:
	var occupied_points: Dictionary = {}
	for placement in REFERENCE_PLACEMENTS:
		var id: StringName = placement["id"]
		if not placement_ids.has(id):
			continue
		var anchor_position: Vector2 = anchor_positions.get(id, placement["position"])
		var chosen := _find_valid_position(placement, anchor_position, room_id, room_type, occupied_points)
		if chosen.is_empty():
			return false
		_add_footprint_to_occupancy(id, chosen["position"], occupied_points)
	return true


func _find_valid_position(
	placement: Dictionary,
	anchor_position: Vector2,
	room_id: StringName,
	room_type: StringName,
	occupied_points: Dictionary,
) -> Dictionary:
	var id: StringName = placement["id"]
	var repeated_candidate := Vector2.INF
	for offset in _candidate_offsets(id, room_id, room_type):
		var candidate: Vector2 = anchor_position + offset
		if _candidate_repeats_previous_position(id, candidate):
			repeated_candidate = candidate
			continue
		if _placement_fits(placement, candidate, occupied_points):
			return {"position": candidate, "anchor": anchor_position}
	# Some edge slots have only one legal pixel after door and wall clearance.
	# Prefer a changed coordinate, but retain the legal repeated coordinate rather
	# than dropping the piece or spinning through dozens of layout variants.
	if repeated_candidate != Vector2.INF and _placement_fits(placement, repeated_candidate, occupied_points):
		return {"position": repeated_candidate, "anchor": anchor_position}
	return {}


func _candidate_repeats_previous_position(placement_id: StringName, candidate: Vector2) -> bool:
	if _is_crack_placement(placement_id) or not previous_layout_positions.has(placement_id):
		return false
	return candidate.is_equal_approx(previous_layout_positions[placement_id] as Vector2)


func _candidate_offsets(placement_id: StringName, room_id: StringName, room_type: StringName) -> Array[Vector2]:
	if candidate_offsets_cache.has(placement_id):
		return candidate_offsets_cache[placement_id]
	var offsets: Array[Vector2] = []
	var placement := _placement_for_id(placement_id)
	if not _placement_allows_reposition(placement_id):
		offsets.append(Vector2.ZERO)
		return offsets
	var surface: StringName = placement.get("surface", &"wall")
	if surface == &"wall":
		for dy in range(-MAX_WALL_JITTER, MAX_WALL_JITTER + 1):
			offsets.append(Vector2(0.0, dy))
	else:
		for dx in range(-MAX_FLOOR_JITTER, MAX_FLOOR_JITTER + 1):
			for dy in range(-MAX_FLOOR_JITTER, MAX_FLOOR_JITTER + 1):
				offsets.append(Vector2(dx, dy))
	var candidate_rng := RandomNumberGenerator.new()
	candidate_rng.seed = int(dungeon_seed) ^ String(room_id).hash() ^ String(room_type).hash() ^ String(placement_id).hash() ^ POSITION_VARIATION_SALT ^ (active_layout_variant * LAYOUT_VARIATION_SALT)
	for index in range(offsets.size() - 1, 0, -1):
		var swap_index := candidate_rng.randi_range(0, index)
		var swap_value: Vector2 = offsets[index]
		offsets[index] = offsets[swap_index]
		offsets[swap_index] = swap_value
	candidate_offsets_cache[placement_id] = offsets
	return offsets


func _all_candidate_offsets(placement_id: StringName) -> Array[Vector2]:
	var offsets: Array[Vector2] = []
	if not _placement_allows_reposition(placement_id):
		offsets.append(Vector2.ZERO)
		return offsets
	var placement := _placement_for_id(placement_id)
	if placement.get("surface", &"wall") == &"wall":
		for dy in range(-MAX_WALL_JITTER, MAX_WALL_JITTER + 1):
			offsets.append(Vector2(0.0, dy))
	else:
		for dx in range(-MAX_FLOOR_JITTER, MAX_FLOOR_JITTER + 1):
			for dy in range(-MAX_FLOOR_JITTER, MAX_FLOOR_JITTER + 1):
				offsets.append(Vector2(dx, dy))
	return offsets


func _placement_allows_reposition(placement_id: StringName) -> bool:
	return not _is_crack_placement(placement_id)


func _placement_allows_anchor_swap(placement_id: StringName) -> bool:
	return _placement_allows_reposition(placement_id) and placement_id != RIGHT_OUTER_WALL_STONE_ID


func _is_crack_placement(placement_id: StringName) -> bool:
	return String(placement_id).begins_with("WallCrack_")


func _placement_fits(placement: Dictionary, position: Vector2, occupied_points: Dictionary) -> bool:
	var id: StringName = placement["id"]
	var static_fit_key := "%s|%s@%s" % [current_constraint_signature, id, position]
	_cache_static_fit(placement, position, static_fit_key)
	if not bool(placement_static_fit_cache[static_fit_key]):
		return false
	var points := _translated_footprint(id, position)
	for point in points:
		if occupied_points.has(point):
			return false
	return true


func _cache_static_fit(placement: Dictionary, position: Vector2, cache_key: String = "") -> void:
	var resolved_key := cache_key
	if resolved_key.is_empty():
		resolved_key = "%s|%s@%s" % [current_constraint_signature, placement["id"], position]
	if not placement_static_fit_cache.has(resolved_key):
		placement_static_fit_cache[resolved_key] = _placement_static_fit(placement, position)


func _placement_static_fit(placement: Dictionary, position: Vector2) -> bool:
	var id: StringName = placement["id"]
	var surface: StringName = placement["surface"]
	var side: StringName = placement["side"]
	var points := _translated_footprint(id, position)
	for point in points:
		if _point_is_blocked_by_door(point):
			return false
		if surface == &"floor":
			if not _floor_point_has_clearance(point):
				return false
		elif not _wall_point_has_clearance(point, side, _is_crack_placement(id)):
			return false
	return true


func _floor_point_has_clearance(point: Vector2) -> bool:
	if floor_boundary_polygon.is_empty():
		return false
	for dx in range(-FLOOR_CLEARANCE, FLOOR_CLEARANCE + 1):
		for dy in range(-FLOOR_CLEARANCE, FLOOR_CLEARANCE + 1):
			if not Geometry2D.is_point_in_polygon(point + Vector2(dx, dy), floor_boundary_polygon):
				return false
	return true


func _wall_point_has_clearance(point: Vector2, side: StringName, is_crack: bool = false) -> bool:
	var bounds: Rect2 = WALL_SAFE_BOUNDS.get(side, Rect2())
	if is_crack:
		return bounds.has_point(point)
	return bounds.grow(-WALL_EDGE_BUFFER).has_point(point)


func _point_is_blocked_by_door(point: Vector2) -> bool:
	if door_blocked_point_lookup.has(point):
		return true
	for polygon in door_block_polygons:
		if Geometry2D.is_point_in_polygon(point, polygon):
			return true
		for index in polygon.size():
			var next_index := (index + 1) % polygon.size()
			if _distance_to_segment(point, polygon[index], polygon[next_index]) <= DOOR_CLEARANCE:
				return true
	return false


func _distance_to_segment(point: Vector2, start: Vector2, end: Vector2) -> float:
	var segment := end - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return point.distance_to(start)
	var fraction := clampf((point - start).dot(segment) / length_squared, 0.0, 1.0)
	return point.distance_to(start + segment * fraction)


func _translated_footprint(placement_id: StringName, position: Vector2) -> Array:
	var placement_cache := translated_footprint_cache.get(placement_id, {}) as Dictionary
	if placement_cache.has(position):
		return placement_cache[position] as Array
	var result: Array = []
	for point in footprints_by_id.get(placement_id, []) as Array:
		result.append(position + point)
	placement_cache[position] = result
	translated_footprint_cache[placement_id] = placement_cache
	return result


func _add_footprint_to_occupancy(placement_id: StringName, position: Vector2, occupied_points: Dictionary) -> void:
	for point in _translated_footprint(placement_id, position):
		occupied_points[point] = true


func _placement_for_id(placement_id: StringName) -> Dictionary:
	return placements_by_id.get(placement_id, {}) as Dictionary


func _build_placement_footprint(base_sprite: Sprite2D, specular_sprite: Sprite2D, placement: Dictionary) -> Array:
	var result: Array = _opaque_texture_points(base_sprite.texture, Vector2.ZERO)
	if specular_sprite != null:
		var specular_delta: Vector2 = placement["specular_position"] - placement["position"]
		result.append_array(_opaque_texture_points(specular_sprite.texture, specular_delta))
	return result


func _opaque_texture_points(texture: Texture2D, relative_origin: Vector2) -> Array:
	var result: Array = []
	if texture == null:
		return result
	for point in _cached_opaque_texture_points(texture):
		result.append(relative_origin + point)
	return result


func _cached_opaque_texture_points(texture: Texture2D) -> Array:
	if texture == null:
		return []
	var cache_key := texture.resource_path
	if cache_key.is_empty():
		cache_key = str(texture.get_rid())
	if opaque_texture_points_cache.has(cache_key):
		return opaque_texture_points_cache[cache_key]
	var result: Array = []
	var image := texture.get_image()
	if image == null or image.is_empty():
		opaque_texture_points_cache[cache_key] = result
		return result
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.0:
				result.append(Vector2(x + 0.5, y + 0.5))
	opaque_texture_points_cache[cache_key] = result
	return result


func _refresh_room_constraints() -> void:
	floor_boundary_polygon = PackedVector2Array()
	door_block_points.clear()
	door_blocked_point_lookup.clear()
	door_block_polygons.clear()
	var map_root := get_parent() as Node2D
	if map_root == null:
		return
	var floor_guide := map_root.get_node_or_null("FloorTiles/FloorCollisionGuide") as Polygon2D
	if floor_guide != null:
		for point in floor_guide.polygon:
			floor_boundary_polygon.append(to_local(floor_guide.to_global(point)))
	for path in BLOCKING_SPRITE_PATHS:
		var sprite := map_root.get_node_or_null(path) as Sprite2D
		if sprite != null:
			_append_opaque_sprite_points(sprite)
	for path in BLOCKING_GUIDE_PATHS:
		var guide := map_root.get_node_or_null(path) as Polygon2D
		if guide != null and not guide.polygon.is_empty():
			var polygon := PackedVector2Array()
			for point in guide.polygon:
				polygon.append(to_local(guide.to_global(point)))
			door_block_polygons.append(polygon)
	for door_point in door_block_points:
		for dx in range(-ceili(DOOR_CLEARANCE), ceili(DOOR_CLEARANCE) + 1):
			for dy in range(-ceili(DOOR_CLEARANCE), ceili(DOOR_CLEARANCE) + 1):
				if Vector2(dx, dy).length() <= DOOR_CLEARANCE:
					door_blocked_point_lookup[door_point + Vector2(dx, dy)] = true
	current_constraint_signature = str(hash([floor_boundary_polygon, door_block_points, door_block_polygons]))


func _append_opaque_sprite_points(sprite: Sprite2D) -> void:
	if sprite.texture == null:
		return
	var image_width := sprite.texture.get_width()
	var image_height := sprite.texture.get_height()
	for cached_point in _cached_opaque_texture_points(sprite.texture):
		var local_point: Vector2 = cached_point
		if sprite.flip_h:
			local_point.x = image_width - local_point.x
		if sprite.flip_v:
			local_point.y = image_height - local_point.y
		if sprite.centered:
			local_point -= Vector2(image_width, image_height) * 0.5
		local_point += sprite.offset
		door_block_points.append(to_local(sprite.to_global(local_point)))


func _make_sprite(
	node_name: StringName,
	texture_path: String,
	position: Vector2,
	alpha: float,
	z_index_value: int,
) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = String(node_name)
	sprite.centered = false
	sprite.texture = load(texture_path) as Texture2D
	if sprite.texture == null:
		push_error("HubStoneAccentLayer could not load %s" % texture_path)
	sprite.position = position
	sprite.self_modulate = _accent_modulate(alpha)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = z_index_value
	return sprite
