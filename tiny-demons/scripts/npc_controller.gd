extends Node
class_name NpcController

var full_message := ""
var character_index := 0
var type_timer := 0.0
var button_timer := 0.0
var dialogue_complete := false


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
	return {"layer": layer, "box": box, "text": text, "button": button, "shadow": shadow}
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


func update_dialogue(delta: float, box: ColorRect, text: Sprite2D, button: Sprite2D, button_shadow: Sprite2D, head_position: Vector2, pixel_texture: Callable, snap_position: Callable, type_interval: float, button_bob_time: float) -> void:
	if box == null or not box.visible:
		return
	if not dialogue_complete:
		type_timer += delta
		while type_timer >= type_interval and character_index < full_message.length():
			type_timer -= type_interval
			character_index += 1
			text.texture = pixel_texture.call(full_message.substr(0, character_index), Color.WHITE) as Texture2D
		if character_index >= full_message.length():
			dialogue_complete = true
			button.visible = true
	var full_text_texture := pixel_texture.call(full_message, Color.WHITE) as Texture2D
	var box_size := full_text_texture.get_size() + Vector2(10, 10)
	var box_position := snap_position.call(head_position + Vector2(-box_size.x * 0.5, -box_size.y - 6)) as Vector2
	box.position = box_position
	box.size = box_size
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
