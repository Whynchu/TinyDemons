extends Node
class_name ProfileRuntimeController

func apply_profile_to_runtime(root: Object) -> void:
	if root.player_profile == null:
		return
	var palette: String = root.player_profile.palette_name
	# XP/stat refreshes during a run must not overwrite a palette selected at a
	# fire with the profile's original saved palette.
	if root.run_state != null and root.run_state.active and not root.current_player_palette_name.is_empty():
		palette = root.current_player_palette_name
	root.screen_state_controller.player_palette_name = palette
	root.current_player_palette_name = palette
	var chroma := root.get("player_chroma_component") as Node
	if chroma != null and is_instance_valid(chroma):
		if root.player_profile.has_bound_element:
			chroma.call("set_bound_flame", root.player_profile.bound_element)
		else:
			chroma.call("clear_bound_aspect")
	if root.run_state == null or not root.run_state.active:
		# The hub flame is a durable starter-or-bound identity, not whichever
		# temporary aspect happened to be active during the previous run.
		root.run_start_palette_name = root.player_profile.hub_palette()
	root.player_profile.ensure_starter_items()
	if root.player_equipment != null:
		root.player_equipment.configure_from_profile(root.player_profile)
	if root.player_stats == null:
		return
	root.player_stats.level = root.player_profile.level
	if root.player_profile.has_started:
		root.player_stats.configure_manual_growth(root.player_profile.base_vit, root.player_profile.base_str, root.player_profile.base_def, root.player_profile.base_agi, root.player_profile.allocated_vit, root.player_profile.allocated_str, root.player_profile.allocated_def, root.player_profile.allocated_agi, root.player_profile.base_int, root.player_profile.base_mnd, root.player_profile.allocated_int, root.player_profile.allocated_mnd)
	else:
		root.player_stats.manual_allocation_enabled = false
	root.call("_configure_equipment_transmutations")
	root.call("_recompute_player_speed_multiplier")


func reapply_equipment_preserving_health(root: Object) -> void:
	var old_max := float(root.call("_player_max_health")) if root.player_stats != null and root.player_equipment != null else 1.0
	var current_health: float = root.player_health_component.current_health if root.player_health_component != null else 0.0
	var health_ratio := clampf(current_health / old_max, 0.0, 1.0) if old_max > 0.0 else 1.0
	root.player_equipment.configure_from_profile(root.player_profile)
	root.call("_configure_equipment_transmutations")
	var new_max := float(root.call("_player_max_health"))
	if root.player_health_component != null:
		root.player_health_component.maximum_health = new_max
		root.player_health_component.reset(minf(new_max, maxf(1.0, new_max * health_ratio)))
	root.call("_save_player_profile")
	root.call("_update_player_health_ui")
	root.call("_recompute_player_speed_multiplier")


func equip_profile_item(root: Object, instance_id: String) -> bool:
	if root.player_profile == null or not root.player_profile.equip_item(instance_id):
		return false
	reapply_equipment_preserving_health(root)
	root.call("_play_sound", "ui_equip", 0.0, 1.0)
	return true


func unequip_profile_slot(root: Object, slot: StringName) -> bool:
	if root.player_profile == null or not root.player_profile.unequip_slot(slot):
		return false
	reapply_equipment_preserving_health(root)
	root.call("_play_sound", "ui_unequip", 0.0, 1.0)
	return true


func set_gold_value(root: Object, value: int) -> void:
	if root.player_profile == null:
		return
	root.player_profile.gold = maxi(value, 0)
	root.call("_save_player_profile")
	root.call("_update_gold_indicator")


func set_soul_value(root: Object, value: int) -> void:
	if root.player_profile == null:
		return
	root.player_profile.souls = maxi(value, 0)
	root.call("_save_player_profile")
	root.call("_update_soul_indicator")


func sync_runtime_progression_to_profile(root: Object) -> void:
	if root.player_profile == null:
		return
	if root.player_stats != null and root.player_stats.manual_allocation_enabled:
		var allocation: Dictionary = root.player_stats.manual_allocation()
		root.player_profile.allocated_vit = int(allocation["VIT"])
		root.player_profile.allocated_str = int(allocation["STR"])
		root.player_profile.allocated_def = int(allocation["DEF"])
		root.player_profile.allocated_agi = int(allocation.get("AGI", allocation.get("SPD", 0)))
		root.player_profile.allocated_int = int(allocation.get("INT", 0))
		root.player_profile.allocated_mnd = int(allocation.get("MND", 0))
	root.call("_save_player_profile")


func respec_player_stats(root: Object) -> int:
	if root.player_profile == null or not root.player_profile.has_started:
		return 0
	var refunded: int = root.player_profile.reset_allocated_stats()
	root.call("_apply_profile_to_runtime")
	root.call("_apply_player_level")
	sync_runtime_progression_to_profile(root)
	return refunded
