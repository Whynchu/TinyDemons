extends Node
class_name HudController

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const SOUL_ICON_COLOR := Color8(211, 167, 255)

var target_health_fill_textures: Dictionary = {}
var target_health_damage_fill_textures: Dictionary = {}
var target_overhead_fill_textures: Dictionary = {}
var target_overhead_damage_fill_textures: Dictionary = {}
var target_overhead_frames: Dictionary = {}
var target_overhead_damage_fills: Dictionary = {}
var target_overhead_fills: Dictionary = {}
var target_overhead_offsets: Dictionary = {}
var target_overhead_fill_sizes: Dictionary = {}
var target_overhead_aggro_markers: Dictionary = {}
var target_overhead_aggro_offsets: Dictionary = {}
var bright_bar_cache: Dictionary = {}
var aggro_marker_texture_cache: Dictionary = {}
var last_run_timer_text := ""
var room_number_indicator: Sprite2D = null
var dungeon_run_indicator: Sprite2D = null
var gold_indicator: Sprite2D = null
var gold_amount_indicator: Sprite2D = null
var soul_icon_indicator: Sprite2D = null
var soul_amount_indicator: Sprite2D = null
var run_timer_indicator: Sprite2D = null
var gold_animation_frames: Array[Texture2D] = []
var gold_animation_timer := 0.0
var button_hud_sprites: Array[Sprite2D] = []
var cooldown_hud: Dictionary = {}


func set_visible(target_name: CanvasItem, target_bar: CanvasItem, target_damage_fill: CanvasItem, target_fill: CanvasItem, target_health_text: CanvasItem, visible: bool) -> void:
	target_name.visible = visible
	target_bar.visible = visible
	if target_damage_fill != null:
		target_damage_fill.visible = visible
	target_fill.visible = visible
	if target_health_text != null:
		target_health_text.visible = visible


func update_target_ui(target: Sprite2D, target_name: Sprite2D, _target_bar: Sprite2D, target_damage_fill: Sprite2D, target_fill: Sprite2D, target_health_text: Sprite2D, bar_size: Vector2, display_name: Callable, max_health_for: Callable, health_for: Callable, display_health_for: Callable, pixel_name: Callable, pixel_number: Callable, set_values: Callable) -> Vector2:
	if target == null: return bar_size
	target_name.texture = pixel_name.call(display_name.call(target), Color.WHITE); target_name.centered = true; target_name.position = Vector2(120, 148)
	var fill_texture := target_health_fill_textures.get(target, target_fill.texture) as Texture2D
	if fill_texture != null:
		target_fill.texture = fill_texture
		target_fill.self_modulate = Color.WHITE
		bar_size = fill_texture.get_size()
	var damage_fill_texture := target_health_damage_fill_textures.get(target, target_fill.texture) as Texture2D
	if target_damage_fill != null and damage_fill_texture != null:
		target_damage_fill.texture = damage_fill_texture
		target_damage_fill.self_modulate = Color.WHITE
	var max_health := float(max_health_for.call(target)); var health := float(health_for.call(target)); var display_health := float(display_health_for.call(target))
	target_health_text.texture = pixel_number.call("%d/%d" % [ceili(health), ceili(max_health)], Color.WHITE)
	set_values.call(target_fill, target_damage_fill, bar_size, health, display_health, max_health)
	return bar_size


func update_player_health_ui(health: float, display_health: float, damage_hold: float, delta: float, regen_speed: float, drain_speed: float, max_health: float, fill: Sprite2D, damage_fill: Sprite2D, fill_size: Vector2, health_text: Sprite2D, pixel_number: Callable, set_values: Callable) -> Dictionary:
	# Bar speeds are %-relative: they scale with max HP so the bar fills/drains at
	# the same visual rate regardless of how large the pool is.
	var scale := max_health / 100.0
	if health > display_health: display_health = move_toward(display_health, health, regen_speed * scale * delta)
	if damage_hold > 0.0: damage_hold = maxf(damage_hold - delta, 0.0)
	elif display_health > health: display_health = move_toward(display_health, health, drain_speed * scale * delta)
	set_values.call(fill, damage_fill, fill_size, health, display_health, max_health)
	if health_text != null: health_text.texture = pixel_number.call("%d/%d" % [ceili(health), ceili(max_health)], Color.WHITE)
	return {"display_health": display_health, "damage_hold": damage_hold}


func set_fill_ratio(fill: Sprite2D, fill_size: Vector2, ratio: float) -> void:
	if fill == null:
		return
	fill.region_enabled = true
	fill.region_rect = Rect2(Vector2.ZERO, Vector2(fill_size.x * clampf(ratio, 0.0, 1.0), fill_size.y))


func set_health_bar_values(main_fill: Sprite2D, transition_fill: Sprite2D, fill_size: Vector2, health: float, display_health: float, max_health: float) -> void:
	if main_fill == null or max_health <= 0.0: return
	var health_ratio := clampf(health / max_health, 0.0, 1.0); var display_ratio := clampf(display_health / max_health, 0.0, 1.0)
	var main_ratio := display_ratio if display_health < health else health_ratio; var transition_ratio := health_ratio if display_health < health else display_ratio
	set_fill_ratio(main_fill, fill_size, main_ratio)
	if transition_fill != null: set_fill_ratio(transition_fill, fill_size, transition_ratio)


func update_overhead_bars(
	slimes: Array[Sprite2D],
	max_health_for: Callable,
	health_for: Callable,
	display_health_for: Callable,
	is_dead_for: Callable,
	is_aggroed_for: Callable,
	set_values: Callable,
	overwold_ui_z: int,
	is_hidden_for: Callable = Callable()
) -> void:
	for slime in slimes:
		var frame := target_overhead_frames.get(slime) as Sprite2D
		var damage_fill := target_overhead_damage_fills.get(slime) as Sprite2D
		var fill := target_overhead_fills.get(slime) as Sprite2D
		var aggro_marker := target_overhead_aggro_markers.get(slime) as Sprite2D
		if frame == null or damage_fill == null or fill == null or aggro_marker == null:
			continue
		var hidden := is_hidden_for.is_valid() and bool(is_hidden_for.call(slime))
		if is_dead_for.call(slime) or hidden:
			frame.visible = false
			damage_fill.visible = false
			fill.visible = false
			aggro_marker.visible = false
			continue
		var max_health := float(max_health_for.call(slime))
		var health := float(health_for.call(slime))
		var is_aggroed := bool(is_aggroed_for.call(slime))
		var should_show := health < max_health or is_aggroed
		frame.visible = should_show
		damage_fill.visible = should_show
		fill.visible = should_show
		fill.self_modulate = Color.WHITE
		damage_fill.self_modulate = Color.WHITE
		aggro_marker.visible = is_aggroed
		if not should_show:
			continue
		var overhead_offset := target_overhead_offsets.get(slime, Vector2.ZERO) as Vector2
		var encounter_scale := float(slime.get_meta("encounter_scale", 1.0))
		overhead_offset.y -= 15.0 * (encounter_scale - 1.0)
		if not is_aggroed:
			overhead_offset.x -= 2.0
		var overhead_position := slime.global_position + overhead_offset + Vector2(0, -2)
		frame.global_position = overhead_position
		frame.global_scale = Vector2.ONE
		frame.z_index = overwold_ui_z
		damage_fill.global_position = overhead_position
		damage_fill.global_scale = Vector2.ONE
		damage_fill.z_index = overwold_ui_z + 1
		fill.global_position = overhead_position
		fill.global_scale = Vector2.ONE
		fill.z_index = overwold_ui_z + 2
		aggro_marker.top_level = true
		var aggro_offset := target_overhead_aggro_offsets.get(slime, Vector2.ZERO) as Vector2
		aggro_offset.y -= 15.0 * (encounter_scale - 1.0)
		aggro_marker.global_position = slime.global_position + aggro_offset + Vector2(0, -2)
		aggro_marker.global_scale = Vector2.ONE
		aggro_marker.z_index = overwold_ui_z + 3
		var fill_size := target_overhead_fill_sizes.get(slime, Vector2.ZERO) as Vector2
		set_values.call(fill, damage_fill, fill_size, health, float(display_health_for.call(slime)), max_health)


func update_button_hud(buttons: Array[Sprite2D], devices: Array[int], router: InputRouter = null, input_device_tracker: Node = null, pixel_texture: Callable = Callable()) -> void:
	if buttons.size() < 4:
		return
	var pressed := [false, false, false, false]
	if router != null:
		pressed[0] = router.button_pressed(JOY_BUTTON_Y)
		pressed[1] = router.button_pressed(JOY_BUTTON_X)
		pressed[2] = router.button_pressed(JOY_BUTTON_A)
		pressed[3] = router.button_pressed(JOY_BUTTON_B)
	var device := int(input_device_tracker.get("current_device")) if input_device_tracker != null else 1
	var keyboard_labels := ["U", "J", "K", "E"]
	for index in buttons.size():
		var button := buttons[index]
		if device == 2:
			button.visible = false
			button.modulate = Color.WHITE
		elif device == 0 and pixel_texture.is_valid():
			button.visible = true
			button.texture = pixel_texture.call(keyboard_labels[index] if index < keyboard_labels.size() else "", Color.WHITE) as Texture2D
			button.modulate = Color(1.7, 1.7, 1.7, 1.0) if pressed[index] else Color.WHITE
		else:
			button.visible = true
			var gamepad_texture: Variant = button.get_meta("gamepad_texture", button.texture)
			if gamepad_texture is Texture2D:
				button.texture = gamepad_texture as Texture2D
		button.modulate = Color(1.7, 1.7, 1.7, 1.0) if pressed[index] else Color.WHITE


func update_cooldown_hud(root: Object) -> void:
	if cooldown_hud.is_empty():
		return
	var ability := root.get("player_aspect_ability_component") as Node
	var chroma := root.get("player_chroma_component") as Node
	var regular_remaining := float(ability.get("cooldown_remaining")) if ability != null else 0.0
	var regular_duration := float(root.get("GREY_MAGIC_COOLDOWN"))
	if ability != null and chroma != null:
		regular_duration = float(ability.call("cooldown_duration_for_mode", int(chroma.call("ability_mode"))))
	var imbue_runtime := root.get("magic_runtime_controller") as Node
	var imbue_remaining := float(imbue_runtime.get("imbue_cooldown_remaining")) if imbue_runtime != null else 0.0
	var imbue_duration := float(root.get("IMBUE_COOLDOWN"))
	var regular_ratio := 1.0 - clampf(regular_remaining / maxf(regular_duration, 0.001), 0.0, 1.0)
	var imbue_ratio := 1.0 - clampf(imbue_remaining / maxf(imbue_duration, 0.001), 0.0, 1.0)
	set_fill_ratio(cooldown_hud.get("triangle_fill") as Sprite2D, Vector2(24, 4), regular_ratio)
	set_fill_ratio(cooldown_hud.get("imbue_fill") as Sprite2D, Vector2(24, 4), imbue_ratio)
	var player_palette := String(root.get("current_player_palette_name"))
	var regular_color := PaletteLibrary.accent(player_palette)
	var imbue_active := imbue_runtime != null and float(imbue_runtime.get("imbue_remaining")) > 0.0
	var imbue_color := PaletteLibrary.accent("grey")
	if imbue_active:
		var element := int(imbue_runtime.get("imbued_element"))
		imbue_color = ElementCatalogScript.damage_number_color(element)
	elif imbue_remaining > 0.0:
		imbue_color = PaletteLibrary.shadow("grey")
	(cooldown_hud.get("triangle_label") as Sprite2D).texture = root.call("_pixel_text_texture", "TRI", regular_color)
	(cooldown_hud.get("imbue_label") as Sprite2D).texture = root.call("_pixel_text_texture", "IMB", imbue_color)
	(cooldown_hud.get("triangle_fill") as Sprite2D).self_modulate = regular_color
	(cooldown_hud.get("imbue_fill") as Sprite2D).self_modulate = imbue_color


func update_overworld(root: Object, delta: float, ui_z: int) -> void:
	update_button_hud(button_hud_sprites, root.call("_controller_devices"), root.get("input_router") as InputRouter, root.get("input_device_tracker") as Node, Callable(root, "_pixel_text_texture"))
	update_cooldown_hud(root)
	var timer := fmod(gold_animation_timer + delta, 0.48); gold_animation_timer = timer; update_gold_indicator(gold_indicator, gold_animation_frames, timer)
	update_run_timer(root)
	update_overhead_bars(root.get("slimes"), Callable(root, "_enemy_max_health"), Callable(root, "_slime_current_health"), Callable(root, "_slime_display_health"), Callable(root, "_is_slime_dead"), Callable(root, "_is_slime_aggroed"), Callable(self, "set_health_bar_values"), ui_z, Callable(root, "_is_slime_hidden"))


func update_run_timer(root: Object) -> void:
	var indicator := run_timer_indicator
	if indicator == null:
		return
	var run_state := root.get("run_state") as RunState
	var elapsed := floori(run_state.elapsed_time) if run_state != null and run_state.timer_started else 0
	var label := "TIME %02d:%02d" % [floori(float(elapsed) / 60.0), elapsed % 60]
	if label == last_run_timer_text:
		return
	last_run_timer_text = label
	indicator.texture = root.call("_pixel_text_texture", label, Color8(244, 244, 244)) as Texture2D


func update_room_number(root: Object) -> void:
	var indicator := room_number_indicator
	if indicator == null: return
	var room_label := "D%d" % int(root.get("current_room_display_number")); var room_type: StringName = root.get("current_room_type")
	if room_type == DungeonGraph.ROOM_START: room_label = "START"
	elif room_type == DungeonGraph.ROOM_REST: room_label = "REST"
	elif room_type == DungeonGraph.ROOM_TRADER: room_label = "TRADER"
	elif room_type == DungeonGraph.ROOM_NPC: room_label = "CLOAKED"
	elif room_type == DungeonGraph.ROOM_DOWNSTAIRS: room_label = "BOSS"
	indicator.texture = root.call("_pixel_text_texture", room_label, Color8(244, 244, 244))
	var run_indicator := dungeon_run_indicator
	if run_indicator != null:
		var profile := root.get("player_profile") as PlayerProfile
		# The HUD's R-number is the successful-run progression. Difficulty rank is
		# performance-sensitive and can fall after an F, but a failed R2 must still
		# restart as R2 rather than appearing to roll back to R1.
		var run_number := profile.completed_runs + 1 if profile != null else 1
		var grade := profile.last_run_grade if profile != null else "D"
		run_indicator.texture = root.call("_pixel_text_texture", "%s R%d" % [DungeonGraph.DUNGEON_NAME, run_number], _run_grade_color(grade))

func _run_grade_color(grade: String) -> Color:
	match grade:
		"S": return Color8(177, 62, 83)
		"A": return Color8(255, 205, 117)
		"B": return Color8(118, 66, 138)
		"C": return Color8(65, 166, 246)
		"F": return Color8(150, 156, 170)
		_: return Color.WHITE


func update_gold_indicator(indicator: Sprite2D, frames: Array[Texture2D], delta: float) -> float:
	if indicator == null or frames.is_empty():
		return 0.0
	var timer := fmod(delta, 0.48)
	var frame_index := mini(int(timer / 0.12), frames.size() - 1)
	indicator.texture = frames[frame_index]
	return timer


func _solid_texture(size: Vector2i, color: Color) -> Texture2D:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)


func _build_cooldown_hud(parent: Node) -> Dictionary:
	var result: Dictionary = {}
	var rows := [
		{"name": "TriangleCooldown", "label": "triangle_label", "base": "triangle_base", "fill": "triangle_fill", "position": Vector2(197, 40), "bar_position": Vector2(212, 41)},
		{"name": "ImbueCooldown", "label": "imbue_label", "base": "imbue_base", "fill": "imbue_fill", "position": Vector2(197, 50), "bar_position": Vector2(212, 51)},
	]
	for row in rows:
		var label := Sprite2D.new()
		label.name = row["name"] + "Label"
		label.centered = false
		label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		label.position = row["position"]
		label.z_index = 3
		parent.add_child(label)
		var base := Sprite2D.new()
		base.name = row["name"] + "Base"
		base.centered = false
		base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		base.texture = _solid_texture(Vector2i(24, 4), Color8(28, 31, 43, 220))
		base.position = row["bar_position"]
		base.z_index = 1
		parent.add_child(base)
		var fill := Sprite2D.new()
		fill.name = row["name"] + "Fill"
		fill.centered = false
		fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		fill.texture = _solid_texture(Vector2i(24, 4), Color.WHITE)
		fill.position = row["bar_position"]
		fill.z_index = 2
		parent.add_child(fill)
		set_fill_ratio(fill, Vector2(24, 4), 1.0)
		result[row["label"]] = label
		result[row["base"]] = base
		result[row["fill"]] = fill
	return result


func build_world_hud(parent: Node, library: SpriteFrameLibrary, load_texture: Callable, target_bar: Sprite2D, _target_fill: Sprite2D, player_fill: Sprite2D) -> Dictionary:
	var layout := parent.get_node_or_null("PlayerHud") as Node2D
	var room_number := layout.get_node("RoomNumber") as Sprite2D if layout != null else Sprite2D.new()
	room_number.name = "RoomNumber"
	room_number.centered = false
	room_number.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	room_number.z_index = 2
	if layout == null:
		room_number.position = Vector2(5, 141)
		parent.add_child(room_number)
	var gold_display := layout.get_node_or_null("GoldDisplay") as Node2D if layout != null else null
	var gold := layout.get_node("GoldDisplay/Gold") as Sprite2D if layout != null else Sprite2D.new()
	gold.name = "GoldIndicator"
	gold.centered = false
	gold.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gold.z_index = 2
	if layout == null:
		gold.position = Vector2(64, 2)
		parent.add_child(gold)
	if gold_display != null:
		gold_display.position.y = 2.0
	var gold_amount := layout.get_node("GoldDisplay/GoldAmount") as Sprite2D if layout != null else Sprite2D.new()
	gold_amount.name = "GoldAmount"
	gold_amount.centered = false
	gold_amount.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	gold_amount.z_index = 2
	if layout == null:
		gold_amount.position = Vector2(72, 2)
		parent.add_child(gold_amount)
	var soul_display := layout.get_node_or_null("SoulDisplay") as Node2D if layout != null else null
	if soul_display == null:
		soul_display = Node2D.new()
		soul_display.name = "SoulDisplay"
		soul_display.position = Vector2(205, 9) if layout != null else Vector2(64, 9)
		(layout if layout != null else parent).add_child(soul_display)
	else:
		soul_display.position = Vector2(205, 9) if layout != null else Vector2(64, 9)
	var soul_icon := soul_display.get_node_or_null("SoulIcon") as Sprite2D
	if soul_icon == null:
		soul_icon = Sprite2D.new()
		soul_icon.name = "SoulIcon"
		soul_display.add_child(soul_icon)
	soul_icon.position = Vector2.ZERO
	soul_icon.centered = false
	soul_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	soul_icon.z_index = 2
	var soul_amount := soul_display.get_node_or_null("SoulAmount") as Sprite2D
	if soul_amount == null:
		soul_amount = Sprite2D.new()
		soul_amount.name = "SoulAmount"
		soul_display.add_child(soul_amount)
	soul_amount.position = Vector2(7, 0)
	soul_amount.centered = false
	soul_amount.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	soul_amount.z_index = 2
	var run_timer := layout.get_node_or_null("RunTimer") as Sprite2D if layout != null else Sprite2D.new()
	run_timer.name = "RunTimer"
	run_timer.centered = false
	run_timer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	run_timer.z_index = 2
	if layout == null:
		run_timer.position = Vector2(174, 149)
		parent.add_child(run_timer)
	var dungeon_run := layout.get_node_or_null("DungeonRun") as Sprite2D if layout != null else Sprite2D.new()
	dungeon_run.name = "DungeonRun"
	dungeon_run.centered = false
	dungeon_run.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	dungeon_run.z_index = 2
	if layout == null:
		dungeon_run.position = Vector2(5, 149)
		parent.add_child(dungeon_run)
	var gold_frames := library.slice_frames("res://assets/artwork/GoldFresh2.png", Vector2i(5, 5))
	gold.hframes = 1
	gold.vframes = 1
	gold.frame = 0
	gold.texture = gold_frames[0] if not gold_frames.is_empty() else null
	soul_icon.hframes = 1
	soul_icon.vframes = 1
	soul_icon.frame = 0
	soul_icon.texture = _purple_coin_texture(gold_frames[0] if not gold_frames.is_empty() else null)
	var buttons: Array[Sprite2D] = []
	for data in [{"texture": "triangle55.png", "position": Vector2(224, 64)}, {"texture": "square55.png", "position": Vector2(219, 69)}, {"texture": "x55.png", "position": Vector2(224, 74)}, {"texture": "circle55.png", "position": Vector2(229, 69)}]:
		var button := Sprite2D.new()
		button.texture = load_texture.call("res://assets/artwork/" + data["texture"])
		button.set_meta("gamepad_texture", button.texture)
		button.centered = false
		button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.position = data["position"]
		button.z_index = 2
		parent.add_child(button)
		buttons.append(button)
	var cooldowns := _build_cooldown_hud(parent)
	var target_text := Sprite2D.new()
	target_text.name = "TargetHealthText"
	target_text.centered = true
	target_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	target_text.z_index = 3
	target_text.position = target_bar.position + target_bar.texture.get_size() * 0.5
	target_text.visible = false
	parent.add_child(target_text)
	var focus_label_base := Sprite2D.new()
	focus_label_base.name = "FocusLabelBase"
	focus_label_base.centered = false
	focus_label_base.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_label_base.z_index = 2
	focus_label_base.position = Vector2(120, 148)
	focus_label_base.visible = false
	parent.add_child(focus_label_base)
	var focus_label := Sprite2D.new()
	focus_label.name = "FocusLabel"
	focus_label.centered = false
	focus_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	focus_label.z_index = 3
	focus_label.position = Vector2(120, 148)
	focus_label.visible = false
	parent.add_child(focus_label)
	var player_text := layout.get_node("PlayerStatus/Health/HpText") as Sprite2D if layout != null else Sprite2D.new()
	player_text.name = "PlayerHealthText"
	player_text.centered = true
	player_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_text.z_index = 3
	player_text.position = player_fill.position + player_fill.texture.get_size() * 0.5 + Vector2(0, -1)
	if layout == null: parent.add_child(player_text)
	return {"room": room_number, "dungeon_run": dungeon_run, "gold": gold, "gold_amount": gold_amount, "soul": soul_icon, "soul_amount": soul_amount, "timer": run_timer, "gold_frames": gold_frames, "buttons": buttons, "cooldowns": cooldowns, "target_text": target_text, "focus_label": focus_label, "focus_label_base": focus_label_base, "player_text": player_text}


func _purple_coin_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var image := source.get_image()
	if image == null:
		return source
	image = image.duplicate()
	var target_hue: float = SOUL_ICON_COLOR.h
	var target_saturation: float = maxf(SOUL_ICON_COLOR.s, 0.45)
	for y in image.get_height():
		for x in image.get_width():
			var source_color := image.get_pixel(x, y)
			if source_color.a <= 0.0:
				continue
			image.set_pixel(x, y, Color.from_hsv(target_hue, target_saturation, source_color.v, source_color.a))
	return ImageTexture.create_from_image(image)


func update_aggro_markers(markers: Dictionary, _palette_name: String, _pixel_particle: Callable) -> void:
	var marker_texture := _aggro_marker_texture(_palette_name)
	for marker in markers.values():
		var aggro_marker := marker as Sprite2D
		if aggro_marker != null and marker_texture != null:
			aggro_marker.texture = marker_texture


func _aggro_marker_texture(palette_name: String) -> Texture2D:
	var shadow_color: Color = PaletteLibrary.shadow(palette_name)
	var normal_color: Color = PaletteLibrary.normal(palette_name)
	var key := "%s:%s:%s" % [palette_name, shadow_color.to_html(false), normal_color.to_html(false)]
	if aggro_marker_texture_cache.has(key):
		return aggro_marker_texture_cache[key] as Texture2D
	var source := load("res://assets/artwork/aggrodot(blue).png") as Texture2D
	if source == null:
		return null
	var source_image := source.get_image()
	var image := Image.create(source_image.get_width(), source_image.get_height(), false, Image.FORMAT_RGBA8)
	var center := Vector2i(floori(float(source_image.get_width()) * 0.5), floori(float(source_image.get_height()) * 0.5))
	for y in source_image.get_height():
		for x in source_image.get_width():
			var source_pixel := source_image.get_pixel(x, y)
			if source_pixel.a <= 0.0:
				continue
			var output_color := normal_color if Vector2i(x, y) == center else shadow_color
			image.set_pixel(x, y, Color(output_color.r, output_color.g, output_color.b, source_pixel.a))
	var texture := ImageTexture.create_from_image(image)
	aggro_marker_texture_cache[key] = texture
	return texture


func build_enemy_health_ui(
	slimes: Array[Sprite2D],
	target_health_fill: Sprite2D,
	target_health_bar: Sprite2D,
	player_health_fill: Sprite2D,
	_player_health_damage_fill: Sprite2D,
	hp_overhead: Sprite2D,
	hp_overhead_fill: Sprite2D,
	slime_green: Sprite2D,
	load_texture: Callable,
	bright_texture: Callable,
	duplicate_fill: Callable,
	register_overhead: Callable,
	pixel_particle: Callable
) -> Texture2D:
	var target_bar_paths := {"blue": "EnemyHpRedBar.png", "green": "EnemyHpRedBar.png", "red": "EnemyHpRedBar.png", "grey": "EnemyHpRedBar.png", "yellow": "EnemyHpRedBar.png", "orange": "EnemyHpRedBar.png", "aquamarine": "EnemyHpRedBar.png"}; var overhead_bar_paths := {"blue": "HpOverheadRedBar.png", "green": "HpOverheadRedBar.png", "red": "HpOverheadRedBar.png", "grey": "HpOverheadRedBar.png", "yellow": "HpOverheadRedBar.png", "orange": "HpOverheadRedBar.png", "aquamarine": "HpOverheadRedBar.png"}
	target_health_fill_textures.clear(); target_overhead_fill_textures.clear()
	for slime in slimes:
		var palette := String(slime.get("variant")); if not target_bar_paths.has(palette): palette = "green"
		target_health_fill_textures[slime] = load_texture.call("res://assets/artwork/" + target_bar_paths[palette]); target_overhead_fill_textures[slime] = load_texture.call("res://assets/artwork/" + overhead_bar_paths[palette])
	target_health_damage_fill_textures.clear(); target_overhead_damage_fill_textures.clear()
	for slime in slimes:
		target_health_damage_fill_textures[slime] = bright_texture.call(target_health_fill_textures.get(slime) as Texture2D)
		target_overhead_damage_fill_textures[slime] = bright_texture.call(target_overhead_fill_textures.get(slime) as Texture2D)
	target_overhead_frames.clear(); target_overhead_damage_fills.clear(); target_overhead_fills.clear(); target_overhead_offsets.clear(); target_overhead_fill_sizes.clear(); target_overhead_aggro_markers.clear(); target_overhead_aggro_offsets.clear()
	var target_damage_fill := duplicate_fill.call(target_health_fill, "EnemyHpDamageFill") as Sprite2D
	target_health_bar.z_index = 0; target_health_bar.z_as_relative = true; target_damage_fill.z_index = 1; target_health_fill.z_index = 2; target_damage_fill.z_as_relative = true; target_health_fill.z_as_relative = true; target_damage_fill.get_parent().move_child(target_damage_fill, target_health_fill.get_index())
	var player_damage_fill := duplicate_fill.call(player_health_fill, "HpBarDamageFill") as Sprite2D
	player_damage_fill.texture = bright_texture.call(player_health_fill.texture); player_damage_fill.z_index = 1; player_health_fill.z_index = 2; player_damage_fill.z_as_relative = true; player_health_fill.z_as_relative = true; player_damage_fill.get_parent().move_child(player_damage_fill, player_health_fill.get_index())
	var base_texture := player_health_fill.texture
	register_overhead.call(slime_green, hp_overhead, hp_overhead_fill, hp_overhead.global_position - slime_green.global_position, duplicate_fill, pixel_particle)
	for slime in slimes:
		if slime == slime_green: continue
		var frame := Sprite2D.new(); frame.name = "HpOverhead"; frame.texture = hp_overhead.texture; frame.centered = hp_overhead.centered; frame.position = hp_overhead.position; frame.z_index = 0; frame.z_as_relative = false; slime.add_child(frame)
		var damage_fill := Sprite2D.new(); damage_fill.name = "HpOverheadDamageFill"; damage_fill.texture = target_overhead_damage_fill_textures.get(slime, hp_overhead_fill.texture); damage_fill.centered = hp_overhead_fill.centered; damage_fill.position = hp_overhead_fill.position; damage_fill.z_index = 1; damage_fill.z_as_relative = false; slime.add_child(damage_fill)
		var fill := Sprite2D.new(); fill.name = "HpOverheadFill"; fill.texture = target_overhead_fill_textures.get(slime, hp_overhead_fill.texture); fill.centered = hp_overhead_fill.centered; fill.position = hp_overhead_fill.position; fill.z_index = 2; fill.z_as_relative = false; slime.add_child(fill)
		register_overhead.call(slime, frame, fill, hp_overhead.global_position - slime_green.global_position, duplicate_fill, pixel_particle)
	return base_texture


func refresh_enemy_palette_textures(slimes: Array[Sprite2D], load_texture: Callable, bright_texture: Callable) -> void:
	var target_bar_paths := {"blue": "EnemyHpRedBar.png", "green": "EnemyHpRedBar.png", "red": "EnemyHpRedBar.png", "grey": "EnemyHpRedBar.png", "yellow": "EnemyHpRedBar.png", "orange": "EnemyHpRedBar.png", "aquamarine": "EnemyHpRedBar.png"}; var overhead_bar_paths := {"blue": "HpOverheadRedBar.png", "green": "HpOverheadRedBar.png", "red": "HpOverheadRedBar.png", "grey": "HpOverheadRedBar.png", "yellow": "HpOverheadRedBar.png", "orange": "HpOverheadRedBar.png", "aquamarine": "HpOverheadRedBar.png"}
	for slime in slimes:
		var palette := String(slime.get("variant")); if not target_bar_paths.has(palette): palette = "green"
		var target_texture := load_texture.call("res://assets/artwork/" + target_bar_paths[palette]) as Texture2D; var overhead_texture := load_texture.call("res://assets/artwork/" + overhead_bar_paths[palette]) as Texture2D
		target_health_fill_textures[slime] = target_texture; target_health_damage_fill_textures[slime] = bright_texture.call(target_texture)
		target_overhead_fill_textures[slime] = overhead_texture; target_overhead_damage_fill_textures[slime] = bright_texture.call(overhead_texture)
		var overhead_fill := target_overhead_fills.get(slime) as Sprite2D; var overhead_damage := target_overhead_damage_fills.get(slime) as Sprite2D
		if overhead_fill != null: overhead_fill.texture = overhead_texture
		if overhead_damage != null: overhead_damage.texture = target_overhead_damage_fill_textures[slime]


func register_overhead_bar(slime: Sprite2D, frame: Sprite2D, fill: Sprite2D, offset: Vector2, duplicate_fill: Callable, _pixel_particle: Callable) -> void:
	var fill_texture := target_overhead_fill_textures.get(slime, fill.texture) as Texture2D
	if fill_texture != null: fill.texture = fill_texture
	var damage_fill := fill.get_parent().get_node_or_null("HpOverheadDamageFill") as Sprite2D
	if damage_fill == null: damage_fill = duplicate_fill.call(fill, "HpOverheadDamageFill") as Sprite2D; damage_fill.z_index = 1
	fill.z_index = 2
	var damage_fill_texture := target_overhead_damage_fill_textures.get(slime, damage_fill.texture) as Texture2D
	if damage_fill_texture != null: damage_fill.texture = damage_fill_texture
	var aggro_marker := fill.get_parent().get_node_or_null("AggroMarker") as Sprite2D
	if aggro_marker == null:
		aggro_marker = Sprite2D.new(); aggro_marker.name = "AggroMarker"; aggro_marker.texture = load("res://assets/artwork/aggrodot(blue).png") as Texture2D; aggro_marker.centered = false; aggro_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST; aggro_marker.position = Vector2.ZERO; aggro_marker.z_index = 3; aggro_marker.z_as_relative = false; fill.get_parent().add_child(aggro_marker)
	var aggro_offset := aggro_marker.position
	aggro_marker.top_level = true
	target_overhead_frames[slime] = frame; target_overhead_damage_fills[slime] = damage_fill; target_overhead_fills[slime] = fill; target_overhead_offsets[slime] = offset; target_overhead_fill_sizes[slime] = fill.texture.get_size() if fill.texture != null else Vector2.ZERO; target_overhead_aggro_markers[slime] = aggro_marker; target_overhead_aggro_offsets[slime] = aggro_offset
	frame.visible = false; damage_fill.visible = false; fill.visible = false; aggro_marker.visible = false


func duplicate_fill_sprite(source: Sprite2D, sprite_name: String) -> Sprite2D:
	var sprite := Sprite2D.new(); sprite.name = sprite_name; sprite.texture = source.texture; sprite.centered = source.centered; sprite.position = source.position; sprite.offset = source.offset; sprite.scale = source.scale; sprite.region_enabled = source.region_enabled; sprite.region_rect = source.region_rect; sprite.texture_filter = source.texture_filter; sprite.z_as_relative = source.z_as_relative; sprite.z_index = source.z_index; source.get_parent().add_child(sprite); return sprite


func brighter_bar_texture(source: Texture2D) -> Texture2D:
	if source == null: return null
	var key := "%s:%s" % [source.resource_path, source.get_instance_id()]
	if bright_bar_cache.has(key): return bright_bar_cache[key]
	var image: Image = source.get_image().duplicate()
	if image == null: return source
	var palette_step := {"B13E53": Color8(239, 125, 87), "3B5DC9": Color8(65, 166, 246), "38B764": Color8(167, 240, 112), "764E8E": Color8(170, 145, 167), "3A8A97": Color8(134, 203, 179)}
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if color.a > 0.0:
				var bright_color := palette_step.get("%02X%02X%02X" % [int(round(color.r * 255.0)), int(round(color.g * 255.0)), int(round(color.b * 255.0))], color) as Color
				image.set_pixel(x, y, Color(bright_color.r, bright_color.g, bright_color.b, color.a))
	var texture := ImageTexture.create_from_image(image); bright_bar_cache[key] = texture; return texture
