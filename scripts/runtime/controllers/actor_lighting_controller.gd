extends RefCounted
class_name ActorLightingController

const LIGHT_TEXTURE: Texture2D = preload("res://resources/lighting/point_light_falloff.tres")
const MAP_LIGHTING = preload("res://scripts/runtime/world/map_lighting_controller.gd")
const UNSHADED_SPRITE_MATERIAL: CanvasItemMaterial = preload("res://resources/materials/gameplay_sprite_unshaded.tres")
const ACTOR_LIGHT_NAME := &"ActorLight"
const ELEMENTAL_LIGHT_NAME := &"ElementalLight"
const LIGHT_ENERGY := 0.12
const ACTOR_LIGHT_COVERAGE := 1.8
const ACTOR_LIGHT_PADDING := 8.0
const WEAPON_LIGHT_COVERAGE := 1.3
const WEAPON_LIGHT_PADDING := 4.0
const ELEMENTAL_LIGHT_ENERGY := 0.38
const ELEMENTAL_LIGHT_SCALE := 0.44
const PLAYER_REFERENCE_BOUNDS := &"player_light_reference_bounds"
const FIRE_PLAYER_SIZE_RATIO := 1.5
const PLAYER_LIGHT_COVERAGE := 1.35
const PLAYER_LIGHT_PADDING := 6.0


static func configure_player_reference(player: Sprite2D, attack_visual: Sprite2D, idle_frames: Array[Texture2D]) -> void:
	if player == null or idle_frames.is_empty():
		return
	var bounds := Rect2()
	for texture in idle_frames:
		if texture == null:
			continue
		var image := texture.get_image()
		if image == null or image.is_empty():
			continue
		var frame_bounds := Rect2(image.get_used_rect())
		if frame_bounds.has_area():
			bounds = bounds.merge(frame_bounds) if bounds.has_area() else frame_bounds
	if not bounds.has_area():
		return
	player.set_meta(PLAYER_REFERENCE_BOUNDS, bounds)
	if attack_visual != null:
		attack_visual.set_meta(PLAYER_REFERENCE_BOUNDS, bounds)


static func fit_rest_fire_light(light: PointLight2D, player: Sprite2D, flicker: float) -> void:
	if light == null or player == null or light.texture == null:
		return
	var drawn_rect := player.get_rect() if player.texture != null else Rect2(Vector2.ZERO, Vector2(16.0, 16.0))
	if player.has_meta(PLAYER_REFERENCE_BOUNDS):
		drawn_rect = player.get_meta(PLAYER_REFERENCE_BOUNDS) as Rect2
		drawn_rect.position += player.get_rect().position
	var world_rect := player.global_transform * drawn_rect
	if not world_rect.has_area():
		return
	var diameter := Vector2(world_rect.size.x, world_rect.size.y * 2.0).length() * PLAYER_LIGHT_COVERAGE + PLAYER_LIGHT_PADDING
	var size := Vector2(diameter, diameter * 0.5) * FIRE_PLAYER_SIZE_RATIO * clampf(flicker, 0.95, 1.05)
	light.texture_scale = 1.0
	light.global_scale = size / Vector2(light.texture.get_size())


static func preserve_sprite_colors(sprite: CanvasItem) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	# Palette/desaturation shaders own their slot and declare unshaded themselves.
	# Plain foreground art keeps its authored tint and alpha, independent of the map.
	sprite.use_parent_material = false
	if sprite.material == null:
		sprite.material = UNSHADED_SPRITE_MATERIAL
	elif sprite.material is CanvasItemMaterial:
		var material := sprite.material as CanvasItemMaterial
		if material.light_mode != CanvasItemMaterial.LIGHT_MODE_UNSHADED:
			material = material.duplicate() as CanvasItemMaterial
			material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
			sprite.material = material


static func attach_actor_light(actor: Sprite2D) -> PointLight2D:
	if actor == null or not is_instance_valid(actor):
		return null
	preserve_sprite_colors(actor)
	var light := actor.get_node_or_null(NodePath(ACTOR_LIGHT_NAME)) as PointLight2D
	if light == null:
		light = _new_light(actor, ACTOR_LIGHT_NAME)
	_configure_light(light, Color.WHITE, LIGHT_ENERGY, 1.0)
	var drawn_rect := actor.get_rect() if actor.texture != null else Rect2(Vector2.ZERO, Vector2(16.0, 16.0))
	_fit_actor_light(actor, light, drawn_rect)
	return light


static func refresh_actor_lights(actors: Array[Sprite2D], player: Sprite2D, attack_visual: Sprite2D, npc: Sprite2D, effects: EffectsSpawner, renderer: OcclusionRenderer) -> void:
	if effects == null:
		return
	for actor in actors:
		_refresh_actor_light(actor, effects, renderer)
	_refresh_actor_light(npc, effects, renderer)
	# Attacks hide the base player Sprite2D. Its child light is hidden too, so
	# the separately rendered attack pose needs its own light and status tint.
	_refresh_actor_light(attack_visual, effects, renderer)
	if player != null and attack_visual != null and attack_visual.visible:
		refresh_actor_status_tint(attack_visual, player.get_node_or_null("Status") as StatusComponent)
	MAP_LIGHTING.refresh_for_actor(player)


static func _refresh_actor_light(actor: Sprite2D, effects: EffectsSpawner, renderer: OcclusionRenderer) -> void:
	preserve_sprite_colors(actor)
	if actor == null or not is_instance_valid(actor) or not actor.visible or actor.texture == null:
		return
	var source_texture := actor.texture
	if renderer != null:
		source_texture = renderer.original_actor_textures.get(actor, source_texture) as Texture2D
	var drawn_rect := effects.sprite_drawn_rect(actor, source_texture)
	var light := actor.get_node_or_null(NodePath(ACTOR_LIGHT_NAME)) as PointLight2D
	if light == null:
		light = attach_actor_light(actor)
	_fit_actor_light(actor, light, drawn_rect)
	refresh_actor_status_tint(actor, actor.get_node_or_null("Status") as StatusComponent)


static func attach_weapon_light(weapon: Sprite2D, color: Color, drawn_rect: Rect2) -> PointLight2D:
	var light := attach_elemental_light(weapon, color, 0.34)
	if light != null:
		_fit_light_to_drawn_rect(light, drawn_rect, WEAPON_LIGHT_COVERAGE, WEAPON_LIGHT_PADDING)
	return light


static func attach_impact_light(owner: Sprite2D, color: Color, drawn_rect: Rect2) -> PointLight2D:
	var light := attach_elemental_light(owner, color, 0.32)
	if light != null:
		_fit_light_to_drawn_rect(light, drawn_rect, 1.25, 4.0)
	return light


static func _fit_actor_light(actor: Sprite2D, light: PointLight2D, drawn_rect: Rect2) -> void:
	if actor.has_meta(PLAYER_REFERENCE_BOUNDS):
		drawn_rect = actor.get_meta(PLAYER_REFERENCE_BOUNDS) as Rect2
		drawn_rect.position += actor.get_rect().position
	light.visible = drawn_rect.has_area()
	if not light.visible:
		return
	var world_rect := actor.global_transform * drawn_rect
	var fixed_player := actor.has_meta(PLAYER_REFERENCE_BOUNDS)
	var coverage := PLAYER_LIGHT_COVERAGE if fixed_player else ACTOR_LIGHT_COVERAGE
	var padding := PLAYER_LIGHT_PADDING if fixed_player else ACTOR_LIGHT_PADDING
	var diameter := Vector2(world_rect.size.x, world_rect.size.y * 2.0).length() * coverage + padding
	light.texture_scale = 1.0
	light.global_transform = Transform2D(0.0, Vector2(diameter, diameter * 0.5) / Vector2(LIGHT_TEXTURE.get_size()), 0.0, world_rect.get_center())


static func _fit_light_to_drawn_rect(light: PointLight2D, drawn_rect: Rect2, coverage: float, padding: float) -> void:
	light.visible = drawn_rect.has_area()
	if not light.visible:
		return
	light.position = drawn_rect.get_center()
	# A circle wider than the sprite's diagonal surrounds every drawn corner.
	# Normalize the shared fire texture's 2:1 dimensions before applying size.
	var diameter := drawn_rect.size.length() * coverage + padding
	light.texture_scale = 1.0
	light.scale = Vector2.ONE * diameter / Vector2(LIGHT_TEXTURE.get_size())


static func attach_elemental_light(
	owner: Node2D,
	color: Color,
	energy: float = ELEMENTAL_LIGHT_ENERGY,
	texture_scale: float = ELEMENTAL_LIGHT_SCALE,
	light_name: StringName = ELEMENTAL_LIGHT_NAME
) -> PointLight2D:
	if owner == null or not is_instance_valid(owner):
		return null
	preserve_sprite_colors(owner)
	var light := owner.get_node_or_null(NodePath(light_name)) as PointLight2D
	if light == null:
		light = _new_light(owner, light_name)
	_configure_light(light, color, energy, texture_scale)
	light.position = _light_center_for(owner)
	return light


static func hide_elemental_light(owner: Node2D, light_name: StringName = ELEMENTAL_LIGHT_NAME) -> void:
	if owner == null or not is_instance_valid(owner):
		return
	var light := owner.get_node_or_null(NodePath(light_name)) as PointLight2D
	if light != null:
		light.visible = false


static func refresh_actor_status_tint(actor: Sprite2D, status_component: StatusComponent) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var light := actor.get_node_or_null(NodePath(ACTOR_LIGHT_NAME)) as PointLight2D
	if light == null:
		return
	var definition := status_component.strongest_applied_definition() if status_component != null else null
	if definition == null:
		light.color = Color.WHITE
		return
	light.color = PaletteLibrary.accent(ElementCatalog.palette_key(definition.element))


static func _new_light(owner: Node2D, light_name: StringName) -> PointLight2D:
	var light := PointLight2D.new()
	light.name = light_name
	light.texture = LIGHT_TEXTURE
	light.shadow_enabled = false
	light.z_index = -1
	owner.add_child(light)
	return light


static func _configure_light(light: PointLight2D, color: Color, energy: float, texture_scale: float) -> void:
	light.enabled = false
	if not light.is_in_group(MAP_LIGHTING.SOURCE_GROUP):
		light.add_to_group(MAP_LIGHTING.SOURCE_GROUP)
	light.set_meta("map_light_priority", 2 if light.name == ACTOR_LIGHT_NAME else (1 if light.name == &"ChromaLight" else 3))
	light.texture = LIGHT_TEXTURE
	light.color = color
	light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	light.energy = maxf(energy, 0.0)
	light.texture_scale = maxf(texture_scale, 0.01)
	light.scale = Vector2.ONE
	light.shadow_enabled = false
	light.z_index = -1
	light.visible = true


static func _light_center_for(owner: Node2D) -> Vector2:
	if owner is Sprite2D:
		var actor := owner as Sprite2D
		if actor.texture != null:
			var actor_rect := actor.get_rect()
			if actor_rect.size.x > 0.0 and actor_rect.size.y > 0.0:
				return actor_rect.get_center()
		if actor is SkeletonActor:
			return Vector2(SkeletonActor.FRAME_SIZE) * 0.5
	if owner is Line2D:
		var points := (owner as Line2D).points
		if points.size() >= 2:
			return points[0].lerp(points[1], 0.5)
	return Vector2(8.0, 8.0)
