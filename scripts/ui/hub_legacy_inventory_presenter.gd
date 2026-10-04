extends RefCounted
class_name HubLegacyInventoryPresenter

# Owner: ScreenStateController composition; renders legacy Hub inventory views.
## Renders the compatibility inventory, equipment, and gear-comparison views.
var owner: ScreenStateController

func bind(screen: Node) -> void:
	owner = screen as ScreenStateController

const CURSOR_LEFT_GAP := 10.0
const HUB_ITEM_DETAIL_TOP := 105.0
const HUB_ITEM_DETAIL_PITCH := 7.0
const HUB_GEAR_BROWSE_DETAIL_TOP := 136.0
const HUB_ITEM_TEXT_WRAP_LENGTH := 34
const MENU_CIRCLE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_CIRCLE_TEXTURE
const MenuPromptTextureFactoryScript = preload("res://scripts/ui/menu_prompt_texture_factory.gd")
func _update_hub_item_page(root: Object, pixel_texture: Callable, profile: PlayerProfile, page: int, item_list: Array[Sprite2D], details: Array[Sprite2D], action: Button, highlight_color: Color) -> void:
	var catalog := ItemCatalog.new()
	var shop_prices := owner.hub_shop_price_texts
	for detail in details:
		detail.texture = null
		detail.visible = false
	if page == 1:
		_update_hub_gear_slots(root, pixel_texture, profile, catalog, item_list, owner.hub_gear_choice_texts, details, action, highlight_color)
		return
	var item: ItemInstance = null
	var price := 0
	var sold := false
	var index := owner.hub_item_index
	var count := 0
	if page == 1:
		count = profile.inventory.size()
		if count > 0: item = ItemInstance.from_dictionary(profile.inventory[clampi(index, 0, count - 1)])
	elif page == 2:
		if owner.hub_shop_sell_mode:
			var sellable := root.call("_hub_shop_sellable_items") as Array[ItemInstance]
			count = sellable.size()
			if count > 0:
				item = sellable[clampi(index, 0, count - 1)]
				price = catalog.sell_value(item)
		else:
			var run_state := root.get("run_state") as RunState
			if run_state != null:
				run_state.ensure_shop_stock(profile); count = run_state.shop_stock.size()
				if count > 0:
					var entry: Dictionary = run_state.shop_stock[clampi(index, 0, count - 1)]
					item = ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary); price = int(entry.get("price", 0)); sold = bool(entry.get("sold", false))
	else:
		var fusion_items := root.call("_hub_fusion_candidates") as Array[ItemInstance]
		count = fusion_items.size()
		if count > 0:
			item = fusion_items[clampi(index, 0, count - 1)]
	var selected := clampi(index, 0, maxi(count - 1, 0))
	if owner.hub_item_name_text != null:
		if item != null:
			var header_name: String = catalog.gear_name(item)
			if item.enhancement_level > 0: header_name += " F%d" % item.enhancement_level
			owner.hub_item_name_text.texture = pixel_texture.call("%d/%d %s" % [selected + 1, count, header_name], catalog.rarity_color(item.rarity)) as Texture2D
		else:
			owner.hub_item_name_text.texture = pixel_texture.call("0/0 NO ITEMS", Color8(140, 145, 160)) as Texture2D
		owner.hub_item_name_text.visible = true
	var item_pitch := 10.0
	var visible_rows := item_list.size()
	owner.hub_list_scroll = clampf(owner.hub_list_scroll, 0.0, maxf(0.0, float(count - visible_rows)))
	owner._apply_hub_item_scroll(item_pitch)
	var window_start := int(owner.hub_list_scroll)
	var scroll_frac: float = owner.hub_list_scroll - float(window_start)
	for row in item_list.size():
		var source_index := window_start + row
		if source_index >= count:
			item_list[row].texture = null
			if row < shop_prices.size(): shop_prices[row].texture = null
			continue
		if row < owner.hub_item_row_buttons.size():
			owner.hub_item_row_buttons[row].visible = (page == 2 or page == 3) and owner.hub_content_focus
			owner.hub_item_row_buttons[row].mouse_filter = Control.MOUSE_FILTER_STOP if owner.hub_item_row_buttons[row].visible else Control.MOUSE_FILTER_IGNORE
		var row_item: ItemInstance
		var row_sold := false
		var row_price := 0
		if page == 1:
			row_item = ItemInstance.from_dictionary(profile.inventory[source_index])
		elif page == 2:
			if owner.hub_shop_sell_mode:
				# Keep the legacy list renderer on the same grouped sell rows as
				# _render_shop_menu.  Rebuilding directly from inventory makes plain
				# copies appear as separate rows and bypasses OWNED:x quantities.
				var sellable_rows := root.call("_hub_shop_sellable_items") as Array[ItemInstance]
				row_item = sellable_rows[source_index]
				row_price = catalog.sell_value(row_item)
			else:
				var row_state := root.get("run_state") as RunState
				var row_entry: Dictionary = row_state.shop_stock[source_index]
				row_item = ItemInstance.from_dictionary(row_entry.get("item", {}) as Dictionary); row_sold = bool(row_entry.get("sold", false)); row_price = int(row_entry.get("price", 0))
		else:
			var fusion_items := root.call("_hub_fusion_candidates") as Array[ItemInstance]
			if source_index >= fusion_items.size():
				item_list[row].texture = null; continue
			row_item = fusion_items[source_index]
		var rarity_mark := catalog.rarity_letter_grade(row_item.rarity)
		var row_label := "%s %s" % [rarity_mark, catalog.gear_name(row_item)]
		var row_mastery := row_item.enhancement_level
		if row_mastery > 0 and page != 3: row_label += " F%d" % row_mastery
		if page == 2 and row_sold: row_label += " SOLD"
		elif page == 3: row_label += "  F%d" % row_mastery
		if page == 3:
			var row_slot := catalog.definition_slot(row_item.definition_id)
			if profile.get_equipped_instance_id(row_slot) == row_item.instance_id:
				row_label += " E"
		var row_color := highlight_color if source_index == selected else Color8(120, 120, 130) if row_sold else catalog.rarity_color(row_item.rarity)
		item_list[row].texture = pixel_texture.call(row_label, row_color) as Texture2D
		if page == 2 and row < shop_prices.size():
			var sell_text := "%dG + %dS" % [row_price, catalog.sell_soul_value(row_item)] if owner.hub_shop_sell_mode else ("SOLD" if row_sold else "%dG" % row_price)
			shop_prices[row].texture = pixel_texture.call(sell_text, highlight_color if source_index == selected else Color8(120, 120, 130) if row_sold else Color8(255, 205, 117)) as Texture2D
	# The hand cursor marks the selected row and moves with the scrolled content.
	if owner.hub_list_cursor != null:
		var selected_visible_slot := selected - window_start
		if owner.hub_content_focus and selected_visible_slot >= 0 and selected_visible_slot < item_list.size() and item != null:
			owner.hub_list_cursor.visible = true
			var cursor_row_y := 35.0 + 4.0 + float(selected_visible_slot) * item_pitch - scroll_frac * item_pitch
			owner._menu_cursor_animator.move_menu_cursor(owner.hub_list_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, cursor_row_y + 3.0), false, owner)
		else:
			owner.hub_list_cursor.visible = false
	if item == null:
		if not item_list.is_empty():
			var empty_text := owner.hub_fusion_message if page == 3 and not owner.hub_fusion_message.is_empty() else ("NO FUSE / SALVAGE" if page == 3 else "NO ITEMS")
			item_list[0].texture = pixel_texture.call(empty_text, Color8(255, 205, 117) if page == 3 else Color.WHITE) as Texture2D
		for detail in details: detail.texture = null
		for stale_stat in owner.hub_gear_stat_texts: stale_stat.texture = null
		if owner.hub_item_detail_panel != null: owner.hub_item_detail_panel.visible = true
		action.disabled = true
		return
	var mastery := item.enhancement_level
	var bonuses := catalog.bonuses(item, mastery); var bonus_parts: Array[String] = []
	if page != 3:
		for stat: String in bonuses:
			if stat == "speed":
				continue
			var bonus_label: String = str({"health_rate": "HP", "damage_rate": "DMG"}.get(stat, stat.to_upper()))
			var value := float(bonuses[stat])
			bonus_parts.append("%s %s%.1f" % [bonus_label, "+" if value > 0 else "", value])
		if not bonus_parts.is_empty():
			details[0].texture = pixel_texture.call("  ".join(bonus_parts), Color.WHITE) as Texture2D
			details[0].visible = not bonus_parts.is_empty()
	var selected_transmutation_name := catalog.transmutation_name(item.transmutation_id)
	if page == 3 and not selected_transmutation_name.is_empty():
		details[0].texture = pixel_texture.call("SPECIAL: %s" % selected_transmutation_name, Color8(148, 220, 255)) as Texture2D
		details[0].visible = true
	elif page == 3:
		details[0].texture = null
	var slot := catalog.definition_slot(item.definition_id)
	var equipped := profile.get_equipped_instance_id(slot) == item.instance_id
	var overflow := profile.can_salvage_overflow(item.instance_id, catalog)
	var material_count := profile.fusion_material_count(item.instance_id, catalog)
	var can_fuse := material_count > 0
	var fusion_count := clampi(owner.hub_fusion_count, 1, maxi(material_count, 1))
	if page == 3 and overflow:
		details[1].texture = pixel_texture.call("MYTHIC +10  SALVAGE %dG" % catalog.overflow_salvage_value(item), Color8(255, 205, 117)) as Texture2D
		details[1].visible = true
		for stale_stat in owner.hub_gear_stat_texts: stale_stat.texture = null
	elif page == 3:
		var batch_cost := profile.fusion_batch_cost(item, fusion_count)
		var fusion_color := Color8(211, 167, 255) if profile.souls >= batch_cost else Color8(255, 105, 105)
		var final_rarity := item.rarity
		var final_enhancement := mastery
		for step in fusion_count:
			if final_enhancement >= PlayerProfile.MAX_ITEM_ENHANCEMENT:
				final_rarity = ItemCatalog.next_rarity(final_rarity)
				final_enhancement = 0
			else:
				final_enhancement += 1
		var next_text := "%s -> %s +0" % [String(final_rarity).to_upper(), String(ItemCatalog.next_rarity(final_rarity)).to_upper()] if final_rarity != item.rarity else "+%d -> +%d" % [mastery, final_enhancement]
		details[1].texture = pixel_texture.call("FUSE x%d  %dS  S%d  MAT%d  %s" % [fusion_count, batch_cost, profile.souls, material_count, next_text], fusion_color) as Texture2D
		details[1].visible = true
		var projected := ItemInstance.from_dictionary(item.to_dictionary())
		projected.enhancement_level = final_enhancement
		projected.rarity = final_rarity
		var next_bonuses := catalog.bonuses(projected, 0)
		var preview_stats := owner.hub_gear_stat_texts
		var preview_rows: Array[String] = []
		var preview_order := ["strength", "defense", "vitality", "agi", "intelligence", "mnd"]
		for stat: String in preview_order:
			var before := float(bonuses.get(stat, 0.0))
			var after := float(next_bonuses.get(stat, 0.0))
			if is_equal_approx(before, 0.0) and is_equal_approx(after, 0.0):
				continue
			var preview_label: String = str({"health_rate": "HP", "damage_rate": "DMG", "strength": "STR", "defense": "DEF", "vitality": "VIT", "speed": "AGI", "agi": "AGI", "intelligence": "INT", "mnd": "MND"}.get(stat, stat.to_upper()))
			preview_rows.append("%s %.1f>%.1f" % [preview_label, before, after])
		for row_index in preview_stats.size():
			if row_index < preview_rows.size():
				preview_stats[row_index].texture = pixel_texture.call(preview_rows[row_index], Color8(167, 240, 112)) as Texture2D
				preview_stats[row_index].visible = true
			else:
				preview_stats[row_index].texture = null
				preview_stats[row_index].visible = false
	else:
		var item_info: Array[String] = []
		if page == 2 and owner.hub_shop_sell_mode:
			item_info.append("SELL FOR %dG + %dS" % [catalog.sell_value(item), catalog.sell_soul_value(item)])
			if owner.hub_shop_sell_confirm_pending:
				item_info.append("ARE YOU SURE? CONFIRM / BACK")
		var random_text := catalog.random_stat_text(item)
		if not random_text.is_empty(): item_info.append(random_text)
		var player_rate_text := catalog.player_stat_rate_text(item)
		if not player_rate_text.is_empty(): item_info.append(player_rate_text)
		if not selected_transmutation_name.is_empty(): item_info.append("SPECIAL: %s" % selected_transmutation_name)
		if not item_info.is_empty():
			details[1].texture = pixel_texture.call("  ".join(item_info), Color8(148, 220, 255)) as Texture2D
		details[1].visible = not item_info.is_empty()
		var item_detail_lines := catalog.effect_display_lines(item)
		item_detail_lines.append_array(_wrap_gear_text(catalog.player_description(item), HUB_ITEM_TEXT_WRAP_LENGTH))
		_set_gear_detail_lines(details, pixel_texture, item_detail_lines, Color8(210, 220, 235))
	action.disabled = (owner.hub_shop_sell_mode and equipped) or (not owner.hub_shop_sell_mode and sold) or (page == 2 and not owner.hub_shop_sell_mode and profile.gold < price) or (page == 1 and equipped) or (page == 3 and (not can_fuse and not overflow or (can_fuse and profile.souls < profile.fusion_batch_cost(item, fusion_count))))
	if owner.hub_fusion_decrease_button != null:
		owner.hub_fusion_decrease_button.disabled = page != 3 or not can_fuse or fusion_count <= 1
		owner._menu_widget_factory.set_archetype_button_state(owner.hub_fusion_decrease_button, not owner.hub_fusion_decrease_button.disabled, highlight_color)
	if owner.hub_fusion_increase_button != null:
		owner.hub_fusion_increase_button.disabled = page != 3 or not can_fuse or fusion_count >= material_count
		owner._menu_widget_factory.set_archetype_button_state(owner.hub_fusion_increase_button, not owner.hub_fusion_increase_button.disabled, highlight_color)
	var label := action.get_child(0) as Sprite2D
	if label != null: label.texture = pixel_texture.call(("SELL" if owner.hub_shop_sell_mode else "BUY") if page == 2 else ("SALVAGE" if page == 3 and overflow else ("FUSE x%d" % fusion_count if page == 3 else "EQUIP")), Color.WHITE) as Texture2D
	owner._menu_widget_factory.set_archetype_button_state(action, true, highlight_color)
	owner._menu_prompt_texture_factory.set_menu_button_icon(action, MENU_CIRCLE_TEXTURE, owner._menu_uses_face_art(root) and not action.disabled)

func _update_hub_gear_slots(root: Object, pixel_texture: Callable, profile: PlayerProfile, catalog: ItemCatalog, item_list: Array[Sprite2D], choices: Array[Sprite2D], details: Array[Sprite2D], action: Button, highlight_color: Color) -> void:
	# Equipment owns its top Equip/Remove action row. The old lower action
	# button belongs to Shop/Fusion and must never become a second, hidden focus
	# target while the slot picker is being navigated.
	action.visible = false
	action.disabled = true
	for button in owner.hub_gear_choice_buttons: button.visible = false
	for stat in owner.hub_gear_stat_texts:
		stat.texture = null
		stat.visible = false
	var selected_slot_index := clampi(owner.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var selected_slot: StringName = ItemCatalog.SLOTS[selected_slot_index]
	var candidate_indices := owner.hub_gear_candidate_indices
	var browsing := owner.hub_gear_browsing
	var action_state := owner.hub_equipment_action_focus and not browsing
	var selected_candidate: ItemInstance = null
	var slot_candidates := root.call("_hub_gear_candidates", selected_slot) as Array[ItemInstance]
	var slot_labels := ["WEAPON", "HEAD", "BODY", "ARM", "SHIELD", "ACCESSORY"]
	if owner.hub_item_name_text != null:
		var header := "%s GEAR" % slot_labels[selected_slot_index] if browsing else "SELECT SLOT"
		owner.hub_item_name_text.texture = pixel_texture.call(header, highlight_color if browsing else Color.WHITE) as Texture2D
		owner.hub_item_name_text.visible = not action_state
	for detail in details:
		detail.texture = null
		detail.visible = false
	if action_state:
		# The action row is the complete Equipment screen at this depth. Clear
		# descendants so no slot header, stat card, or old picker label can sit
		# underneath it and look like a second active menu.
		for row in item_list:
			row.texture = null
		for choice in choices:
			choice.texture = null
		if owner.hub_item_detail_panel != null:
			owner.hub_item_detail_panel.visible = false
		if owner.hub_gear_stat_panel != null:
			owner.hub_gear_stat_panel.visible = false
		return
	var head_locked := profile._head_locked_by_body(catalog) if profile != null else false
	for row in item_list.size():
		if row >= ItemCatalog.SLOTS.size():
			item_list[row].texture = null
			continue
		var slot := ItemCatalog.SLOTS[row]
		var shown_item := profile.find_item(profile.get_equipped_instance_id(slot))
		if row == selected_slot_index:
			selected_candidate = shown_item
		var slot_name: String = slot_labels[row]
		var shown_name: String = "EMPTY"
		var shown_color := Color8(140, 145, 160)
		if shown_item != null:
			shown_name = catalog.gear_name(shown_item)
			var shown_mastery := shown_item.enhancement_level
			if shown_mastery > 0: shown_name += " F%d" % shown_mastery
			shown_color = catalog.rarity_color(shown_item.rarity)
		# Selection is represented by the slot cursor. Keep the gear's rarity color
		# intact even in the compatibility presenter used by older callers.
		var row_color := shown_color
		var slot_locked := slot == &"head" and head_locked
		if slot_locked:
			# The Demon Cloak occupies Body + Head; the Head slot is greyed out.
			item_list[row].texture = pixel_texture.call("%s: LOCKED" % slot_name, Color8(88, 92, 102)) as Texture2D
		else:
			item_list[row].texture = pixel_texture.call("%s: %s" % [slot_name, shown_name], row_color) as Texture2D
		if row < owner.hub_gear_slot_buttons.size():
			owner.hub_gear_slot_buttons[row].disabled = slot_locked
			owner.hub_gear_slot_buttons[row].visible = not action_state
	if owner.hub_slot_cursor != null:
		owner.hub_slot_cursor.visible = not action_state and selected_slot_index >= 0 and selected_slot_index < item_list.size()
		if owner.hub_slot_cursor.visible:
			owner._menu_cursor_animator.move_menu_cursor(owner.hub_slot_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, 35.0 + 4.0 + float(selected_slot_index) * 10.0 + 3.0), false, owner)
	for choice in choices: choice.texture = null
	if browsing:
		var current_index := posmod(int(candidate_indices.get(String(selected_slot), 0)), maxi(slot_candidates.size(), 1))
		if not slot_candidates.is_empty(): selected_candidate = slot_candidates[current_index]
		var choice_pitch := 10.0
		var visible_choices := choices.size()
		owner.hub_choice_scroll = clampf(owner.hub_choice_scroll, 0.0, maxf(0.0, float(slot_candidates.size() - visible_choices)))
		owner._apply_hub_choice_scroll(choice_pitch)
		var window_start := int(owner.hub_choice_scroll)
		var choice_frac: float = owner.hub_choice_scroll - float(window_start)
		for choice_row in choices.size():
			var choice_index := window_start + choice_row
			if choice_index >= slot_candidates.size(): break
			if choice_row < owner.hub_gear_choice_buttons.size(): owner.hub_gear_choice_buttons[choice_row].visible = true
			var choice_item := slot_candidates[choice_index]
			var is_unequip := choice_item.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID
			var choice_label := "%s" % ("UNEQUIP SHIELD" if is_unequip else "%s %s" % [String(choice_item.rarity).substr(0, 1).to_upper(), catalog.gear_name(choice_item)])
			var choice_mastery := choice_item.enhancement_level
			if choice_mastery > 0: choice_label += " F%d" % choice_mastery
			# Candidate selection belongs to the cursor; the candidate name keeps its
			# rarity color so the equipment route has one consistent visual language.
			var choice_color := Color8(140, 145, 160) if is_unequip else catalog.rarity_color(choice_item.rarity)
			choices[choice_row].texture = pixel_texture.call(choice_label, choice_color) as Texture2D
		if owner.hub_choice_cursor != null:
			var choice_visible_slot := current_index - window_start
			owner.hub_choice_cursor.visible = choice_visible_slot >= 0 and choice_visible_slot < choices.size()
			if owner.hub_choice_cursor.visible:
				var choice_cursor_y := 91.0 + 4.0 + float(choice_visible_slot) * choice_pitch - choice_frac * choice_pitch
				owner._menu_cursor_animator.move_menu_cursor(owner.hub_choice_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, choice_cursor_y + 3.0), false, owner)
		action.visible = false
		if owner.hub_item_detail_panel != null: owner.hub_item_detail_panel.visible = true
		if not details.is_empty():
			details[0].position = Vector2(20, HUB_GEAR_BROWSE_DETAIL_TOP)
			details[0].texture = pixel_texture.call("SELECT %s" % catalog.display_name(selected_candidate) if selected_candidate != null else "NO GEAR", highlight_color) as Texture2D
			details[0].visible = true
		if selected_candidate != null:
			_update_gear_comparison_stats(root, pixel_texture, profile, catalog, selected_candidate, selected_slot_index, true)
		return
	else:
		for choice in choices: choice.visible = false
	if owner.hub_item_detail_panel != null: owner.hub_item_detail_panel.visible = true
	for detail_index in details.size(): details[detail_index].position = Vector2(20, HUB_ITEM_DETAIL_TOP + detail_index * HUB_ITEM_DETAIL_PITCH)
	if selected_candidate == null:
		var available_candidates := slot_candidates
		if selected_slot_index == ItemCatalog.SLOTS.find(&"shield") and not available_candidates.is_empty():
			details[0].texture = pixel_texture.call("NO SHIELD EQUIPPED", Color8(255, 205, 117)) as Texture2D
			details[1].texture = pixel_texture.call("SELECT FROM INVENTORY", Color8(148, 220, 255)) as Texture2D
			details[0].visible = true; details[1].visible = true
		else:
			details[0].texture = pixel_texture.call("NO GEAR FOR THIS SLOT", Color8(255, 205, 117)) as Texture2D
			details[0].visible = true
		return
	_update_gear_comparison_stats(root, pixel_texture, profile, catalog, selected_candidate, selected_slot_index, browsing)
	details[0].texture = pixel_texture.call(catalog.display_name(selected_candidate), catalog.rarity_color(selected_candidate.rarity)) as Texture2D
	details[0].visible = true
	var transmutation_name := catalog.transmutation_name(selected_candidate.transmutation_id)
	var item_info: Array[String] = []
	var random_text := catalog.random_stat_text(selected_candidate)
	if not random_text.is_empty(): item_info.append(random_text)
	var player_rate_text := catalog.player_stat_rate_text(selected_candidate)
	if not player_rate_text.is_empty(): item_info.append(player_rate_text)
	if not transmutation_name.is_empty(): item_info.append("SPECIAL: %s" % transmutation_name)
	if selected_slot_index == ItemCatalog.SLOTS.find(&"shield"):
		var shield_values := catalog.shield_bonuses(selected_candidate)
		item_info.append("BLOCK +%d ARM +%d%%" % [roundi(float(shield_values.get("guard_durability", 0.0))), roundi(float(shield_values.get("guard_reduction", 0.0)))])
	if not item_info.is_empty():
		details[1].texture = pixel_texture.call("  ".join(item_info), Color8(148, 220, 255)) as Texture2D
		details[1].visible = true
	var description_lines := catalog.effect_display_lines(selected_candidate)
	description_lines.append_array(_wrap_gear_text(catalog.player_description(selected_candidate), HUB_ITEM_TEXT_WRAP_LENGTH))
	if not transmutation_name.is_empty():
		description_lines.append_array(_wrap_gear_text(catalog.transmutation_description(selected_candidate.transmutation_id), HUB_ITEM_TEXT_WRAP_LENGTH))
	_set_gear_detail_lines(details, pixel_texture, description_lines, Color8(210, 220, 235))
	action.disabled = true
	action.visible = false

func _set_transmutation_description(details: Array[Sprite2D], pixel_texture: Callable, description: String) -> void:
	for detail_index in range(2, details.size()):
		details[detail_index].texture = null
		details[detail_index].visible = false
	if description.is_empty():
		return
	var words := description.split(" ")
	var lines: Array[String] = []
	var line := ""
	for word in words:
		if word.length() > HUB_ITEM_TEXT_WRAP_LENGTH:
			if not line.is_empty():
				lines.append(line)
				line = ""
			while word.length() > HUB_ITEM_TEXT_WRAP_LENGTH:
				lines.append(word.left(HUB_ITEM_TEXT_WRAP_LENGTH))
				word = word.substr(HUB_ITEM_TEXT_WRAP_LENGTH)
		var candidate := word if line.is_empty() else "%s %s" % [line, word]
		if candidate.length() > HUB_ITEM_TEXT_WRAP_LENGTH and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty(): lines.append(line)
	for line_index in mini(lines.size(), details.size() - 2):
		details[line_index + 2].texture = pixel_texture.call(lines[line_index], Color8(210, 220, 235)) as Texture2D
		details[line_index + 2].visible = true

func _wrap_gear_text(source_text: String, line_length: int) -> Array[String]:
	return owner._hub_equipment_menu_presenter.wrap_gear_text(source_text, line_length)

func _set_gear_detail_lines(details: Array[Sprite2D], pixel_texture: Callable, lines: Array[String], color: Color) -> void:
	for detail_index in range(2, details.size()):
		details[detail_index].texture = null
		details[detail_index].visible = false
	for line_index in mini(lines.size(), details.size() - 2):
		details[line_index + 2].texture = pixel_texture.call(lines[line_index], color) as Texture2D
		details[line_index + 2].visible = true

func _update_gear_comparison_stats(root: Object, pixel_texture: Callable, profile: PlayerProfile, catalog: ItemCatalog, candidate: ItemInstance, slot_index: int, comparing: bool) -> void:
	var stats := owner.hub_gear_stat_texts
	var slot := ItemCatalog.SLOTS[clampi(slot_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var live_snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot if root.has_method("_player_stat_snapshot") else null
	var player_stats := root.get("player_stats") as StatsComponent
	if live_snapshot != null and player_stats != null:
		# Preview through the same equipment component and shared snapshot used by
		# combat. This keeps rarity rates, transmutation health effects, and the
		# flat-before-rate ordering identical between the menu and runtime.
		var preview_equipment := EquipmentComponent.new()
		var preview_item := candidate
		if candidate != null and candidate.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID:
			preview_item = null
		preview_equipment.configure_preview_from_profile(profile, catalog, slot, preview_item)
		var preview_snapshot := CombatStatSnapshot.from_components(player_stats, preview_equipment)
		var comparison_fields := [
			{"key": "vit", "label": "VIT"}, {"key": "strength", "label": "STR"},
			{"key": "def", "label": "DEF"}, {"key": "agi", "label": "AGI"},
			{"key": "intelligence", "label": "INT"}, {"key": "mnd", "label": "MND"},
		]
		for index in mini(stats.size(), comparison_fields.size()):
			var field: Dictionary = comparison_fields[index]
			var key := str(field["key"])
			var before := float(live_snapshot.get(key))
			var after := float(preview_snapshot.get(key))
			var delta := after - before
			var shown := delta if comparing else after
			var prefix := "+" if shown > 0.0 and comparing else "-" if shown < 0.0 and comparing else ""
			var color := Color8(148, 220, 255) if delta > 0.0 else Color8(239, 125, 87) if delta < 0.0 else Color8(167, 240, 112) if not comparing else Color8(150, 156, 170)
			stats[index].visible = true
			stats[index].texture = pixel_texture.call("%s %s%.1f" % [str(field["label"]), prefix, absf(shown) if comparing else shown], color) as Texture2D
		var tuning := root.get("combat_tuning") as CombatTuning
		var current_attack := CombatCalculator.attack_power_for_snapshot(live_snapshot, tuning)
		var preview_attack := CombatCalculator.attack_power_for_snapshot(preview_snapshot, tuning)
		var current_magic := CombatCalculator.magic_power_for_snapshot(live_snapshot, tuning)
		var preview_magic := CombatCalculator.magic_power_for_snapshot(preview_snapshot, tuning)
		if owner.hub_context_text != null:
			var context := "P%.0f>%.0f M%.0f>%.0f" % [current_attack, preview_attack, current_magic, preview_magic] if comparing else "P%.0f M%.0f" % [preview_attack, preview_magic]
			var confirm_prompt := owner._menu_confirm_prompt_for(root).replace("SELECT", "EQUIP")
			owner.hub_context_text.texture = pixel_texture.call("%s  %s" % [context, confirm_prompt], Color8(148, 220, 255)) as Texture2D
		preview_equipment.free()
		return
	# Lightweight test doubles and legacy callers may not expose a player
	# snapshot. Keep their package-only comparison readable while using the
	# canonical six-stat names.
	var equipped := profile.find_item(profile.get_equipped_instance_id(slot))
	var candidate_bonuses := _effective_item_bonuses(catalog, candidate, profile.mastery_level(candidate.definition_id))
	var equipped_bonuses := _effective_item_bonuses(catalog, equipped, profile.mastery_level(equipped.definition_id)) if equipped != null else {}
	var fallback_fields := [{"key": "vitality", "label": "VIT", "rate": false}, {"key": "strength", "label": "STR", "rate": false}, {"key": "defense", "label": "DEF", "rate": false}, {"key": "agi", "label": "AGI", "rate": false}, {"key": "intelligence", "label": "INT", "rate": false}, {"key": "mnd", "label": "MND", "rate": false}]
	for index in mini(stats.size(), fallback_fields.size()):
		var field: Dictionary = fallback_fields[index]
		var key := str(field["key"])
		var value := float(candidate_bonuses.get(key, 0.0)) - float(equipped_bonuses.get(key, 0.0)) if comparing else float(candidate_bonuses.get(key, 0.0))
		var prefix := "+" if value > 0 else "-" if value < 0 else ""
		var color := Color8(148, 220, 255) if value > 0 else Color8(239, 125, 87) if value < 0 else Color8(150, 156, 170)
		if is_zero_approx(value) and (key == "intelligence" or key == "mnd"):
			stats[index].texture = null
			stats[index].visible = false
		else:
			stats[index].visible = true
			stats[index].texture = pixel_texture.call("%s %s%.1f%s" % [str(field["label"]), prefix, absf(value), "%" if bool(field["rate"]) else ""], color) as Texture2D
	for index in range(fallback_fields.size(), stats.size()):
		stats[index].texture = null
		stats[index].visible = false

func _effective_item_bonuses(catalog: ItemCatalog, item: ItemInstance, mastery_level: int = 0) -> Dictionary:
	if item == null:
		return {}
	return catalog.bonuses(item, mastery_level)

# --- Pause routing and shared Hub equipment input ---

func _equipment_bonus_lines(catalog: ItemCatalog, item: ItemInstance) -> Array[String]:
	return owner._hub_equipment_menu_presenter.equipment_bonus_lines(catalog, item)

func _equipment_item_description(catalog: ItemCatalog, item: ItemInstance) -> Array[String]:
	return owner._hub_equipment_menu_presenter.equipment_item_description(catalog, item)

func _equipment_item_label(catalog: ItemCatalog, item: ItemInstance) -> String:
	return owner._hub_equipment_menu_presenter.equipment_item_label(catalog, item)
