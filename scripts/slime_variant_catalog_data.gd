extends Resource
class_name SlimeVariantCatalogData

## Editor-inspectable slime variant definitions. Each entry is an authored
## EnemyDefinition sub-resource so the catalog remains the single registry and
## the runtime never has to reconstruct a typed definition from a raw record.

@export var definitions: Array[Resource] = []


func validate() -> Array[String]:
	var problems: Array[String] = []
	if definitions.is_empty():
		problems.append("slime variant definitions are empty")
	var seen: Dictionary = {}
	for entry in definitions:
		var definition := entry as EnemyDefinition
		if definition == null:
			problems.append("slime variant catalog contains a non-EnemyDefinition entry")
			continue
		if seen.has(definition.id):
			problems.append("duplicate enemy definition id '%s'" % definition.id)
		seen[definition.id] = true
		for problem in definition.validate():
			problems.append("%s: %s" % [definition.id, problem])
	return problems
