extends SceneTree

const Chroma = preload("res://scripts/player_chroma_component.gd")
const Elements = preload("res://scripts/element_catalog.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for IMBUE coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 30:
		await process_frame
	var runtime := gameplay.get("magic_runtime_controller") as MagicRuntimeController
	var chroma := gameplay.get("player_chroma_component") as Node
	var ability := gameplay.get("player_aspect_ability_component") as Node
	var equipment := gameplay.get("player_equipment_visual_component") as PlayerEquipmentVisualComponent
	var projectiles := gameplay.get("magic_projectile_controller") as MagicProjectileController
	_expect(runtime != null and chroma != null, "IMBUE runtime owners are installed", failures)
	if runtime == null or chroma == null:
		gameplay.queue_free()
		await process_frame
		_finish(failures)
		return

	var hud := gameplay.get("hud_controller") as HudController
	_expect(hud != null and hud.cooldown_hud.size() == 6, "HUD builds both cooldown icon widgets", failures)
	if hud != null and hud.cooldown_hud.size() == 6:
		var magic_icon := hud.cooldown_hud["magic_icon"] as Sprite2D
		var imbue_icon := hud.cooldown_hud["imbue_icon"] as Sprite2D
		var magic_timer := hud.cooldown_hud["magic_timer"] as Sprite2D
		var imbue_timer := hud.cooldown_hud["imbue_timer"] as Sprite2D
		var magic_shadow := hud.cooldown_hud["magic_timer_shadow"] as Sprite2D
		var imbue_shadow := hud.cooldown_hud["imbue_timer_shadow"] as Sprite2D
		_expect(magic_icon != null and imbue_icon != null and magic_icon.texture != null and imbue_icon.texture != null, "cooldown icons load their authored 16x16 art", failures)
		_expect(magic_icon.texture.get_size().is_equal_approx(Vector2(16, 16)) and imbue_icon.texture.get_size().is_equal_approx(Vector2(16, 16)), "cooldown icons preserve their native pixel size", failures)
		_expect(magic_icon.position.is_equal_approx(Vector2(84, 0)) and imbue_icon.position.is_equal_approx(Vector2(102, 0)), "cooldown icons align beside the player status strip", failures)
		_expect(magic_icon.material is ShaderMaterial and imbue_icon.material is ShaderMaterial, "cooldown icons use independent radial shader materials", failures)
		hud.update_cooldown_hud(gameplay)
		_expect(not magic_timer.visible and not imbue_timer.visible and not magic_shadow.visible and not imbue_shadow.visible, "ready cooldown icons hide their countdown text", failures)
		var imbue_material := imbue_icon.material as ShaderMaterial
		_expect(imbue_material != null and is_zero_approx(float(imbue_material.get_shader_parameter("cooldown_ratio"))), "ready IMBUE icon has no radial cooldown coverage", failures)
		chroma.call("attune", Chroma.Aspect.FIRE)
		gameplay.set("current_player_palette_name", "red")
		hud.update_cooldown_hud(gameplay)
		var imbue_palette_textures: Dictionary = imbue_icon.get_meta("cooldown_palette_textures", {}) as Dictionary
		_expect(imbue_icon.texture == imbue_palette_textures.get("red"), "cooldown icons recolor from the active player Chroma palette", failures)
		runtime.set("imbue_cooldown_remaining", 2.0)
		hud.update_cooldown_hud(gameplay)
		_expect(imbue_timer.visible and imbue_shadow.visible and imbue_timer.texture != null and imbue_timer.texture.get_size().is_equal_approx(Vector2(14, 5)), "cooling IMBUE icon shows its centered compact countdown", failures)
		_expect(imbue_material != null and is_equal_approx(float(imbue_material.get_shader_parameter("cooldown_ratio")), 0.1), "IMBUE radial coverage follows remaining cooldown", failures)
		runtime.set("imbue_cooldown_remaining", 0.0)
		hud.update_cooldown_hud(gameplay)
		_expect(not imbue_timer.visible and is_zero_approx(float(imbue_material.get_shader_parameter("cooldown_ratio"))), "ready IMBUE icon clears its timer and radial coverage", failures)
		chroma.call("spend_chroma", 80)
		hud.update_cooldown_hud(gameplay)
		_expect(is_equal_approx(float(imbue_material.get_shader_parameter("unavailable")), 1.0), "unavailable IMBUE icon stays greyed without a countdown", failures)
		chroma.call("attune", Chroma.Aspect.FIRE)
		hud.update_cooldown_hud(gameplay)

	chroma.call("attune", Chroma.Aspect.FIRE)
	var accepted := bool(runtime.call("update_magic_input", gameplay, true, false, 0.0))
	_expect(not accepted and bool(gameplay.get("player_is_magic_casting")) and int(gameplay.get("player_anim_frame")) == 0, "triangle press starts the shared magic animation immediately", failures)
	accepted = bool(runtime.call("update_magic_input", gameplay, false, true, 0.0))
	_expect(accepted and bool(gameplay.get("player_is_magic_casting")) and projectiles.projectiles.is_empty(), "short triangle press starts the normal spell", failures)
	if hud != null:
		hud.update_cooldown_hud(gameplay)
		var magic_icon := hud.cooldown_hud["magic_icon"] as Sprite2D
		var magic_material := magic_icon.material as ShaderMaterial if magic_icon != null else null
		_expect(magic_material != null and float(magic_material.get_shader_parameter("flash_strength")) > 0.0, "normal magic activation briefly highlights its cooldown icon", failures)
	var normal_frame_time := float(runtime.call("magic_frame_time", gameplay))
	runtime.call("tick_magic_animation", gameplay, normal_frame_time * 2.01)
	_expect(not projectiles.projectiles.is_empty(), "short triangle press reaches the normal projectile frame", failures)
	runtime.call("cancel_magic_animation", gameplay)
	gameplay.set("player_is_magic_casting", false)
	if ability != null:
		ability.set("cooldown_remaining", 0.0)
	if projectiles != null:
		projectiles.clear()

	# Exercise the real input-router/frame-controller input path as well as the
	# direct runtime path.
	# Once the first press starts the shared animation, the regular player lock
	# must not stop Triangle from being polled for the hold-to-IMBUE decision.
	var frame_controller := gameplay.get("gameplay_frame_controller") as GameplayFrameController
	var input_router := gameplay.get("input_router") as InputRouter
	if frame_controller != null and input_router != null:
		Input.action_release(&"magic")
		input_router.poll(InputRouter.Context.GAMEPLAY)
		chroma.call("attune", Chroma.Aspect.FIRE)
		Input.action_press(&"magic")
		input_router.poll(InputRouter.Context.GAMEPLAY)
		frame_controller.update_player_input(gameplay, 0.0)
		_expect(bool(gameplay.get("player_is_magic_casting")), "live Triangle press enters the shared animation", failures)
		input_router.poll(InputRouter.Context.GAMEPLAY)
		frame_controller.call("_update_magic_input", gameplay, 0.36)
		_expect(bool(runtime.get("magic_animation_is_imbue")), "live held Triangle reaches IMBUE while magic animation is locked", failures)
		Input.action_release(&"magic")
		input_router.poll(InputRouter.Context.GAMEPLAY)
		frame_controller.call("_update_magic_input", gameplay, 0.0)
		_expect(not bool(runtime.get("magic_hold_active")), "releasing Triangle closes the IMBUE decision window", failures)
		runtime.call("cancel_magic_animation", gameplay)
		gameplay.set("player_is_magic_casting", false)

	chroma.call("attune", Chroma.Aspect.FIRE)
	accepted = bool(runtime.call("update_magic_input", gameplay, true, false, 0.0))
	_expect(not accepted, "IMBUE hold begins as a candidate", failures)
	accepted = bool(runtime.call("update_magic_input", gameplay, true, true, 0.36))
	_expect(accepted and bool(runtime.get("magic_animation_is_imbue")) and projectiles.projectiles.is_empty(), "holding triangle commits IMBUE without a projectile", failures)
	_expect(int(chroma.get("current_chroma")) == 100, "IMBUE waits to charge mana until its effect frame", failures)
	var frame_time := float(runtime.call("magic_frame_time", gameplay))
	# Simulate an unrelated animation transition trying to restore an idle frame
	# while the IMBUE animation is still active.
	gameplay.set("player_anim_name", "idle")
	runtime.call("tick_magic_animation", gameplay, frame_time * 1.01)
	_expect(String(gameplay.get("player_anim_name")) == "magic", "IMBUE reasserts its animation after a stale state", failures)
	for _frame in 3:
		runtime.call("tick_magic_animation", gameplay, frame_time * 1.01)
	_expect(int(gameplay.get("player_anim_frame")) == 4, "IMBUE reaches its fifth displayed frame", failures)
	_expect(int(chroma.get("current_chroma")) == 60, "IMBUE spends exactly 40 mana on frame five", failures)
	_expect(int(runtime.get("imbued_element")) == Elements.Element.FIRE, "IMBUE snapshots the active element", failures)
	_expect(absf(float(runtime.get("imbue_remaining")) - 15.0) < 0.1, "IMBUE starts its fifteen second duration", failures)
	_expect(absf(float(runtime.get("imbue_cooldown_remaining")) - 20.0) < 0.1, "IMBUE starts its twenty second cooldown", failures)
	if equipment != null:
		equipment.tick(gameplay, 0.0)
		_expect(int(equipment.get("imbue_element")) == Elements.Element.FIRE, "weapon visual stores the imbued element", failures)
		_expect((equipment.get("imbue_outline_overlays") as Dictionary).size() > 0, "weapon visual creates an elemental outline overlay", failures)
	for _frame in 5:
		runtime.call("tick_magic_animation", gameplay, frame_time * 1.01)
	_expect(not bool(gameplay.get("player_is_magic_casting")), "IMBUE returns to normal animation after the held final frame", failures)
	if equipment != null:
		# Force both sword layers visible so the overlay depth follows each source
		# layer, not one shared depth above the player.
		gameplay.set("player_is_attacking", true)
		gameplay.set("player_anim_name", "attack1")
		gameplay.set("player_anim_frame", 0)
		equipment.tick(gameplay, 0.0)
		var equipment_layers: Dictionary = equipment.get("layers") as Dictionary
		var outline_overlays: Dictionary = equipment.get("imbue_outline_overlays") as Dictionary
		var player := gameplay.get("player") as Sprite2D
		var sword_back := equipment_layers.get("EquipmentSwordBack") as Sprite2D
		var sword_front := equipment_layers.get("EquipmentSwordFront") as Sprite2D
		var back_outline := outline_overlays.get(sword_back) as Sprite2D
		var front_outline := outline_overlays.get(sword_front) as Sprite2D
		_expect(back_outline != null and back_outline.z_index == sword_back.z_index and back_outline.z_index < player.z_index, "back sword imbue outline stays behind the player", failures)
		_expect(front_outline != null and front_outline.z_index == sword_front.z_index and front_outline.z_index > player.z_index, "front sword imbue outline follows the front sword", failures)
		gameplay.set("player_is_attacking", false)
		gameplay.set("player_anim_name", "idle")
		gameplay.set("player_anim_frame", 0)
		equipment.tick(gameplay, 0.0)
	var imbue_before_room_reset := float(runtime.get("imbue_remaining"))
	gameplay.call("_reset_magic_runtime")
	if equipment != null:
		equipment.reset_for_room(gameplay)
	_expect(int(runtime.get("imbued_element")) == Elements.Element.FIRE, "room reset preserves the active IMBUE element", failures)
	_expect(absf(float(runtime.get("imbue_remaining")) - imbue_before_room_reset) < 0.1, "room reset preserves the active IMBUE timer", failures)
	_expect(int(gameplay.call("_player_weapon_element")) == Elements.Element.FIRE, "weapon attacks retain IMBUE after a room reset", failures)
	if equipment != null:
		_expect(int(equipment.get("imbue_element")) == Elements.Element.FIRE, "room reset restores the imbued weapon visual", failures)

	var attack := gameplay.get("player_attack_component") as PlayerAttackComponent
	if attack != null:
		attack.start_player_attack(gameplay, 1)
		_expect(int(attack.get("attack_element")) == Elements.Element.FIRE, "next weapon swing uses the imbued element", failures)
		attack.cancel()
		gameplay.set("player_is_attacking", false)
		gameplay.set("player_anim_name", "idle")
		gameplay.set("player_anim_frame", 0)
		(gameplay.get("player_animation_component") as PlayerAnimationComponent).apply_frame(gameplay)

	runtime.call("tick_magic_animation", gameplay, 15.0)
	_expect(int(runtime.get("imbued_element")) == Elements.Element.NEUTRAL, "weapon element clears after fifteen seconds", failures)
	_expect(int(gameplay.get("player_imbued_element")) == Elements.Element.NEUTRAL, "gameplay element mirror clears after expiration", failures)
	_expect(float(runtime.get("imbue_cooldown_remaining")) > 0.0, "IMBUE cooldown outlasts its active duration", failures)
	runtime.call("tick_magic_animation", gameplay, 5.0)
	_expect(is_zero_approx(float(runtime.get("imbue_cooldown_remaining"))), "IMBUE becomes ready after twenty seconds", failures)

	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("IMBUE_SPELL_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
