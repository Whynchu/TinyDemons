extends Node
class_name CombatRuntimeController

const ProgressionControllerScript = preload("res://scripts/progression_controller.gd")
const SlimeVariantCatalogScript = preload("res://scripts/slime_variant_catalog.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const CombatDamageRequestScript = preload("res://scripts/combat_damage_request.gd")

const ENEMY_HEALTH_R1_FACTOR := 0.50
const ENEMY_HEALTH_R2_FACTOR := 0.65
const ENEMY_HEALTH_RUN_STEP := 0.15
const ENEMY_HEALTH_MAX_FACTOR := 1.0
const R1_BOSS_HEALTH_FACTOR := 0.50
const BOSS_ENCOUNTER_HEALTH_FACTOR := 0.90
const SOUL_DROP_VALUE := 1


static func enemy_health_factor(completed_runs: int, encounter_scale: float = 1.0) -> float:
	var run_count := maxi(completed_runs, 0)
	var factor := ENEMY_HEALTH_R1_FACTOR if run_count == 0 else clampf(ENEMY_HEALTH_R2_FACTOR + float(run_count - 1) * ENEMY_HEALTH_RUN_STEP, ENEMY_HEALTH_R2_FACTOR, ENEMY_HEALTH_MAX_FACTOR)
	if encounter_scale > 1.0 and run_count == 0:
		return R1_BOSS_HEALTH_FACTOR
	return factor


static func enemy_level_cap_for_rank(run_rank: int) -> int:
	var normalized_rank := maxi(run_rank, 1)
	return 3 if normalized_rank <= 1 else normalized_rank + 3


func damage_slime(root: Object, slime: Sprite2D, amount: float, was_critical: bool = false, attack_element: int = ElementCatalogScript.Element.NEUTRAL, immune: bool = false) -> void:
	damage_slime_with_number(root, slime, amount, was_critical, true, attack_element, immune)


func damage_slime_with_number(root: Object, slime: Sprite2D, amount: float, was_critical: bool, show_damage_number: bool, attack_element: int = ElementCatalogScript.Element.NEUTRAL, immune: bool = false) -> void:
	if slime != null and not bool(root.call("_is_slime_dead", slime)) and root.has_method("_mark_current_room_engaged"):
		# A room locks only after a real player hit. Empty swings and passive
		# enemy aggro deliberately leave the arrival entrance available.
		root.call("_mark_current_room_engaged")
	register_combo_hit(root)
	var ambush := root.call("_slime_ambush", slime) as SlimeAmbushComponent
	if ambush != null:
		var tuning := root.get("slime_tuning") as SlimeTuning
		ambush.extend_rehide(slime, tuning.ambush_hit_extension)
	SlimeActor.damage_actor(root, slime, amount, was_critical, attack_element, immune, show_damage_number)
	var rng := root.get("rng") as RandomNumberGenerator
	root.call("_play_sound", "slash", -15.0, 0.95 + rng.randf_range(-0.10, 0.10))
	root.call("_play_sound", "enemy_hit", -10.0, 0.88 + rng.randf_range(-0.06, 0.06))


func player_attack_damage_result_against(root: Object, slime: Sprite2D, attack_element: int = ElementCatalogScript.Element.NEUTRAL) -> CombatCalculator.DamageResult:
	var result := player_weapon_damage_result_against(root, slime, attack_element)
	var momentum := combat_momentum(root)
	var current_target := root.call("_valid_current_target") as Sprite2D
	var multiplier := momentum.focus_multiplier(slime == current_target) * momentum.combo_multiplier()
	var transmutation := root.get("equipment_transmutation_component") as EquipmentTransmutationComponent
	if transmutation != null:
		var snapshot := player_stat_snapshot(root)
		var transmutation_multiplier := transmutation.duelist_damage_multiplier(slime, current_target, snapshot.strength)
		if not is_equal_approx(transmutation_multiplier, 1.0):
			transmutation.consume_duelist_feedback(slime == current_target, snapshot.strength)
		multiplier *= transmutation_multiplier
	if not result.immune:
		result.amount *= multiplier
	return result


func player_weapon_damage_result_against(root: Object, slime: Sprite2D, attack_element: int = ElementCatalogScript.Element.NEUTRAL) -> CombatCalculator.DamageResult:
	var player_stats := root.get("player_stats") as StatsComponent
	var slime_stats := root.call("_slime_stats", slime) as StatsComponent
	var tuning := root.get("combat_tuning") as CombatTuning
	var active_element_value: Variant = root.get("player_imbued_element")
	var active_element := int(active_element_value) if active_element_value != null else ElementCatalogScript.Element.NEUTRAL
	var request: RefCounted
	if active_element != ElementCatalogScript.Element.NEUTRAL and ElementCatalogScript.normalize(attack_element) == active_element:
		request = CombatDamageRequestScript.imbued_weapon(tuning.damage_base, tuning.damage_per_strength, tuning.imbue_base, tuning.imbue_per_int, attack_element, slime_element(slime), true)
	else:
		request = CombatDamageRequestScript.physical(tuning.damage_base, tuning.damage_per_strength, attack_element, slime_element(slime), true)
	return combat_damage_request(root, player_stats, slime_stats, request)


func player_magic_damage_result_against(root: Object, slime: Sprite2D, attack_element: int, magic_base_bonus: float = 0.0) -> CombatCalculator.DamageResult:
	var player_stats := root.get("player_stats") as StatsComponent
	var slime_stats := root.call("_slime_stats", slime) as StatsComponent
	var tuning := root.get("combat_tuning") as CombatTuning
	var request := CombatDamageRequestScript.magic(tuning.magic_base + magic_base_bonus, tuning.magic_per_int, attack_element, slime_element(slime), true)
	return combat_damage_request(root, player_stats, slime_stats, request)


func player_attack_damage_against(root: Object, slime: Sprite2D) -> float:
	return player_attack_damage_result_against(root, slime).amount


func combat_momentum(root: Object) -> CombatMomentumComponent:
	var momentum := root.get("combat_momentum") as CombatMomentumComponent
	if momentum == null:
		momentum = CombatMomentumComponent.new()
		momentum.configure(root.get("player_tuning") as PlayerTuning)
		root.set("combat_momentum", momentum)
	return momentum


func register_combo_hit(root: Object) -> void:
	combat_momentum(root).register_hit()


func tick_focus_combo(root: Object, delta: float) -> void:
	var momentum := combat_momentum(root)
	var was_focus_active := momentum.focus_active
	momentum.tick(delta, root.get("current_target") != null)
	if was_focus_active and not momentum.focus_active and root.get("current_target") != null:
		root.call("_play_sound", "ui_decline", -10.0, 1.0)
		root.set("focus_flash_timer", 0.25)


func reset_combo(root: Object) -> void:
	combat_momentum(root).reset_combo()


func player_attack_damage_share_divisor(root: Object, slime: Sprite2D, target_count: int) -> float:
	var transmutation := root.get("equipment_transmutation_component") as EquipmentTransmutationComponent
	return transmutation.damage_share_divisor(slime, target_count) if transmutation != null else maxf(float(target_count), 1.0)


func combat_damage(root: Object, attacker_stats: StatsComponent, defender_stats: StatsComponent, attack_element: int = ElementCatalogScript.Element.NEUTRAL, defense_element: int = ElementCatalogScript.Element.NEUTRAL) -> CombatCalculator.DamageResult:
	var player_stats := root.get("player_stats") as StatsComponent
	var tuning := root.get("combat_tuning") as CombatTuning
	var strength_scale := tuning.damage_per_strength if attacker_stats == player_stats else tuning.enemy_damage_per_strength
	var request := CombatDamageRequestScript.physical(tuning.damage_base, strength_scale, attack_element, defense_element, attacker_stats == player_stats)
	return combat_damage_request(root, attacker_stats, defender_stats, request)


func combat_damage_request(root: Object, attacker_stats: StatsComponent, defender_stats: StatsComponent, request: RefCounted) -> CombatCalculator.DamageResult:
	var player_stats := root.get("player_stats") as StatsComponent
	var equipment := root.get("player_equipment") as EquipmentComponent
	var attacker_snapshot := CombatStatSnapshot.from_components(attacker_stats, equipment if attacker_stats == player_stats else null)
	var defender_snapshot := CombatStatSnapshot.from_components(defender_stats, equipment if defender_stats == player_stats else null)
	return CombatCalculator.calculate_request(request, attacker_snapshot, defender_snapshot, root.get("rng") as RandomNumberGenerator, root.get("combat_tuning") as CombatTuning)


func max_health_for_stats(root: Object, stats: StatsComponent) -> float:
	var player_stats := root.get("player_stats") as StatsComponent
	return CombatCalculator.max_health_for_snapshot(CombatStatSnapshot.from_components(stats, root.get("player_equipment") as EquipmentComponent if stats == player_stats else null), root.get("combat_tuning") as CombatTuning)


func player_stat_snapshot(root: Object) -> CombatStatSnapshot:
	return CombatStatSnapshot.from_components(root.get("player_stats") as StatsComponent, root.get("player_equipment") as EquipmentComponent)


func player_stat_debug_breakdown(root: Object) -> Dictionary:
	var snapshot := player_stat_snapshot(root)
	var tuning := root.get("combat_tuning") as CombatTuning
	var breakdown := snapshot.debug_breakdown(tuning)
	var player_tuning := root.get("player_tuning") as PlayerTuning
	if player_tuning != null:
		breakdown["MOV"] = player_tuning.agi_multiplier(snapshot.agi)
		breakdown["RECOVERY"] = player_tuning.attack_multiplier_for_agi(snapshot.agi)
	breakdown["KNOCKBACK"] = (tuning.knockback_multiplier_for_strength(snapshot.strength) if tuning != null else 1.0)
	return breakdown


func player_stat_debug_summary(root: Object) -> String:
	var breakdown := player_stat_debug_breakdown(root)
	return "LV %d | VIT %.1f STR %.1f DEF %.1f AGI %.1f INT %.1f MND %.1f | HP %.1f P.ATK %.1f P.DEF %.2f M.ATK %.1f M.DEF %.2f MOV %.2fx RECOVERY %.2fx KNOCKBACK %.2fx" % [
		int(breakdown["LV"]), float(breakdown["VIT"]), float(breakdown["STR"]), float(breakdown["DEF"]), float(breakdown["AGI"]), float(breakdown["INT"]), float(breakdown["MND"]),
		float(breakdown["HP"]), float(breakdown["P.ATK"]), float(breakdown["P.DEF"]), float(breakdown["M.ATK"]), float(breakdown["M.DEF"]), float(breakdown["MOV"]), float(breakdown["RECOVERY"]), float(breakdown["KNOCKBACK"]),
	]


func recompute_player_speed_multiplier(root: Object) -> void:
	var stats := root.get("player_stats") as StatsComponent
	var tuning := root.get("player_tuning") as PlayerTuning
	if stats == null or tuning == null:
		return
	var snapshot := player_stat_snapshot(root)
	root.set("player_spd", snapshot.agi)
	root.set("player_agi", snapshot.agi)
	root.set("player_speed_multiplier", tuning.agi_multiplier(snapshot.agi))
	if bool(root.get("debug_stat_breakdown")):
		print("STAT_BREAKDOWN %s" % player_stat_debug_summary(root))


func player_max_health(root: Object) -> float:
	return max_health_for_stats(root, root.get("player_stats") as StatsComponent)


func enemy_max_health(root: Object, slime: Sprite2D) -> float:
	var health := max_health_for_stats(root, root.call("_slime_stats", slime) as StatsComponent)
	var profile := root.get("player_profile") as PlayerProfile
	var encounter_scale := float(slime.get_meta("encounter_scale", 1.0))
	var completed_runs := profile.completed_runs if profile != null else 0
	# Keep the first two runs approachable while restoring the full encounter
	# curve gradually instead of making R2 an immediate health wall.
	health *= enemy_health_factor(completed_runs, encounter_scale)
	if encounter_scale > 1.0:
		health *= encounter_scale * BOSS_ENCOUNTER_HEALTH_FACTOR
	return health


func enemy_level_for_room(root: Object) -> int:
	return maxi(1, ceili(float(root.get("current_room_depth")) / 4.0))


func enemy_level_cap_for_run(root: Object) -> int:
	var rank := encounter_run_rank(root)
	return enemy_level_cap_for_rank(rank)


func run_enemy_level_bonus(root: Object) -> int:
	return maxi(0, encounter_run_rank(root) - 8)


func encounter_run_rank(root: Object) -> int:
	var profile := root.get("player_profile") as PlayerProfile
	return maxi(1, profile.completed_runs + 1 if profile != null else 1)


func apply_enemy_room_level(root: Object, slime: Sprite2D, level_override: int = 0) -> void:
	var stats := root.call("_slime_stats", slime) as StatsComponent
	if stats == null:
		return
	var run := root.get("run_state") as RunState
	var is_popcorn := bool(slime.get_meta("is_popcorn", false))
	var requested := level_override if level_override > 0 else enemy_level_for_room(root)
	if not is_popcorn:
		requested += run_enemy_level_bonus(root) + (run.difficulty_bonus if run != null else 0)
	stats.level = maxi(requested, 1) if is_popcorn else clampi(requested, 1, enemy_level_cap_for_run(root))


func configure_slime_variant(root: Object, slime: Sprite2D, variant: String) -> void:
	var requested_variant := StringName(variant)
	var definition := SlimeVariantCatalogScript.definition(requested_variant)
	var palette := String(definition["variant"])
	slime.set("variant", palette)
	slime.set_meta("element", int(definition["element"]))
	slime.set_meta("damage_contract", String(definition.get("damage_contract", &"physical")))
	var actor := slime as SlimeActor
	if actor != null:
		actor.combat_element = int(definition["element"])
	var stats := root.call("_slime_stats", slime) as StatsComponent
	if stats != null:
		stats.apply_enemy_variant_profile(definition["base_stats"] as Dictionary, definition["growth_weights"] as Dictionary, StringName(palette))
	root.call("_configure_slime_ambush", slime, palette)


func knockback_slime(root: Object, slime: Sprite2D, knockback_multiplier: float = 1.0, strength_scaled: bool = true) -> void:
	if bool(root.call("_is_slime_dead", slime)):
		return
	var direction: Vector2 = root.call("_slime_knockback_direction", slime)
	var transmutation := root.get("equipment_transmutation_component") as EquipmentTransmutationComponent
	var attack := root.get("player_attack_component") as PlayerAttackComponent
	var player_tuning := root.get("player_tuning") as PlayerTuning
	var slime_tuning := root.get("slime_tuning") as SlimeTuning
	var multiplier := (transmutation.attack_knockback_multiplier() if transmutation != null else 1.0) * maxf(knockback_multiplier, 0.0)
	if strength_scaled:
		var combat_tuning := root.get("combat_tuning") as CombatTuning
		if combat_tuning != null:
			multiplier *= combat_tuning.knockback_multiplier_for_strength(player_stat_snapshot(root).strength)
	var combo := attack.base_knockback_multiplier(player_tuning) if attack != null else player_tuning.attack1_knockback_multiplier
	var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
	combat.knockback_velocity = root.call("_perspective_movement", direction.normalized() * (player_tuning.attack_knockback * combo * multiplier / slime_tuning.knockback_duration))
	combat.knockback_timer = slime_tuning.knockback_duration
	var brain := root.call("_slime_brain", slime) as SlimeBrain
	brain.scoot_start = slime.position
	brain.scoot_target = slime.position
	brain.scoot_timer = 0.0
	brain.hold_timer = slime_tuning.hitstun_time


func slime_knockback_direction(root: Object, slime: Sprite2D) -> Vector2:
	var direction: Vector2 = root.call("_actor_foot", slime) - root.call("_actor_foot", root.get("player"))
	if direction.length_squared() < 0.01:
		direction = Vector2.LEFT if bool(root.get("player_attack_flip_h")) else Vector2.RIGHT
	return direction.normalized()


func kill_slime(root: Object, slime: Sprite2D) -> void:
	if bool(root.call("_is_slime_dead", slime)):
		return
	var run := root.get("run_state") as RunState
	if run != null and run.active:
		run.record_enemy_kill()
	var rng := root.get("rng") as RandomNumberGenerator
	root.call("_play_sound", "enemy_death", -6.0, 0.90 + rng.randf_range(-0.08, 0.08))
	root.call("_award_slime_xp", slime)
	var seed_value := int(root.get("current_dungeon_seed")) ^ String(root.get("current_room_id")).hash() ^ slime.get_instance_id()
	var drop_rng := RandomNumberGenerator.new()
	drop_rng.seed = seed_value
	var chroma_tuning := root.get("chroma_tuning") as ChromaTuning
	if chroma_tuning != null and drop_rng.randf() < chroma_tuning.enemy_drop_chance:
		root.call("_spawn_chroma_pickup", root.call("_actor_foot", slime), chroma_tuning.pickup_value, seed_value, root.call("_slime_knockback_direction", slime))
	# Souls are the persistent exchange currency. Every defeated enemy drops one
	# so the fire and equipment-fusion economy does not depend on a lucky roll.
	root.call("_spawn_soul_pickup", root.call("_actor_foot", slime), SOUL_DROP_VALUE, seed_value ^ 0x51A7, root.call("_slime_knockback_direction", slime))
	(root.get("effects_spawner") as EffectsSpawner).spawn_slime_death_from_root(root, slime)
	var room_controller := root.get("room_controller") as RoomController
	room_controller.record_special_enemy_death(root, slime)
	room_controller.kill_slime_without_effects(root, slime)
	room_controller.record_popcorn_enemy_death(root, slime)
	if root.get("current_target") == slime:
		if bool(root.call("_is_target_input_held")):
			root.call("_set_current_target", root.call("_closest_target"), false)
		else:
			root.call("_set_current_target", null, false)
			root.call("_set_target_ui_visible", false)
	if bool(root.call("_are_all_slimes_dead")):
		root.call("_unlock_chest")
		root.call("_on_room_enemies_cleared")


func is_slime_dead(root: Object, slime: Sprite2D) -> bool:
	return bool((root.call("_slime_combat", slime) as SlimeCombatComponent).dead)


func are_all_slimes_dead(root: Object) -> bool:
	for slime in root.get("slimes") as Array[Sprite2D]:
		if not is_slime_dead(root, slime):
			return false
	return true


func slime_element(slime: Sprite2D) -> int:
	if slime == null:
		return ElementCatalogScript.Element.NEUTRAL
	var actor := slime as SlimeActor
	if actor != null:
		return ElementCatalogScript.normalize(actor.combat_element)
	var palette := String(slime.get("variant"))
	return ElementCatalogScript.element_for_palette(palette if not palette.is_empty() else "grey")


func slime_attack_damage_result(root: Object, slime: Sprite2D) -> CombatCalculator.DamageResult:
	var slime_stats := root.call("_slime_stats", slime) as StatsComponent
	var player_stats := root.get("player_stats") as StatsComponent
	var tuning := root.get("combat_tuning") as CombatTuning
	var element := slime_element(slime)
	var variant := StringName(str(slime.get("variant")))
	var request: RefCounted
	if element != ElementCatalogScript.Element.NEUTRAL and SlimeVariantCatalogScript.is_elemental_variant(variant):
		request = CombatDamageRequestScript.elemental_slime(tuning.elemental_slime_physical_base, tuning.elemental_slime_physical_per_strength, tuning.elemental_slime_magic_base, tuning.elemental_slime_magic_per_int, element, ElementCatalogScript.Element.NEUTRAL, false)
	else:
		request = CombatDamageRequestScript.physical(tuning.damage_base, tuning.enemy_damage_per_strength, ElementCatalogScript.Element.NEUTRAL, ElementCatalogScript.Element.NEUTRAL, false)
	return combat_damage_request(root, slime_stats, player_stats, request)


func slime_attack_damage(root: Object, slime: Sprite2D) -> float:
	return slime_attack_damage_result(root, slime).amount


func mark_player_in_combat(root: Object) -> void:
	var health := root.get("player_health_component") as HealthComponent
	var tuning := root.get("player_tuning") as PlayerTuning
	if health != null:
		health.regen_delay_timer = tuning.regen_delay
		health.regen_accumulator = 0.0


func on_player_health_damaged(root: Object, amount: float) -> void:
	reset_combo(root)
	var tuning := root.get("player_tuning") as PlayerTuning
	root.set("player_damage_fill_hold_timer", tuning.health_damage_hang_time)
	var run := root.get("run_state") as RunState
	if run != null:
		run.record_damage(amount)
	var rng := root.get("rng") as RandomNumberGenerator
	root.call("_play_sound", "impact_flesh", -6.0, 0.95 + rng.randf_range(-0.08, 0.08))


func on_player_health_changed(root: Object) -> void:
	if is_instance_valid(root.get("player_health_fill")):
		root.call("_update_player_health_ui")


func on_player_health_healed(root: Object, amount: float) -> void:
	var health := root.get("player_health_component") as HealthComponent
	var display := float(root.get("player_display_health"))
	root.set("player_display_health", minf(display, health.current_health if health != null else display))
	root.call("_spawn_player_healing_number", amount, Color8(177, 62, 83))


func on_slime_health_damaged(root: Object, slime: Sprite2D) -> void:
	(root.call("_slime_health_presenter", slime) as SlimeHealthPresenter).damage_fill_hold_timer = (root.get("slime_tuning") as SlimeTuning).health_damage_hang_time


func on_slime_health_changed(root: Object, slime: Sprite2D) -> void:
	if slime == root.get("current_target") and is_instance_valid(root.get("target_health_fill")):
		root.call("_update_target_ui")


func on_slime_health_healed(root: Object, slime: Sprite2D, amount: float) -> void:
	var health := root.call("_slime_health", slime) as HealthComponent
	var presenter := root.call("_slime_health_presenter", slime) as SlimeHealthPresenter
	if health != null:
		presenter.display_health = minf(presenter.display_health, health.current_health)
	root.call("_spawn_slime_healing_number", slime, amount, root.call("_health_feedback_color", String(slime.get("variant"))) as Color)


func update_player_health_regen(_root: Object, _delta: float) -> void:
	# Fire rooms are paid services now. Do not let the old rest-room regeneration
	# path silently heal the player without an explicit fire interaction.
	pass


func apply_slime_attack_lunge(root: Object, slime: Sprite2D) -> void:
	var movement: Vector2 = root.call("_slime_attack_lunge_vector", slime)
	if movement.length_squared() > 0.0001:
		(root.get("actor_collision_system") as ActorCollisionSystem).try_move_swept(slime, movement, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))


func slime_attack_lunge_vector(root: Object, slime: Sprite2D) -> Vector2:
	var to_player: Vector2 = root.call("_slime_attack_offset", slime)
	var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
	var direction := Vector2.LEFT if to_player.length_squared() < 0.01 and combat.face_left else Vector2.RIGHT if to_player.length_squared() < 0.01 else to_player.normalized()
	var contact_gap: float = root.call("_slime_attack_contact_gap", slime, direction)
	var tuning := root.get("slime_tuning") as SlimeTuning
	var max_lunge := tuning.attack_lunge_distance * float(root.call("_slime_encounter_scale", slime))
	return direction * minf(max_lunge, maxf(to_player.length() - contact_gap, 0.0))


func apply_player_hit_knockback(root: Object, slime: Sprite2D) -> void:
	var player := root.get("player") as Sprite2D
	var direction: Vector2 = root.call("_actor_foot", player) - root.call("_actor_foot", slime)
	if direction.length_squared() < 0.01:
		direction = Vector2.RIGHT if player.global_position.x >= slime.global_position.x else Vector2.LEFT
	var motor := root.get("player_motor") as ActorMotor
	var tuning := root.get("player_tuning") as PlayerTuning
	if motor != null:
		motor.start_knockback(root.call("_perspective_movement", direction.normalized() * (tuning.hit_knockback / tuning.hit_knockback_duration)), tuning.hit_knockback_duration)


func update_slime_knockback(root: Object, slime: Sprite2D, delta: float) -> bool:
	return bool((root.call("_slime_combat", slime) as SlimeCombatComponent).tick_knockback(delta, slime, Callable(root, "_try_knockback_slime"), Callable(root, "_reset_slime_scoot")))


func reset_slime_scoot(root: Object, slime: Sprite2D) -> void:
	var brain := root.call("_slime_brain", slime) as SlimeBrain
	brain.scoot_start = slime.position
	brain.scoot_target = slime.position
	brain.scoot_timer = 0.0
	brain.hold_timer = 0.0
	brain.repath_timer = 0.0
	brain.blocked_repath_cooldown = 0.0
	root.call("_set_actor_visual_scale", slime, Vector2.ONE)


func show_slime_hit_flash(root: Object, slime: Sprite2D) -> void:
	var overlay := slime.get_node_or_null("HitFlashOverlay") as Sprite2D
	if overlay == null:
		overlay = Sprite2D.new()
		overlay.name = "HitFlashOverlay"
		overlay.centered = slime.centered
		overlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slime.add_child(overlay)
	var renderer := root.get("occlusion_renderer") as OcclusionRenderer
	var source := renderer.original_actor_textures.get(slime, slime.texture) as Texture2D
	if source != null:
		overlay.texture = renderer.white_texture(source)
		ActorGeometry.sync_overlay(overlay, slime)
	overlay.z_as_relative = true
	overlay.z_index = 1
	overlay.visible = overlay.texture != null


func update_enemy_hit_flashes(root: Object, delta: float) -> void:
	for slime in root.get("slimes") as Array[Sprite2D]:
		if is_slime_dead(root, slime):
			continue
		var combat := root.call("_slime_combat", slime) as SlimeCombatComponent
		combat.flash_timer = maxf(combat.flash_timer - delta, 0.0)
		var overlay := slime.get_node_or_null("HitFlashOverlay") as Sprite2D
		if overlay != null:
			overlay.visible = combat.flash_timer > 0.0
			if overlay.visible:
				show_slime_hit_flash(root, slime)


func update_enemy_health(root: Object, delta: float) -> void:
	var tuning := root.get("slime_tuning") as SlimeTuning
	for slime in root.get("slimes") as Array[Sprite2D]:
		if not is_slime_dead(root, slime):
			(root.call("_slime_health_presenter", slime) as SlimeHealthPresenter).update(delta, root.call("_slime_health", slime) as HealthComponent, float(root.call("_enemy_max_health", slime)), tuning)


func spawn_damage_number(root: Object, slime: Sprite2D, amount: float, was_critical: bool = false, attack_element: int = ElementCatalogScript.Element.NEUTRAL, immune: bool = false) -> void:
	var tuning := root.get("effects_tuning") as EffectsTuning
	var color := ElementCatalogScript.damage_number_color(attack_element, was_critical and not immune)
	var value := int(round(amount))
	var display_text := "immune" if immune else str(maxi(value, 0))
	root.call("_spawn_floating_number", slime.global_position + Vector2(5, -9), 0 if immune else maxi(value, 0), Vector2(0.0, -tuning.damage_number_float_speed), false if immune else was_critical, false, color, display_text)


func spawn_player_number(root: Object, text: String, value: int, color: Color, is_healing: bool, display_text: String) -> void:
	var origin: Vector2 = root.call("_player_floating_number_origin", text, color)
	var speed := (root.get("effects_tuning") as EffectsTuning).damage_number_float_speed
	root.call("_spawn_floating_number", origin, value, Vector2(0.0, speed), false, is_healing, color, display_text)


func spawn_player_damage_number(root: Object, amount: float, attack_element: int = ElementCatalogScript.Element.NEUTRAL, immune: bool = false) -> void:
	var value := int(round(amount))
	var display_text := "immune" if immune else str(maxi(value, 0))
	spawn_player_number(root, display_text, 0 if immune else value, ElementCatalogScript.damage_number_color(attack_element), false, display_text)


func spawn_player_shield_damage_number(root: Object, amount: float) -> void:
	var value := int(round(amount))
	var color := Color8(148, 220, 255)
	var origin: Vector2 = root.call("_player_floating_number_origin", str(maxi(value, 0)), color) + Vector2(8, 0)
	var speed := (root.get("effects_tuning") as EffectsTuning).damage_number_float_speed
	root.call("_spawn_floating_number", origin, value, Vector2(0.0, speed), false, false, color, str(maxi(value, 0)))


func spawn_player_healing_number(root: Object, amount: float, color: Color) -> void:
	var value := int(round(amount))
	spawn_player_number(root, "+%d" % maxi(value, 0), value, color, true, "")


func apply_player_lifesteal(root: Object, damage: float) -> void:
	var transmutation := root.get("equipment_transmutation_component") as EquipmentTransmutationComponent
	var health := root.get("player_health_component") as HealthComponent
	if transmutation == null or health == null:
		return
	var heal := transmutation.life_steal_amount(damage)
	if heal <= 0.0:
		return
	var applied := health.apply_healing(heal)
	if applied <= 0.0:
		return
	root.call("_update_player_health_ui")
	spawn_player_healing_number(root, applied, Color8(177, 62, 83))


func player_floating_number_origin(root: Object, text: String, color: Color) -> Vector2:
	var texture := root.call("_pixel_text_texture", text, color) as Texture2D
	var width := texture.get_width() if texture != null else 0
	return root.call("_actor_foot", root.get("player")) + Vector2(-float(width) * 0.5, 2)


func spawn_slime_healing_number(root: Object, slime: Sprite2D, amount: float, color: Color) -> void:
	var speed := (root.get("effects_tuning") as EffectsTuning).damage_number_float_speed
	root.call("_spawn_floating_number", slime.global_position + Vector2(5, -9), int(round(amount)), Vector2(0.0, -speed), false, true, color)


func spawn_floating_number(root: Object, world_position: Vector2, value: int, velocity: Vector2, was_critical: bool = false, is_healing: bool = false, healing_color: Color = Color.WHITE, display_text := "") -> void:
	var priority_offset := Vector2.ZERO
	if display_text.contains("lv!"):
		priority_offset = Vector2(0.0, -6.0)
	elif display_text.contains("xp"):
		priority_offset = Vector2(0.0, 6.0)
	world_position += priority_offset
	var tuning := root.get("effects_tuning") as EffectsTuning
	(root.get("effects_spawner") as EffectsSpawner).spawn_health_number(root, world_position, value, velocity, was_critical, is_healing, healing_color, Callable(root, "_pixel_text_texture"), Callable(root, "_snap_half_pixel"), tuning.damage_number_lifetime, tuning.damage_number_pop_time, display_text)


func health_feedback_color(_root: Object, palette_name: String) -> Color:
	return PaletteLibrary.normal(palette_name)


func configure_equipment_transmutations(root: Object) -> void:
	var transmutation := root.get("equipment_transmutation_component") as EquipmentTransmutationComponent
	var equipment := root.get("player_equipment") as EquipmentComponent
	if transmutation == null or equipment == null:
		return
	transmutation.configure(equipment)
	var guard := root.get("player_guard_component") as PlayerGuardComponent
	if guard != null:
		var snapshot: CombatStatSnapshot = root.call("_player_stat_snapshot")
		var shield_maximum := PlayerGuardComponent.MAX_DURABILITY + equipment.guard_durability_bonus
		guard.set_maximum_durability(transmutation.guard_maximum_durability(shield_maximum, snapshot.def), true)


func on_transmutation_effect_triggered(root: Object, effect_id: StringName, message: String) -> void:
	if effect_id == &"duelist_focus" or root.get("player") == null or message.is_empty():
		return
	root.call("_spawn_floating_number", root.call("_actor_foot", root.get("player")) + Vector2(0, -14), 0, Vector2(0, -10), false, false, Color8(148, 220, 255), message)


func xp_required_for_level(root: Object, level: int) -> int:
	return PlayerProfile.xp_required_for_level(level, root.get("progression_tuning") as ProgressionTuning)


func xp_reward_for_slime(root: Object, slime: Sprite2D) -> int:
	var stats := root.call("_slime_stats", slime) as StatsComponent
	var enemy_level := maxi(stats.level if stats != null else 1, 1)
	var base_reward := 2.0 + 2.0 * pow(float(enemy_level), 0.85)
	var profile := root.get("player_profile") as PlayerProfile
	var level_difference := enemy_level - (profile.level if profile != null else 1)
	var difficulty_modifier := pow(1.15, float(level_difference)) if level_difference >= 0 else pow(0.72, float(-level_difference))
	return maxi(1, roundi(base_reward * clampf(difficulty_modifier, 0.2, 2.0)))


func award_slime_xp(root: Object, slime: Sprite2D) -> void:
	var reward := xp_reward_for_slime(root, slime)
	var progression := {"levels": 0}
	var profile := root.get("player_profile") as PlayerProfile
	if profile != null:
		progression = ProgressionControllerScript.award_xp(profile, reward, root.get("progression_tuning") as ProgressionTuning)
		root.call("_apply_profile_to_runtime")
	var levels_gained := int(progression.get("levels", 0))
	if levels_gained > 0:
		spawn_player_level_number(root, profile.level if profile != null else 1)
		root.call("_play_sound", "level_up", -3.0, 1.0)
		root.call("_apply_player_level")
	spawn_player_xp_number(root, reward)
	root.call("_update_player_progression_ui")
	root.call("_sync_runtime_progression_to_profile")


func apply_player_level(root: Object) -> void:
	var profile := root.get("player_profile") as PlayerProfile
	var stats := root.get("player_stats") as StatsComponent
	stats.level = profile.level if profile != null else stats.level
	var health := root.get("player_health_component") as HealthComponent
	var maximum := float(root.call("_player_max_health"))
	if health != null:
		health.set_maximum_health(maximum, true)
		root.set("player_display_health", health.current_health)
	root.call("_update_player_health_ui")


func update_player_progression_ui(root: Object) -> void:
	var level_text := root.get("player_level_text") as Sprite2D
	var xp_fill := root.get("player_xp_fill") as Sprite2D
	var xp_text := root.get("player_xp_text") as Sprite2D
	if not is_instance_valid(level_text) or not is_instance_valid(xp_fill) or not is_instance_valid(xp_text):
		return
	var profile := root.get("player_profile") as PlayerProfile
	var level := profile.level if profile != null else 1
	var xp := profile.xp if profile != null else 0
	var required := xp_required_for_level(root, level)
	var ui := root.get("ui") as Node2D
	var hud_root := ui.get_node_or_null("PlayerHud") as Node2D
	var screen := root.get("screen_state_controller") as Node
	if hud_root != null:
		hud_root.call("set_static_text", "lv. %d" % level, health_feedback_color(root, String(screen.get("player_palette_name"))))
	xp_text.texture = root.call("_pixel_text_texture", "%d/%d" % [xp, required], Color.WHITE) as Texture2D
	var fill_size := xp_fill.texture.get_size() if xp_fill.texture != null else Vector2(48, 16)
	(root.get("hud_controller") as HudController).set_fill_ratio(xp_fill, fill_size, float(xp) / float(required))


func spawn_player_xp_number(root: Object, amount: int) -> void:
	var screen := root.get("screen_state_controller") as Node
	var color := health_feedback_color(root, String(screen.get("player_palette_name")))
	var text := "+%d xp" % maxi(amount, 0)
	spawn_player_number(root, text, amount, color, true, text)


func spawn_player_level_number(root: Object, level: int) -> void:
	var text := "lv up!"
	spawn_player_number(root, text, level, Color.WHITE, false, text)


func update_damage_numbers(root: Object, delta: float) -> void:
	(root.get("effects_spawner") as EffectsSpawner).update_damage_numbers(delta, Callable(root, "_snap_half_pixel"), (root.get("effects_tuning") as EffectsTuning).damage_number_lifetime)


func pixel_text_texture(root: Object, text: String, color: Color) -> Texture2D:
	return (root.get("effects_spawner") as EffectsSpawner).number_texture(text, color)


func pixel_name_texture(root: Object, text: String, color: Color) -> Texture2D:
	return (root.get("effects_spawner") as EffectsSpawner).name_texture(text, color)
