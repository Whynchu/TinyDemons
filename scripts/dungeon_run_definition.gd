extends Resource
class_name DungeonRunDefinition

## Editor-inspectable authored run layout. Each run builder loads its
## room/connection data from a .tres resource; the flame-selection and rare
## enemy exception logic stays in the builder code. Room and connection entries
## are stored as dictionaries so the editor can inspect and tune the authored
## topology without changing runtime lookup code.

@export var layout_id: StringName = &""
@export var map_size := Vector2i(16, 23)
@export var rooms: Array[Dictionary] = []
@export var connections: Array[Dictionary] = []
@export var apply_rare_enemy_branch_entry_exceptions := false