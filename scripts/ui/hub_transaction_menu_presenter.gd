extends RefCounted
class_name HubTransactionMenuPresenter

const ShopMenuModelScript = preload("res://scripts/ui/shop_menu_model.gd")
const FusionMenuModelScript = preload("res://scripts/ui/fusion_menu_model.gd")
const HubTransactionMenuContextScript = preload("res://scripts/ui/hub_transaction_menu_context.gd")
const FUSION_VISIBLE_ROWS := 10

func build_shop_model(context: HubTransactionMenuContextScript) -> ShopMenuModelScript:
	var model := ShopMenuModelScript.new() as ShopMenuModelScript
	model.state = context.state
	model.sell_mode = context.sell_mode
	var count := context.items.size()
	var selected := clampi(context.selected_index, 0, maxi(count - 1, 0))
	var max_scroll := maxi(0, count - ShopMenuLayout.VISIBLE_ROWS)
	var scroll := clampf(context.scroll, 0.0, float(max_scroll))
	var window_start := clampi(int(floor(scroll)), 0, maxi(count - ShopMenuLayout.VISIBLE_ROWS, 0))
	model.selected_row = selected - window_start
	model.scroll_fraction = scroll - floor(scroll)
	for row in ShopMenuLayout.VISIBLE_ROWS:
		var source_index := window_start + row
		if source_index >= count:
			model.row_labels.append("")
			model.row_colors.append(Color8(140, 145, 160))
			model.row_prices.append("")
			model.row_soul_values.append(0)
			model.row_slots.append(&"")
			continue
		var item := context.items[source_index]
		var label := context.catalog.gear_name(item)
		if item.enhancement_level > 0:
			label += " F%d" % item.enhancement_level
		if context.sell_mode and source_index < context.sell_owned_counts.size() and context.sell_owned_counts[source_index] > 1:
			label += " x%d" % context.sell_owned_counts[source_index]
		model.row_labels.append(label)
		model.row_colors.append(Color8(120, 120, 130) if source_index < context.sold_flags.size() and context.sold_flags[source_index] else context.catalog.rarity_color(item.rarity))
		model.row_prices.append(context.prices[source_index] if source_index < context.prices.size() else "")
		model.row_soul_values.append(context.soul_values[source_index] if source_index < context.soul_values.size() else 0)
		model.row_slots.append(context.item_slots[source_index] if source_index < context.item_slots.size() else &"")
	model.owned_count = context.owned_count
	model.quantity = clampi(context.quantity, 1, maxi(context.max_quantity, 1))
	model.max_quantity = maxi(context.max_quantity, 1)
	model.stat_comparison = shop_stat_comparison(context.profile, context.catalog, context.items[selected] if count > 0 else null)
	if context.sell_mode and context.state == ShopMenuLayout.SELL_AMOUNT and count > 0 and selected < context.prices.size():
		var value := context.batch_value
		if value.is_empty():
			var selected_item := context.items[selected]
			value = {"gold": context.catalog.sell_value(selected_item) * model.quantity, "souls": context.catalog.sell_soul_value(selected_item) * model.quantity}
		var gold := str(int(value.get("gold", 0)))
		var souls := int(value.get("souls", 0))
		if selected >= window_start and selected - window_start < model.row_prices.size():
			var visible_index := selected - window_start
			model.row_prices[visible_index] = gold
			model.row_soul_values[visible_index] = souls
	return model

func build_fusion_model(context: HubTransactionMenuContextScript) -> FusionMenuModel:
	var model := FusionMenuModelScript.new() as FusionMenuModel
	model.state = context.fusion_state
	model.item_selected = context.fusion_item_selected
	model.scroll_fraction = context.scroll - floor(context.scroll)
	var window_start := int(floor(context.scroll))
	for row_index in FUSION_VISIBLE_ROWS:
		var item_index := window_start + row_index
		if item_index >= context.fusion_candidates.size():
			continue
		var item := context.fusion_candidates[item_index]
		model.rows.append({"label": fusion_item_label(context.catalog, context.profile, item), "slot": str(context.catalog.definition_slot(item.definition_id)), "color": context.catalog.rarity_color(item.rarity), "soul_cost": context.profile.fusion_batch_cost(item, 1), "equipped": context.profile.equipped_instance_ids.values().has(item.instance_id), "stat_total": context.catalog.stat_allocation_total(item)})
	model.selected_row = clampi(context.selected_index - window_start, 0, model.rows.size() - 1) if not model.rows.is_empty() else -1
	var selected: ItemInstance = null
	var material_count := int(context.fusion_details.get("material_count", 0))
	if not context.fusion_candidates.is_empty():
		selected = context.fusion_candidates[clampi(context.selected_index, 0, context.fusion_candidates.size() - 1)]
		model.owned_count = int(context.fusion_details.get("owned_count", 0))
		model.material_count = material_count
		model.fusion_count_max = maxi(material_count, 1)
		model.fusion_count = clampi(context.fusion_count, 1, model.fusion_count_max)
		model.soul_cost = context.profile.fusion_batch_cost(selected, model.fusion_count) if material_count > 0 else 0
		model.can_fuse = selected != null and material_count > 0 and context.profile.souls >= model.soul_cost
		model.can_salvage = bool(context.fusion_details.get("can_salvage", false))
		model.stat_comparison = shop_stat_comparison(context.profile, context.catalog, selected)
	model.message = context.fusion_message
	if model.message.is_empty() and model.state == 2 and material_count > 0 and not model.can_fuse:
		model.message = "NEED %dS" % model.soul_cost
	return model

func shop_stat_comparison(profile: PlayerProfile, catalog: ItemCatalog, item: ItemInstance) -> Array[Dictionary]:
	var fields := [{"key": "vit", "label": "VIT"}, {"key": "strength", "label": "STR"}, {"key": "def", "label": "DEF"}, {"key": "agi", "label": "AGI"}, {"key": "intelligence", "label": "INT"}, {"key": "mnd", "label": "MND"}]
	var result: Array[Dictionary] = []
	var equipped: ItemInstance = null
	if item != null:
		var slot := catalog.definition_slot(item.definition_id)
		equipped = profile.find_item(profile.get_equipped_instance_id(slot))
	var before_bonuses := catalog.bonuses(equipped, profile.mastery_level(equipped.definition_id)) if equipped != null else {}
	var after_bonuses := catalog.bonuses(item, profile.mastery_level(item.definition_id)) if item != null else {}
	for field: Dictionary in fields:
		var key := str(field["key"])
		var catalog_key := "vitality" if key == "vit" else "defense" if key == "def" else key
		var before := float(before_bonuses.get(catalog_key, 0.0))
		var after := float(after_bonuses.get(catalog_key, 0.0))
		var delta := after - before
		result.append({"label": str(field["label"]), "before": before, "after": after, "before_color": Color8(244, 244, 244), "after_color": Color8(56, 183, 100) if delta > 0.0 else Color8(177, 62, 83) if delta < 0.0 else Color8(244, 244, 244)})
	return result

func fusion_item_label(catalog: ItemCatalog, profile: PlayerProfile, item: ItemInstance) -> String:
	var label := catalog.gear_name(item)
	if item.enhancement_level > 0:
		label += " F%d" % item.enhancement_level
	if profile.equipped_instance_ids.values().has(item.instance_id):
		label += " E"
	return label
