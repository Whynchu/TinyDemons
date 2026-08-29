extends SceneTree


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for attack shadow coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 90:
		await process_frame
	var attack := gameplay.get("player_attack_component") as PlayerAttackComponent
	var animation := gameplay.get("player_animation_component") as PlayerAnimationComponent
	var equipment := gameplay.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	var chroma := gameplay.get("player_chroma_component") as Node
	var attack_visual := gameplay.get("player_attack_visual") as Sprite2D
	var player := gameplay.get("player") as Sprite2D
	var player_shadow := gameplay.get("player_shadow") as Sprite2D
	var sprite_shadow := gameplay.get("player_sprite_shadow") as Sprite2D
	var frame_controller := gameplay.get("gameplay_frame_controller") as GameplayFrameController
	_expect(attack != null and animation != null and equipment != null and chroma != null and frame_controller != null, "attack presentation components are composed", failures)
	if attack != null and animation != null and equipment != null and chroma != null and frame_controller != null and attack_visual != null and player != null and player_shadow != null and sprite_shadow != null:
		_hide_modal_screens(gameplay)
		gameplay.call("_update_player_shadow")
		_expect(player_shadow.visible, "the player's ground shadow is visible while the player is visible", failures)
		_expect(sprite_shadow.visible, "the player's sprite drop shadow is visible while idle", failures)
		_expect(sprite_shadow.texture == player.texture, "idle sprite shadow follows the base player frame", failures)
		_expect(sprite_shadow.global_position.is_equal_approx(player.global_position + Vector2(-0.5, 0.0)), "idle sprite shadow keeps the half-pixel left offset", failures)
		chroma.set("current_chroma", 0)
		gameplay.call("_update_mp_desaturation")
		attack.start_player_attack(gameplay, 1)
		gameplay.call("_update_player_shadow")
		_expect(not player.visible and attack_visual.visible, "attack 1 exposes only the attack render layer", failures)
		_expect(sprite_shadow.texture == attack_visual.texture, "sprite shadow follows the active attack frame", failures)
		_expect(sprite_shadow.global_position.is_equal_approx(attack_visual.global_position + Vector2(-0.5, 0.0)), "sprite shadow follows the attack layer position", failures)
		_expect(sprite_shadow.visible, "sprite shadow remains visible while the attack layer is active", failures)
		var grey_set := animation.get("frames_by_palette").get("grey", {}) as Dictionary
		var grey_attack: Array = grey_set.get("attack", [])
		var attack_material := attack_visual.material as ShaderMaterial
		var player_material := player.material as ShaderMaterial
		_expect(attack_material != null and not grey_attack.is_empty() and attack_material.get_shader_parameter("grey_texture") == grey_attack[0], "empty-MP attack uses its matching grey frame", failures)
		_expect(player_material != null and player_material != attack_material, "base and attack layers use independent MP materials", failures)
		_expect(sprite_shadow.material == null, "attack shadow does not inherit the attack layer MP material", failures)
		_expect(sprite_shadow.self_modulate.is_equal_approx(Color(0.0, 0.0, 0.0, 0.25)), "attack shadow uses the equipment-style black silhouette tint", failures)
		for frame_index in grey_attack.size():
			gameplay.set("player_anim_name", "attack1")
			gameplay.set("player_anim_frame", frame_index)
			animation.apply_frame(gameplay)
			gameplay.call("_update_player_shadow")
			_expect(attack_visual.material.get_shader_parameter("grey_texture") == grey_attack[frame_index], "empty-MP attack keeps grey frame %d synchronized" % frame_index, failures)
			_expect(sprite_shadow.material == null, "empty-MP attack shadow stays independent of the grey shader at frame %d" % frame_index, failures)
			_expect(not player.visible and attack_visual.visible, "attack frame %d keeps the base layer hidden" % frame_index, failures)
		var visible_equipment_layers := 0
		var equipment_grey_set := equipment.get("frames_by_palette").get("grey", {}) as Dictionary
		for layer_name in equipment.layers:
			var layer := equipment.layers[layer_name] as Sprite2D
			if layer == null or not layer.visible:
				continue
			visible_equipment_layers += 1
			var layer_material := layer.material as ShaderMaterial
			var grey_key := String(layer.get_meta("mp_grey_key", ""))
			var grey_frame := int(layer.get_meta("mp_grey_frame", 0))
			var grey_frames: Array = equipment_grey_set.get(grey_key, [])
			var layer_matches: bool = layer_material != null and not grey_frames.is_empty() and layer_material.get_shader_parameter("grey_texture") == grey_frames[mini(grey_frame, grey_frames.size() - 1)]
			if not layer_matches:
				print("EQUIPMENT_MISMATCH layer=%s key=%s frame=%d material=%s grey_count=%d grey_keys=%s expected=%s actual=%s" % [layer.name, grey_key, grey_frame, layer_material, grey_frames.size(), equipment_grey_set.keys(), grey_frames[mini(grey_frame, grey_frames.size() - 1)] if not grey_frames.is_empty() else null, layer_material.get_shader_parameter("grey_texture") if layer_material != null else null])
			_expect(layer_matches, "empty-MP equipment layer keeps its matching grey frame", failures)
		_expect(visible_equipment_layers > 0, "attack presentation has visible equipment layers", failures)
		gameplay.call("_interrupt_player_attack")
		_expect(player.visible and not attack_visual.visible, "interrupt restores the base render layer", failures)
		_expect(sprite_shadow.texture == player.texture, "interrupt restores the base sprite shadow", failures)
		_expect(sprite_shadow.visible, "interrupt restores the visible base sprite shadow", failures)
		for chroma_value in [25, 50, 75]:
			_run_reduced_chroma_attack_case(gameplay, frame_controller, attack, animation, chroma, player, sprite_shadow, 1, &"between", chroma_value, failures)
			_run_reduced_chroma_attack_case(gameplay, frame_controller, attack, animation, chroma, player, sprite_shadow, 2, &"after", chroma_value, failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


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


func _run_reduced_chroma_attack_case(
	gameplay: Node,
	frame_controller: GameplayFrameController,
	attack: PlayerAttackComponent,
	animation: PlayerAnimationComponent,
	chroma: Node,
	player: Sprite2D,
	sprite_shadow: Sprite2D,
	variant: int,
	transition_name: StringName,
	chroma_value: int,
	failures: Array[String]
) -> void:
	gameplay.call("_interrupt_player_attack")
	gameplay.set("player_between_timer", 0.0)
	chroma.set("current_chroma", chroma_value)
	gameplay.call("_update_mp_desaturation")
	attack.start_player_attack(gameplay, variant)
	var attack_frame_count := animation.attack2_frames.size() if variant == 2 else animation.attack_frames.size()
	for _step in attack_frame_count:
		frame_controller.tick(gameplay, 0.1)
	var material := player.material as ShaderMaterial
	var grey_set := animation.get("frames_by_palette").get("grey", {}) as Dictionary
	var expected_transition_grey := grey_set.get(String(transition_name)) as Texture2D
	_expect(bool(gameplay.get("player_between_timer")) and StringName(gameplay.get("player_anim_name")) == transition_name, "reduced-Chroma attack %d enters its %s transition at %d MP" % [variant, transition_name, chroma_value], failures)
	_expect(material != null and material.get_shader_parameter("grey_texture") == expected_transition_grey, "reduced-Chroma attack %d keeps its %s grey frame synchronized at %d MP" % [variant, transition_name, chroma_value], failures)
	_expect(sprite_shadow.visible and sprite_shadow.texture == player.texture, "reduced-Chroma attack %d keeps the visible transition shadow synchronized at %d MP" % [variant, chroma_value], failures)
	frame_controller.tick(gameplay, 0.2)
	var idle_material := player.material as ShaderMaterial
	var idle_grey_frames := grey_set.get("idle", []) as Array[Texture2D]
	_expect(String(gameplay.get("player_anim_name")) == "idle" and float(gameplay.get("player_between_timer")) <= 0.0, "reduced-Chroma attack %d returns to idle after its transition at %d MP" % [variant, chroma_value], failures)
	_expect(idle_material != null and not idle_grey_frames.is_empty() and idle_material.get_shader_parameter("grey_texture") == idle_grey_frames[0], "reduced-Chroma attack %d restores the idle grey frame after transition at %d MP" % [variant, chroma_value], failures)
	_expect(sprite_shadow.visible and sprite_shadow.texture == player.texture, "reduced-Chroma attack %d keeps the idle shadow visible after transition at %d MP" % [variant, chroma_value], failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("ATTACK_SHADOW_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
