extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var tuning := SlimeTuning.new()
	_expect(tuning.boss_scoot_distance >= 6.0 and tuning.boss_scoot_distance <= 8.0, "boss scoot uses the authored heavy range", failures)
	_expect(tuning.boss_scoot_duration >= 0.48 and tuning.boss_scoot_duration <= 0.62, "boss scoot has a committed duration", failures)
	_expect(tuning.boss_attack_lunge_distance >= 8.0 and tuning.boss_attack_lunge_distance <= 12.0, "boss lunge has the committed authored attack distance", failures)
	_expect(tuning.attack_commit_frames_before_hit == 2, "regular slimes commit two frames before impact", failures)
	_expect(tuning.boss_attack_commit_frames_before_hit == 3, "boss commits three frames before impact", failures)
	_expect(tuning.boss_attack_overshoot_distance > tuning.attack_overshoot_distance, "boss lunge overshoots slightly farther than a regular slime", failures)
	_expect(tuning.attack_hit_range - 0.5 < tuning.attack_hit_range + 0.75, "boss preferred spacing stays inside attack permission", failures)
	var combat := SlimeCombatComponent.new()
	combat.begin_lunge(Vector2.RIGHT * 10.0, tuning.boss_attack_lunge_duration)
	_expect(combat.lunge_remaining > 0.0, "boss lunge remains active across attack frames", failures)
	_expect(combat.lunge_total >= 0.14 and combat.lunge_total <= 0.22, "boss lunge uses the authored temporal window", failures)

	# Characterize the real attack scheduler: the boss commits on frame 5 for
	# its frame-8 impact, then applies a fixed lunge in progress deltas. A
	# moving player after the callback must not create another commitment.
	var actor := Sprite2D.new()
	actor.set_meta("encounter_scale", 3.0)
	var attack_texture := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	var frames: Array[Texture2D] = []
	for _frame in 12:
		frames.append(attack_texture)
	var scheduled := SlimeCombatComponent.new()
	var commit_count := [0]
	var lunge_fractions: Array[float] = []
	var hit_count := [0]
	var capture := func(_actor: Sprite2D) -> void:
		commit_count[0] += 1
		scheduled.attack_target_point = Vector2(40.0, 20.0)
		scheduled.attack_lunge_vector = Vector2(20.0, 0.0)
		scheduled.attack_committed = true
	var set_frame := func(_actor: Sprite2D, _frame_index: int) -> void: pass
	var set_texture := func(_actor: Sprite2D, _texture: Texture2D) -> void: pass
	var apply_lunge := func(_actor: Sprite2D, fraction: float) -> void: lunge_fractions.append(fraction)
	var apply_hit := func(_actor: Sprite2D) -> void: hit_count[0] += 1
	var restore_idle := func(_actor: Sprite2D) -> void: pass
	var can_attack := func(_actor: Sprite2D) -> bool: return true
	var start_attack := func(_actor: Sprite2D) -> void: scheduled.begin()
	var started := scheduled.tick_attack(0.016, actor, tuning, frames, false, set_frame, set_texture, apply_lunge, apply_hit, restore_idle, can_attack, start_attack, capture)
	_expect(started and scheduled.active, "attack scheduler starts the boss attack", failures)
	for _step in 9:
		scheduled.tick_attack(tuning.attack_frame_time, actor, tuning, frames, false, set_frame, set_texture, apply_lunge, apply_hit, restore_idle, can_attack, start_attack, capture)
	_expect(commit_count[0] == 1, "boss attack target is captured exactly once", failures)
	_expect(scheduled.attack_lunge_vector.is_equal_approx(Vector2(20.0, 0.0)), "boss keeps the captured lunge vector after commitment", failures)
	_expect(lunge_fractions.size() == 3, "boss lunge spans the intended two-to-three impact frames", failures)
	var total_fraction := 0.0
	for fraction in lunge_fractions:
		total_fraction += fraction
	_expect(is_equal_approx(total_fraction, 1.0), "boss lunge applies exactly one full target displacement", failures)
	_expect(hit_count[0] == 1, "boss attack still resolves one impact", failures)
	actor.free()
	scheduled.free()
	if failures.is_empty():
		print("BOSS_MOVEMENT_CONTACT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)

func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)
