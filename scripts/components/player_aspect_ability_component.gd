extends Node
class_name PlayerAspectAbilityComponent

## Triangle execution boundary.
## Concrete ability behavior is supplied by the caller. This component owns
## acceptance, cooldown, ability-mode resolution, and Chroma payment timing.

signal ability_started(mode: int)
signal ability_rejected

const CHROMA_COMPONENT_SCRIPT = preload("res://scripts/components/player_chroma_component.gd")

## Editor-facing default cooldown durations used when the caller does not
## provide explicit values via configure_mode_cooldowns.
@export var default_elemental_cooldown := 2.0
@export var default_grey_cooldown := 2.5

var cooldown_duration := 0.0
var grey_cooldown_duration := 0.0
var cooldown_remaining := 0.0
var active_cooldown_duration := 0.0


func configure_cooldown(duration: float = -1.0) -> void:
	cooldown_duration = maxf(default_elemental_cooldown if duration < 0.0 else duration, 0.0)
	grey_cooldown_duration = cooldown_duration


func configure_mode_cooldowns(elemental_duration: float = -1.0, grey_duration: float = -1.0) -> void:
	cooldown_duration = maxf(default_elemental_cooldown if elemental_duration < 0.0 else elemental_duration, 0.0)
	grey_cooldown_duration = maxf(default_grey_cooldown if grey_duration < 0.0 else grey_duration, 0.0)


func cooldown_duration_for_mode(mode: int) -> float:
	return cooldown_duration if mode == CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL else grey_cooldown_duration


func tick(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)


func can_activate(chroma: Node, blocked: bool = false, elemental_cost: int = -1) -> bool:
	if blocked or chroma == null or cooldown_remaining > 0.0:
		return false
	var mode := _activation_mode(chroma, elemental_cost)
	if mode == CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL:
		return bool(chroma.call("can_use_elemental_ability", _resolved_elemental_cost(chroma, elemental_cost)))
	# The neutral stub costs nothing, but still requires a positive Chroma bar.
	# Elemental forms use their own cost gate above, so a cast at exactly its
	# cost can spend the bar down to zero.
	return int(chroma.get("current_chroma")) > 0


func try_activate(chroma: Node, execute: Callable, blocked: bool = false, elemental_cost: int = -1, elemental_cooldown: float = -1.0, grey_cooldown: float = -1.0) -> bool:
	if not can_activate(chroma, blocked, elemental_cost):
		ability_rejected.emit()
		return false
	var mode := _activation_mode(chroma, elemental_cost)
	var result: Variant = execute.call(mode)
	if typeof(result) == TYPE_BOOL and not bool(result):
		ability_rejected.emit()
		return false
	if mode == CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL:
		if not bool(chroma.call("spend_elemental_ability", _resolved_elemental_cost(chroma, elemental_cost))):
			ability_rejected.emit()
			return false
	if mode == CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL and elemental_cooldown >= 0.0:
		active_cooldown_duration = maxf(elemental_cooldown, 0.0)
	elif mode == CHROMA_COMPONENT_SCRIPT.AbilityMode.GRAY and grey_cooldown >= 0.0:
		active_cooldown_duration = maxf(grey_cooldown, 0.0)
	else:
		active_cooldown_duration = cooldown_duration_for_mode(mode)
	cooldown_remaining = active_cooldown_duration
	emit_signal(&"ability_started", mode)
	return true


func _resolved_elemental_cost(chroma: Node, elemental_cost: int) -> int:
	if elemental_cost >= 0:
		return elemental_cost
	return int(chroma.get("elemental_ability_cost"))


func _activation_mode(chroma: Node, elemental_cost: int) -> int:
	var mode := int(chroma.call("ability_mode"))
	if elemental_cost >= 0:
		var has_elemental_identity := int(chroma.get("current_aspect")) != CHROMA_COMPONENT_SCRIPT.Aspect.NONE or int(chroma.get("bound_aspect")) != CHROMA_COMPONENT_SCRIPT.Aspect.NONE
		if has_elemental_identity:
			# Keep Triangle bound to the same form at every Chroma level. If its
			# cost is unaffordable, can_activate rejects it instead of swapping to
			# the neutral stub.
			return CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL
		return CHROMA_COMPONENT_SCRIPT.AbilityMode.GRAY
	return mode
