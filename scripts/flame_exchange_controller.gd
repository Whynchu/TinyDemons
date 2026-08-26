extends Node
class_name FlameExchangeController

## Explicit action menu for a contacted elemental flame. The gameplay state
## owns the transactions; this controller only presents the choices and routes
## confirmed input so Fusion can never happen implicitly.

var menu_layer: CanvasLayer = null
var panel: ColorRect = null
var title_text: Sprite2D = null
var current_text: Sprite2D = null
var swap_text: Sprite2D = null
var fuse_text: Sprite2D = null
var footer_text: Sprite2D = null
var active := false
var choice := 0
var input_was_down := false

const PANEL_POSITION := Vector2(28, 43)
const PANEL_SIZE := Vector2(184, 74)
const PADDING := Vector2(7, 5)
const SELECTED_COLOR := Color8(255, 205, 117)
const DISABLED_COLOR := Color8(102, 108, 122)
const SECONDARY_COLOR := Color8(183, 191, 210)


func open(root: Object) -> void:
	if active or not bool(root.call("_can_interact_with_fire")):
		return
	_ensure_menu(root)
	active = true
	choice = 0
	input_was_down = bool(root.call("_is_interact_input_pressed"))
	panel.visible = true
	root.set("player_is_moving", false)
	root.set("player_is_attacking", false)
	root.set("player_is_rolling", false)
	root.set("player_is_defending", false)
	root.call("_set_target_ui_visible", false)
	var prompt := root.get("interact_prompt") as Sprite2D
	if prompt != null:
		prompt.visible = false
	_update_menu(root)
	root.call("_play_sound", "ui_confirm", -4.0, 1.0)


func close(root: Object, play_sound := false) -> void:
	if not active:
		return
	active = false
	input_was_down = false
	if panel != null:
		panel.visible = false
	# The interaction key may still be held on the frame that confirmed or
	# cancelled the menu. Require a release before the world can reopen it.
	root.set("interact_input_was_down", true)
	if play_sound:
		root.call("_play_sound", "ui_decline", 0.0, 1.0)


func update_input(root: Object) -> void:
	if not active:
		return
	var input_down: bool = root.call("_is_interact_input_pressed")
	var input_pressed := input_down and not input_was_down
	if bool(root.call("_is_ui_cancel_just_pressed")):
		close(root, true)
		return
	if bool(root.call("_is_ui_direction_just_pressed", &"ui_up")) or bool(root.call("_is_ui_direction_just_pressed", &"ui_down")) or bool(root.call("_is_ui_direction_just_pressed", &"ui_left")) or bool(root.call("_is_ui_direction_just_pressed", &"ui_right")):
		choice = 1 - choice
		_update_menu(root)
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif input_pressed or bool(root.call("_is_ui_accept_just_pressed")):
		var accepted := false
		if choice == 0:
			accepted = bool(root.call("_interact_with_fire"))
		else:
			accepted = bool(root.call("_fuse_with_fire"))
		if accepted:
			close(root)
		else:
			_update_menu(root)
	input_was_down = input_down


func _ensure_menu(root: Object) -> void:
	if menu_layer != null and is_instance_valid(menu_layer):
		return
	menu_layer = CanvasLayer.new()
	menu_layer.name = "FlameExchangeLayer"
	menu_layer.layer = 21
	root.add_child(menu_layer)
	panel = ColorRect.new()
	panel.name = "FlameExchangePanel"
	panel.position = PANEL_POSITION
	panel.size = PANEL_SIZE
	panel.color = Color(0.0, 0.0, 0.0, 0.94)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	menu_layer.add_child(panel)
	title_text = _make_text("FLAME", root)
	current_text = _make_text("", root)
	swap_text = _make_text("", root)
	fuse_text = _make_text("", root)
	footer_text = _make_text("", root)
	for text_node in [title_text, current_text, swap_text, fuse_text, footer_text]:
		menu_layer.add_child(text_node)


func _make_text(_text: String, _root: Object) -> Sprite2D:
	var result := Sprite2D.new()
	result.centered = false
	result.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	result.z_as_relative = false
	result.z_index = 1
	result.visible = true
	return result


func _set_text(root: Object, node: Sprite2D, value: String, color: Color, y: float) -> void:
	if node == null:
		return
	node.texture = root.call("_pixel_text_texture", value, color)
	node.position = PANEL_POSITION + Vector2(PADDING.x, y)


func _update_menu(root: Object) -> void:
	if panel == null:
		return
	var target_palette := str(root.call("_fire_target_palette"))
	var target_flame := String(root.call("_fire_target_flame"))
	var current_flame := String(root.call("_current_player_flame"))
	var fusion_result := String(root.call("_fire_fusion_result"))
	var profile := root.get("player_profile") as PlayerProfile
	var souls := profile.souls if profile != null else 0
	var current_identity := "GRAY"
	if current_flame != "gray":
		var chroma := root.get("player_chroma_component") as Node
		var bound := chroma != null and bool(chroma.call("current_is_bound"))
		current_identity = "%s %s" % [current_flame.to_upper(), "BOUND" if bound else "UNBOUND"]
	var swap_enabled := souls >= int(root.get("FLAME_SWAP_SOUL_COST"))
	var fuse_enabled := not fusion_result.is_empty() and souls >= int(root.get("FLAME_FUSION_SOUL_COST"))
	_set_text(root, title_text, "FLAME", SELECTED_COLOR, 5)
	_set_text(root, current_text, "%s > %s" % [current_identity, target_flame.to_upper()], SECONDARY_COLOR, 17)
	_set_text(root, swap_text, "SWAP  %d SOULS" % int(root.get("FLAME_SWAP_SOUL_COST")), SELECTED_COLOR if choice == 0 and swap_enabled else DISABLED_COLOR if not swap_enabled else Color.WHITE, 31)
	var fuse_label := "FUSE  %s  %d SOULS" % [fusion_result.to_upper() if not fusion_result.is_empty() else "NO RECIPE", int(root.get("FLAME_FUSION_SOUL_COST"))]
	_set_text(root, fuse_text, fuse_label, SELECTED_COLOR if choice == 1 and fuse_enabled else DISABLED_COLOR if not fuse_enabled else Color.WHITE, 44)
	_set_text(root, footer_text, "%d SOULS  %s" % [souls, target_palette.to_upper()], Color8(145, 153, 174), 59)
