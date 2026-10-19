extends RefCounted
class_name EnemyRoster

## Ordered, run-local enemy slots. The public members array is retained as a
## compatibility view for older systems while slot ownership migrates.

var members: Array[Sprite2D] = []
var _next_slot_index := 0


func replace_members(shared_members: Array[Sprite2D]) -> void:
	members = shared_members
	_next_slot_index = 0
	for index in members.size():
		_register_member(members[index], index)
		_next_slot_index = maxi(_next_slot_index, index + 1)


func append(actor: Sprite2D) -> bool:
	if actor == null or members.has(actor):
		return false
	members.append(actor)
	_register_member(actor, _next_slot_index)
	_next_slot_index += 1
	return true


func remove(actor: Sprite2D) -> bool:
	var index := members.find(actor)
	if index < 0:
		return false
	members.remove_at(index)
	return true


func replace(current_actor: Sprite2D, replacement: Sprite2D) -> int:
	var slot_index := members.find(current_actor)
	if slot_index < 0 or replacement == null:
		return -1
	if not current_actor is EnemyActor or not replacement is EnemyActor:
		push_error("EnemyRoster.replace requires EnemyActor instances.")
		return -1
	var current_enemy := current_actor as EnemyActor
	var replacement_enemy := replacement as EnemyActor
	if current_enemy.roster_slot_id.is_empty():
		_register_member(current_enemy, slot_index)
	replacement_enemy.roster_slot_id = current_enemy.roster_slot_id
	members[slot_index] = replacement
	replacement.add_to_group(&"enemies")
	current_actor.remove_from_group(&"enemies")
	return slot_index


func slot_index(actor: Sprite2D) -> int:
	return members.find(actor)


func _register_member(actor: Sprite2D, slot_index: int) -> void:
	if actor == null:
		return
	if actor is EnemyActor:
		var enemy := actor as EnemyActor
		if enemy.roster_slot_id.is_empty():
			enemy.roster_slot_id = StringName("enemy_slot_%04d" % slot_index)
		enemy.add_to_group(&"enemies")
