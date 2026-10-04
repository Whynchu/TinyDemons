extends RefCounted
class_name HubEquipmentMenuPresenter

## Builds the active authored Equipment view model from typed menu and player state.


func render(context: HubEquipmentMenuContext) -> void:
	if context == null or context.view == null or context.profile == null or context.menu_state == null:
		return
	var view := context.view
	var profile := context.profile
	var state := context.menu_state
	view.set_pixel_texture(context.pixel_texture)
	view.set_read_only(context.read_only)
	view.set_portrait_texture(context.portrait_texture)
	view.set_command_labels(["EQUIPMENT", "EQUIP", "REMOVE", "REMOVE ALL"])
	view.set_icons_visible(true)
	# The corrected render reserves the lower-right framed cell for the device
	# prompt. It is informational on controller/keyboard, and its BACK half is
	# a real touch target wired to the same nested route callback.
	view.set_navigation_texture(context.navigation_texture)
	# The Demon Hub owns the canonical shared footer. Pause shows this view's
	# prompt because its shared Hub footer is not mounted.
	view.set_navigation_visible(context.show_navigation)

	var snapshot := context.stat_snapshot
	var catalog := ItemCatalog.new()
	var slot_labels: Array[String] = []
	var slot_colors: Array[Color] = []
	var slot_locked: Array[bool] = []
	var selected_slot_index := clampi(state.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var mode := EquipmentMenuLayout.MODE_SLOT_EQUIP if context.read_only else state.equipment_mode_for_render()
	var head_locked := profile._head_locked_by_body(catalog)
	var selected_item: ItemInstance = null
	var any_equipped := false
	for index in ItemCatalog.SLOTS.size():
		var slot: StringName = ItemCatalog.SLOTS[index]
		var item := profile.find_item(profile.get_equipped_instance_id(slot))
		var locked := slot == &"head" and head_locked
		if index == selected_slot_index:
			selected_item = item
		if item != null:
			any_equipped = true
		slot_locked.append(locked)
		if locked:
			slot_labels.append("HEAD")
			slot_colors.append(Color8(88, 92, 102))
		elif item == null:
			# An unfilled cell keeps its slot identity instead of introducing an
			# EMPTY label that was never in the mockup.
			slot_labels.append(catalog.slot_label(slot))
			slot_colors.append(Color8(140, 145, 160))
		else:
			slot_labels.append(equipment_item_label(catalog, item))
			# Gear identity is communicated by rarity color. Selection belongs to
			# the cursor layer, so selected gear keeps its rarity color.
			slot_colors.append(catalog.rarity_color(item.rarity))
	view.set_slot_grid(slot_labels, slot_colors, slot_locked)
	view.set_command_enabled(0, true)
	# REMOVE always opens the six-slot grid, even when the highlighted slot is
	# empty; the player can then choose an equipped slot to clear.
	view.set_command_enabled(1, true)
	view.set_command_enabled(2, any_equipped)

	var selected_candidate_index := 0
	var candidate_labels: Array[String] = []
	var candidate_colors: Array[Color] = []
	var candidate_item: ItemInstance = selected_item
	var selected_slot: StringName = ItemCatalog.SLOTS[selected_slot_index]
	var candidates := context.selected_slot_candidates
	selected_candidate_index = posmod(
		int(state.hub_gear_candidate_indices.get(String(selected_slot), 0)),
		maxi(candidates.size(), 1)
	)
	if not candidates.is_empty():
		candidate_item = candidates[selected_candidate_index]
	var candidate_window_start := 0
	var candidate_scroll_fraction := 0.0
	if candidates.size() > 8:
		var max_start := EquipmentMenuLayout.candidate_max_scroll(candidates.size())
		var candidate_scroll := clampf(state.hub_choice_scroll, 0.0, float(max_start))
		candidate_window_start = clampi(int(floor(candidate_scroll / 2.0)) * 2, 0, max_start)
		candidate_scroll_fraction = candidate_scroll - float(candidate_window_start)
	for index in 8:
		var source_index := candidate_window_start + index
		if source_index >= candidates.size():
			break
		var item := candidates[source_index]
		var label := "UNEQUIP SHIELD" if item.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID else equipment_item_label(catalog, item)
		candidate_labels.append(label)
		candidate_colors.append(Color8(140, 145, 160) if item.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID else catalog.rarity_color(item.rarity))
	view.set_candidates(candidate_labels, candidate_colors, selected_candidate_index, candidate_scroll_fraction)

	# Candidate focus previews effective stats through the same equipment and
	# snapshot path combat uses. The summary otherwise reads the current snapshot.
	var values: Array[String] = []
	var stat_colors: Array[Color] = []
	var stat_keys := ["vit", "strength", "def", "agi", "intelligence", "mnd"]
	var stat_labels := ["VIT", "STR", "DEF", "AGI", "INT", "MND"]
	var bonus_keys := ["vitality", "strength", "defense", "agi", "intelligence", "mnd"]
	var preview_snapshot: CombatStatSnapshot = null
	var equipped_bonuses: Dictionary = {}
	var candidate_bonuses: Dictionary = {}
	if mode == EquipmentMenuLayout.MODE_CANDIDATE:
		if candidate_item != null and candidate_item.instance_id != ItemCatalog.UNEQUIP_SHIELD_ID:
			candidate_bonuses = catalog.bonuses(candidate_item)
		if selected_item != null and selected_item.instance_id != ItemCatalog.UNEQUIP_SHIELD_ID:
			equipped_bonuses = catalog.bonuses(selected_item)
		if context.player_stats != null and candidate_item != null:
			var preview_equipment := EquipmentComponent.new()
			var preview_item := candidate_item
			if preview_item.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID:
				preview_item = null
			preview_equipment.configure_preview_from_profile(profile, catalog, selected_slot, preview_item)
			preview_snapshot = CombatStatSnapshot.from_components(context.player_stats, preview_equipment)
			preview_equipment.free()
	for index in stat_keys.size():
		var source := preview_snapshot if preview_snapshot != null else snapshot
		var value := float(source.get(stat_keys[index])) if source != null else 0.0
		values.append("%s %d" % [stat_labels[index], roundi(value)])
		var stat_color := Color.WHITE
		if mode == EquipmentMenuLayout.MODE_CANDIDATE:
			var before := float(equipped_bonuses.get(bonus_keys[index], 0.0))
			var after := float(candidate_bonuses.get(bonus_keys[index], 0.0))
			if after > before:
				stat_color = PaletteLibrary.NORMAL["green"]
			elif after < before:
				stat_color = PaletteLibrary.NORMAL["red"]
		stat_colors.append(stat_color)
	view.set_summary(PlayerProfile.normalize_player_name(profile.player_name), values, Color.WHITE, stat_colors)

	# Legacy arrays remain populated for existing touch/smoke probes; the
	# authored EquipmentMenuLayout owns the visible rendering.
	for index in context.legacy_candidate_texts.size():
		if index < candidate_labels.size():
			context.legacy_candidate_texts[index].texture = context.pixel_texture.call(candidate_labels[index], candidate_colors[index]) as Texture2D
		else:
			context.legacy_candidate_texts[index].texture = null
	for index in context.legacy_slot_texts.size():
		if index < slot_labels.size():
			context.legacy_slot_texts[index].texture = context.pixel_texture.call(slot_labels[index], slot_colors[index]) as Texture2D
		else:
			context.legacy_slot_texts[index].texture = null

	var description_lines: Array[String] = []
	var bonus_lines: Array[String] = []
	if mode == EquipmentMenuLayout.MODE_CANDIDATE:
		# Candidate focus replaces the description pane with the 2x4 inventory
		# grid, while the bottom strip previews the selected final bonuses.
		bonus_lines = equipment_bonus_lines(catalog, candidate_item)
	elif mode != EquipmentMenuLayout.MODE_REMOVE_ALL_CONFIRM and mode != EquipmentMenuLayout.MODE_COMMAND:
		description_lines = equipment_item_description(catalog, selected_item)
		bonus_lines = equipment_bonus_lines(catalog, selected_item)
	view.set_description(description_lines, Color8(210, 220, 235))
	view.set_bonuses(bonus_lines, [Color.WHITE, Color.WHITE, Color.WHITE])
	# Remove All uses the locked grey cursor under the normal bobbing cursor;
	# confirmation is conveyed by cursor state, not a YES/NO prompt.
	view.set_confirm_prompt([], state.hub_remove_all_confirm_index)
	var visible_candidate_index := selected_candidate_index - candidate_window_start
	view.render_mode(mode, clampi(state.hub_action_column, 0, 2), selected_slot_index, visible_candidate_index, state.hub_remove_all_confirm_index)


func equipment_bonus_lines(catalog: ItemCatalog, item: ItemInstance) -> Array[String]:
	if item == null:
		return []
	var labels := {"vitality": "VIT", "strength": "STR", "defense": "DEF", "agi": "AGI", "speed": "AGI", "intelligence": "INT", "mnd": "MND", "health_rate": "HP", "damage_rate": "DMG"}
	var parts: Array[String] = []
	var bonuses := catalog.bonuses(item)
	for key in ["vitality", "strength", "defense", "agi", "intelligence", "mnd", "health_rate", "damage_rate"]:
		if not bonuses.has(key):
			continue
		var value := float(bonuses[key])
		if is_zero_approx(value):
			continue
		var shown := "%d" % roundi(value) if is_equal_approx(value, round(value)) else "%.1f" % value
		if value > 0.0:
			shown = "+%s" % shown
		parts.append("%s: %s" % [str(labels.get(key, key.to_upper())), shown])
	# The authored stat strip has three columns. Keep each to two newline-
	# separated stats so a multi-stat item cannot run into its neighbor.
	var lines: Array[String] = ["", "", ""]
	for index in parts.size():
		var column_index := index % 3
		var row_index := floori(float(index) / 3.0)
		if row_index >= 2:
			break
		if lines[column_index].is_empty():
			lines[column_index] = parts[index]
		else:
			lines[column_index] += "\n%s" % parts[index]
	return lines


func equipment_item_description(catalog: ItemCatalog, item: ItemInstance) -> Array[String]:
	if item == null:
		return []
	var lines: Array[String] = []
	var random_text := catalog.random_stat_text(item)
	if not random_text.is_empty():
		lines.append(random_text)
	var description := catalog.player_description(item)
	if not description.is_empty():
		lines.append_array(wrap_gear_text(description, 34))
	lines.append_array(catalog.effect_display_lines(item))
	if not item.transmutation_id.is_empty():
		lines.append_array(wrap_gear_text(catalog.transmutation_description(item.transmutation_id), 34))
	return lines


func equipment_item_label(catalog: ItemCatalog, item: ItemInstance) -> String:
	if item == null:
		return "EMPTY"
	var label := catalog.gear_name(item)
	if item.enhancement_level > 0:
		label += " F%d" % item.enhancement_level
	return label


func wrap_gear_text(source_text: String, line_length: int) -> Array[String]:
	var lines: Array[String] = []
	if source_text.is_empty():
		return lines
	var line := ""
	for word in source_text.split(" "):
		if word.length() > line_length:
			if not line.is_empty():
				lines.append(line)
				line = ""
			while word.length() > line_length:
				lines.append(word.left(line_length))
				word = word.substr(line_length)
		var candidate := word if line.is_empty() else "%s %s" % [line, word]
		if candidate.length() > line_length and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty():
		lines.append(line)
	return lines
