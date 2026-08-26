extends Node
class_name EquipmentTransmutationComponent

signal effect_triggered(effect_id: StringName, message: String)

const BASTION_CORE := &"bastion_core"
const BLOODWOVEN_CORE := &"bloodwoven_core"
const BLOOD_FEED := &"blood_feed"
const DUELIST_FOCUS := &"duelist_focus"
const GATHERING_EDGE := &"gathering_edge"
const BASTION_MAX_CHARGES := 3
const BASTION_KNOCKBACK_PER_CHARGE := 0.35
const BASTION_DURABILITY_PER_DEF := 0.50
const DUELIST_LOCKED_DAMAGE_PER_STR := 0.03
const DUELIST_OTHER_TARGET_MULTIPLIER := 0.80
const BLOOD_FEED_LIFE_STEAL_RATE := 0.20

var active_transmutations: Dictionary = {}
var bastion_charges := 0
var active_bastion_attack_charges := 0
var duelist_feedback_ready := false
var gathering_armed_targets: Array[Sprite2D] = []
var gathering_active_targets: Array[Sprite2D] = []


func configure(equipment: EquipmentComponent) -> void:
	active_transmutations = equipment.equipped_transmutations.duplicate(true) if equipment != null else {}
	if not has(BASTION_CORE):
		bastion_charges = 0
		active_bastion_attack_charges = 0
	if not has(DUELIST_FOCUS):
		duelist_feedback_ready = false
	if not has(GATHERING_EDGE):
		gathering_armed_targets.clear()
		gathering_active_targets.clear()


func has(transmutation_id: StringName) -> bool:
	return String(transmutation_id) in active_transmutations.values()


func guard_maximum_durability(base_durability: float, effective_defense: float) -> float:
	if not has(BASTION_CORE):
		return base_durability
	return base_durability + maxf(effective_defense, 0.0) * BASTION_DURABILITY_PER_DEF


func record_successful_block(_shield_damage: float = 0.0, _health_damage: float = 0.0) -> void:
	if not has(BASTION_CORE):
		return
	bastion_charges = mini(bastion_charges + 1, BASTION_MAX_CHARGES)
	effect_triggered.emit(BASTION_CORE, "BASTION %d/%d" % [bastion_charges, BASTION_MAX_CHARGES])


func begin_attack(variant: int) -> void:
	active_bastion_attack_charges = 0
	duelist_feedback_ready = has(DUELIST_FOCUS)
	gathering_active_targets.clear()
	if variant == 1 and has(GATHERING_EDGE):
		gathering_armed_targets.clear()
	if variant == 2 and has(BASTION_CORE) and bastion_charges > 0:
		active_bastion_attack_charges = bastion_charges
		bastion_charges = 0
		effect_triggered.emit(BASTION_CORE, "BASTION x%d" % active_bastion_attack_charges)
	if variant == 2 and has(GATHERING_EDGE) and not gathering_armed_targets.is_empty():
		gathering_active_targets = gathering_armed_targets.duplicate()
		gathering_armed_targets.clear()
		effect_triggered.emit(GATHERING_EDGE, "GATHERING EDGE")


func finish_attack() -> void:
	active_bastion_attack_charges = 0
	duelist_feedback_ready = false
	gathering_active_targets.clear()


func attack_knockback_multiplier() -> float:
	return 1.0 + active_bastion_attack_charges * BASTION_KNOCKBACK_PER_CHARGE


func record_attack_hits(attack_variant: int, targets: Array) -> void:
	if attack_variant != 1 or not has(GATHERING_EDGE):
		return
	gathering_armed_targets.clear()
	if targets.size() < 2:
		return
	for target: Variant in targets:
		if target is Sprite2D:
			gathering_armed_targets.append(target as Sprite2D)
	if gathering_armed_targets.size() >= 2:
		effect_triggered.emit(GATHERING_EDGE, "GATHERING READY")


func damage_share_divisor(target: Sprite2D, target_count: int) -> float:
	if not has(GATHERING_EDGE) or not gathering_active_targets.has(target):
		return maxf(float(target_count), 1.0)
	return maxf(float(target_count - 1), 1.0)


func duelist_damage_multiplier(target: Sprite2D, locked_target: Sprite2D, effective_strength: float) -> float:
	if not has(DUELIST_FOCUS) or locked_target == null:
		return 1.0
	return 1.0 + maxf(float(effective_strength), 0.0) * DUELIST_LOCKED_DAMAGE_PER_STR if target == locked_target else DUELIST_OTHER_TARGET_MULTIPLIER


func life_steal_amount(damage: float) -> float:
	if not has(BLOOD_FEED):
		return 0.0
	return maxf(damage, 0.0) * BLOOD_FEED_LIFE_STEAL_RATE


func consume_duelist_feedback(target_is_locked: bool, effective_strength: float) -> void:
	if not duelist_feedback_ready:
		return
	duelist_feedback_ready = false
	if target_is_locked:
		effect_triggered.emit(DUELIST_FOCUS, "DUELIST +%d%%" % roundi(maxf(float(effective_strength), 0.0) * DUELIST_LOCKED_DAMAGE_PER_STR * 100.0))
	else:
		effect_triggered.emit(DUELIST_FOCUS, "DUELIST -20%")
