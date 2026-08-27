@tool
extends Node2D
class_name AttackHitboxGuide

@export var attack_sheet: Texture2D:
	set(value):
		attack_sheet = value
		_refresh_deferred()
@export var frame_size := Vector2i(36, 36):
	set(value):
		frame_size = value
		_refresh_deferred()
@export_range(0, 15, 1) var frame_index := 2:
	set(value):
		frame_index = value
		_refresh_deferred()
@export var use_frame_hitboxes := false:
	set(value):
		use_frame_hitboxes = value
		_refresh_deferred()
@export var show_preview := true:
	set(value):
		show_preview = value
		_refresh_deferred()


func _ready() -> void:
	_refresh_preview()


func hitbox_for_frame(requested_frame: int = -1) -> Polygon2D:
	var selected_frame := frame_index if requested_frame < 0 else requested_frame
	if use_frame_hitboxes:
		var frame_hitbox := get_node_or_null("HitboxFrame%d" % selected_frame) as Polygon2D
		if frame_hitbox != null:
			return frame_hitbox
	return get_node_or_null("Hitbox") as Polygon2D


func world_polygon(mirror_h: bool, requested_frame: int = -1) -> PackedVector2Array:
	var hitbox := hitbox_for_frame(requested_frame)
	var result := PackedVector2Array()
	if hitbox == null:
		return result
	if mirror_h:
		for index in range(hitbox.polygon.size() - 1, -1, -1):
			var point := hitbox.polygon[index]; result.append(hitbox.to_global(Vector2(float(frame_size.x) - point.x, point.y)))
	else:
		for point in hitbox.polygon: result.append(hitbox.to_global(point))
	return result


func _refresh_deferred() -> void:
	if is_inside_tree():
		call_deferred("_refresh_preview")


func _refresh_preview() -> void:
	var preview := get_node_or_null("Preview") as Sprite2D
	var hitbox := hitbox_for_frame()
	if not Engine.is_editor_hint():
		visible = false
		return
	visible = true
	if preview != null:
		preview.visible = show_preview
		preview.texture = attack_sheet
		var frame_width := maxi(frame_size.x, 1)
		var frame_height := maxi(frame_size.y, 1)
		preview.hframes = maxi(1, floori(float(attack_sheet.get_width()) / float(frame_width))) if attack_sheet != null else 1
		preview.vframes = maxi(1, floori(float(attack_sheet.get_height()) / float(frame_height))) if attack_sheet != null else 1
		preview.frame = clampi(frame_index, 0, preview.hframes * preview.vframes - 1)
	for child in get_children():
		if child is Polygon2D:
			(child as Polygon2D).visible = show_preview and child == hitbox
