extends Node
class_name ActorCollisionSystem

## Contact-resolution boundary. Existing gameplay resolver remains authoritative
## until static-map and actor-contact parity is verified.

var actors: Array[Sprite2D] = []
@export var contact_distance := 64.0


func stabilize_guides(actors_to_stabilize: Array[Sprite2D], update_attack_guides: Callable) -> void:
	for actor in actors_to_stabilize:
		var actor_scale := actor.scale
		if absf(actor_scale.x) < 0.001 or absf(actor_scale.y) < 0.001:
			continue
		for child in actor.get_children():
			if child is Node2D and (child.name.ends_with("Guide") or child.name.begins_with("AttackGuide") or child.name.begins_with("SwordHitbox")):
				(child as Node2D).scale = Vector2(1.0 / actor_scale.x, 1.0 / actor_scale.y)
		if actor.name.begins_with("Slime"):
			update_attack_guides.call(actor)


func set_actors(new_actors: Array[Sprite2D]) -> void:
	actors = new_actors.duplicate()


func add_actor(actor: Sprite2D) -> void:
	if not actors.has(actor):
		actors.append(actor)


func remove_actor(actor: Sprite2D) -> void:
	actors.erase(actor)


func contacts_for(actor: Sprite2D) -> Array[Sprite2D]:
	var contacts: Array[Sprite2D] = []
	for other in actors:
		if other == actor or not is_instance_valid(other) or not other.visible:
			continue
		if actor.global_position.distance_to(other.global_position) <= contact_distance:
			contacts.append(other)
	return contacts


func resolve_contacts(actor: Sprite2D, movement: Vector2, resolver: Callable) -> void:
	for other in contacts_for(actor):
		resolver.call(actor, other, movement)


func try_move(actor: Sprite2D, movement: Vector2, can_stand: Callable, collides_static: Callable, resolve_contacts_for: Callable) -> bool:
	var original := actor.position
	if absf(movement.x) > 0.001:
		actor.position.x += movement.x
		if not can_stand.call(actor) or collides_static.call(actor):
			actor.position.x = original.x
		else:
			resolve_contacts_for.call(actor, Vector2(movement.x, 0.0))
	if absf(movement.y) > 0.001:
		actor.position.y += movement.y
		if not can_stand.call(actor) or collides_static.call(actor):
			actor.position.y = original.y
		else:
			resolve_contacts_for.call(actor, Vector2(0.0, movement.y))
	return actor.position.distance_squared_to(original) > 0.0001


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


func can_actor_stand(actor: Sprite2D, slimes: Array[Sprite2D], foot: Callable, is_walkable: Callable, is_slime_walkable: Callable, collision_rect: Callable) -> bool:
	if not slimes.has(actor):
		return bool(is_walkable.call(foot.call(actor)))
	var rect: Rect2 = collision_rect.call(actor)
	var samples := [foot.call(actor), Vector2(rect.position.x, rect.end.y), Vector2(rect.get_center().x, rect.end.y), Vector2(rect.end.x, rect.end.y)]
	for sample in samples:
		if not bool(is_slime_walkable.call(sample)):
			return false
	return true


func resolve_contact_pair(actor: Sprite2D, other: Sprite2D, movement: Vector2, root: Object) -> void:
	if other == actor or not actors_are_in_contact(root, actor, other): return
	var chest := root.get("chest") as Sprite2D
	if other == chest:
		separate_actor(root, actor, other)
	elif other == root.get("cloaked_demon"):
		separate_actor(root, actor, other)
	elif (root.get("slimes") as Array[Sprite2D]).has(actor) and (root.get("slimes") as Array[Sprite2D]).has(other):
		push_actor(root, actor, other, movement)
	elif actor != root.get("player") and other == root.get("player") and bool(root.call("_is_enemy_control_locked", actor)):
		separate_actor(root, actor, other)
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
	actor.position += push * actor_share
	try_move_swept(other, -push * other_share + movement * other_share * 0.45, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))


func separate_actor(root: Object, actor: Sprite2D, other: Sprite2D) -> void:
	actor.position += overlap_push_vector(root, actor, other)


func overlap_push_vector(root: Object, actor: Sprite2D, other: Sprite2D) -> Vector2:
	var chest := root.get("chest") as Sprite2D
	if other != chest and actor != chest: return actor_contact_push_vector(root, actor, other)
	var rect: Rect2 = root.call("_collision_rect", actor)
	var other_rect: Rect2 = root.call("_collision_rect", other)
	var overlap := rect.intersection(other_rect)
	if not overlap.has_area(): return Vector2.ZERO
	var actor_center := rect.get_center(); var other_center := other_rect.get_center()
	if overlap.size.x < overlap.size.y: return Vector2(-overlap.size.x if actor_center.x < other_center.x else overlap.size.x, 0.0)
	return Vector2(0.0, -overlap.size.y if actor_center.y < other_center.y else overlap.size.y)


func actors_are_in_contact(root: Object, actor: Sprite2D, other: Sprite2D) -> bool:
	var chest := root.get("chest") as Sprite2D
	if actor == chest or other == chest: return (root.call("_collision_rect", actor) as Rect2).intersects(root.call("_collision_rect", other) as Rect2, false)
	return actor_contact_push_vector(root, actor, other) != Vector2.ZERO


func actor_contact_push_vector(root: Object, actor: Sprite2D, other: Sprite2D) -> Vector2:
	var delta: Vector2 = root.call("_actor_foot", actor) - root.call("_actor_foot", other)
	var distance := delta.length(); var min_distance := actor_contact_radius(root, actor) + actor_contact_radius(root, other)
	if distance >= min_distance: return Vector2.ZERO
	if distance <= 0.001: delta = Vector2.RIGHT; distance = 1.0
	return delta.normalized() * (min_distance - distance)


func actor_contact_radius(root: Object, actor: Sprite2D) -> float:
	var chest := root.get("chest") as Sprite2D
	if actor == chest: return 5.5
	var guide: Rect2 = root.call("_collision_guide_rect_by_name", actor, "CollisionGuide")
	return maxf(minf(guide.size.x, guide.size.y) * 0.5, 2.0) if guide.has_area() else 3.6
