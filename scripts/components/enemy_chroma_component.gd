extends Node

const ActorPaletteMaterialScript = preload("res://scripts/actors/actor_palette_material.gd")

const DEFAULT_ELEMENTAL_CHROMA := 20

var enabled := false
var palette_name := "green"
var maximum_chroma := DEFAULT_ELEMENTAL_CHROMA
var current_chroma := 0.0
var _damage_chroma_budget := 0.0
var _drops_emitted := 0
var _shared_palette_material: ShaderMaterial = null
var _actor_palette_material: ShaderMaterial = null


func configure(is_elemental: bool, palette: String) -> void:
	var palette_material_changed := enabled != is_elemental or palette_name != palette
	enabled = is_elemental
	palette_name = palette
	maximum_chroma = DEFAULT_ELEMENTAL_CHROMA
	reset_pool()
	if palette_material_changed:
		_sync_actor_material()


func reset_pool() -> void:
	_damage_chroma_budget = 0.0
	_drops_emitted = 0
	current_chroma = float(maximum_chroma) if enabled else 0.0
	_update_desaturation()


func on_health_damage(root: Object, damage: float, maximum_health: float, is_lethal: bool) -> void:
	if not enabled or damage <= 0.0 or maximum_health <= 0.0 or current_chroma <= 0.0:
		return
	_damage_chroma_budget = minf(
		float(maximum_chroma),
		_damage_chroma_budget + damage * float(maximum_chroma) / maximum_health
	)
	current_chroma = maxf(float(maximum_chroma) - _damage_chroma_budget, 0.0)
	var earned_drops := mini(floori(_damage_chroma_budget + 0.0001), maximum_chroma)
	if is_lethal:
		_damage_chroma_budget = float(maximum_chroma)
		current_chroma = 0.0
		earned_drops = maximum_chroma
	var new_drops := maxi(earned_drops - _drops_emitted, 0)
	_drops_emitted += new_drops
	_update_desaturation()
	_emit_chroma_drops(root, new_drops)


func runtime_state() -> Dictionary:
	return {
		"damage_budget": _damage_chroma_budget,
		"drops_emitted": _drops_emitted,
	}


func restore_runtime_state(state: Dictionary, current_health: float, maximum_health: float) -> void:
	if not enabled:
		return
	if state.has("damage_budget"):
		_damage_chroma_budget = clampf(float(state["damage_budget"]), 0.0, float(maximum_chroma))
		_drops_emitted = clampi(int(state.get("drops_emitted", floori(_damage_chroma_budget))), 0, maximum_chroma)
	else:
		var health_fraction := clampf(current_health / maximum_health, 0.0, 1.0) if maximum_health > 0.0 else 0.0
		_damage_chroma_budget = float(maximum_chroma) * (1.0 - health_fraction)
		_drops_emitted = clampi(floori(_damage_chroma_budget + 0.0001), 0, maximum_chroma)
	current_chroma = maxf(float(maximum_chroma) - _damage_chroma_budget, 0.0)
	_update_desaturation()


func palette_material_for(shared_material: ShaderMaterial) -> ShaderMaterial:
	if not enabled or shared_material == null:
		return shared_material
	if _shared_palette_material != shared_material or _actor_palette_material == null:
		_shared_palette_material = shared_material
		_actor_palette_material = shared_material.duplicate() as ShaderMaterial
	_update_desaturation()
	return _actor_palette_material


func _sync_actor_material() -> void:
	var actor := get_parent() as Sprite2D
	if actor == null:
		return
	_shared_palette_material = null
	_actor_palette_material = null
	var is_skeleton: bool = actor.get_meta("enemy_type_id", &"") == &"skeleton"
	var shared_material: ShaderMaterial = (
		ActorPaletteMaterialScript.for_skeleton_palette(palette_name)
		if is_skeleton
		else ActorPaletteMaterialScript.for_slime_palette(palette_name)
	)
	var material := palette_material_for(shared_material) if enabled else shared_material
	if not is_skeleton and palette_name == "green" and not enabled:
		material = null
	actor.material = material
	var shadow := actor.get_node_or_null("SlimeFloorShadow") as Sprite2D
	if shadow != null:
		shadow.material = material


func _update_desaturation() -> void:
	if _actor_palette_material == null:
		return
	var drained_fraction := 1.0 - current_chroma / float(maximum_chroma) if maximum_chroma > 0 else 1.0
	_actor_palette_material.set_shader_parameter("chroma_desaturation", clampf(drained_fraction, 0.0, 1.0))


func _emit_chroma_drops(root: Object, drop_count: int) -> void:
	if drop_count <= 0 or root == null or not root.has_method("_spawn_chroma_pickup"):
		return
	var actor := get_parent() as Sprite2D
	if actor == null or not is_instance_valid(actor):
		return
	var player := root.get("player") as Sprite2D
	var origin := actor.global_position
	if root.has_method("_actor_foot"):
		origin = root.call("_actor_foot", actor) as Vector2
	var direction := Vector2.UP
	if player != null and is_instance_valid(player):
		var player_position := player.global_position
		if root.has_method("_actor_foot"):
			player_position = root.call("_actor_foot", player) as Vector2
		var to_player := player_position - origin
		if to_player.length_squared() > 0.0001:
			direction = to_player.normalized()
	var tangent := Vector2(-direction.y, direction.x)
	var first_drop_index := _drops_emitted - drop_count
	for unit_index in drop_count:
		var fan_position := float(unit_index) - float(drop_count - 1) * 0.5
		var launch_direction := direction.rotated(fan_position * 0.03).normalized()
		var spawn_position := origin + direction * 1.5 + tangent * fan_position * 0.75
		var seed_value := int(actor.get_instance_id() ^ ((first_drop_index + unit_index + 1) * 0x45D9F3B))
		root.call("_spawn_chroma_pickup", spawn_position, 1, seed_value, launch_direction, null, unit_index == 0)
