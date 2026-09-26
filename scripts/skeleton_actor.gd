@tool
extends SlimeActor
class_name SkeletonActor

const SpriteFrameLibraryScript = preload("res://scripts/sprite_frame_library.gd")
const FRAME_SIZE := Vector2i(36, 36)
const FRAME_OFFSET := Vector2(-10.0, -10.0)
const IDLE_PATH := "res://assets/artwork/TinyDemon-Skeleton-Idle.png"
const WALK_PATH := "res://assets/artwork/TinyDemon-Skeleton-Walk.png"
const ATTACK_PATH := "res://assets/artwork/TinyDemon-Skeleton-attack.png"
const BETWEEN_ATTACK_PATH := "res://assets/artwork/TinyDemon-Skeleton-between_attack.png"
const SHOCKED_PATH := "res://assets/artwork/TinyDemon-Skeleton-Shocked_Right.png"
const SPAWN_PATH := "res://assets/artwork/TinyDemon-Skeleton-Spawn_Right.png"
const BETWEEN_ATTACK_RECOVERY_FRAMES := 3
const BONE_THROW_ATTACK_FRAME_INDEX := 2
const ATTACK_SECOND_FRAME_HOLD_TICKS := 5
static var _authored_frames_ready := false
static var _cached_idle_frames: Array[Texture2D] = []
static var _cached_walk_frames: Array[Texture2D] = []
static var _cached_attack_frames: Array[Texture2D] = []
static var _cached_shocked_frames: Array[Texture2D] = []
static var _cached_spawn_frames: Array[Texture2D] = []
static var _cached_idle_left_frames: Array[Texture2D] = []
static var _cached_walk_left_frames: Array[Texture2D] = []
static var _cached_attack_left_frames: Array[Texture2D] = []
static var _cached_shocked_left_frames: Array[Texture2D] = []
static var _cached_spawn_left_frames: Array[Texture2D] = []
static var _cached_between_attack_frame: Texture2D = null
static var _cached_between_attack_left_frame: Texture2D = null

var idle_frames: Array[Texture2D] = []
var idle_left_frames: Array[Texture2D] = []
var walk_frames: Array[Texture2D] = []
var walk_left_frames: Array[Texture2D] = []
var attack_frames: Array[Texture2D] = []
var attack_left_frames: Array[Texture2D] = []
var between_attack_frame: Texture2D = null
var between_attack_left_frame: Texture2D = null
var shocked_frames: Array[Texture2D] = []
var shocked_left_frames: Array[Texture2D] = []
var spawn_frames: Array[Texture2D] = []
var spawn_left_frames: Array[Texture2D] = []
var animation_timer := 0.0
var animation_frame := 0
var animation_name := "idle"
var animation_facing_left := false


func apply_authored_visuals() -> void:
	warm_authored_frames()
	idle_frames = _cached_idle_frames.duplicate()
	if texture == null and not idle_frames.is_empty():
		texture = idle_frames[0]
	walk_frames = _cached_walk_frames.duplicate()
	attack_frames = _cached_attack_frames.duplicate()
	shocked_frames = _cached_shocked_frames.duplicate()
	spawn_frames = _cached_spawn_frames.duplicate()
	idle_left_frames = _cached_idle_left_frames.duplicate()
	walk_left_frames = _cached_walk_left_frames.duplicate()
	attack_left_frames = _cached_attack_left_frames.duplicate()
	shocked_left_frames = _cached_shocked_left_frames.duplicate()
	spawn_left_frames = _cached_spawn_left_frames.duplicate()
	between_attack_frame = _cached_between_attack_frame
	between_attack_left_frame = _cached_between_attack_left_frame
	var visual := get_node_or_null("Visual") as SlimeVisualComponent
	if visual == null:
		return
	visual.right_texture = idle_frames[0] if not idle_frames.is_empty() else null
	visual.left_texture = idle_left_frames[0] if not idle_left_frames.is_empty() else null
	visual.attack_right_frames = attack_sequence_frames(false)
	visual.attack_left_frames = attack_sequence_frames(true)
	set_meta("art_note", "Skeleton uses authored idle, walk, attack, between-attack, shocked, and spawn sheets.")


static func warm_authored_frames() -> void:
	if _authored_frames_ready:
		return
	var library := SpriteFrameLibraryScript.new() as SpriteFrameLibrary
	_cached_idle_frames = library.slice_frames(IDLE_PATH, FRAME_SIZE)
	_cached_walk_frames = library.slice_frames(WALK_PATH, FRAME_SIZE)
	_cached_attack_frames = library.slice_frames(ATTACK_PATH, FRAME_SIZE)
	_cached_shocked_frames = library.slice_frames(SHOCKED_PATH, FRAME_SIZE)
	_cached_spawn_frames = library.slice_frames(SPAWN_PATH, FRAME_SIZE)
	var between_frames := library.slice_frames(BETWEEN_ATTACK_PATH, FRAME_SIZE)
	_cached_between_attack_frame = between_frames[0] if not between_frames.is_empty() else null
	_cached_idle_left_frames = library.flip_frames(_cached_idle_frames)
	_cached_walk_left_frames = library.flip_frames(_cached_walk_frames)
	_cached_attack_left_frames = library.flip_frames(_cached_attack_frames)
	_cached_shocked_left_frames = library.flip_frames(_cached_shocked_frames)
	_cached_spawn_left_frames = library.flip_frames(_cached_spawn_frames)
	_cached_between_attack_left_frame = library.flip_frames(between_frames)[0] if not between_frames.is_empty() else null
	_authored_frames_ready = true


func attack_sequence_frames(facing_left: bool) -> Array[Texture2D]:
	var authored_attack: Array[Texture2D] = attack_left_frames if facing_left else attack_frames
	var sequence: Array[Texture2D] = []
	for frame_index in authored_attack.size():
		var attack_frame := authored_attack[frame_index]
		sequence.append(attack_frame)
		if frame_index == 1:
			for _tick in range(ATTACK_SECOND_FRAME_HOLD_TICKS - 1):
				sequence.append(attack_frame)
	var recovery := between_attack_left_frame if facing_left else between_attack_frame
	if recovery != null:
		for _frame_index in BETWEEN_ATTACK_RECOVERY_FRAMES:
			sequence.append(recovery)
	return sequence


func bone_throw_sequence_frame_index() -> int:
	# The 2nd authored frame is repeated to create a readable wind-up. The throw
	# still lands on the 3rd authored frame, after those extra display ticks.
	return BONE_THROW_ATTACK_FRAME_INDEX + ATTACK_SECOND_FRAME_HOLD_TICKS - 1


func animation_frame_for_state(delta: float, walking: bool, facing_left: bool) -> Texture2D:
	var state := "walk" if walking else "idle"
	var frames := walk_left_frames if walking and facing_left else walk_frames if walking else idle_left_frames if facing_left else idle_frames
	if frames.is_empty():
		return null
	if animation_name != state or animation_facing_left != facing_left:
		animation_name = state
		animation_facing_left = facing_left
		animation_frame = 0
		animation_timer = 0.0
		return frames[0]
	animation_timer += delta
	var frame_duration := 0.14 if walking else 0.22
	if animation_timer < frame_duration:
		return null
	animation_timer = fmod(animation_timer, frame_duration)
	animation_frame = (animation_frame + 1) % frames.size()
	return frames[animation_frame]
