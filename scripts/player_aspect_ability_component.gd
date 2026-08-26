extends Node
class_name PlayerAspectAbilityComponent

## Triangle execution boundary.
## Concrete ability behavior is supplied by the caller. This component owns
## acceptance, cooldown, ability-mode resolution, and Chroma payment timing.

signal ability_started(mode: int)
signal ability_rejected

const CHROMA_COMPONENT_SCRIPT = preload("res://scripts/player_chroma_component.gd")

var cooldown_duration := 0.0
var grey_cooldown_duration := 0.0
var cooldown_remaining := 0.0


func configure_cooldown(duration: float) -> void:
	cooldown_duration = maxf(duration, 0.0)
	grey_cooldown_duration = cooldown_duration


func configure_mode_cooldowns(elemental_duration: float, grey_duration: float) -> void:
	cooldown_duration = maxf(elemental_duration, 0.0)
	grey_cooldown_duration = maxf(grey_duration, 0.0)


func cooldown_duration_for_mode(mode: int) -> float:
	return cooldown_duration if mode == CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL else grey_cooldown_duration


func tick(delta: float) -> void:
	cooldown_remaining = maxf(cooldown_remaining - maxf(delta, 0.0), 0.0)


func can_activate(chroma: Node, blocked: bool = false) -> bool:
	if blocked or chroma == null or cooldown_remaining > 0.0:
		return false
	var mode: int = chroma.call("ability_mode")
	if mode == CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL:
		return bool(chroma.call("can_use_elemental_ability"))
	return true


func try_activate(chroma: Node, execute: Callable, blocked: bool = false) -> bool:
	if not can_activate(chroma, blocked):
		ability_rejected.emit()
		return false
	var mode: int = chroma.call("ability_mode")
	var result: Variant = execute.call(mode)
	if typeof(result) == TYPE_BOOL and not bool(result):
		ability_rejected.emit()
		return false
	if mode == CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL:
		if not bool(chroma.call("spend_elemental_ability")):
			ability_rejected.emit()
			return false
	cooldown_remaining = grey_cooldown_duration if mode != CHROMA_COMPONENT_SCRIPT.AbilityMode.ELEMENTAL else cooldown_duration
	emit_signal(&"ability_started", mode)
	return true
