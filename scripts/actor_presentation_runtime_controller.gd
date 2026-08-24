extends Node
class_name ActorPresentationRuntimeController

const ACTOR_DEPTH_TIE_WINDOW := 1.5


## Owns actor-facing presentation: depth ordering, occlusion, authored geometry
## offsets, slime texture libraries, and the shared visual scale transform.

func set_actor_visual_scale(root: Object, actor: Sprite2D, visual_scale: Vector2) -> void:
	var slimes := root.get("slimes") as Array[Sprite2D]
	var encounter_scale := float(actor.get_meta("encounter_scale", 1.0)) if slimes.has(actor) else 1.0
	(root.get("occlusion_renderer") as OcclusionRenderer).actor_visual_scales[actor] = visual_scale * encounter_scale
	apply_actor_scale(root, actor, false)


func build_depth_lists(root: Object) -> void:
	var lists := (root.get("depth_sorter") as DepthSorter).visible_lists(root.get("player") as Sprite2D, root.get("slimes") as Array[Sprite2D], root.get("chest") as Sprite2D, root.get("rest_fire") as Sprite2D, root.get("cloaked_demon") as Sprite2D, Callable(root, "_is_slime_dead"))
	root.set("depth_sprites", lists["depth"] as Array[Sprite2D])
	root.set("occluder_sprites", lists["occluders"] as Array[Sprite2D])
	for torch in root.get("puzzle_torches") as Array[Sprite2D]:
		if is_instance_valid(torch) and torch.visible and not (root.get("depth_sprites") as Array[Sprite2D]).has(torch):
			(root.get("depth_sprites") as Array[Sprite2D]).append(torch)
	var occlusion := root.get("occlusion_renderer") as OcclusionRenderer
	var demon := root.get("cloaked_demon") as Sprite2D
	var fire := root.get("rest_fire") as Sprite2D
	var chest := root.get("chest") as Sprite2D
	if demon.visible:
		occlusion.sprite_images[demon] = occlusion.cached_texture_image(demon.texture)
	if fire.visible:
		occlusion.sprite_images[fire] = occlusion.cached_texture_image(fire.texture)
	if chest.visible:
		var paths: Array[NodePath] = root.get("OCCLUDER_PATHS")
		for path in paths:
			collect_occluders(root, root.call("get_node_or_null", path) as Node)
	root.call("_update_depth_sorting")


func hide_editor_only_guides(root: Object) -> void:
	(root.get("room_controller") as RoomController).hide_editor_only_guides(root.get("floor_tiles") as Node2D)
	var player := root.get("player") as Sprite2D
	if player != null:
		for node_name in [&"Attack1HitboxShape", &"Attack2HitboxShape", &"CollisionGuide", &"DoorFeetGuide"]:
			var guide := player.get_node_or_null(NodePath(node_name)) as CanvasItem
			if guide != null:
				guide.visible = false
	var rest_fire := root.get("rest_fire") as Sprite2D
	var firepit_polygon := rest_fire.get_node_or_null("Firepit/CollisionPolygon") as Polygon2D if rest_fire != null else null
	if firepit_polygon != null:
		firepit_polygon.visible = false
	for slime in root.get("slimes") as Array[Sprite2D]:
		var collision_polygon := slime.get_node_or_null("CollisionPolygon") as Polygon2D
		if collision_polygon != null:
			collision_polygon.visible = false
		var body_hitbox := slime.get_node_or_null("BodyHitbox") as Polygon2D
		if body_hitbox != null:
			body_hitbox.visible = false
		for node_name in [&"CollisionGuide", &"AttackGuideL", &"AttackGuideR"]:
			var guide := slime.get_node_or_null(NodePath(node_name)) as CanvasItem
			if guide != null:
				guide.visible = false


func build_slime_direction_textures(root: Object) -> void:
	var slimes := root.get("slimes") as Array[Sprite2D]
	var paths := {}
	for slime in slimes:
		var palette := String(slime.get("variant"))
		var source := "SlimeGreen" if palette in ["purple", "grey", "yellow"] else "Slime%s" % palette.capitalize()
		paths[slime] = ["res://assets/artwork/%sLeft.png" % source, "res://assets/artwork/%sRight.png" % source]
	SlimeVisualComponent.build_direction_textures(slimes, paths, Callable(root, "_load_texture_or_null"))
	var texture_cache := (root.get("occlusion_renderer") as OcclusionRenderer).texture_image_cache
	for palette in ["grey", "yellow", "purple"]:
		var palette_slimes: Array[Sprite2D] = []
		for slime in slimes:
			if String(slime.get("variant")) == palette:
				palette_slimes.append(slime)
		if not palette_slimes.is_empty():
			SlimeVisualComponent.recolor_direction_textures(palette_slimes, palette, texture_cache)


func build_slime_attack_frames(root: Object) -> void:
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary
	var cache := (root.get("occlusion_renderer") as OcclusionRenderer).texture_image_cache
	var frame_size: Vector2i = root.get("SLIME_ATTACK_FRAME_SIZE")
	var frames := SlimeVisualComponent.build_attack_frame_library(library, frame_size, cache, Callable((root.get("player_animation_component") as PlayerAnimationComponent), "warm_texture_cache"))
	root.set("slime_attack_frames_by_palette", frames)
	SlimeVisualComponent.assign_attack_frames(root.get("slimes") as Array[Sprite2D], frames)


func assign_slime_attack_frames(root: Object) -> void:
	SlimeVisualComponent.assign_attack_frames(root.get("slimes") as Array[Sprite2D], root.get("slime_attack_frames_by_palette") as Dictionary)


func build_slime_shocked_frames(root: Object) -> void:
	var library := root.get("sprite_frame_library") as SpriteFrameLibrary
	var cache := (root.get("occlusion_renderer") as OcclusionRenderer).texture_image_cache
	var frame_size: Vector2i = root.get("SLIME_ATTACK_FRAME_SIZE")
	var frames := SlimeVisualComponent.build_shocked_frame_library(library, frame_size, cache, Callable((root.get("player_animation_component") as PlayerAnimationComponent), "warm_texture_cache"))
	root.set("slime_shocked_frames_by_palette", frames)
	SlimeVisualComponent.assign_shocked_frames(root.get("slimes") as Array[Sprite2D], frames)


func assign_slime_shocked_frames(root: Object) -> void:
	SlimeVisualComponent.assign_shocked_frames(root.get("slimes") as Array[Sprite2D], root.get("slime_shocked_frames_by_palette") as Dictionary)


func build_enemy_health_ui(root: Object) -> void:
	var hud := root.get("hud_controller") as HudController
	var animation := root.get("player_animation_component") as PlayerAnimationComponent
	var fill := root.get("target_health_fill") as Sprite2D
	animation.base_health_fill_texture = hud.build_enemy_health_ui(root.get("slimes") as Array[Sprite2D], fill, root.get("target_health_bar") as Sprite2D, root.get("player_health_fill") as Sprite2D, root.get("player_health_damage_fill") as Sprite2D, root.get("hp_overhead") as Sprite2D, root.get("hp_overhead_fill") as Sprite2D, root.get("slime_green") as Sprite2D, Callable(root, "_load_health_bar_texture"), Callable(hud, "brighter_bar_texture"), Callable(hud, "duplicate_fill_sprite"), Callable(hud, "register_overhead_bar"), Callable(root, "_pixel_particle_texture"))
	root.set("target_health_damage_fill", fill.get_parent().get_node_or_null("EnemyHpDamageFill") as Sprite2D)
	root.set("player_health_damage_fill", (root.get("player_health_fill") as Sprite2D).get_parent().get_node_or_null("HpBarDamageFill") as Sprite2D)
	var player_hud := (root.get("ui") as Node2D).get_node_or_null("PlayerHud") as Node2D
	if player_hud != null:
		animation.base_health_fill_texture = (root.get("player_health_fill") as Sprite2D).texture
		var player_damage_fill := root.get("player_health_damage_fill") as Sprite2D
		if player_damage_fill != null:
			player_damage_fill.texture = player_hud.call("hp_highlight_texture") as Texture2D


func refresh_enemy_palette_textures(root: Object) -> void:
	var hud := root.get("hud_controller") as HudController
	hud.refresh_enemy_palette_textures(root.get("slimes") as Array[Sprite2D], Callable(root, "_load_health_bar_texture"), Callable(hud, "brighter_bar_texture"))


func set_slime_facing(root: Object, slime: Sprite2D, direction_x: float) -> void:
	SlimeVisualComponent.set_facing(root, slime, direction_x)


func update_slime_attack_guides(root: Object, slime: Sprite2D) -> void:
	var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
	var active_name := "AttackGuideL" if combat.face_left else "AttackGuideR"
	var show_guides := bool(root.get("debug_actor_geometry"))
	for child in slime.get_children():
		if child is Node2D and child.name.begins_with("AttackGuide"):
			(child as Node2D).visible = show_guides and child.name == active_name


func set_actor_base_texture(root: Object, actor: Sprite2D, texture: Texture2D) -> void:
	(root.get("occlusion_renderer") as OcclusionRenderer).set_actor_base_texture(actor, texture)


func collect_occluders(root: Object, node: Node) -> void:
	if node == null:
		return
	if node is Sprite2D:
		var sprite := node as Sprite2D
		if sprite.visible:
			add_depth_sprite(root, sprite)
			var occluders := root.get("occluder_sprites") as Array[Sprite2D]
			if not occluders.has(sprite):
				occluders.append(sprite)
	for child in node.get_children():
		collect_occluders(root, child as Node)


func add_depth_sprite(root: Object, sprite: Sprite2D) -> void:
	var depth := root.get("depth_sprites") as Array[Sprite2D]
	if not depth.has(sprite):
		sprite.z_as_relative = false
		depth.append(sprite)


func update_depth_sorting(root: Object) -> void:
	var sorter := root.get("depth_sorter") as DepthSorter
	var scale: float = root.get("DEPTH_Z_SCALE")
	var player := root.get("player") as Sprite2D
	var player_depth := depth_key(root, player) if player != null else -INF
	for sprite in root.get("depth_sprites") as Array[Sprite2D]:
		sprite.z_as_relative = false
		sprite.z_index = sorter.z_index_for(sprite, depth_key(root, sprite), scale) if sorter != null else int(round(depth_key(root, sprite) * scale))
	# A player and a boss standing beside one another can have nearly identical
	# foot depths. Give the player the tie so the boss does not visually cover
	# them unless the player's feet are clearly farther back in the room.
	if player != null:
		for slime in root.get("slimes") as Array[Sprite2D]:
			if not is_instance_valid(slime) or not slime.visible or float(slime.get_meta("encounter_scale", 1.0)) <= 1.0:
				continue
			if player_depth >= depth_key(root, slime) - ACTOR_DEPTH_TIE_WINDOW:
				player.z_index = maxi(player.z_index, slime.z_index + 1)


func update_actor_occlusion(root: Object, delta: float) -> void:
	var player := root.get("player") as Sprite2D
	var target := root.call("_valid_current_target") as Sprite2D
	var actors: Array[Sprite2D] = [player]
	var actor_sprites := root.get("actor_sprites") as Array[Sprite2D]
	if target != null and target != player and actor_sprites.has(target) and not bool(root.call("_is_target_actor_dead", target)):
		actors.append(target)
	var momentum := root.call("_combat_momentum") as CombatMomentumComponent
	var focus_lost := target != null and not momentum.focus_active
	var release_grace: float = root.get("OCCLUSION_RELEASE_GRACE") if target != null else 0.0
	(root.get("occlusion_renderer") as OcclusionRenderer).update_actor_occlusion(actors, root.get("occluder_sprites") as Array[Sprite2D], player, target, focus_lost, delta, release_grace, Callable(root, "_is_actor_occlusion_flashing"), Callable(root, "_depth_key"), Callable(root, "_sprite_source_global_rect"), Callable(root, "_build_exact_occluded_actor_texture"), Callable(root, "_apply_actor_scale"), Callable(root, "_restore_actor_base_visual_scale"))
	var equipment_visual := root.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	if equipment_visual != null:
		equipment_visual.update_occlusion(root, delta)


func is_actor_occlusion_flashing(root: Object, actor: Sprite2D) -> bool:
	return actor == root.get("player") and float(root.get("player_hit_flash_timer")) > 0.0


func depth_key(root: Object, sprite: Sprite2D) -> float:
	var actors := root.get("actor_sprites") as Array[Sprite2D]
	if actors.has(sprite):
		return (root.call("_actor_foot", sprite) as Vector2).y
	if sprite == root.get("rest_fire"):
		return (root.get("rest_fire_depth_marker") as Marker2D).global_position.y
	if sprite == root.get("cloaked_demon"):
		return (root.call("_cloaked_demon_foot_position") as Vector2).y
	if sprite.name.begins_with("WallLeft") or sprite.name.begins_with("WallRight"):
		return sprite.global_position.y + 28.0
	if sprite.name.begins_with("Door"):
		return sprite.global_position.y + 30.0
	return sprite.global_position.y + float(sprite.texture.get_height() if sprite.texture != null else 0)


func equipment_occlusion_depth_key(root: Object, sprite: Sprite2D) -> float:
	return (root.call("_actor_foot", root.get("player")) as Vector2).y if String(sprite.name).begins_with("Equipment") else depth_key(root, sprite)


func sprite_source_global_rect(root: Object, sprite: Sprite2D) -> Rect2:
	var renderer := root.get("occlusion_renderer") as OcclusionRenderer
	var texture: Texture2D = renderer.original_actor_textures[sprite] if renderer.original_actor_textures.has(sprite) else sprite.texture
	if texture == null:
		return Rect2(sprite.global_position, Vector2.ZERO)
	var sprite_scale := sprite.scale.abs()
	if renderer.original_actor_scales.has(sprite):
		sprite_scale = actor_screen_scale(root, sprite).abs()
	var size: Vector2 = texture.get_size() * sprite_scale
	var source_offset: Vector2 = actor_visual_offset(root, sprite) if renderer.original_actor_scales.has(sprite) else sprite.offset
	var origin := sprite.global_position + source_offset * sprite_scale - size * 0.5 if sprite.centered else sprite.global_position + source_offset * sprite_scale
	return Rect2(origin, size)


func build_exact_occluded_actor_texture(root: Object, actor: Sprite2D, active_occluders: Array[Sprite2D], is_target: bool, use_grey_highlight: bool) -> Texture2D:
	var renderer := root.get("occlusion_renderer") as OcclusionRenderer
	return renderer.build_exact_occluded_actor_texture(actor, active_occluders, is_target, use_grey_highlight, Callable(root, "_is_pixel_covered_by_occluder"), Callable(root, "_actor_visual_offset"))


func is_pixel_covered_by_occluder(root: Object, world_pixel: Vector2, active_occluders: Array[Sprite2D]) -> bool:
	var renderer := root.get("occlusion_renderer") as OcclusionRenderer
	return renderer.is_pixel_covered_by_occluder(world_pixel, active_occluders, Callable(root, "_actor_screen_scale"), Callable(root, "_actor_visual_offset"))


func apply_actor_scale(root: Object, actor: Sprite2D, _use_effect_texture: bool) -> void:
	actor.scale = actor_screen_scale(root, actor)
	actor.offset = actor_visual_offset(root, actor)
	sync_actor_geometry_offset(root, actor)


func restore_actor_base_visual_scale(root: Object, actor: Sprite2D) -> void:
	var renderer := root.get("occlusion_renderer") as OcclusionRenderer
	if renderer.original_actor_scales.has(actor):
		actor.scale = actor_screen_scale(root, actor)
		actor.offset = actor_visual_offset(root, actor)


func actor_screen_scale(root: Object, actor: Sprite2D) -> Vector2:
	var renderer := root.get("occlusion_renderer") as OcclusionRenderer
	var original_scale: Vector2 = renderer.original_actor_scales.get(actor, Vector2.ONE)
	var visual_scale: Vector2 = renderer.actor_visual_scales.get(actor, Vector2.ONE)
	return original_scale * visual_scale


func actor_visual_offset(root: Object, actor: Sprite2D) -> Vector2:
	return ActorGeometry.visual_offset(actor, root.get("player") as Sprite2D, root.get("slimes") as Array[Sprite2D], root.get("ACTOR_FOOT_OFFSET") as Vector2)


func sync_actor_geometry_offset(root: Object, actor: Sprite2D) -> void:
	if not (root.get("slimes") as Array[Sprite2D]).has(actor):
		return
	for node_name in [&"CollisionGuide", &"CollisionPolygon", &"BodyHitbox", &"AttackGuideL", &"AttackGuideR"]:
		var geometry := actor.get_node_or_null(NodePath(node_name)) as Node2D
		if geometry == null:
			continue
		if not geometry.has_meta("authored_position"):
			geometry.set_meta("authored_position", geometry.position)
		var authored_position := geometry.get_meta("authored_position") as Vector2
		geometry.position = authored_position + actor.offset
