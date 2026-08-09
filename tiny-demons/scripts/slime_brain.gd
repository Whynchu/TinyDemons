extends Node
class_name SlimeBrain

## Decision-state boundary for slime actors.
## Movement and collision remain coordinated by gameplay during migration.

var aggroed := false
var holding := false
var repath_timer := 0.0
var hold_timer := 0.0
var attack_cooldown := 0.0
var target := Vector2.ZERO
var scoot_start := Vector2.ZERO
var scoot_target := Vector2.ZERO
var scoot_timer := 0.0
var persistent_aggro := false
var start_position := Vector2.ZERO
var idle_breath_timer := 0.0


func tick(delta: float) -> void:
	repath_timer = maxf(repath_timer - delta, 0.0)
	hold_timer = maxf(hold_timer - delta, 0.0)
	attack_cooldown = maxf(attack_cooldown - delta, 0.0)


func set_aggro(value: bool) -> void:
	aggroed = value


func begin_hold(duration: float) -> void:
	holding = true
	hold_timer = maxf(duration, 0.0)


func can_attack() -> bool:
	return aggroed and not holding and attack_cooldown <= 0.0


func start_attack(cooldown: float) -> void:
	attack_cooldown = maxf(cooldown, 0.0)


func needs_repath() -> bool:
	return repath_timer <= 0.0


func schedule_repath(delay: float) -> void:
	repath_timer = maxf(delay, 0.0)
