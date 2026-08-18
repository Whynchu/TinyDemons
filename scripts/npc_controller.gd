extends Node
class_name NpcController

var full_message := ""
var character_index := 0
var type_timer := 0.0
var button_timer := 0.0
var dialogue_complete := false
var allocation_prompt_active := false
var allocation_choice := 0
var dialogue_box: ColorRect = null
var dialogue_text: Sprite2D = null
var dialogue_button: Sprite2D = null
var dialogue_button_shadow: Sprite2D = null
var dialogue_yes_text: Sprite2D = null
var dialogue_no_text: Sprite2D = null
var dialogue_layer: CanvasLayer = null
var dialogue_input_was_down := false
var demon_idle_frames: Array[Texture2D] = []
var demon_walk_frames: Array[Texture2D] = []
var demon_animation_timer := 0.0
var demon_animation_frame := 0
var demon_wander_timer := 0.0
var demon_wander_origin := Vector2.ZERO
var demon_patrol_direction := -1.0
var demon_patrol_paused := false
var demon_patrol_pause_timer := 0.0
var demon_patrol_position_x := 0.0
var demon_patrol_min_x := 0.0
var demon_patrol_max_x := 0.0
var demon_wander_target := Vector2.ZERO
var demon_wander_has_target := false
var demon_visual_bounds := Rect2(12, 10, 12, 16)


func build_cloaked_demon_frames(library: SpriteFrameLibrary, actor: Sprite2D, frame_size: Vector2i, cached_image: Callable) -> Dictionary:
	var idle_frames := library.slice_frames("res://assets/artwork/TinyDemonCloacked-Idle.png", frame_size)
	var walk_frames := library.slice_frames("res://assets/artwork/TinyDemonCloacked-Walk.png", frame_size)
	var bounds := Rect2()
	if not idle_frames.is_empty():
		actor.texture = idle_frames[0]; actor.hframes = 1
		var used_rect: Rect2 = cached_image.call(actor.texture).get_used_rect()
		if used_rect.has_area(): bounds = Rect2(used_rect.position, used_rect.size)
	return {"idle": idle_frames, "walk": walk_frames, "bounds": bounds}


func configure_patrol_route(actor: Sprite2D, outline: PackedVector2Array, foot_position: Callable, is_walkable: Callable) -> Dictionary:
	if outline.is_empty() or actor == null: return {}
	var original_foot: Vector2 = foot_position.call(); var anchor_foot := original_foot
	if not is_walkable.call(anchor_foot):
		for step in range(1, 49):
			var distance := float(step) * 0.5
			for offset_x in [-distance, distance]:
				var candidate := original_foot + Vector2(offset_x, 0.0)
				if is_walkable.call(candidate): anchor_foot = candidate; break
			if anchor_foot != original_foot: break
	actor.global_position += anchor_foot - original_foot
	var patrol_foot: Vector2 = foot_position.call(); var left_extent := 0.0; var right_extent := 0.0
	for step in range(1, 25):
		var distance := float(step) * 0.5
		if is_walkable.call(patrol_foot + Vector2(-distance, 0.0)): left_extent = distance
		else: break
	for step in range(1, 25):
		var distance := float(step) * 0.5
		if is_walkable.call(patrol_foot + Vector2(distance, 0.0)): right_extent = distance
		else: break
	return {"min_x": actor.position.x - left_extent, "max_x": actor.position.x + right_extent, "origin": actor.position, "position_x": actor.position.x, "target": foot_position.call(), "has_target": false}

signal dialogue_requested


func update_dialogue_from_root(root: Object, delta: float) -> void:
	var box := dialogue_box
	if box == null or not box.visible: return
	if not (root.get("cloaked_demon") as Sprite2D).visible: hide_dialogue(root); return
	box.set_meta("dialogue_choice_active", allocation_prompt_active)
	update_dialogue(delta, box, dialogue_text, dialogue_button, dialogue_button_shadow, root.call("_cloaked_demon_head_position"), Callable(root, "_pixel_text_texture"), Callable(root, "_snap_half_pixel"), 0.045, root.get("NPC_DIALOGUE_BUTTON_BOB_TIME"), Callable(root.get("sound_manager"), "chatter") if root.get("sound_manager") != null else Callable())
	_update_allocation_choices(root)


func show_dialogue(root: Object) -> void:
	var demon := root.get("cloaked_demon") as Sprite2D
	if dialogue_box == null or not demon.visible: return
	var profile := root.get("player_profile") as PlayerProfile
	var message := "YOUR PATH AWAITS."
	if profile != null:
		message = "LV %d. %d PTS TO SPEND." % [profile.level, profile.unspent_stat_points] if profile.unspent_stat_points > 0 else "LV %d. READY TO TRADE." % profile.level
	allocation_prompt_active = false
	allocation_choice = 0
	begin_dialogue(message)
	var player_was_idle := String(root.get("player_anim_name")) == "idle"
	dialogue_text.texture = root.call("_pixel_text_texture", "", Color.WHITE); dialogue_text.visible = true; dialogue_button.visible = false; dialogue_input_was_down = root.call("_is_interact_input_pressed"); dialogue_box.visible = true; root.set("player_is_moving", false); root.set("player_is_attacking", false); root.set("player_is_rolling", false); (root.get("player_attack_visual") as Sprite2D).visible = false
	if not player_was_idle:
		root.set("player_anim_name", "idle"); root.set("player_anim_frame", 0); root.set("player_anim_timer", 0.0); (root.get("player_animation_component") as PlayerAnimationComponent).apply_frame(root)
	(root.get("interact_prompt") as Sprite2D).visible = false
	update_dialogue_from_root(root, 0.0)


func hide_dialogue(root: Object) -> void:
	end_dialogue()
	allocation_prompt_active = false
	allocation_choice = 0
	var box := dialogue_box; if box != null: box.visible = false
	var text := dialogue_text; if text != null: text.visible = false
	var button := dialogue_button; if button != null: button.visible = false
	var shadow := dialogue_button_shadow; if shadow != null: shadow.visible = false
	var yes_text := dialogue_yes_text; if yes_text != null: yes_text.visible = false
	var no_text := dialogue_no_text; if no_text != null: no_text.visible = false
	dialogue_input_was_down = false


func update_dialogue_input(root: Object) -> void:
	var input_down: bool = root.call("_is_interact_input_pressed")
	var input_pressed := input_down and not dialogue_input_was_down
	if allocation_prompt_active and dialogue_complete:
		if Input.is_action_just_pressed("ui_left") or Input.is_action_just_pressed("ui_right"):
			allocation_choice = 1 - allocation_choice
			_update_allocation_choices(root)
			root.call("_play_sound", "ui_hover", -6.0, 1.0)
		elif Input.is_action_just_pressed("ui_cancel"):
			root.call("_play_sound", "ui_decline", 0.0, 1.0)
			hide_dialogue(root)
		elif input_pressed or Input.is_action_just_pressed("ui_accept"):
			root.call("_play_sound", "ui_confirm", 0.0, 1.0)
			if allocation_choice == 0:
				hide_dialogue(root)
				root.call("_open_hub_from_cloaked_demon")
			else:
				hide_dialogue(root)
	elif dialogue_complete and (input_pressed or Input.is_action_just_pressed("ui_accept")):
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		allocation_prompt_active = true
		allocation_choice = 0
		begin_dialogue("OPEN STATS AND SHOP?")
		dialogue_text.texture = root.call("_pixel_text_texture", "", Color.WHITE) as Texture2D
		dialogue_button.visible = false
		dialogue_button_shadow.visible = false
		update_dialogue_from_root(root, 0.0)
	dialogue_input_was_down = input_down


func request_dialogue() -> void:
	dialogue_requested.emit()


func build_dialogue(parent: Node, continue_texture: Texture2D) -> Dictionary:
	var layer := CanvasLayer.new()
	layer.name = "NpcDialogueLayer"
	layer.layer = 20
	parent.add_child(layer)
	var box := ColorRect.new()
	box.name = "NpcDialogueBox"
	box.color = Color(0.0, 0.0, 0.0, 0.94)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.z_index = 0
	box.visible = false
	layer.add_child(box)
	var text := Sprite2D.new()
	text.name = "NpcDialogueText"
	text.centered = false
	text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	text.z_index = 1
	text.visible = false
	layer.add_child(text)
	var button := Sprite2D.new()
	button.name = "NpcDialogueContinue"
	button.texture = continue_texture
	button.centered = false
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.z_index = 3
	button.visible = false
	layer.add_child(button)
	var button_outline := Sprite2D.new()
	button_outline.name = "NpcDialogueContinueOutline"
	button_outline.texture = _highlight_button_texture(continue_texture)
	button_outline.position = Vector2(-1, -1)
	button_outline.centered = false
	button_outline.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button_outline.z_index = -1
	button.add_child(button_outline)
	var shadow := Sprite2D.new()
	shadow.name = "NpcDialogueContinueShadow"
	shadow.texture = continue_texture
	shadow.centered = false
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_index = 2
	shadow.self_modulate = Color(0.0, 0.0, 0.0, 0.45)
	shadow.visible = false
	layer.add_child(shadow)
	layer.move_child(shadow, -1)
	layer.move_child(button, -1)
	var yes_text := Sprite2D.new()
	yes_text.name = "NpcDialogueYes"
	yes_text.centered = false
	yes_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	yes_text.z_index = 2
	yes_text.visible = false
	layer.add_child(yes_text)
	var no_text := Sprite2D.new()
	no_text.name = "NpcDialogueNo"
	no_text.centered = false
	no_text.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	no_text.z_index = 2
	no_text.visible = false
	layer.add_child(no_text)
	return {"layer": layer, "box": box, "text": text, "button": button, "shadow": shadow, "yes": yes_text, "no": no_text}


func _update_allocation_choices(root: Object) -> void:
	var yes_text := dialogue_yes_text
	var no_text := dialogue_no_text
	var box := dialogue_box
	if yes_text == null or no_text == null or box == null:
		return
	var show_choices := allocation_prompt_active and dialogue_complete and box.visible
	yes_text.visible = show_choices
	no_text.visible = show_choices
	if not show_choices:
		return
	var selected_color := Color8(255, 205, 117)
	yes_text.texture = root.call("_pixel_text_texture", "YES", selected_color if allocation_choice == 0 else Color.WHITE)
	no_text.texture = root.call("_pixel_text_texture", "NO", selected_color if allocation_choice == 1 else Color.WHITE)
	if not bool(box.get_meta("choice_extension_applied", false)):
		box.size.y += 12.0
		box.set_meta("choice_extension_applied", true)
	var choice_y := box.size.y - 9.0
	var choice_group_x := maxf(box.size.x - 54.0, 7.0)
	yes_text.position = root.call("_snap_half_pixel", box.position + Vector2(choice_group_x, choice_y))
	no_text.position = root.call("_snap_half_pixel", box.position + Vector2(choice_group_x + 30.0, choice_y))


func _highlight_button_texture(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	var source_image := source.get_image()
	var image := Image.create(source_image.get_width() + 2, source_image.get_height() + 2, false, Image.FORMAT_RGBA8)
	for y in source_image.get_height():
		for x in source_image.get_width():
			if source_image.get_pixel(x, y).a <= 0.0:
				continue
			for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				var sample_x: int = x + offset.x
				var sample_y: int = y + offset.y
				if sample_x < 0 or sample_y < 0 or sample_x >= source_image.get_width() or sample_y >= source_image.get_height() or source_image.get_pixel(sample_x, sample_y).a <= 0.0:
					image.set_pixel(x + 1 + offset.x, y + 1 + offset.y, Color.WHITE)
	return ImageTexture.create_from_image(image)


func begin_dialogue(message: String) -> void:
	full_message = message
	character_index = 0
	type_timer = 0.0
	button_timer = 0.0
	dialogue_complete = false


func end_dialogue() -> void:
	full_message = ""
	character_index = 0
	type_timer = 0.0
	button_timer = 0.0
	dialogue_complete = false


func update_dialogue(delta: float, box: ColorRect, text: Sprite2D, button: Sprite2D, button_shadow: Sprite2D, head_position: Vector2, pixel_texture: Callable, snap_position: Callable, type_interval: float, button_bob_time: float, chatter: Callable = Callable()) -> void:
	if box == null or not box.visible:
		return
	if not dialogue_complete:
		type_timer += delta
		while type_timer >= type_interval and character_index < full_message.length():
			type_timer -= type_interval
			character_index += 1
			text.texture = pixel_texture.call(full_message.substr(0, character_index), Color.WHITE) as Texture2D
			if chatter.is_valid():
				chatter.call()
		if character_index >= full_message.length():
			dialogue_complete = true
			button.visible = true
	var full_text_texture := pixel_texture.call(full_message, Color.WHITE) as Texture2D
	var choice_height := 12.0 if bool(box.get_meta("dialogue_choice_active", false)) else 0.0
	# All standard demon lines are authored for this one-line budget. Keep the
	# box absolute rather than allowing a longer message to resize the UI.
	var minimum_text_texture := pixel_texture.call("OPEN STATS AND SHOP?", Color.WHITE) as Texture2D
	var box_size := Vector2(minimum_text_texture.get_width() + 10.0, full_text_texture.get_height() + 10.0 + choice_height)
	var box_position := snap_position.call(head_position + Vector2(-box_size.x * 0.5, -box_size.y - 6)) as Vector2
	box.position = box_position
	box.size = box_size
	box.set_meta("choice_extension_applied", choice_height > 0.0)
	text.position = snap_position.call(box_position + Vector2(5, 5))
	if button.visible:
		button_timer = fmod(button_timer + delta, button_bob_time)
		var button_bob := snappedf(sin((button_timer / button_bob_time) * TAU) * 0.5, 0.5)
		var button_size := button.texture.get_size()
		var button_position := snap_position.call(box_position + box_size - button_size * 0.5 + Vector2(0, -1)) as Vector2
		button.position = button_position + Vector2(0, button_bob)
		button_shadow.position = button_position + Vector2(0, button_bob) + Vector2(-0.5, 0.5)
		button_shadow.visible = true
	else:
		button_shadow.visible = false


func update_patrol_animation(actor: Sprite2D, idle_frames: Array[Texture2D], walk_frames: Array[Texture2D], delta: float, near_player: bool, patrolling: bool, patrol_paused: bool, wander_target: Vector2, has_target: bool, pause_timer: float, patrol_direction: float, player_x: float, random_source: RandomNumberGenerator, foot_position: Callable, random_point: Callable, move_actor: Callable, perspective: Callable, cache_texture: Callable, animation_timer: float, animation_frame: int) -> Dictionary:
	if actor == null or not actor.visible or idle_frames.is_empty():
		return {"wander_target": wander_target, "has_target": has_target, "paused": patrol_paused, "pause_timer": pause_timer, "direction": patrol_direction, "timer": animation_timer, "frame": animation_frame}
	var frames := idle_frames
	var frame_time := 0.28
	animation_timer += delta
	if patrolling and not patrol_paused and not walk_frames.is_empty():
		frames = walk_frames
		frame_time = 0.18
		var foot: Vector2 = foot_position.call()
		if not has_target:
			wander_target = random_point.call(foot, 24.0)
			has_target = true
		var direction := wander_target - foot
		if direction.length_squared() <= 1.0:
			has_target = false
			patrol_paused = true
			pause_timer = random_source.randf_range(1.1, 2.4)
		elif direction.length_squared() > 0.01:
			direction = direction.normalized()
			var moved: bool = move_actor.call(perspective.call(direction * 6.0 * delta), 0.5)
			if direction.x < -0.01: actor.flip_h = true
			elif direction.x > 0.01: actor.flip_h = false
			if not moved:
				has_target = false
				patrol_paused = true
				pause_timer = random_source.randf_range(1.1, 2.4)
	elif patrolling:
		pause_timer = maxf(pause_timer - delta, 0.0)
		actor.flip_h = patrol_direction < 0.0
		if pause_timer <= 0.0:
			patrol_paused = false
			patrol_direction *= -1.0
	elif near_player:
		actor.flip_h = player_x < actor.global_position.x
	if animation_timer < frame_time:
		return {"wander_target": wander_target, "has_target": has_target, "paused": patrol_paused, "pause_timer": pause_timer, "direction": patrol_direction, "timer": animation_timer, "frame": animation_frame}
	animation_timer = fmod(animation_timer, frame_time)
	animation_frame = (animation_frame + 1) % frames.size()
	actor.texture = frames[animation_frame]
	cache_texture.call(actor, actor.texture)
	return {"wander_target": wander_target, "has_target": has_target, "paused": patrol_paused, "pause_timer": pause_timer, "direction": patrol_direction, "timer": animation_timer, "frame": animation_frame}
