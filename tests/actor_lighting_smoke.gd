extends SceneTree

const Lighting = preload("res://scripts/runtime/controllers/actor_lighting_controller.gd")
const Effects = preload("res://scripts/runtime/services/effects_spawner.gd")
const Hud = preload("res://scripts/ui/hud_controller.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var effects := Effects.new()
	world.add_child(effects)
	_check_frame_bounds(world, effects)
	_check_actor_coverage(world, effects)
	_check_weapon_centers(world, effects)
	_check_world_ui(world, effects)
	for failure in failures:
		push_error(failure)
	print("ACTOR_LIGHTING_SMOKE_OK" if failures.is_empty() else "ACTOR_LIGHTING_SMOKE_FAILED: %d" % failures.size())
	world.free()
	quit(0 if failures.is_empty() else 1)


func _check_frame_bounds(world: Node2D, effects: EffectsSpawner) -> void:
	var sheet := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	sheet.fill(Color.TRANSPARENT)
	sheet.fill_rect(Rect2i(4, 4, 12, 20), Color.WHITE)
	sheet.fill_rect(Rect2i(40, 8, 18, 18), Color.WHITE)
	var sheet_texture := ImageTexture.create_from_image(sheet)
	var sprite := _sprite(world, sheet_texture)
	sprite.hframes = 2
	_expect(effects.sprite_drawn_rect(sprite).is_equal_approx(Rect2(4, 4, 12, 20)), "first animation frame excludes sheet padding")
	sprite.frame = 1
	_expect(effects.sprite_drawn_rect(sprite).is_equal_approx(Rect2(8, 8, 18, 18)), "second animation frame uses its own drawn pixels")
	sprite.flip_h = true
	sprite.flip_v = true
	_expect(effects.sprite_drawn_rect(sprite).is_equal_approx(Rect2(6, 6, 18, 18)), "both sprite flips mirror the drawn bounds")
	sprite.flip_h = false
	sprite.flip_v = false
	sprite.hframes = 1
	sprite.region_enabled = true
	sprite.region_rect = Rect2(32, 0, 32, 32)
	_expect(effects.sprite_drawn_rect(sprite).is_equal_approx(Rect2(8, 8, 18, 18)), "sprite regions select only authored visible pixels")
	sprite.region_enabled = false
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet_texture
	atlas.region = Rect2(32, 0, 32, 32)
	sprite.texture = atlas
	sprite.centered = true
	sprite.offset = Vector2(-10, 3)
	_expect(effects.sprite_drawn_rect(sprite).is_equal_approx(Rect2(-18, -5, 18, 18)), "atlas frames preserve centering and authored offsets")


func _check_actor_coverage(world: Node2D, effects: EffectsSpawner) -> void:
	var player_texture := _texture(Vector2i(36, 36), Rect2i(12, 5, 12, 25))
	var player := _sprite(world, player_texture)
	player.offset = Vector2(-10, -10)
	var renderer := OcclusionRenderer.new()
	world.add_child(renderer)
	renderer.original_actor_textures[player] = player_texture
	var attack := _sprite(world, _texture(Vector2i(36, 36), Rect2i(2, 3, 30, 28)))
	attack.visible = false
	var actors: Array[Sprite2D] = [player]
	Lighting.refresh_actor_lights(actors, player, attack, null, effects, renderer)
	var base_light := player.get_node("ActorLight") as PointLight2D
	_check_coverage(player, base_light, Rect2(2, -5, 12, 25))
	_expect(base_light.color.is_equal_approx(Color.WHITE), "actors start with neutral light")
	# Occlusion removes rendered pixels, but must not shrink authored coverage.
	player.texture = _texture(Vector2i(36, 36), Rect2i(12, 5, 2, 3))
	Lighting.refresh_actor_lights(actors, player, attack, null, effects, renderer)
	_expect(base_light.position.is_equal_approx(Vector2(8, 7.5)), "occlusion keeps the full authored actor center")
	var small_diameter := _light_size(base_light).x
	player.visible = false
	attack.visible = true
	var status := StatusComponent.new()
	status.name = "Status"
	player.add_child(status)
	status.apply_effect(ElementCatalog.status_effect_for_element(ElementCatalog.Element.ICE), ElementCatalog.Element.ICE)
	Lighting.refresh_actor_lights(actors, player, attack, null, effects, renderer)
	var attack_light := attack.get_node("ActorLight") as PointLight2D
	_check_coverage(attack, attack_light, Rect2(2, 3, 30, 28))
	_expect(not base_light.is_visible_in_tree() and attack_light.is_visible_in_tree(), "the visible attack pose retains actor illumination when the base player is hidden")
	_expect(_light_size(attack_light).x > small_diameter, "larger authored poses receive larger lights")
	_expect(attack_light.color.is_equal_approx(PaletteLibrary.accent("aquamarine")), "attack-pose light inherits applied actor status tint")
	status.clear_all()
	Lighting.refresh_actor_lights(actors, player, attack, null, effects, renderer)
	_expect(attack_light.color.is_equal_approx(Color.WHITE), "cleared statuses restore neutral attack-pose light")
	var enemy := _sprite(world, _texture(Vector2i(64, 48), Rect2i(2, 2, 60, 44)))
	enemy.scale = Vector2(1.5, 0.8)
	enemy.rotation = 0.3
	actors.append(enemy)
	Lighting.refresh_actor_lights(actors, player, attack, null, effects, renderer)
	_check_coverage(enemy, enemy.get_node("ActorLight") as PointLight2D, Rect2(2, 2, 60, 44))


func _check_weapon_centers(world: Node2D, effects: EffectsSpawner) -> void:
	var weapon := _sprite(world, _texture(Vector2i(36, 36), Rect2i(26, 10, 4, 15)))
	weapon.position = Vector2(80, 40)
	var light := Lighting.attach_weapon_light(weapon, Color.CORNFLOWER_BLUE, effects.sprite_drawn_rect(weapon))
	_expect(light.position.is_equal_approx(Vector2(28, 17.5)), "weapon light is on the blade, not the padded frame center")
	weapon.flip_h = true
	light = Lighting.attach_weapon_light(weapon, Color.CORNFLOWER_BLUE, effects.sprite_drawn_rect(weapon))
	_expect(light.position.is_equal_approx(Vector2(8, 17.5)), "weapon light follows the blade when facing reverses")
	weapon.texture = _texture(Vector2i(36, 36), Rect2i())
	Lighting.attach_weapon_light(weapon, Color.CORNFLOWER_BLUE, effects.sprite_drawn_rect(weapon))
	_expect(not light.visible, "blank weapon frames emit no light")
	# Exercise the real padded sword artwork, not just synthetic rectangles.
	var library := SpriteFrameLibrary.new()
	var frames := library.slice_frames("res://assets/artwork/TinyDemon_sword(back)_idle.png", Vector2i(36, 36))
	_expect(not frames.is_empty(), "authored sword frames load")
	var found_offset_blade := false
	weapon.flip_h = false
	for frame in frames:
		weapon.texture = frame
		var drawn_rect := effects.sprite_drawn_rect(weapon)
		if not drawn_rect.has_area():
			continue
		light = Lighting.attach_weapon_light(weapon, Color.ORANGE, drawn_rect)
		_expect(light.position.is_equal_approx(drawn_rect.get_center()), "authored sword light follows every visible blade frame")
		found_offset_blade = found_offset_blade or not drawn_rect.get_center().is_equal_approx(weapon.get_rect().get_center())
	_expect(found_offset_blade, "real sword artwork confirms why padded frame centering was incorrect")


func _check_world_ui(world: Node2D, effects: EffectsSpawner) -> void:
	var ambience := CanvasModulate.new()
	ambience.color = Color(0.6, 0.6, 0.6)
	world.add_child(ambience)
	for number_color in [Color.WHITE, Color.GREEN, Color.CORNFLOWER_BLUE]:
		effects.spawn_health_number(world, Vector2.ZERO, 17, Vector2.ZERO, true, number_color == Color.GREEN, number_color, Callable(effects, "number_texture"), func(point: Vector2) -> Vector2: return point, 1.0, 0.1)
		var number: Dictionary = effects.damage_numbers.back()
		for key in ["sprite", "shadow", "outline"]:
			_check_unshaded(number[key] as CanvasItem, "%s on combat feedback keeps its original colors" % key)
	var hud := Hud.new()
	world.add_child(hud)
	var enemy := _sprite(world, _texture(Vector2i(16, 16), Rect2i(0, 0, 16, 16)))
	var frame := _sprite(enemy, _texture(Vector2i(14, 4), Rect2i(0, 0, 14, 4)))
	var fill := _sprite(enemy, frame.texture)
	hud.register_overhead_bar(enemy, frame, fill, Vector2.ZERO, Callable(hud, "duplicate_fill_sprite"), Callable())
	for ui_sprite in [frame, fill, hud.target_overhead_damage_fills[enemy], hud.target_overhead_aggro_markers[enemy], hud.target_overhead_elite_symbols[enemy]]:
		_check_unshaded(ui_sprite as CanvasItem, "enemy overhead UI ignores room and point lighting")
	_check_unshaded(hud._new_status_marker(world, "StatusMark"), "world-space status badges ignore lighting")


func _check_coverage(sprite: Sprite2D, light: PointLight2D, drawn_rect: Rect2) -> void:
	var size := _light_size(light)
	_expect(is_equal_approx(size.x, size.y), "actor glow normalizes the elliptical fire texture to a circle")
	_expect(light.position.is_equal_approx(drawn_rect.get_center()), "actor glow centers on its full drawn silhouette")
	for corner in [drawn_rect.position, drawn_rect.end, Vector2(drawn_rect.position.x, drawn_rect.end.y), Vector2(drawn_rect.end.x, drawn_rect.position.y)]:
		var source_point := light.to_local(sprite.to_global(corner)) / (Vector2(light.texture.get_size()) * 0.5)
		_expect(source_point.length() < 0.6, "every authored actor corner stays inside the glow before the outer fade")


func _check_unshaded(item: CanvasItem, message: String) -> void:
	var material := item.material as CanvasItemMaterial
	_expect(material != null and material.light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED and not item.use_parent_material, message)


func _light_size(light: PointLight2D) -> Vector2:
	return Vector2(light.texture.get_size()) * light.scale * light.texture_scale


func _sprite(parent: Node, texture: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	parent.add_child(sprite)
	return sprite


func _texture(size: Vector2i, drawn_rect: Rect2i) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	if drawn_rect.has_area():
		image.fill_rect(drawn_rect, Color.WHITE)
	return ImageTexture.create_from_image(image)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
