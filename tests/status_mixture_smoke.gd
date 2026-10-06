extends SceneTree

const ElementCatalogScript = preload("res://scripts/content/element_catalog.gd")
const ElementAuraComponentScript = preload("res://scripts/components/element_aura_component.gd")
const SlimeActorScript = preload("res://scripts/actors/slime_actor.gd")
const HudControllerScript = preload("res://scripts/ui/hud_controller.gd")
const EffectsSpawnerScript = preload("res://scripts/runtime/services/effects_spawner.gd")

var _finished := false
var _attack_update_count := 0


func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	_expect(ElementCatalogScript.DATA.validate().is_empty(), "status and mixture registry validates", failures)
	var chill := ElementCatalogScript.status_effect_for_id(&"chill")
	var freeze := ElementCatalogScript.status_effect_for_id(&"freeze")
	var burn := ElementCatalogScript.status_effect_for_id(&"burn")
	var wet := ElementCatalogScript.status_effect_for_id(&"wet")
	_expect(wet != null and wet.badge_glyph == "W", "Wet uses its W badge", failures)
	_expect(freeze != null and freeze.badge_glyph == "F", "Freeze uses its F badge", failures)
	if wet == null or chill == null or freeze == null:
		_finish(failures)
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 1207
	var wet_then_chill := _new_target()
	_expect(_apply(wet_then_chill, ElementCatalogScript.Element.WATER, rng), "Wet applies first", failures)
	_expect(_apply(wet_then_chill, ElementCatalogScript.Element.ICE, rng), "Chill applies after Wet", failures)
	_assert_frozen(wet_then_chill, failures)
	wet_then_chill.queue_free()

	var chill_then_wet := _new_target()
	_expect(_apply(chill_then_wet, ElementCatalogScript.Element.ICE, rng), "Chill applies first", failures)
	_expect(_apply(chill_then_wet, ElementCatalogScript.Element.WATER, rng), "Wet applies after Chill", failures)
	_assert_frozen(chill_then_wet, failures)
	chill_then_wet.queue_free()

	var innate_water := _new_target()
	var innate_status := innate_water.get_node(^"Status") as StatusComponent
	innate_status.configure_innate(&"wet")
	_expect(_apply(innate_water, ElementCatalogScript.Element.ICE, rng), "Chill applies to an innately Wet actor", failures)
	_expect(innate_status.record_for(&"freeze") != null, "innate Wet plus applied Chill triggers Freeze", failures)
	_expect(innate_status.record_for(&"wet") != null and innate_status.is_suppressed(&"wet"), "innate Wet is hidden under Freeze without deleting the affinity", failures)
	_expect(innate_status.stacks_for(&"chill") == 0, "applied Chill is consumed by the reaction", failures)
	var freeze_remaining := innate_status.record_for(&"freeze").remaining
	_expect(_apply(innate_water, ElementCatalogScript.Element.ICE, rng), "a later Chill hit still applies while Freeze is active", failures)
	_expect(is_equal_approx(innate_status.record_for(&"freeze").remaining, freeze_remaining), "suppressed innate Wet cannot refresh Freeze for free", failures)
	innate_water.queue_free()

	var burn_then_ice := _new_target()
	var burn_status := burn_then_ice.get_node(^"Status") as StatusComponent
	burn_status.apply_effect(burn, ElementCatalogScript.Element.FIRE)
	_expect(_apply(burn_then_ice, ElementCatalogScript.Element.ICE, rng), "Ice melts applied Burn into Wet", failures)
	_expect(burn_status.stacks_for(&"burn") == 0 and burn_status.stacks_for(&"wet") == 1, "melting Burn consumes it and applies one Wet stack", failures)
	_expect(burn_status.stacks_for(&"chill") == 0, "Ice melting Burn does not also apply Chill", failures)
	burn_then_ice.queue_free()

	var freeze_then_fire := _new_target()
	var freeze_then_fire_status := freeze_then_fire.get_node(^"Status") as StatusComponent
	freeze_then_fire_status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	_expect(_apply(freeze_then_fire, ElementCatalogScript.Element.FIRE, rng), "Fire melts applied Freeze into Wet", failures)
	_expect(freeze_then_fire_status.stacks_for(&"freeze") == 0 and freeze_then_fire_status.stacks_for(&"wet") == 1, "melting Freeze consumes it and applies Wet", failures)
	_expect(freeze_then_fire_status.stacks_for(&"burn") == 0, "Fire melting Freeze does not also apply Burn", failures)
	freeze_then_fire.queue_free()

	var innate_fire := _new_target()
	var innate_fire_status := innate_fire.get_node(^"Status") as StatusComponent
	innate_fire_status.configure_innate(&"burn")
	_expect(_apply(innate_fire, ElementCatalogScript.Element.ICE, rng), "Ice melts an innately Fire-affinity target", failures)
	_expect(innate_fire_status.stacks_for(&"wet") == 1 and innate_fire_status.stacks_for(&"chill") == 0, "innate Fire reaction applies Wet without Chill", failures)
	innate_fire.queue_free()

	var freeze_status := _new_target().get_node(^"Status") as StatusComponent
	freeze_status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	_expect(is_zero_approx(freeze_status.movement_speed_multiplier()), "Freeze locks movement completely", failures)
	_expect(is_equal_approx(freeze_status.attack_speed_multiplier(), 1.0), "Freeze does not apply an attack-speed slow", failures)
	_expect(freeze_status.is_attack_locked(), "Freeze locks enemy attacks for the status duration", failures)
	_assert_frozen_enemy_pauses_attack(freeze, failures)
	_expect(is_equal_approx(freeze_status.incoming_damage_multiplier_for(ElementCatalogScript.Element.FIRE), 1.25), "Freeze increases direct incoming damage by 25 percent", failures)
	_expect(is_equal_approx(freeze_status.incoming_damage_multiplier_for(ElementCatalogScript.Element.FIRE, false), 1.0), "Freeze vulnerability is excluded from status damage ticks", failures)
	_expect(is_equal_approx(freeze_status.damage_taken_multiplier(), 1.0), "Freeze does not alter the DoT damage multiplier", failures)
	freeze_status.advance(freeze.duration + 0.01)
	_expect(freeze_status.record_for(&"freeze") == null, "Freeze expires cleanly", failures)
	freeze_status.get_parent().queue_free()

	var immune_target := _new_target()
	var immune_status := immune_target.get_node(^"Status") as StatusComponent
	immune_status.status_immunities.append(&"wet")
	immune_status.apply_effect(burn, ElementCatalogScript.Element.FIRE)
	_expect(_apply(immune_target, ElementCatalogScript.Element.ICE, rng), "Ice falls back to its ordinary status when Wet is immune", failures)
	_expect(immune_status.stacks_for(&"burn") == 1 and immune_status.stacks_for(&"wet") == 0, "Wet immunity blocks the thermal reaction without consuming Burn", failures)
	immune_target.queue_free()
	_assert_boss_resistance(freeze, failures)
	_assert_status_marker_draw_order(freeze, failures)
	_finish(failures)


func _new_target() -> Node2D:
	var target := Node2D.new()
	get_root().add_child(target)
	var status := StatusComponent.new()
	status.name = "Status"
	target.add_child(status)
	return target


func _apply(target: Node2D, element: int, rng: RandomNumberGenerator) -> bool:
	var request := StatusApplicationRequest.new()
	request.configure(target, element, 1.0, StatusApplicationRequest.SourceKind.ELEMENTAL_HIT, rng, true)
	return StatusApplication.apply(request)


func _assert_frozen(target: Node2D, failures: Array[String]) -> void:
	var status := target.get_node(^"Status") as StatusComponent
	_expect(status.record_for(&"freeze") != null, "Water and Ice produce Freeze", failures)
	_expect(status.stacks_for(&"wet") == 0 and status.stacks_for(&"chill") == 0, "Freeze consumes applied Wet and Chill", failures)
	_expect(is_zero_approx(status.movement_speed_multiplier()), "Frozen actor cannot move", failures)
	_expect(is_equal_approx(status.attack_speed_multiplier(), 1.0), "Frozen actor keeps its attack speed", failures)
	status.advance(3.1)
	_expect(status.record_for(&"freeze") == null, "Freeze expires after its authored duration", failures)


func _assert_status_marker_draw_order(freeze: StatusEffectDefinition, failures: Array[String]) -> void:
	var world := Node2D.new()
	get_root().add_child(world)
	var actor := Sprite2D.new()
	actor.z_index = 4
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	var shared_texture := ImageTexture.create_from_image(image)
	actor.texture = shared_texture
	world.add_child(actor)
	var status := StatusComponent.new()
	status.name = "Status"
	actor.add_child(status)
	var aura := ElementAuraComponentScript.new() as ElementAuraComponent
	aura.name = "ElementAura"
	actor.add_child(aura)
	aura.configure(actor, world, status)
	status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	var marker := aura._status_outline as Sprite2D
	_expect(marker != null and marker.top_level and not marker.z_as_relative, "status marker uses an absolute world-space draw layer", failures)
	_expect(marker != null and marker.z_index < actor.z_index, "status marker renders underneath its character sprite", failures)
	_expect(marker != null and marker.texture != null and marker.texture.get_size() == Vector2i(4, 4), "sprite outline byte scan preserves the one-pixel border", failures)
	var second_actor := Sprite2D.new()
	second_actor.texture = shared_texture
	second_actor.z_index = 4
	world.add_child(second_actor)
	var second_status := StatusComponent.new()
	second_status.name = "Status"
	second_actor.add_child(second_status)
	var second_aura := ElementAuraComponentScript.new() as ElementAuraComponent
	second_actor.add_child(second_aura)
	second_aura.configure(second_actor, world, second_status)
	second_status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	_expect(marker != null and second_aura._status_outline != null and second_aura._status_outline.texture == marker.texture, "actors sharing a sprite frame reuse the generated status outline", failures)
	var hud := HudControllerScript.new() as HudController
	var actor_status := actor.get_node(^"Status") as StatusComponent
	hud.update_player_status_marks(actor, actor_status, Callable(self, "_status_glyph_texture"))
	var badge: Sprite2D = hud.player_status_markers[0] if not hud.player_status_markers.is_empty() else null
	_expect(badge != null and badge.top_level and not badge.z_as_relative, "player status badge uses an absolute world-space draw layer", failures)
	_expect(badge != null and badge.get_parent() == world and badge.z_index < actor.z_index, "player status badge renders behind the player sprite in the world", failures)
	var enemy_badges: Array = []
	hud._update_actor_status_markers(actor, actor_status, enemy_badges, Vector2.ZERO, Callable(self, "_status_glyph_texture"))
	var enemy_badge: Sprite2D = enemy_badges[0] as Sprite2D if not enemy_badges.is_empty() else null
	_expect(enemy_badge != null and enemy_badge.top_level and not enemy_badge.z_as_relative and enemy_badge.z_index < actor.z_index, "enemy status badge renders behind its actor sprite", failures)
	hud.free()
	var effects := EffectsSpawnerScript.new() as EffectsSpawner
	var edge_positions := effects._status_edge_positions(actor)
	_expect(edge_positions.size() == 4, "status particle edge scan keeps the complete outline boundary", failures)
	effects.free()
	world.queue_free()


func _status_glyph_texture(_text: String, _color: Color) -> Texture2D:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)


func _assert_boss_resistance(freeze: StatusEffectDefinition, failures: Array[String]) -> void:
	var actor := Node2D.new()
	get_root().add_child(actor)
	var status := StatusComponent.new()
	status.name = "Status"
	actor.add_child(status)
	var combat := SlimeCombatComponent.new()
	combat.name = "Combat"
	combat.boss_jump_phase_stun_resistant = true
	actor.add_child(combat)
	status.set_movement_lock_resistance_check(Callable(combat, "movement_lock_is_resisted"))
	status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	_expect(status.record_for(&"freeze") != null, "boss-resisted actors still receive Freeze", failures)
	_expect(is_equal_approx(status.incoming_damage_multiplier_for(ElementCatalogScript.Element.FIRE), 1.25), "Freeze vulnerability applies during a boss resistance phase", failures)
	_expect(is_equal_approx(status.movement_speed_multiplier(), 1.0), "boss resistance prevents Freeze movement lock during its protected phase", failures)
	_expect(not status.is_attack_locked(), "boss movement-lock resistance also prevents Freeze from locking attacks", failures)
	combat.boss_jump_phase_stun_resistant = false
	_expect(is_zero_approx(status.movement_speed_multiplier()), "Freeze movement lock resumes when boss resistance ends", failures)
	_expect(status.is_attack_locked(), "Freeze attack lock resumes when boss resistance ends", failures)
	actor.queue_free()


func _assert_frozen_enemy_pauses_attack(freeze: StatusEffectDefinition, failures: Array[String]) -> void:
	var enemy := SlimeActorScript.new() as SlimeActor
	get_root().add_child(enemy)
	var status := StatusComponent.new()
	status.name = "Status"
	enemy.add_child(status)
	var combat := SlimeCombatComponent.new()
	combat.name = "Combat"
	enemy.add_child(combat)
	status.apply_effect(freeze, ElementCatalogScript.Element.ICE)
	enemy.tick_runtime(
		0.1,
		Callable(self, "_never_dead"),
		Callable(self, "_noop_update"),
		Callable(self, "_count_attack_update"),
		Callable(self, "_never_aggroed"),
		Callable(self, "_no_target"),
		Callable(self, "_noop_update")
	)
	_expect(_attack_update_count == 0, "a frozen enemy does not advance or start an attack", failures)
	enemy.queue_free()


func _never_dead(_actor: Node) -> bool:
	return false


func _never_aggroed(_actor: Node) -> bool:
	return false


func _no_target(_actor: Node) -> Node:
	return null


func _count_attack_update(_actor: Node, _delta: float) -> bool:
	_attack_update_count += 1
	return false


func _noop_update(_actor: Node, _delta: float) -> bool:
	return false


func _watchdog() -> void:
	if not _finished:
		push_error("TEST_ABORTED: status mixture smoke timed out")
		quit(1)


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("STATUS_MIXTURE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
