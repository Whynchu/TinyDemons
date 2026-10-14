extends SceneTree

const CatalogScript = preload("res://scripts/content/enemy_catalog.gd")
const EnemyFactoryScript = preload("res://scripts/content/enemy_factory.gd")
const CombatRuntimeControllerScript = preload("res://scripts/runtime/controllers/combat_runtime_controller.gd")
const EnemySpawnServicesScript = preload("res://scripts/runtime/services/room_enemy_spawn_services.gd")
const SlimeRuntimeControllerScript = preload("res://scripts/runtime/controllers/slime_runtime_controller.gd")
const TargetingRuntimeControllerScript = preload("res://scripts/runtime/controllers/targeting_runtime_controller.gd")

class TargetFixture:
	extends RefCounted
	var current_target: Sprite2D = null

var rebound_enemy_damage_count := 0
var rebound_enemy_damage_actor: Sprite2D = null
var enemy_max_health_cache_clear_count := 0

## Slice C characterization: EncounterDefinition captures the run-gated enemy
## pool as validated, editor-inspectable data. It must reject bad weights/policy,
## gate late families by run rank, and reproduce the authored shadow-bound
## composition contract.

var _finished := false


func _initialize() -> void:
	create_timer(10.0).timeout.connect(_watchdog)
	var failures: Array[String] = []

	var definition := EncounterDefinition.new()
	_expect(definition.validate().is_empty(), "default encounter definition validates", failures)
	_expect(definition.grey_weight == 1.0 and definition.shadow_weight == 0.12, "defaults keep the authored neutral/shadow weights", failures)

	var late_run_1 := definition.late_pool_entries(1)
	_expect(late_run_1.is_empty(), "no late elemental families below run five", failures)
	var late_run_5 := definition.late_pool_entries(5)
	var authored_late_count := 0
	for variant in CatalogScript.ids():
		var authored_definition := CatalogScript.definition_resource(variant)
		if authored_definition != null and authored_definition.encounter_role == &"late" and authored_definition.encounter_min_run_number <= 5 and authored_definition.encounter_weight > 0.0:
			authored_late_count += 1
	_expect(late_run_5.size() == authored_late_count, "run five includes every authored late definition", failures)
	var late_names: Array[String] = []
	for entry in late_run_5: late_names.append(str(entry["variant"]))
	_expect("yellow" in late_names and "orange" in late_names and "aquamarine" in late_names and "crimson" in late_names, "run five pool includes yellow/ground/ice/crimson", failures)
	for entry in late_run_5:
		_expect(float(entry["weight"]) > 0.0, "%s late entry carries a positive weight" % str(entry["variant"]), failures)

	var skeleton_entries := EnemyFactoryScript.weighted_variants_for_type(&"skeleton")
	_expect(skeleton_entries.size() == 8, "catalog registers the normal and seven elemental skeleton variants", failures)
	var slime_runtime := SlimeRuntimeControllerScript.new() as SlimeRuntimeController
	var bone_frames := slime_runtime._skeleton_bone_projectile_frames()
	_expect(bone_frames.size() == 4, "bone projectile sheet loads four frames through the resource loader", failures)
	for frame in bone_frames:
		_expect(frame.get_size() == Vector2(5.0, 5.0), "bone projectile frame keeps its authored 5x5 dimensions", failures)
	var red_outline_color := PaletteLibrary.normal("red")
	var bone_outline_found := false
	for frame in bone_frames:
		var outline := slime_runtime._bone_projectile_outline_texture(frame, "red")
		if outline == null:
			continue
		_expect(outline.get_size() == Vector2(7.0, 7.0), "elemental bone outline adds a one-pixel transparent border", failures)
		var outline_image := outline.get_image()
		for y in outline_image.get_height():
			for x in outline_image.get_width():
				if outline_image.get_pixel(x, y).is_equal_approx(red_outline_color):
					bone_outline_found = true
	_expect(bone_outline_found, "elemental bone outline uses the element normal color", failures)
	_expect(slime_runtime._bone_projectile_outline_texture(bone_frames[0], "grey") == null, "normal bones remain unoutlined", failures)
	slime_runtime.free()
	var rooms := RoomController.new()
	rooms.progression_run_rank = 1
	rooms.progression_run_number = 4
	var skeleton_before_r5 := false
	var skeleton_slots_at_r5 := 0
	var total_slots_at_r5 := 0
	for seed in range(1, 513):
		var early_encounter := rooms._generate_enemy_encounter(seed, 1)
		for variant in early_encounter["variants"] as Array:
			skeleton_before_r5 = skeleton_before_r5 or EnemyFactoryScript.variant_is_type(StringName(variant), &"skeleton")
	rooms.progression_run_number = 5
	for seed in range(1, 513):
		var r5_encounter := rooms._generate_enemy_encounter(seed, 1)
		for variant in r5_encounter["variants"] as Array:
			total_slots_at_r5 += 1
			if EnemyFactoryScript.variant_is_type(StringName(variant), &"skeleton"):
				skeleton_slots_at_r5 += 1
	_expect(not skeleton_before_r5, "skeletons do not enter the regular pool before run rank five", failures)
	var skeleton_share_at_r5 := float(skeleton_slots_at_r5) / float(maxi(total_slots_at_r5, 1))
	_expect(skeleton_share_at_r5 >= 0.45 and skeleton_share_at_r5 <= 0.55, "run rank five and later enemy slots split evenly between skeletons and slimes at every room depth (observed %.1f%%)" % (skeleton_share_at_r5 * 100.0), failures)
	rooms.free()
	var actor_parent := Node2D.new()
	root.add_child(actor_parent)
	var before_slot := Node2D.new()
	before_slot.name = "BeforeEnemySlot"
	actor_parent.add_child(before_slot)
	var actor_slot := EnemyFactoryScript.assemble(EnemyFactoryScript.definition(&"grey"))
	actor_slot.name = "EnemySlot1"
	actor_parent.add_child(actor_slot)
	var after_slot := Node2D.new()
	after_slot.name = "AfterEnemySlot"
	actor_parent.add_child(after_slot)
	actor_slot.position = Vector2(17.0, 28.0)
	actor_slot.rotation = 0.3
	actor_slot.skew = 0.12
	actor_slot.z_index = 9
	actor_slot.z_as_relative = false
	actor_slot.scale = Vector2(1.4, 1.25)
	actor_slot.modulate = Color(0.4, 0.5, 0.6, 0.8)
	actor_slot.self_modulate = Color(0.7, 0.8, 0.9, 0.5)
	var actor_pool: Array[Sprite2D] = [actor_slot]
	_expect(actor_slot is SlimeActor and not actor_slot is SkeletonActor, "slime definition materializes the slime family beneath EnemyActor", failures)
	var roster := EnemyRoster.new()
	roster.replace_members(actor_pool)
	var original_slot_id := (actor_slot as EnemyActor).roster_slot_id
	var actor_sprites: Array[Sprite2D] = [actor_slot]
	var collision_sprites: Array[Sprite2D] = [actor_slot]
	var depth_sprites: Array[Sprite2D] = [actor_slot]
	var occluder_sprites: Array[Sprite2D] = [actor_slot]
	var hud := HudController.new()
	root.add_child(hud)
	var occlusion_renderer := OcclusionRenderer.new()
	root.add_child(occlusion_renderer)
	occlusion_renderer.occluders = occluder_sprites.duplicate()
	occlusion_renderer.original_actor_scales[actor_slot] = Vector2(2.0, 2.0)
	occlusion_renderer.actor_visual_scales[actor_slot] = Vector2(1.5, 1.5)
	var hud_children: Dictionary = {}
	for child_name: String in ["HpOverhead", "HpOverheadFill", "HpOverheadDamageFill", "AggroMarker", "EliteOverheadSymbol"]:
		var hud_child := Sprite2D.new()
		hud_child.name = child_name
		actor_slot.add_child(hud_child)
		hud_children[child_name] = hud_child
	var last_valid_positions: Dictionary = {actor_slot: Vector2(42.0, 84.0)}
	hud.target_overhead_frames[actor_slot] = hud_children["HpOverhead"]
	hud.target_overhead_fills[actor_slot] = hud_children["HpOverheadFill"]
	hud.target_overhead_damage_fills[actor_slot] = hud_children["HpOverheadDamageFill"]
	hud.target_overhead_aggro_markers[actor_slot] = hud_children["AggroMarker"]
	var spawn_services := EnemySpawnServicesScript.new() as RoomEnemySpawnServices
	spawn_services.slimes = actor_pool
	spawn_services.enemy_roster = roster
	spawn_services.actor_sprites = actor_sprites
	spawn_services.collision_sprites = collision_sprites
	spawn_services.depth_sprites = depth_sprites
	spawn_services.occluder_sprites = occluder_sprites
	spawn_services.last_valid_positions = last_valid_positions
	spawn_services.hud_controller = hud
	spawn_services.occlusion_renderer = occlusion_renderer
	spawn_services.enemy_health_damaged_callback = Callable(self, "_on_test_enemy_damaged")
	spawn_services.enemy_health_healed_callback = Callable(self, "_on_test_enemy_healed")
	spawn_services.enemy_health_changed_callback = Callable(self, "_on_test_enemy_health_changed")
	spawn_services.clear_enemy_max_health_cache = Callable(self, "_on_enemy_max_health_cache_cleared")
	var target_fixture := TargetFixture.new()
	target_fixture.current_target = actor_slot
	spawn_services.configure_slime_variant(actor_slot, "skeleton")
	_expect(actor_pool[0] is SkeletonActor, "selected skeleton definition replaces the pooled slime actor family", failures)
	var skeleton_slot := actor_pool[0]
	_expect(skeleton_slot is EnemyActor and not skeleton_slot is SlimeActor, "skeleton actor uses the EnemyActor sibling contract", failures)
	var skeleton_brain := skeleton_slot.get_node_or_null("Brain") as EnemyBrain
	_expect(skeleton_brain != null and skeleton_brain.behavior_component is SkeletonBrainBehaviorComponent, "Slime-to-Skeleton replacement installs and binds Skeleton brain behavior", failures)
	_expect((skeleton_slot as EnemyActor).roster_slot_id == original_slot_id and skeleton_slot.is_in_group("enemies") and not actor_slot.is_in_group("enemies"), "family replacement preserves slot identity and transfers enemies-group membership", failures)
	var combat_runtime := CombatRuntimeControllerScript.new() as CombatRuntimeController
	var skeleton_combat := skeleton_slot.get_node("Combat") as SlimeCombatComponent
	_expect(not combat_runtime.is_slime_dead(self, skeleton_slot), "generic enemy defeat query reads the cached combat capability", failures)
	skeleton_combat.dead = true
	_expect(combat_runtime.is_slime_dead(self, skeleton_slot), "generic enemy defeat query preserves the authoritative combat-dead state", failures)
	skeleton_combat.dead = false
	combat_runtime.free()
	var skeleton_slot_name := skeleton_slot.name
	_expect(skeleton_slot.texture != null and skeleton_slot.self_modulate == Color.WHITE, "replacement skeleton has artwork and clears the prior transient tint", failures)
	_expect(roster.slot_index(skeleton_slot) == 0 and roster.members[0] == spawn_services.slimes[0] and actor_sprites[0] == skeleton_slot and collision_sprites[0] == skeleton_slot and depth_sprites[0] == skeleton_slot and occluder_sprites[0] == skeleton_slot and occlusion_renderer.occluders[0] == skeleton_slot, "all actor, collision, depth, and occlusion lists follow family replacement", failures)
	_expect(skeleton_slot.get_index() == 1, "replacement remains at the same sibling index as its room slot", failures)
	_expect(skeleton_slot.position == Vector2(17.0, 28.0) and is_equal_approx(skeleton_slot.rotation, 0.3) and is_equal_approx(skeleton_slot.skew, 0.12) and skeleton_slot.z_index == 9 and not skeleton_slot.z_as_relative, "replacement preserves slot position, rotation, skew, and depth", failures)
	_expect(skeleton_slot.modulate == Color.WHITE and skeleton_slot.scale == Vector2.ONE, "replacement clears transient tint and uses the new family's authored scale", failures)
	var hud_children_migrated := true
	for child_name: String in hud_children.keys():
		hud_children_migrated = hud_children_migrated and (hud_children[child_name] as Node).get_parent() == skeleton_slot
	_expect(hud_children_migrated and hud.target_overhead_frames.has(skeleton_slot) and hud.target_overhead_fills.has(skeleton_slot) and hud.target_overhead_damage_fills.has(skeleton_slot) and hud.target_overhead_aggro_markers.has(skeleton_slot), "all five enemy HUD children and actor-keyed caches migrate", failures)
	_expect(not hud.target_overhead_frames.has(actor_slot) and not hud.target_overhead_fills.has(actor_slot) and not hud.target_overhead_damage_fills.has(actor_slot) and not hud.target_overhead_aggro_markers.has(actor_slot), "HUD caches release the replaced actor key", failures)
	_expect(not last_valid_positions.has(actor_slot) and last_valid_positions.get(actor_pool[0]) == Vector2(42.0, 84.0), "last valid walkable position follows the replacement actor", failures)
	_expect(not occlusion_renderer.original_actor_scales.has(actor_slot) and occlusion_renderer.original_actor_scales.get(actor_pool[0]) == Vector2.ONE, "family replacement starts from the new actor's authored scale", failures)
	_expect(occlusion_renderer.actor_visual_scales.get(skeleton_slot) == Vector2.ONE and occlusion_renderer.actor_occlusion_grace.has(skeleton_slot), "occlusion visual-scale and grace caches bind to the replacement", failures)
	_expect(enemy_max_health_cache_clear_count == 1, "family replacement invalidates the enemy max-health cache", failures)
	var replacement_health := skeleton_slot.get_node("Health") as HealthComponent
	replacement_health.reset(1.0)
	replacement_health.apply_damage(0.5)
	_expect(rebound_enemy_damage_count == 1 and rebound_enemy_damage_actor == skeleton_slot, "replacement actor health signal is rebound to its new actor identity", failures)
	await process_frame
	_expect(actor_parent.get_child(1) == skeleton_slot and actor_parent.get_child(2) == after_slot, "deferred deletion leaves the replacement in its original sibling order", failures)
	var targeting := TargetingRuntimeControllerScript.new() as TargetingRuntimeController
	_expect(targeting.valid_current_target(target_fixture) == null and target_fixture.current_target == null, "targeting clears a stale target after the replaced actor is freed", failures)
	spawn_services.configure_slime_variant(skeleton_slot, "grey")
	var returned_slime_slot := actor_pool[0]
	_expect(returned_slime_slot is SlimeActor and not returned_slime_slot is SkeletonActor, "skeleton-to-slime configuration restores the slime actor family", failures)
	var returned_slime_brain := returned_slime_slot.get_node_or_null("Brain") as EnemyBrain
	_expect(returned_slime_brain != null and returned_slime_brain.behavior_component is SlimeBrainBehaviorComponent, "Skeleton-to-Slime replacement restores and binds Slime brain behavior", failures)
	_expect((returned_slime_slot as EnemyActor).roster_slot_id == original_slot_id and returned_slime_slot.is_in_group("enemies") and not skeleton_slot.is_in_group("enemies"), "the return swap retains slot identity and removes the replaced family from enemies", failures)
	_expect(actor_pool.size() == 1 and actor_pool[0] == returned_slime_slot and actor_sprites[0] == returned_slime_slot and collision_sprites[0] == returned_slime_slot and depth_sprites[0] == returned_slime_slot and occluder_sprites[0] == returned_slime_slot, "Slime-to-Skeleton-to-Slime keeps one ordered room slot across every runtime list", failures)
	_expect(returned_slime_slot.get_index() == 1, "the returned slime remains at the same sibling index as its room slot", failures)
	_expect(hud.target_overhead_frames.has(returned_slime_slot) and hud.target_overhead_fills.has(returned_slime_slot) and hud.target_overhead_damage_fills.has(returned_slime_slot) and hud.target_overhead_aggro_markers.has(returned_slime_slot), "HUD actor caches rebind on the return family swap", failures)
	_expect(last_valid_positions.get(returned_slime_slot) == Vector2(42.0, 84.0) and occlusion_renderer.occluders[0] == returned_slime_slot, "position recovery and occlusion registration survive both family swaps", failures)
	_expect(enemy_max_health_cache_clear_count == 2, "return family swap also invalidates enemy max-health cache", failures)
	await process_frame
	_expect(actor_parent.get_child(1) == returned_slime_slot and actor_parent.get_child(2) == after_slot, "second deferred deletion keeps the returned slime in original sibling order", failures)
	var returned_health := returned_slime_slot.get_node("Health") as HealthComponent
	returned_health.reset(1.0)
	returned_health.apply_damage(0.25)
	_expect(rebound_enemy_damage_count == 2 and rebound_enemy_damage_actor == returned_slime_slot, "returned slime has health callbacks bound to its own actor identity", failures)
	print("ENEMY_SLOT_IDENTITY original=EnemySlot1 skeleton=%s slime=%s roster_index=0 sibling_index=%d" % [skeleton_slot_name, returned_slime_slot.name, returned_slime_slot.get_index()])
	targeting.free()
	actor_parent.free()
	hud.free()
	occlusion_renderer.free()

	var bad := EncounterDefinition.new()
	bad.matchup_policy = "not_a_policy"
	_expect(not bad.validate().is_empty(), "unknown matchup policy is rejected", failures)
	var bad_weight := EncounterDefinition.new()
	bad_weight.grey_weight = -1.0
	_expect(not bad_weight.validate().is_empty(), "negative weight is rejected", failures)

	var shadow := EncounterDefinition.new()
	shadow.matchup_policy = EncounterDefinition.POLICY_SHADOW_BOUND
	_expect(shadow.is_shadow_bound(), "shadow-bound policy is recognized", failures)
	_expect(shadow.shadow_bound_normal_weight == 0.20 and shadow.shadow_bound_variant_weight == 0.80, "shadow-bound relief contract is preserved", failures)

	_finished = true
	call_deferred("_finish", failures)


func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: encounter definition failed before completion")
	quit(1)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ENCOUNTER_DEFINITION_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _on_test_enemy_damaged(_amount: float, actor: Sprite2D) -> void:
	rebound_enemy_damage_count += 1
	rebound_enemy_damage_actor = actor


func _on_test_enemy_healed(_amount: float, _actor: Sprite2D) -> void:
	pass


func _on_test_enemy_health_changed(_current: float, _maximum: float, _actor: Sprite2D) -> void:
	pass


func _on_enemy_max_health_cache_cleared() -> void:
	enemy_max_health_cache_clear_count += 1


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
