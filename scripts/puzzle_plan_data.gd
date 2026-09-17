extends Resource
class_name PuzzlePlanData

## Editor-inspectable authored route-map plan. Each puzzle map builder loads its
## marker grid from a .tres resource; runtime transforms (rotation, validation
## variants) stay in the builder code. Markers are stored as {coordinate: Vector2i,
## kind: StringName} dictionaries so the editor can inspect the authored plan.

@export var plan_id: StringName = &""
@export var markers: Array[Dictionary] = []
@export var active_tiles: Array[Vector2i] = []
@export var generation_mode: StringName = &""
@export var logical_edges: Array[Dictionary] = []