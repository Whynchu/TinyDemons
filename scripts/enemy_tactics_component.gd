extends Node
class_name EnemyTacticsComponent

## Generic per-enemy tactical state. Encounter rules stay outside the actor.

@export var approach_spacing := 9.0
var attack_reserved := false
var recent_attack_timer := 0.0
var formation_slot := 0


func tick(delta: float) -> void:
	recent_attack_timer = maxf(recent_attack_timer - delta, 0.0)


func request_attack_slot(active_attackers: int, maximum_attackers: int) -> bool:
	if attack_reserved or active_attackers >= maximum_attackers:
		return false
	attack_reserved = true
	return true


func release_attack_slot() -> void:
	attack_reserved = false
	recent_attack_timer = 0.18


func reset() -> void:
	attack_reserved = false
	recent_attack_timer = 0.0
	formation_slot = 0


func set_formation_slot(slot: int) -> void:
	formation_slot = clampi(slot, -1, 1)


func approach_offset(to_player: Vector2) -> Vector2:
	if formation_slot == 0 or to_player.length_squared() < 0.01:
		return Vector2.ZERO
	var perpendicular := Vector2(-to_player.y, to_player.x).normalized()
	return perpendicular * float(formation_slot) * approach_spacing
