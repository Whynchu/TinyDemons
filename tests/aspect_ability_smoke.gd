extends SceneTree

const Chroma = preload("res://scripts/player_chroma_component.gd")
const Ability = preload("res://scripts/player_aspect_ability_component.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var chroma := Chroma.new()
	var ability := Ability.new()
	root.add_child(chroma)
	root.add_child(ability)
	ability.configure_cooldown(1.0)

	var callback_modes: Array[int] = []
	var accepted := ability.try_activate(chroma, func(mode: int) -> bool:
		callback_modes.append(mode)
		return true
	)
	_expect(accepted, "Gray ability can activate without Chroma", failures)
	_expect(callback_modes == [Chroma.AbilityMode.GRAY], "Gray mode reaches the execution callback", failures)
	_expect(chroma.current_chroma == 0, "Gray activation spends no Chroma", failures)
	_expect(ability.cooldown_remaining == 1.0, "accepted activation starts cooldown", failures)
	_expect(not ability.try_activate(chroma, func(_mode: int) -> bool: return true), "cooldown rejects activation", failures)
	ability.tick(1.0)

	chroma.attune(Chroma.Aspect.FIRE)
	accepted = ability.try_activate(chroma, func(mode: int) -> bool:
		callback_modes.append(mode)
		return true
	)
	_expect(accepted, "elemental activation succeeds when affordable", failures)
	_expect(callback_modes[-1] == Chroma.AbilityMode.ELEMENTAL, "elemental mode reaches the execution callback", failures)
	_expect(chroma.current_chroma == 75, "elemental payment occurs after accepted execution", failures)
	ability.tick(1.0)

	accepted = ability.try_activate(chroma, func(_mode: int) -> bool: return false)
	_expect(not accepted, "failed execution is rejected", failures)
	_expect(chroma.current_chroma == 75, "failed execution does not spend Chroma", failures)

	chroma.set_binding_active(true)
	for _i in 3:
		ability.tick(1.0)
		ability.try_activate(chroma, func(_mode: int) -> bool: return true)
	ability.tick(1.0)
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
