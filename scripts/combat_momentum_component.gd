class_name CombatMomentumComponent
extends RefCounted

var focus_timer := 0.0
var focus_active := false
var combo_count := 0
var combo_timer := 0.0

var focus_window := 2.5
var focus_bonus := 0.30
var focus_penalty := -0.20
var combo_hit_window := 1.5
var combo_damage_per_hit := 0.05
var combo_damage_cap := 0.25
## Optional safety/tuning limit. Zero means the streak continues for every
## confirmed hit until combo_hit_window expires; it does not affect the
## separately bounded combo damage multiplier.
var combo_max_steps := 0


func configure(tuning: PlayerTuning) -> void:
	focus_window = tuning.focus_window
	focus_bonus = tuning.focus_bonus
	focus_penalty = tuning.focus_penalty
	combo_hit_window = tuning.combo_hit_window
	combo_damage_per_hit = tuning.combo_damage_per_hit
	combo_damage_cap = tuning.combo_damage_cap
	combo_max_steps = tuning.combo_max_steps


func focus_multiplier(slime_is_target: bool) -> float:
	if not slime_is_target:
		return 1.0
	if focus_active and focus_timer > 0.0:
		return 1.0 + focus_bonus
	return 1.0 + focus_penalty


func combo_multiplier() -> float:
	return 1.0 + minf(float(combo_count) * combo_damage_per_hit, combo_damage_cap)


func on_target_changed(new_target_valid: bool) -> void:
	focus_timer = focus_window if new_target_valid else 0.0
	focus_active = new_target_valid


func register_hit() -> void:
	combo_count += 1
	if combo_max_steps > 0:
		combo_count = mini(combo_count, combo_max_steps)
	combo_timer = combo_hit_window


func reset_combo() -> void:
	combo_count = 0
	combo_timer = 0.0


func reset_all() -> void:
	focus_timer = 0.0
	focus_active = false
	reset_combo()


func tick(delta: float, target_valid: bool) -> void:
	if focus_active:
		if not target_valid:
			focus_active = false
		else:
			focus_timer = maxf(focus_timer - delta, 0.0)
			if focus_timer <= 0.0:
				focus_active = false
	if combo_count > 0:
		combo_timer = maxf(combo_timer - delta, 0.0)
		if combo_timer <= 0.0:
			combo_count = 0
