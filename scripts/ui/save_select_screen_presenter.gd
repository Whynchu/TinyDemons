extends RefCounted
class_name SaveSelectScreenPresenter

const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")

var overlay: ColorRect = null
var footer_text: Sprite2D = null


func build(parent: Node, view_size: Vector2, pixel_texture: Callable, select_callback: Callable, overwrite_yes: Callable, overwrite_no: Callable, portrait_texture: Callable, back_callback: Callable, widget_factory: MenuWidgetFactory) -> ColorRect:
	overlay = widget_factory.create_overlay(parent, "SaveSelectOverlay", view_size, Color.BLACK, 4, false)
	overlay.set_meta("display_full_view", true)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	widget_factory.create_sprite(overlay, "SaveSelectTitle", pixel_texture.call("CHOOSE SAVE", Color.WHITE) as Texture2D, Vector2((view_size.x - 64.0) * 0.5, 42), false)
	widget_factory.create_sprite(overlay, "SaveSelectCursor", MENU_CURSOR_TEXTURE, Vector2((view_size.x - 130.0) * 0.5, 70), false)
	var prompt := widget_factory.create_sprite(overlay, "OverwritePrompt", pixel_texture.call("OVERWRITE?  YES / NO", Color.WHITE) as Texture2D, Vector2((view_size.x - 100.0) * 0.5, 126), false)
	prompt.visible = false
	var prompt_cursor := widget_factory.create_sprite(overlay, "OverwriteCursor", MENU_CURSOR_TEXTURE, Vector2((view_size.x - 42.0) * 0.5, 140), false)
	prompt_cursor.visible = false
	var yes := widget_factory.make_retro_button("YES", Vector2((view_size.x - 30.0) * 0.5, 137), Vector2(24, 12), pixel_texture)
	yes.name = "OverwriteYes"
	yes.visible = false
	yes.pressed.connect(overwrite_yes)
	overlay.add_child(yes)
	var no := widget_factory.make_retro_button("NO", Vector2((view_size.x + 30.0) * 0.5, 137), Vector2(20, 12), pixel_texture)
	no.name = "OverwriteNo"
	no.visible = false
	no.pressed.connect(overwrite_no)
	overlay.add_child(no)
	for slot in ProfileSaveService.SLOT_COUNT:
		var profile := ProfileSaveService.load_profile_for_slot(slot)
		var label := "SAVE %d  EMPTY" % (slot + 1)
		var palette_name := "blue"
		if profile != null and profile.has_started:
			label = "SAVE %d  %s" % [slot + 1, PlayerProfile.normalize_player_name(profile.player_name)]
			var flame := profile.starter_flame
			palette_name = AspectCatalog.palette_for_flame(flame)
			if palette_name == "grey" and not profile.palette_name.is_empty():
				palette_name = profile.palette_name
			if profile.has_bound_element:
				palette_name = AspectCatalog.palette_for_flame(profile.bound_element)
		var button := widget_factory.make_retro_button(label, Vector2((view_size.x - 112.0) * 0.5, 66 + slot * 20), Vector2(112, 18), pixel_texture)
		button.focus_mode = Control.FOCUS_NONE
		button.disabled = false
		button.set_meta("save_slot", slot)
		button.pressed.connect(select_callback.bind(slot))
		overlay.add_child(button)
		var label_sprite := button.get_child(0) as Sprite2D
		if label_sprite != null:
			label_sprite.position = Vector2(67, 9)
		if profile != null and profile.has_started and portrait_texture.is_valid():
			var portrait := Sprite2D.new()
			portrait.name = "Save%dPortrait" % slot
			portrait.texture = portrait_texture.call(palette_name, profile.has_demon_cloak_equipped()) as Texture2D
			portrait.position = Vector2(1, 1)
			portrait.centered = false
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			portrait.z_index = 1
			button.add_child(portrait)
	var nav_back := widget_factory.make_retro_button("BACK", Vector2(12, view_size.y - 23.0), Vector2(42, 18), pixel_texture)
	nav_back.name = "SaveNavBack"
	nav_back.focus_mode = Control.FOCUS_NONE
	if back_callback.is_valid():
		nav_back.pressed.connect(back_callback)
	overlay.add_child(nav_back)
	footer_text = widget_factory.create_sprite(overlay, "SaveSelectFooter", pixel_texture.call("A BACK", Color8(148, 220, 255)) as Texture2D, Vector2(view_size.x - 64.0, view_size.y - 18.0), false)
	for child in overlay.get_children():
		if child is Button and (child as Button).name in [&"OverwriteYes", &"OverwriteNo"]:
			(child as Button).focus_mode = Control.FOCUS_NONE
	return overlay


func position_controls(view_size: Vector2) -> void:
	if footer_text != null:
		footer_text.position = Vector2(view_size.x - 64.0, view_size.y - 18.0)
