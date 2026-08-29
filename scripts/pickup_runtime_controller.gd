extends Node
class_name PickupRuntimeController

const SoulVisualsScript = preload("res://scripts/soul_visuals.gd")

const CHEST_INTERACT_DISTANCE := 16.0
const DEPTH_Z_SCALE := 10.0
const CHROMA_PICKUP_VALUE := 20
const ITEM_DROP_GRAVITY := 92.0
const ITEM_DROP_AIR_TIME := 0.38
const ITEM_DROP_ARC_HEIGHT := 8.0
const ITEM_DROP_FOOTPRINT_PADDING := Vector2(4.0, 2.0)
const CHROMA_COLOR := PaletteLibrary.ACCENT["blue"]
const CHROMA_BOB_SPEED := 4.5
const CHROMA_BOB_AMPLITUDE := 1.5
const CHROMA_LIGHT_SIZE := 32
const CHROMA_LIGHT_ENERGY := 0.12
const CHROMA_LIGHT_TEXTURE_SCALE := 0.70
const SOUL_COLOR := Color8(211, 167, 255)
const SOUL_PICKUP_GRAVITY := 92.0
const SOUL_BOB_SPEED := 4.5
const SOUL_BOB_AMPLITUDE := 1.5
const SOUL_PICKUP_COLLECTION_DISTANCE := 10.0
const SOUL_PICKUP_AIR_TIME := 0.38
const SOUL_PICKUP_LAUNCH_SPEED := 30.0
const SOUL_PICKUP_LAUNCH_SPREAD := 18.0
const ITEM_DROP_TEXTURE_PATHS := {
	&"weapon": "res://assets/artwork/sword_pickup.png",
	&"armor": "res://assets/artwork/armor_pickup.png",
	&"shield": "res://assets/artwork/shield_pickup.png",
	&"accessory": "res://assets/artwork/acc_pickup.png",
}
const ITEM_TYPE_LABELS := {
	&"weapon": "SWORD",
	&"armor": "ARMOR",
	&"shield": "SHIELD",
	&"accessory": "ACCESSORY",
}

var chroma_light_texture: Texture2D = null
var soul_pickup_texture_cache: Texture2D = null


func placeholder_item_texture() -> Texture2D:
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func soul_pickup_texture() -> Texture2D:
	if soul_pickup_texture_cache != null:
		return soul_pickup_texture_cache
	# Use the authored soul for both world pickups and currency displays. The
	# shared helper recolours only the grey body and its light outline, preserving
	# the two dark eye pixels.
	soul_pickup_texture_cache = SoulVisualsScript.texture()
	return soul_pickup_texture_cache


func item_drop_texture(item: ItemInstance) -> Texture2D:
	var slot := ItemCatalog.new().definition_slot(item.definition_id)
	var path := str(ITEM_DROP_TEXTURE_PATHS.get(slot, ""))
	return load(path) as Texture2D if not path.is_empty() and ResourceLoader.exists(path) else placeholder_item_texture()


func item_type_label(item: ItemInstance) -> String:
	if item == null:
		return "ITEM"
	var slot := ItemCatalog.new().definition_slot(item.definition_id)
	return str(ITEM_TYPE_LABELS.get(slot, "ITEM"))


func item_acquired_text(item: ItemInstance) -> String:
	return "%s ACQUIRED!" % item_type_label(item)


func _safe_drop_position(root: Object, point: Vector2) -> Vector2:
	var candidate: Vector2 = root.call("_nearest_slime_walkable_point", point) as Vector2
	if bool(root.call("_is_slime_walkable_point", candidate)):
		return candidate
	var area := root.get("walkable_area") as WalkableArea
	if area != null and not area.is_empty():
		var best := Vector2.ZERO
		var best_distance := INF
		for area_point in area.points:
			var valid_point: Vector2 = area_point
			if not area.is_slime_walkable(valid_point):
				continue
			var distance := point.distance_squared_to(valid_point)
			if distance < best_distance:
				best = valid_point
				best_distance = distance
		if best_distance < INF:
			return best
		var center := Vector2.ZERO
		for outline_point in area.outline:
			center += outline_point
		if not area.outline.is_empty():
			center /= float(area.outline.size())
		if area.is_slime_walkable(center):
			return center
	var player := root.get("player") as Sprite2D
	if player != null and is_instance_valid(player):
		var player_point: Vector2 = root.call("_actor_foot", player) as Vector2
		candidate = root.call("_nearest_slime_walkable_point", player_point) as Vector2
		if bool(root.call("_is_slime_walkable_point", candidate)):
			return candidate
	return candidate


func _drop_position_is_walkable(root: Object, point: Vector2) -> bool:
	return bool(root.call("_is_slime_walkable_point", point))


func _advance_drop_position(root: Object, current_position: Vector2, velocity: Vector2, delta: float) -> Dictionary:
	var next_position := current_position + velocity * delta
	if _drop_position_is_walkable(root, next_position):
		return {"position": next_position, "velocity": velocity}
	# Resolve each axis independently at the current position. A failed sample
	# stops that component of the launch in place instead of asking the nearest
	# point solver to teleport the pickup to another part of the room.
	var resolved_position := current_position
	var resolved_velocity := velocity
	if absf(velocity.x) > 0.0001:
		var horizontal_position := resolved_position + Vector2(velocity.x * delta, 0.0)
		if _drop_position_is_walkable(root, horizontal_position):
			resolved_position.x = horizontal_position.x
		else:
			resolved_velocity.x = 0.0
	if absf(velocity.y) > 0.0001:
		var vertical_position := resolved_position + Vector2(0.0, velocity.y * delta)
		if _drop_position_is_walkable(root, vertical_position):
			resolved_position.y = vertical_position.y
		else:
			resolved_velocity.y = 0.0
	return {"position": resolved_position, "velocity": resolved_velocity}


func _chest_drop_rect(root: Object) -> Rect2:
	var chest := root.get("chest") as Sprite2D
	if chest != null and is_instance_valid(chest):
		var chest_rect: Rect2 = root.call("_collision_rect", chest)
		if chest_rect.has_area():
			return chest_rect
	return Rect2()


func _chest_drop_launch_position(root: Object, chest_rect: Rect2) -> Vector2:
	if chest_rect.has_area():
		# The item starts at the top edge of the chest collision guide. This keeps
		# the first visible frame attached to the chest instead of to a room-wide
		# walkable-point fallback.
		return Vector2(chest_rect.get_center().x, chest_rect.position.y + 1.0)
	var chest := root.get("chest") as Sprite2D
	return chest.global_position + Vector2(8.0, 7.0) if chest != null else root.get("chest_start_position") as Vector2


func _item_drop_position_is_safe(root: Object, point: Vector2, chest_rect: Rect2, reserved: Array[Vector2]) -> bool:
	if not _drop_position_is_walkable(root, point):
		return false
	if chest_rect.has_area() and chest_rect.grow(1.0).has_point(point):
		return false
	for occupied in reserved:
		if point.distance_to(occupied) < 6.0:
			return false
	for sample in [
		point + Vector2(-ITEM_DROP_FOOTPRINT_PADDING.x, 0.0),
		point + Vector2(ITEM_DROP_FOOTPRINT_PADDING.x, 0.0),
		point + Vector2(0.0, ITEM_DROP_FOOTPRINT_PADDING.y),
	]:
		if not _drop_position_is_walkable(root, sample):
			return false
	return true


func _chest_drop_landing_position(root: Object, chest_rect: Rect2, index: int, count: int, reserved: Array[Vector2], launch_rng: RandomNumberGenerator) -> Vector2:
	var anchor := chest_rect.get_center() if chest_rect.has_area() else _chest_drop_launch_position(root, chest_rect)
	var fan_offset := 0.0 if count <= 1 else (float(index) - float(count - 1) * 0.5) * 0.28
	fan_offset += launch_rng.randf_range(-0.06, 0.06)
	var directions: Array[Vector2] = []
	for direction_index in 24:
		var angle := TAU * float(direction_index) / 24.0 + fan_offset
		directions.append(Vector2.DOWN.rotated(angle))
	for radius_value in [8.0, 10.0, 12.0, 16.0, 20.0, 24.0, 32.0, 40.0]:
		var radius: float = radius_value
		for direction in directions:
			var candidate: Vector2 = anchor + direction * radius
			if _item_drop_position_is_safe(root, candidate, chest_rect, reserved):
				return candidate
	# This is only a last resort for malformed geometry. Normal authored and
	# generated chests find a nearby point in the radial search above.
	var fallback := _safe_drop_position(root, anchor + Vector2(0.0, 8.0))
	return fallback


func _chroma_light_texture() -> Texture2D:
	if chroma_light_texture != null:
		return chroma_light_texture
	var image := Image.create(CHROMA_LIGHT_SIZE, CHROMA_LIGHT_SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(CHROMA_LIGHT_SIZE - 1, CHROMA_LIGHT_SIZE - 1) * 0.5
	var radius := float(CHROMA_LIGHT_SIZE) * 0.5
	for y in CHROMA_LIGHT_SIZE:
		for x in CHROMA_LIGHT_SIZE:
			var distance := Vector2(x, y).distance_to(center) / radius
			var alpha := pow(clampf(1.0 - distance, 0.0, 1.0), 2.0) * 0.9
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	chroma_light_texture = ImageTexture.create_from_image(image)
	return chroma_light_texture


func spawn_chest_item_drop(root: Object, item: ItemInstance) -> void:
	var items: Array[ItemInstance] = [item]
	spawn_chest_item_drops(root, items)


func spawn_chest_item_drops(root: Object, items: Array[ItemInstance]) -> void:
	clear_world_item_drops(root)
	if items.is_empty():
		return
	var catalog := ItemCatalog.new()
	var count := items.size()
	var chest_rect := _chest_drop_rect(root)
	var reserved_landings: Array[Vector2] = []
	for index in count:
		var item := items[index]
		if item == null:
			continue
		var rarity_color := catalog.rarity_color(item.rarity)
		var sprite := Sprite2D.new()
		sprite.name = "ChestItemDrop%d" % (index + 1)
		sprite.texture = item_drop_texture(item)
		sprite.centered = true
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.modulate = rarity_color
		var launch_rng := RandomNumberGenerator.new()
		launch_rng.seed = item.instance_id.hash()
		var launch_position := _chest_drop_launch_position(root, chest_rect)
		var landing_position := _chest_drop_landing_position(root, chest_rect, index, count, reserved_landings, launch_rng)
		reserved_landings.append(landing_position)
		sprite.global_position = launch_position
		sprite.z_as_relative = false
		sprite.z_index = root.chest.z_index + 3
		root.add_child(sprite)
		var label := Sprite2D.new()
		label.name = "ChestItemDropLabel%d" % (index + 1)
		var item_name := str(ItemCatalog.DEFINITIONS.get(item.definition_id, {}).get("name", "ITEM"))
		label.texture = root.call("_pixel_text_texture", "%s %s +%d" % [catalog.rarity_letter_grade(item.rarity), item_name, item.enhancement_level], rarity_color)
		label.set_meta("item_type", item_type_label(item))
		label.centered = true
		label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		label.z_as_relative = false
		label.visible = false
		label.global_position = sprite.global_position + Vector2(0, -10)
		label.z_index = sprite.z_index + 1
		root.add_child(label)
		root.world_item_drops.append({
			"sprite": sprite,
			"label": label,
			"item": item,
			"velocity": Vector2.ZERO,
			"air_time": ITEM_DROP_AIR_TIME,
			"flight_elapsed": 0.0,
			"launch_position": launch_position,
			"landing_position": landing_position,
			"trajectory_mode": &"chest_arc",
			"last_valid_position": landing_position,
		})
	constrain_world_item_drops(root)


func restore_chest_item_drop(root: Object, item: ItemInstance, saved_position: Vector2) -> void:
	restore_chest_item_drops(root, [{"item": item.to_dictionary(), "position": saved_position}])


func restore_chest_item_drops(root: Object, saved_drops: Array) -> void:
	var items: Array[ItemInstance] = []
	var positions: Array[Vector2] = []
	for saved_value in saved_drops:
		if not (saved_value is Dictionary):
			continue
		var saved := saved_value as Dictionary
		var item := ItemInstance.from_dictionary(saved.get("item", {}) as Dictionary)
		if item.instance_id.is_empty():
			continue
		items.append(item)
		positions.append(saved.get("position", root.get("chest_start_position")) as Vector2)
	spawn_chest_item_drops(root, items)
	for index in mini(items.size(), root.world_item_drops.size()):
		var drop := root.world_item_drops[index] as Dictionary
		var sprite := drop.get("sprite") as Sprite2D
		if sprite == null or not is_instance_valid(sprite):
			continue
		sprite.global_position = _safe_drop_position(root, positions[index])
		drop["velocity"] = Vector2.ZERO
		drop["air_time"] = 0.0
		drop["trajectory_mode"] = &"landed"
		drop["launch_position"] = sprite.global_position
		drop["landing_position"] = sprite.global_position
		drop["flight_elapsed"] = 0.0
		drop["last_valid_position"] = sprite.global_position
	constrain_world_item_drops(root)


func clear_world_item_drops(root: Object) -> void:
	for drop in root.world_item_drops:
		var sprite := drop.get("sprite") as Sprite2D
		var label := drop.get("label") as Sprite2D
		if sprite != null and is_instance_valid(sprite):
			sprite.queue_free()
		if label != null and is_instance_valid(label):
			label.queue_free()
	root.world_item_drops.clear()


func constrain_world_item_drop(root: Object) -> void:
	constrain_world_item_drops(root)


func constrain_world_item_drops(root: Object) -> void:
	for drop in root.world_item_drops:
		var sprite := drop.get("sprite") as Sprite2D
		if sprite != null and is_instance_valid(sprite):
			# Airborne chest loot intentionally lives above the floor polygon for a
			# few frames. Constraining it here would immediately snap it to the
			# nearest sampled floor point, which is often the room center.
			if float(drop.get("air_time", 0.0)) <= 0.0:
				sprite.global_position = _safe_drop_position(root, sprite.global_position)
				drop["last_valid_position"] = sprite.global_position
			var label := drop.get("label") as Sprite2D
			if label != null and is_instance_valid(label):
				label.global_position = sprite.global_position + Vector2(0, -10)
	_update_world_item_labels(root)


func update_world_item_drop(root: Object, delta: float) -> void:
	update_world_item_drops(root, delta)


func update_world_item_drops(root: Object, delta: float) -> void:
	var index: int = root.world_item_drops.size() - 1
	while index >= 0:
		var drop := root.world_item_drops[index] as Dictionary
		var sprite := drop.get("sprite") as Sprite2D
		var label := drop.get("label") as Sprite2D
		var item := drop.get("item") as ItemInstance
		if sprite == null or not is_instance_valid(sprite) or item == null:
			root.world_item_drops.remove_at(index)
			index -= 1
			continue
		var air_time := float(drop.get("air_time", 0.0))
		var velocity := drop.get("velocity", Vector2.ZERO) as Vector2
		var last_valid_position: Vector2 = drop.get("last_valid_position", sprite.global_position) as Vector2
		var trajectory_mode := StringName(drop.get("trajectory_mode", &""))
		if air_time <= 0.0 and not _drop_position_is_walkable(root, last_valid_position):
			last_valid_position = _safe_drop_position(root, sprite.global_position)
			sprite.global_position = last_valid_position
		if air_time > 0.0:
			air_time = maxf(air_time - delta, 0.0)
			if trajectory_mode == &"chest_arc":
				var flight_elapsed := minf(float(drop.get("flight_elapsed", 0.0)) + delta, ITEM_DROP_AIR_TIME)
				var flight_t := clampf(flight_elapsed / ITEM_DROP_AIR_TIME, 0.0, 1.0)
				var launch_position: Vector2 = drop.get("launch_position", sprite.global_position) as Vector2
				var landing_position: Vector2 = drop.get("landing_position", last_valid_position) as Vector2
				var arc_position := launch_position.lerp(landing_position, flight_t)
				arc_position.y -= sin(flight_t * PI) * ITEM_DROP_ARC_HEIGHT
				sprite.global_position = arc_position
				drop["flight_elapsed"] = flight_elapsed
				if air_time <= 0.0:
					sprite.global_position = landing_position
					last_valid_position = landing_position
					velocity = Vector2.ZERO
			else:
				velocity.y += ITEM_DROP_GRAVITY * delta
				var airborne_step := _advance_drop_position(root, last_valid_position, velocity, delta)
				last_valid_position = airborne_step["position"] as Vector2
				velocity = airborne_step["velocity"] as Vector2
				sprite.global_position = last_valid_position
			if air_time <= 0.0:
				velocity = Vector2.ZERO
		drop["air_time"] = air_time
		drop["velocity"] = velocity
		var distance: float = root.call("_actor_foot", root.player).distance_to(sprite.global_position)
		if distance < 10.0 and root.player_is_moving and air_time <= 0.0:
			var push: Vector2 = sprite.global_position - root.call("_actor_foot", root.player)
			if push.length_squared() < 0.01:
				push = root.call("_player_facing_vector")
			var push_step := _advance_drop_position(root, last_valid_position, push.normalized() * 18.0, delta)
			last_valid_position = push_step["position"] as Vector2
			sprite.global_position = last_valid_position
		drop["last_valid_position"] = last_valid_position
		sprite.z_index = int(round(sprite.global_position.y * DEPTH_Z_SCALE)) + 2
		if label != null and is_instance_valid(label):
			label.global_position = sprite.global_position + Vector2(0, -10)
			label.z_index = sprite.z_index + 1
		index -= 1
	_update_world_item_labels(root)


func _world_item_drop_is_interactable(root: Object, drop: Dictionary) -> bool:
	var sprite := drop.get("sprite") as Sprite2D
	if sprite == null or not is_instance_valid(sprite) or float(drop.get("air_time", 0.0)) > 0.0:
		return false
	var player_foot: Vector2 = root.call("_actor_foot", root.player)
	if player_foot.distance_to(sprite.global_position) > CHEST_INTERACT_DISTANCE:
		return false
	return not root.has_method("_is_interaction_target_in_front") or bool(root.call("_is_interaction_target_in_front", sprite.global_position))


func _interactable_world_item_drop(root: Object) -> Dictionary:
	var nearest: Dictionary = {}
	var nearest_distance := INF
	var player_foot: Vector2 = root.call("_actor_foot", root.player)
	for drop in root.world_item_drops:
		if not _world_item_drop_is_interactable(root, drop):
			continue
		var sprite := drop.get("sprite") as Sprite2D
		var distance := player_foot.distance_squared_to(sprite.global_position)
		if distance < nearest_distance:
			nearest = drop
			nearest_distance = distance
	return nearest


func _update_world_item_labels(root: Object) -> void:
	var selected := _interactable_world_item_drop(root)
	var selected_sprite := selected.get("sprite") as Sprite2D
	for drop in root.world_item_drops:
		var sprite := drop.get("sprite") as Sprite2D
		var label := drop.get("label") as Sprite2D
		if label == null or not is_instance_valid(label):
			continue
		var is_selected := selected_sprite != null and sprite == selected_sprite
		label.visible = is_selected
		if is_selected and sprite != null and is_instance_valid(sprite):
			label.global_position = sprite.global_position + Vector2(0, -10)


func world_item_drop_position(root: Object) -> Vector2:
	var drop := _interactable_world_item_drop(root)
	var sprite := drop.get("sprite") as Sprite2D
	return sprite.global_position if sprite != null and is_instance_valid(sprite) else Vector2.ZERO


func can_interact_with_world_item(root: Object) -> bool:
	return not _interactable_world_item_drop(root).is_empty()


func collect_world_item_drop(root: Object) -> bool:
	var drop := _interactable_world_item_drop(root)
	var sprite := drop.get("sprite") as Sprite2D
	var item := drop.get("item") as ItemInstance
	if sprite == null or not is_instance_valid(sprite) or item == null or root.player_profile == null:
		return false
	if not root.player_profile.grant_item(item):
		return false
	root.call("_save_player_profile")
	var acquired_text := item_acquired_text(item)
	var acquired_color := Color("ffd866")
	var acquired_origin: Vector2 = root.call("_player_floating_number_origin", acquired_text, acquired_color) as Vector2
	root.call("_spawn_floating_number", acquired_origin + Vector2(0, -20), 0, Vector2(0, -12), false, false, acquired_color, acquired_text)
	root.call("_play_sound", "item_pickup", -4.0, 1.0)
	var drop_index := -1
	for index in root.world_item_drops.size():
		if (root.world_item_drops[index] as Dictionary).get("sprite") == sprite:
			drop_index = index
			break
	if drop_index >= 0:
		root.world_item_drops.remove_at(drop_index)
	var label := drop.get("label") as Sprite2D
	sprite.queue_free()
	if label != null and is_instance_valid(label):
		label.queue_free()
	return true


func spawn_chroma_pickup(root: Object, position: Vector2, value: int = CHROMA_PICKUP_VALUE, launch_seed: int = 0, launch_direction: Vector2 = Vector2.ZERO) -> void:
	var launch_rng := RandomNumberGenerator.new()
	var root_rng := root.get("rng") as RandomNumberGenerator
	launch_rng.seed = launch_seed if launch_seed != 0 else root_rng.randi() if root_rng != null else Time.get_ticks_msec()
	var sprite := Sprite2D.new()
	sprite.name = "ChromaPickup"
	sprite.texture = root.call("_pixel_particle_texture", CHROMA_COLOR, 3) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.modulate = Color.WHITE
	var spawn_position := _safe_drop_position(root, position)
	sprite.global_position = spawn_position
	sprite.set_meta("chroma_bob_phase", launch_rng.randf_range(0.0, TAU))
	sprite.set_meta("chroma_bob_time", 0.0)
	sprite.set_meta("chroma_base_position", spawn_position)
	sprite.set_meta("chroma_last_valid_position", spawn_position)
	var light := PointLight2D.new()
	light.name = "ChromaLight"
	light.texture = _chroma_light_texture()
	light.color = CHROMA_COLOR
	light.energy = CHROMA_LIGHT_ENERGY
	light.texture_scale = CHROMA_LIGHT_TEXTURE_SCALE
	light.shadow_enabled = false
	light.z_index = -1
	sprite.add_child(light)
	root.add_child(sprite)
	var tuning: ChromaTuning = root.chroma_tuning
	var velocity := Vector2(launch_rng.randf_range(-tuning.pickup_launch_spread, tuning.pickup_launch_spread), -tuning.pickup_launch_speed)
	if launch_direction.length_squared() > 0.001:
		velocity = launch_direction.normalized() * tuning.pickup_launch_speed
	root.chroma_pickup_controller.add_pickup(sprite, value, velocity, tuning.pickup_air_time)


func restore_chroma_pickups(root: Object, saved_pickups: Array) -> void:
	for saved_pickup_value in saved_pickups:
		if not (saved_pickup_value is Dictionary):
			continue
		var saved_pickup := saved_pickup_value as Dictionary
		spawn_chroma_pickup(root, saved_pickup.get("position", root.player_start_position) as Vector2, int(saved_pickup.get("value", CHROMA_PICKUP_VALUE)), 1)
		var index: int = root.chroma_pickup_controller.sprites.size() - 1
		root.chroma_pickup_controller.air_times[index] = 0.0


func update_chroma_pickups(root: Object, delta: float) -> void:
	var index: int = root.chroma_pickup_controller.sprites.size() - 1
	while index >= 0:
		var pickup: Sprite2D = root.chroma_pickup_controller.sprites[index]
		if pickup == null or not is_instance_valid(pickup):
			remove_chroma_pickup(root, index)
			index -= 1
			continue
		if root.chroma_pickup_controller.air_times[index] > 0.0:
			root.chroma_pickup_controller.air_times[index] = maxf(root.chroma_pickup_controller.air_times[index] - delta, 0.0)
			var velocity: Vector2 = root.chroma_pickup_controller.velocities[index]
			velocity.y += 92.0 * delta
			var last_valid_position: Vector2 = pickup.get_meta("chroma_last_valid_position", pickup.global_position) as Vector2
			if not _drop_position_is_walkable(root, last_valid_position):
				last_valid_position = _safe_drop_position(root, pickup.global_position)
			var airborne_step := _advance_drop_position(root, last_valid_position, velocity, delta)
			last_valid_position = airborne_step["position"] as Vector2
			velocity = airborne_step["velocity"] as Vector2
			root.chroma_pickup_controller.velocities[index] = velocity
			pickup.global_position = last_valid_position
			pickup.set_meta("chroma_last_valid_position", last_valid_position)
			if root.chroma_pickup_controller.air_times[index] <= 0.0:
				pickup.set_meta("chroma_base_position", pickup.global_position)
				pickup.set_meta("chroma_last_valid_position", pickup.global_position)
		else:
			var base_position: Vector2 = pickup.get_meta("chroma_base_position", pickup.global_position) as Vector2
			if not _drop_position_is_walkable(root, base_position):
				base_position = _safe_drop_position(root, pickup.global_position)
			pickup.set_meta("chroma_base_position", base_position)
			pickup.set_meta("chroma_last_valid_position", base_position)
			var bob_time: float = float(pickup.get_meta("chroma_bob_time", 0.0)) + delta
			pickup.set_meta("chroma_bob_time", bob_time)
			var bob_phase: float = float(pickup.get_meta("chroma_bob_phase", 0.0))
			var bobbed_position := base_position + Vector2(0.0, sin(bob_time * CHROMA_BOB_SPEED + bob_phase) * CHROMA_BOB_AMPLITUDE)
			pickup.global_position = bobbed_position if bool(root.call("_is_slime_walkable_point", bobbed_position)) else base_position
			var distance: float = root.call("_actor_foot", root.player).distance_to(pickup.global_position)
			if distance <= root.chroma_tuning.pickup_collection_distance:
				collect_chroma_pickup(root, index)
				index -= 1
				continue
		pickup.z_index = int(round(pickup.global_position.y * DEPTH_Z_SCALE)) + 2
		var bob_time_for_scale: float = float(pickup.get_meta("chroma_bob_time", 0.0))
		var bob_phase_for_scale: float = float(pickup.get_meta("chroma_bob_phase", 0.0))
		pickup.scale = Vector2.ONE * (1.0 + sin(bob_time_for_scale * CHROMA_BOB_SPEED + bob_phase_for_scale) * 0.08)
		index -= 1


func collect_chroma_pickup(root: Object, index: int) -> void:
	var value: int = root.chroma_pickup_controller.values[index]
	var pickup: Sprite2D = root.chroma_pickup_controller.sprites[index]
	var restored := false
	if root.player_chroma_component != null and is_instance_valid(root.player_chroma_component):
		restored = bool(root.player_chroma_component.call("restore_neutral_chroma", value))
		root.call("_update_player_mp_ui")
	if restored:
		if pickup != null and is_instance_valid(pickup):
			root.call("_spawn_chroma_pickup_burst", pickup.global_position)
		root.call("_spawn_floating_number", root.call("_actor_foot", root.player) + Vector2(0, -18), 0, Vector2(0, -12), false, false, CHROMA_COLOR, "+%d CHROMA" % value)
		root.call("_play_sound", "item_pickup", -12.0, 1.15)
	remove_chroma_pickup(root, index)


func remove_chroma_pickup(root: Object, index: int) -> void:
	root.chroma_pickup_controller.remove(index)


func clear_chroma_pickups(root: Object) -> void:
	root.chroma_pickup_controller.clear()


func spawn_soul_pickup(root: Object, position: Vector2, value: int = 1, launch_seed: int = 0, launch_direction: Vector2 = Vector2.ZERO) -> void:
	var launch_rng := RandomNumberGenerator.new()
	var root_rng := root.get("rng") as RandomNumberGenerator
	launch_rng.seed = launch_seed if launch_seed != 0 else root_rng.randi() if root_rng != null else Time.get_ticks_msec()
	var sprite := Sprite2D.new()
	sprite.name = "SoulPickup"
	sprite.texture = soul_pickup_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.modulate = Color.WHITE
	var spawn_position := _safe_drop_position(root, position)
	sprite.global_position = spawn_position
	sprite.set_meta("soul_bob_phase", launch_rng.randf_range(0.0, TAU))
	sprite.set_meta("soul_bob_time", 0.0)
	sprite.set_meta("soul_base_position", spawn_position)
	sprite.set_meta("soul_last_valid_position", spawn_position)
	root.add_child(sprite)
	var velocity := Vector2(launch_rng.randf_range(-SOUL_PICKUP_LAUNCH_SPREAD, SOUL_PICKUP_LAUNCH_SPREAD), -SOUL_PICKUP_LAUNCH_SPEED)
	if launch_direction.length_squared() > 0.001:
		velocity = launch_direction.normalized() * SOUL_PICKUP_LAUNCH_SPEED
	root.soul_pickup_controller.add_pickup(sprite, value, velocity, SOUL_PICKUP_AIR_TIME)


func update_soul_pickups(root: Object, delta: float) -> void:
	var index: int = root.soul_pickup_controller.sprites.size() - 1
	while index >= 0:
		var pickup: Sprite2D = root.soul_pickup_controller.sprites[index]
		if pickup == null or not is_instance_valid(pickup):
			remove_soul_pickup(root, index)
			index -= 1
			continue
		if root.soul_pickup_controller.air_times[index] > 0.0:
			root.soul_pickup_controller.air_times[index] = maxf(root.soul_pickup_controller.air_times[index] - delta, 0.0)
			var velocity: Vector2 = root.soul_pickup_controller.velocities[index]
			velocity.y += SOUL_PICKUP_GRAVITY * delta
			var last_valid_position: Vector2 = pickup.get_meta("soul_last_valid_position", pickup.global_position) as Vector2
			if not _drop_position_is_walkable(root, last_valid_position):
				last_valid_position = _safe_drop_position(root, pickup.global_position)
			var airborne_step := _advance_drop_position(root, last_valid_position, velocity, delta)
			last_valid_position = airborne_step["position"] as Vector2
			velocity = airborne_step["velocity"] as Vector2
			root.soul_pickup_controller.velocities[index] = velocity
			pickup.global_position = last_valid_position
			pickup.set_meta("soul_last_valid_position", last_valid_position)
			if root.soul_pickup_controller.air_times[index] <= 0.0:
				pickup.set_meta("soul_base_position", pickup.global_position)
				pickup.set_meta("soul_last_valid_position", pickup.global_position)
		else:
			var base_position: Vector2 = pickup.get_meta("soul_base_position", pickup.global_position) as Vector2
			if not _drop_position_is_walkable(root, base_position):
				base_position = _safe_drop_position(root, pickup.global_position)
			pickup.set_meta("soul_base_position", base_position)
			pickup.set_meta("soul_last_valid_position", base_position)
			var bob_time: float = float(pickup.get_meta("soul_bob_time", 0.0)) + delta
			pickup.set_meta("soul_bob_time", bob_time)
			var bob_phase: float = float(pickup.get_meta("soul_bob_phase", 0.0))
			var bobbed_position := base_position + Vector2(0.0, sin(bob_time * SOUL_BOB_SPEED + bob_phase) * SOUL_BOB_AMPLITUDE)
			pickup.global_position = bobbed_position if bool(root.call("_is_slime_walkable_point", bobbed_position)) else base_position
			var distance: float = root.call("_actor_foot", root.player).distance_to(pickup.global_position)
			var collection_distance := float(root.get("SOUL_PICKUP_COLLECTION_DISTANCE")) if root.get("SOUL_PICKUP_COLLECTION_DISTANCE") != null else SOUL_PICKUP_COLLECTION_DISTANCE
			if distance <= collection_distance:
				collect_soul_pickup(root, index)
				index -= 1
				continue
		pickup.z_index = int(round(pickup.global_position.y * DEPTH_Z_SCALE)) + 2
		var bob_time_for_scale: float = float(pickup.get_meta("soul_bob_time", 0.0))
		var bob_phase_for_scale: float = float(pickup.get_meta("soul_bob_phase", 0.0))
		pickup.scale = Vector2.ONE * (1.0 + sin(bob_time_for_scale * SOUL_BOB_SPEED + bob_phase_for_scale) * 0.08)
		index -= 1


func collect_soul_pickup(root: Object, index: int) -> void:
	if index < 0 or index >= root.soul_pickup_controller.values.size():
		return
	var value: int = root.soul_pickup_controller.values[index]
	var pickup: Sprite2D = root.soul_pickup_controller.sprites[index]
	if root.player_profile == null:
		remove_soul_pickup(root, index)
		return
	root.player_profile.add_souls(value)
	root.call("_save_player_profile")
	root.call("_update_soul_indicator")
	var acquired_text := "+%d SOUL%s" % [value, "" if value == 1 else "S"]
	var acquired_origin: Vector2 = root.call("_player_floating_number_origin", acquired_text, SOUL_COLOR) as Vector2
	root.call("_spawn_floating_number", acquired_origin + Vector2(0, -18), 0, Vector2(0, -12), false, false, SOUL_COLOR, acquired_text)
	root.call("_play_sound", "item_pickup", -10.0, 1.0)
	remove_soul_pickup(root, index)


func remove_soul_pickup(root: Object, index: int) -> void:
	if index < 0 or index >= root.soul_pickup_controller.sprites.size():
		return
	root.soul_pickup_controller.remove(index)


func clear_soul_pickups(root: Object) -> void:
	root.soul_pickup_controller.clear()
