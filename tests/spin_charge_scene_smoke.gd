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
		_expect(not attack.has_lunge(), "spin attack does not use the forward combo lunge", failures)
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
		gameplay.call("_interrupt_player_attack")
		gameplay.set("player_between_timer", 0.0)
		attack.set_attack_input_held(true)
		_expect(attack.start_player_attack(gameplay, 1), "a held attack begins with attack 1", failures)
		for _frame in animation.attack_frames.size():
			animation.tick_coordinator_animation(gameplay, 0.10)
		_expect(attack.is_charging() and StringName(gameplay.get("player_anim_name")) == &"charge", "holding attack enters the post-attack charge pose", failures)
		_expect(player.visible and not (gameplay.get("player_attack_visual") as Sprite2D).visible, "charge pose restores the base player layer", failures)
		attack.tick_charge(gameplay, tuning.charge_minimum_time)
		attack.set_attack_input_held(false)
		attack.tick_charge(gameplay, 0.01)
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


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SPIN_CHARGE_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
