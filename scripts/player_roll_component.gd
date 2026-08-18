extends Node
class_name PlayerRollComponent

signal roll_started(direction: Vector2)
signal roll_finished

var active := false
var direction := Vector2.ZERO
var elapsed := 0.0
var frame := 0
var frame_timer := 0.0
var velocity := Vector2.ZERO


func start_from_root(root: Object) -> void:
	var anim := root.get("player_animation_component") as PlayerAnimationComponent
	var frames := anim.roll_frames as Array[Texture2D]
	if frames.is_empty(): return
	var run_state := root.get("run_state") as RunState
	if run_state != null:
		run_state.record_roll(bool(root.call("_is_run_combat_active")))
	var movement_direction: Vector2 = root.call("_movement_input")
	if movement_direction.length_squared() <= 0.0: movement_direction = root.call("_player_facing_vector")
	else: movement_direction = movement_direction.normalized()
	var player := root.get("player") as Sprite2D
	if movement_direction.x < 0.0: player.flip_h = true
	elif movement_direction.x > 0.0: player.flip_h = false
	root.set("player_is_rolling", true); begin(movement_direction)
	var motor := root.get("player_motor") as ActorMotor
	if motor != null: motor.begin_roll()
	root.set("roll_dust_spawned_this_roll", false); (root.get("player_attack_visual") as Sprite2D).visible = false
	var tuning := root.get("player_tuning") as PlayerTuning
	var roll_multiplier := tuning.roll_multiplier(int(root.get("player_spd")))
	start_motion(root.call("_perspective_movement", movement_direction * (tuning.roll_distance * roll_multiplier / tuning.roll_duration))); player.visible = true
	anim.apply_frame(root)


func update_from_root(root: Object, delta: float) -> void:
	if not bool(root.get("player_is_rolling")): return
	var anim := root.get("player_animation_component") as PlayerAnimationComponent
	var tuning := root.get("player_tuning") as PlayerTuning; var player := root.get("player") as Sprite2D; var before := player.global_position
	var roll_multiplier := tuning.roll_multiplier(int(root.get("player_spd")))
	var result := tick_motion(delta, tuning.roll_duration, tuning.roll_frame_time / roll_multiplier, (anim.roll_frames as Array[Texture2D]).size(), Callable(self, "move_swept").bind(root))
	if not bool(root.get("roll_dust_spawned_this_roll")):
		var movement_direction := player.global_position - before
		if movement_direction.length_squared() <= 0.0001: movement_direction = root.call("_perspective_movement", self.direction)
		root.call("_start_roll_dust", movement_direction.normalized()); root.set("roll_dust_spawned_this_roll", true)
	if bool(result["finished"]):
		root.set("player_is_rolling", false)
		var motor := root.get("player_motor") as ActorMotor
		if motor != null: motor.end_roll()
		root.set("player_anim_name", "idle")
	anim.apply_frame(root)


func move_swept(movement: Vector2, root: Object) -> bool:
	return (root.get("actor_collision_system") as ActorCollisionSystem).try_move_swept(root.get("player"), movement, 0.75, Callable(root, "_can_actor_stand_at_current_position"), Callable(root, "_collides_with_static"))


func begin(new_direction: Vector2) -> void:
	active = true
	direction = new_direction.normalized() if new_direction.length_squared() > 0.0 else Vector2.RIGHT
	elapsed = 0.0
	frame = 0
	frame_timer = 0.0
	velocity = Vector2.ZERO
	roll_started.emit(direction)


func start_motion(new_velocity: Vector2) -> void:
	velocity = new_velocity


func tick_motion(delta: float, duration: float, frame_time: float, frame_count: int, move_motion: Callable) -> Dictionary:
	if not active:
		return {"finished": true}
	var elapsed_at_frame := frame_timer + float(frame) * frame_time
	var step_time := minf(delta, maxf(duration - elapsed_at_frame, 0.0))
	if frame >= frame_count - 2:
		step_time *= 0.25
	move_motion.call(velocity * step_time)
	frame_timer += delta
	var current_frame_time := frame_time
	if frame == frame_count - 2:
		current_frame_time *= 3.0
	if frame_timer < current_frame_time:
		return {"finished": false}
	frame_timer = fmod(frame_timer, current_frame_time)
	frame += 1
	if frame < frame_count:
		return {"finished": false}
	active = false
	roll_finished.emit()
	return {"finished": true}


func advance(delta: float, duration: float) -> bool:
	if not active:
		return false
	elapsed += delta
	if elapsed >= duration:
		active = false
		roll_finished.emit()
	return active


func cancel() -> void:
	if active:
		active = false
		roll_finished.emit()
