extends Node
class_name SlimeRuntimeController


## Owns the enemy runtime loop: aggro, attacks, scooting, knockback, and the
## collision geometry queries used by those systems. GameplayState keeps only
## the stable callback surface that the other runtime components depend on.

func try_knockback_slime(root: Object, slime: Sprite2D, movement: Vector2) -> bool:
	var original := slime.position
	if slime_position_is_valid(root, slime):
		(root.get("slime_last_valid_positions") as Dictionary)[slime] = original
	var moved := try_move_actor_axes(root, slime, movement)
	separate_slime_from_player(root, slime)
	if not bool(root.call("_can_actor_stand_at_current_position", slime)) or bool(root.call("_collides_with_static", slime)):
		slime.position = original
		moved = false
	var actual_movement := slime.position - original
	var moved_distance := slime.position.distance_to(original)
	var x_clipped := absf(movement.x) > 0.01 and absf(actual_movement.x) < absf(movement.x) * 0.92
	var y_clipped := absf(movement.y) > 0.01 and absf(actual_movement.y) < absf(movement.y) * 0.92
	var blocked := not moved or moved_distance < movement.length() * 0.92 or x_clipped or y_clipped
	if blocked:
		slime.position = original
		if movement.length_squared() > 0.001:
			(root.get("actor_collision_system") as ActorCollisionSystem).try_move_swept(slime, -movement.normalized() * 2.5, 0.5, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
		recover_slime_position(root, slime)
		var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
		combat.knockback_timer = 0.0
		combat.knockback_velocity = Vector2.ZERO
		repath_slime_after_block(root, slime)
	return slime.position.distance_squared_to(original) > 0.0001 if blocked else moved


func separate_slime_from_player(root: Object, slime: Sprite2D) -> void:
	var player := root.get("player") as Sprite2D
	var overlap_push := (root.get("actor_collision_system") as ActorCollisionSystem).overlap_push_vector(root, slime, player)
	if overlap_push != Vector2.ZERO:
		(root.get("actor_collision_system") as ActorCollisionSystem).try_move_swept(slime, overlap_push, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))


func configure_slime_ambush(root: Object, slime: Sprite2D, palette: String) -> void:
	var ambush := slime.get_node_or_null("Ambush") as SlimeAmbushComponent
	var tuning := root.get("slime_tuning") as SlimeTuning
	if palette == "purple":
		if ambush == null:
			ambush = SlimeAmbushComponent.new()
			ambush.name = "Ambush"
			slime.add_child(ambush)
		ambush.configure(true, tuning.ambush_reveal_window, tuning.ambush_block_stun, tuning.ambush_hit_extension)
		ambush.apply_hidden(slime)
	elif ambush != null:
		ambush.configure(false, 0.0, 0.0, 0.0)
		slime.self_modulate = Color.WHITE


func slime_ambush(_root: Object, slime: Sprite2D) -> SlimeAmbushComponent:
	return slime.get_node_or_null("Ambush") as SlimeAmbushComponent


func is_slime_hidden(root: Object, slime: Sprite2D) -> bool:
	var ambush := slime_ambush(root, slime)
	return ambush != null and ambush.is_hidden()


func is_slime_targetable(root: Object, slime: Sprite2D) -> bool:
	var puzzle_torches := root.get("puzzle_torches") as Array[Sprite2D]
	if puzzle_torches.has(slime):
		return is_instance_valid(slime) and slime.visible
	return not bool(root.call("_is_slime_dead", slime)) and not is_slime_hidden(root, slime)


func is_target_actor_dead(root: Object, target: Sprite2D) -> bool:
	return false if (root.get("puzzle_torches") as Array[Sprite2D]).has(target) else bool(root.call("_is_slime_dead", target))


func move_slimes(root: Object, delta: float) -> void:
	prepare_slime_frame_cache(root)
	var slimes := root.get("slimes") as Array[Sprite2D]
	(root.get("combat_runtime_controller") as CombatRuntimeController).clear_enemy_max_health_frame_cache()
	# Spatial broad-phase for the crowd: built once per frame so slime-slime
	# contact and AI steering only examine spatially local slimes.
	(root.get("actor_collision_system") as ActorCollisionSystem).build_slime_grid(slimes, Callable(root, "_actor_foot"))
	for slime in slimes:
		if bool(root.call("_is_slime_dead", slime)):
			continue
		var slime_actor := slime as SlimeActor
		if slime_actor != null:
			slime_actor.tick_components(delta)
			slime_actor.tick_runtime(delta, Callable(root, "_is_slime_dead"), Callable(root, "_update_slime_knockback"), Callable(root, "_update_slime_attack"), Callable(root, "_is_slime_aggroed"), Callable(root, "_aggro_slime_target"), Callable(root, "_update_slime_scoot"))
			continue
		SlimeActor.tick_legacy_runtime(slime, delta, Callable(root, "_is_slime_dead"), Callable(root, "_update_slime_knockback"), Callable(root, "_update_slime_attack"), Callable(root, "_is_slime_aggroed"), Callable(root, "_aggro_slime_target"), Callable(root, "_update_slime_scoot"))
	var separation_passes := 1 if slimes.size() >= 5 else 2
	(root.get("actor_collision_system") as ActorCollisionSystem).resolve_slime_contacts(slimes, root, separation_passes)
	if not bool(root.get("player_dead")):
		var player := root.get("player") as Sprite2D
		for slime in slimes:
			if is_instance_valid(slime) and slime.visible and not bool(root.call("_is_slime_dead", slime)):
				(root.get("actor_collision_system") as ActorCollisionSystem).resolve_contact_pair(slime, player, Vector2.ZERO, root)


func prepare_slime_frame_cache(root: Object) -> void:
	var aggro_cache := root.get("slime_frame_aggro") as Dictionary
	var slot_cache := root.get("slime_frame_slots") as Dictionary
	aggro_cache.clear()
	slot_cache.clear()
	root.set("slime_frame_active_attackers", 0)
	var player := root.get("player") as Sprite2D
	var player_foot: Vector2 = root.call("_actor_foot", player)
	var slimes := root.get("slimes") as Array[Sprite2D]
	var player_dead := bool(root.get("player_dead"))
	var tuning := root.get("slime_tuning") as SlimeTuning
	for index in slimes.size():
		var slime := slimes[index]
		if bool(root.call("_is_slime_dead", slime)):
			continue
		slot_cache[slime] = index
		var brain := root.call("_slime_brain", slime) as SlimeBrain
		var is_aggroed := not player_dead and (brain.persistent_aggro or (root.call("_actor_foot", slime) as Vector2).distance_squared_to(player_foot) <= tuning.aggro_range * tuning.aggro_range)
		if is_aggroed and not brain.aggroed and not brain.notice_started and not is_slime_hidden(root, slime):
			trigger_slime_notice(root, slime)
			aggro_cache[slime] = true
		else:
			aggro_cache[slime] = is_aggroed
		var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
		if combat != null and combat.active:
			root.set("slime_frame_active_attackers", int(root.get("slime_frame_active_attackers")) + 1)
	root.set("slime_frame_cache_valid", true)


func trigger_slime_notice(root: Object, slime: Sprite2D) -> void:
	var brain := root.call("_slime_brain", slime) as SlimeBrain
	if brain == null or brain.notice_started or bool(root.call("_is_slime_dead", slime)):
		return
	brain.persistent_aggro = true
	var shocked_frames := shocked_frames_for(root, slime)
	var notice_duration := maxf(float(shocked_frames.size()) * float(root.get("SLIME_NOTICE_FRAME_TIME")), float(root.get("SLIME_NOTICE_FRAME_TIME")))
	brain.begin_notice(notice_duration)
	set_slime_notice_frame(root, slime, 0)
	var run := root.get("run_state") as RunState
	if run != null and run.active:
		run.record_enemy_encounter()
	(root.get("effects_spawner") as EffectsSpawner).spawn_slime_notice(root, slime, notice_duration)
	var rng := root.get("rng") as RandomNumberGenerator
	root.call("_play_sound", "enemy_alert", -8.0, 0.96 + rng.randf_range(-0.04, 0.04))


func slime_position_is_valid(root: Object, slime: Sprite2D) -> bool:
	return bool(root.call("_can_actor_stand_at_current_position", slime)) and not bool(root.call("_collides_with_static", slime))


func recover_slime_position(root: Object, slime: Sprite2D) -> void:
	var last_valid := root.get("slime_last_valid_positions") as Dictionary
	if slime_position_is_valid(root, slime):
		last_valid[slime] = slime.position
		return
	if last_valid.has(slime):
		slime.position = last_valid[slime] as Vector2
	if not slime_position_is_valid(root, slime):
		var recovery_foot: Vector2 = root.call("_nearest_valid_slime_walkable_point", root.call("_actor_foot", slime), slime)
		slime.position += recovery_foot - (root.call("_actor_foot", slime) as Vector2)
	if slime_position_is_valid(root, slime):
		last_valid[slime] = slime.position
	var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
	combat.knockback_timer = 0.0
	combat.knockback_velocity = Vector2.ZERO


func update_slime_attack(root: Object, slime: Sprite2D, delta: float) -> bool:
	var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
	var was_active := combat.active
	var result: bool = combat.tick_attack(delta, slime, root.get("slime_tuning") as SlimeTuning, attack_frames_for(root, slime), bool(root.get("player_dead")), Callable(root, "_set_slime_attack_frame"), Callable(root, "_set_actor_base_texture"), Callable(root, "_apply_slime_attack_lunge"), Callable(root, "_apply_slime_attack_hit"), Callable(root, "_restore_slime_idle_texture"), Callable(root, "_can_slime_attack_player"), Callable(root, "_start_slime_attack"))
	if was_active and not combat.active:
		var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
		if tactics != null:
			tactics.release_attack_slot()
	return result


func set_slime_attack_frame(root: Object, slime: Sprite2D, frame_index: int) -> void:
	(root.call("_slime_animation", slime) as SlimeAnimationComponent).set_attack_frame(frame_index)


func start_slime_attack(root: Object, slime: Sprite2D) -> void:
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		tactics.attack_reserved = true
	SlimeActor.start_attack_actor(root, slime)


func attack_frames_for(root: Object, slime: Sprite2D) -> Array[Texture2D]:
	var visual := root.call("_slime_visual", slime) as SlimeVisualComponent
	var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
	return [] if visual == null else visual.attack_left_frames if combat.face_left else visual.attack_right_frames


func shocked_frames_for(root: Object, slime: Sprite2D) -> Array[Texture2D]:
	var visual := root.call("_slime_visual", slime) as SlimeVisualComponent
	return [] if visual == null else visual.shocked_frames


func set_slime_notice_frame(root: Object, slime: Sprite2D, frame_index: int) -> void:
	var frames := shocked_frames_for(root, slime)
	if frames.is_empty():
		return
	root.call("_set_actor_base_texture", slime, frames[clampi(frame_index, 0, frames.size() - 1)])


func restore_slime_idle_texture(root: Object, slime: Sprite2D) -> void:
	var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
	root.call("_set_slime_facing", slime, -1.0 if combat.face_left else 1.0)


func can_slime_attack_player(root: Object, slime: Sprite2D) -> bool:
	var brain := root.call("_slime_brain", slime) as SlimeBrain
	if brain != null and brain.is_noticing():
		return false
	var attack_distance := slime_attack_reach(root, slime)
	if bool(root.get("player_dead")) or slime_attack_offset(root, slime).length() > attack_distance:
		return false
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics == null:
		return true
	var own_combat := root.call("_slime_combat", slime) as SlimeCombatComponent
	if tactics.attack_reserved and (own_combat == null or not own_combat.active):
		tactics.release_attack_slot()
	var active_attackers := int(root.get("slime_frame_active_attackers"))
	if not bool(root.get("slime_frame_cache_valid")):
		active_attackers = 0
		for other in root.get("slimes") as Array[Sprite2D]:
			if bool(root.call("_is_slime_dead", other)):
				continue
			var combat := root.call("_slime_combat", other) as SlimeCombatComponent
			if combat != null and combat.active:
				active_attackers += 1
	var granted := tactics.request_attack_slot(active_attackers, int(root.get("MAX_ACTIVE_ENEMY_ATTACKERS")))
	if granted and bool(root.get("slime_frame_cache_valid")):
		root.set("slime_frame_active_attackers", int(root.get("slime_frame_active_attackers")) + 1)
	return granted


func is_slime_aggroed(root: Object, slime: Sprite2D) -> bool:
	var cache := root.get("slime_frame_aggro") as Dictionary
	if bool(root.get("slime_frame_cache_valid")) and cache.has(slime):
		return bool(cache[slime])
	var brain := root.call("_slime_brain", slime) as SlimeBrain
	return not bool(root.call("_is_slime_dead", slime)) and not bool(root.get("player_dead")) and (brain.persistent_aggro or (root.call("_actor_foot", slime) as Vector2).distance_to(root.call("_actor_foot", root.get("player")) as Vector2) <= float((root.get("slime_tuning") as SlimeTuning).aggro_range))


func is_any_slime_aggroed(root: Object) -> bool:
	for slime in root.get("slimes") as Array[Sprite2D]:
		if is_slime_aggroed(root, slime):
			return true
	return false


func slime_attack_reach(root: Object, slime: Sprite2D) -> float:
	var to_player := slime_attack_offset(root, slime)
	var direction := to_player.normalized() if to_player.length_squared() > 0.001 else Vector2.RIGHT
	var encounter_scale := float(root.call("_slime_encounter_scale", slime))
	var tuning := root.get("slime_tuning") as SlimeTuning
	return maxf(tuning.attack_hit_range, slime_attack_contact_gap(root, slime, direction)) + tuning.attack_lunge_distance * encounter_scale + 0.75


func slime_attack_contact_gap(root: Object, slime: Sprite2D, direction: Vector2) -> float:
	var slime_body: PackedVector2Array = root.call("_slime_body_polygon", slime)
	var slime_center := ActorGeometry.polygon_center(slime_body)
	var player_rect: Rect2 = collision_rect(root, root.get("player") as Sprite2D)
	var player_body := PackedVector2Array([player_rect.position, Vector2(player_rect.end.x, player_rect.position.y), player_rect.end, Vector2(player_rect.position.x, player_rect.end.y)])
	var body_reach := ActorGeometry.directional_reach(slime_body, slime_center, direction)
	var player_reach := ActorGeometry.directional_reach(player_body, player_rect.get_center(), -direction)
	return maxf(body_reach + player_reach - 0.5, 0.0)


func slime_attack_offset(root: Object, slime: Sprite2D) -> Vector2:
	var slime_body: PackedVector2Array = root.call("_slime_body_polygon", slime)
	var slime_center := ActorGeometry.polygon_center(slime_body) if slime_body.size() >= 3 else collision_rect(root, slime).get_center()
	return collision_rect(root, root.get("player") as Sprite2D).get_center() - slime_center


func aggro_slime_target(root: Object, slime: Sprite2D) -> Vector2:
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		var slimes := root.get("slimes") as Array[Sprite2D]
		var slots := root.get("slime_frame_slots") as Dictionary
		var slot_index := int(slots.get(slime, slimes.find(slime)))
		tactics.set_formation_slot(-1 if slot_index % 3 == 1 else 1 if slot_index % 3 == 2 else 0)
	return SlimeBrain.aggro_target(root, slime)


func apply_slime_attack_hit(root: Object, slime: Sprite2D) -> void:
	var ambush := slime_ambush(root, slime)
	if ambush != null:
		var tuning := root.get("slime_tuning") as SlimeTuning
		ambush.reveal(slime)
		ambush.begin_rehide(slime, tuning.ambush_reveal_window)
	SlimeActor.apply_attack_hit(root, slime)


func update_slime_scoot(root: Object, slime: Sprite2D, delta: float) -> void:
	var brain := root.call("_slime_brain", slime) as SlimeBrain
	brain.set_aggro(is_slime_aggroed(root, slime))
	if brain.is_noticing():
		var frames := shocked_frames_for(root, slime)
		if frames.is_empty():
			root.call("_set_actor_visual_scale", slime, brain.notice_wiggle_scale())
		else:
			var progress := 1.0 - clampf(brain.notice_timer / brain.notice_duration, 0.0, 1.0)
			root.call("_set_actor_visual_scale", slime, Vector2.ONE)
			set_slime_notice_frame(root, slime, int(floor(progress * float(frames.size()))))
		return
	if brain.notice_started and not brain.notice_animation_finished:
		brain.notice_animation_finished = true
		restore_slime_idle_texture(root, slime)
		root.call("_set_actor_visual_scale", slime, Vector2.ONE)
	var tactics := slime.get_node_or_null("Tactics") as EnemyTacticsComponent
	if tactics != null:
		var slimes := root.get("slimes") as Array[Sprite2D]
		var slots := root.get("slime_frame_slots") as Dictionary
		var slot_index := int(slots.get(slime, slimes.find(slime)))
		tactics.set_formation_slot(-1 if slot_index % 3 == 1 else 1 if slot_index % 3 == 2 else 0)
	brain.tick_scoot(slime, delta, root.get("slime_tuning") as SlimeTuning, Callable(root, "_is_slime_aggroed"), Callable(root, "_try_move_actor"), Callable(root, "_set_actor_visual_scale"), Callable(root, "_repath_slime_after_block"), Callable(root, "_start_slime_hold"), Callable(root, "_start_slime_scoot"))


func start_slime_scoot(root: Object, slime: Sprite2D) -> void:
	root.call("_set_actor_visual_scale", slime, Vector2.ONE)
	(root.call("_slime_brain", slime) as SlimeBrain).start_scoot(slime, root.get("slime_tuning") as SlimeTuning, root.get("rng") as RandomNumberGenerator, Callable(root, "_actor_foot"), Callable(root, "_aggro_slime_target"), Callable(root, "_random_slime_walkable_point_near"), Callable(root, "_perspective_movement"), Callable(root, "_set_slime_facing"))


func repath_slime_after_block(root: Object, slime: Sprite2D) -> void:
	if bool(root.call("_is_slime_dead", slime)):
		return
	var brain := root.call("_slime_brain", slime) as SlimeBrain
	var rng := root.get("rng") as RandomNumberGenerator
	brain.scoot_timer = 0.0
	brain.scoot_start = slime.position
	brain.scoot_target = slime.position
	brain.repath_timer = 0.0
	if brain.blocked_repath_cooldown > 0.0:
		brain.hold_timer = maxf(brain.hold_timer, brain.blocked_repath_cooldown)
		root.call("_set_actor_visual_scale", slime, Vector2.ONE)
		return
	brain.blocked_repath_cooldown = rng.randf_range(0.10, 0.18)
	if is_slime_aggroed(root, slime):
		brain.detour_target = slime_wall_detour_target(root, slime)
		brain.detour_timer = 0.42
		brain.target = brain.detour_target
		brain.hold_timer = 0.0
	else:
		brain.target = root.call("_random_slime_walkable_point_near", root.call("_actor_foot", slime), 8, slime) as Vector2
		brain.hold_timer = rng.randf_range(0.08, 0.18)
	root.call("_set_actor_visual_scale", slime, Vector2.ONE)


func slime_wall_detour_target(root: Object, slime: Sprite2D) -> Vector2:
	var foot: Vector2 = root.call("_actor_foot", slime)
	var player_foot: Vector2 = root.call("_actor_foot", root.get("player"))
	var toward_player := player_foot - foot
	if toward_player.length_squared() < 0.01:
		return aggro_slime_target(root, slime)
	var side := toward_player.normalized().rotated(PI * 0.5)
	var best := Vector2.ZERO
	var best_score := INF
	var rng := root.get("rng") as RandomNumberGenerator
	for radius_value in [12.0, 18.0, 24.0]:
		for direction in [side, -side]:
			var candidate: Vector2 = foot + (direction as Vector2) * radius_value
			if not bool(root.call("_is_slime_collision_rect_walkable_at", slime, candidate)):
				continue
			var score := candidate.distance_to(player_foot) + rng.randf_range(0.0, 2.0)
			if score < best_score:
				best = candidate
				best_score = score
	return best if best_score < INF else aggro_slime_target(root, slime)


func start_slime_hold(root: Object, slime: Sprite2D) -> void:
	(root.call("_slime_brain", slime) as SlimeBrain).start_random_hold(root.get("slime_tuning") as SlimeTuning, root.get("rng") as RandomNumberGenerator)


func try_move_actor(root: Object, actor: Sprite2D, movement: Vector2) -> bool:
	var original := actor.position
	var moved := try_move_actor_axes(root, actor, movement)
	var slimes := root.get("slimes") as Array[Sprite2D]
	if actor == root.get("player") or not slimes.has(actor) or not is_slime_aggroed(root, actor) or movement.length_squared() < 0.001:
		return moved
	var moved_distance := actor.position.distance_to(original)
	var movement_was_clipped := moved and moved_distance < movement.length() * 0.65
	if moved and not movement_was_clipped:
		return true
	var slide := movement.rotated(PI * 0.5) * 0.72
	if try_move_actor_axes(root, actor, slide):
		return true
	if try_move_actor_axes(root, actor, -slide):
		return true
	return false


func try_move_actor_axes(root: Object, actor: Sprite2D, movement: Vector2) -> bool:
	var original := actor.position
	actor.position.x += movement.x
	if actor == root.get("player") and bool(root.call("_try_enter_any_active_socket")):
		return true
	if not bool(root.call("_can_actor_stand_at_current_position", actor)) or bool(root.call("_collides_with_static", actor)):
		actor.position.x = original.x
	else:
		resolve_actor_contacts(root, actor, Vector2(movement.x, 0.0))
	actor.position.y += movement.y
	if actor == root.get("player") and bool(root.call("_try_enter_any_active_socket")):
		return true
	if not bool(root.call("_can_actor_stand_at_current_position", actor)) or bool(root.call("_collides_with_static", actor)):
		actor.position.y = original.y
	else:
		resolve_actor_contacts(root, actor, Vector2(0.0, movement.y))
	return actor.position.distance_squared_to(original) > 0.0001


func resolve_actor_contacts(root: Object, actor: Sprite2D, movement: Vector2) -> void:
	var collision := root.get("actor_collision_system") as ActorCollisionSystem
	if collision == null:
		return
	var valid_position := actor.position
	collision.resolve_motion_contacts(actor, movement, root.get("collision_sprites") as Array[Sprite2D], root)
	if not bool(root.call("_can_actor_stand_at_current_position", actor)) or bool(root.call("_collides_with_static", actor)):
		actor.position = valid_position


func collides_with_static(root: Object, actor: Sprite2D) -> bool:
	var rest_fire := root.get("rest_fire") as Sprite2D
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	var chest := root.get("chest") as Sprite2D
	for other in root.get("collision_sprites") as Array[Sprite2D]:
		if other == actor or (other != chest and other != firepit):
			continue
		if other == firepit and collision_polygon_intersects_actor(root, actor, firepit):
			return true
		if other == chest and collision_rect(root, actor).intersects(collision_rect(root, other), false):
			return true
	return false


func collision_polygon_intersects_actor(root: Object, actor: Sprite2D, polygon_owner: Sprite2D) -> bool:
	var polygon := polygon_owner.get_node_or_null("CollisionPolygon") as Polygon2D
	if polygon == null or polygon.polygon.size() < 3:
		return false
	var rect := collision_rect(root, actor)
	var rect_polygon := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var world_polygon := PackedVector2Array()
	for point in polygon.polygon:
		world_polygon.append(polygon.to_global(point))
	return not Geometry2D.intersect_polygons(rect_polygon, world_polygon).is_empty()


func perspective_movement(_root: Object, movement: Vector2) -> Vector2:
	return Vector2(movement.x, movement.y * 0.5)


func collision_rect(root: Object, actor: Sprite2D) -> Rect2:
	var rest_fire := root.get("rest_fire") as Sprite2D
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	var actor_foot_offset: Vector2 = root.get("ACTOR_FOOT_OFFSET")
	var actor_collision_size := Vector2(float(root.get("ACTOR_COLLISION_WIDTH")), float(root.get("ACTOR_COLLISION_HEIGHT")))
	var chest_collision_size: Vector2 = root.get("CHEST_COLLISION_SIZE")
	return ActorGeometry.collision_rect(actor, root.get("chest") as Sprite2D, firepit, root.get("slimes") as Array[Sprite2D], actor_foot_offset, actor_collision_size, chest_collision_size, float(actor.get_meta("encounter_scale", 1.0)))


func collision_guide_rect(_root: Object, actor: Sprite2D) -> Rect2:
	return ActorGeometry.guide_rect(actor, "CollisionGuide")


func collision_guide_rect_by_name(_root: Object, actor: Sprite2D, guide_name: String) -> Rect2:
	return ActorGeometry.guide_rect(actor, guide_name)


func collect_walkable_tiles(root: Object, node: Node) -> void:
	var area := root.get("walkable_area") as WalkableArea
	if area != null:
		area.collect_geometry(node, Callable(root, "_tile_top_polygon"))
		root.set("walkable_points", area.points.duplicate())
		root.set("walkable_polygons", area.polygons.duplicate())


func build_walkable_outline(root: Object) -> void:
	var area := root.get("walkable_area") as WalkableArea
	if area != null:
		area.build_outline(bool(root.get("use_walkable_polygon_direct")))
		root.set("walkable_outline", area.outline)


func build_entrance_block_polygons(root: Object) -> void:
	(root.get("room_controller") as RoomController).build_entrance_blocks(root)
	var area := root.get("walkable_area") as WalkableArea
	if area != null:
		area.set_entrance_blocks(root.get("entrance_block_polygons") as Array[PackedVector2Array])


func is_walkable(root: Object, point: Vector2) -> bool:
	var area := root.get("walkable_area") as WalkableArea
	return area == null or area.is_walkable(point)


func can_actor_stand_at_current_position(root: Object, actor: Sprite2D) -> bool:
	var collision := root.get("actor_collision_system") as ActorCollisionSystem
	return collision == null or collision.can_actor_stand(actor, root.get("slimes") as Array[Sprite2D], Callable(root, "_actor_foot"), Callable(root, "_is_walkable"), Callable(root, "_is_slime_walkable_point"), Callable(root, "_collision_rect"), Callable(root, "_slime_collision_polygon"))


func is_slime_walkable_point(root: Object, point: Vector2) -> bool:
	var area := root.get("walkable_area") as WalkableArea
	return area != null and area.is_slime_walkable(point)


func tile_top_polygon(_root: Object, tile: Sprite2D) -> PackedVector2Array:
	return PackedVector2Array([tile.to_global(Vector2(8, 0)), tile.to_global(Vector2(16, 4)), tile.to_global(Vector2(8, 7)), tile.to_global(Vector2(0, 4))])


func nearest_slime_walkable_point(root: Object, point: Vector2) -> Vector2:
	var area := root.get("walkable_area") as WalkableArea
	return area.nearest_slime_walkable_point(point) if area != null and not area.is_empty() else point


func random_slime_walkable_point_near(root: Object, point: Vector2, sample_count: int, ignored_slime: Sprite2D = null) -> Vector2:
	var area := root.get("walkable_area") as WalkableArea
	if area == null:
		return point
	var rng := root.get("rng") as RandomNumberGenerator
	for _attempt in 16:
		var candidate: Vector2 = area.random_slime_walkable_point_near(point, sample_count, ignored_slime, rng, Callable(root, "_is_point_near_other_slime"))
		if ignored_slime == null or bool(root.call("_is_slime_collision_rect_walkable_at", ignored_slime, candidate)):
			return candidate
	return nearest_valid_slime_walkable_point(root, point, ignored_slime)


func nearest_valid_slime_walkable_point(root: Object, point: Vector2, slime: Sprite2D) -> Vector2:
	var area := root.get("walkable_area") as WalkableArea
	if area == null or area.is_empty():
		return point
	var nearest := area.nearest_slime_walkable_point(point)
	for radius_value in [0.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0]:
		var radius: float = radius_value
		for direction_index in 16:
			var candidate := nearest + Vector2.RIGHT.rotated(TAU * float(direction_index) / 16.0) * radius
			if bool(root.call("_is_slime_collision_rect_walkable_at", slime, candidate)):
				return candidate
	return point


func is_slime_collision_rect_walkable_at(root: Object, slime: Sprite2D, foot: Vector2) -> bool:
	var polygon: PackedVector2Array = root.call("_slime_collision_polygon", slime, foot)
	if polygon.size() >= 3:
		return is_slime_collision_polygon_walkable(root, polygon)
	var guide := slime.get_node_or_null("CollisionGuide") as Node2D
	var collision_bounds := Rect2(foot - Vector2(4.5, 2.2), Vector2(9, 4))
	if guide != null:
		var guide_position: Vector2 = guide.get("rect_position")
		var guide_size: Vector2 = guide.get("rect_size")
		var actor_position := foot - (root.get("ACTOR_FOOT_OFFSET") as Vector2)
		var origin := actor_position + guide.position + guide_position + Vector2(minf(guide_size.x, 0.0), minf(guide_size.y, 0.0))
		collision_bounds = Rect2(origin, guide_size.abs())
	var samples := [collision_bounds.position, collision_bounds.position + Vector2(collision_bounds.size.x, 0), collision_bounds.position + collision_bounds.size, collision_bounds.position + Vector2(0, collision_bounds.size.y), collision_bounds.get_center(), collision_bounds.position + Vector2(collision_bounds.size.x * 0.5, 0), collision_bounds.position + Vector2(collision_bounds.size.x, collision_bounds.size.y * 0.5), collision_bounds.position + Vector2(collision_bounds.size.x * 0.5, collision_bounds.size.y), collision_bounds.position + Vector2(0, collision_bounds.size.y * 0.5)]
	for sample in samples:
		if not is_slime_walkable_point(root, sample):
			return false
	return true


func slime_collision_polygon(root: Object, slime: Sprite2D, foot: Vector2 = Vector2.INF) -> PackedVector2Array:
	return ActorGeometry.collision_polygon(slime, root.get("ACTOR_FOOT_OFFSET") as Vector2, foot)


func slime_body_polygon(root: Object, slime: Sprite2D) -> PackedVector2Array:
	return ActorGeometry.body_polygon(slime, root.get("ACTOR_FOOT_OFFSET") as Vector2)


func is_slime_collision_polygon_walkable(root: Object, polygon: PackedVector2Array) -> bool:
	var center := Vector2.ZERO
	for index in polygon.size():
		var point := polygon[index]
		# The authored slime foot polygons are convex; vertices + center bound the
		# whole shape, so edge midpoints are skipped to halve the per-scoot cost.
		if not is_slime_walkable_point(root, point):
			return false
		center += point
	return is_slime_walkable_point(root, center / float(polygon.size()))


func is_point_near_other_slime(root: Object, point: Vector2, ignored_slime: Sprite2D = null) -> bool:
	for slime in root.get("slimes") as Array[Sprite2D]:
		if slime != ignored_slime and not bool(root.call("_is_slime_dead", slime)) and collision_rect(root, slime).grow(4.0).has_point(point):
			return true
	return false


func actor_foot(root: Object, actor: Sprite2D) -> Vector2:
	if actor == root.get("cloaked_demon"):
		return root.call("_cloaked_demon_foot_position") as Vector2
	return ActorGeometry.foot(actor, root.get("ACTOR_FOOT_OFFSET") as Vector2)
