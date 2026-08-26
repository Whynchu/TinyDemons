extends RefCounted
class_name HubProgressionDraft

## Ephemeral hub-only edits. The profile remains the durable owner; this object
## is discarded or reset when the hub transaction is cancelled/applied.
var vit := 0
var str := 0
var def := 0
var spd := 0

func clear() -> void:
	vit = 0
	str = 0
	def = 0
	spd = 0

func as_dictionary() -> Dictionary:
	return {"VIT": vit, "STR": str, "DEF": def, "SPD": spd}
