@tool
extends Resource
class_name StatusEffectDefinition

enum Family {
	DAMAGE_OVER_TIME,
	MOVEMENT_SLOW,
	PERIODIC_STUN,
	DAMAGE_AMPLIFICATION,
	AMBIENT_MODIFIER,
	DAMAGE_VULNERABILITY,
	MOVEMENT_LOCK,
}

const STATUS_IDS: Array[StringName] = [&"burn", &"poison", &"chill", &"shocked", &"wet"]
const AUXILIARY_STATUS_IDS: Array[StringName] = [&"freeze"]
const CONTACT_TRANSMISSIBLE_STATUS_IDS: Array[StringName] = [&"wet", &"burn", &"chill", &"freeze", &"shocked"]
const PARTICLE_STYLES: Array[StringName] = [&"ember", &"poison_mote", &"electric_spark", &"frost_crystal", &"bubble", &"ice_shard"]

@export var id: StringName = &""
@export_range(1, 7, 1) var element := 1
@export_enum("Damage over time", "Movement slow", "Periodic stun", "Damage amplification", "Ambient modifier", "Damage vulnerability", "Movement lock") var family: int = Family.DAMAGE_OVER_TIME
@export_range(0.0, 1.0, 0.01) var proc_chance := 0.2
@export_range(0.05, 30.0, 0.05) var duration := 2.5
@export_range(1, 10, 1) var maximum_stacks := 3
@export_range(0.0, 100.0, 0.1) var magnitude_per_stack := 1.0
## DoT magnitude as a percent of the affected actor's maximum health per stack.
@export_range(0.0, 100.0, 0.1) var damage_percent_max_health_per_stack := 0.0
@export_range(0.1, 1.0, 0.01) var movement_multiplier_floor := 0.55
@export_range(0.05, 10.0, 0.05) var tick_interval := 1.0
@export_range(0.05, 10.0, 0.05) var stun_interval := 1.0
@export_range(0.0, 2.0, 0.01) var stun_interval_reduction_per_extra_stack := 0.05
@export_range(0.05, 10.0, 0.05) var stun_interval_floor := 0.5
@export_range(0.01, 2.0, 0.01) var stun_lock_duration := 0.2
@export_range(0.0, 100.0, 0.1) var periodic_damage_percent_max_health_per_stack := 0.0
@export_range(0.05, 10.0, 0.05) var periodic_damage_interval := 1.0
@export_range(0.0, 4.0, 0.05) var vulnerability_per_stack := 0.0
@export var badge_glyph := "?"
@export var badge_icon: Texture2D
@export var badge_icon_uses_element_palette := false
@export var particle_style: StringName = &"ember"
@export_range(0.02, 1.0, 0.01) var particle_interval := 0.12
@export_group("Ambient modifier")
## Element whose attacks are amplified while this effect is applied.
@export_range(0, 7, 1) var conducts_element := 0
@export_range(0.0, 4.0, 0.05) var conduct_damage_bonus_per_stack := 0.0
@export_range(1.0, 4.0, 0.05) var conduct_stun_cadence_divisor := 1.0
## Applied status ids removed when this status is applied.
@export var extinguishes: Array[StringName] = []
@export_range(0, 10, 1) var extinguish_stacks_per_application := 3
@export var transmissible := false


func validate() -> Array[String]:
	var problems: Array[String] = []
	if not STATUS_IDS.has(id) and not AUXILIARY_STATUS_IDS.has(id):
		problems.append("status id '%s' is not registered" % String(id))
	if element < 1 or element > 7:
		problems.append("status element must be a non-neutral element")
	if family < Family.DAMAGE_OVER_TIME or family > Family.MOVEMENT_LOCK:
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
	if family == Family.DAMAGE_OVER_TIME and damage_percent_max_health_per_stack <= 0.0:
		problems.append("damage-over-time statuses need positive max-health damage per stack")
	if damage_percent_max_health_per_stack < 0.0:
		problems.append("damage_percent_max_health_per_stack must be non-negative")
	if family != Family.DAMAGE_OVER_TIME and damage_percent_max_health_per_stack > 0.0:
		problems.append("only damage-over-time statuses may define damage_percent_max_health_per_stack")
	if family == Family.PERIODIC_STUN:
		if stun_interval <= 0.0 or stun_interval_floor <= 0.0:
			problems.append("periodic stun cadence and floor must be positive")
		if stun_lock_duration <= 0.0:
			problems.append("stun_lock_duration must be positive")
	if periodic_damage_percent_max_health_per_stack < 0.0:
		problems.append("periodic_damage_percent_max_health_per_stack must be non-negative")
	if periodic_damage_percent_max_health_per_stack > 0.0 and periodic_damage_interval <= 0.0:
		problems.append("periodic damage needs a positive interval")
	if family != Family.PERIODIC_STUN and periodic_damage_percent_max_health_per_stack > 0.0:
		problems.append("only periodic-stun statuses may define periodic damage")
	if applies_damage_vulnerability() and vulnerability_per_stack <= 0.0:
		problems.append("damage vulnerability statuses need a positive vulnerability_per_stack")
	if family == Family.AMBIENT_MODIFIER:
		if conducts_element < 0 or conducts_element > 7:
			problems.append("ambient conducts_element must be a valid non-neutral element or zero")
		if conducts_element == 0 and extinguishes.is_empty():
			problems.append("ambient modifiers need a conducted element or at least one extinguished status")
		if conducts_element > 0 and conduct_damage_bonus_per_stack <= 0.0 and is_equal_approx(conduct_stun_cadence_divisor, 1.0):
			problems.append("ambient conducted element needs a damage or stun modifier")
		if not extinguishes.is_empty() and extinguish_stacks_per_application <= 0:
			problems.append("ambient extinguish stack count must be positive")
		for extinguished_id in extinguishes:
			if not STATUS_IDS.has(extinguished_id):
				problems.append("ambient extinguished id '%s' is not a registered status" % String(extinguished_id))
	else:
		if conducts_element != 0 or not is_zero_approx(conduct_damage_bonus_per_stack) or not is_equal_approx(conduct_stun_cadence_divisor, 1.0):
			problems.append("only ambient modifiers may define conductivity behavior")
	if not applies_damage_vulnerability() and not is_zero_approx(vulnerability_per_stack):
		problems.append("only damage vulnerability statuses may define vulnerability_per_stack")
	if not extinguishes.is_empty() and extinguish_stacks_per_application <= 0:
		problems.append("extinguish stack count must be positive")
	for extinguished_id in extinguishes:
		if not STATUS_IDS.has(extinguished_id):
			problems.append("extinguished id '%s' is not a registered status" % String(extinguished_id))
	if badge_glyph.is_empty():
		problems.append("badge_glyph must not be empty")
	if badge_icon == null:
		problems.append("badge_icon must be assigned")
	elif badge_icon.get_width() != 7 or badge_icon.get_height() != 7:
		problems.append("badge_icon must be 7x7 pixels")
	if not PARTICLE_STYLES.has(particle_style):
		problems.append("particle_style '%s' is not registered" % String(particle_style))
	if particle_interval <= 0.0:
		problems.append("particle_interval must be positive")
	return problems


## Damage vulnerability applies to its own family and also to movement locks,
## so a frozen target can be both rooted and easier to break.
func applies_damage_vulnerability() -> bool:
	return family == Family.DAMAGE_VULNERABILITY or family == Family.MOVEMENT_LOCK


func can_transmit_by_contact() -> bool:
	return transmissible and CONTACT_TRANSMISSIBLE_STATUS_IDS.has(id)


func tick_interval_for(_stacks: int) -> float:
	return maxf(tick_interval, 0.05)


func stun_interval_for(stacks: int) -> float:
	var reductions := maxi(stacks - 1, 0)
	return maxf(stun_interval_floor, stun_interval - float(reductions) * stun_interval_reduction_per_extra_stack)
