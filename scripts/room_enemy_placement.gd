extends RefCounted
class_name RoomEnemyPlacement

## Pure placement policy for room enemies.
##
## RoomController owns encounter state and spawn side effects. This helper only
## answers where an actor can stand, using explicit room geometry and socket
## inputs so the solver does not need a GameplayState/root lookup.

static func choose_spawn_position(
	area: WalkableArea,
	slime: Sprite2D,
	layout_rng: RandomNumberGenerator,
	occupied: Array[Vector2],
	player_foot: Vector2,
	chest_rect: Rect2,
	actor_foot_offset: Vector2,
	active_door_sockets: Dictionary,
	active_entrance_sockets: Dictionary,
	minimum_player_distance: float,
	minimum_spawn_distance: float,
	minimum_socket_distance: float
) -> Vector2:
	var bounds := Rect2()
	if area != null:
		for point in area.outline:
			bounds = bounds.expand(point)
	for _attempt in 96:
		if bounds.size == Vector2.ZERO:
			break
		var candidate_foot := Vector2(
			layout_rng.randf_range(bounds.position.x, bounds.end.x),
			layout_rng.randf_range(bounds.position.y, bounds.end.y))
		if valid_spawn_foot(
			slime,
			candidate_foot,
			player_foot,
			chest_rect,
			occupied,
			area,
			actor_foot_offset,
			active_door_sockets,
			active_entrance_sockets,
			minimum_player_distance,
			minimum_spawn_distance,
			minimum_socket_distance):
			return candidate_foot - actor_foot_offset
	if area != null:
		for candidate_foot in area.points:
			if valid_spawn_foot(
				slime,
				candidate_foot,
				player_foot,
				chest_rect,
				occupied,
				area,
				actor_foot_offset,
				active_door_sockets,
				active_entrance_sockets,
				minimum_player_distance,
				minimum_spawn_distance,
				minimum_socket_distance):
				return candidate_foot - actor_foot_offset
	var nearest_foot := area.nearest_slime_walkable_point(player_foot) if area != null and not area.is_empty() else player_foot
	for radius_value in [0.0, 4.0, 8.0, 12.0, 16.0, 24.0, 32.0]:
		var radius: float = radius_value
		for direction_index in 16:
			var candidate_foot := nearest_foot + Vector2.RIGHT.rotated(TAU * float(direction_index) / 16.0) * radius
			if valid_spawn_foot(
				slime,
				candidate_foot,
				player_foot,
				chest_rect,
				occupied,
				area,
				actor_foot_offset,
				active_door_sockets,
				active_entrance_sockets,
				minimum_player_distance,
				minimum_spawn_distance,
				minimum_socket_distance):
				return candidate_foot - actor_foot_offset
	return Vector2(INF, INF)


static func valid_spawn_foot(
	slime: Sprite2D,
	candidate_foot: Vector2,
	player_foot: Vector2,
	chest_rect: Rect2,
	occupied: Array[Vector2],
	area: WalkableArea,
	actor_foot_offset: Vector2,
	active_door_sockets: Dictionary,
	active_entrance_sockets: Dictionary,
	minimum_player_distance: float,
	minimum_spawn_distance: float,
	minimum_socket_distance: float
) -> bool:
	if not is_slime_collision_rect_walkable_at(area, slime, candidate_foot, actor_foot_offset):
		return false
	var collision_rect := enemy_collision_rect_at(slime, candidate_foot, actor_foot_offset)
	if not is_collision_rect_walkable(area, collision_rect):
		return false
	if candidate_foot.distance_to(player_foot) < minimum_player_distance:
		return false
	if chest_rect.grow(4.0).intersects(collision_rect, false):
		return false
	if is_enemy_spawn_near_socket(candidate_foot, active_door_sockets, active_entrance_sockets, minimum_socket_distance):
		return false
	for occupied_foot in occupied:
		if candidate_foot.distance_to(occupied_foot) < minimum_spawn_distance:
			return false
	return true


static func is_enemy_spawn_near_socket(
	candidate_foot: Vector2,
	active_door_sockets: Dictionary,
	active_entrance_sockets: Dictionary,
	minimum_socket_distance: float
) -> bool:
	for socket_group in [active_door_sockets, active_entrance_sockets]:
		for socket_value in socket_group.values():
			var socket := socket_value as DungeonSocket
			var marker := socket.spawn_marker() if socket != null else null
			if marker != null and candidate_foot.distance_to(marker.global_position) < minimum_socket_distance:
				return true
	return false


static func enemy_collision_rect_at(slime: Sprite2D, foot: Vector2, actor_foot_offset: Vector2) -> Rect2:
	var guide := slime.get_node_or_null("CollisionGuide") as Node2D
	if guide == null:
		return Rect2(foot - Vector2(4.5, 2.2), Vector2(9, 4))
	var guide_position: Vector2 = guide.get("rect_position")
	var guide_size: Vector2 = guide.get("rect_size")
	var actor_position := foot - actor_foot_offset
	var origin := actor_position + guide.position + guide_position + Vector2(minf(guide_size.x, 0.0), minf(guide_size.y, 0.0))
	return Rect2(origin, guide_size.abs())


static func is_collision_rect_walkable(area: WalkableArea, collision_rect: Rect2) -> bool:
	if area == null:
		return false
	var samples := [
		collision_rect.position,
		collision_rect.position + Vector2(collision_rect.size.x, 0),
		collision_rect.position + collision_rect.size,
		collision_rect.position + Vector2(0, collision_rect.size.y),
		collision_rect.get_center(),
		collision_rect.position + Vector2(collision_rect.size.x * 0.5, 0),
		collision_rect.position + Vector2(collision_rect.size.x, collision_rect.size.y * 0.5),
		collision_rect.position + Vector2(collision_rect.size.x * 0.5, collision_rect.size.y),
		collision_rect.position + Vector2(0, collision_rect.size.y * 0.5),
	]
	for sample in samples:
		if not area.is_slime_walkable(sample):
			return false
	return true


static func is_slime_collision_rect_walkable_at(
	area: WalkableArea,
	slime: Sprite2D,
	foot: Vector2,
	actor_foot_offset: Vector2
) -> bool:
	if area == null:
		return false
	var polygon := ActorGeometry.collision_polygon(slime, actor_foot_offset, foot)
	if polygon.size() >= 3:
		var center := Vector2.ZERO
		for point in polygon:
			if not area.is_slime_walkable(point):
				return false
			center += point
		return area.is_slime_walkable(center / float(polygon.size()))
	var guide := slime.get_node_or_null("CollisionGuide") as Node2D
	var collision_bounds := Rect2(foot - Vector2(4.5, 2.2), Vector2(9, 4))
	if guide != null:
		var guide_position: Vector2 = guide.get("rect_position")
		var guide_size: Vector2 = guide.get("rect_size")
		var actor_position := foot - actor_foot_offset
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
		if not area.is_slime_walkable(sample):
			return false
	return true
