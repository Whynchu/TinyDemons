extends SceneTree

## Guard-block regression coverage for the composition freeze: blocking a slime
## must route the block/break guard visuals through a valid
## build_equipment_visual_context callable (the frame-controller builder). The
## removed gameplay_state seam left flash_guard/break_guard with a null context,
## which dereferenced null and hung. The callable must also tolerate a null
## context without crashing.

const GUARD_SCRIPT = preload("res://scripts/player_guard_component.gd")
const CONTEXT_SCRIPT = preload("res://scripts/player_guard_context.gd")
const VISUAL_SCRIPT = preload("res://scripts/player_equipment_visual_component.gd")

var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var player := Sprite2D.new()
	player.name = "Player"
	root.add_child(player)
	var guard := GUARD_SCRIPT.new()
	root.add_child(guard)
	var visuals := VISUAL_SCRIPT.new()
	root.add_child(visuals)
	guard.maximum_durability = 8.0
	guard.durability = 8.0
	guard.display_durability = 8.0
	guard.guard_active_timer = 0.02

	var context := CONTEXT_SCRIPT.new()
	context.player = player
	context.visuals = visuals
	context.overworld_ui_z = 4090
	context.is_defending_get = func() -> Variant: return true
	context.is_defending_set = func(value: Variant) -> void: pass
	context.player_dead_get = func() -> Variant: return false
	context.player_death_pending_get = func() -> Variant: return false
	context.player_is_attacking_get = func() -> Variant: return false
	context.player_is_rolling_get = func() -> Variant: return false
	context.player_is_backflipping_get = func() -> Variant: return false
	context.player_hitstun_timer_get = func() -> Variant: return 0.0
	context.actor_foot = func(actor: Node) -> Vector2: return actor.global_position
	context.build_equipment_visual_context = func() -> PlayerEquipmentVisualContext:
		var visual_context := PlayerEquipmentVisualContext.new()
		visual_context.player = player
		visual_context.effects_spawner = null
		visual_context.rng = RandomNumberGenerator.new()
		return visual_context

	var block := guard.absorb_damage(context, 10.0, Vector2(1.0, 0.0))
	_expect(bool(block["blocked"]), "a held guard in front of the source blocks the hit", failures)
	_expect(is_equal_approx(float(block["shield_damage"]), 8.0) and is_equal_approx(float(block["health_damage"]), 2.0), "blocked hit splits 80 percent to the shield", failures)
	_expect(guard.durability <= 0.001 and guard.cooldown_timer > 0.0, "an 8-point shield fully blocking a 10-point hit breaks it and starts recovery", failures)

	guard.free()
	visuals.free()
	player.free()
	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: guard block smoke failed before completion (likely a hang)")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("GUARD_BLOCK_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)