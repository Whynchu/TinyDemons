extends RefCounted
class_name PausePageDataPresenter

## Renders the profile-backed values shown by the Pause Status, Equipment, and
## Debug pages. The screen presenter owns the page tree and this presenter owns
## its data-to-label projection.

const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")


func update_status(context: MenuPlayerContext, pixel_texture: Callable, status_texts: Array[Sprite2D], description_text: Sprite2D) -> void:
	if context == null or not context.is_valid():
		return
	var profile: PlayerProfile = context.profile
	var snapshot: CombatStatSnapshot = context.snapshot
	var tuning: CombatTuning = context.combat_tuning
	var player_tuning: PlayerTuning = context.player_tuning
	var xp_required := PlayerProfile.xp_required_for_level(profile.level, context.progression_tuning)
	var values := [
		"LV ...... %d" % profile.level, "XP ...... %d/%d" % [profile.xp, xp_required], "HP ...... %d/%d" % [context.current_health(), context.max_health()], "CHROMA .. %d/%d" % [context.chroma(), context.max_chroma()], "STR .... %d" % roundi(snapshot.strength), "AGI .... %d" % roundi(snapshot.agi), "VIT .... %d" % roundi(snapshot.vit), "INT .... %d" % roundi(snapshot.intelligence), "MND .... %d" % roundi(snapshot.mnd), "DEF .... %d" % roundi(snapshot.def),
		"P.ATK .. %d" % roundi(CombatCalculator.attack_power_for_snapshot(snapshot, tuning)), "P.DEF .. %d" % roundi(CombatCalculator.physical_defense_for_snapshot(snapshot)), "M.ATK .. %d" % roundi(CombatCalculator.magic_power_for_snapshot(snapshot, tuning)), "M.DEF .. %d" % roundi(CombatCalculator.magic_defense_for_snapshot(snapshot)), "MOV .... %.2fx" % (player_tuning.agi_multiplier(snapshot.agi) if player_tuning != null else 1.0), "REC .... %.2fx" % (player_tuning.attack_multiplier_for_agi(snapshot.agi) if player_tuning != null else 1.0),
	]
	for index in mini(values.size(), status_texts.size()):
		status_texts[index].texture = pixel_texture.call(values[index], Color8(255, 205, 117) if index == 1 else Color.WHITE) as Texture2D
	if description_text != null:
		description_text.texture = null


func update_equipment(profile: PlayerProfile, pixel_texture: Callable, equipment_texts: Array[Sprite2D], description_text: Sprite2D) -> void:
	if profile == null:
		return
	var catalog := ItemCatalog.new()
	var slot_labels := ["WEAPON", "HEAD", "BODY", "ARM", "SHIELD", "ACCESSORY"]
	for index in mini(slot_labels.size(), equipment_texts.size()):
		var slot: StringName = ItemCatalog.SLOTS[index]
		var item := profile.find_item(profile.get_equipped_instance_id(slot))
		var item_name := "EMPTY"
		if item != null:
			item_name = catalog.gear_name(item)
			if item.enhancement_level > 0: item_name += " F%d" % item.enhancement_level
		equipment_texts[index].texture = pixel_texture.call("%s .... %s" % [slot_labels[index], item_name], catalog.rarity_color(item.rarity) if item != null else Color8(140, 145, 160)) as Texture2D
	for index in range(slot_labels.size(), equipment_texts.size()):
		equipment_texts[index].texture = null
	if description_text != null:
		description_text.texture = null


func refresh_debug_menu(layout: DebugMenuLayout, context: PauseDebugMenuContext, pixel_texture: Callable) -> void:
	if layout == null or context == null:
		return
	var toggles := {
		&"invulnerable": context.invulnerable,
		&"unlimited_chroma": context.unlimited_chroma,
		&"pause_enemies": context.enemies_paused,
		&"geometry_guides": context.geometry_guides,
	}
	layout.refresh(
		pixel_texture,
		context.run_number,
		context.player_level,
		context.unspent_stat_points,
		context.reset_confirmation_armed,
		toggles
	)
	layout.select_row(context.selected_row)
