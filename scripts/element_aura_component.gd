extends Node
class_name ElementAuraComponent

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

@export var actor_sprite: Sprite2D
# Player attacks temporarily render through a separate sprite; include it in the aura source set.
@export var alternate_actor_sprite: Sprite2D
@export var overlay_parent: Node2D
@export var status_component: StatusComponent

var health_component: HealthComponent = null
var _outline_texture_cache: Dictionary = {}
var _tint_texture_cache: Dictionary = {}
var _imbue_outlines: Dictionary = {}
var _imbue_flashes: Dictionary = {}
var _status_outline: Sprite2D = null
var _status_particle_timers: Dictionary = {}
var _stun_shake_remaining := 0.0
var _stun_shake_duration := 0.0
var _stun_shake_amplitude := 0.0


func _ready() -> void:
	refresh_status_aura()


func configure(new_actor_sprite: Sprite2D, new_overlay_parent: Node2D, new_status_component: StatusComponent, new_alternate_actor_sprite: Sprite2D = null) -> void:
	var ownership_changed := actor_sprite != new_actor_sprite or alternate_actor_sprite != new_alternate_actor_sprite or overlay_parent != new_overlay_parent
	if health_component != null and is_instance_valid(health_component) and health_component.died.is_connected(_on_actor_died):
		health_component.died.disconnect(_on_actor_died)
	if status_component != null and is_instance_valid(status_component) and status_component.status_changed.is_connected(refresh_status_aura):
		status_component.status_changed.disconnect(refresh_status_aura)
	if ownership_changed:
		_queue_status_outline()
	actor_sprite = new_actor_sprite
	alternate_actor_sprite = new_alternate_actor_sprite
	overlay_parent = new_overlay_parent
	status_component = new_status_component
	health_component = actor_sprite.get_node_or_null("Health") as HealthComponent if actor_sprite != null else null
	if health_component != null and not health_component.died.is_connected(_on_actor_died):
		health_component.died.connect(_on_actor_died)
	if status_component != null and not status_component.status_changed.is_connected(refresh_status_aura):
		status_component.status_changed.connect(refresh_status_aura)
	refresh_status_aura()


func clear_status_visuals() -> void:
	_status_particle_timers.clear()
	_stun_shake_remaining = 0.0
	_stun_shake_duration = 0.0
	_stun_shake_amplitude = 0.0
	_queue_status_outline()


func _on_actor_died() -> void:
	var component := _valid_status_component(status_component)
	if component != null:
		component.clear_all()
	clear_status_visuals()


func update_imbue_layer(layer: Sprite2D, outline_color: Color, outline_alpha: float, flash_color: Color, flash_alpha: float) -> void:
	if layer == null or not is_instance_valid(layer) or layer.texture == null or overlay_parent == null or not is_instance_valid(overlay_parent):
		return
	var outline := _valid_sprite(_imbue_outlines.get(layer))
	if outline == null:
		outline = _new_sibling_overlay(layer, "%sImbueOutline" % layer.name)
		_imbue_outlines[layer] = outline
	outline.texture = _outline_texture(layer, outline_color)
	_sync_imbue_overlay(outline, layer, true)
	outline.modulate = Color(1.0, 1.0, 1.0, clampf(outline_alpha, 0.0, 1.0))
	outline.visible = outline_alpha > 0.0
	var flash := _valid_sprite(_imbue_flashes.get(layer))
	if flash == null:
		flash = _new_sibling_overlay(layer, "%sImbueFlash" % layer.name)
		_imbue_flashes[layer] = flash
	flash.texture = _tint_texture(layer, flash_color)
	_sync_imbue_overlay(flash, layer, false)
	flash.modulate = Color(1.0, 1.0, 1.0, clampf(flash_alpha, 0.0, 1.0))
	flash.visible = flash_alpha > 0.0


func hide_unused_imbue_layers(visible_layers: Dictionary) -> void:
	for layer_value in _imbue_outlines.keys():
		var overlay := _valid_sprite(_imbue_outlines.get(layer_value))
		if not is_instance_valid(layer_value) or overlay == null:
			_imbue_outlines.erase(layer_value)
			continue
		overlay.visible = visible_layers.has(layer_value) and overlay.modulate.a > 0.0
	for layer_value in _imbue_flashes.keys():
		var overlay := _valid_sprite(_imbue_flashes.get(layer_value))
		if not is_instance_valid(layer_value) or overlay == null:
			_imbue_flashes.erase(layer_value)
			continue
		overlay.visible = visible_layers.has(layer_value) and overlay.modulate.a > 0.0


func clear_imbue() -> void:
	for overlay_value in _imbue_outlines.values():
		var overlay := _valid_sprite(overlay_value)
		if overlay != null:
			overlay.queue_free()
	for overlay_value in _imbue_flashes.values():
		var overlay := _valid_sprite(overlay_value)
		if overlay != null:
			overlay.queue_free()
	_imbue_outlines.clear()
	_imbue_flashes.clear()


func refresh_status_aura() -> void:
	var actor := _active_actor_sprite()
	var component := _valid_status_component(status_component)
	var definition: StatusEffectDefinition = component.strongest_active_definition() if component != null else null
	if actor == null or definition == null or actor.texture == null or overlay_parent == null or not is_instance_valid(overlay_parent):
		var old_outline := _valid_sprite(_status_outline)
		if old_outline != null:
			old_outline.visible = false
		return
	if _valid_sprite(_status_outline) == null or _status_outline.get_parent() != overlay_parent:
		_queue_status_outline()
		_status_outline = Sprite2D.new()
		_status_outline.name = "ElementStatusOutline"
		_status_outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_status_outline.z_as_relative = true
		overlay_parent.add_child(_status_outline)
	_status_outline.texture = _outline_texture(actor, ElementCatalogScript.damage_number_color(definition.element))
	sync_status_outline_transform()
	_status_outline.visible = actor.visible and actor.is_visible_in_tree()


func sync_status_outline_transform() -> void:
	var actor := _active_actor_sprite()
	var outline := _valid_sprite(_status_outline)
	if actor == null or outline == null:
		return
	_status_outline.centered = actor.centered
	_status_outline.global_transform = actor.global_transform
	_status_outline.offset = actor.offset + (Vector2.ZERO if actor.centered else Vector2(-1.0, -1.0))
	_status_outline.flip_h = actor.flip_h
	_status_outline.flip_v = actor.flip_v
	_status_outline.z_as_relative = actor.z_as_relative
	_status_outline.z_index = actor.z_index - 1


func trigger_status_stun_shake(duration: float, is_initial_pulse: bool) -> void:
	var lock_duration := maxf(duration, 0.0)
	if lock_duration <= 0.0:
		return
	_stun_shake_remaining = lock_duration
	_stun_shake_duration = lock_duration
	_stun_shake_amplitude = 3.0 if is_initial_pulse else 2.0


func status_stun_visual_offset() -> Vector2:
	if _stun_shake_remaining <= 0.0 or _stun_shake_duration <= 0.0:
		return Vector2.ZERO
	var progress := clampf(1.0 - _stun_shake_remaining / _stun_shake_duration, 0.0, 1.0)
	var envelope := 1.0 - progress
	var phase := progress * PI * 6.0
	var amplitude := _stun_shake_amplitude * envelope
	return Vector2(roundf(cos(phase) * amplitude), roundf(sin(phase * 1.5) * minf(amplitude * 0.35, 1.0)))


func advance_status_visuals(delta: float, effects: EffectsSpawner, rng: RandomNumberGenerator, pixel_texture: Callable) -> void:
	refresh_status_aura()
	_stun_shake_remaining = maxf(_stun_shake_remaining - maxf(delta, 0.0), 0.0)
	if _stun_shake_remaining <= 0.0:
		_stun_shake_duration = 0.0
		_stun_shake_amplitude = 0.0
	var actor := _active_actor_sprite()
	var component := _valid_status_component(status_component)
	if actor == null or component == null or effects == null or not is_instance_valid(effects) or not pixel_texture.is_valid():
		_status_particle_timers.clear()
		return
	var active_ids: Dictionary = {}
	for definition in component.active_definitions():
		if definition == null:
			continue
		active_ids[definition.id] = true
		var timer := float(_status_particle_timers.get(definition.id, 0.0)) - maxf(delta, 0.0)
		if timer <= 0.0:
			effects.spawn_actor_status_particle(actor, overlay_parent, definition, rng, pixel_texture)
			timer = definition.particle_interval
		_status_particle_timers[definition.id] = timer
	for status_id: Variant in _status_particle_timers.keys():
		if not active_ids.has(status_id):
			_status_particle_timers.erase(status_id)


func _active_actor_sprite() -> Sprite2D:
	var alternate := _valid_sprite(alternate_actor_sprite)
	if alternate != null and alternate.visible and alternate.is_visible_in_tree():
		return alternate
	return _valid_sprite(actor_sprite)


func _new_sibling_overlay(layer: Sprite2D, overlay_name: String) -> Sprite2D:
	var overlay := Sprite2D.new()
	overlay.name = overlay_name
	overlay.centered = layer.centered
	overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	overlay.z_as_relative = false
	if overlay_parent != null and is_instance_valid(overlay_parent):
		overlay_parent.add_child(overlay)
	return overlay


func _sync_imbue_overlay(overlay: Sprite2D, layer: Sprite2D, is_outline: bool) -> void:
	if overlay == null or layer == null:
		return
	overlay.global_transform = layer.global_transform
	overlay.offset = layer.offset + (Vector2(-1.0, -1.0) if is_outline and not layer.centered else Vector2.ZERO)
	overlay.flip_h = layer.flip_h
	# Back/front sword layers share the original layer's exact draw depth.
	overlay.z_index = layer.z_index


func _valid_sprite(value: Variant) -> Sprite2D:
	if not is_instance_valid(value) or not (value is Sprite2D):
		return null
	return value as Sprite2D


func _valid_status_component(value: Variant) -> StatusComponent:
	if not is_instance_valid(value) or not (value is StatusComponent):
		return null
	return value as StatusComponent


func _queue_status_outline() -> void:
	var outline := _valid_sprite(_status_outline)
	if outline != null:
		outline.visible = false
		outline.queue_free()
	_status_outline = null


func _exit_tree() -> void:
	if health_component != null and is_instance_valid(health_component) and health_component.died.is_connected(_on_actor_died):
		health_component.died.disconnect(_on_actor_died)
	clear_imbue()
	_queue_status_outline()


func _tint_texture(source_sprite: Sprite2D, color: Color) -> Texture2D:
	if source_sprite == null or not is_instance_valid(source_sprite) or source_sprite.texture == null:
		return null
	var key := "%s:%s:%s" % [_sprite_cache_key(source_sprite), "tint", color.to_html(false)]
	if _tint_texture_cache.has(key):
		return _tint_texture_cache[key] as Texture2D
	var image := _sprite_source_image(source_sprite)
	if image == null or image.is_empty():
		return null
	image = image.duplicate()
	for y in image.get_height():
		for x in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.0:
				image.set_pixel(x, y, Color(color.r, color.g, color.b, pixel.a))
	var texture := ImageTexture.create_from_image(image)
	_tint_texture_cache[key] = texture
	return texture


func _outline_texture(source_sprite: Sprite2D, color: Color) -> Texture2D:
	if source_sprite == null or not is_instance_valid(source_sprite) or source_sprite.texture == null:
		return null
	var key := "%s:%s:%s" % [_sprite_cache_key(source_sprite), "outline", color.to_html(false)]
	if _outline_texture_cache.has(key):
		return _outline_texture_cache[key] as Texture2D
	var image := _sprite_source_image(source_sprite)
	if image == null or image.is_empty():
		return null
	var output := Image.create(image.get_width() + 2, image.get_height() + 2, false, Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.0:
				continue
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var neighbor: Vector2i = Vector2i(x, y) + offset
				if neighbor.x < 0 or neighbor.y < 0 or neighbor.x >= image.get_width() or neighbor.y >= image.get_height() or image.get_pixelv(neighbor).a <= 0.0:
					output.set_pixel(x + 1 + offset.x, y + 1 + offset.y, color)
	var texture := ImageTexture.create_from_image(output)
	_outline_texture_cache[key] = texture
	return texture


func _sprite_cache_key(sprite: Sprite2D) -> String:
	var region_key := ""
	if sprite.region_enabled:
		region_key = ":%s:%s" % [sprite.region_rect.position, sprite.region_rect.size]
	return "%s:%s:%s:%s:%s%s" % [sprite.texture.get_rid(), sprite.hframes, sprite.vframes, sprite.frame, sprite.region_enabled, region_key]


func _sprite_source_image(sprite: Sprite2D) -> Image:
	if sprite == null or not is_instance_valid(sprite) or sprite.texture == null:
		return null
	var source := sprite.texture
	var image: Image = null
	if source is AtlasTexture:
		var atlas_texture := source as AtlasTexture
		if atlas_texture.atlas == null:
			return null
		image = atlas_texture.atlas.get_image()
		if image == null or image.is_empty():
			return null
		var region := Rect2i(atlas_texture.region.position, atlas_texture.region.size)
		if region.position.x < 0 or region.position.y < 0 or region.end.x > image.get_width() or region.end.y > image.get_height():
			return null
		image = image.get_region(region)
	else:
		image = source.get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed() and image.decompress() != OK:
		return null
	if sprite.region_enabled:
		var region := Rect2i(sprite.region_rect.position, sprite.region_rect.size)
		if region.size.x <= 0 or region.size.y <= 0 or region.position.x < 0 or region.position.y < 0 or region.end.x > image.get_width() or region.end.y > image.get_height():
			return null
		image = image.get_region(region)
	var horizontal_frames := maxi(sprite.hframes, 1)
	var vertical_frames := maxi(sprite.vframes, 1)
	if horizontal_frames > 1 or vertical_frames > 1:
		var frame_width := floori(float(image.get_width()) / float(horizontal_frames))
		var frame_height := floori(float(image.get_height()) / float(vertical_frames))
		var frame_index := clampi(sprite.frame, 0, horizontal_frames * vertical_frames - 1)
		var frame_x := frame_index % horizontal_frames
		var frame_y := floori(float(frame_index) / float(horizontal_frames))
		var frame_rect := Rect2i(frame_x * frame_width, frame_y * frame_height, frame_width, frame_height)
		if frame_rect.size.x <= 0 or frame_rect.size.y <= 0:
			return null
		image = image.get_region(frame_rect)
	return image
