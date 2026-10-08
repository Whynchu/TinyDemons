extends RefCounted
class_name ActorLightingController

const LIGHT_TEXTURE: Texture2D = preload("res://resources/lighting/point_light_falloff.tres")
const ACTOR_LIGHT_NAME := &"ActorLight"
const ELEMENTAL_LIGHT_NAME := &"ElementalLight"
const LIGHT_ENERGY := 0.12
const DEFAULT_LIGHT_SCALE := 0.46
const SMALL_ENEMY_LIGHT_SCALE := 0.30
const ENEMY_LIGHT_SCALE := 0.46
const ELEMENTAL_LIGHT_ENERGY := 0.38
const ELEMENTAL_LIGHT_SCALE := 0.44


static func attach_actor_light(actor: Sprite2D) -> PointLight2D:
	if actor == null or not is_instance_valid(actor):
		return null
	var light := actor.get_node_or_null(NodePath(ACTOR_LIGHT_NAME)) as PointLight2D
	if light == null:
		light = _new_light(actor, ACTOR_LIGHT_NAME)
	_configure_light(light, Color.WHITE, LIGHT_ENERGY, _light_scale_for(actor))
	light.position = _light_center_for(actor)
	return light


static func attach_elemental_light(
	owner: Node2D,
	color: Color,
	energy: float = ELEMENTAL_LIGHT_ENERGY,
	texture_scale: float = ELEMENTAL_LIGHT_SCALE,
	light_name: StringName = ELEMENTAL_LIGHT_NAME
) -> PointLight2D:
	if owner == null or not is_instance_valid(owner):
		return null
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
	light.texture = LIGHT_TEXTURE
	light.color = color
	light.energy = maxf(energy, 0.0)
	light.texture_scale = maxf(texture_scale, 0.01)
	light.shadow_enabled = false
	light.z_index = -1
	light.visible = true


static func _light_scale_for(actor: Sprite2D) -> float:
	if actor is SkeletonActor:
		return ENEMY_LIGHT_SCALE
	if actor is SlimeActor:
		return SMALL_ENEMY_LIGHT_SCALE
	return DEFAULT_LIGHT_SCALE


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
