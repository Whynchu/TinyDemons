extends Resource
class_name CombatTuning

@export var health_base := 8.0
@export var health_per_vit := 4.0
## Leveling grants stat points; it does not grant Core HP on its own.
## Kept as a tuning field for compatibility with existing inspector data.
@export var health_per_level := 0.0
@export var health_vit_core_rate := 0.03
@export var target_health_max := 10.0
@export var damage_base := 2.0
@export var damage_per_strength := 0.5
@export var enemy_damage_per_strength := 1.0
@export var defense_scale := 12.0
@export var magic_base := 2.0
@export var magic_per_int := 0.75
@export var magic_defense_scale := 12.0
@export var elemental_magic_bonus := 0.75
@export_group("Imbue composite")
## Imbue has its own magic package so it can be balanced independently of
## Triangle and elemental slime attacks.
@export var imbue_base := 1.0
@export var imbue_per_int := 0.50
@export_group("Imbue presentation")
## INT changes the readable intensity of the active Imbue effect only. It does
## not participate in the Imbue duration, cost, or cooldown contracts.
@export var imbue_visual_intelligence_reference := 1.0
@export var imbue_visual_intelligence_scale := 0.12
@export var imbue_visual_intensity_min := 0.75
@export var imbue_visual_intensity_max := 1.50
@export_group("Elemental slime composite")
## Non-neutral slimes keep a STR-primary body hit while adding a separate INT
## magic portion. These values are intentionally independent from Imbue.
@export var elemental_slime_physical_base := 1.5
@export var elemental_slime_physical_per_strength := 0.85
@export var elemental_slime_magic_base := 0.75
@export var elemental_slime_magic_per_int := 0.50
@export var knockback_strength_reference := 5.0
@export var knockback_per_strength := 0.04
@export var knockback_strength_min := 0.75
@export var knockback_strength_max := 1.50
@export_group("Damage roll")
@export var damage_roll_min := 0.85
@export var damage_roll_max := 1.15
@export var critical_hit_chance := 0.10
@export var critical_damage_multiplier := 1.5


func knockback_multiplier_for_strength(strength: float) -> float:
	return 1.0 + clampf((float(strength) - knockback_strength_reference) * knockback_per_strength, knockback_strength_min - 1.0, knockback_strength_max - 1.0)


func imbue_visual_intensity_for_intelligence(intelligence: float) -> float:
	return 1.0 + clampf((float(intelligence) - imbue_visual_intelligence_reference) * imbue_visual_intelligence_scale, imbue_visual_intensity_min - 1.0, imbue_visual_intensity_max - 1.0)
