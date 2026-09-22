@tool
extends Node2D
class_name HubWorldPreview

## Editor-facing view of the authored Hub world.
##
## The production Hub currently lives inside main.tscn because the runtime uses
## the same room shell for the opening room and dungeon transitions. This
## preview deliberately reuses that scene as a visual source, but does not
## boot GameplayState, load a profile, or create a run. It is the safe design
## preview tier; interactive play belongs in a later isolated workbench.

const MAIN_SCENE_NODE := ^"Main"
const HUB_ROOM_ID: StringName = &"room_0_0"
const HUB_ROOM_TYPE: StringName = &"START"
const PREVIEW_VIEW_SIZE := Vector2(240.0, 160.0)
const FIRE_PATH := "res://assets/artwork/Fire.png"
const FIRE_FRAME_COUNT := 6
const FIRE_FRAME_TIME := 0.12
const CLOAKED_IDLE_PATH := "res://assets/artwork/TinyDemonCloacked-Idle.png"
const CLOAKED_IDLE_FRAME_COUNT := 5
const CLOAKED_IDLE_FRAME_TIME := 0.16
const PLAYER_FULLSHEET_PATH := "res://assets/artwork/TinyDemon_fullsheet.png"
const PLAYER_FRAME_SIZE := Vector2i(36, 36)
const PLAYER_IDLE_FRAME_TIME := 0.18

const SpriteFrameLibraryScript = preload("res://scripts/sprite_frame_library.gd")
const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const ActorPaletteMaterialScript = preload("res://scripts/actor_palette_material.gd")
const PLAYER_DEFAULT_ELEMENT := ElementCatalogScript.Element.WATER

@export_category("Hub Preview")
@export var animate_preview := true:
	set(value):
		animate_preview = value
		# Keep the editor follow-up pass active even when frame animation is
		# paused, so a dragged player still carries its shadow with it.
		set_process(true)

@export var show_collision_guides := false:
	set(value):
		show_collision_guides = value
		call_deferred("_configure_preview")

@export var show_hud := false:
	set(value):
		show_hud = value
		call_deferred("_configure_preview")

@export var refresh_preview := false:
	set(value):
		if value:
			call_deferred("_configure_preview")
		refresh_preview = false

@export_category("Player Presentation")
@export_enum("Neutral:0", "Fire:1", "Water:2", "Electric:3", "Grass:4", "Shadow:5", "Ground:6", "Ice:7") var player_element: int = PLAYER_DEFAULT_ELEMENT:
	set(value):
		player_element = clampi(value, 0, ElementCatalogScript.element_count() - 1)
		call_deferred("_configure_preview")

var _configured := false
var _animation_time := 0.0
var _fire_frames: Array[Texture2D] = []
var _cloaked_idle_frames: Array[Texture2D] = []
var _player_idle_frames: Array[Texture2D] = []


func _ready() -> void:
	call_deferred("_configure_preview")


func _process(delta: float) -> void:
	if not _configured:
		return
	if animate_preview:
		_animation_time += delta
	_apply_animation_frames()


func _configure_preview() -> void:
	var main := get_node_or_null(MAIN_SCENE_NODE) as Node2D
	if main == null:
		return

	main.visible = true
	_set_canvas_visible(main, ^"BackgroundCanvas", true)
	_set_canvas_visible(main, ^"Map", true)
	_set_canvas_visible(main, ^"Actors", true)
	_set_canvas_visible(main, ^"InterfaceCanvas", show_hud)

	# The Hub scene is the authored safe-room composition. The pooled dungeon
	# enemies and attack-only authoring guides are not part of the normal view.
	_set_node_visible(main, ^"Actors/SlimeBlue", false)
	_set_node_visible(main, ^"Actors/SlimeGreen", false)
	_set_node_visible(main, ^"Actors/SlimeRed", false)
	_set_node_visible(main, ^"Actors/PlayerPlacement/TinyDemonAttack", false)
	_set_node_visible(main, ^"Actors/PlayerPlacement/TinyDemon/Attack1HitboxShape", show_collision_guides)
	_set_node_visible(main, ^"Actors/PlayerPlacement/TinyDemon/Attack2HitboxShape", show_collision_guides)
	_set_node_visible(main, ^"Actors/PlayerPlacement/TinyDemon/SpinAttackHitboxShape", show_collision_guides)
	_set_node_visible(main, ^"Actors/PlayerPlacement/TinyDemon", true)
	_set_node_visible(main, ^"Actors/CloakedDemon", true)
	_set_node_visible(main, ^"Actors/RestFire", true)
	_set_node_visible(main, ^"Actors/Chest", true)
	_set_node_visible(main, ^"Actors/PlayerPlacement/TinyDemonShadow", true)
	_set_node_visible(main, ^"Actors/CloakedDemonShadow", true)

	_configure_guides(main)
	_configure_hub_accents(main)
	_build_animation_frames()
	_apply_animation_frames()
	_configured = true
	set_process(true)
	queue_redraw()


func _configure_hub_accents(main: Node2D) -> void:
	var accents := main.get_node_or_null(^"Map/HubStoneAccentLayer") as CanvasItem
	if accents == null:
		return
	accents.visible = true
	if accents.has_method("on_room_entered"):
		accents.call("on_room_entered", HUB_ROOM_ID, HUB_ROOM_TYPE)
	if accents.has_method("refresh_current_room"):
		accents.call("refresh_current_room", HUB_ROOM_ID, HUB_ROOM_TYPE)


func _configure_guides(main: Node) -> void:
	for node in main.find_children("*", "CanvasItem", true, false):
		var canvas_item := node as CanvasItem
		if canvas_item == null:
			continue
		var node_name := String(canvas_item.name)
		if node_name.contains("Guide") or node_name.contains("Hitbox") or node_name == "CollisionPolygon":
			canvas_item.visible = show_collision_guides


func _build_animation_frames() -> void:
	var library := SpriteFrameLibraryScript.new()
	_fire_frames = _slice_horizontal(library, FIRE_PATH, FIRE_FRAME_COUNT)
	_cloaked_idle_frames = _slice_horizontal(library, CLOAKED_IDLE_PATH, CLOAKED_IDLE_FRAME_COUNT)
	_player_idle_frames = library.slice_full_row_visible(PLAYER_FULLSHEET_PATH, 0, PLAYER_FRAME_SIZE)


func _slice_horizontal(library: RefCounted, path: String, frame_count: int) -> Array[Texture2D]:
	var texture := load(path) as Texture2D
	if texture == null or frame_count <= 0:
		return []
	var frame_size := Vector2i(maxi(1, texture.get_width() / frame_count), texture.get_height())
	return library.slice_frames(path, frame_size)


func _apply_animation_frames() -> void:
	var main := get_node_or_null(MAIN_SCENE_NODE) as Node2D
	if main == null:
		return
	var fire := main.get_node_or_null(^"Actors/RestFire") as Sprite2D
	if fire != null and not _fire_frames.is_empty():
		fire.texture = _fire_frames[_frame_for(_animation_time, FIRE_FRAME_TIME, _fire_frames.size())]
		fire.hframes = 1
		fire.frame = 0
	var cloaked_demon := main.get_node_or_null(^"Actors/CloakedDemon") as Sprite2D
	if cloaked_demon != null and not _cloaked_idle_frames.is_empty():
		cloaked_demon.texture = _cloaked_idle_frames[_frame_for(_animation_time, CLOAKED_IDLE_FRAME_TIME, _cloaked_idle_frames.size())]
		cloaked_demon.hframes = 1
		cloaked_demon.frame = 0
	var player := main.get_node_or_null(^"Actors/PlayerPlacement/TinyDemon") as Sprite2D
	if player != null and not _player_idle_frames.is_empty():
		player.texture = _player_idle_frames[_frame_for(_animation_time, PLAYER_IDLE_FRAME_TIME, _player_idle_frames.size())]
		# Match PlayerAnimationComponent's render offset. The node position is the
		# editable actor/foot anchor; the offset positions the 36px artwork around
		# that anchor instead of moving the authored actor itself.
		player.offset = Vector2(-10.0, -10.0)
		player.hframes = 1
		player.frame = 0
		var palette_name := ElementCatalogScript.palette_key(player_element)
		player.material = ActorPaletteMaterialScript.for_palette(palette_name)
		var player_attack := main.get_node_or_null(^"Actors/PlayerPlacement/TinyDemonAttack") as Sprite2D
		if player_attack != null:
			player_attack.material = ActorPaletteMaterialScript.for_palette(palette_name)
		_sync_player_shadow(main, player)


func _sync_player_shadow(main: Node2D, player: Sprite2D) -> void:
	if main == null or player == null:
		return
	var shadow := main.get_node_or_null(^"Actors/PlayerPlacement/TinyDemonShadow") as Sprite2D
	if shadow == null:
		return
	# This is the resolved runtime relationship: actor foot (+8,+15), then
	# player_shadow_offset (-8,-9), which places the shadow six pixels below the
	# authored player node anchor. Keep it local so editor dragging remains clear.
	shadow.position = player.position + Vector2(0.0, 6.0)
	shadow.flip_h = player.flip_h


func _frame_for(time_value: float, frame_time: float, frame_count: int) -> int:
	return posmod(floori(time_value / maxf(frame_time, 0.001)), maxi(frame_count, 1))


func _set_canvas_visible(main: Node, path: NodePath, is_visible: bool) -> void:
	_set_node_visible(main, path, is_visible)


func _set_node_visible(main: Node, path: NodePath, is_visible: bool) -> void:
	var node := main.get_node_or_null(path)
	if node is CanvasItem:
		(node as CanvasItem).visible = is_visible
	elif node is CanvasLayer:
		(node as CanvasLayer).visible = is_visible


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	# A subtle reference frame makes the 240x160 authored viewport discoverable
	# against Godot's dark 2D canvas without changing the game's actual artwork.
	draw_rect(Rect2(Vector2.ZERO, PREVIEW_VIEW_SIZE), Color(0.42, 0.48, 0.60, 0.55), false, 1.0)
