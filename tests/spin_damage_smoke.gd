extends SceneTree


class DamageRoot extends Node:
	var player: Sprite2D
	var player_tuning: PlayerTuning
	var player_attack_flip_h := false
	var player_anim_frame := 3
	var slimes: Array[Sprite2D] = []
	var puzzle_torches: Array[Sprite2D] = []
	var run_state: RunState = null
	var target_polygon := PackedVector2Array([
		Vector2(3, 3), Vector2(33, 3), Vector2(33, 33), Vector2(3, 33),
	])
	var damage_values: Array[float] = []
	var damage_targets: Array[Sprite2D] = []


	func _is_slime_targetable(_slime: Sprite2D) -> bool:
		return true


	func _slime_body_polygon(_slime: Sprite2D) -> PackedVector2Array:
		return target_polygon


	func _player_attack_damage_result_against(_slime: Sprite2D, _attack_element: int) -> CombatCalculator.DamageResult:
		var result := CombatCalculator.DamageResult.new()
		result.amount = 20.0
		result.critical = false
		result.element = 0
		result.effectiveness = 1.0
		result.immune = false
		return result


	func _player_attack_damage_share_divisor(_slime: Sprite2D, target_count: int) -> float:
		return maxf(float(target_count), 1.0)


	func _damage_slime(slime: Sprite2D, amount: float, _was_critical: bool = false, _attack_element: int = 0, _immune: bool = false) -> void:
		damage_targets.append(slime)
		damage_values.append(amount)


	func _knockback_slime(_slime: Sprite2D, _multiplier: float = 1.0) -> void:
		pass


func _initialize() -> void:
	var failures: Array[String] = []
	var root := DamageRoot.new()
	root.player_tuning = PlayerTuning.new()
	root.player = Sprite2D.new()
	root.add_child(root.player)
	_add_attack_guide(root.player, "Attack1HitboxShape")
	_add_attack_guide(root.player, "SpinAttackHitboxShape")
	var target_a := Sprite2D.new()
	var target_b := Sprite2D.new()
	root.add_child(target_a)
	root.add_child(target_b)
	get_root().add_child(root)
	var attack := PlayerAttackComponent.new()
	root.add_child(attack)

	root.slimes = [target_a]
	root.damage_values.clear()
	attack.begin(1, PlayerAttackComponent.AttackKind.ATTACK1)
	attack.apply_hitbox(root)
	var normal_single := root.damage_values[0] if root.damage_values.size() == 1 else 0.0
	_expect(root.damage_values.size() == 1 and is_equal_approx(normal_single, 20.0), "normal Attack 1 keeps its full single-target damage", failures)

	root.damage_values.clear()
	root.damage_targets.clear()
	attack.begin(1, PlayerAttackComponent.AttackKind.SPIN)
	attack.apply_hitbox(root)
	var spin_single := root.damage_values[0] if root.damage_values.size() == 1 else 0.0
	var expected_spin := floorf(20.0 * root.player_tuning.spin_damage_multiplier)
	_expect(root.damage_values.size() == 1 and is_equal_approx(spin_single, expected_spin), "single-target spin uses its reduced damage coefficient", failures)
	_expect(spin_single < normal_single, "single-target spin deals slightly less than a normal attack", failures)

	root.slimes = [target_a, target_b]
	root.damage_values.clear()
	root.damage_targets.clear()
	attack.begin(1, PlayerAttackComponent.AttackKind.ATTACK1)
	attack.apply_hitbox(root)
	var normal_multi := root.damage_values.duplicate()
	_expect(normal_multi.size() == 2 and is_equal_approx(normal_multi[0], 10.0) and is_equal_approx(normal_multi[1], 10.0), "normal multi-target attack uses the damage share", failures)

	root.damage_values.clear()
	root.damage_targets.clear()
	attack.begin(1, PlayerAttackComponent.AttackKind.SPIN)
	attack.apply_hitbox(root)
	_expect(root.damage_values.size() == 2, "spin resolves damage against both targets", failures)
	for amount in root.damage_values:
		_expect(is_equal_approx(amount, spin_single), "multi-target spin gives each enemy the full spin amount", failures)

	root.queue_free()
	await process_frame
	_finish(failures)


func _add_attack_guide(player: Sprite2D, guide_name: String) -> void:
	var guide := AttackHitboxGuide.new()
	guide.name = guide_name
	var hitbox := Polygon2D.new()
	hitbox.name = "Hitbox"
	hitbox.polygon = PackedVector2Array([
		Vector2(0, 0), Vector2(36, 0), Vector2(36, 36), Vector2(0, 36),
	])
	guide.add_child(hitbox)
	player.add_child(guide)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("SPIN_DAMAGE_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)
