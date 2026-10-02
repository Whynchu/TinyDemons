extends SceneTree

## Fire Cinder Cone aim contract.
##
## The cone is a lateral breath: it leaves the caster's left or right side and
## never angles at a target. A cast reaches it through two entry points:
##
##  - execute_current_aspect_ability with no candidate animation active, which
##    derives the aim from the closest target and calls begin_magic_animation;
##  - execute_current_aspect_ability during a magic hold, which is the ordinary
##    tap-and-release cast: the candidate animation already began aimed at the
##    closest enemy and the form is only chosen when the button comes up.
##
## The hold path is the one that used to keep the raw closest-enemy vector, so
## both are driven here through the real entry point rather than through the
## aiming helper.
##
## Every other form keeps its authored aim, so the control case pins that this
## rule is fire-cone-only and has not become a global "flatten all spell aim"
## change.

const MagicRuntime = preload("res://scripts/magic_runtime_controller.gd")
const SpellForms = preload("res://scripts/spell_form_catalog.gd")
const SpellFormDefinition = preload("res://scripts/spell_form_definition.gd")
const Elements = preload("res://scripts/element_catalog.gd")
const Chroma = preload("res://scripts/player_chroma_component.gd")
const ActorMotor = preload("res://scripts/actor_motor.gd")

const PLAYER_POSITION := Vector2(120.0, 80.0)
## Target offsets from the player, covering every aim shape the room can produce.
const TARGET_OFFSETS: Array[Vector2] = [
	Vector2(24.0, -12.0),
	Vector2(-24.0, -12.0),
	Vector2(24.0, 12.0),
	Vector2(-24.0, 12.0),
	Vector2(2.0, -24.0),
	Vector2(-2.0, -24.0),
	Vector2(24.0, 0.0),
	Vector2(-24.0, 0.0),
]


func _initialize() -> void:
	var failures: Array[String] = []
	var fire_form := SpellForms.form_for_element(Elements.Element.FIRE)
	_expect(SpellForms.delivery_of(fire_form) == SpellFormDefinition.Delivery.CONE, "Fire is authored as a cone delivery", failures)
	var water_form := SpellForms.form_for_element(Elements.Element.WATER)
	_expect(SpellForms.delivery_of(water_form) != SpellFormDefinition.Delivery.CONE, "a non-cone form exists for the control case", failures)

	for remembered_facing_left in [false, true]:
		for target_offset in TARGET_OFFSETS:
			_check_direct_path(fire_form, target_offset, remembered_facing_left, "direct Fire cone", failures)
			_check_hold_path(fire_form, target_offset, remembered_facing_left, "hold Fire cone", failures)
			_check_hold_path(water_form, target_offset, remembered_facing_left, "hold Water projectile", failures, true)
	_finish(failures)


## execute_current_aspect_ability with no candidate running: it resolves the
## closest target, derives the aim itself, and calls begin_magic_animation.
func _check_direct_path(form: Resource, target_offset: Vector2, remembered_facing_left: bool, label: String, failures: Array[String]) -> void:
	var controller := MagicRuntime.new()
	var chroma := _chroma_for(form)
	var context := _context(chroma, target_offset, remembered_facing_left)
	# The aim the runtime itself derives from the closest target, captured before
	# any cone rule runs, so the expectation cannot drift from the runtime's own
	# geometry.
	var target := _target_sprite(target_offset)
	var requested := (controller.magic_target_point(context, target) - controller.player_visual_center(context)).normalized()
	var accepted: bool = controller.execute_current_aspect_ability(context, Chroma.AbilityMode.ELEMENTAL)
	var resolved: Vector2 = controller.pending_magic_direction
	controller.free()
	_expect(accepted, "%s accepted the cast" % label, failures)
	_expect_cone_axis(resolved, requested, remembered_facing_left, label, failures)


## The ordinary tap-and-release cast. The candidate animation has already begun
## with the closest-enemy aim and no form; the release chooses the form, which is
## the moment the cone rule has to run.
func _check_hold_path(form: Resource, target_offset: Vector2, remembered_facing_left: bool, label: String, failures: Array[String], expect_unchanged := false) -> void:
	var controller := MagicRuntime.new()
	var chroma := _chroma_for(form)
	var context := _context(chroma, target_offset, remembered_facing_left)
	var target := _target_sprite(target_offset)
	var requested := (controller.magic_target_point(context, target) - controller.player_visual_center(context)).normalized()
	# Candidate state exactly as _begin_magic_candidate leaves it: an animation in
	# flight, aimed at the closest target, with no form chosen yet. The frame is
	# held before the cast frame so the test observes aim resolution without also
	# requiring the full delivery presentation to be wired.
	controller.magic_animation_active = true
	controller.magic_hold_active = true
	controller.magic_animation_frame = MagicRuntime.MAGIC_CAST_FRAME_INDEX - 1
	controller.magic_cast_decided = false
	controller.pending_magic_form = null
	controller.pending_magic_direction = requested
	var candidate_aim: Vector2 = controller.pending_magic_direction
	var accepted: bool = controller.execute_current_aspect_ability(context, Chroma.AbilityMode.ELEMENTAL)
	var resolved: Vector2 = controller.pending_magic_direction
	controller.free()
	_expect(accepted, "%s accepted the release cast" % label, failures)
	if expect_unchanged:
		_expect(resolved.is_equal_approx(candidate_aim), "%s keeps its authored aim for a %s aim" % [label, requested], failures)
		return
	_expect_cone_axis(resolved, requested, remembered_facing_left, label, failures)


func _expect_cone_axis(resolved: Vector2, requested: Vector2, remembered_facing_left: bool, label: String, failures: Array[String]) -> void:
	var axis_name := "right" if resolved == Vector2.RIGHT else "left"
	_expect(resolved == Vector2.LEFT or resolved == Vector2.RIGHT, "%s resolves to a horizontal axis for a %s aim but got %s" % [label, requested, resolved], failures)
	# An aim that is essentially straight up or down carries no horizontal
	# intent, so the cone follows the player's remembered facing instead of
	# inventing one. This mirrors the runtime's own deadzone rule.
	var expected_left := remembered_facing_left
	if absf(requested.x) > ActorMotor.HORIZONTAL_FACING_DEADZONE:
		expected_left = requested.x < 0.0
	var expected_axis := Vector2.LEFT if expected_left else Vector2.RIGHT
	_expect(resolved == expected_axis, "%s aims %s for a %s aim with facing_left=%s" % [label, axis_name, requested, remembered_facing_left], failures)
	_expect(resolved.y == 0.0, "%s has no vertical component for a %s aim" % [label, requested], failures)


func _chroma_for(form: Resource) -> Node:
	# A real chroma component: the cast path reads current/bound aspect off it to
	# decide which form is cast, so the form under test must be what it selects.
	var chroma := PlayerChromaComponent.new()
	chroma.bound_aspect = form.native_element as PlayerChromaComponent.Aspect
	chroma.current_aspect = chroma.bound_aspect
	return chroma


func _player_sprite() -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.global_position = PLAYER_POSITION
	return sprite


func _target_sprite(target_offset: Vector2) -> Sprite2D:
	var target := Sprite2D.new()
	target.global_position = PLAYER_POSITION + target_offset
	return target


func _context(chroma: Node, target_offset: Vector2, remembered_facing_left: bool) -> MagicRuntimeContext:
	var context := MagicRuntimeContext.new()
	context.player_chroma_component = chroma
	context.player = _player_sprite()
	context.last_player_facing_left_get = func() -> bool: return remembered_facing_left
	context.last_player_input_direction_get = func() -> Vector2: return Vector2.ZERO
	context.player_magic_flip_h_set = func(_left: bool) -> void: pass
	context.valid_current_target = func() -> Sprite2D: return null
	var target := _target_sprite(target_offset)
	context.closest_target = func() -> Sprite2D: return target
	context.is_slime_targetable = func(_candidate: Sprite2D) -> bool: return true
	context.slime_body_polygon = func(_candidate: Sprite2D) -> PackedVector2Array: return PackedVector2Array()
	context.collision_rect = func(_candidate: Sprite2D) -> Rect2: return Rect2(PLAYER_POSITION + target_offset, Vector2(9.0, 4.0))
	context.play_sound = func(_name: String, _volume: float, _pitch: float) -> void: pass
	# begin_magic_animation drives the cast pose before it resolves the aim.
	context.player_is_magic_casting_set = func(_casting: bool) -> void: pass
	context.player_anim_name_set = func(_name: StringName) -> void: pass
	context.player_anim_frame_set = func(_frame: int) -> void: pass
	context.player_anim_timer_set = func(_timer: float) -> void: pass
	return context


func _expect(condition: bool, message: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(message)


func _finish(failures: Array[String]) -> void:
	if failures.is_empty():
		print("CONE_AIM_CONTRACT_SMOKE_OK")
		quit(0)
		return
	for failure in failures:
		push_error("FAILED: %s" % failure)
	quit(1)