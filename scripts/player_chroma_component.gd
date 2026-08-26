extends Node
class_name PlayerChromaComponent

const AspectCatalogScript = preload("res://scripts/aspect_catalog.gd")

## Runtime owner for the player's aspect identity and Chroma state.
## Triangle execution, HUD presentation, and visual desaturation are separate.

signal aspect_changed(aspect: Aspect)
signal bound_aspect_changed(aspect: Aspect)
signal chroma_changed(current: int, maximum: int)
signal ability_mode_changed(mode: AbilityMode)

enum Aspect {
	NONE,
	FIRE,
	WATER,
	ELECTRIC,
	GRASS,
	SHADOW,
	GROUND,
	ICE,
}

enum AbilityMode {
	GRAY,
	ELEMENTAL,
	BOUND_WEAKENED,
}

const MAX_CHROMA := 100
const CHROMA_PICKUP_VALUE := 20
const ELEMENTAL_ABILITY_COST := 10

var current_aspect: Aspect = Aspect.NONE
var current_chroma := 0
# The permanent identity is deliberately separate from current_aspect. A
# fusion may change the current element without changing this value.
var bound_aspect: Aspect = Aspect.NONE
# Compatibility surface for older callers. It mirrors whether a bound aspect
# exists; current_is_bound() handles the more precise current/bound question.
var binding_active := false


func begin_new_run() -> void:
	_set_aspect(Aspect.NONE)
	_sync_binding_state()
	_set_chroma(0)


func attune(aspect: Aspect) -> bool:
	if not _is_valid_elemental_aspect(aspect):
		return false
	_set_aspect(aspect)
	_set_chroma(MAX_CHROMA)
	return true


func attune_flame(flame: StringName) -> bool:
	var aspect := aspect_for_flame(flame)
	return attune(aspect) if aspect != Aspect.NONE else false


func change_flame(flame: StringName) -> bool:
	var next_aspect := aspect_for_flame(flame)
	if next_aspect == Aspect.NONE:
		return false
	_set_aspect(next_aspect)
	return true


func refill_chroma() -> bool:
	if current_aspect == Aspect.NONE and bound_aspect != Aspect.NONE:
		_set_aspect(bound_aspect)
	if current_aspect == Aspect.NONE or current_chroma >= MAX_CHROMA:
		return false
	_set_chroma(MAX_CHROMA)
	return true


func restore_neutral_chroma(_value: int = CHROMA_PICKUP_VALUE) -> bool:
	# A dormant bound identity can be recovered by a neutral pickup. Gray with
	# no permanent identity still cannot store Chroma.
	if current_aspect == Aspect.NONE and bound_aspect != Aspect.NONE:
		_set_aspect(bound_aspect)
	if current_aspect == Aspect.NONE:
		return false
	if current_chroma >= MAX_CHROMA:
		return false
	_set_chroma(mini(current_chroma + CHROMA_PICKUP_VALUE, MAX_CHROMA))
	return true


func can_use_elemental_ability() -> bool:
	return current_aspect != Aspect.NONE and current_chroma >= ELEMENTAL_ABILITY_COST


func spend_elemental_ability() -> bool:
	if not can_use_elemental_ability():
		return false
	return spend_chroma(ELEMENTAL_ABILITY_COST)


func can_spend_chroma(amount: int) -> bool:
	return amount > 0 and current_chroma >= amount


func spend_chroma(amount: int) -> bool:
	if not can_spend_chroma(amount):
		return false
	_set_chroma(current_chroma - amount)
	if current_chroma == 0:
		# A temporary fusion is useful while charged. Once it is depleted, return
		# to the permanent identity when one exists; otherwise resolve Gray.
		if bound_aspect != Aspect.NONE and current_aspect != bound_aspect:
			_set_aspect(bound_aspect)
		elif bound_aspect == Aspect.NONE:
			_set_aspect(Aspect.NONE)
	return true


func set_binding_active(active: bool) -> void:
	# Legacy callers used this to mark the currently attuned aspect as bound.
	# Preserve that behavior while routing new code through bound_aspect.
	if active and current_aspect != Aspect.NONE:
		set_bound_aspect(current_aspect)
	elif not active:
		clear_bound_aspect()


func set_bound_aspect(aspect: Aspect) -> bool:
	if aspect != Aspect.NONE and not _is_valid_elemental_aspect(aspect):
		return false
	if bound_aspect == aspect:
		_sync_binding_state()
		return true
	var previous_mode := ability_mode()
	bound_aspect = aspect
	_sync_binding_state()
	bound_aspect_changed.emit(bound_aspect)
	var next_mode := ability_mode()
	if previous_mode != next_mode:
		ability_mode_changed.emit(next_mode)
	return true


func set_bound_flame(flame: StringName) -> bool:
	var aspect := aspect_for_flame(flame)
	return set_bound_aspect(aspect)


func clear_bound_aspect() -> void:
	set_bound_aspect(Aspect.NONE)


func has_bound_aspect() -> bool:
	return bound_aspect != Aspect.NONE


func current_is_bound() -> bool:
	return current_aspect != Aspect.NONE and current_aspect == bound_aspect


func aspect_for_flame(flame: StringName) -> Aspect:
	match flame:
		&"fire": return Aspect.FIRE
		&"water": return Aspect.WATER
		&"electric": return Aspect.ELECTRIC
		&"grass": return Aspect.GRASS
		&"shadow": return Aspect.SHADOW
		&"ground": return Aspect.GROUND
		&"ice": return Aspect.ICE
	return Aspect.NONE


func ability_mode() -> AbilityMode:
	if current_aspect == Aspect.NONE:
		return AbilityMode.GRAY
	if current_chroma >= ELEMENTAL_ABILITY_COST:
		return AbilityMode.ELEMENTAL
	if current_is_bound() and current_chroma == 0:
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
		Aspect.GRASS:
			return &"grass"
		Aspect.SHADOW:
			return &"shadow"
		Aspect.GROUND:
			return &"ground"
		Aspect.ICE:
			return &"ice"
	return &"gray"


func bound_aspect_name() -> StringName:
	match bound_aspect:
		Aspect.FIRE: return &"fire"
		Aspect.WATER: return &"water"
		Aspect.ELECTRIC: return &"electric"
		Aspect.GRASS: return &"grass"
		Aspect.SHADOW: return &"shadow"
		Aspect.GROUND: return &"ground"
		Aspect.ICE: return &"ice"
	return &"gray"


func _is_valid_elemental_aspect(aspect: Aspect) -> bool:
	return aspect > Aspect.NONE and aspect <= Aspect.ICE


func _sync_binding_state() -> void:
	binding_active = bound_aspect != Aspect.NONE


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
	# Triangle spends are 10-point actions while neutral pickups restore 20, so
	# Chroma intentionally is not restricted to the old 25-point grid.
	if current_chroma == clamped:
		return
	var previous_mode := ability_mode()
	current_chroma = clamped
	chroma_changed.emit(current_chroma, MAX_CHROMA)
	var next_mode := ability_mode()
	if previous_mode != next_mode:
		ability_mode_changed.emit(next_mode)
