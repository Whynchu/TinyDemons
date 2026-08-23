extends SceneTree

const Chroma = preload("res://scripts/player_chroma_component.gd")
const Ability = preload("res://scripts/player_aspect_ability_component.gd")
const MagicRuntime = preload("res://scripts/magic_runtime_controller.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var chroma := Chroma.new()
	var ability := Ability.new()
	root.add_child(chroma)
	root.add_child(ability)
	ability.configure_mode_cooldowns(2.0, 2.5)
	var magic := MagicRuntime.new()
	var grey_damage := magic.magic_damage_for_mode(20.0, Chroma.AbilityMode.GRAY)
	var elemental_damage := magic.magic_damage_for_mode(20.0, Chroma.AbilityMode.ELEMENTAL)
	_expect(is_equal_approx(grey_damage, 22.0), "gray triangle keeps its baseline magic damage", failures)
	_expect(is_equal_approx(elemental_damage, 23.0), "elemental triangle gets a small damage increase", failures)
	_expect(elemental_damage > grey_damage, "elemental triangle is stronger than gray", failures)
	_expect(magic.magic_damage_for_mode(5.0, Chroma.AbilityMode.ELEMENTAL) == 6.0, "elemental triangle stays visibly stronger at normal low damage", failures)
	_expect(is_equal_approx(magic.magic_knockback_multiplier(), 0.25), "triangle attacks use quarter-strength knockback", failures)

	var callback_modes: Array[int] = []
	var accepted := ability.try_activate(chroma, func(mode: int) -> bool:
		callback_modes.append(mode)
		return true
	)
	_expect(accepted, "Gray ability can activate without Chroma", failures)
	_expect(callback_modes == [Chroma.AbilityMode.GRAY], "Gray mode reaches the execution callback", failures)
	_expect(chroma.current_chroma == 0, "Gray activation spends no Chroma", failures)
	_expect(is_equal_approx(ability.cooldown_remaining, 2.5), "gray activation starts the longer cooldown", failures)
	_expect(not ability.try_activate(chroma, func(_mode: int) -> bool: return true), "cooldown rejects activation", failures)
	ability.tick(2.5)

	chroma.attune(Chroma.Aspect.FIRE)
	accepted = ability.try_activate(chroma, func(mode: int) -> bool:
		callback_modes.append(mode)
		return true
	)
	_expect(accepted, "elemental activation succeeds when affordable", failures)
	_expect(callback_modes[-1] == Chroma.AbilityMode.ELEMENTAL, "elemental mode reaches the execution callback", failures)
	_expect(chroma.current_chroma == 75, "elemental payment occurs after accepted execution", failures)
	_expect(is_equal_approx(ability.cooldown_remaining, 2.0), "elemental activation starts the standard cooldown", failures)
	ability.tick(2.0)

	accepted = ability.try_activate(chroma, func(_mode: int) -> bool: return false)
	_expect(not accepted, "failed execution is rejected", failures)
	_expect(chroma.current_chroma == 75, "failed execution does not spend Chroma", failures)

	chroma.set_binding_active(true)
	for _i in 3:
		ability.tick(2.0)
		ability.try_activate(chroma, func(_mode: int) -> bool: return true)
	ability.tick(2.5)
	_expect(chroma.current_chroma == 0, "bound aspect reaches zero through accepted casts", failures)
	accepted = ability.try_activate(chroma, func(mode: int) -> bool:
		callback_modes.append(mode)
		return true
	)
	_expect(accepted, "dormant bound aspect can activate", failures)
	_expect(callback_modes[-1] == Chroma.AbilityMode.BOUND_WEAKENED, "dormant bound mode reaches callback", failures)
	_expect(chroma.current_chroma == 0, "weakened bound activation spends no Chroma", failures)

	chroma.free()
	ability.free()
	magic.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: aspect ability smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ASPECT_ABILITY_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
