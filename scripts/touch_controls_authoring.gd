@tool
extends Control

## Editor-only authoring surface for the logical 240x160 touch layout.
## Move the action nodes around Roll, then press `Save Layout Profile` in the
## Inspector to serialize their offsets into the runtime profile resource.

const PROFILE_SCRIPT = preload("res://scripts/touch_controls_layout_profile.gd")
const PROFILE_PATH := "res://resources/definitions/touch_controls_layout.tres"
const ACTIONS := [&"attack", &"magic", &"guard", &"target"]


@export_tool_button("Save Layout Profile", "Save") var save_layout_profile: Callable

func _enter_tree() -> void:
	if save_layout_profile.is_null():
		save_layout_profile = Callable(self, "_write_profile")

func _ready() -> void:
	if Engine.is_editor_hint():
		_style_preview()
		queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_style_preview()
		queue_redraw()

func _style_preview() -> void:
	var labels := {
		&"Roll": "ROLL",
		&"Attack": "ATK",
		&"Magic": "MAG",
		&"Guard": "GUARD",
		&"Target": "TGT",
	}
	for node_name in labels:
		var node := get_node_or_null(String(node_name)) as Panel
		if node == null:
			continue
		node.add_theme_stylebox_override("panel", _preview_style(node_name == &"Roll"))
		var label := node.get_node_or_null("Label") as Label
		if label == null:
			label = Label.new()
			label.name = "Label"
			label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			node.add_child(label)
		label.text = str(labels[node_name])
		label.add_theme_color_override("font_color", Color(0.92, 0.94, 1.0, 0.96))
		label.add_theme_font_size_override("font_size", 7 if node_name != &"Roll" else 8)
	var stick := get_node_or_null("StickPreview") as Panel
	if stick != null:
		stick.add_theme_stylebox_override("panel", _preview_style(false))
	var knob := get_node_or_null("StickKnob") as Panel
	if knob != null:
		knob.add_theme_stylebox_override("panel", _preview_style(false))

func _preview_style(primary: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.92) if primary else Color(0.04, 0.05, 0.08, 0.86)
	style.border_color = Color(0.80, 0.86, 1.0, 0.95) if primary else Color(0.46, 0.52, 0.66, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(18 if primary else 12)
	return style

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(240, 160)), Color("111522"), true)
	draw_line(Vector2(120, 0), Vector2(120, 160), Color(0.3, 0.35, 0.5, 0.25), 1.0)
	draw_line(Vector2(0, 80), Vector2(240, 80), Color(0.3, 0.35, 0.5, 0.25), 1.0)
	var roll := get_node_or_null("Roll") as Control
	if roll != null:
		for action in ACTIONS:
			var node := get_node_or_null(String(action)) as Control
			if node != null:
				draw_line(roll.position + roll.size * 0.5, node.position + node.size * 0.5, Color(0.45, 0.65, 1.0, 0.35), 1.0)

func _write_profile() -> void:
	var roll := get_node_or_null("Roll") as Control
	if roll == null:
		push_error("TouchControlsAuthoring: Roll node is required")
		return
	var profile := PROFILE_SCRIPT.new() as TouchControlsLayoutProfile
	var roll_center := roll.position + roll.size * 0.5
	for action in ACTIONS:
		var node := get_node_or_null(String(action).capitalize()) as Control
		if node == null:
			push_error("TouchControlsAuthoring: missing node %s" % action)
			return
		profile.set(String(action) + "_offset", node.position + node.size * 0.5 - roll_center)
	var error := ResourceSaver.save(profile, PROFILE_PATH)
	if error != OK:
		push_error("TouchControlsAuthoring: failed to save profile (%s)" % error)
	else:
		print("TOUCH_LAYOUT_PROFILE_SAVED %s" % PROFILE_PATH)
