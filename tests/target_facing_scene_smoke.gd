extends SceneTree

const INTERACTION_SCRIPT = preload("res://scripts/interaction_component.gd")
const ACTOR_MOTOR_SCRIPT = preload("res://scripts/actor_motor.gd")


class FakeRoot extends Node:
	var player: Sprite2D = null
	var foot_offset := Vector2(8, 15)
	var last_player_facing_left := false


	func _actor_foot(actor: Sprite2D) -> Vector2:
		return ActorGeometry.foot(actor, foot_offset)


func _initialize() -> void:
	var failures: Array[String] = []
	var root_node := FakeRoot.new()
	root.add_child(root_node)
	root_node.player = Sprite2D.new()
	root_node.player.centered = false
	root_node.player.global_position = Vector2(100, 100)
	root_node.add_child(root_node.player)
	var target := Sprite2D.new()
	target.centered = false
	root_node.add_child(target)
	var interaction := INTERACTION_SCRIPT.new() as InteractionComponent
	root_node.player.flip_h = false
	_expect(interaction.target_is_in_front(root_node, Vector2(112, 115)), "right-facing player accepts a target in front", failures)
	_expect(not interaction.target_is_in_front(root_node, Vector2(88, 115)), "right-facing player rejects a target behind", failures)
	root_node.player.flip_h = true
	_expect(interaction.target_is_in_front(root_node, Vector2(88, 115)), "left-facing player accepts a target in front", failures)
	_expect(not interaction.target_is_in_front(root_node, Vector2(112, 115)), "left-facing player rejects a target behind", failures)

	# Facing is a horizontal state, not a fresh decision from every movement
	# vector. This protects straight vertical walking from controller drift.
	var motor := ACTOR_MOTOR_SCRIPT.new() as ActorMotor
	root_node.player.flip_h = false
	root_node.last_player_facing_left = false
	motor.update_horizontal_facing(root_node, Vector2.LEFT)
	_expect(root_node.player.flip_h and root_node.last_player_facing_left, "left input records left-facing state", failures)
	motor.update_horizontal_facing(root_node, Vector2(0.0, -1.0))
	_expect(root_node.player.flip_h and root_node.last_player_facing_left, "straight up preserves the last horizontal facing", failures)
	motor.update_horizontal_facing(root_node, Vector2(0.04, 1.0))
	_expect(root_node.player.flip_h and root_node.last_player_facing_left, "small horizontal controller noise does not flip vertical walking", failures)
	motor.update_horizontal_facing(root_node, Vector2.RIGHT)
	_expect(not root_node.player.flip_h and not root_node.last_player_facing_left, "right input updates the remembered facing", failures)
	motor.update_horizontal_facing(root_node, Vector2(0.0, 1.0))
	_expect(not root_node.player.flip_h and not root_node.last_player_facing_left, "straight down preserves the last horizontal facing", failures)
	motor.free()

	target.global_position = Vector2(96, 100)
	_expect(interaction.target_facing_left(root_node, target), "non-centered target on the left faces the player left", failures)
	target.global_position = Vector2(104, 100)
	_expect(not interaction.target_facing_left(root_node, target), "non-centered target on the right faces the player right", failures)

	# A centered target can sit inside the player's non-centered anchor width.
	# This is the close-range case that previously reported the wrong side.
	target.centered = true
	target.global_position = Vector2(104, 100)
	_expect(interaction.target_facing_left(root_node, target), "centered target just left of the visible player faces left", failures)
	target.global_position = Vector2(112, 100)
	_expect(not interaction.target_facing_left(root_node, target), "centered target just right of the visible player faces right", failures)

	interaction.free()
	root_node.queue_free()
	await process_frame
	_finish(failures)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("TARGET_FACING_SCENE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
