extends Node
class_name CloudSavePanel

var root: Object
var service: CloudSaveService
var overlay: ColorRect
var key_input: LineEdit
var status_texts: Array[Sprite2D] = []
var buttons: Array[Button] = []
var selected_row := 0
var restore_armed := false
var delete_armed := false
var _paste_poll_timer: Timer
var _paste_poll_started := 0

func configure(game_root: Object, cloud_service: CloudSaveService) -> void:
	root = game_root; service = cloud_service
	service.operation_completed.connect(_on_operation_completed)
	_paste_poll_timer = Timer.new(); _paste_poll_timer.wait_time = 0.15; _paste_poll_timer.timeout.connect(_poll_pasted_key); add_child(_paste_poll_timer)

func build(parent: Node) -> void:
	overlay = ColorRect.new(); overlay.name = "CloudSaveOverlay"; overlay.color = Color(0.015, 0.02, 0.035, 0.96); overlay.size = Vector2(240, 160); overlay.z_index = 40; overlay.visible = false; overlay.mouse_filter = Control.MOUSE_FILTER_STOP; parent.add_child(overlay)
	var pixel_texture := Callable(root, "_pixel_text_texture")
	var title: Sprite2D = root.screen_state_controller.create_sprite(overlay, "CloudSaveTitle", pixel_texture.call("CLOUD SAVE", Color8(148, 220, 255)) as Texture2D, Vector2(12, 7), false) as Sprite2D
	var help: Sprite2D = root.screen_state_controller.create_sprite(overlay, "CloudSaveHelp", pixel_texture.call("KEEP YOUR RECOVERY KEY SAFE", Color8(150, 156, 170)) as Texture2D, Vector2(12, 24), false) as Sprite2D
	key_input = LineEdit.new(); key_input.placeholder_text = "PASTE OR TYPE TD1- KEY"; key_input.position = Vector2(12, 36); key_input.size = Vector2(188, 23); key_input.add_theme_font_size_override("font_size", 8); key_input.virtual_keyboard_enabled = true; key_input.select_all_on_focus = false; key_input.clear_button_enabled = false; key_input.text_submitted.connect(_on_key_submitted); overlay.add_child(key_input)
	var clear_key: Button = root.screen_state_controller.make_retro_button("X", Vector2(204, 36), Vector2(24, 23), pixel_texture) as Button; clear_key.name = "ClearRecoveryKey"; clear_key.focus_mode = Control.FOCUS_NONE; clear_key.pressed.connect(_clear_key_input); overlay.add_child(clear_key)
	if root != null and root.get("screen_state_controller") != null: root.get("screen_state_controller").set_archetype_button_state(clear_key, false, Color8(239, 125, 87))
	var labels := ["CREATE BACKUP", "COPY KEY", "PASTE KEY", "RESTORE", "SYNC NOW", "DELETE CLOUD", "BACK"]
	for index in labels.size():
		var button_position: Vector2 = Vector2(12 + (index % 2) * 110, 78 + (index / 2) * 24) if index < 6 else Vector2(176, 5)
		var button_size: Vector2 = Vector2(106, 22) if index < 6 else Vector2(52, 20)
		var button: Button = root.screen_state_controller.make_retro_button(labels[index], button_position, button_size, pixel_texture) as Button; button.focus_mode = Control.FOCUS_NONE
		if index < 6:
			button.position = button_position; button.size = button_size
		overlay.add_child(button); buttons.append(button)
		if root != null and root.get("screen_state_controller") != null: root.get("screen_state_controller").set_archetype_button_state(button, false, Color8(148, 220, 255))
	buttons[0].pressed.connect(_create); buttons[1].pressed.connect(_copy_key); buttons[2].pressed.connect(_paste); buttons[3].pressed.connect(_restore); buttons[4].pressed.connect(_sync); buttons[5].pressed.connect(_delete); buttons[6].pressed.connect(close)
	status_texts.clear()
	for line_index in 2:
		status_texts.append(root.screen_state_controller.create_sprite(overlay, "CloudSaveStatus%d" % line_index, null, Vector2(12, 62 + line_index * 7), false))
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
	overlay.visible = true; _set_status("Cloud storage is ready." if service.configured() else "Cloud storage requires the Web build.")
	if not service.recovery_key.is_empty(): key_input.text = service.recovery_key
	selected_row = 0; _update_selection()

func close() -> void:
	if overlay != null: overlay.visible = false
	if key_input != null and key_input.has_focus(): key_input.release_focus()
	restore_armed = false; delete_armed = false
	if root != null and root.get("screen_state_controller") != null: root.get("screen_state_controller").menu_input_release_lock = true

func update_input() -> void:
	if overlay == null or not overlay.visible: return
	if bool(root.call("_is_menu_back_just_pressed")): close(); return
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_left")): selected_row = 6 if selected_row == 0 else selected_row - 1; _update_selection()
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_right")): selected_row = 0 if selected_row == 6 else selected_row + 1; _update_selection()
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_up")): selected_row = 6 if selected_row < 2 else selected_row - 2; _update_selection()
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")): selected_row = selected_row + 2 if selected_row < 4 else 6; _update_selection()
	elif bool(root.call("_is_menu_confirm_just_pressed")) and not key_input.has_focus(): buttons[selected_row].pressed.emit()

func _on_key_submitted(_text: String) -> void:
	_restore()

func _clear_key_input() -> void:
	key_input.clear()
	service.recovery_key = ""
	_set_status("Recovery key cleared.")

func _update_selection() -> void:
	for index in buttons.size():
		if root != null and root.get("screen_state_controller") != null: root.get("screen_state_controller").set_archetype_button_state(buttons[index], index == selected_row, Color8(148, 220, 255))
func _create() -> void: _clear_confirmations(); _set_status("Encrypting and creating backup..."); service.create_backup(ProfileSaveService.export_cloud_envelope())
func _copy_key() -> void:
	_clear_confirmations()
	if key_input.text.strip_edges().is_empty(): _set_status("Create or enter a recovery key first."); return
	DisplayServer.clipboard_set(key_input.text.strip_edges()); _set_status("Recovery key copied. Store it somewhere safe.")

func _paste() -> void:
	_clear_confirmations()
	if OS.has_feature("web"):
		# Godot's canvas LineEdit has no native paste menu on iOS. Read the
		# clipboard through the browser API and poll for the result. The done
		# flag is set on every path (success, rejection, or synchronous throw)
		# so the panel can never hang on "Reading clipboard...".
		_set_status("Reading clipboard...")
		_paste_poll_started = Time.get_ticks_msec()
		JavaScriptBridge.eval("window.__tdPastedKeyDone=false;try{if(!navigator.clipboard||!navigator.clipboard.readText)throw Error('no_clipboard');navigator.clipboard.readText().then(function(t){window.__tdPastedKey=t||'';window.__tdPastedKeyDone=true},function(){window.__tdPastedKey='';window.__tdPastedKeyDone=true})}catch(e){window.__tdPastedKey='';window.__tdPastedKeyDone=true}")
		_paste_poll_timer.start()
		return
	var text := DisplayServer.clipboard_get().strip_edges()
	if text.is_empty():
		_set_status("Clipboard is empty. Copy the key first.")
		return
	key_input.text = text
	_set_status("Recovery key pasted. You can now RESTORE.")

func _poll_pasted_key() -> void:
	if bool(JavaScriptBridge.eval("window.__tdPastedKeyDone || false")):
		_paste_poll_timer.stop()
		var text := str(JavaScriptBridge.eval("window.__tdPastedKey || ''"))
		if text.is_empty():
			_set_status("Clipboard is empty or blocked. Copy the key on this device first.")
			return
		key_input.text = text
		_set_status("Recovery key pasted. You can now RESTORE.")
		return
	if Time.get_ticks_msec() - _paste_poll_started > 3000:
		_paste_poll_timer.stop()
		_set_status("Clipboard read timed out. Allow clipboard access or type the key.")
func _restore() -> void:
	_clear_confirmations()
	if key_input.text.strip_edges().is_empty(): _set_status("Paste or type your recovery key first."); return
	_set_status("Finding encrypted backup..."); service.restore_backup(key_input.text)
func _sync() -> void:
	_clear_confirmations()
	if not key_input.text.strip_edges().is_empty(): service.recovery_key = key_input.text.strip_edges()
	_set_status("Encrypting and syncing..."); service.sync_backup(ProfileSaveService.export_cloud_envelope())
func _delete() -> void:
	restore_armed = false
	if not delete_armed: delete_armed = true; _set_status("DELETE CLOUD is permanent. Press DELETE again."); return
	delete_armed = false; _set_status("Deleting cloud backup..."); service.delete_backup()

func _clear_confirmations() -> void: restore_armed = false; delete_armed = false

func _on_operation_completed(result: Dictionary) -> void:
	if not bool(result.get("ok", false)): _set_status(str(result.get("error", "Cloud operation failed."))); return
	var action := str(result.get("action", ""))
	if action == "create":
		key_input.text = str(result.get("recovery_key", "")); _set_status("Backup protected. Save this key outside the game.")
	elif action == "restore":
		if ProfileSaveService.import_cloud_envelope(result.get("envelope", {}) as Dictionary):
			root.has_persistent_profile = ProfileSaveService.has_any_profile_save(); root.screen_state_controller.refresh_title_menu_layout(root.has_persistent_profile); _set_status("Cloud slots restored. You can now continue.")
		else: _set_status("Backup decrypted, but its save format is invalid.")
	elif action == "delete": _set_status("Cloud backup deleted.")
	else: _set_status("Cloud backup synchronized (revision %d)." % int(result.get("revision", 0)))

func _set_status(message: String) -> void:
	if status_texts.is_empty(): return
	var words := message.to_upper().split(" ")
	var lines: Array[String] = [""]
	for word in words:
		var candidate := str(word) if lines.back().is_empty() else lines.back() + " " + str(word)
		if candidate.length() <= 35 or lines.size() >= 2:
			lines[lines.size() - 1] = candidate
		else:
			lines.append(str(word))
	if lines.size() > 2: lines.resize(2)
	if lines.size() == 2 and lines[1].length() > 35: lines[1] = lines[1].left(32) + "..."
	var pixel_texture := Callable(root, "_pixel_text_texture")
	for index in status_texts.size():
		status_texts[index].texture = pixel_texture.call(lines[index] if index < lines.size() else "", Color.WHITE) as Texture2D
