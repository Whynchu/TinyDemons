extends Node
class_name SlimeHealthPresenter

var display_health := 0.0
var damage_fill_hold_timer := 0.0


func update(delta: float, health: HealthComponent, max_health: float, tuning: SlimeTuning, in_combat: bool = false) -> void:
	if health == null:
		return
	var previous_health := health.current_health
	# HealthComponent owns regeneration in its process loop. The presenter only
	# animates the displayed value; ticking here as well caused slimes to heal
	# twice as quickly. Keep the regen delay alive while the slime is aggroed so
	# recovery cannot begin until the encounter is actually over.
	if in_combat:
		health.regen_delay_timer = maxf(health.regen_delay_timer, health.regen_interval + delta)
	var current := health.current_health
	if current > previous_health:
		display_health = minf(display_health, previous_health)
	if is_equal_approx(display_health, current):
		return
	var goal := current
	# Bar speeds are %-relative: they scale with max HP so every bar drains and
	# refills at the same visual rate regardless of how large the pool is.
	var speed := tuning.health_regen_fill_speed * (max_health / 100.0)
	if display_health > current:
		damage_fill_hold_timer = maxf(damage_fill_hold_timer - delta, 0.0)
		if damage_fill_hold_timer <= 0.0:
			goal = maxf(current, ceilf(display_health) - 1.0)
			speed = tuning.health_drain_fill_speed * (max_health / 100.0)
	else:
		goal = minf(current, floorf(display_health) + 1.0)
	display_health = move_toward(display_health, goal, speed * delta)
