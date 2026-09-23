@tool
extends Resource
class_name ElementCatalogData

## Editor-inspectable element lookup tables. The stable Element enum and
## matchup policy stay in element_catalog.gd; the id/name/palette lookups are
## authored here so the editor can inspect and tune presentation keys.

@export var ids: Dictionary = {}
@export var display_names: Dictionary = {}
@export var palette_keys: Dictionary = {}
@export var matchup_table: Array = []
@export var damage_number_color_boost := 1.10
@export var default_element := 0
@export var element_count := 8
