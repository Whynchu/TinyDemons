extends RefCounted
class_name SlimeGeometryQueries

## Typed access to room collision and walkability data used by slime movement,
## placement, interaction, and actor-foot queries. GameplayState delegates remain
## the stable public callback surface for the rest of the game.

func _firepit_collision_body(root: GameplayState) -> Sprite2D:
	return root.rest_fire.get_node_or_null("Firepit") as Sprite2D if root.rest_fire != null else null

func collides_with_static(root: GameplayState, actor: Sprite2D) -> bool:
	var firepit := _firepit_collision_body(root)
	var chest := root.chest
	for other in root.collision_sprites:
		if other == actor or (other != chest and other != firepit):
			continue
		if other == firepit and collision_polygon_intersects_actor(root, actor, firepit):
			return true
		if other == chest and collision_rect(root, actor).intersects(collision_rect(root, other), false):
			return true
	return false


func collision_polygon_intersects_actor(root: GameplayState, actor: Sprite2D, polygon_owner: Sprite2D) -> bool:
	var polygon := polygon_owner.get_node_or_null("CollisionPolygon") as Polygon2D
	if polygon == null or polygon.polygon.size() < 3:
		return false
	var rect := collision_rect(root, actor)
	var rect_polygon := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var world_polygon := PackedVector2Array()
	for point in polygon.polygon:
		world_polygon.append(polygon.to_global(point))
	return not Geometry2D.intersect_polygons(rect_polygon, world_polygon).is_empty()


func perspective_movement(_root: GameplayState, movement: Vector2) -> Vector2:
	return Vector2(movement.x, movement.y * 0.5)


func collision_rect(root: GameplayState, actor: Sprite2D) -> Rect2:
	var firepit := _firepit_collision_body(root)
	var actor_foot_offset: Vector2 = GameplayState.ACTOR_FOOT_OFFSET
	var actor_collision_size := Vector2(GameplayState.ACTOR_COLLISION_WIDTH, GameplayState.ACTOR_COLLISION_HEIGHT)
	var chest_collision_size: Vector2 = GameplayState.CHEST_COLLISION_SIZE
	return ActorGeometry.collision_rect(actor, root.chest, firepit, root.slimes, actor_foot_offset, actor_collision_size, chest_collision_size, float(actor.get_meta("encounter_scale", 1.0)))


func collision_guide_rect(_root: GameplayState, actor: Sprite2D) -> Rect2:
	return ActorGeometry.guide_rect(actor, "CollisionGuide")


func collision_guide_rect_by_name(_root: GameplayState, actor: Sprite2D, guide_name: String) -> Rect2:
	return ActorGeometry.guide_rect(actor, guide_name)


func collect_walkable_tiles(root: GameplayState, node: Node) -> void:
	var area := root.walkable_area
	if area != null:
		area.collect_geometry(node, Callable(root, "_tile_top_polygon"))
		root.walkable_points = area.points.duplicate()
		root.walkable_polygons = area.polygons.duplicate()


func build_walkable_outline(root: GameplayState) -> void:
	var area := root.walkable_area
	if area != null:
		area.build_outline(bool(root.use_walkable_polygon_direct))
		root.walkable_outline = area.outline


func build_entrance_block_polygons(root: GameplayState) -> void:
	root.room_controller.build_entrance_blocks(root)
	var area := root.walkable_area
	if area != null:
		area.set_entrance_blocks(root.entrance_block_polygons)


func is_walkable(root: GameplayState, point: Vector2) -> bool:
	var area := root.walkable_area
	return area == null or area.is_walkable(point)


func can_actor_stand_at_current_position(root: GameplayState, actor: Sprite2D) -> bool:
	var collision := root.actor_collision_system
	return collision == null or collision.can_actor_stand(
		actor,
		root.slimes,
		Callable(root, "_actor_foot"),
		Callable(root, "_is_walkable"),
		Callable(root, "_is_slime_walkable_point"),
		Callable(root, "_collision_rect"),
		Callable(root, "_slime_collision_polygon")
	)


func is_slime_walkable_point(root: GameplayState, point: Vector2) -> bool:
	var area := root.walkable_area
	return area != null and area.is_slime_walkable(point)


func tile_top_polygon(_root: GameplayState, tile: Sprite2D) -> PackedVector2Array:
	return PackedVector2Array([
		tile.to_global(Vector2(8, 0)),
		tile.to_global(Vector2(16, 4)),
		tile.to_global(Vector2(8, 7)),
		tile.to_global(Vector2(0, 4)),
	])


func nearest_slime_walkable_point(root: GameplayState, point: Vector2) -> Vector2:
	var area := root.walkable_area
	return area.nearest_slime_walkable_point(point) if area != null and not area.is_empty() else point


func random_slime_walkable_point_near(root: GameplayState, point: Vector2, sample_count: int, ignored_slime: Sprite2D = null) -> Vector2:
	var area := root.walkable_area
	if area == null:
		return point
	var rng := root.rng
	for _attempt in 16:
		var candidate: Vector2 = area.random_slime_walkable_point_near(
			point,
			sample_count,
			ignored_slime,
			rng,
			Callable(root, "_is_point_near_other_slime")
		)
		if ignored_slime == null or bool(root._is_slime_collision_rect_walkable_at(ignored_slime, candidate)):
			return candidate
	return nearest_valid_slime_walkable_point(root, point, ignored_slime)


func nearest_valid_slime_walkable_point(root: GameplayState, point: Vector2, slime: Sprite2D) -> Vector2:
	var area := root.walkable_area
	if area == null or area.is_empty():
		return point
	var nearest := area.nearest_slime_walkable_point(point)
	for radius_value in [0.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0]:
		var radius: float = radius_value
		for direction_index in 16:
			var candidate := nearest + Vector2.RIGHT.rotated(TAU * float(direction_index) / 16.0) * radius
			if bool(root._is_slime_collision_rect_walkable_at(slime, candidate)):
				return candidate
	return point


func is_slime_collision_rect_walkable_at(root: GameplayState, slime: Sprite2D, foot: Vector2) -> bool:
	var polygon: PackedVector2Array = root._slime_collision_polygon(slime, foot)
	if polygon.size() >= 3:
		return is_slime_collision_polygon_walkable(root, polygon)
	var guide := slime.get_node_or_null("CollisionGuide") as Node2D
	var collision_bounds := Rect2(foot - Vector2(4.5, 2.2), Vector2(9, 4))
	if guide != null:
		var guide_position: Vector2 = guide.get("rect_position")
		var guide_size: Vector2 = guide.get("rect_size")
		var actor_position := foot - GameplayState.ACTOR_FOOT_OFFSET
		var origin := actor_position + guide.position + guide_position + Vector2(minf(guide_size.x, 0.0), minf(guide_size.y, 0.0))
		collision_bounds = Rect2(origin, guide_size.abs())
	var samples := [
		collision_bounds.position,
		collision_bounds.position + Vector2(collision_bounds.size.x, 0),
		collision_bounds.position + collision_bounds.size,
		collision_bounds.position + Vector2(0, collision_bounds.size.y),
		collision_bounds.get_center(),
		collision_bounds.position + Vector2(collision_bounds.size.x * 0.5, 0),
		collision_bounds.position + Vector2(collision_bounds.size.x, collision_bounds.size.y * 0.5),
		collision_bounds.position + Vector2(collision_bounds.size.x * 0.5, collision_bounds.size.y),
		collision_bounds.position + Vector2(0, collision_bounds.size.y * 0.5),
	]
	for sample in samples:
		if not is_slime_walkable_point(root, sample):
			return false
	return true


func slime_collision_polygon(root: GameplayState, slime: Sprite2D, foot: Vector2 = Vector2.INF) -> PackedVector2Array:
	return ActorGeometry.collision_polygon(slime, GameplayState.ACTOR_FOOT_OFFSET, foot)


func slime_body_polygon(root: GameplayState, slime: Sprite2D) -> PackedVector2Array:
	return ActorGeometry.body_polygon(slime, GameplayState.ACTOR_FOOT_OFFSET)


func is_slime_collision_polygon_walkable(root: GameplayState, polygon: PackedVector2Array) -> bool:
	var center := Vector2.ZERO
	for index in polygon.size():
		var point := polygon[index]
		# The authored slime foot polygons are convex; vertices + center bound the
		# whole shape, so edge midpoints are skipped to halve the per-scoot cost.
		if not is_slime_walkable_point(root, point):
			return false
		center += point
	return is_slime_walkable_point(root, center / float(polygon.size()))


func is_point_near_other_slime(root: GameplayState, point: Vector2, ignored_slime: Sprite2D = null) -> bool:
	for slime in root.slimes:
		if slime != ignored_slime and not bool(root._is_slime_dead(slime)) and collision_rect(root, slime).grow(4.0).has_point(point):
			return true
	return false


func actor_foot(root: GameplayState, actor: Sprite2D) -> Vector2:
	if actor == root.cloaked_demon:
		return root._cloaked_demon_foot_position()
	return ActorGeometry.foot(actor, GameplayState.ACTOR_FOOT_OFFSET)
