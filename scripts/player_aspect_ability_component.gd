extends Node
class_name PlayerAspectAbilityComponent

## Triangle execution boundary.
## Concrete ability behavior is supplied by the caller. This component owns
## acceptance, cooldown, ability-mode resolution, and Chroma payment timing.

signal ability_started(mode: int)
signal ability_rejected

const CHROMA_COMPONENT_SCRIPT = preload("res://scripts/player_chroma_component.gd")

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


func can_activate(chroma: Node, blocked: bool = false) -> bool:
	if blocked or chroma == null or cooldown_remaining > 0.0:
		return false
	# Magic always requires Chroma: at zero the player cannot cast even the
	# gray baseline triangle. The elemental branch keeps its own cost gate.
	if int(chroma.get("current_chroma")) <= 0:
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
	active_cooldown_duration = cooldown_duration_for_mode(mode)
	cooldown_remaining = active_cooldown_duration
	emit_signal(&"ability_started", mode)
	return true
