extends SceneTree

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")

class CombatRoot extends Node:
	var player_stats: StatsComponent
	var player_equipment: EquipmentComponent = null
	var player_tuning: PlayerTuning
	var combat_tuning: CombatTuning
	var rng: RandomNumberGenerator
	var combat_momentum: CombatMomentumComponent = null
	var equipment_transmutation_component: EquipmentTransmutationComponent = null
	var current_target: Sprite2D = null
	var player: Sprite2D
	var player_is_defending := false
	var player_is_rolling := false
	var player_equipment_visual_component: PlayerEquipmentVisualComponent = null

	func _slime_stats(slime: Sprite2D) -> StatsComponent:
		return slime.get_node_or_null("Stats") as StatsComponent

	func _valid_current_target() -> Sprite2D:
		return current_target

	func _actor_foot(actor: Sprite2D) -> Vector2:
		return actor.global_position


var _finished := false


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var root := CombatRoot.new()
	root.player_stats = StatsComponent.new()
	root.player_tuning = PlayerTuning.new()
	root.combat_tuning = CombatTuning.new()
	root.combat_tuning.damage_roll_min = 1.0
	root.combat_tuning.damage_roll_max = 1.0
	root.combat_tuning.critical_hit_chance = 0.0
	root.rng = RandomNumberGenerator.new()
	root.rng.seed = 20260824
	var controller := CombatRuntimeController.new()

	var shadow := _make_slime(root, ElementCatalogScript.Element.SHADOW, &"purple")
	root.rng.seed = 808
	var sword_into_shadow := controller.player_attack_damage_result_against(root, shadow, ElementCatalogScript.Element.NEUTRAL)
	_expect(sword_into_shadow.immune and is_zero_approx(sword_into_shadow.amount), "basic sword is Neutral and immune into Shadow", failures)
	_expect(sword_into_shadow.element == ElementCatalogScript.Element.NEUTRAL, "basic sword result preserves Neutral", failures)

	var grass := _make_slime(root, ElementCatalogScript.Element.GRASS, &"green")
	root.rng.seed = 808
	var fire_triangle := controller.player_attack_damage_result_against(root, grass, ElementCatalogScript.Element.FIRE)
	_expect(fire_triangle.element == ElementCatalogScript.Element.FIRE, "Triangle result carries Fire", failures)
	_expect(is_equal_approx(fire_triangle.effectiveness, 1.25), "Fire Triangle is strong into Grass", failures)

	root.rng.seed = 909
	var shadow_bite := controller.slime_attack_damage_result(root, shadow)
	_expect(shadow_bite.element == ElementCatalogScript.Element.SHADOW, "Shadow slime bite carries Shadow", failures)
	_expect(shadow_bite.immune and is_zero_approx(shadow_bite.amount), "Shadow bite is immune into Neutral player defense", failures)

	var red := _make_slime(root, ElementCatalogScript.Element.FIRE, &"red")
	root.rng.seed = 707
	var red_bite := controller.slime_attack_damage_result(root, red)
	_expect(red_bite.element == ElementCatalogScript.Element.FIRE, "Fire slime bite carries Fire", failures)
	_expect(not red_bite.immune and red_bite.amount >= 1.0, "non-immune slime bite still deals damage", failures)

	root.player = Sprite2D.new()
	root.add_child(root.player)
	root.player_is_defending = true
	var guard := PlayerGuardComponent.new()
	root.add_child(guard)
	var block := guard.absorb_damage(root, 10.0, Vector2(1.0, 0.0))
	_expect(is_equal_approx(float(block["shield_damage"]), 8.0) and is_equal_approx(float(block["health_damage"]), 2.0), "Neutral guard split remains 80 percent shield reduction", failures)

	root.free()
	controller.free()
	_finished = true
	call_deferred("_finish", failures)


func _make_slime(root: CombatRoot, element: int, variant: StringName) -> SlimeActor:
	var slime := SlimeActor.new()
	slime.variant = String(variant)
	slime.combat_element = element
	var stats := StatsComponent.new()
	slime.add_child(stats)
	root.add_child(slime)
	return slime


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: typed combat path smoke failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TYPED_COMBAT_PATH_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
