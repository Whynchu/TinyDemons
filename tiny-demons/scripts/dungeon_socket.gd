@tool
class_name DungeonSocket
extends Node2D

enum SocketKind {
	WALL_LEFT,
	WALL_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT,
}

@export var socket_kind: SocketKind = SocketKind.WALL_RIGHT
@export var paired_socket_id: StringName = &"BOTTOM_LEFT"
@export var inward_facing := Vector2.RIGHT
@export_node_path("CanvasItem") var visual_path: NodePath
@export_node_path("Polygon2D") var trigger_path: NodePath
@export_node_path("Marker2D") var spawn_marker_path: NodePath
@export var block_tile_paths: Array[NodePath] = []


func socket_id() -> StringName:
	return StringName(SocketKind.keys()[socket_kind])


func visual() -> CanvasItem:
	return get_node_or_null(visual_path) as CanvasItem


func trigger() -> Polygon2D:
	return get_node_or_null(trigger_path) as Polygon2D


func spawn_marker() -> Marker2D:
	return get_node_or_null(spawn_marker_path) as Marker2D


func block_tiles() -> Array[Sprite2D]:
	var tiles: Array[Sprite2D] = []
	for tile_path in block_tile_paths:
		var tile := get_node_or_null(tile_path) as Sprite2D
		if tile != null:
			tiles.append(tile)
	return tiles
