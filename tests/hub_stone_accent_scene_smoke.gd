extends SceneTree

const MAIN_SCENE := "res://scenes/main.tscn"
const LAYER_SCRIPT := preload("res://scripts/hub_stone_accent_layer.gd")
const BASE_ALPHA: float = 128.0 / 255.0
const SPECULAR_ALPHA: float = 38.0 / 255.0
const NON_HUB_REMOVAL_MIN := 3
const NON_HUB_REMOVAL_MAX := 5
const RIGHT_OUTER_WALL_STONE_ID: StringName = &"WallStone_05_right"

var failures: Array[String] = []


func _initialize() -> void:
	var packed_scene := load(MAIN_SCENE) as PackedScene
	_assert(packed_scene != null, "main scene loads")
	if packed_scene == null:
		_finish()
		return

	var gameplay := packed_scene.instantiate()
	_assert(gameplay != null, "main scene instantiates")
	if gameplay == null:
		_finish()
		return

	var layer := gameplay.get_node_or_null("Map/HubStoneAccentLayer") as Node2D
	_assert(layer != null, "main scene contains HubStoneAccentLayer")
	if layer == null:
		gameplay.free()
		_finish()
		return

	_assert(LAYER_SCRIPT != null, "accent layer script loads")
	layer.call("build_reference")
	_assert(layer.call("reference_placement_count") == 13, "reference table contains 13 base placements")
	_assert(layer.call("base_sprite_count") == 13, "reference builds 13 base sprites")
	_assert(layer.call("specular_sprite_count") == 8, "reference builds 8 specular sprites")
	_assert(layer.get_child_count() == 21, "reference builds 21 total sprites")
	var base_sprites: Array = layer.get("base_sprites")
	var specular_sprites: Array = layer.get("specular_sprites")
	var floor_stone_02 := layer.get_node_or_null("FloorStone_02") as Sprite2D
	_assert(floor_stone_02 != null and floor_stone_02.texture != null, "FloorStone_02 runtime texture loads")
	if floor_stone_02 != null and floor_stone_02.texture != null:
		var floor_stone_02_image := floor_stone_02.texture.get_image()
		_assert(floor_stone_02_image != null and floor_stone_02_image.get_pixel(7, 8).a > 0.0, "FloorStone_02 keeps the new upper row")
		_assert(floor_stone_02_image != null and floor_stone_02_image.get_pixel(6, 15).a > 0.0, "FloorStone_02 keeps the new bottom row")

	var expected_positions := {
		"FloorStone_01": Vector2(74, 75),
		"FloorStone_02": Vector2(138, 64),
		"FloorStone_03": Vector2(130, 94),
		"FloorStone_04": Vector2(158, 83),
		"WallCrack_01_left": Vector2(87, 40),
		"WallCrack_02_left": Vector2(112, 44),
		"WallCrack_03_right": Vector2(148, 56),
		"WallStone_01_left": Vector2(71, 47),
		"WallStone_02_left": Vector2(113, 38),
		"WallStone_03_right": Vector2(145, 40),
		"WallStone_04_right": Vector2(159, 59),
		"WallStone_05_right": Vector2(177, 68),
		"WallStone_06_left": Vector2(58, 69),
	}
	for sprite_value in base_sprites:
		var sprite := sprite_value as Sprite2D
		_assert(sprite != null, "base placement creates a Sprite2D")
		if sprite == null:
			continue
		_assert(expected_positions.has(sprite.name), "%s has a reference placement" % sprite.name)
		if expected_positions.has(sprite.name):
			_assert(sprite.position == expected_positions[sprite.name], "%s position matches reference" % sprite.name)
		_assert(not sprite.centered, "%s uses authored texture-origin placement" % sprite.name)
		_assert(sprite.texture != null, "%s texture loads" % sprite.name)
		if sprite.texture != null:
			_assert(sprite.texture.get_width() == 16 and sprite.texture.get_height() == 16, "%s is 16x16" % sprite.name)
		_assert(is_equal_approx(sprite.self_modulate.a, BASE_ALPHA), "%s uses reference base opacity" % sprite.name)
		_assert(sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s uses nearest filtering" % sprite.name)

	var expected_specular_positions := {
		"WallCrack_01_left_Specular": Vector2(87, 39),
		"WallCrack_03_right_Specular": Vector2(148, 56),
		"WallStone_01_left_Specular": Vector2(70, 48),
		"WallStone_02_left_Specular": Vector2(112, 39),
		"WallStone_03_right_Specular": Vector2(144, 41),
		"WallStone_04_right_Specular": Vector2(158, 60),
		"WallStone_05_right_Specular": Vector2(176, 69),
		"WallStone_06_left_Specular": Vector2(57, 70),
	}
	for sprite_value in specular_sprites:
		var sprite := sprite_value as Sprite2D
		_assert(sprite != null, "specular placement creates a Sprite2D")
		if sprite == null:
			continue
		_assert(expected_specular_positions.has(sprite.name), "%s has a reference placement" % sprite.name)
		if expected_specular_positions.has(sprite.name):
			_assert(sprite.position == expected_specular_positions[sprite.name], "%s position matches reference" % sprite.name)
		_assert(not sprite.centered, "%s uses authored texture-origin placement" % sprite.name)
		_assert(sprite.texture != null, "%s texture loads" % sprite.name)
		_assert(is_equal_approx(sprite.self_modulate.a, SPECULAR_ALPHA), "%s uses reference specular opacity" % sprite.name)

	layer.call("configure_dungeon_seed", 24681357)
	layer.call("on_room_entered", &"room_1_0", &"COMBAT")
	layer.call("refresh_current_room", &"room_1_0", &"COMBAT")
	var combat_removed_count := int(layer.call("removed_count_for_room", &"room_1_0", &"COMBAT"))
	var combat_ids: Array = layer.call("visible_placement_ids")
	var combat_positions: Dictionary = layer.call("visible_placement_positions")
	var combat_anchor_positions: Dictionary = layer.call("visible_placement_anchor_positions")
	_assert(combat_removed_count >= NON_HUB_REMOVAL_MIN and combat_removed_count <= NON_HUB_REMOVAL_MAX, "non-Hub room removes 3 to 5 placements (removed=%d, visible=%d)" % [combat_removed_count, combat_ids.size()])
	_assert(combat_ids.size() == 13 - combat_removed_count, "non-Hub room keeps the remaining authored placements")
	_assert(layer.call("visible_base_sprite_count") == combat_ids.size(), "non-Hub base visibility follows placement selection")
	_assert(bool(layer.call("placement_constraints_valid")), "non-Hub placement passes the edge, door, and overlap validator")
	_assert(bool(layer.call("anchor_swaps_valid")), "non-Hub movable groups exchange authored anchors")
	for placement_value in layer.call("reference_placements") as Array:
		var placement := placement_value as Dictionary
		var placement_id: StringName = placement["id"]
		if not combat_positions.has(placement_id):
			continue
		var anchor_position: Vector2 = layer.call("anchor_position_for", placement_id)
		var offset: Vector2 = (layer.call("position_for", placement_id) as Vector2) - anchor_position
		_assert(absf(offset.x) <= 2.0 and absf(offset.y) <= 2.0, "%s stays within the two-pixel jitter budget" % placement_id)
		if placement["surface"] == &"wall":
			_assert(is_zero_approx(offset.x), "%s keeps its wall lane" % placement_id)
			if String(placement_id).begins_with("WallCrack_"):
				_assert(anchor_position == placement["position"] and layer.call("position_for", placement_id) == placement["position"], "%s stays on its authored anchor" % placement_id)
	layer.call("on_room_entered", &"room_1_0", &"COMBAT")
	layer.call("refresh_current_room", &"room_1_0", &"COMBAT")
	var combat_ids_repeat: Array = layer.call("visible_placement_ids")
	_assert(combat_ids == combat_ids_repeat, "same seed and room reproduce the same sparse selection")
	_assert(combat_positions == layer.call("visible_placement_positions"), "same seed and room reproduce the same jittered positions")
	_assert(combat_anchor_positions == layer.call("visible_placement_anchor_positions"), "same seed and room reproduce the same anchor swaps")
	var seed_varies_selection := false
	var seed_varies_layout := false
	var floor_swap_seen := false
	var wall_swap_seen := false
	for candidate_seed in range(1, 65):
		layer.call("configure_dungeon_seed", candidate_seed)
		layer.call("on_room_entered", &"room_1_0", &"COMBAT")
		layer.call("refresh_current_room", &"room_1_0", &"COMBAT")
		var candidate_ids: Array = layer.call("visible_placement_ids")
		var candidate_removed_count := int(layer.call("removed_count_for_room", &"room_1_0", &"COMBAT"))
		var candidate_positions: Dictionary = layer.call("visible_placement_positions")
		var candidate_anchor_positions: Dictionary = layer.call("visible_placement_anchor_positions")
		_assert(candidate_removed_count >= NON_HUB_REMOVAL_MIN and candidate_removed_count <= NON_HUB_REMOVAL_MAX, "seed %d keeps the 3–5 removal density (removed=%d, visible=%d)" % [candidate_seed, candidate_removed_count, candidate_ids.size()])
		_assert(bool(layer.call("placement_constraints_valid")), "seed %d keeps the stone placement validator green" % candidate_seed)
		_assert(bool(layer.call("anchor_swaps_valid")), "seed %d swaps every selected movable group" % candidate_seed)
		if candidate_ids != combat_ids:
			seed_varies_selection = true
		if candidate_positions != combat_positions:
			seed_varies_layout = true
		for placement_value in layer.call("reference_placements") as Array:
			var placement := placement_value as Dictionary
			var placement_id: StringName = placement["id"]
			if not candidate_anchor_positions.has(placement_id):
				continue
			var candidate_anchor: Vector2 = candidate_anchor_positions[placement_id]
			if String(placement_id).begins_with("WallCrack_"):
				_assert(candidate_anchor == placement["position"] and candidate_positions[placement_id] == placement["position"], "%s never participates in movement or swapping" % placement_id)
			elif placement["surface"] == &"wall" and placement["side"] == &"right":
				if placement_id == RIGHT_OUTER_WALL_STONE_ID:
					_assert(candidate_anchor == placement["position"], "rightmost wall stone keeps its reserved outer anchor")
				else:
					_assert(candidate_anchor != Vector2(177, 68), "%s never inherits the clipping-prone outer right anchor" % placement_id)
					if candidate_anchor != placement["position"]:
						_assert(_same_relative_anchor(layer.call("reference_placements") as Array, placement, candidate_anchor), "%s swaps only with a matching right-wall anchor" % placement_id)
						wall_swap_seen = true
			elif candidate_anchor != placement["position"]:
				_assert(_same_relative_anchor(layer.call("reference_placements") as Array, placement, candidate_anchor), "%s swaps only with a matching surface/side anchor" % placement_id)
				if placement["surface"] == &"floor":
					floor_swap_seen = true
				else:
					wall_swap_seen = true
	_assert(seed_varies_selection, "different dungeon seeds can produce a different sparse selection")
	_assert(seed_varies_layout, "different dungeon seeds can produce different bounded positions")
	_assert(floor_swap_seen, "different dungeon seeds can swap floor-stone anchors")
	_assert(wall_swap_seen, "different dungeon seeds can swap same-side wall-stone anchors")
	layer.call("configure_dungeon_seed", 24681357)
	layer.call("on_room_entered", &"room_1_0", &"COMBAT")
	layer.call("refresh_current_room", &"room_1_0", &"COMBAT")
	for sprite_value in specular_sprites:
		var specular_sprite := sprite_value as Sprite2D
		if specular_sprite == null:
			continue
		var base_sprite := layer.get_node_or_null(specular_sprite.name.replace("_Specular", "")) as Sprite2D
		_assert(base_sprite != null and specular_sprite.visible == base_sprite.visible, "%s visibility follows its base placement" % specular_sprite.name)
		if base_sprite != null and expected_specular_positions.has(base_sprite.name):
			var expected_delta: Vector2 = expected_specular_positions[base_sprite.name + "_Specular"] - expected_positions[base_sprite.name]
			_assert(specular_sprite.position - base_sprite.position == expected_delta, "%s follows its base through anchor swaps and jitter" % specular_sprite.name)
	var first_connected_layout := layer.call("layout_signature") as String
	layer.call("on_room_entered", &"room_1_1", &"COMBAT")
	layer.call("refresh_current_room", &"room_1_1", &"COMBAT")
	_assert(first_connected_layout != layer.call("layout_signature"), "connected non-Hub rooms never reuse the same accent layout")
	_assert(float(layer.call("shared_movable_position_change_ratio")) >= 0.60, "connected rooms move most shared movable pieces")
	layer.call("on_room_entered", &"room_2_0", &"BOSS")
	layer.call("refresh_current_room", &"room_2_0", &"BOSS")
	var boss_removed_count := int(layer.call("removed_count_for_room", &"room_2_0", &"BOSS"))
	_assert(boss_removed_count >= NON_HUB_REMOVAL_MIN and boss_removed_count <= NON_HUB_REMOVAL_MAX, "boss room receives the 3 to 5 piece sparse treatment (removed=%d, visible=%d)" % [boss_removed_count, layer.call("visible_base_sprite_count")])
	_assert(bool(layer.call("placement_constraints_valid")), "boss placement passes the edge, door, and overlap validator")
	_assert(bool(layer.call("anchor_swaps_valid")), "boss movable groups exchange authored anchors")
	_assert(layer.visible and layer.call("visible_base_sprite_count") >= 8 and layer.call("visible_base_sprite_count") <= 10, "non-Hub accent layer remains visible with a sparse subset (visible=%d)" % layer.call("visible_base_sprite_count"))

	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	# A fresh headless profile intentionally boots to the title route. Enter the
	# Hub through the normal run-start boundary before asserting room-entry
	# wiring; otherwise this fixture only observes the title-only bootstrap.
	var profile := gameplay.get("player_profile") as PlayerProfile
	if profile != null:
		profile.has_started = true
		profile.pending_route = "hub"
		gameplay.call("_begin_new_run")
		for _frame in 120:
			await process_frame
	_assert(gameplay.get("current_room_type") == &"START", "runtime begins in the Hub room")
	_assert(layer.visible, "room-entered wiring shows the accent layer in the Hub")
	_assert(layer.get_child_count() == 21, "runtime reuses the static composition")
	_assert(layer.get("dungeon_seed") == gameplay.get("current_dungeon_seed"), "accent selection receives the current dungeon seed")
	var room_controller := gameplay.get("room_controller") as RoomController
	_assert(room_controller != null, "runtime composes the room controller")
	var room_puzzle_controller := gameplay.get("room_puzzle_controller") as RoomPuzzleController
	var room_tint := Color(0.38, 0.62, 0.92, 1.0)
	gameplay.call("_apply_puzzle_environment_tint", room_tint)
	if room_puzzle_controller != null and not base_sprites.is_empty():
		var presentation_tint: Color = room_puzzle_controller.call("_lightened_artwork_tint", room_tint)
		var expected_base_tint := Color(presentation_tint.r, presentation_tint.g, presentation_tint.b, BASE_ALPHA)
		for sprite_value in base_sprites:
			var base_sprite := sprite_value as Sprite2D
			_assert(base_sprite != null and base_sprite.self_modulate.is_equal_approx(expected_base_tint), "all stone accents receive the active room tint")
		var expected_specular_tint := Color(presentation_tint.r, presentation_tint.g, presentation_tint.b, SPECULAR_ALPHA)
		for sprite_value in specular_sprites:
			var specular_sprite := sprite_value as Sprite2D
			_assert(specular_sprite != null and specular_sprite.self_modulate.is_equal_approx(expected_specular_tint), "all stone specular overlays receive the active room tint")
	gameplay.call("_apply_puzzle_environment_tint", Color.WHITE)

	room_controller.set_current_room(&"room_0_0", &"START")
	_assert(layer.visible, "Hub room entry shows accent layer")
	_assert(layer.call("visible_base_sprite_count") == 13, "Hub room restores all base placements")
	room_controller.set_current_room(&"room_1_0", &"COMBAT")
	_assert(layer.visible, "non-Hub room entry keeps accent layer visible")
	_assert(layer.call("visible_base_sprite_count") >= 8 and layer.call("visible_base_sprite_count") <= 10, "non-Hub room shows a sparse subset")
	room_controller.set_current_room(&"room_0_0", &"START")
	_assert(layer.visible and layer.get_child_count() == 21 and layer.call("visible_base_sprite_count") == 13, "Hub re-entry restores the static composition")

	gameplay.queue_free()
	await process_frame
	_finish()


func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	failures.append(message)
	push_error("hub_stone_accent_scene_smoke: " + message)


func _same_relative_anchor(reference_placements: Array, source: Dictionary, candidate_anchor: Vector2) -> bool:
	for placement_value in reference_placements:
		var destination := placement_value as Dictionary
		if destination == null or destination["id"] == source["id"]:
			continue
		if destination["position"] != candidate_anchor or destination["surface"] != source["surface"]:
			continue
		if source["surface"] == &"wall" and destination["side"] != source["side"]:
			continue
		return true
	return false


func _finish() -> void:
	if failures.is_empty():
		print("HUB_STONE_ACCENT_SCENE_SMOKE_OK")
	else:
		print("HUB_STONE_ACCENT_SCENE_SMOKE_FAILED: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
