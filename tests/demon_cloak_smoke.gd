extends SceneTree

var _finished := false
var _original_slot := 0
var _profile_file_snapshots: Dictionary = {}
var _profile_file_snapshot_active := false


func _initialize() -> void:
	create_timer(20.0).timeout.connect(_watchdog)
	var failures: Array[String] = []
	var packed := load("res://scenes/main.tscn") as PackedScene
	_expect(packed != null, "main scene loads for Demon Cloak coverage", failures)
	if packed == null:
		_finish(failures)
		return
	var gameplay := packed.instantiate()
	root.add_child(gameplay)
	for _frame in 120:
		await process_frame
	var profile := gameplay.get("player_profile") as PlayerProfile
	var anim := gameplay.get("player_animation_component") as PlayerAnimationComponent
	var screens := gameplay.get("screen_state_controller") as Node
	_expect(profile != null and anim != null and screens != null, "Demon Cloak owners are composed", failures)
	if profile != null and anim != null and screens != null:
		var run_state := gameplay.get("run_state") as RunState
		if run_state == null:
			run_state = RunState.new()
		var catalog := ItemCatalog.new()
		var seller_items := catalog.definition_ids_for_source_tag(&"cloaked_demon")
		_expect(seller_items.size() == 1 and seller_items[0] == &"demon_cloak", "the typed Cloaked Demon source identifies its special offer", failures)
		_expect(catalog.definition_locked_slots(&"demon_cloak") == [&"head"], "the typed Demon Cloak definition declares its secondary slot", failures)
		# Ignore any persistent-save pollution from earlier runs: this test owns
		# the cloak purchase state it asserts on.
		profile.demon_cloak_purchases = 0
		for data: Dictionary in profile.inventory.duplicate():
			if str(data.get("instance_id", "")).begins_with("demon-cloak-"):
				profile.inventory.erase(data)
		if str(profile.get_equipped_instance_id(&"body")).begins_with("demon-cloak-"):
			profile.unequip_slot(&"body")
		gameplay.call("_refresh_player_cloak_visual")
		await process_frame
		_expect(not anim.cloaked, "player starts with the base sheet", failures)
		_expect(profile.demon_cloak_price() == 500, "first cloak costs 500G", failures)
		run_state.ensure_shop_stock(profile)
		run_state.ensure_shop_stock(profile)
		var cloak_entry: Dictionary = {}
		var cloak_offer_count := 0
		for entry: Dictionary in run_state.shop_stock:
			var entry_item: Dictionary = entry.get("item", {}) as Dictionary
			if str(entry_item.get("definition_id", "")) == "demon_cloak":
				cloak_offer_count += 1
				cloak_entry = entry
		_expect(not cloak_entry.is_empty(), "shop always offers the Demon Cloak", failures)
		_expect(cloak_offer_count == 1, "rebuilding stock keeps one source-tagged special offer", failures)
		_expect(bool(cloak_entry.get("permanent", false)), "Demon Cloak is a permanent shop offer", failures)
		profile.gold = 1000
		var first_cloak := profile.purchase_demon_cloak()
		_expect(first_cloak != null and first_cloak.definition_id == &"demon_cloak" and first_cloak.rarity == &"common", "Demon Cloak is sold as a Common", failures)
		_expect(profile.demon_cloak_purchases == 1 and profile.gold == 500, "first purchase costs 500G", failures)
		_expect(profile.demon_cloak_price() == 600, "each purchase raises the price by 100G", failures)
		profile.gold = 1000
		var second_cloak := profile.purchase_demon_cloak()
		_expect(second_cloak != null and second_cloak.instance_id != first_cloak.instance_id, "repeated purchases never share an instance", failures)
		_expect(profile.gold == 400 and profile.demon_cloak_price() == 700, "second purchase costs 600G and raises to 700G", failures)
		_expect(profile.demon_cloak_price() == 700, "price escalates per purchase", failures)
		var cloak_bonuses := catalog.bonuses(first_cloak)
		_expect(float(cloak_bonuses.get("agi", 0.0)) >= 4.0 and float(cloak_bonuses.get("mnd", 0.0)) >= 2.0, "Demon Cloak carries the buffed Body + Head package", failures)
		var mythic_cloak := ItemInstance.from_dictionary(first_cloak.to_dictionary())
		mythic_cloak.rarity = &"mythic"
		mythic_cloak.enhancement_level = PlayerProfile.MAX_ITEM_ENHANCEMENT
		var scaled_bonuses := catalog.bonuses(mythic_cloak)
		_expect(float(scaled_bonuses.get("agi", 0.0)) > float(cloak_bonuses.get("agi", 0.0)) and float(scaled_bonuses.get("defense", 0.0)) > float(cloak_bonuses.get("defense", 0.0)), "both AGI and DEF scale with rarity and enhancement", failures)
		var head_item := ItemInstance.new()
		head_item.instance_id = "test-head"
		head_item.definition_id = &"basic_hood"
		head_item.rarity = &"common"
		profile.grant_item(head_item)
		_expect(profile.equip_item(head_item.instance_id), "a head item equips before the cloak", failures)
		_expect(not profile.get_equipped_instance_id(&"head").is_empty(), "head slot holds the head item", failures)
		var preview_profile := PlayerProfile.new()
		preview_profile.grant_item(head_item)
		preview_profile.equip_item(head_item.instance_id, catalog)
		var cloak_preview := EquipmentComponent.new()
		cloak_preview.configure_preview_from_profile(preview_profile, catalog, &"body", first_cloak)
		var cloak_primary_points := catalog.combat_primary_points(first_cloak) if first_cloak != null else {}
		_expect(is_equal_approx(cloak_preview.mnd_bonus, float(cloak_primary_points.get("mnd", 0.0))), "body preview omits head gear blocked by the candidate definition", failures)
		cloak_preview.free()
		if first_cloak != null:
			_expect(profile.equip_item(first_cloak.instance_id), "Demon Cloak equips into the body slot", failures)
		_expect(profile.get_equipped_instance_id(&"head").is_empty(), "equipping the cloak auto-unequips the head slot", failures)
		_expect(profile._head_locked_by_body(catalog), "the cloak locks the head slot", failures)
		_expect(not profile.equip_item(head_item.instance_id), "a head item cannot be equipped while the cloak is worn", failures)
		gameplay.call("_refresh_player_cloak_visual")
		await process_frame
		_expect(anim.cloaked, "equipping the Demon Cloak swaps the player sheet", failures)
		_expect(profile.has_demon_cloak_equipped(), "the active profile owns its equipped Demon Cloak state", failures)

		# Save-select portraits must resolve from each slot's profile, not the
		# currently active runtime animation. Build two same-palette fixtures so a
		# shared active cloak cannot hide behind a palette difference.
		_original_slot = ProfileSaveService.current_slot()
		_snapshot_profile_files()
		var cloaked_slot_profile := PlayerProfile.new()
		cloaked_slot_profile.has_started = true
		cloaked_slot_profile.player_name = "CLOAKED"
		cloaked_slot_profile.starter_flame = &"fire"
		var slot_cloak := ItemInstance.new()
		slot_cloak.instance_id = "save-test-cloak"
		slot_cloak.definition_id = &"demon_cloak"
		slot_cloak.rarity = &"common"
		cloaked_slot_profile.grant_item(slot_cloak)
		cloaked_slot_profile.equip_item(slot_cloak.instance_id)
		var plain_slot_profile := PlayerProfile.new()
		plain_slot_profile.has_started = true
		plain_slot_profile.player_name = "PLAIN"
		plain_slot_profile.starter_flame = &"fire"
		ProfileSaveService.select_slot(0)
		ProfileSaveService.save_profile(cloaked_slot_profile)
		ProfileSaveService.select_slot(1)
		ProfileSaveService.save_profile(plain_slot_profile)
		ProfileSaveService.select_slot(0)
		var assembly_controller: Variant = screens.get("assembly_controller")
		var save_portrait_overlay: ColorRect = null
		if assembly_controller != null:
			save_portrait_overlay = assembly_controller.call("build_save_select", gameplay.get("ui") as Node, Callable(gameplay, "_pixel_text_texture"), Callable(gameplay, "_select_save_slot"), Callable(gameplay, "_confirm_overwrite"), Callable(gameplay, "_save_overwrite_no"), Callable(gameplay, "_save_portrait_texture"), Callable(gameplay, "_close_save_select")) as ColorRect
		_expect(save_portrait_overlay != null, "current screen assembly builds the save-select preview", failures)
		var cloaked_portrait: Sprite2D = null
		var plain_portrait: Sprite2D = null
		if save_portrait_overlay != null:
			for child in save_portrait_overlay.get_children():
				if not child is Button or not child.has_meta("save_slot"):
					continue
				var slot := int(child.get_meta("save_slot"))
				var slot_portrait := child.get_node_or_null("Save%dPortrait" % slot) as Sprite2D
				if slot == 0:
					cloaked_portrait = slot_portrait
				elif slot == 1:
					plain_portrait = slot_portrait
			_expect(cloaked_slot_profile.has_demon_cloak_equipped() and not plain_slot_profile.has_demon_cloak_equipped(), "save fixtures keep cloak state isolated per profile", failures)
		_expect(cloaked_portrait != null and plain_portrait != null and cloaked_portrait.texture != plain_portrait.texture, "save-slot portraits do not inherit the active profile's cloak", failures)
		if save_portrait_overlay != null:
			save_portrait_overlay.queue_free()
		_restore_profile_files()

		if profile != null:
			_expect(profile.unequip_slot(&"body"), "Demon Cloak unequips", failures)
		_expect(not profile._head_locked_by_body(catalog), "removing the cloak unlocks the head slot", failures)
		_expect(profile.equip_item(head_item.instance_id), "a head item equips again after the cloak is removed", failures)
		gameplay.call("_refresh_player_cloak_visual")
		await process_frame
		_expect(not anim.cloaked, "removing the Demon Cloak reverts the player sheet", failures)
	gameplay.queue_free()
	await process_frame
	_finish(failures)


func _watchdog() -> void:
	if _finished:
		return
	_restore_profile_files()
	push_error("TEST_ABORTED: Demon Cloak smoke failed before completion")
	quit(1)


func _snapshot_profile_files() -> void:
	_profile_file_snapshots.clear()
	var paths: Array[String] = [ProfileSaveService.ACTIVE_SLOT_PATH]
	for slot in ProfileSaveService.SLOT_COUNT:
		paths.append(ProfileSaveService._save_path(slot))
		paths.append(ProfileSaveService._backup_path(slot))
		paths.append(ProfileSaveService._temp_path(slot))
	for path: String in paths:
		var exists := FileAccess.file_exists(path)
		_profile_file_snapshots[path] = {
			"exists": exists,
			"bytes": FileAccess.get_file_as_bytes(path) if exists else PackedByteArray(),
		}
	_profile_file_snapshot_active = true


func _restore_profile_files() -> void:
	if not _profile_file_snapshot_active:
		return
	for raw_path: Variant in _profile_file_snapshots:
		var path := str(raw_path)
		var snapshot: Dictionary = _profile_file_snapshots[raw_path]
		if bool(snapshot.get("exists", false)):
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file == null:
				push_error("Demon Cloak smoke could not restore profile file: %s" % path)
				continue
			file.store_buffer(snapshot.get("bytes", PackedByteArray()) as PackedByteArray)
			file.close()
		elif FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ProfileSaveService.active_slot = _original_slot
	_profile_file_snapshot_active = false


func _finish(failures: Array[String]) -> void:
	_finished = true
	if failures.is_empty():
		print("DEMON_CLOAK_SMOKE_OK")
		quit(0)
		return
	for failure: String in failures:
		push_error("FAILED: %s" % failure)
	quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
