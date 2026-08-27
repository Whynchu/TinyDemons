extends Node
class_name TargetingRuntimeController

const TARGET_LOCK_MAX_DISTANCE := 9999.0
const FOCUS_TEXT_WIDTH := 19.0
const FOCUS_TEXT_HEIGHT := 5.0
const FOCUS_FLASH_TIME := 0.25
const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/slime_variant_catalog.gd")


func valid_current_target(root: Object) -> Sprite2D:
	var target_value: Variant = root.get("current_target")
	if target_value == null:
		return null
	if not is_instance_valid(target_value):
		# Room rebuilds can free an orb before the next targeting tick. Clear the
		# dangling reference before any typed cast or HUD access occurs.
		root.set("current_target", null)
		return null
	return target_value as Sprite2D


func closest_target(root: Object) -> Sprite2D:
	var candidates: Array[Sprite2D] = (root.get("slimes") as Array[Sprite2D]).duplicate()
	candidates.append_array(root.get("puzzle_torches") as Array[Sprite2D])
	return (root.get("interaction_component") as InteractionComponent).closest_target(root.get("player") as Sprite2D, candidates, TARGET_LOCK_MAX_DISTANCE, Callable(root, "_actor_foot"), Callable(root, "_is_target_actor_dead"), Callable(root, "_is_slime_targetable"))


func cycle_target(root: Object, direction: int) -> void:
	if direction == 0:
		return
	var candidates: Array[Sprite2D] = (root.get("slimes") as Array[Sprite2D]).duplicate()
	candidates.append_array(root.get("puzzle_torches") as Array[Sprite2D])
	var current := valid_current_target(root)
	var player := root.get("player") as Sprite2D
	var origin := current if current != null and bool(root.call("_is_slime_targetable", current)) else player
	var origin_position: Vector2 = root.call("_actor_foot", origin)
	var best: Sprite2D = null
	var best_score := INF
	for candidate in candidates:
		if candidate == null or candidate == current or not bool(root.call("_is_slime_targetable", candidate)):
			continue
		var offset: Vector2 = root.call("_actor_foot", candidate) - origin_position
		if origin != player and offset.x * float(direction) <= 0.5:
			continue
		var score: float = offset.length() + (root.call("_actor_foot", candidate) as Vector2).distance_to(root.call("_actor_foot", player) as Vector2) * 0.25
		if score < best_score:
			best_score = score
			best = candidate
	if best == null:
		for candidate in candidates:
			if candidate == null or candidate == current or not bool(root.call("_is_slime_targetable", candidate)):
				continue
			var candidate_position: Vector2 = root.call("_actor_foot", candidate)
			var wrap_score := candidate_position.x * -float(direction) + candidate_position.distance_to(root.call("_actor_foot", player)) * 0.01
			if best == null or wrap_score < best_score:
				best_score = wrap_score
				best = candidate
	if best != null:
		set_current_target(root, best)


func set_current_target(root: Object, target: Sprite2D, play_feedback: bool = true) -> void:
	if target != null and not is_instance_valid(target):
		target = null
	var previous := valid_current_target(root)
	if previous == target:
		return
	var actors := root.get("actor_sprites") as Array[Sprite2D]
	var occlusion := root.get("occlusion_renderer") as OcclusionRenderer
	if actors.has(previous) and is_instance_valid(previous):
		occlusion.apply_unoccluded_actor_texture(previous, false, false, 0.0, Callable(root, "_apply_actor_scale"), 0.0)
	var torches := root.get("puzzle_torches") as Array[Sprite2D]
	if torches.has(previous):
		set_puzzle_torch_target_highlight(root, previous, false)
	if play_feedback and previous != null and target == null:
		root.call("_play_sound", "target_release", -8.0, 1.0)
	root.set("current_target", target)
	if torches.has(target):
		set_puzzle_torch_target_highlight(root, target, true)
	root.set("focus_flash_timer", 0.0)
	var momentum := root.call("_combat_momentum") as CombatMomentumComponent
	if momentum != null:
		momentum.on_target_changed(target != null)
	root.call("_update_focus_indicator")


func set_puzzle_torch_target_highlight(root: Object, torch: Sprite2D, highlighted: bool) -> void:
	if torch == null or not is_instance_valid(torch):
		return
	var highlight := torch.get_node_or_null("TargetHighlight") as Sprite2D
	if highlighted and highlight == null:
		highlight = Sprite2D.new()
		highlight.name = "TargetHighlight"
		highlight.texture = (root.get("occlusion_renderer") as OcclusionRenderer).orb_highlighted_texture(torch.texture)
		highlight.centered = true
		highlight.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		highlight.z_index = -1
		torch.add_child(highlight)
	if highlight != null:
		highlight.visible = highlighted


func update_target_ui(root: Object) -> void:
	var target := valid_current_target(root)
	if target == null:
		set_target_ui_visible(root, false)
		return
	if (root.get("puzzle_torches") as Array[Sprite2D]).has(target):
		update_puzzle_torch_target_ui(root, target)
		return
	set_target_ui_visible(root, true)
	var hud := root.get("hud_controller") as HudController
	var size: Vector2 = root.get("target_health_bar_size")
	size = hud.update_target_ui(target, root.get("target_name_text") as Sprite2D, root.get("target_health_bar") as Sprite2D, root.get("target_health_damage_fill") as Sprite2D, root.get("target_health_fill") as Sprite2D, root.get("target_health_text") as Sprite2D, size, Callable(root, "_slime_display_name"), Callable(root, "_enemy_max_health"), Callable(root, "_slime_current_health"), Callable(root, "_slime_display_health"), Callable(root, "_pixel_name_texture"), Callable(root, "_pixel_text_texture"), Callable(hud, "set_health_bar_values"))
	root.set("target_health_bar_size", size)


func update_puzzle_torch_target_ui(root: Object, torch: Sprite2D) -> void:
	set_target_ui_visible(root, true)
	var name_text := root.get("target_name_text") as Sprite2D
	name_text.texture = root.call("_pixel_name_texture", "ENTRY ORB", Color.WHITE) as Texture2D
	name_text.centered = true
	name_text.position = (root.get("hud_controller") as HudController).target_name_position()
	(root.get("target_health_text") as Sprite2D).visible = false
	var palette := str(torch.get_meta("puzzle_torch_palette", "grey"))
	var color := PaletteLibrary.normal(palette)
	var size: Vector2 = root.get("target_health_bar_size")
	var fill := root.get("target_health_fill") as Sprite2D
	if size == Vector2.ZERO:
		size = fill.texture.get_size() if fill.texture != null else Vector2(48, 16)
	root.set("target_health_bar_size", size)
	fill.self_modulate = color
	var damage_fill := root.get("target_health_damage_fill") as Sprite2D
	if damage_fill != null:
		damage_fill.self_modulate = color
		(root.get("hud_controller") as HudController).set_fill_ratio(damage_fill, size, 1.0)
	(root.get("hud_controller") as HudController).set_fill_ratio(fill, size, 1.0)


func set_target_ui_visible(root: Object, target_visible: bool) -> void:
	(root.get("hud_controller") as HudController).set_visible(root.get("target_name_text") as Sprite2D, root.get("target_health_bar") as Sprite2D, root.get("target_health_damage_fill") as Sprite2D, root.get("target_health_fill") as Sprite2D, root.get("target_health_text") as Sprite2D, target_visible)


func update_focus_indicator(root: Object, delta: float = 0.0) -> void:
	var label := root.get("focus_label") as Sprite2D
	var label_base := root.get("focus_label_base") as Sprite2D
	if label == null or label_base == null:
		return
	var target := valid_current_target(root)
	if target == null:
		label.visible = false
		label_base.visible = false
		root.set("focus_flash_timer", 0.0)
		return
	var momentum := root.call("_combat_momentum") as CombatMomentumComponent
	var flash_timer := maxf(float(root.get("focus_flash_timer")) - delta, 0.0)
	root.set("focus_flash_timer", flash_timer)
	var active := momentum != null and momentum.focus_active and momentum.focus_timer > 0.0
	var name_text := root.get("target_name_text") as Sprite2D
	var name_half := name_text.texture.get_size().x * 0.5 if name_text.texture != null else 0.0
	var top_left := name_text.position + Vector2(name_half + 12.0, -FOCUS_TEXT_HEIGHT * 0.5 - 1.0)
	label.position = top_left
	label_base.position = top_left
	label.visible = true
	label_base.visible = true
	label_base.texture = root.call("_pixel_text_texture", "FOCUS", Color8(150, 150, 150)) as Texture2D
	var fill_ratio := 1.0 if flash_timer > 0.0 else momentum.focus_timer / momentum.focus_window if active else 0.0
	var fill_color: Color = Color.WHITE if flash_timer > 0.0 else root.call("_health_feedback_color", str((root.get("screen_state_controller") as Node).get("player_palette_name"))) as Color
	label.texture = root.call("_pixel_text_texture", "FOCUS", fill_color) as Texture2D
	if fill_ratio >= 1.0:
		label.region_enabled = false
	else:
		label.region_enabled = true
		label.region_rect = Rect2(Vector2.ZERO, Vector2(FOCUS_TEXT_WIDTH * fill_ratio, FOCUS_TEXT_HEIGHT))


func slime_display_name(root: Object, slime: Sprite2D) -> String:
	var palette := str(slime.get("variant"))
	var display_name := SLIME_VARIANT_CATALOG_SCRIPT.display_name_for_variant(StringName(palette))
	var stats := root.call("_slime_stats", slime) as StatsComponent
	return "lv.%d %s" % [stats.level if stats != null else 1, display_name]
