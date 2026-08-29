extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for spin and charge coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 90:
		await process_frame
	_hide_modal_screens(gameplay)
	var attack := gameplay.get("player_attack_component") as PlayerAttackComponent
	var animation := gameplay.get("player_animation_component") as PlayerAnimationComponent
	var equipment := gameplay.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	var player := gameplay.get("player") as Sprite2D
	var tuning := gameplay.get("player_tuning") as PlayerTuning
	_expect(attack != null and animation != null and equipment != null and player != null and tuning != null, "spin and charge components are composed", failures)
	if attack != null and animation != null and equipment != null and player != null and tuning != null:
		var guide := player.get_node_or_null("SpinAttackHitboxShape") as AttackHitboxGuide
		_expect(guide != null and guide.use_frame_hitboxes, "spin attack uses scene-authored per-frame hitboxes", failures)
		_expect(animation.spin_frames.size() == 8 and animation.spin_left_frames.size() == 8, "spin body has eight right and left frames", failures)
		var input_router := gameplay.get("input_router") as InputRouter
		if input_router != null:
			input_router.set("_movement", Vector2.RIGHT)
		if guide != null:
			for frame_index in 8:
				var frame_hitbox := guide.get_node_or_null("HitboxFrame%d" % frame_index) as Polygon2D
				_expect(frame_hitbox != null and frame_hitbox.polygon.size() >= 3, "spin frame %d exposes an editable polygon" % frame_index, failures)
				_expect(guide.hitbox_for_frame(frame_index) == frame_hitbox, "spin frame %d resolves its own polygon" % frame_index, failures)
			var frame_three_polygon := guide.world_polygon(false, 3)
			var frame_six_polygon := guide.world_polygon(false, 6)
			_expect(frame_three_polygon.size() >= 3 and frame_six_polygon.size() >= 3, "active spin frames return world polygons", failures)
			_expect(frame_three_polygon != frame_six_polygon, "different spin frames remain independently editable", failures)
		attack.set_attack_input_held(false)
		_expect(attack.start_spin_attack(gameplay), "spin attack can start with the supplied animation", failures)
		_expect(attack.is_spin_attack() and StringName(gameplay.get("player_anim_name")) == &"spin_attack", "spin attack owns its animation state", failures)
		_expect(attack.has_lunge() and attack.spin_direction.is_equal_approx(Vector2.RIGHT), "spin attack snapshots the input direction for a small lunge", failures)
		gameplay.set("player_between_timer", 0.4)
		attack.buffer_combo(1.0)
		_expect(attack.start_spin_attack(gameplay), "spin attack can start while a prior combo recovery is pending", failures)
		_expect(is_zero_approx(float(gameplay.get("player_between_timer"))) and not attack.combo_buffered, "spin attack clears combo and recovery state", failures)
		for frame_index in range(tuning.spin_hit_start_frame, tuning.spin_hit_end_frame + 1):
			gameplay.set("player_anim_frame", frame_index)
			animation.apply_frame(gameplay)
			var polygon := attack.attack_polygon(gameplay)
			_expect(polygon.size() >= 3, "spin frame %d uses its scene polygon at runtime" % frame_index, failures)
			equipment.tick(gameplay, 0.0)
			var sword_front := equipment.layers.get("EquipmentSwordFront") as Sprite2D
			_expect(sword_front != null and sword_front.visible and String(sword_front.get_meta("mp_grey_key", "")) == "sword_front_spin", "spin frame %d keeps the sword front layer aligned" % frame_index, failures)
		player.flip_h = true
		gameplay.set("player_attack_flip_h", true)
		gameplay.set("player_anim_frame", tuning.spin_hit_start_frame)
		animation.apply_frame(gameplay)
		equipment.tick(gameplay, 0.0)
		var left_sword_front := equipment.layers.get("EquipmentSwordFront") as Sprite2D
		var left_sword_back := equipment.layers.get("EquipmentSwordBack") as Sprite2D
		_expect(left_sword_front != null and left_sword_front.flip_h and left_sword_back != null and left_sword_back.flip_h, "spin equipment mirrors both sword layers when facing left", failures)
		player.flip_h = false
		gameplay.set("player_attack_flip_h", false)
		for _frame in 40:
			animation.tick_coordinator_animation(gameplay, 0.10)
		_expect(not bool(gameplay.get("player_is_attacking")) and is_zero_approx(float(gameplay.get("player_between_timer"))), "spin attack finishes without a combo recovery", failures)
		_expect(StringName(gameplay.get("player_anim_name")) == &"idle", "spin attack returns directly to idle", failures)
		equipment.tick(gameplay, 0.0)
		_expect(not equipment.was_attacking and is_zero_approx(equipment.transition_hold_timer), "spin completion clears equipment recovery hold", failures)
		var frame_controller := gameplay.get("gameplay_frame_controller") as GameplayFrameController
		_expect(frame_controller != null, "gameplay frame controller is available for spin transition coverage", failures)
		if frame_controller != null:
			_expect(attack.start_spin_attack(gameplay), "spin can be completed through the gameplay frame controller", failures)
			gameplay.set("player_anim_frame", animation.spin_frames.size() - 1)
			gameplay.set("player_anim_timer", 1.0)
			frame_controller.tick(gameplay, 0.0)
			_expect(StringName(gameplay.get("player_anim_name")) == &"idle" and is_zero_approx(float(gameplay.get("player_between_timer"))), "frame controller does not append recovery after spin", failures)
			_expect(not equipment.was_attacking and is_zero_approx(equipment.transition_hold_timer), "frame controller keeps spin equipment in idle after completion", failures)
		gameplay.call("_interrupt_player_attack")
		gameplay.set("player_between_timer", 0.0)
		attack.set_attack_input_held(true)
		_expect(attack.start_player_attack(gameplay, 1), "a held attack begins with attack 1", failures)
		for _frame in animation.attack_frames.size():
			animation.tick_coordinator_animation(gameplay, 0.10)
		_expect(attack.is_charging() and StringName(gameplay.get("player_anim_name")) == &"charge", "holding attack enters the post-attack charge pose", failures)
		_expect(player.visible and not (gameplay.get("player_attack_visual") as Sprite2D).visible, "charge pose restores the base player layer", failures)
		_expect(player.texture == animation.between_attack_texture, "charge uses the authored between-attacks pose", failures)
		var effects := gameplay.get("effects_spawner") as EffectsSpawner
		_expect(effects != null, "charge effect spawner is composed", failures)
		if effects != null:
			effects.update_charge_aura_from_root(gameplay, 0.0)
			var initial_aura_count := _charge_aura_count(effects)
			# Advance past the one-second cap so the test observes the authored
			# peak even when the fixture's AGI charge multiplier is below 1.0.
			attack.tick_charge(gameplay, 1.10)
			effects.update_charge_aura_from_root(gameplay, 0.20)
			var peak_aura_count := _charge_aura_count(effects)
			var peak_streak_visible := false
			var aura_is_white := true
			for particle_data in effects.pixel_particles:
				if particle_data.get("effect_tag", &"") == EffectsSpawner.CHARGE_AURA_TAG and float(particle_data.get("charge_progress", 0.0)) >= 0.90:
					var particle := particle_data.get("sprite") as Sprite2D
					aura_is_white = aura_is_white and particle != null and is_equal_approx(particle.modulate.r, 1.0) and is_equal_approx(particle.modulate.g, 1.0) and is_equal_approx(particle.modulate.b, 1.0)
					peak_streak_visible = particle != null and is_equal_approx(particle.scale.y, 2.0)
					if peak_streak_visible:
						break
			_expect(initial_aura_count > 0, "charge aura emits its initial foot wisp", failures)
			_expect(peak_aura_count > initial_aura_count, "charge aura increases its particle cadence near peak", failures)
			_expect(peak_streak_visible, "charge aura stretches a peak particle into an air streak", failures)
			_expect(aura_is_white, "charge aura particles remain neutral white", failures)
			var ready_highlight := effects.charge_ready_highlight
			var expected_highlight := PaletteLibrary.accent(str(gameplay.get("current_player_palette_name")))
			_expect(ready_highlight != null and ready_highlight.visible, "charge cap shows the player ready highlight", failures)
			_expect(ready_highlight != null and is_equal_approx(ready_highlight.modulate.r, expected_highlight.r) and is_equal_approx(ready_highlight.modulate.g, expected_highlight.g) and is_equal_approx(ready_highlight.modulate.b, expected_highlight.b), "charge ready highlight uses the active player accent", failures)
		var charge_grey_set := animation.frames_by_palette.get("grey", {}) as Dictionary
		var charge_grey := charge_grey_set.get("between") as Texture2D
		var base_mp_material := gameplay.get("mp_desaturation_material") as ShaderMaterial
		_expect(base_mp_material != null and base_mp_material.get_shader_parameter("grey_texture") == charge_grey, "charge assigns its grey reference frame to the visible base layer", failures)
		# Chroma changes should alter only the desaturation amount. They must never
		# change the authored charge pose or make the base layer sample a stale
		# attack frame.
		var chroma := gameplay.get("player_chroma_component") as Node
		var charge_texture := player.texture
		for chroma_value in [100, 50, 10, 0]:
			if chroma != null:
				chroma.call("_set_chroma", chroma_value)
			gameplay.call("_update_mp_desaturation")
			base_mp_material = gameplay.get("mp_desaturation_material") as ShaderMaterial
			_expect(player.texture == charge_texture and player.texture == animation.between_attack_texture, "charge pose stays on one authored frame at %d Chroma" % chroma_value, failures)
			_expect(base_mp_material != null and base_mp_material.get_shader_parameter("grey_texture") == charge_grey, "charge grey reference stays aligned at %d Chroma" % chroma_value, failures)
		# A flame/chroma change can happen while the attack button remains held.
		# The active pose must be refreshed in the new palette rather than leaving
		# the previous palette's attack frame frozen on the player.
		gameplay.call("_apply_player_palette_async", "red")
		_expect(player.texture == animation.between_attack_texture, "charge refreshes its between-attacks pose after a palette change", failures)
		gameplay.call("_apply_player_palette_async", "blue")
		_expect(player.texture == animation.between_attack_texture, "charge keeps the between-attacks pose when returning to water chroma", failures)
		gameplay.set("player_anim_name", "attack1")
		animation.tick_coordinator_animation(gameplay, 0.0)
		_expect(StringName(gameplay.get("player_anim_name")) == &"charge" and player.texture == animation.between_attack_texture, "charging state repairs a stale attack animation name", failures)
		attack.tick_charge(gameplay, tuning.charge_minimum_time)
		attack.set_attack_input_held(false)
		attack.tick_charge(gameplay, 0.01)
		if effects != null:
			effects.update_charge_aura_from_root(gameplay, 0.0)
			_expect(_charge_aura_count(effects) == 0, "charge aura clears when the hold becomes charged Attack 2", failures)
			_expect(effects.charge_ready_highlight == null or not effects.charge_ready_highlight.visible, "charge ready highlight clears when the attack releases", failures)
		_expect(attack.is_charged_attack2() and attack.variant == 2 and StringName(gameplay.get("player_anim_name")) == &"attack2_charged", "releasing a charged hold starts charged attack 2", failures)
		_expect(attack.special_knockback_multiplier(tuning) > 1.0 and attack.knockback_multiplier(tuning) > 1.0, "charged attack 2 has stronger knockback than regular attack 2", failures)
		_expect(tuning.charged_attack2_damage_multiplier > tuning.attack2_damage_multiplier and tuning.charged_attack2_frame_time_multiplier > 1.0, "charged attack 2 is stronger and slower by tuning", failures)
		equipment.tick(gameplay, 0.0)
		var charged_sword := equipment.layers.get("EquipmentSwordFront") as Sprite2D
		_expect(charged_sword != null and charged_sword.visible and String(charged_sword.get_meta("mp_grey_key", "")) == "sword_front_attack2", "charged attack 2 keeps normal front equipment layering", failures)
		for _frame in animation.attack2_frames.size():
			animation.tick_coordinator_animation(gameplay, 0.20)
		_expect(not bool(gameplay.get("player_is_attacking")) and float(gameplay.get("player_between_timer")) > 0.0, "charged attack 2 finishes through the normal finisher recovery", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _hide_modal_screens(gameplay: Node) -> void:
	var screens := gameplay.get("screen_state_controller") as Node
	if screens == null:
		return
	for property_name in [&"title_overlay", &"archetype_overlay", &"hub_overlay", &"run_complete_overlay", &"save_select_overlay"]:
		var overlay := screens.get(property_name) as CanvasItem
		if overlay != null:
			overlay.visible = false
	screens.set("title_transition_active", false)
	screens.set("hub_pause_mode", false)
	screens.call("set_state", &"gameplay")


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _charge_aura_count(effects: EffectsSpawner) -> int:
	var count := 0
	for particle_data in effects.pixel_particles:
		if particle_data.get("effect_tag", &"") == EffectsSpawner.CHARGE_AURA_TAG:
			count += 1
	return count


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SPIN_CHARGE_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
