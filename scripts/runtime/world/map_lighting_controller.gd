extends Node
class_name MapLightingController

## Scheduled map-only illumination. PointLight2D nodes remain typed source
## records; this shared shader owns the strongest-source blend instead of ADD.
const FIELD_SHADER: Shader = preload("res://shaders/map_light_field.gdshader")
const SOURCE_GROUP := &"map_light_sources"
const MAX_LIGHTS := 64
const INNER_RADIUS := 0.58
const INNER_LEVEL := 0.78
const OUTER_LEVEL := 0.40
const AMBIENT := 0.60
const FOREGROUND_MATERIAL = preload("res://resources/materials/gameplay_sprite_unshaded.tres")
const CHEST_MAP_MATERIAL := &"chest_map_light_material"


static func set_chest_collectible(chest: Sprite2D, collectible: bool) -> void:
	if chest == null or not chest.has_meta(CHEST_MAP_MATERIAL):
		return
	chest.material = FOREGROUND_MATERIAL if collectible else chest.get_meta(CHEST_MAP_MATERIAL) as Material
	chest.use_parent_material = false

@export var environment_path: NodePath = ^"../Map"
@export var ambience_path: NodePath = ^"../RoomAmbience"
@export var chest_path: NodePath = ^"../Actors/Props/Chest"
@export var firepit_path: NodePath = ^"../Actors/Props/RestFire/Firepit"

var field_material: ShaderMaterial = ShaderMaterial.new()
var centers := PackedVector4Array()
var inverse_axes := PackedVector4Array()
var colors := PackedVector4Array()
var source_count := 0
var _environment: Node = null
var _chest: Node = null
var _firepit: Node = null


func _ready() -> void:
	field_material.shader = FIELD_SHADER
	field_material.set_shader_parameter("ambient", AMBIENT)
	field_material.set_shader_parameter("inner_radius", INNER_RADIUS)
	field_material.set_shader_parameter("inner_level", INNER_LEVEL)
	field_material.set_shader_parameter("outer_level", OUTER_LEVEL)
	_environment = get_node_or_null(environment_path)
	_chest = get_node_or_null(chest_path)
	_firepit = get_node_or_null(firepit_path)
	var ambience := get_node_or_null(ambience_path) as CanvasModulate
	if ambience != null:
		ambience.color = Color.WHITE
	_enroll_tree(get_parent())
	get_tree().node_added.connect(_enroll_item)
	refresh_field()


static func refresh_for_actor(actor: Sprite2D) -> void:
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return
	var scene := actor.get_tree().current_scene
	if scene == null:
		return
	var controller := scene.get_node_or_null("MapLighting") as MapLightingController
	if controller != null:
		controller.refresh_field()


func refresh_field() -> void:
	var sources: Array[PointLight2D] = []
	for node in get_tree().get_nodes_in_group(SOURCE_GROUP):
		if node is PointLight2D and get_parent().is_ancestor_of(node):
			sources.append(node as PointLight2D)
	var view := get_viewport()
	var world_view := view.get_canvas_transform().affine_inverse() * view.get_visible_rect()
	capture_sources(sources, world_view)


## Explicit typed boundary, also used by focused owner verification.
func capture_sources(sources: Array[PointLight2D], world_view: Rect2 = Rect2()) -> void:
	var candidates: Array[PointLight2D] = []
	for source in sources:
		if source == null or not is_instance_valid(source) or source.is_queued_for_deletion():
			continue
		if not source.is_visible_in_tree() or source.texture == null or source.energy <= 0.0:
			continue
		var half_size := Vector2(source.texture.get_size()) * source.texture_scale * 0.5
		if half_size.x <= 0.0 or half_size.y <= 0.0 or is_zero_approx(source.global_transform.determinant()):
			continue
		var local_rect := Rect2(source.offset - half_size, half_size * 2.0)
		if world_view.has_area() and not (source.global_transform * local_rect).intersects(world_view):
			continue
		candidates.append(source)
	if candidates.size() > MAX_LIGHTS:
		var view_center := world_view.get_center()
		candidates.sort_custom(func(a: PointLight2D, b: PointLight2D) -> bool:
			var a_priority := int(a.get_meta("map_light_priority", 2))
			var b_priority := int(b.get_meta("map_light_priority", 2))
			if a_priority != b_priority:
				return a_priority > b_priority
			var a_distance := a.global_position.distance_squared_to(view_center)
			var b_distance := b.global_position.distance_squared_to(view_center)
			return a_distance < b_distance if not is_equal_approx(a_distance, b_distance) else a.get_instance_id() < b.get_instance_id())
	source_count = mini(candidates.size(), MAX_LIGHTS)
	centers.resize(MAX_LIGHTS)
	inverse_axes.resize(MAX_LIGHTS)
	colors.resize(MAX_LIGHTS)
	for index in source_count:
		var source := candidates[index]
		var half_size := Vector2(source.texture.get_size()) * source.texture_scale * 0.5
		var inverse := source.global_transform.affine_inverse()
		var center := source.to_global(source.offset)
		centers[index] = Vector4(center.x, center.y, clampf(source.energy * source.color.a, 0.0, 1.0), 0.0)
		inverse_axes[index] = Vector4(inverse.x.x / half_size.x, inverse.y.x / half_size.x, inverse.x.y / half_size.y, inverse.y.y / half_size.y)
		colors[index] = Vector4(source.color.r, source.color.g, source.color.b, 1.0)
	field_material.set_shader_parameter("light_count", source_count)
	field_material.set_shader_parameter("light_centers", centers)
	field_material.set_shader_parameter("light_inverse_axes", inverse_axes)
	field_material.set_shader_parameter("light_colors", colors)


## CPU counterpart for overlap/shape verification; matches shader pixel snapping.
func sample_at(world_position: Vector2) -> Color:
	var pixel := world_position.floor() + Vector2.ONE * 0.5
	var strongest := 0.0
	var tint_sum := Vector3.ZERO
	var tint_count := 0
	for index in source_count:
		var center := centers[index]
		var delta := pixel - Vector2(center.x, center.y)
		var axes := inverse_axes[index]
		var local := Vector2(Vector2(axes.x, axes.y).dot(delta), Vector2(axes.z, axes.w).dot(delta))
		var radius_squared := local.length_squared()
		var band := INNER_LEVEL if radius_squared < INNER_RADIUS * INNER_RADIUS else OUTER_LEVEL
		var strength := band * center.z if radius_squared < 1.0 else 0.0
		var tint := colors[index]
		if strength > strongest + 0.000001:
			strongest = strength
			tint_sum = Vector3(tint.x, tint.y, tint.z)
			tint_count = 1
		elif strength > 0.0 and absf(strength - strongest) <= 0.000001:
			tint_sum += Vector3(tint.x, tint.y, tint.z)
			tint_count += 1
	var illumination := Vector3.ONE * AMBIENT + tint_sum * strongest / float(maxi(tint_count, 1))
	return Color(illumination.x, illumination.y, illumination.z, 1.0)


func _enroll_tree(node: Node) -> void:
	_enroll_item(node)
	for child in node.get_children():
		_enroll_tree(child)


func _enroll_item(node: Node) -> void:
	if not _is_map_artwork(node):
		return
	var item := node as CanvasItem
	# Do not replace any independently authored shader/material.
	if item.material == null or item.material == field_material:
		item.use_parent_material = false
		item.material = field_material
		if node == _chest:
			node.set_meta(CHEST_MAP_MATERIAL, field_material)


func _is_map_artwork(node: Node) -> bool:
	if node == _chest or node == _firepit:
		return true
	if _environment == null or not _environment.is_ancestor_of(node):
		return false
	if node is Sprite2D or node is TileMapLayer:
		return true
	return node is Polygon2D and node.name == &"FloorUnderlay"
