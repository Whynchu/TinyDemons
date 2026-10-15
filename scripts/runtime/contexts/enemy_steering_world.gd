extends RefCounted
class_name EnemySteeringWorld

const ActorGeometryScript = preload("res://scripts/algorithms/actor_geometry.gd")
const SLIME_GEOMETRY_QUERIES_SCRIPT = preload("res://scripts/runtime/controllers/slime_geometry_queries.gd")

var player: Sprite2D
var collision_system: ActorCollisionSystem
var walkable_area: WalkableArea
var _geometry_queries: SlimeGeometryQueries = SLIME_GEOMETRY_QUERIES_SCRIPT.new() as SlimeGeometryQueries


func configure(new_player: Sprite2D, new_collision_system: ActorCollisionSystem, new_walkable_area: WalkableArea) -> void:
	player = new_player
	collision_system = new_collision_system
	walkable_area = new_walkable_area


func actor_foot(actor: Sprite2D) -> Vector2:
	return ActorGeometryScript.foot(actor, GameplayState.ACTOR_FOOT_OFFSET)


func collision_polygon(actor: Sprite2D, foot: Vector2) -> PackedVector2Array:
	return ActorGeometryScript.collision_polygon(actor, GameplayState.ACTOR_FOOT_OFFSET, foot)


func nearby_enemies(point: Vector2, radius: float) -> Array[Sprite2D]:
	if collision_system != null:
		return collision_system.slime_grid_candidates(point, radius)
	var empty: Array[Sprite2D] = []
	return empty


func is_defeated(actor: Sprite2D) -> bool:
	var enemy_actor := actor as EnemyActor
	if enemy_actor != null:
		return enemy_actor.is_defeated()
	var combat := actor.get_node_or_null("Combat") as SlimeCombatComponent
	return combat != null and combat.dead


func is_collision_rect_walkable_at(actor: Sprite2D, foot: Vector2) -> bool:
	return _geometry_queries.is_slime_collision_rect_walkable_at_area(walkable_area, actor, foot)


func is_walkable_point(point: Vector2) -> bool:
	return _geometry_queries.is_slime_walkable_point_in_area(walkable_area, point)
