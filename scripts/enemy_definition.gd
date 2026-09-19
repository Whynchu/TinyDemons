extends Resource
class_name EnemyDefinition

## Typed, editor-inspectable enemy content contract. Each definition is a view
## over one authored variant record in the SlimeVariantCatalogData resource, so
## the catalog stays the single source of truth while runtime assembly reads a
## typed contract instead of a raw dictionary. EnemyFactory assembles actors
## from these definitions.

@export var id: StringName = &""
@export var display_name := ""
@export var element := 0
@export var damage_contract: StringName = &"physical"
@export var base_stats: Dictionary = {}
@export var growth_weights: Dictionary = {}
## Artwork source name used to resolve direction/spawn/attack textures (for
## example "red" resolves to SlimeRed.png; recolor-only palettes reuse a base
## art sheet and recolor at runtime).
@export var visual_source := "green"


static func from_variant(variant: StringName) -> EnemyDefinition:
	var catalog := preload("res://scripts/slime_variant_catalog.gd")
	var raw := catalog.definition(variant)
	var definition := EnemyDefinition.new()
	definition.id = StringName(str(raw.get("variant", String(variant))))
	definition.display_name = str(raw.get("display_name", String(variant)))
	definition.element = int(raw.get("element", 0))
	definition.damage_contract = StringName(str(raw.get("damage_contract", "physical")))
	definition.base_stats = (raw.get("base_stats", {}) as Dictionary).duplicate(true)
	definition.growth_weights = (raw.get("growth_weights", {}) as Dictionary).duplicate(true)
	# Recolor-only palettes share the green base art sheet and are tinted at
	# runtime; only art-sheet variants (red/blue/green) and explicit overrides
	# (crimson -> red) name a distinct source.
	var raw_source := str(raw.get("visual_source", ""))
	if raw_source.is_empty():
		raw_source = "green" if String(variant) in ["grey", "purple", "yellow", "orange", "aquamarine"] else String(variant)
	definition.visual_source = raw_source
	return definition


func to_record() -> Dictionary:
	return {
		"variant": id,
		"display_name": display_name,
		"element": element,
		"damage_contract": damage_contract,
		"base_stats": base_stats.duplicate(true),
		"growth_weights": growth_weights.duplicate(true),
		"visual_source": visual_source,
	}