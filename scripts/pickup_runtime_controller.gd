extends Node
class_name PickupRuntimeController

const CHEST_INTERACT_DISTANCE := 16.0
const DEPTH_Z_SCALE := 10.0
const CHROMA_PICKUP_VALUE := 25


func placeholder_item_texture() -> Texture2D:
	var image := Image.create(6, 6, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func spawn_chest_item_drop(root: Object, item: ItemInstance) -> void:
	if root.world_item_drop != null and is_instance_valid(root.world_item_drop):
		root.world_item_drop.queue_free()
	if root.world_item_drop_label != null and is_instance_valid(root.world_item_drop_label):
		root.world_item_drop_label.queue_free()
	var catalog := ItemCatalog.new()
	var sprite := Sprite2D.new()
	sprite.name = "ChestItemDrop"
	sprite.texture = placeholder_item_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.modulate = catalog.rarity_color(item.rarity)
	sprite.global_position = root.chest.global_position + Vector2(0, -4)
	sprite.z_as_relative = false
	sprite.z_index = root.chest.z_index + 3
	root.add_child(sprite)
	var label := Sprite2D.new()
	label.name = "ChestItemDropLabel"
	var item_name := str(ItemCatalog.DEFINITIONS.get(item.definition_id, {}).get("name", "ITEM"))
	label.texture = root.call("_pixel_text_texture", "%s %s +%d" % [catalog.rarity_letter_grade(item.rarity), item_name, item.enhancement_level], catalog.rarity_color(item.rarity))
	label.centered = true
	label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	label.z_as_relative = false
	label.z_index = sprite.z_index + 1
	root.add_child(label)
	root.world_item_drop = sprite
	root.world_item_drop_label = label
	root.world_item_drop_instance = item
	var launch_rng := RandomNumberGenerator.new()
	launch_rng.seed = item.instance_id.hash()
	root.world_item_drop_velocity = Vector2(launch_rng.randf_range(-18.0, 18.0), -30.0)
	root.world_item_drop_air_time = 0.38
	constrain_world_item_drop(root)


func restore_chest_item_drop(root: Object, item: ItemInstance, saved_position: Vector2) -> void:
	spawn_chest_item_drop(root, item)
	root.world_item_drop.global_position = root.call("_nearest_slime_walkable_point", saved_position)
	root.world_item_drop_velocity = Vector2.ZERO
	root.world_item_drop_air_time = 0.0


func constrain_world_item_drop(root: Object) -> void:
	if root.world_item_drop == null or not is_instance_valid(root.world_item_drop):
		return
	root.world_item_drop.global_position = root.call("_nearest_slime_walkable_point", root.world_item_drop.global_position)


func update_world_item_drop(root: Object, delta: float) -> void:
	if root.world_item_drop == null or not is_instance_valid(root.world_item_drop):
		return
	if root.world_item_drop_air_time > 0.0:
		root.world_item_drop_air_time = maxf(root.world_item_drop_air_time - delta, 0.0)
		root.world_item_drop_velocity.y += 92.0 * delta
		root.world_item_drop.global_position += root.world_item_drop_velocity * delta
		constrain_world_item_drop(root)
		if root.world_item_drop_air_time <= 0.0:
			root.world_item_drop_velocity = Vector2.ZERO
	var distance: float = root.call("_actor_foot", root.player).distance_to(root.world_item_drop.global_position)
	if distance < 10.0 and root.player_is_moving and root.world_item_drop_air_time <= 0.0:
		var push: Vector2 = root.world_item_drop.global_position - root.call("_actor_foot", root.player)
		if push.length_squared() < 0.01:
			push = root.call("_player_facing_vector")
		root.world_item_drop.global_position += push.normalized() * 18.0 * delta
		constrain_world_item_drop(root)
	root.world_item_drop.z_index = int(round(root.world_item_drop.global_position.y * DEPTH_Z_SCALE)) + 2
	if root.world_item_drop_label != null and is_instance_valid(root.world_item_drop_label):
		root.world_item_drop_label.global_position = root.world_item_drop.global_position + Vector2(0, -10)
		root.world_item_drop_label.z_index = root.world_item_drop.z_index + 1


func can_interact_with_world_item(root: Object) -> bool:
	return root.world_item_drop != null and is_instance_valid(root.world_item_drop) and root.world_item_drop_air_time <= 0.0 and root.call("_actor_foot", root.player).distance_to(root.world_item_drop.global_position) <= CHEST_INTERACT_DISTANCE


func collect_world_item_drop(root: Object) -> bool:
	if not can_interact_with_world_item(root) or root.world_item_drop_instance == null or root.player_profile == null:
		return false
	if not root.player_profile.grant_item(root.world_item_drop_instance):
		return false
	root.call("_save_player_profile")
	root.call("_spawn_floating_number", root.call("_actor_foot", root.player) + Vector2(0, -18), 0, Vector2(0, -12), false, false, Color("ffd866"), "FOUND %s" % ItemCatalog.new().display_name(root.world_item_drop_instance))
	root.call("_play_sound", "item_pickup", -4.0, 1.0)
	root.world_item_drop.queue_free()
	if root.world_item_drop_label != null:
		root.world_item_drop_label.queue_free()
	root.world_item_drop = null
	root.world_item_drop_label = null
	root.world_item_drop_instance = null
	return true


func spawn_chroma_pickup(root: Object, position: Vector2, value: int = CHROMA_PICKUP_VALUE, launch_seed: int = 0, launch_direction: Vector2 = Vector2.ZERO) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "ChromaPickup"
	sprite.texture = root.call("_pixel_particle_texture", Color("9fe3b4"), 3)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_as_relative = false
	sprite.modulate = Color("d8ffe8")
	sprite.global_position = root.call("_nearest_slime_walkable_point", position)
	root.add_child(sprite)
	var launch_rng := RandomNumberGenerator.new()
	launch_rng.seed = launch_seed if launch_seed != 0 else root.rng.randi()
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
			root.chroma_pickup_controller.velocities[index] = velocity
			pickup.global_position += velocity * delta
			pickup.global_position = root.call("_nearest_slime_walkable_point", pickup.global_position)
		else:
			var distance: float = root.call("_actor_foot", root.player).distance_to(pickup.global_position)
			if distance <= root.chroma_tuning.pickup_collection_distance:
				collect_chroma_pickup(root, index)
				index -= 1
				continue
		pickup.z_index = int(round(pickup.global_position.y * DEPTH_Z_SCALE)) + 2
		pickup.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.008 + float(index)) * 0.08)
		index -= 1


func collect_chroma_pickup(root: Object, index: int) -> void:
	var value: int = root.chroma_pickup_controller.values[index]
	var restored := false
	if root.player_chroma_component != null and is_instance_valid(root.player_chroma_component):
		restored = bool(root.player_chroma_component.call("restore_neutral_chroma", value))
		root.call("_update_player_mp_ui")
	if restored:
		root.call("_spawn_floating_number", root.call("_actor_foot", root.player) + Vector2(0, -18), 0, Vector2(0, -12), false, false, Color("9fe3b4"), "+%d CHROMA" % value)
		root.call("_play_sound", "item_pickup", -6.0, 1.15)
	remove_chroma_pickup(root, index)


func remove_chroma_pickup(root: Object, index: int) -> void:
	root.chroma_pickup_controller.remove(index)


func clear_chroma_pickups(root: Object) -> void:
	root.chroma_pickup_controller.clear()
