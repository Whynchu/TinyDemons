extends Resource
class_name SlimeVariantCatalogData

## Editor-inspectable slime variant definitions. The catalog class loads this
## resource so variant tuning is authored in .tres data instead of a code
## dictionary, while the static lookup API stays unchanged.

@export var order: Array[StringName] = []
@export var definitions: Dictionary = {}