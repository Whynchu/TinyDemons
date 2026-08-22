extends RefCounted
class_name ActorGeometry

## Single source of truth for actor render anchors and combat geometry.
##
## The coordinator still exposes compatibility wrappers while consumers migrate,
## but the transform math lives here so hitboxes, attacks, and flashes agree.

static func foot(actor: Sprite2D, actor_foot_offset: Vector2) -> Vector2:
	return foot_position(actor.global_position, actor_foot_offset)


static func foot_position(position: Vector2, actor_foot_offset: Vector2) -> Vector2:
	return position + actor_foot_offset


static func encounter_visual_offset(encounter_scale: float, actor_foot_offset: Vector2) -> Vector2:
	return actor_foot_offset * (1.0 / encounter_scale - 1.0) if encounter_scale > 1.0 else Vector2.ZERO


static func sync_overlay(overlay: Sprite2D, actor: Sprite2D) -> void:
	## Child overlays inherit the actor's scale; copy only Sprite2D presentation
	## properties that are not inherited so they cannot drift down/right.
	overlay.position = Vector2.ZERO
	overlay.scale = Vector2.ONE
	overlay.offset = actor.offset
	overlay.flip_h = actor.flip_h
	overlay.flip_v = actor.flip_v


static func visual_offset(actor: Sprite2D, player: Sprite2D, slimes: Array[Sprite2D], actor_foot_offset: Vector2) -> Vector2:
	if actor == player:
		return Vector2(-10, -10)
	if slimes.has(actor):
		var encounter_scale := float(actor.get_meta("encounter_scale", 1.0))
		return encounter_visual_offset(encounter_scale, actor_foot_offset)
	return Vector2.ZERO


static func guide_rect(actor: Sprite2D, guide_name: String) -> Rect2:
	var guide := actor.get_node_or_null(guide_name) as Node2D
	if guide == null:
		return Rect2()
	var scaled_position: Vector2 = guide.get("rect_position")
	var scaled_size: Vector2 = guide.get("rect_size")
	var origin := actor.global_position + guide.position + scaled_position + Vector2(minf(scaled_size.x, 0.0), minf(scaled_size.y, 0.0))
	return Rect2(origin, scaled_size.abs())


static func collision_rect(actor: Sprite2D, chest: Sprite2D, firepit: Sprite2D, slimes: Array[Sprite2D], actor_foot_offset: Vector2, actor_collision_size: Vector2, chest_collision_size: Vector2, encounter_scale: float) -> Rect2:
	if actor == firepit:
		var polygon := actor.get_node_or_null("CollisionPolygon") as Polygon2D
		if polygon != null and polygon.polygon.size() >= 3:
			return global_polygon_bounds(polygon)
	var guide_rect := guide_rect(actor, "CollisionGuide")
	var foot_position := foot(actor, actor_foot_offset)
	var size := actor_collision_size
	if actor != chest and slimes.has(actor) and not guide_rect.has_area():
		size *= 1.0 + (encounter_scale - 1.0) * 0.35
	if guide_rect.has_area():
		return guide_rect
	if actor == chest:
		return Rect2(actor.global_position + Vector2(8, 13) - chest_collision_size * 0.5, chest_collision_size)
	return Rect2(foot_position - Vector2(size.x * 0.5, size.y * 0.55), size)


static func collision_polygon(slime: Sprite2D, actor_foot_offset: Vector2, requested_foot: Vector2 = Vector2.INF) -> PackedVector2Array:
	var guide := slime.get_node_or_null("CollisionPolygon") as Polygon2D
	if guide == null or guide.polygon.size() < 3:
		return PackedVector2Array()
	var offset := Vector2.ZERO if requested_foot == Vector2.INF else requested_foot - foot(slime, actor_foot_offset)
	var polygon := PackedVector2Array()
	for point in guide.polygon:
		polygon.append(guide.to_global(point) + offset)
	return polygon


static func body_polygon(slime: Sprite2D, actor_foot_offset: Vector2) -> PackedVector2Array:
	var hitbox := slime.get_node_or_null("BodyHitbox") as Polygon2D
	if hitbox == null or hitbox.polygon.size() < 3:
		return collision_polygon(slime, actor_foot_offset)
	var visual_offset := Vector2(slime.offset.x * slime.scale.x, slime.offset.y * slime.scale.y)
	var polygon := PackedVector2Array()
	for point in hitbox.polygon:
		polygon.append(hitbox.to_global(point) + visual_offset)
	return polygon


static func contact_radius(actor: Sprite2D, chest: Sprite2D, guide_rect: Rect2, fallback_radius: float) -> float:
	if actor == chest:
		return 5.5
	var body := actor.get_node_or_null("BodyHitbox") as Polygon2D
	if body != null and body.polygon.size() >= 3:
		var minimum_x := body.polygon[0].x
		var maximum_x := minimum_x
		for point in body.polygon:
			minimum_x = minf(minimum_x, point.x)
			maximum_x = maxf(maximum_x, point.x)
		var encounter_scale := float(actor.get_meta("encounter_scale", 1.0))
		return maxf((maximum_x - minimum_x) * encounter_scale * 0.5, 2.0)
	var scale_factor := 1.0 + (float(actor.get_meta("encounter_scale", 1.0)) - 1.0) * 0.35
	return (maxf(minf(guide_rect.size.x, guide_rect.size.y) * 0.5, 2.0) if guide_rect.has_area() else fallback_radius) * scale_factor


static func directional_reach(polygon: PackedVector2Array, origin: Vector2, direction: Vector2) -> float:
	var reach := 0.0
	for point in polygon:
		reach = maxf(reach, (point - origin).dot(direction))
	return reach


static func combat_target_point(collision_rect: Rect2) -> Vector2:
	return collision_rect.get_center()


static func global_polygon_bounds(polygon_owner: Polygon2D) -> Rect2:
	var bounds := Rect2(polygon_owner.to_global(polygon_owner.polygon[0]), Vector2.ZERO)
	for point in polygon_owner.polygon:
		bounds = bounds.expand(polygon_owner.to_global(point))
	return bounds
