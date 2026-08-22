extends Node
class_name PlayerChromaComponent

## Runtime owner for the player's aspect identity and quantized Chroma state.
## Triangle execution, HUD presentation, and visual desaturation are separate.

signal aspect_changed(aspect: Aspect)
signal chroma_changed(current: int, maximum: int)
signal ability_mode_changed(mode: AbilityMode)

enum Aspect {
	NONE,
	FIRE,
	WATER,
	ELECTRIC,
}

enum AbilityMode {
	GRAY,
	ELEMENTAL,
	BOUND_WEAKENED,
}

const MAX_CHROMA := 100
const CHROMA_STEP := 25
const ELEMENTAL_ABILITY_COST := 25

var current_aspect: Aspect = Aspect.NONE
var current_chroma := 0
var binding_active := false


func begin_new_run() -> void:
	_set_aspect(Aspect.NONE)
	binding_active = false
	_set_chroma(0)


func attune(aspect: Aspect) -> bool:
	if aspect == Aspect.NONE:
		return false
	_set_aspect(aspect)
	_set_chroma(MAX_CHROMA)
	return true


func attune_flame(flame: StringName) -> bool:
	match flame:
		&"fire":
			return attune(Aspect.FIRE)
		&"water":
			return attune(Aspect.WATER)
		&"electric":
			return attune(Aspect.ELECTRIC)
	return false


func restore_neutral_chroma(_value: int = CHROMA_STEP) -> bool:
	# Gray cannot store Chroma. The pickup is consumed by the caller, but this
	# state owner reports that no restoration occurred.
	if current_aspect == Aspect.NONE:
		return false
	if current_chroma >= MAX_CHROMA:
		return false
	_set_chroma(mini(current_chroma + CHROMA_STEP, MAX_CHROMA))
	return true


func can_use_elemental_ability() -> bool:
	return current_aspect != Aspect.NONE and current_chroma >= ELEMENTAL_ABILITY_COST


func spend_elemental_ability() -> bool:
	if not can_use_elemental_ability():
		return false
	_set_chroma(current_chroma - ELEMENTAL_ABILITY_COST)
	if current_chroma == 0 and not binding_active:
		_set_aspect(Aspect.NONE)
	return true


func set_binding_active(active: bool) -> void:
	if binding_active == active:
		return
	binding_active = active
	emit_signal(&"ability_mode_changed", ability_mode())


func ability_mode() -> AbilityMode:
	if current_aspect == Aspect.NONE:
		return AbilityMode.GRAY
	if current_chroma >= ELEMENTAL_ABILITY_COST:
		return AbilityMode.ELEMENTAL
	if binding_active and current_chroma == 0:
		return AbilityMode.BOUND_WEAKENED
	return AbilityMode.GRAY


func aspect_name() -> StringName:
	match current_aspect:
		Aspect.FIRE:
			return &"fire"
		Aspect.WATER:
			return &"water"
		Aspect.ELECTRIC:
			return &"electric"
	return &"gray"


func _set_aspect(next_aspect: Aspect) -> void:
	if current_aspect == next_aspect:
		return
	var previous_mode := ability_mode()
	current_aspect = next_aspect
	aspect_changed.emit(current_aspect)
	var next_mode := ability_mode()
	if previous_mode != next_mode:
		ability_mode_changed.emit(next_mode)


func _set_chroma(next_chroma: int) -> void:
	var clamped := clampi(next_chroma, 0, MAX_CHROMA)
	# All initial Chroma changes are charge-sized. Keeping the invariant here
	# prevents future callers from accidentally creating a 1–24 state.
	clamped = clamped - posmod(clamped, CHROMA_STEP)
	if current_chroma == clamped:
		return
	var previous_mode := ability_mode()
	current_chroma = clamped
	chroma_changed.emit(current_chroma, MAX_CHROMA)
	var next_mode := ability_mode()
	if previous_mode != next_mode:
		ability_mode_changed.emit(next_mode)
