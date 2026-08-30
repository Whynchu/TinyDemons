extends Node
class_name CloudSavePanel

var root: Object
var service: CloudSaveService
var overlay: ColorRect
var key_input: LineEdit
var status_label: Label
var key_label: Label
var buttons: Array[Button] = []
var selected_row := 0
var restore_armed := false
var delete_armed := false

func configure(game_root: Object, cloud_service: CloudSaveService) -> void:
	root = game_root; service = cloud_service
	service.operation_completed.connect(_on_operation_completed)

func build(parent: Node) -> void:
	overlay = ColorRect.new(); overlay.name = "CloudSaveOverlay"; overlay.color = Color(0.015, 0.02, 0.035, 1); overlay.size = Vector2(240, 160); overlay.z_index = 40; overlay.visible = false; overlay.mouse_filter = Control.MOUSE_FILTER_STOP; parent.add_child(overlay)
	var title := Label.new(); title.text = "CLOUD SAVE"; title.position = Vector2(12, 7); title.add_theme_font_size_override("font_size", 14); overlay.add_child(title)
	var help := Label.new(); help.text = "No account needed. Keep your recovery key safe."; help.position = Vector2(12, 27); help.size = Vector2(216, 22); help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; help.add_theme_font_size_override("font_size", 8); overlay.add_child(help)
	key_input = LineEdit.new(); key_input.placeholder_text = "TD1 recovery key"; key_input.position = Vector2(12, 51); key_input.size = Vector2(216, 20); key_input.add_theme_font_size_override("font_size", 8); overlay.add_child(key_input)
	var labels := ["CREATE", "COPY KEY", "RESTORE", "SYNC", "DELETE", "BACK"]
	for index in labels.size():
		var button := Button.new(); button.text = labels[index]; button.position = Vector2(12 + (index % 3) * 73, 77 + (index / 3) * 22); button.size = Vector2(68, 18); button.focus_mode = Control.FOCUS_NONE; overlay.add_child(button); buttons.append(button)
	buttons[0].pressed.connect(_create); buttons[1].pressed.connect(_copy_key); buttons[2].pressed.connect(_restore); buttons[3].pressed.connect(_sync); buttons[4].pressed.connect(_delete); buttons[5].pressed.connect(close)
	key_label = Label.new(); key_label.position = Vector2(12, 122); key_label.size = Vector2(216, 15); key_label.add_theme_font_size_override("font_size", 7); key_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; overlay.add_child(key_label)
	status_label = Label.new(); status_label.position = Vector2(12, 138); status_label.size = Vector2(216, 18); status_label.add_theme_font_size_override("font_size", 7); status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; overlay.add_child(status_label)
	for child in overlay.get_children():
		if child is Control: (child as Control).set_meta("cloud_base_x", (child as Control).position.x)
	apply_layout(root.screen_state_controller.layout_view_size())

func apply_layout(view_size: Vector2) -> void:
	if overlay == null: return
	overlay.size = view_size
	var offset_x := maxf((view_size.x - 240.0) * 0.5, 0.0)
	for child in overlay.get_children():
		if child is Control and (child as Control).has_meta("cloud_base_x"):
			(child as Control).position.x = float((child as Control).get_meta("cloud_base_x")) + offset_x

func open() -> void:
	if overlay == null: return
	overlay.visible = true; status_label.text = "Cloud storage is ready." if service.configured() else "Cloud storage requires the Web build."
	if not service.recovery_key.is_empty(): key_input.text = service.recovery_key
	selected_row = 0; _update_selection()

func close() -> void:
	if overlay != null: overlay.visible = false
	restore_armed = false; delete_armed = false
	if root != null and root.get("screen_state_controller") != null: root.get("screen_state_controller").menu_input_release_lock = true

func update_input() -> void:
	if overlay == null or not overlay.visible: return
	if bool(root.call("_is_menu_back_just_pressed")): close(); return
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_left")): selected_row = posmod(selected_row - 1, buttons.size()); _update_selection()
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_right")): selected_row = posmod(selected_row + 1, buttons.size()); _update_selection()
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_up")): selected_row = posmod(selected_row - 3, buttons.size()); _update_selection()
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")): selected_row = posmod(selected_row + 3, buttons.size()); _update_selection()
	elif bool(root.call("_is_menu_confirm_just_pressed")): buttons[selected_row].pressed.emit()

func _update_selection() -> void:
	for index in buttons.size(): buttons[index].modulate = Color8(148, 220, 255) if index == selected_row else Color.WHITE
func _create() -> void: _clear_confirmations(); status_label.text = "Encrypting and creating backup..."; service.create_backup(ProfileSaveService.export_cloud_envelope())
func _copy_key() -> void:
	_clear_confirmations()
	if key_input.text.strip_edges().is_empty(): status_label.text = "Create or enter a recovery key first."; return
	DisplayServer.clipboard_set(key_input.text.strip_edges()); status_label.text = "Recovery key copied. Store it somewhere safe."
func _restore() -> void:
	delete_armed = false
	if not restore_armed: restore_armed = true; status_label.text = "RESTORE replaces matching local slots. Press RESTORE again."; return
	restore_armed = false; status_label.text = "Finding encrypted backup..."; service.restore_backup(key_input.text)
func _sync() -> void:
	_clear_confirmations()
	if not key_input.text.strip_edges().is_empty(): service.recovery_key = key_input.text.strip_edges()
	status_label.text = "Encrypting and syncing..."; service.sync_backup(ProfileSaveService.export_cloud_envelope())
func _delete() -> void:
	restore_armed = false
	if not delete_armed: delete_armed = true; status_label.text = "DELETE CLOUD is permanent. Press DELETE again."; return
	delete_armed = false; status_label.text = "Deleting cloud backup..."; service.delete_backup()

func _clear_confirmations() -> void: restore_armed = false; delete_armed = false

func _on_operation_completed(result: Dictionary) -> void:
	if not bool(result.get("ok", false)): status_label.text = str(result.get("error", "Cloud operation failed.")); return
	var action := str(result.get("action", ""))
	if action == "create":
		key_input.text = str(result.get("recovery_key", "")); key_label.text = "COPY THIS KEY: " + key_input.text; status_label.text = "Backup protected. Save this key outside the game."
	elif action == "restore":
		if ProfileSaveService.import_cloud_envelope(result.get("envelope", {}) as Dictionary):
			root.has_persistent_profile = ProfileSaveService.has_any_profile_save(); root.screen_state_controller.title_continue_button.disabled = not root.has_persistent_profile; status_label.text = "Cloud slots restored. You can now continue."
		else: status_label.text = "Backup decrypted, but its save format is invalid."
	elif action == "delete": status_label.text = "Cloud backup deleted."; key_label.text = ""
	else: status_label.text = "Cloud backup synchronized (revision %d)." % int(result.get("revision", 0))
