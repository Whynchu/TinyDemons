extends RefCounted
class_name PauseScreenPresenter

signal debug_page_requested
signal debug_action_requested(action: StringName, amount: int)

const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/menus/pause/pause_menu.tscn")
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")
const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")
const DebugMenuLayoutScript = preload("res://scripts/editor/debug_menu_layout.gd")
const SoulVisualsScript = preload("res://scripts/runtime/services/soul_visuals.gd")
const STATUS_LEFT_ROW_COUNT := 10

var overlay: ColorRect = null
var title_text: Sprite2D = null
var menu_buttons: Array[Button] = []
var cursor_text: Sprite2D = null
var root_page: Control = null
var page_roots: Dictionary = {}
var player_card_texts: Array[Sprite2D] = []
var player_portrait: Sprite2D = null
var gold_icon: Sprite2D = null
var gold_text: Sprite2D = null
var soul_text: Sprite2D = null
var resource_icon: Sprite2D = null
var status_texts: Array[Sprite2D] = []
var equipment_texts: Array[Sprite2D] = []
var description_text: Sprite2D = null
var back_button: Button = null
var status_button: Button = null
var equipment_button: Button = null
var settings_button: Button = null
var debug_button: Button = null
var quit_button: Button = null
var equipment_menu: Control = null
var debug_menu_layout: RefCounted = null
var debug_menu_buttons: Array[Button] = []


func build(
	parent: Node,
	view_size: Vector2,
	pixel_texture: Callable,
	actions: HubScreenActions,
	widget_factory: MenuWidgetFactory,
	set_hub_action_column: Callable
) -> void:
	var built_overlay := PAUSE_MENU_SCENE.instantiate() as ColorRect
	if built_overlay == null:
		return
	built_overlay.name = "PauseOverlay"
	built_overlay.position = Vector2.ZERO
	built_overlay.size = view_size
	built_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	built_overlay.z_index = 4
	built_overlay.visible = false
	built_overlay.set_meta("display_full_view", true)
	parent.add_child(built_overlay)
	var pause_title := built_overlay.get_node_or_null("PauseTitle") as Sprite2D
	root_page = built_overlay.get_node_or_null("PauseRootPage") as Control
	var status_page := built_overlay.get_node_or_null("PauseStatusPage") as Control
	var equipment_page := built_overlay.get_node_or_null("PauseEquipmentPage") as Control
	equipment_menu = equipment_page.get_node_or_null("EquipmentMenu") as EquipmentMenuLayout if equipment_page != null else null
	if equipment_menu != null:
		equipment_menu.visible = false
		equipment_menu.set_read_only(false)
		equipment_menu.set_pixel_texture(pixel_texture)
		if equipment_menu.has_signal("navigation_back_pressed"):
			if actions.pause_equipment_back.is_valid(): equipment_menu.navigation_back_pressed.connect(actions.pause_equipment_back)
			elif actions.pause_back.is_valid(): equipment_menu.navigation_back_pressed.connect(actions.pause_back)
		if equipment_menu.has_signal("command_pressed"):
			equipment_menu.command_pressed.connect(func(index: int):
				set_hub_action_column.call(index)
				if index == 0 and actions.item_action.is_valid(): actions.item_action.call()
				elif index == 1 and actions.equipment_remove.is_valid(): actions.equipment_remove.call()
				elif index == 2 and actions.equipment_remove_all.is_valid(): actions.equipment_remove_all.call())
		if equipment_menu.has_signal("slot_pressed") and actions.select_gear_slot.is_valid():
			equipment_menu.slot_pressed.connect(func(index: int): actions.select_gear_slot.call(index))
		if equipment_menu.has_signal("candidate_pressed") and actions.select_gear_candidate.is_valid():
			equipment_menu.candidate_pressed.connect(func(index: int): actions.select_gear_candidate.call(index))
		if equipment_menu.has_signal("remove_all_confirmed"):
			equipment_menu.remove_all_confirmed.connect(func(accepted: bool):
				if accepted and actions.equipment_remove_all.is_valid(): actions.equipment_remove_all.call()
				elif not accepted and actions.equipment_remove_all_cancel.is_valid(): actions.equipment_remove_all_cancel.call())
	var status_title := status_page.get_node_or_null("Title") as Sprite2D
	var equipment_title := equipment_page.get_node_or_null("Title") as Sprite2D
	if status_title != null: status_title.texture = pixel_texture.call("STATUS", Color.WHITE) as Texture2D
	if equipment_title != null: equipment_title.texture = pixel_texture.call("EQUIPMENT", Color.WHITE) as Texture2D
	page_roots = {0: root_page, 1: status_page, 2: equipment_page}
	player_portrait = built_overlay.get_node_or_null("PauseRootPage/PausePlayerPortrait") as Sprite2D
	gold_icon = built_overlay.get_node_or_null("PauseGoldIcon") as Sprite2D
	resource_icon = built_overlay.get_node_or_null("PauseResourceIcon") as Sprite2D
	player_card_texts.clear()
	for index in PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.size():
		player_card_texts.append(widget_factory.create_sprite(root_page, "PauseCardText%d" % index, null, PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[index], false))
	status_texts.clear()
	for index in 16:
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		status_texts.append(widget_factory.create_sprite(status_page, "PauseStatus%d" % index, null, Vector2(14 + column * 108, 28 + row * 10), false))
	equipment_texts.clear()
	for index in 8:
		equipment_texts.append(widget_factory.create_sprite(equipment_page, "PauseEquipment%d" % index, null, Vector2(14, 28 + index * 12), false))
	description_text = widget_factory.create_sprite(built_overlay, "PauseDescription", null, PauseMenuLayoutScript.select_prompt_position(view_size), false)
	gold_text = widget_factory.create_sprite(built_overlay, "PauseGoldText", null, PauseMenuLayoutScript.resource_text_position(view_size, 0.0, false), false)
	soul_text = widget_factory.create_sprite(built_overlay, "PauseSoulText", null, PauseMenuLayoutScript.resource_text_position(view_size, 0.0, true), false)
	menu_buttons.clear()
	var labels := ["STATUS", "EQUIPMENT", "SETTINGS", "DEBUG", "QUIT TITLE"]
	for index in labels.size():
		var button := widget_factory.make_menu_command_button(labels[index], PauseMenuLayoutScript.command_button_position(view_size, index), PauseMenuLayoutScript.COMMAND_BUTTON_SIZE, pixel_texture)
		button.name = "Pause%s" % labels[index].replace(" ", "").capitalize()
		button.focus_mode = Control.FOCUS_NONE
		if index == 0:
			if actions.pause_status.is_valid(): button.pressed.connect(actions.pause_status)
			elif actions.pause_set_page.is_valid(): button.pressed.connect(actions.pause_set_page.bind(1))
		elif index == 1:
			if actions.pause_equipment.is_valid(): button.pressed.connect(actions.pause_equipment)
			elif actions.pause_set_page.is_valid(): button.pressed.connect(actions.pause_set_page.bind(2))
		elif index == 2 and actions.pause_settings.is_valid(): button.pressed.connect(actions.pause_settings)
		elif index == 3: button.pressed.connect(_request_debug_page)
		elif index == 4 and actions.pause_quit.is_valid(): button.pressed.connect(actions.pause_quit)
		root_page.add_child(button)
		menu_buttons.append(button)
	back_button = widget_factory.make_menu_command_button("BACK", PauseMenuLayoutScript.back_button_position(view_size), PauseMenuLayoutScript.BACK_BUTTON_SIZE, pixel_texture)
	back_button.name = "PauseBack"
	back_button.focus_mode = Control.FOCUS_NONE
	if actions.pause_back.is_valid(): back_button.pressed.connect(actions.pause_back)
	built_overlay.add_child(back_button)
	cursor_text = widget_factory.create_sprite(root_page, "PauseCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false)
	cursor_text.visible = false
	debug_menu_layout = DebugMenuLayoutScript.new() as RefCounted
	var debug_controls := debug_menu_layout.call("build", built_overlay, pixel_texture, Callable(widget_factory, "make_menu_command_button"), MENU_CURSOR_TEXTURE) as Dictionary
	debug_menu_layout.connect(&"action_requested", Callable(self, "_forward_debug_action_requested"))
	page_roots[3] = debug_controls["page"] as Control
	debug_menu_buttons = debug_controls["buttons"] as Array[Button]
	overlay = built_overlay
	title_text = pause_title
	status_button = menu_buttons[0] if menu_buttons.size() > 0 else null
	equipment_button = menu_buttons[1] if menu_buttons.size() > 1 else null
	settings_button = menu_buttons[2] if menu_buttons.size() > 2 else null
	debug_button = menu_buttons[3] if menu_buttons.size() > 3 else null
	quit_button = menu_buttons[4] if menu_buttons.size() > 4 else null


func position_resource_texts(view_size: Vector2) -> void:
	if gold_text != null and gold_text.texture != null:
		gold_text.position = PauseMenuLayoutScript.resource_text_position(view_size, gold_text.texture.get_width(), false)
	if soul_text != null and soul_text.texture != null:
		soul_text.position = PauseMenuLayoutScript.resource_text_position(view_size, soul_text.texture.get_width(), true)


func update_player_info(context: MenuPlayerContext, pixel_texture: Callable, view_size: Vector2) -> void:
	if player_card_texts.is_empty() or context == null or not context.is_valid():
		return
	var profile: PlayerProfile = context.profile
	var values := [
		PlayerProfile.normalize_player_name(profile.player_name),
		context.element_display_name(),
		"HP",
		"%d/%d" % [context.current_health(), context.max_health()],
		"CHR",
		"%d/%d" % [context.chroma(), context.max_chroma()],
		"LV %d" % profile.level,
	]
	for index in player_card_texts.size():
		var text := player_card_texts[index]
		text.visible = true
		var label: String = str(values[index]) if index < values.size() else ""
		var label_color := PauseMenuLayoutScript.MUTED_TEXT_COLOR if index == 1 else Color.WHITE
		text.texture = pixel_texture.call(label, label_color) as Texture2D
	if player_portrait != null:
		var portrait_texture := context.portrait_texture()
		if portrait_texture != null:
			player_portrait.texture = portrait_texture
	update_resources(profile, pixel_texture, view_size)


func update_resources(profile: PlayerProfile, pixel_texture: Callable, view_size: Vector2) -> void:
	if profile == null:
		return
	if gold_icon != null:
		gold_icon.visible = true
	if resource_icon != null:
		resource_icon.visible = true
		resource_icon.texture = SoulVisualsScript.texture()
	if gold_text != null:
		gold_text.texture = pixel_texture.call(str(profile.gold), PauseMenuLayoutScript.GOLD_TEXT_COLOR) as Texture2D
	if soul_text != null:
		soul_text.texture = pixel_texture.call(str(profile.souls), SoulVisualsScript.SOUL_HIGHLIGHT_COLOR) as Texture2D
	position_resource_texts(view_size)


func update_status(context: MenuPlayerContext, pixel_texture: Callable) -> void:
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


func update_equipment(profile: PlayerProfile, pixel_texture: Callable) -> void:
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


func _request_debug_page() -> void:
	debug_page_requested.emit()


func _forward_debug_action_requested(action: StringName, amount: int) -> void:
	debug_action_requested.emit(action, amount)
