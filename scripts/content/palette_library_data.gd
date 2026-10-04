@tool
extends Resource
class_name PaletteLibraryData

## Editor-inspectable palette color tables. PaletteLibrary keeps its static
## lookup API over this resource; the authored colors live here so the editor
## can inspect and retune presentation tones.

@export var palette_names: Array[String] = []
@export var selectable_palettes: Array[String] = []
@export var rest_fire_palettes: Array[String] = []
@export var shadow: Dictionary = {}
@export var normal: Dictionary = {}
@export var accent: Dictionary = {}
@export var archetype_highlights: Array[Color] = []
@export var white: Color = Color.WHITE
