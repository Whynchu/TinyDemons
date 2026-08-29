extends RefCounted
class_name HubProgressionDraft

## Ephemeral hub-only edits. The profile remains the durable owner; this object
## is discarded or reset when the hub transaction is cancelled/applied.
var vit := 0
var strength := 0
var def := 0
var agi := 0
var intelligence := 0
var mnd := 0

## Temporary compatibility alias for the pre-AGI hub code.
var spd:
	get:
		return agi
	set(value):
		agi = maxi(int(value), 0)

func clear() -> void:
	vit = 0
	strength = 0
	def = 0
	agi = 0
	intelligence = 0
	mnd = 0

func as_dictionary() -> Dictionary:
	return {
		"VIT": vit,
		"STR": strength,
		"DEF": def,
		"AGI": agi,
		"INT": intelligence,
		"MND": mnd,
		"SPD": agi,
	}
