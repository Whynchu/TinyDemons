extends Node
class_name HealthComponent

## Reusable health lifecycle boundary for actors.
## Gameplay owns presentation and combat formulas; this node owns health state.

signal health_changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

@export var maximum_health: float = 1.0
@export var regen_delay: float = 0.0
@export var regen_interval: float = 1.0
@export var regen_amount: float = 0.0

var current_health: float = 0.0
var regen_delay_timer: float = 0.0
var regen_accumulator: float = 0.0
var _dead := false


func _ready() -> void:
	reset()


func _process(delta: float) -> void:
	tick_regeneration(delta)


func reset(value: float = -1.0) -> void:
	current_health = maximum_health if value < 0.0 else clampf(value, 0.0, maximum_health)
	regen_delay_timer = 0.0
	regen_accumulator = 0.0
	_dead = current_health <= 0.0
	health_changed.emit(current_health, maximum_health)


func set_maximum_health(value: float, preserve_ratio := true) -> void:
	var ratio: float = current_health / maximum_health if maximum_health > 0.0 else 1.0
	maximum_health = maxf(value, 1.0)
	current_health = clampf(maximum_health * ratio if preserve_ratio else current_health, 0.0, maximum_health)
	health_changed.emit(current_health, maximum_health)


func apply_damage(amount: float) -> float:
	var applied: float = minf(maxf(amount, 0.0), current_health)
	if applied <= 0.0:
		return 0.0
	current_health -= applied
	regen_delay_timer = regen_delay
	regen_accumulator = 0.0
	damaged.emit(applied)
	health_changed.emit(current_health, maximum_health)
	if current_health <= 0.0 and not _dead:
		_dead = true
		died.emit()
	return applied


func apply_healing(amount: float) -> float:
	var applied: float = minf(maxf(amount, 0.0), maximum_health - current_health)
	if applied <= 0.0:
		return 0.0
	current_health += applied
	_dead = false
	healed.emit(applied)
	health_changed.emit(current_health, maximum_health)
	return applied


func tick_regeneration(delta: float) -> float:
	if _dead or regen_amount <= 0.0 or current_health >= maximum_health:
		regen_accumulator = 0.0
		return 0.0
	regen_delay_timer = maxf(regen_delay_timer - delta, 0.0)
	if regen_delay_timer > 0.0:
		return 0.0
	regen_accumulator += delta
	var healed_total: float = 0.0
	while regen_accumulator >= regen_interval and current_health < maximum_health:
		regen_accumulator -= regen_interval
		healed_total += apply_healing(regen_amount)
	return healed_total


func is_dead() -> bool:
	return _dead
