extends Resource
class_name ItemCatalogData

## Editor-inspectable item definition data. ItemCatalog loads this resource so
## the authored gear definitions live in .tres data instead of code dictionaries,
## while the instance API stays unchanged.

@export var live_base_ids: Array[StringName] = []
@export var live_base_definitions: Dictionary = {}
@export var set_definitions: Dictionary = {}
@export var definitions: Dictionary = {}
@export var definition_metadata: Dictionary = {}
@export var transmutations: Dictionary = {}