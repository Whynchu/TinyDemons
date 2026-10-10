# Owner: Actor collision geometry, contact broad phase, and response.
extends Node
class_name ActorCollisionSystem

## Handles floor checks and bounded actor-contact broad/narrow phases.

@export var contact_distance := 64.0

## Spatial broad-phase for the slime crowd. A uniform grid is rebuilt once per
## frame so contact separation and AI steering only examine slimes in nearby
## cells instead of scanning the whole room, keeping crowd work bounded by local
## density rather than the total enemy count.
const SLIME_GRID_CELL_SIZE := 24.0
## Caps how many slime-slime separation attempts run per frame. A packed crowd
## can otherwise spend the whole frame budget pushing overlapping slimes apart;
## the budget bounds that work so the worst frame stays near the steady-state
## cost. Slimes not separated this frame retry next frame.
const MAX_SLIME_SEPARATION_BUDGET := 28

var _slime_grid: Dictionary = {}
var _slime_grid_index: Dictionary = {}
var _slime_grid_valid := false
var _grid_candidate_scratch: Array[Sprite2D] = []
var _motion_candidate_slime_ids: Dictionary = {}
var _motion_candidate_scratch: Array[Sprite2D] = []
var _contact_eligibility_cache: Dictionary = {}
var _contact_foot_cache: Dictionary = {}
var _contact_radius_cache: Dictionary = {}
var _contact_collision_rect_cache: Dictionary = {}
var _contact_broadphase_radius_cache: Dictionary = {}
var _contact_broadphase_max_radius := 0.0
var _contact_broadphase_ready_for_separation := false
var _contact_broadphase_root_id := 0
var _contact_broadphase_physics_frame := -1


func stabilize_guides(actors_to_stabilize: Array[Sprite2D], update_attack_guides: Callable) -> void:
	for actor in actors_to_stabilize:
		var is_slime := actor is SlimeActor
		var actor_scale := actor.scale
		if absf(actor_scale.x) < 0.001 or absf(actor_scale.y) < 0.001:
			continue
		for child in actor.get_children():
			if child is Node2D and (child.name.ends_with("Guide") or child.name.begins_with("AttackGuide") or child.name == "CollisionPolygon"):
				# Boss collision guides describe the scaled visual body. Inverse-
				# scaling them makes the runtime guide detach from the editor-authored
				# position after the boss sprite is enlarged. CollisionPolygon is the
				# boss's foot/walkability shape, so it must inherit that same scale too.
				if child.name in [&"CollisionGuide", &"CollisionPolygon"] and is_slime and float(actor.get_meta("encounter_scale", 1.0)) > 1.0:
					continue
				(child as Node2D).scale = Vector2(1.0 / actor_scale.x, 1.0 / actor_scale.y)
		if is_slime:
			update_attack_guides.call(actor)


func build_motion_contact_candidates(candidates: Array[Sprite2D], slimes: Array[Sprite2D]) -> Array[Sprite2D]:
	_motion_candidate_slime_ids.clear()
	for slime in slimes:
		if is_instance_valid(slime):
			_motion_candidate_slime_ids[slime.get_instance_id()] = true
	_motion_candidate_scratch.clear()
	for candidate in candidates:
		if is_instance_valid(candidate) and _motion_candidate_slime_ids.has(candidate.get_instance_id()):
			continue
		_motion_candidate_scratch.append(candidate)
	# The returned scratch array is consumed synchronously by one movement call.
	return _motion_candidate_scratch


func resolve_motion_contacts(
	actor: Sprite2D,
	movement: Vector2,
	candidates: Array[Sprite2D],
	root: GameplayState,
	actor_is_slime_override: Variant = null,
	candidates_are_slime_filtered: bool = false
) -> void:
	# Slime movement passes a filtered candidate snapshot and its known actor
	# kind, so avoid resolving the same roster property on every displacement.
	var slimes: Array[Sprite2D] = []
	if not candidates_are_slime_filtered or actor_is_slime_override == null:
		slimes = root.get("slimes") as Array[Sprite2D]
	var actor_is_slime := slimes.has(actor) if actor_is_slime_override == null else bool(actor_is_slime_override)
	for other in candidates:
		if other == actor or not is_instance_valid(other) or not other.visible or bool(other.get_meta("boss_airborne", false)):
			continue
		if not candidates_are_slime_filtered and slimes.has(other) and root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", other)):
			continue
		if actor_is_slime and not candidates_are_slime_filtered and slimes.has(other):
			continue
		if actor.global_position.distance_squared_to(other.global_position) > contact_distance * contact_distance:
			continue
		resolve_contact_pair(actor, other, movement, root)


func resolve_slime_contacts(slimes: Array[Sprite2D], root: GameplayState, max_passes: int = 2) -> int:
	var resolved_pairs := 0
	if slimes.size() < 2:
		return 0
	var actor_foot := Callable(root, "_actor_foot")
	var is_spawn_locked := Callable(root, "_is_slime_spawn_locked") if root.has_method("_is_slime_spawn_locked") else Callable()
	# The frame cache normally builds the broad-phase grid; build it lazily so the
	# resolver stays correct for direct callers.
	if not _slime_grid_valid:
		build_slime_grid(slimes, actor_foot, is_spawn_locked)
	if not _contact_broadphase_ready_for_separation or _contact_broadphase_root_id != _contact_broadphase_key(slimes) or _contact_broadphase_physics_frame != Engine.get_physics_frames():
		_contact_foot_cache.clear()
		_contact_radius_cache.clear()
		_contact_collision_rect_cache.clear()
		_contact_broadphase_radius_cache.clear()
		_prepare_contact_broadphase_cache(slimes, root, actor_foot, is_spawn_locked, Callable(), false)
	_contact_broadphase_ready_for_separation = false
	var separation_attempts := 0
	for separation_pass in max_passes:
		if separation_pass > 0:
			# Separation moved actors after the previous pass. Rebuild their cells
			# before searching again so the next pass remains complete for large
			# contacts and does not rely on an oversized stale-grid radius.
			build_slime_grid(slimes, actor_foot, is_spawn_locked)
			_contact_foot_cache.clear()
			_contact_radius_cache.clear()
			_contact_collision_rect_cache.clear()
			_contact_broadphase_radius_cache.clear()
			_prepare_contact_broadphase_cache(slimes, root, actor_foot, is_spawn_locked, Callable(), false)
		var resolved_this_pass := false
		for actor_index in slimes.size():
			var actor := slimes[actor_index]
			if not is_instance_valid(actor) or not actor.visible or bool(actor.get_meta("boss_airborne", false)) or (root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", actor))):
				continue
			# Keep the legacy search window during a pass because earlier pairs can
			# move actors while their grid cells remain fixed. Expand it when an
			# enlarged actor's exact contact envelope is wider.
			var contact_envelope := float(_contact_broadphase_radius_cache.get(actor, contact_distance)) + _contact_broadphase_max_radius
			var query_radius := maxf(contact_distance, contact_envelope)
			_fill_slime_grid_candidates(actor_foot.call(actor), query_radius, _grid_candidate_scratch)
			for other in _grid_candidate_scratch:
				if other == actor or not is_instance_valid(other) or not other.visible or bool(other.get_meta("boss_airborne", false)) or (root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", other))):
					continue
				if slime_grid_position(other) <= actor_index:
					continue
				if separation_attempts >= MAX_SLIME_SEPARATION_BUDGET:
					return resolved_pairs
				separation_attempts += 1
				var push := _contact_capture_push_vector(root, actor, other, _contact_foot_cache, _contact_radius_cache, _contact_collision_rect_cache, actor_foot)
				if push == Vector2.ZERO:
					continue
				if _separate_slime_pair(root, actor, other, push):
					resolved_pairs += 1
					resolved_this_pass = true
					_contact_foot_cache.erase(actor)
					_contact_foot_cache.erase(other)
					_contact_collision_rect_cache.erase(actor)
					_contact_collision_rect_cache.erase(other)
		if not resolved_this_pass:
			break
	return resolved_pairs


func capture_status_contact_pairs(
	slimes: Array[Sprite2D],
	player: Sprite2D,
	root: GameplayState,
	actor_foot: Callable,
	is_spawn_locked: Callable,
	is_dead: Callable
) -> Array[StatusContactPair]:
	var contacts: Array[StatusContactPair] = []
	_contact_eligibility_cache.clear()
	_contact_foot_cache.clear()
	_contact_radius_cache.clear()
	_contact_collision_rect_cache.clear()
	_contact_broadphase_radius_cache.clear()
	_contact_broadphase_max_radius = 0.0
	_contact_broadphase_ready_for_separation = false
	if not _slime_grid_valid:
		build_slime_grid(slimes, actor_foot, is_spawn_locked)
	# The radius envelope covers every entry in the live movement grid. Exact
	# status-pair eligibility is still checked inside the snapshot loops.
	_prepare_contact_broadphase_cache(slimes, root, actor_foot, is_spawn_locked, Callable(), false)
	for actor_index in slimes.size():
		var actor := slimes[actor_index]
		if not _contact_capture_actor_is_eligible_cached(actor, _contact_eligibility_cache, is_spawn_locked, is_dead):
			continue
		var actor_foot_position := _contact_capture_actor_foot(actor, _contact_foot_cache, actor_foot)
		var actor_query_radius := float(_contact_broadphase_radius_cache.get(actor, contact_distance)) + _contact_broadphase_max_radius
		_fill_slime_grid_candidates(actor_foot_position, actor_query_radius, _grid_candidate_scratch)
		for other in _grid_candidate_scratch:
			# The stable grid indices emit each unordered pair once.
			if other == actor or slime_grid_position(other) <= actor_index or not _contact_capture_actor_is_eligible_cached(other, _contact_eligibility_cache, is_spawn_locked, is_dead):
				continue
			if _contact_capture_push_vector(root, actor, other, _contact_foot_cache, _contact_radius_cache, _contact_collision_rect_cache, actor_foot) == Vector2.ZERO:
				continue
			var pair := StatusContactPair.new()
			pair.configure(actor, other)
			contacts.append(pair)
	if player != null and is_instance_valid(player):
		var player_foot_position := _contact_capture_actor_foot(player, _contact_foot_cache, actor_foot)
		var player_query_radius := _contact_capture_broadphase_radius(root, player, actor_foot, _contact_foot_cache, _contact_radius_cache, _contact_collision_rect_cache, _contact_broadphase_radius_cache) + _contact_broadphase_max_radius
		_fill_slime_grid_candidates(player_foot_position, player_query_radius, _grid_candidate_scratch)
		for slime in _grid_candidate_scratch:
			if not _contact_capture_actor_is_eligible_cached(slime, _contact_eligibility_cache, is_spawn_locked, is_dead) or _contact_capture_push_vector(root, slime, player, _contact_foot_cache, _contact_radius_cache, _contact_collision_rect_cache, actor_foot) == Vector2.ZERO:
				continue
			var pair := StatusContactPair.new()
			pair.configure(slime, player)
			contacts.append(pair)
	_contact_broadphase_ready_for_separation = true
	_contact_broadphase_root_id = _contact_broadphase_key(slimes, player)
	_contact_broadphase_physics_frame = Engine.get_physics_frames()
	return contacts


func _contact_broadphase_key(slimes: Array[Sprite2D], fallback: Sprite2D = null) -> int:
	if not slimes.is_empty() and is_instance_valid(slimes[0]):
		return slimes[0].get_instance_id()
	return fallback.get_instance_id() if fallback != null and is_instance_valid(fallback) else 0


func _prepare_contact_broadphase_cache(
	slimes: Array[Sprite2D],
	root: GameplayState,
	actor_foot: Callable,
	is_spawn_locked: Callable = Callable(),
	is_dead: Callable = Callable(),
	require_capture_eligibility: bool = true
) -> void:
	_contact_broadphase_max_radius = 0.0
	for actor in slimes:
		if require_capture_eligibility:
			if not _contact_capture_actor_is_eligible(actor, is_spawn_locked, is_dead):
				continue
		else:
			if actor == null or not is_instance_valid(actor) or not actor.visible or bool(actor.get_meta("boss_airborne", false)):
				continue
			if is_spawn_locked.is_valid() and bool(is_spawn_locked.call(actor)):
				continue
		var radius := _contact_capture_broadphase_radius(root, actor, actor_foot, _contact_foot_cache, _contact_radius_cache, _contact_collision_rect_cache, _contact_broadphase_radius_cache)
		_contact_broadphase_max_radius = maxf(_contact_broadphase_max_radius, radius)


func _contact_capture_broadphase_radius(
	root: GameplayState,
	actor: Sprite2D,
	actor_foot: Callable,
	foot_cache: Dictionary,
	radius_cache: Dictionary,
	collision_rect_cache: Dictionary,
	broadphase_radius_cache: Dictionary
) -> float:
	if broadphase_radius_cache.has(actor):
		return float(broadphase_radius_cache[actor])
	var actor_foot_position := _contact_capture_actor_foot(actor, foot_cache, actor_foot)
	var rect := _contact_capture_collision_rect(root, actor, collision_rect_cache)
	var rect_radius := actor_foot_position.distance_to(rect.get_center()) + rect.size.length() * 0.5
	var radius := maxf(_contact_capture_actor_radius(root, actor, radius_cache), rect_radius)
	broadphase_radius_cache[actor] = radius
	return radius


func _contact_capture_actor_is_eligible(actor: Sprite2D, is_spawn_locked: Callable, is_dead: Callable) -> bool:
	if actor == null or not is_instance_valid(actor) or not actor.visible or not actor.is_visible_in_tree() or bool(actor.get_meta("boss_airborne", false)):
		return false
	if is_spawn_locked.is_valid() and bool(is_spawn_locked.call(actor)):
		return false
	if is_dead.is_valid() and bool(is_dead.call(actor)):
		return false
	return true


func _contact_capture_actor_is_eligible_cached(actor: Sprite2D, cache: Dictionary, is_spawn_locked: Callable, is_dead: Callable) -> bool:
	if cache.has(actor):
		return bool(cache[actor])
	var eligible := _contact_capture_actor_is_eligible(actor, is_spawn_locked, is_dead)
	cache[actor] = eligible
	return eligible


func _contact_capture_actor_foot(actor: Sprite2D, cache: Dictionary, actor_foot: Callable) -> Vector2:
	if cache.has(actor):
		return cache[actor] as Vector2
	var foot := actor_foot.call(actor) as Vector2
	cache[actor] = foot
	return foot


func _contact_capture_push_vector(
	root: GameplayState,
	actor: Sprite2D,
	other: Sprite2D,
	foot_cache: Dictionary,
	radius_cache: Dictionary,
	collision_rect_cache: Dictionary,
	actor_foot: Callable
) -> Vector2:
	if _uses_body_contact(actor) or _uses_body_contact(other):
		var actor_rect := _contact_capture_collision_rect(root, actor, collision_rect_cache)
		var other_rect := _contact_capture_collision_rect(root, other, collision_rect_cache)
		return _rect_contact_push_vector(actor_rect, other_rect)
	var delta := _contact_capture_actor_foot(actor, foot_cache, actor_foot) - _contact_capture_actor_foot(other, foot_cache, actor_foot)
	if not delta.is_finite():
		return Vector2.ZERO
	var distance := delta.length()
	var minimum_distance := _contact_capture_actor_radius(root, actor, radius_cache) + _contact_capture_actor_radius(root, other, radius_cache)
	if not is_finite(distance) or not is_finite(minimum_distance) or minimum_distance <= 0.0:
		return Vector2.ZERO
	if distance >= minimum_distance:
		return Vector2.ZERO
	if distance <= 0.001:
		delta = Vector2.RIGHT
		distance = 1.0
	var push_distance := minimum_distance - distance
	if not is_finite(push_distance) or push_distance <= 0.0:
		return Vector2.ZERO
	var normal := delta.normalized()
	return normal * push_distance if normal.is_finite() else Vector2.ZERO


func _contact_capture_actor_radius(root: GameplayState, actor: Sprite2D, cache: Dictionary) -> float:
	if cache.has(actor):
		return float(cache[actor])
	var radius := actor_contact_radius(root, actor)
	cache[actor] = radius
	return radius


func _contact_capture_collision_rect(root: GameplayState, actor: Sprite2D, cache: Dictionary) -> Rect2:
	if cache.has(actor):
		return cache[actor] as Rect2
	var rect := root.call("_collision_rect", actor) as Rect2
	cache[actor] = rect
	return rect


func build_slime_grid(slimes: Array[Sprite2D], actor_foot: Callable, is_spawn_locked: Callable = Callable()) -> void:
	_contact_broadphase_ready_for_separation = false
	_slime_grid.clear()
	_slime_grid_index.clear()
	for index in slimes.size():
		var slime := slimes[index]
		if slime == null or not is_instance_valid(slime) or not slime.visible or bool(slime.get_meta("boss_airborne", false)) or (is_spawn_locked.is_valid() and bool(is_spawn_locked.call(slime))):
			continue
		var cell := _grid_cell(actor_foot.call(slime) as Vector2)
		var bucket: Variant = _slime_grid.get(cell)
		if bucket == null:
			bucket = []
			_slime_grid[cell] = bucket
		(bucket as Array).append(slime)
		_slime_grid_index[slime] = index
	_slime_grid_valid = true


func invalidate_slime_grid() -> void:
	_contact_broadphase_ready_for_separation = false
	_slime_grid_valid = false


## Returns the slimes whose broad-phase cells overlap a circle of `radius`
## around `point`. Callers still apply their exact distance/dead/boss filters.
func slime_grid_candidates(point: Vector2, radius: float) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	_fill_slime_grid_candidates(point, radius, result)
	return result


func _fill_slime_grid_candidates(point: Vector2, radius: float, result: Array[Sprite2D]) -> void:
	result.clear()
	if not _slime_grid_valid:
		return
	var min_cell := _grid_cell(point - Vector2.ONE * radius)
	var max_cell := _grid_cell(point + Vector2.ONE * radius)
	for cell_x in range(min_cell.x, max_cell.x + 1):
		for cell_y in range(min_cell.y, max_cell.y + 1):
			var bucket: Variant = _slime_grid.get(Vector2i(cell_x, cell_y))
			if bucket == null:
				continue
			# Each live slime is inserted into exactly one grid cell and each
			# cell coordinate is visited once, so candidates cannot duplicate.
			for slime in bucket as Array:
				result.append(slime)


## The slot index recorded for a slime by the last grid build (used to dedupe
## contact pairs). Returns -1 for slimes not present in the grid.
func slime_grid_position(slime: Sprite2D) -> int:
	return int(_slime_grid_index.get(slime, -1))


func _grid_cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / SLIME_GRID_CELL_SIZE), floori(point.y / SLIME_GRID_CELL_SIZE))


func _separate_slime_pair(root: GameplayState, actor: Sprite2D, other: Sprite2D, push: Vector2) -> bool:
	var actor_start := actor.position
	var other_start := other.position
	var actor_movement_locked := _actor_movement_locked(actor)
	var other_movement_locked := _actor_movement_locked(other)
	if actor_movement_locked or other_movement_locked:
		if actor_movement_locked and other_movement_locked:
			return false
		var movable := other if actor_movement_locked else actor
		if _uses_body_contact(movable):
			return false
		var movable_start := movable.position
		var displacement := -push if actor_movement_locked else push
		movable.position += displacement
		if _position_is_valid(root, movable):
			return true
		movable.position = movable_start
		return false
	var actor_cast_locked := _is_support_cast_locked(actor)
	var other_cast_locked := _is_support_cast_locked(other)
	if actor_cast_locked or other_cast_locked:
		if actor_cast_locked and other_cast_locked:
			return false
		var movable := other if actor_cast_locked else actor
		# A boss and a healer both hold their authored position during these
		# contacts. Preserve the overlap instead of displacing either actor.
		if _uses_body_contact(movable):
			return false
		var movable_start := movable.position
		var displacement := -push if actor_cast_locked else push
		movable.position += displacement
		if _position_is_valid(root, movable):
			return true
		movable.position = movable_start
		return false
	var actor_is_boss := _uses_body_contact(actor)
	var other_is_boss := _uses_body_contact(other)
	# Bosses own their movement lane. A regular slime caught in that lane takes
	# the entire separation displacement; it can never stop or shove the boss.
	if actor_is_boss != other_is_boss:
		if actor_is_boss:
			return _move_regular_away_from_boss(root, other, -push)
		return _move_regular_away_from_boss(root, actor, push)
	actor.position += push * 0.5
	other.position -= push * 0.5
	var actor_valid := _position_is_valid(root, actor)
	var other_valid := _position_is_valid(root, other)
	if actor_valid and other_valid:
		return true
	# The 50/50 split was the cheap, always-valid-in-open-space resolve. In a
	# packed crowd a side can be blocked; skip the expensive full-push fallback
	# revalidations and leave the overlap for the next frame's pass instead.
	actor.position = actor_start
	other.position = other_start
	return false


func _is_support_cast_locked(actor: Sprite2D) -> bool:
	var support := actor.get_node_or_null("Support")
	return support != null and bool(support.call("is_cast_active"))


func _move_regular_away_from_boss(root: GameplayState, regular: Sprite2D, preferred_direction: Vector2) -> bool:
	if preferred_direction.length_squared() <= 0.0001:
		return false
	var directions := [preferred_direction, preferred_direction.rotated(PI * 0.5)]
	for direction in directions:
		var original := regular.position
		var unit_direction: Vector2 = (direction as Vector2).normalized()
		# Resolve the whole measured overlap, and keep probing beyond it when the
		# enlarged boss body still contains the regular slime. The boss never
		# moves; the regular actor owns the retry distance.
		var maximum_distance: float = maxf((direction as Vector2).length(), 12.0)
		var probe_count: int = maxi(1, ceili(maximum_distance / 0.75))
		for probe_index in range(1, probe_count + 1):
			regular.position = original + unit_direction * 0.75 * float(probe_index)
			if _position_is_valid(root, regular):
				return true
		regular.position = original
	return false


func _position_is_valid(root: GameplayState, actor: Sprite2D) -> bool:
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


func can_actor_stand(actor: Sprite2D, slimes: Array[Sprite2D], foot: Callable, is_walkable: Callable, is_slime_walkable: Callable, collision_rect: Callable, collision_polygon: Callable, collision_polygon_walkability: Callable = Callable()) -> bool:
	var actor_is_slime := actor is SlimeActor
	if not actor_is_slime:
		actor_is_slime = slimes.has(actor)
	if not actor_is_slime:
		# Room floor geometry is authored for the actor's foot path. The sprite
		# body is intentionally allowed to overhang the isometric floor edge; using
		# every body corner here makes ordinary wall travel snag and prevents an
		# open lower doorway from reaching its transition trigger. Closed doorway
		# seams are handled by the entrance block polygons through this foot check.
		return bool(is_walkable.call(foot.call(actor)))
	var collision_guide := actor.get_node_or_null("CollisionPolygon") as Polygon2D
	if collision_guide != null and collision_guide.polygon.size() >= 3 and collision_polygon_walkability.is_valid():
		return bool(collision_polygon_walkability.call(actor))
	var polygon: PackedVector2Array = collision_polygon.call(actor)
	if polygon.size() >= 3:
		for index: int in polygon.size():
			var point := polygon[index]
			if not bool(is_slime_walkable.call(point)):
				return false
			var next_point := polygon[(index + 1) % polygon.size()]
			if not bool(is_slime_walkable.call(point.lerp(next_point, 0.5))):
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


func resolve_contact_pair(actor: Sprite2D, other: Sprite2D, movement: Vector2, root: GameplayState) -> void:
	var slimes := root.get("slimes") as Array[Sprite2D]
	if (slimes.has(actor) and root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", actor))) or (slimes.has(other) and root.has_method("_is_slime_spawn_locked") and bool(root.call("_is_slime_spawn_locked", other))):
		return
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
		# An active doorway is a narrow escape lane. Enemy contact should not pin
		# the player against the socket while they are trying to leave a fight.
		if _player_occupies_active_doorway(root):
			return
		# The player should be able to push an enemy even while that enemy is in
		# an attack animation.  Slime AI intentionally stops its own scoot during
		# attacks, so making the player absorb the overlap turns an attacking
		# slime into an immovable wall.  Resolve the contact by moving the
		# non-player body first; static geometry still makes the enemy give way
		# only when the destination is valid.
		var push := overlap_push_vector(root, actor, other)
		if push != Vector2.ZERO:
			var player := root.get("player") as Sprite2D
			var enemy := other if actor == player else actor
			var enemy_push := -push if actor == player else push
			var support := enemy.get_node_or_null("Support") as Node if enemy != null else null
			var cast_locked := support != null and bool(support.call("is_cast_active"))
			var can_move_enemy := enemy != null and enemy != player and not cast_locked and not _actor_movement_locked(enemy)
			if can_move_enemy and try_move_swept(enemy, enemy_push, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static")):
				return
			# If the enemy is pinned against room geometry, preserve the old
			# safety behavior and separate the player instead of allowing the
			# two collision bodies to remain stacked.
			try_move_swept(player, push if actor == player else -push, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
	else:
		push_actor(root, actor, other, movement)


func push_actor(root: GameplayState, actor: Sprite2D, other: Sprite2D, movement: Vector2) -> void:
	var push := overlap_push_vector(root, actor, other)
	if push == Vector2.ZERO: return
	var actor_movement_locked := _actor_movement_locked(actor)
	var other_movement_locked := _actor_movement_locked(other)
	if actor_movement_locked and other_movement_locked:
		return
	if actor_movement_locked:
		try_move_swept(other, -push + movement * 0.45, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
		return
	if other_movement_locked:
		try_move_swept(actor, push + movement * 0.45, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
		return
	var actor_weight := 1.0 if actor == root.get("player") else 1.45
	var other_weight := 1.0 if other == root.get("player") else 1.45
	var total_weight := actor_weight + other_weight
	var actor_share := other_weight / total_weight
	var other_share := actor_weight / total_weight
	try_move_swept(actor, push * actor_share, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))
	try_move_swept(other, -push * other_share + movement * other_share * 0.45, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))


func separate_actor(root: GameplayState, actor: Sprite2D, other: Sprite2D) -> void:
	if _actor_movement_locked(actor):
		return
	actor.position += overlap_push_vector(root, actor, other)


func _actor_movement_locked(actor: Sprite2D) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	var status := actor.get_node_or_null("Status") as StatusComponent
	return status != null and status.is_movement_locked()


func overlap_push_vector(root: GameplayState, actor: Sprite2D, other: Sprite2D) -> Vector2:
	if (actor != null and bool(actor.get_meta("boss_airborne", false))) or (other != null and bool(other.get_meta("boss_airborne", false))):
		return Vector2.ZERO
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


func actors_are_in_contact(root: GameplayState, actor: Sprite2D, other: Sprite2D) -> bool:
	if (actor != null and bool(actor.get_meta("boss_airborne", false))) or (other != null and bool(other.get_meta("boss_airborne", false))):
		return false
	var chest := root.get("chest") as Sprite2D
	var rest_fire := root.get("rest_fire") as Sprite2D
	var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D if rest_fire != null else null
	if actor == firepit or other == firepit:
		var moving_actor := actor if other == firepit else other
		var fire_actor := firepit if other == firepit else actor
		return fire_actor != null and bool(root.call("_collision_polygon_intersects_actor", moving_actor, fire_actor))
	if actor == chest or other == chest: return (root.call("_collision_rect", actor) as Rect2).intersects(root.call("_collision_rect", other) as Rect2, false)
	return actor_contact_push_vector(root, actor, other) != Vector2.ZERO


func actor_contact_push_vector(root: GameplayState, actor: Sprite2D, other: Sprite2D) -> Vector2:
	if actor == null or other == null or not is_instance_valid(actor) or not is_instance_valid(other):
		return Vector2.ZERO
	if _uses_body_contact(actor) or _uses_body_contact(other):
		return _rect_overlap_push_vector(root, actor, other)
	var delta: Vector2 = root.call("_actor_foot", actor) - root.call("_actor_foot", other)
	if not delta.is_finite():
		return Vector2.ZERO
	var distance := delta.length(); var min_distance := actor_contact_radius(root, actor) + actor_contact_radius(root, other)
	if not is_finite(distance) or not is_finite(min_distance) or min_distance <= 0.0:
		return Vector2.ZERO
	if distance >= min_distance: return Vector2.ZERO
	if distance <= 0.001: delta = Vector2.RIGHT; distance = 1.0
	var push_distance := min_distance - distance
	if not is_finite(push_distance) or push_distance <= 0.0:
		return Vector2.ZERO
	var normal := delta.normalized()
	return normal * push_distance if normal.is_finite() else Vector2.ZERO


func player_contact_movement(root: GameplayState, movement: Vector2) -> Vector2:
	var player := root.get("player") as Sprite2D
	if player == null or movement.length_squared() <= 0.0001:
		return movement
	if _player_occupies_active_doorway(root):
		return movement
	var result := movement
	for slime in root.get("slimes") as Array[Sprite2D]:
		if not is_instance_valid(slime) or not slime.visible or bool(slime.get_meta("boss_airborne", false)) or not actors_are_in_contact(root, player, slime):
			continue
		var away_delta: Vector2 = root.call("_actor_foot", player) - root.call("_actor_foot", slime)
		var away_distance_squared := away_delta.length_squared()
		if not away_delta.is_finite() or not is_finite(away_distance_squared) or away_distance_squared <= 0.0001:
			continue
		var away := away_delta.normalized()
		if not away.is_finite():
			continue
		var inward := maxf(-movement.normalized().dot(-away), 0.0)
		var retained := 0.2 if _uses_body_contact(slime) else 0.78
		var normal_part := away * movement.dot(away)
		var tangent_part := movement - normal_part
		result = tangent_part * 0.9 + normal_part * lerpf(1.0, retained, inward)
	return result


func _uses_body_contact(actor: Sprite2D) -> bool:
	return actor != null and float(actor.get_meta("encounter_scale", 1.0)) > 1.0


func _player_occupies_active_doorway(root: GameplayState) -> bool:
	var state := root as GameplayState
	var room_controller := state.room_controller if state != null else null
	var player := state.player if state != null else null
	if state == null or room_controller == null or player == null or state.dungeon_graph == null or state.room_transition_locked:
		return false
	var feet := room_controller._player_door_feet_rect(state, player)
	for socket_id in room_controller.dungeon_sockets:
		var socket := room_controller.dungeon_sockets.get(socket_id) as DungeonSocket
		var is_entrance := room_controller.active_entrance_sockets.has(socket_id)
		if socket == null or (not is_entrance and not room_controller.active_door_sockets.has(socket_id)):
			continue
		var connection := state.dungeon_graph.get_connection_for_entry(state.current_room_id, socket_id) if is_entrance else state.dungeon_graph.get_connection(state.current_room_id, socket_id)
		if connection == null or not state._map_connection_available(connection, is_entrance):
			continue
		if room_controller._rect_touches_polygon(feet, room_controller._socket_trigger_polygon(socket)):
			return true
	return false


func _rect_overlap_push_vector(root: GameplayState, actor: Sprite2D, other: Sprite2D) -> Vector2:
	var rect := root.call("_collision_rect", actor) as Rect2
	var other_rect := root.call("_collision_rect", other) as Rect2
	return _rect_contact_push_vector(rect, other_rect)


func _rect_contact_push_vector(rect: Rect2, other_rect: Rect2) -> Vector2:
	var overlap := rect.intersection(other_rect)
	if not overlap.has_area():
		return Vector2.ZERO
	var actor_center := rect.get_center()
	var other_center := other_rect.get_center()
	if overlap.size.x < overlap.size.y:
		return Vector2(-overlap.size.x if actor_center.x < other_center.x else overlap.size.x, 0.0)
	return Vector2(0.0, -overlap.size.y if actor_center.y < other_center.y else overlap.size.y)


func actor_contact_radius(root: GameplayState, actor: Sprite2D) -> float:
	var chest := root.get("chest") as Sprite2D
	var guide: Rect2 = root.call("_collision_guide_rect_by_name", actor, "CollisionGuide")
	return ActorGeometry.contact_radius(actor, chest, guide, 3.6)
