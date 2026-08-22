extends Node
class_name ActorCollisionSystem

## Handles static movement checks and bounded actor-contact resolution.

@export var contact_distance := 64.0


func stabilize_guides(actors_to_stabilize: Array[Sprite2D], update_attack_guides: Callable) -> void:
	for actor in actors_to_stabilize:
		var actor_scale := actor.scale
		if absf(actor_scale.x) < 0.001 or absf(actor_scale.y) < 0.001:
			continue
		for child in actor.get_children():
			if child is Node2D and (child.name.ends_with("Guide") or child.name.begins_with("AttackGuide") or child.name == "CollisionPolygon"):
				# Boss collision guides describe the scaled visual body. Inverse-
				# scaling them makes the runtime guide detach from the editor-authored
				# position after the boss sprite is enlarged.
				if child.name == "CollisionGuide" and actor.name.begins_with("Slime") and float(actor.get_meta("encounter_scale", 1.0)) > 1.0:
					continue
				(child as Node2D).scale = Vector2(1.0 / actor_scale.x, 1.0 / actor_scale.y)
		if actor.name.begins_with("Slime"):
			update_attack_guides.call(actor)


func resolve_motion_contacts(actor: Sprite2D, movement: Vector2, candidates: Array[Sprite2D], root: Object) -> void:
	var slimes := root.get("slimes") as Array[Sprite2D]
	var actor_is_slime := slimes.has(actor)
	for other in candidates:
		if other == actor or not is_instance_valid(other) or not other.visible:
			continue
		if actor_is_slime and slimes.has(other):
			continue
		if actor.global_position.distance_squared_to(other.global_position) > contact_distance * contact_distance:
			continue
		resolve_contact_pair(actor, other, movement, root)


func resolve_slime_contacts(slimes: Array[Sprite2D], root: Object, max_passes: int = 2) -> int:
	var resolved_pairs := 0
	for _separation_pass in max_passes:
		var resolved_this_pass := false
		for actor_index in slimes.size():
			var actor := slimes[actor_index]
			if not is_instance_valid(actor) or not actor.visible:
				continue
			for other_index in range(actor_index + 1, slimes.size()):
				var other := slimes[other_index]
				if not is_instance_valid(other) or not other.visible:
					continue
				var push := actor_contact_push_vector(root, actor, other)
				if push == Vector2.ZERO:
					continue
				if _separate_slime_pair(root, actor, other, push):
					resolved_pairs += 1
					resolved_this_pass = true
		if not resolved_this_pass:
			break
	return resolved_pairs


func _separate_slime_pair(root: Object, actor: Sprite2D, other: Sprite2D, push: Vector2) -> bool:
	var actor_start := actor.position
	var other_start := other.position
	var actor_is_boss := _uses_body_contact(actor)
	var other_is_boss := _uses_body_contact(other)
	# Bosses own their movement lane. A regular slime caught in that lane takes
	# the entire separation displacement; it can never stop or shove the boss.
	if actor_is_boss != other_is_boss:
		if actor_is_boss:
			return try_move_swept(other, -push, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
		return try_move_swept(actor, push, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
	actor.position += push * 0.5
	other.position -= push * 0.5
	var actor_valid := _position_is_valid(root, actor)
	var other_valid := _position_is_valid(root, other)
	if actor_valid and other_valid:
		return true
	actor.position = actor_start
	other.position = other_start
	actor.position += push
	if _position_is_valid(root, actor):
		return true
	actor.position = actor_start
	other.position -= push
	if _position_is_valid(root, other):
		return true
	other.position = other_start
	return false


func _position_is_valid(root: Object, actor: Sprite2D) -> bool:
	return bool(root.call("_can_actor_stand_at_current_position", actor)) and not bool(root.call("_collides_with_static", actor))


func try_move_swept(actor: Sprite2D, movement: Vector2, max_step: float, can_stand: Callable, collides_static: Callable) -> bool:
	var original := actor.position
	var distance := movement.length()
	if distance <= 0.001:
		return false
	var steps := maxi(1, int(ceil(distance / max_step)))
	var step := movement / float(steps)
	for _index in steps:
		var before_step := actor.position
		actor.position += step
		if not can_stand.call(actor) or collides_static.call(actor):
			actor.position = before_step
			break
	return actor.position.distance_squared_to(original) > 0.0001


func can_actor_stand(actor: Sprite2D, slimes: Array[Sprite2D], foot: Callable, is_walkable: Callable, is_slime_walkable: Callable, collision_rect: Callable, collision_polygon: Callable) -> bool:
	if not slimes.has(actor):
		return bool(is_walkable.call(foot.call(actor)))
	var polygon: PackedVector2Array = collision_polygon.call(actor)
	if polygon.size() >= 3:
		for index in polygon.size():
			var point := polygon[index]
			var next_point := polygon[(index + 1) % polygon.size()]
			if not bool(is_slime_walkable.call(point)) or not bool(is_slime_walkable.call((point + next_point) * 0.5)):
				return false
		return bool(is_slime_walkable.call(_polygon_center(polygon)))
	var rect: Rect2 = collision_rect.call(actor)
	var samples := [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, rect.position + Vector2(0, rect.size.y), rect.get_center(), rect.position + Vector2(rect.size.x * 0.5, 0), rect.position + Vector2(rect.size.x, rect.size.y * 0.5), rect.position + Vector2(rect.size.x * 0.5, rect.size.y), rect.position + Vector2(0, rect.size.y * 0.5)]
	for sample in samples:
		if not bool(is_slime_walkable.call(sample)):
			return false
	return true


func _polygon_center(polygon: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point in polygon:
		center += point
	return center / float(polygon.size())


func resolve_contact_pair(actor: Sprite2D, other: Sprite2D, movement: Vector2, root: Object) -> void:
	if other == actor or not actors_are_in_contact(root, actor, other): return
	var chest := root.get("chest") as Sprite2D
	var rest_fire := root.get("rest_fire") as Sprite2D
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	if other == chest:
		separate_actor(root, actor, other)
	elif other == firepit:
		separate_actor(root, actor, other)
	elif other == root.get("cloaked_demon"):
		separate_actor(root, actor, other)
	elif actor == root.get("player") or other == root.get("player"):
		# Player and enemy may never trade displacement.  Shared pushes made
		# lock-on movement feel like the player and slime could occupy one spot.
		# The moving body is pushed back by its own overlap instead. If a wall
		# prevents that correction, push the other body as a last resort rather
		# than allowing the pair to remain stacked.
		var push := overlap_push_vector(root, actor, other)
		if push != Vector2.ZERO:
			var separated := try_move_swept(actor, push, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
			if not separated:
				try_move_swept(other, -push, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
	else:
		push_actor(root, actor, other, movement)


func push_actor(root: Object, actor: Sprite2D, other: Sprite2D, movement: Vector2) -> void:
	var push := overlap_push_vector(root, actor, other)
	if push == Vector2.ZERO: return
	var actor_weight := 1.0 if actor == root.get("player") else 1.45
	var other_weight := 1.0 if other == root.get("player") else 1.45
	var total_weight := actor_weight + other_weight
	var actor_share := other_weight / total_weight
	var other_share := actor_weight / total_weight
	try_move_swept(actor, push * actor_share, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
	try_move_swept(other, -push * other_share + movement * other_share * 0.45, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))


func separate_actor(root: Object, actor: Sprite2D, other: Sprite2D) -> void:
	actor.position += overlap_push_vector(root, actor, other)


func overlap_push_vector(root: Object, actor: Sprite2D, other: Sprite2D) -> Vector2:
	var chest := root.get("chest") as Sprite2D
	var rest_fire := root.get("rest_fire") as Sprite2D
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	if other != chest and actor != chest and other != firepit and actor != firepit: return actor_contact_push_vector(root, actor, other)
	if other == firepit or actor == firepit:
		var moving_actor := actor if other == firepit else other
		var fire_actor := firepit if other == firepit else actor
		if fire_actor == null or not bool(root.call("_collision_polygon_intersects_actor", moving_actor, fire_actor)):
			return Vector2.ZERO
	var rect: Rect2 = root.call("_collision_rect", actor)
	var other_rect: Rect2 = root.call("_collision_rect", other)
	var overlap := rect.intersection(other_rect)
	if not overlap.has_area(): return Vector2.ZERO
	var actor_center := rect.get_center(); var other_center := other_rect.get_center()
	if overlap.size.x < overlap.size.y: return Vector2(-overlap.size.x if actor_center.x < other_center.x else overlap.size.x, 0.0)
	return Vector2(0.0, -overlap.size.y if actor_center.y < other_center.y else overlap.size.y)


func actors_are_in_contact(root: Object, actor: Sprite2D, other: Sprite2D) -> bool:
	var chest := root.get("chest") as Sprite2D
	var rest_fire := root.get("rest_fire") as Sprite2D
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	if actor == firepit or other == firepit:
		var moving_actor := actor if other == firepit else other
		var fire_actor := firepit if other == firepit else actor
		return fire_actor != null and bool(root.call("_collision_polygon_intersects_actor", moving_actor, fire_actor))
	if actor == chest or other == chest: return (root.call("_collision_rect", actor) as Rect2).intersects(root.call("_collision_rect", other) as Rect2, false)
	return actor_contact_push_vector(root, actor, other) != Vector2.ZERO


func actor_contact_push_vector(root: Object, actor: Sprite2D, other: Sprite2D) -> Vector2:
	if _uses_body_contact(actor) or _uses_body_contact(other):
		return _rect_overlap_push_vector(root, actor, other)
	var delta: Vector2 = root.call("_actor_foot", actor) - root.call("_actor_foot", other)
	var distance := delta.length(); var min_distance := actor_contact_radius(root, actor) + actor_contact_radius(root, other)
	if distance >= min_distance: return Vector2.ZERO
	if distance <= 0.001: delta = Vector2.RIGHT; distance = 1.0
	return delta.normalized() * (min_distance - distance)


func _uses_body_contact(actor: Sprite2D) -> bool:
	return actor != null and float(actor.get_meta("encounter_scale", 1.0)) > 1.0


func _rect_overlap_push_vector(root: Object, actor: Sprite2D, other: Sprite2D) -> Vector2:
	var rect := root.call("_collision_rect", actor) as Rect2
	var other_rect := root.call("_collision_rect", other) as Rect2
	var overlap := rect.intersection(other_rect)
	if not overlap.has_area():
		return Vector2.ZERO
	var actor_center := rect.get_center()
	var other_center := other_rect.get_center()
	if overlap.size.x < overlap.size.y:
		return Vector2(-overlap.size.x if actor_center.x < other_center.x else overlap.size.x, 0.0)
	return Vector2(0.0, -overlap.size.y if actor_center.y < other_center.y else overlap.size.y)


func actor_contact_radius(root: Object, actor: Sprite2D) -> float:
	var chest := root.get("chest") as Sprite2D
	var guide: Rect2 = root.call("_collision_guide_rect_by_name", actor, "CollisionGuide")
	return ActorGeometry.contact_radius(actor, chest, guide, 3.6)
