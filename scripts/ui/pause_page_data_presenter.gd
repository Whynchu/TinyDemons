extends RefCounted
class_name PausePageDataPresenter

## Owns the read-only Stats layout and data projection for Pause pages.
## Uses MenuPlayerContext and shared combat formulas, never the gameplay root.

const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")

const STAT_LABELS := ["VITALITY", "STRENGTH", "DEFENSE", "AGILITY", "INTELLIGENCE", "MIND"]
const COMBAT_LABELS := ["ATTACK POWER", "SPELL POWER", "PHYSICAL DEFENSE", "MAGIC DEFENSE", "MOVE SPEED", "ATTACK SPEED"]
const HEALTH_COLOR := Color8(238, 139, 139)
const CHROMA_COLOR := Color8(128, 202, 242)
const PROGRESS_COLOR := Color8(255, 205, 117)

var _status_page: MenuScreen
var _status_values: Array[Sprite2D] = []
var _status_identity: Sprite2D
var _status_note: Sprite2D
var _status_points: Sprite2D
var _status_chroma_label: Sprite2D
var _status_progress_label: Sprite2D
var _attribute_window: NinePatchRect
var _combat_window: NinePatchRect
var _status_bars: Array[ColorRect] = []
var _bar_fractions: Array[float] = [0.0, 0.0, 0.0]


func build_status(page: MenuScreen, pixel_texture: Callable, widgets: MenuWidgetFactory) -> Array[Sprite2D]:
	_status_page = page
	page.title_width = 60.0
	page.show_header_window = true
	page.set_heading("Title", "STATS", pixel_texture)
	_status_identity = widgets.create_sprite(page, "BuildIdentity", null, Vector2(70, 8), false)
	_status_values.clear()
	for index in 4:
		_status_values.append(widgets.create_sprite(page, "PauseStatus%d" % index, null, Vector2.ZERO, false))
	widgets.create_sprite(page, "HealthLabel", pixel_texture.call("HP", HEALTH_COLOR), Vector2(12, 29), false)
	_status_chroma_label = widgets.create_sprite(page, "ChromaLabel", pixel_texture.call("CHROMA", CHROMA_COLOR), Vector2.ZERO, false)
	_status_progress_label = widgets.create_sprite(page, "ProgressLabel", pixel_texture.call("NEXT LEVEL", PROGRESS_COLOR), Vector2(12, 49), false)
	_status_bars.clear()
	for bar_color: Color in [HEALTH_COLOR, CHROMA_COLOR, PROGRESS_COLOR]:
		var track := ColorRect.new()
		track.name = ["HealthBar", "ChromaBar", "ExperienceBar"][_status_bars.size()]
		track.color = Color8(43, 51, 67)
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(track)
		var fill := ColorRect.new()
		fill.name = "Fill"
		fill.color = bar_color
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		track.add_child(fill)
		_status_bars.append(track)
	_attribute_window = page.add_window("AttributesWindow", Rect2(4, 64, 114, 68))
	_combat_window = page.add_window("CombatWindow", Rect2(120, 64, 116, 68))
	for column in 2:
		var window := _attribute_window if column == 0 else _combat_window
		window.clip_contents = true
		widgets.create_sprite(window, "SectionTitle", pixel_texture.call("ATTRIBUTES" if column == 0 else "COMBAT", PROGRESS_COLOR), Vector2(8, 7), false)
		var labels: Array = STAT_LABELS if column == 0 else COMBAT_LABELS
		for row in 6:
			widgets.create_sprite(window, "Label%d" % row, pixel_texture.call(labels[row], PauseMenuLayoutScript.MUTED_TEXT_COLOR), Vector2(8, 18 + row * 8), false)
			_status_values.append(widgets.create_sprite(window, "Value%d" % row, null, Vector2.ZERO, false))
	_status_note = widgets.create_sprite(page, "BuildNote", pixel_texture.call("GEAR INCLUDED / BEFORE EFFECTS", PauseMenuLayoutScript.MUTED_TEXT_COLOR), Vector2.ZERO, false)
	_status_points = widgets.create_sprite(page, "StatPointsHint", null, Vector2.ZERO, false)
	position_status(page.size)
	return _status_values


func position_status(view_size: Vector2) -> void:
	if _status_page == null:
		return
	var middle := floorf(view_size.x * 0.5)
	var section_height := maxf(view_size.y - 92.0, 68.0)
	var row_pitch := floorf((section_height - 28.0) / 5.0)
	_attribute_window.position = Vector2(4, 64)
	_attribute_window.size = Vector2(middle - 6, section_height)
	_combat_window.position = Vector2(middle, 64)
	_combat_window.size = Vector2(view_size.x - middle - 4, section_height)
	_status_chroma_label.position = Vector2(middle + 10, 29)
	_right_align(_status_values[0], view_size.x - 10, 8)
	_right_align(_status_values[1], view_size.x - 12, 49)
	_right_align(_status_values[2], middle - 12, 29)
	_right_align(_status_values[3], view_size.x - 12, 29)
	for index in 12:
		var window := _attribute_window if index < 6 else _combat_window
		var row_y := 18 + (index % 6) * row_pitch
		(window.get_node("Label%d" % (index % 6)) as Sprite2D).position.y = row_y
		_right_align(_status_values[index + 4], window.size.x - 8, row_y)
	_status_bars[0].position = Vector2(12, 38)
	_status_bars[0].size = Vector2(middle - 24, 3)
	_status_bars[1].position = Vector2(middle + 10, 38)
	_status_bars[1].size = Vector2(view_size.x - middle - 22, 3)
	_status_bars[2].position = Vector2(12, 58)
	_status_bars[2].size = Vector2(view_size.x - 24, 2)
	for index in _status_bars.size():
		var fill := _status_bars[index].get_node("Fill") as ColorRect
		fill.size = Vector2(floorf(_status_bars[index].size.x * _bar_fractions[index]), _status_bars[index].size.y)
		fill.visible = _bar_fractions[index] > 0.0
	_status_note.position = Vector2(10, view_size.y - 18)
	_status_points.position = Vector2(10, view_size.y - 10)


func _right_align(sprite: Sprite2D, right: float, top: float) -> void:
	var text_width := float(sprite.texture.get_width()) if sprite.texture != null else 0.0
	sprite.position = Vector2(floorf(right - text_width), top)


func update_status(context: MenuPlayerContext, pixel_texture: Callable, status_texts: Array[Sprite2D], description_text: Sprite2D) -> void:
	if context == null or not context.is_valid():
		return
	var profile: PlayerProfile = context.profile
	var snapshot: CombatStatSnapshot = context.snapshot
	var tuning: CombatTuning = context.combat_tuning
	var player_tuning: PlayerTuning = context.player_tuning
	var xp_required := PlayerProfile.xp_required_for_level(profile.level, context.progression_tuning)
	var level_capped := profile.level >= PlayerProfile.MAX_LEVEL
	var values := [
		"LV %d" % profile.level,
		"LEVEL CAP REACHED" if level_capped else "%d / %d XP" % [profile.xp, xp_required],
		"%d / %d" % [context.current_health(), context.max_health()],
		"%d / %d" % [context.chroma(), context.max_chroma()],
		str(roundi(snapshot.vit)), str(roundi(snapshot.strength)), str(roundi(snapshot.def)),
		str(roundi(snapshot.agi)), str(roundi(snapshot.intelligence)), str(roundi(snapshot.mnd)),
		str(roundi(CombatCalculator.attack_power_for_snapshot(snapshot, tuning))),
		str(roundi(CombatCalculator.magic_power_for_snapshot(snapshot, tuning))),
		str(roundi(CombatCalculator.physical_defense_for_snapshot(snapshot))),
		str(roundi(CombatCalculator.magic_defense_for_snapshot(snapshot))),
		"%.2fx" % (player_tuning.agi_multiplier(snapshot.agi) if player_tuning != null else 1.0),
		"%.2fx" % (player_tuning.attack_multiplier_for_agi(snapshot.agi) if player_tuning != null else 1.0),
	]
	for index in mini(values.size(), status_texts.size()):
		status_texts[index].texture = pixel_texture.call(values[index], PROGRESS_COLOR if index == 1 else Color.WHITE) as Texture2D
	if _status_page != null:
		var identity := "%s / %s" % [PlayerProfile.normalize_player_name(profile.player_name), context.element_display_name()]
		var identity_width := _status_page.size.x - 90.0 - status_texts[0].texture.get_width()
		_status_identity.texture = pixel_texture.call(identity, Color.WHITE) as Texture2D
		while _status_identity.texture.get_width() > identity_width and identity.length() > 1:
			identity = identity.left(-1)
			_status_identity.texture = pixel_texture.call(identity + "..", Color.WHITE) as Texture2D
		_bar_fractions[0] = clampf(float(context.current_health()) / maxf(context.max_health(), 1.0), 0.0, 1.0)
		_bar_fractions[1] = clampf(float(context.chroma()) / maxf(context.max_chroma(), 1.0), 0.0, 1.0)
		_bar_fractions[2] = 1.0 if level_capped else clampf(float(profile.xp) / maxf(xp_required, 1.0), 0.0, 1.0)
		_status_progress_label.texture = pixel_texture.call("MAX LEVEL" if level_capped else "NEXT LEVEL", PROGRESS_COLOR) as Texture2D
		var points := maxi(profile.unspent_stat_points, 0)
		var hint := "%d %s TO SPEND AT DEMON HUB" % [points, "POINT" if points == 1 else "POINTS"] if points > 0 else "SPEND STAT POINTS AT DEMON HUB"
		_status_points.texture = pixel_texture.call(hint, PROGRESS_COLOR if points > 0 else PauseMenuLayoutScript.MUTED_TEXT_COLOR) as Texture2D
		position_status(_status_page.size)
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
