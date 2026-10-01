@tool
extends Resource
class_name StatusEffectDefinition

enum Family {
	DAMAGE_OVER_TIME,
	MOVEMENT_SLOW,
	PERIODIC_STUN,
	DAMAGE_AMPLIFICATION,
}

const STATUS_IDS: Array[StringName] = [&"burn", &"poison", &"slow", &"stun"]
const AUXILIARY_STATUS_IDS: Array[StringName] = [&"hex_mark"]
const PARTICLE_STYLES: Array[StringName] = [&"ember", &"poison_mote", &"electric_spark", &"frost_crystal"]

@export var id: StringName = &""
@export_range(1, 7, 1) var element := 1
@export_enum("Damage over time", "Movement slow", "Periodic stun", "Damage amplification") var family: int = Family.DAMAGE_OVER_TIME
@export_range(0.0, 1.0, 0.01) var proc_chance := 0.2
@export_range(0.05, 30.0, 0.05) var duration := 2.5
@export_range(1, 10, 1) var maximum_stacks := 3
@export_range(0.0, 100.0, 0.1) var magnitude_per_stack := 1.0
@export_range(0.1, 1.0, 0.01) var movement_multiplier_floor := 0.55
@export_range(0.05, 10.0, 0.05) var tick_interval := 1.0
@export_range(0.05, 10.0, 0.05) var stun_interval := 1.0
@export_range(0.0, 2.0, 0.01) var stun_interval_reduction_per_extra_stack := 0.05
@export_range(0.05, 10.0, 0.05) var stun_interval_floor := 0.5
@export_range(0.01, 2.0, 0.01) var stun_lock_duration := 0.12
@export var badge_glyph := "?"
@export var particle_style: StringName = &"ember"
@export_range(0.02, 1.0, 0.01) var particle_interval := 0.12


func validate() -> Array[String]:
	var problems: Array[String] = []
	if not STATUS_IDS.has(id) and not AUXILIARY_STATUS_IDS.has(id):
		problems.append("status id '%s' is not registered" % String(id))
	if element < 1 or element > 7:
		problems.append("status element must be a non-neutral element")
	if family < Family.DAMAGE_OVER_TIME or family > Family.DAMAGE_AMPLIFICATION:
		problems.append("status family is invalid")
	if proc_chance < 0.0 or proc_chance > 1.0:
		problems.append("proc chance must be between 0 and 1")
	if duration <= 0.0:
		problems.append("duration must be positive")
	if maximum_stacks < 1:
		problems.append("maximum_stacks must be at least 1")
	if magnitude_per_stack < 0.0:
		problems.append("magnitude_per_stack must be non-negative")
	if movement_multiplier_floor <= 0.0 or movement_multiplier_floor > 1.0:
		problems.append("movement_multiplier_floor must be between 0 and 1")
	if family == Family.DAMAGE_OVER_TIME and tick_interval <= 0.0:
		problems.append("damage-over-time statuses need a positive tick_interval")
	if family == Family.PERIODIC_STUN:
		if stun_interval <= 0.0 or stun_interval_floor <= 0.0:
			problems.append("periodic stun cadence and floor must be positive")
		if stun_lock_duration <= 0.0:
			problems.append("stun_lock_duration must be positive")
	if badge_glyph.is_empty():
		problems.append("badge_glyph must not be empty")
	if not PARTICLE_STYLES.has(particle_style):
		problems.append("particle_style '%s' is not registered" % String(particle_style))
	if particle_interval <= 0.0:
		problems.append("particle_interval must be positive")
	return problems


func tick_interval_for(_stacks: int) -> float:
	return maxf(tick_interval, 0.05)


func stun_interval_for(stacks: int) -> float:
	var reductions := maxi(stacks - 1, 0)
	return maxf(stun_interval_floor, stun_interval - float(reductions) * stun_interval_reduction_per_extra_stack)
