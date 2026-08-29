extends Resource
class_name PlayerTuning

@export var speed := 36.0
## Hold-to-run movement speed reached by continuing to hold the roll button
## after a roll dodge. Almost as fast as rolling (roll_distance / roll_duration).
@export var run_speed := 64.8
@export var agi_reference := 1.0
@export var speed_scale := 0.012
@export var roll_scale := 0.015
@export var attack_scale := 0.010
@export var speed_effect_min := -0.5
@export var speed_effect_max := 1.0


func speed_multiplier(spd: float) -> float:
	return 1.0 + clampf(float(spd) * speed_scale, speed_effect_min, speed_effect_max)


func agi_multiplier(agi: float) -> float:
	return 1.0 + clampf((float(agi) - agi_reference) * speed_scale, speed_effect_min, speed_effect_max)


func roll_multiplier(spd: float) -> float:
	return 1.0 + clampf(float(spd) * roll_scale, speed_effect_min, speed_effect_max)


func roll_multiplier_for_agi(agi: float) -> float:
	return 1.0 + clampf((float(agi) - agi_reference) * roll_scale, speed_effect_min, speed_effect_max)


func attack_multiplier(spd: float) -> float:
	return 1.0 + clampf(float(spd) * attack_scale, speed_effect_min, speed_effect_max)


func attack_multiplier_for_agi(agi: float) -> float:
	return 1.0 + clampf((float(agi) - agi_reference) * attack_scale, speed_effect_min, speed_effect_max)


func charge_multiplier_for_agi(agi: float) -> float:
	# Charging uses the safe action/recovery scale. Keeping this as a named
	# helper makes the charge contract explicit without introducing a second AGI
	# curve that could drift away from attack timing.
	return attack_multiplier_for_agi(agi)
@export var hit_flash_time := 0.12
@export var hitstun_time := 1.0 / 30.0
@export var hit_knockback := 10.0
@export var hit_knockback_duration := 0.12
@export var idle_frame_time := 0.22
@export var walk_frame_time := 0.18
@export var run_frame_time := 0.10
@export var attack_frame_time := 0.09
@export var attack2_hit_frame := 2
@export var attack_hit_frame := 2
@export var combo_window := 0.18
@export var between_attack_time := 0.12
@export var attack2_cooldown := 0.16
@export_group("Spin attack")
@export var spin_circle_min_magnitude := 0.55
@export var spin_circle_max_duration := 0.50
@export var spin_circle_required_turn := TAU * 0.80
@export var spin_circle_arm_duration := 0.28
@export var spin_frame_time := 0.075
@export var spin_recovery_frame_time := 0.14
@export var spin_recovery_start_frame := 6
@export var spin_hit_start_frame := 3
@export var spin_hit_end_frame := 6
## Spin trades single-target power for reliable area coverage. It is deliberately
## below a normal Attack 1, but it does not use the normal multi-target split.
@export var spin_damage_multiplier := 0.90
@export var spin_knockback_multiplier := 1.10
@export_group("Charge attack")
@export var charge_minimum_time := 0.35
@export var charge_maximum_time := 1.00
@export var charged_attack2_frame_time_multiplier := 1.35
@export var charged_attack2_damage_multiplier := 1.60
@export var charged_attack2_knockback_multiplier := 1.50
@export var roll_frame_time := 0.05
@export var roll_distance := 24.3
@export var roll_duration := 0.30
@export var death_particle_lifetime := 1.8
@export var death_fade_time := 0.7
@export var death_particle_delay := 0.7
@export var hitstop_duration := 1.0 / 40.0
@export var death_observe_time := 1.4
@export var attack_lunge_distance := 6.0
@export var attack_lunge_duration := 0.18
@export var attack_knockback := 16.0
@export var attack1_knockback_multiplier := 0.60
@export var attack2_damage_multiplier := 1.25
@export var attack2_multi_target_damage_multiplier := 1.10
@export var regen_delay := 2.0
@export var regen_interval := 1.0
@export var regen_amount := 1.0
@export var health_damage_hang_time := 0.14
@export var focus_window := 2.5
@export var focus_bonus := 0.30
@export var focus_penalty := -0.20
@export var combo_hit_window := 1.5
@export var combo_damage_per_hit := 0.05
@export var combo_damage_cap := 0.25
@export var combo_max_steps := 5
