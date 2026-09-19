extends Node
class_name RoomController

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/aspect_catalog.gd")
const SLIME_VARIANT_CATALOG_SCRIPT = preload("res://scripts/slime_variant_catalog.gd")
const ROOM_TRANSITION_RESULT_SCRIPT = preload("res://scripts/room_transition_result.gd")
const ROOM_ACTIVATION_RESULT_SCRIPT = preload("res://scripts/room_activation_result.gd")
const ROOM_SPAWN_RESULT_SCRIPT = preload("res://scripts/room_spawn_result.gd")
const ROOM_CHECKPOINT_CONTEXT_SCRIPT = preload("res://scripts/room_checkpoint_context.gd")
const ROOM_CHECKPOINT_RESULT_SCRIPT = preload("res://scripts/room_checkpoint_result.gd")
const ROOM_CLEAR_CONTEXT_SCRIPT = preload("res://scripts/room_clear_context.gd")
const ROOM_CLEAR_RESULT_SCRIPT = preload("res://scripts/room_clear_result.gd")
const ROOM_ENTRY_CONTEXT_SCRIPT = preload("res://scripts/room_entry_context.gd")
const ROOM_ENTRY_SERVICES_SCRIPT = preload("res://scripts/room_entry_services.gd")
const ROOM_ENTRY_RESULT_SCRIPT = preload("res://scripts/room_entry_result.gd")
const ROOM_ENEMY_PLACEMENT_SCRIPT = preload("res://scripts/room_enemy_placement.gd")
const ROOM_ENEMY_RUNTIME_RESULT_SCRIPT = preload("res://scripts/room_enemy_runtime_result.gd")
const ROOM_ACTIVATION_CONTEXT_SCRIPT = preload("res://scripts/room_activation_context.gd")
const ROOM_GEOMETRY_CONTROLLER_SCRIPT = preload("res://scripts/room_geometry_controller.gd")

signal room_entered(room_id: StringName, room_type: StringName)
signal room_cleared(result: RoomClearResult)

var current_room_id: StringName = &""
var arrival_socket_id: StringName = &""
var transition_locked := false
var room_states: Dictionary = {}
var progression_run_rank := 1
var player_level := 1
var preferred_enemy_variant := "grey"
var secondary_enemy_variant := "grey"
var boss_variant_selection: StringName = &""
var matchup_policy := "rank_default"
var encounter_definition: EncounterDefinition = null
var room_definition: RoomDefinition = null
var boss_slime_authoring_scene: PackedScene = null
var boss_slime_authoring_template: Node = null
var boss_jump_phase_waves: Dictionary = {}
var boss_jump_phase_pool: Array[Sprite2D] = []
var _enemy_visual_preparation_signature := ""
var last_spawn_result: RoomSpawnResult = null
var enemy_spawn_services: RoomEnemySpawnServices = null
var geometry_controller: RefCounted = null
var current_room_type: StringName = &""

const ACTOR_FOOT_OFFSET := Vector2(8, 15)
const BOSS_SLIME_AUTHORING_SCENE := "res://scenes/boss_slime_authoring.tscn"
const ENEMY_MIN_PLAYER_DISTANCE := 20.0
const ENEMY_MIN_SPAWN_DISTANCE := 18.0
const ENEMY_MIN_SOCKET_DISTANCE := 16.0
const SPECIAL_ROOM_RESPAWN_DELAY := 45.0
const POPCORN_RESPAWN_MIN_DELAY := 30.0
const POPCORN_RESPAWN_MAX_DELAY := 45.0
const POPCORN_RESPAWN_RETRY_DELAY := 0.25
const GREY_ENEMY_WEIGHT: float = 1.0
const YELLOW_ENEMY_WEIGHT: float = 1.0
const YELLOW_MIN_RANK := 5
const GROUND_ENEMY_WEIGHT: float = 1.0
const GROUND_MIN_RANK := 5
const ICE_ENEMY_WEIGHT: float = 1.0
const ICE_MIN_RANK := 5
const SHADOW_ENEMY_WEIGHT: float = 0.12
## Crimson is a tanky Fire slime (content-driven via EnemyDefinition). It enters
## the rotation at the same run rank as the other late elemental families, with
## a modest weight so it adds variety without becoming the default.
const CRIMSON_ENEMY_WEIGHT: float = 0.6
const CRIMSON_MIN_RANK := 5
const SHADOW_BOUND_NORMAL_WEIGHT: float = 0.20
const SHADOW_BOUND_VARIANT_WEIGHT: float = 0.80
const SHADOW_BOSS_CHANCE: float = 0.04
const ROOM_POPCORN := "ROOM_POPCORN"
const ELITE_POPCORN := "ELITE_POPCORN"
const ELITE_ENCOUNTER_LEVEL_BONUS := 2
const SLIME_BOSS_JUMP_PHASE_POPCORN := "SlimeBossJumpPhasePopcorn"
const PLAYER_DOOR_REPOSITION_RADII := [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 16.0, 20.0, 24.0, 32.0, 40.0, 48.0]
const PLAYER_DOOR_REPOSITION_DIRECTIONS := 16


func _exit_tree() -> void:
	# These authoring scenes stay unparented so their nodes never participate in
	# gameplay. Release them with the controller instead of leaving a cached
	# duplicate of the main scene alive across a scene reload.
	if boss_slime_authoring_template != null and is_instance_valid(boss_slime_authoring_template):
		boss_slime_authoring_template.free()
	if geometry_controller != null:
		geometry_controller.dispose()


func configure_geometry(
	new_map_root: Node2D,
	new_floor_tiles: Node2D,
	new_player: Sprite2D,
	new_display_controller: DisplayController,
	new_scene_file_path: String
) -> void:
	geometry_controller = ROOM_GEOMETRY_CONTROLLER_SCRIPT.new()
	geometry_controller.configure(
		new_map_root,
		new_floor_tiles,
		new_player,
		new_display_controller,
		new_scene_file_path)


func prewarm_transition_assets(stone_layer: HubStoneAccentLayer = null) -> void:
	# Called while the boot loading screen is already visible. The first boss
	# entry then reuses the parsed/instantiated authoring data instead of paying
	# that cost during a visible room transition.
	_get_boss_slime_authoring_template()
	if geometry_controller == null:
		return
	geometry_controller.prewarm_transition_assets(stone_layer, current_room_type)


func ensure_layout(graph: DungeonGraph, room_id: StringName, room: DungeonGraph.RoomRecord, room_type: StringName, room_depth: int) -> Dictionary:
	var state := room_states.get(room_id, {}) as Dictionary
	# Generated route policy is carried with the room state so active-run
	# snapshots retain the exact encounter/reward contract. Missing keys are safe
	# defaults for authored rooms and older snapshots.
	state["route_role"] = room.route_role
	state["encounter_tier"] = room.encounter_tier
	state["reward_tier"] = room.reward_tier
	state["vault_id"] = room.vault_id
	if not state.has("generated_exits"):
		var exits: Array[StringName] = []
		if room.authored:
			for exit_socket in room.outgoing_connections.keys():
				exits.append(StringName(exit_socket))
		elif room.milestone_dead_end:
			pass
		elif room_type == DungeonGraph.ROOM_REST or room_type == DungeonGraph.ROOM_TRADER:
			pass
		elif room_type == DungeonGraph.ROOM_NPC:
			var npc_exit := DungeonGraph.WALL_LEFT if room.generation_seed % 2 == 0 else DungeonGraph.WALL_RIGHT
			exits.append(npc_exit)
			var next_room_type := DungeonGraph.ROOM_DOWNSTAIRS if room_depth >= graph.final_npc_depth() else DungeonGraph.ROOM_COMBAT
			graph.ensure_connection(room_id, npc_exit, next_room_type)
		elif room_depth == 0:
			exits.assign([DungeonGraph.WALL_LEFT, DungeonGraph.WALL_RIGHT])
			for exit_socket in exits: graph.ensure_connection(room_id, exit_socket, DungeonGraph.ROOM_COMBAT)
		elif room_type == DungeonGraph.ROOM_DOWNSTAIRS:
			pass
		elif room_type == DungeonGraph.ROOM_PUZZLE:
			var puzzle_exit := DungeonGraph.WALL_RIGHT if room.generation_seed % 2 == 0 else DungeonGraph.WALL_LEFT
			exits.append(puzzle_exit)
			graph.ensure_connection(room_id, puzzle_exit, DungeonGraph.ROOM_COMBAT)
		else:
			var layout_rng := RandomNumberGenerator.new(); layout_rng.seed = room.generation_seed; var primary := DungeonGraph.WALL_LEFT if layout_rng.randi_range(0, 1) == 0 else DungeonGraph.WALL_RIGHT; exits.append(primary); graph.ensure_connection(room_id, primary, DungeonGraph.ROOM_COMBAT)
			if room_depth + 1 != 6 and room_depth + 1 != graph.final_npc_depth() and layout_rng.randf() < graph.side_route_chance():
				var secondary := DungeonGraph.WALL_RIGHT if primary == DungeonGraph.WALL_LEFT else DungeonGraph.WALL_LEFT; var secondary_type := DungeonGraph.ROOM_REST if layout_rng.randf() < graph.side_dead_end_chance() else DungeonGraph.ROOM_COMBAT; exits.append(secondary); graph.ensure_connection(room_id, secondary, secondary_type)
		state["generated_exits"] = exits; state["room_type"] = room_type; state["finished"] = bool(state.get("finished", false)); room_states[room_id] = state
	if room_type == DungeonGraph.ROOM_COMBAT or room_type == DungeonGraph.ROOM_SPECIAL_ENEMY or room_type == DungeonGraph.ROOM_TREASURE:
		if not state.has("enemy_variants"):
			# Special rooms retain their authored color/puzzle behavior. R6+ elite
			# difficulty is expressed explicitly by the generated encounter tier,
			# rather than inferred from room depth.
			var is_special_room := room_type == DungeonGraph.ROOM_SPECIAL_ENEMY
			var extra_room_enemy := room_type == DungeonGraph.ROOM_SPECIAL_ENEMY or room_type == DungeonGraph.ROOM_TREASURE
			var encounter := _generate_enemy_encounter(room.generation_seed, room_depth, extra_room_enemy, not is_special_room, room.encounter_tier)
			state["enemy_variants"] = encounter["variants"]
			state["enemy_levels"] = encounter["levels"]
			state["enemy_popcorn"] = encounter["popcorn"]
			state["enemy_popcorn_types"] = encounter["popcorn_types"]
			state["enemy_ambush"] = encounter["ambush"]
			state["enemy_elite"] = encounter["elite"]
		if not state.has("enemy_elite"):
			var elite_flags: Array[bool] = []
			var popcorn_flags := state.get("enemy_popcorn", []) as Array
			for slot in (state.get("enemy_variants", []) as Array).size():
				elite_flags.append(room.encounter_tier == DungeonGraph.ENCOUNTER_ELITE and not (slot < popcorn_flags.size() and bool(popcorn_flags[slot])))
			state["enemy_elite"] = elite_flags
		if not state.has("regular_room_treasure"):
			var treasure_rng := RandomNumberGenerator.new()
			treasure_rng.seed = room.generation_seed ^ 0x54524541
			state["regular_room_treasure"] = room_type == DungeonGraph.ROOM_COMBAT and progression_run_rank >= 1 and (room.reward_tier == DungeonGraph.REWARD_RISK or treasure_rng.randf() < _room_definition().regular_room_treasure_chance)
		if not state.has("enemy_spawn_seed"):
			state["enemy_spawn_seed"] = room.generation_seed + 303
		room_states[room_id] = state
	elif room_type == DungeonGraph.ROOM_DOWNSTAIRS:
		if not state.has("enemy_variants"):
			var boss_encounter := _generate_boss_encounter(room.generation_seed, room_depth)
			state["enemy_variants"] = boss_encounter["variants"]
			state["enemy_levels"] = boss_encounter["levels"]
			state["enemy_scales"] = boss_encounter["scales"]
			state["enemy_popcorn"] = boss_encounter["popcorn"]
			state["enemy_popcorn_types"] = boss_encounter["popcorn_types"]
			state["enemy_ambush"] = boss_encounter["ambush"]
		if not state.has("enemy_spawn_seed"):
			state["enemy_spawn_seed"] = room.generation_seed + 909
		room_states[room_id] = state
	elif room_type == DungeonGraph.ROOM_PUZZLE or room_type == DungeonGraph.ROOM_ORB:
		room_states[room_id] = state
	return state


func _generate_enemy_encounter(generation_seed: int, room_depth: int, special_room: bool = false, allow_shadow: bool = true, encounter_tier: StringName = DungeonGraph.ENCOUNTER_NORMAL) -> Dictionary:
	var encounter_rng := RandomNumberGenerator.new()
	encounter_rng.seed = generation_seed + 101
	var count := 1
	# Flat difficulty: encounter count keys off run rank via the iteration
	# thresholds below, not room depth. Base count is still the simple 1->2 roll.
	var count_cap := _normal_enemy_cap()
	count = mini(count, count_cap)
	# Every rank can technically roll all the way to seven enemies. Each extra
	# slot is an independent weighted roll, with a heavier crowd tail later.
	while count < count_cap and encounter_rng.randf() < _additional_enemy_chance(count):
		count += 1
	var variants: Array[String] = []
	var levels: Array[int] = []
	var definition := _encounter_definition()
	var variant_pool: Array[Dictionary] = [
		{"variant": "grey", "weight": definition.shadow_bound_normal_weight if definition.is_shadow_bound() else definition.grey_weight},
	]
	if definition.is_shadow_bound() and allow_shadow:
		variant_pool.append({"variant": "purple", "weight": definition.shadow_bound_variant_weight})
	# R1 is neutral-only. R2 teaches player advantage. R3 reverses that lesson.
	# Authored R4 rooms may provide two explicit target families.
	var primary_variant: String = preferred_enemy_variant if preferred_enemy_variant in ["blue", "green", "red", "yellow", "green"] else "grey"
	var secondary_variant: String = secondary_enemy_variant if secondary_enemy_variant in ["blue", "green", "red", "yellow"] else "grey"
	if definition.matchup_policy == EncounterDefinition.POLICY_BASE_ADVANTAGE or (definition.matchup_policy == EncounterDefinition.POLICY_RANK_DEFAULT and progression_run_rank == 2):
		if primary_variant != "grey":
			variant_pool.append({"variant": primary_variant, "weight": 0.75})
	elif definition.matchup_policy == EncounterDefinition.POLICY_BASE_COUNTER:
		if primary_variant != "grey":
			variant_pool.append({"variant": primary_variant, "weight": 0.75})
	elif definition.matchup_policy == EncounterDefinition.POLICY_FLAME_MIXED:
		for family_variant in [primary_variant, secondary_variant]:
			if family_variant != "grey" and not _variant_pool_has(variant_pool, family_variant):
				variant_pool.append({"variant": family_variant, "weight": 0.75})
	elif definition.matchup_policy == EncounterDefinition.POLICY_RANK_DEFAULT and progression_run_rank >= 3:
		if primary_variant != "grey":
			variant_pool.append({"variant": primary_variant, "weight": 0.75})
		for elemental_variant in ["blue", "green", "red"]:
			if elemental_variant != primary_variant:
				variant_pool.append({"variant": elemental_variant, "weight": 0.35})
	if special_room:
		count = mini(maxi(count + 1, 2), count_cap)
	if encounter_tier == DungeonGraph.ENCOUNTER_DANGEROUS:
		count = mini(count + 1, count_cap)
	elif encounter_tier == DungeonGraph.ENCOUNTER_ELITE:
		count = mini(count + 2, count_cap)
	if progression_run_rank >= YELLOW_MIN_RANK:
		variant_pool.append({"variant": "yellow", "weight": YELLOW_ENEMY_WEIGHT})
	if progression_run_rank >= GROUND_MIN_RANK:
		variant_pool.append({"variant": "orange", "weight": GROUND_ENEMY_WEIGHT})
	if progression_run_rank >= ICE_MIN_RANK:
		variant_pool.append({"variant": "aquamarine", "weight": ICE_ENEMY_WEIGHT})
	if progression_run_rank >= CRIMSON_MIN_RANK:
		variant_pool.append({"variant": "crimson", "weight": CRIMSON_ENEMY_WEIGHT})
	if allow_shadow and progression_run_rank >= GROUND_MIN_RANK and not definition.is_shadow_bound():
		# Purple is a rare pressure spike, not a normal member of the enemy
		# rotation. A small weight keeps it available without making most later
		# rooms contain one.
		variant_pool.append({"variant": "purple", "weight": definition.shadow_weight})
	# Popcorn is deliberately tied to the player's durable level instead of the
	# dungeon run curve. It is recovery fodder, so it should remain five levels
	# below the player even when a high-level player revisits an early run.
	var base_level := _generated_enemy_base_level(room_depth) + (1 if special_room else 0)
	if encounter_tier == DungeonGraph.ENCOUNTER_DANGEROUS:
		base_level += 1
	elif encounter_tier == DungeonGraph.ENCOUNTER_ELITE:
		base_level += 2
	var level_spread := 1 if progression_run_rank <= 3 else 2
	var popcorn_flags: Array[bool] = []
	var popcorn_types: Array[String] = []
	var ambush_flags: Array[bool] = []
	var elite_flags: Array[bool] = []
	for enemy_index in count:
		var total_weight := 0.0
		for entry in variant_pool:
			total_weight += float(entry["weight"])
		var roll := encounter_rng.randf_range(0.0, total_weight)
		var selected: String = "grey"
		for entry in variant_pool:
			roll -= float(entry["weight"])
			if roll <= 0.0:
				selected = entry["variant"] as String
				break
		variants.append(selected)
		ambush_flags.append(selected == "purple" and encounter_rng.randf() < 0.40)
		# A Shadow Slime is never itself a popcorn roll. That keeps the shadow
		# pressure spike intact while guaranteeing every actual popcorn slot in a
		# shadow encounter is a Normal Slime.
		var is_popcorn := selected != "purple" and encounter_rng.randf() < _popcorn_enemy_chance()
		popcorn_flags.append(is_popcorn)
		popcorn_types.append(ROOM_POPCORN if is_popcorn else "")
		elite_flags.append(encounter_tier == DungeonGraph.ENCOUNTER_ELITE and not is_popcorn)
		var level_floor := base_level - level_spread
		if encounter_tier == DungeonGraph.ENCOUNTER_ELITE:
			# Elite levels stay above the full normal encounter band, so the
			# overhead marker communicates a real stat-pool increase.
			level_floor = base_level + 1
		var enemy_level := _popcorn_enemy_level() if is_popcorn else encounter_rng.randi_range(level_floor, base_level + level_spread)
		var level_cap := _enemy_level_cap() + ELITE_ENCOUNTER_LEVEL_BONUS if encounter_tier == DungeonGraph.ENCOUNTER_ELITE and not is_popcorn else _enemy_level_cap()
		levels.append(enemy_level if is_popcorn else clampi(enemy_level, 1, level_cap))
	# Ordinary rooms keep one room-popcorn slot so the respawn system remains
	# observable even when all random rolls miss. Shadow-bound composition is a
	# weighted identity policy: forcing a relief slot there would turn the
	# authored 20/80 Shadow/Normal ratio into a much larger Normal bias on the
	# small one-slot encounters.
	if not popcorn_flags.has(true) and not definition.is_shadow_bound():
		for index in range(variants.size() - 1, -1, -1):
			if variants[index] != "purple":
				variants[index] = "grey"
				levels[index] = _popcorn_enemy_level()
				popcorn_flags[index] = true
				popcorn_types[index] = ROOM_POPCORN
				ambush_flags[index] = false
				elite_flags[index] = false
				break
	# Shadow encounters keep any low-level mana-recovery slots readable: every
	# popcorn slot beside a Shadow Slime becomes a Normal Slime. The weighted
	# composition above intentionally does not append a guaranteed slot; doing so
	# would violate the approximately 20 percent Normal relief target.
	if variants.has("purple"):
		for index in variants.size():
			if popcorn_flags[index]:
				variants[index] = "grey"
				popcorn_types[index] = ELITE_POPCORN
				ambush_flags[index] = false
				elite_flags[index] = false
	return {"variants": variants, "levels": levels, "popcorn": popcorn_flags, "popcorn_types": popcorn_types, "ambush": ambush_flags, "elite": elite_flags}


func _encounter_definition() -> EncounterDefinition:
	if encounter_definition != null and encounter_definition.matchup_policy == matchup_policy:
		return encounter_definition
	var definition := EncounterDefinition.default_data()
	definition.matchup_policy = matchup_policy
	encounter_definition = definition
	return definition


func _room_definition() -> RoomDefinition:
	if room_definition == null:
		room_definition = RoomDefinition.default_data()
	return room_definition


func _variant_pool_has(pool: Array[Dictionary], variant: String) -> bool:
	for entry in pool:
		if str(entry.get("variant", "")) == variant:
			return true
	return false

func _generate_boss_encounter(generation_seed: int, room_depth: int) -> Dictionary:
	var boss_level := _generated_enemy_base_level(room_depth)
	# Keep early boss rooms focused on the boss and low-level neutral popcorn.
	# Normal/elemental minor slimes join the roster starting with Run 5.
	# Run 5 is the first mixed-support boss encounter. Add only one minor at
	# first, then grow the mixed roster in steps so later runs do not create a
	# sudden multi-enemy pressure spike.
	var minor_count := _boss_minor_count()
	# Purple is a rare supporting encounter. It is never the scaled lead boss,
	# and it is not guaranteed as a minor, because its pressure is much higher
	# than the ordinary slime variants.
	var boss_rng := RandomNumberGenerator.new()
	boss_rng.seed = generation_seed + 991
	var boss_variant := boss_variant_selection
	var has_explicit_boss_variant := SLIME_VARIANT_CATALOG_SCRIPT.is_variant(boss_variant)
	if not has_explicit_boss_variant:
		var roster: Array[StringName] = SLIME_VARIANT_CATALOG_SCRIPT.VARIANTS.duplicate()
		# Run 1 teaches the neutral encounter first. Later un-authored runs may
		# sample the complete boss catalog; purple remains rare only in the minor
		# conversion below.
		if progression_run_rank <= 1:
			roster.erase(&"purple")
		boss_variant = roster[boss_rng.randi_range(0, roster.size() - 1)]
	if progression_run_rank <= 1 and boss_variant == &"purple":
		boss_variant = &"grey"
	var variants: Array[String] = [String(boss_variant)]
	var levels: Array[int] = [mini(boss_level + 1, _enemy_level_cap())]
	var scales: Array[float] = [3.0]
	var encounter_rng := RandomNumberGenerator.new()
	encounter_rng.seed = generation_seed + 707
	for index in minor_count:
		# A designer-selected lead variant is a complete boss identity. Keep the
		# support wave on that identity as well; the seeded mixed roster is only
		# used when the encounter was not authored with an explicit selection.
		var selected_variant: String = String(boss_variant) if has_explicit_boss_variant else "grey" if progression_run_rank < _room_definition().boss_mixed_support_start_rank else String(SLIME_VARIANT_CATALOG_SCRIPT.VARIANTS[encounter_rng.randi_range(0, SLIME_VARIANT_CATALOG_SCRIPT.VARIANTS.size() - 1)])
		if not has_explicit_boss_variant and progression_run_rank > 1 and encounter_rng.randf() < SHADOW_BOSS_CHANCE:
			selected_variant = "purple"
		variants.append(selected_variant)
		levels.append(mini(boss_level, _enemy_level_cap()))
		scales.append(1.0)
	# Boss rooms always include a run-scaled group of low-level Normal Slime
	# support slots. This is the boss counterpart to Shadow's guaranteed
	# mana-recovery opportunity.
	var popcorn_flags: Array[bool] = []
	var popcorn_types: Array[String] = []
	var ambush_flags: Array[bool] = []
	for index in variants.size():
		popcorn_flags.append(false)
		popcorn_types.append("")
		ambush_flags.append(variants[index] == "purple" and encounter_rng.randf() < 0.40)
	for _support_index in _boss_support_popcorn_count():
		variants.append(String(boss_variant))
		levels.append(_popcorn_enemy_level())
		scales.append(1.0)
		popcorn_flags.append(true)
		popcorn_types.append(ELITE_POPCORN)
		ambush_flags.append(false)
	return {"variants": variants, "levels": levels, "scales": scales, "popcorn": popcorn_flags, "popcorn_types": popcorn_types, "ambush": ambush_flags}


func _enemy_level_cap() -> int:
	return progression_run_rank + 2 if progression_run_rank <= 3 else progression_run_rank + 4


func _generated_enemy_base_level(_room_depth: int) -> int:
	# Flat difficulty: enemy level derives from run rank, not room depth. The
	# depth parameter is retained only so callers (boss/encounter) keep an
	# unchanged signature while the difficulty source is rank-only.
	# R1-R3 use compact three-level bands; from R4 onward the encounter band
	# widens to five levels as the dungeon starts scaling more aggressively.
	return progression_run_rank + 1 if progression_run_rank <= 3 else progression_run_rank + 2


func _popcorn_enemy_chance() -> float:
	return _room_definition().popcorn_chance_for_rank(progression_run_rank)


func _popcorn_enemy_level() -> int:
	return maxi(1, player_level - 5)


func _popcorn_enemy_level_for_root(root: Object) -> int:
	var profile := root.get("player_profile") as PlayerProfile
	return maxi(1, profile.level - 5) if profile != null else _popcorn_enemy_level()


func _popcorn_enemy_level_for_profile(profile: PlayerProfile) -> int:
	return maxi(1, profile.level - 5) if profile != null else _popcorn_enemy_level()


func _boss_support_popcorn_count() -> int:
	return _room_definition().boss_support_popcorn_for_rank(progression_run_rank)


func _boss_minor_count() -> int:
	return _room_definition().boss_minor_count_for_rank(progression_run_rank)

func _normal_enemy_cap() -> int:
	return _room_definition().normal_enemy_cap

func _additional_enemy_chance(current_count: int) -> float:
	return _room_definition().additional_enemy_chance_for(progression_run_rank, current_count)


func enemy_count_for_room(room: DungeonGraph.RoomRecord) -> int:
	if room == null:
		return 0
	if room.room_type == DungeonGraph.ROOM_DOWNSTAIRS:
		return (_generate_boss_encounter(room.generation_seed, room.depth).get("variants", []) as Array).size()
	if room.room_type != DungeonGraph.ROOM_COMBAT and room.room_type != DungeonGraph.ROOM_SPECIAL_ENEMY and room.room_type != DungeonGraph.ROOM_TREASURE:
		return 0
	var is_special_room := room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY
	var extra_room_enemy := is_special_room or room.room_type == DungeonGraph.ROOM_TREASURE
	return (_generate_enemy_encounter(room.generation_seed, room.depth, extra_room_enemy, not is_special_room, room.encounter_tier).get("variants", []) as Array).size()


func configure_sockets(graph: DungeonGraph, room_id: StringName, _unlocked: bool, set_blocks: Callable) -> void:
	active_door_sockets.clear(); active_entrance_sockets.clear()
	for socket_value in dungeon_sockets.values():
		var visual := (socket_value as DungeonSocket).visual()
		if visual != null: visual.visible = false
	var room := graph.get_room(room_id)
	if room == null: return
	var state := room_states.get(room_id, {}) as Dictionary
	for exit_value in state.get("generated_exits", []) as Array:
		var exit_socket := StringName(exit_value); var socket := dungeon_sockets.get(exit_socket) as DungeonSocket
		if socket != null: active_door_sockets[exit_socket] = socket
	for entry_value in room.incoming_connections.keys():
		var entry_socket := StringName(entry_value); var socket := dungeon_sockets.get(entry_socket) as DungeonSocket
		if socket != null:
			active_entrance_sockets[entry_socket] = socket; var visual := socket.visual(); if visual != null: visual.visible = true
	set_blocks.call()
var dungeon_sockets: Dictionary = {}
var active_door_sockets: Dictionary = {}
var active_entrance_sockets: Dictionary = {}

func validate_socket_setup() -> void:
	var pairs := {DungeonGraph.WALL_LEFT: DungeonGraph.BOTTOM_RIGHT, DungeonGraph.WALL_RIGHT: DungeonGraph.BOTTOM_LEFT, DungeonGraph.BOTTOM_LEFT: DungeonGraph.WALL_RIGHT, DungeonGraph.BOTTOM_RIGHT: DungeonGraph.WALL_LEFT}
	for value in pairs.keys():
		var id := StringName(value); var socket := dungeon_sockets.get(id) as DungeonSocket
		if socket == null: push_error("Missing dungeon socket: %s" % id); continue
		if socket.paired_socket_id != StringName(pairs[id]): push_error("Dungeon socket %s has the wrong paired socket." % id)
		if socket.visual() == null or socket.trigger() == null or socket.spawn_marker() == null: push_error("Dungeon socket %s is missing a visual, trigger, or spawn marker." % id)


func hide_editor_only_guides(floor_tiles: Node2D) -> void:
	var floor_collision_guide := floor_tiles.get_node_or_null("FloorCollisionGuide") as CanvasItem
	if floor_collision_guide != null:
		floor_collision_guide.visible = false
	for socket_value in dungeon_sockets.values():
		var socket := socket_value as DungeonSocket
		var trigger := socket.trigger()
		if trigger != null:
			trigger.visible = false


func set_current_room(room_id: StringName, room_type: StringName) -> void:
	current_room_id = room_id
	current_room_type = room_type
	room_entered.emit(room_id, room_type)


func configure_enemy_spawn_services(services: RoomEnemySpawnServices) -> void:
	enemy_spawn_services = services


func enemy_spawn_context() -> RoomSpawnContext:
	if enemy_spawn_services == null:
		return null
	var player_foot := enemy_spawn_services.actor_foot(enemy_spawn_services.player) if enemy_spawn_services.player != null else Vector2.ZERO
	var chest_rect := enemy_spawn_services.current_chest_rect()
	var state := room_states.get(current_room_id, {}) as Dictionary
	return RoomSpawnContext.new(current_room_id, current_room_type, enemy_spawn_services.slimes, enemy_spawn_services.player, enemy_spawn_services.chest, player_foot, chest_rect, enemy_spawn_services, state)


func enemy_respawn_context() -> RoomRespawnContext:
	if enemy_spawn_services == null:
		return null
	var player_foot := enemy_spawn_services.actor_foot(enemy_spawn_services.player) if enemy_spawn_services.player != null else Vector2.ZERO
	var chest_rect := enemy_spawn_services.current_chest_rect()
	return RoomRespawnContext.new(current_room_id, current_room_type, enemy_spawn_services.slimes, enemy_spawn_services.player, enemy_spawn_services.chest, player_foot, chest_rect, enemy_spawn_services)


func enter_room(room_id: StringName, room_type: StringName, arrival_socket: StringName = &"") -> void:
	arrival_socket_id = arrival_socket
	set_current_room(room_id, room_type)


func fast_travel_to_flame(root: Object, destination_room_id: StringName) -> bool:
	if root == null or transition_locked or bool(root.get("room_transition_locked")):
		return false
	var graph := root.get("dungeon_graph") as DungeonGraph
	var map_controller := root.get("dungeon_map_controller") as Node
	if graph == null or map_controller == null:
		return false
	var current_room := graph.get_room(StringName(root.get("current_room_id")))
	var destination_room := graph.get_room(destination_room_id)
	if current_room == null or destination_room == null:
		return false
	var valid_origin := current_room.room_type == DungeonGraph.ROOM_START or not current_room.fire_flame.is_empty()
	var valid_destination := destination_room.id == graph.start_room_id or not destination_room.fire_flame.is_empty()
	if not valid_origin or not valid_destination:
		return false
	if not bool(map_controller.call("can_fast_travel_to_flame", current_room.id, destination_room.id)):
		return false
	var transition := plan_connected_room_transition(graph, current_room.id, destination_room.id, &"", &"")
	return enter_connected_room(root, transition)


func begin_transition() -> void:
	transition_locked = true


func end_transition() -> void:
	transition_locked = false


func plan_connected_room_transition(
	graph: DungeonGraph,
	source_room_id: StringName,
	destination_room_id: StringName,
	arrival_socket_id: StringName,
	departure_socket_id: StringName = &""
) -> RoomTransitionResult:
	var result := ROOM_TRANSITION_RESULT_SCRIPT.new() as RoomTransitionResult
	result.source_room_id = source_room_id
	result.destination_room_id = destination_room_id
	result.arrival_socket_id = arrival_socket_id
	result.departure_socket_id = departure_socket_id
	if graph == null:
		result.reject(RoomTransitionResult.Status.INVALID_GRAPH, &"missing_graph")
		return result
	var source := graph.get_room(source_room_id)
	if source == null:
		result.reject(RoomTransitionResult.Status.MISSING_SOURCE, &"missing_source_room")
		return result
	var destination := graph.get_room(destination_room_id)
	if destination == null:
		result.reject(RoomTransitionResult.Status.MISSING_DESTINATION, &"missing_destination_room")
		return result
	result.destination_room_type = destination.room_type
	return result


func plan_connection_transition(graph: DungeonGraph, connection: DungeonGraph.ConnectionRecord) -> RoomTransitionResult:
	if connection == null:
		var invalid := ROOM_TRANSITION_RESULT_SCRIPT.new() as RoomTransitionResult
		invalid.reject(RoomTransitionResult.Status.INVALID_CONNECTION, &"missing_connection")
		return invalid
	return plan_connected_room_transition(
		graph,
		connection.source_room_id,
		connection.destination_room_id,
		connection.destination_entry,
		connection.exit_socket)


func plan_socket_transition(
	graph: DungeonGraph,
	room_id: StringName,
	socket_id: StringName,
	is_entrance: bool,
) -> RoomTransitionResult:
	if graph == null:
		return plan_connected_room_transition(graph, room_id, &"", &"", socket_id)
	var connection := graph.get_connection_for_entry(room_id, socket_id) if is_entrance else graph.get_connection(room_id, socket_id)
	if connection == null:
		var invalid := ROOM_TRANSITION_RESULT_SCRIPT.new() as RoomTransitionResult
		invalid.source_room_id = room_id
		invalid.departure_socket_id = socket_id
		invalid.reject(RoomTransitionResult.Status.INVALID_CONNECTION, &"missing_socket_connection")
		return invalid
	if is_entrance:
		return plan_connected_room_transition(
			graph, room_id, connection.source_room_id, connection.exit_socket, connection.destination_entry)
	return plan_connection_transition(graph, connection)


func enter_connected_room(root: Object, transition: RoomTransitionResult) -> bool:
	if root is GameplayState:
		var services := ROOM_ENTRY_SERVICES_SCRIPT.new() as RoomEntryServices
		services.execute_entry = Callable(self, "_enter_connected_room_impl").bind(root as GameplayState, transition)
		return enter_connected_room_context(ROOM_ENTRY_CONTEXT_SCRIPT.new(services, transition)).succeeded()
	return false


func enter_connected_room_context(context: RoomEntryContext) -> RoomEntryResult:
	var result: RoomEntryResult = ROOM_ENTRY_RESULT_SCRIPT.new()
	if context != null:
		result.transition = context.transition
		if context.transition != null:
			result.room_id = context.transition.destination_room_id
			result.room_type = context.transition.destination_room_type
	if context == null or not context.is_valid():
		return result
	return context.services.execute_entry.call() as RoomEntryResult


func _enter_connected_room_impl(runtime: GameplayState, transition: RoomTransitionResult) -> RoomEntryResult:
	var result: RoomEntryResult = ROOM_ENTRY_RESULT_SCRIPT.new()
	result.transition = transition
	if transition != null:
		result.room_id = transition.destination_room_id
		result.room_type = transition.destination_room_type
	var player := runtime.player
	if player == null or not is_instance_valid(player):
		result.status = RoomEntryResult.Status.MISSING_PLAYER
		return result
	runtime.room_transition_locked = true
	begin_transition()
	# A combo is local to an encounter. Entering a new room must not carry the
	# previous room's timer or multiplier into the next one.
	runtime._reset_combo()
	runtime._save_current_room_state()
	runtime.current_room_id = transition.destination_room_id
	runtime._sync_current_room_metadata(transition.arrival_socket_id)
	enter_room(transition.destination_room_id, transition.destination_room_type, transition.arrival_socket_id)
	_maybe_add_backtrack_popcorn(runtime)
	runtime._ensure_current_room_layout()
	runtime._update_room_number_indicator()
	var arrival_socket := dungeon_sockets.get(transition.arrival_socket_id) as DungeonSocket
	player.global_position = _arrival_player_position(runtime, arrival_socket)
	if not runtime._can_actor_stand_at_current_position(player):
		var requested_foot: Vector2 = runtime._actor_foot(player)
		var nearest_foot := nearest_player_walkable_point(runtime, requested_foot)
		if nearest_foot != Vector2.INF:
			player.global_position += nearest_foot - requested_foot
		else:
			# Preserve the old sampled-point fallback for partially initialized test
			# scenes that do not yet have a usable player collision context.
			var fallback_foot: Vector2 = runtime._nearest_slime_walkable_point(requested_foot)
			player.global_position = fallback_foot - GameplayState.ACTOR_FOOT_OFFSET
	player.flip_h = arrival_socket != null and arrival_socket.inward_facing.x < 0.0
	runtime.last_player_facing_left = player.flip_h
	runtime.player_is_attacking = false
	runtime.magic_input_was_down = false
	runtime._cancel_magic_animation()
	runtime._reset_magic_runtime()
	runtime.player_is_rolling = false
	runtime.player_is_backflipping = false
	runtime.orb_knockback_animation_lock = false
	runtime.orb_knockback_animation_grace = false
	runtime.orb_knockback_attack_cancelled = false
	runtime._clear_roll_dust()
	var equipment_visual := runtime.player_equipment_visual_component
	if equipment_visual != null:
		equipment_visual.reset_for_room(runtime.gameplay_frame_controller.equipment_visual_context(runtime))
	runtime.player_attack_visual.visible = false
	runtime._set_current_target(null)
	runtime.target_input_was_down = false
	var npc := runtime.npc_controller as NpcController
	if npc != null:
		npc.hide_dialogue(runtime)
	runtime._set_target_ui_visible(false)
	runtime._apply_room_state()
	runtime._build_depth_lists()
	# The destination layout/state is now fully applied. Persist the profile first
	# and then capture this safe boundary; a browser restart cannot resume from a
	# half-applied room transition.
	if runtime.player_profile != null:
		ProfileSaveService.save_profile(runtime.player_profile)
	runtime.call_deferred("_save_active_run_checkpoint")
	runtime.call_deferred("_release_room_transition_lock")
	result.status = RoomEntryResult.Status.ENTERED
	return result


func _arrival_player_position(root: Object, socket: DungeonSocket) -> Vector2:
	if socket == null:
		return root.get("player_start_position")
	# Boss arrival sockets are intentionally sealed as soon as the encounter
	# begins. Their trigger polygon belongs to the doorway itself, so deriving a
	# player position from that polygon places the player's foot inside the
	# entrance block and the normal transition fallback snaps them to the room's
	# nearest sampled point (the visual center). Use the authored inset marker
	# instead; it is shared by normal transitions and the boss debug scene.
	if root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS:
		var boss_marker := socket.spawn_marker()
		if boss_marker != null:
			return boss_marker.global_position
	var trigger := socket.trigger()
	if trigger != null and trigger.polygon.size() >= 3:
		var center := Vector2.ZERO
		for point in trigger.polygon:
			center += trigger.to_global(point)
		center /= float(trigger.polygon.size())
		return center + socket.arrival_offset
	var marker := socket.spawn_marker()
	return marker.global_position if marker != null else root.get("player_start_position")

func activate_room(root: Object) -> RoomActivationResult:
	if root is GameplayState:
		var runtime := root as GameplayState
		var room := runtime.dungeon_graph.get_room(runtime.current_room_id)
		var state := room_states.get(runtime.current_room_id, {}) as Dictionary
		return activate_room_context(ROOM_ACTIVATION_CONTEXT_SCRIPT.new(RoomActivationServices.from_runtime(runtime, self, state, runtime.current_room_type), self, runtime.current_room_id, runtime.current_room_type, room, state))
	var result := ROOM_ACTIVATION_RESULT_SCRIPT.new() as RoomActivationResult
	result.reject(RoomActivationResult.Status.MISSING_ROOT)
	return result


func activate_room_context(context: RoomActivationContext) -> RoomActivationResult:
	var result := ROOM_ACTIVATION_RESULT_SCRIPT.new() as RoomActivationResult
	if context == null or context.services == null:
		result.reject(RoomActivationResult.Status.MISSING_ROOT)
		return result
	if context.services.dungeon_graph == null:
		result.reject(RoomActivationResult.Status.INVALID_GRAPH)
		return result
	result.room_id = context.room_id
	if context.room == null:
		result.reject(RoomActivationResult.Status.MISSING_ROOM)
		return result
	result.room_type = context.room_type
	result.state = context.state.duplicate(true)
	if result.state.is_empty():
		result.reject(RoomActivationResult.Status.MISSING_STATE)
		return result
	apply_state_context(context)
	result.state = (room_states.get(result.room_id, {}) as Dictionary).duplicate(true)
	result.spawn_result = last_spawn_result
	result.configured_enemy_slots = (result.state.get("enemy_variants", []) as Array).size()
	for slime in context.services.slimes:
		if slime.visible:
			result.visible_enemy_slots += 1
	return result


func apply_state(root: Object) -> void:
	if root is GameplayState:
		activate_room(root)

func apply_state_context(context: RoomActivationContext) -> void:
	last_spawn_result = null
	var services := context.services
	var state := context.state
	var room_type := context.room_type
	services.activation_state = state
	var has_regular_treasure: bool = bool(state.get("regular_room_treasure", false)) and room_type == DungeonGraph.ROOM_COMBAT
	services.set_runtime_property.call("regular_room_treasure", has_regular_treasure)
	var treasure_chest_claimed := _treasure_chest_claimed_from_state(state) if room_type == DungeonGraph.ROOM_TREASURE else false
	var regular_chest_claimed := _treasure_chest_claimed_from_state(state) if has_regular_treasure else false
	if room_type == DungeonGraph.ROOM_TREASURE:
		services.set_runtime_property.call("chest_unlocked", treasure_chest_claimed)
		services.set_runtime_property.call("chest_claimed", treasure_chest_claimed)
		services.set_runtime_property.call("chest_evaporated", bool(state.get("chest_evaporated", treasure_chest_claimed)))
	elif has_regular_treasure:
		services.set_runtime_property.call("chest_unlocked", regular_chest_claimed)
		services.set_runtime_property.call("chest_claimed", regular_chest_claimed)
		services.set_runtime_property.call("chest_evaporated", bool(state.get("chest_evaporated", regular_chest_claimed)))
	# The scene's base Chest node is authored visible. Clear its presentation
	# before any room-specific branch; treasure rooms explicitly re-add it later.
	services.hide_chest_presentation.call()
	services.clear_active_world_drop.call()
	services.clear_chroma_pickups.call()
	services.clear_soul_pickups.call()
	services.apply_special_enemy_color_policy.call()
	if is_cleared(context.room_id):
		state["finished"] = true
	if room_type == DungeonGraph.ROOM_START or room_type == DungeonGraph.ROOM_REST:
		services.apply_rest_room_state.call()
	elif room_type == DungeonGraph.ROOM_NPC:
		services.apply_npc_room_state.call()
	elif room_type == DungeonGraph.ROOM_PUZZLE:
		services.apply_puzzle_state.call()
	elif room_type == DungeonGraph.ROOM_ORB:
		services.apply_orb_state.call()
	elif bool(state.get("finished", false)):
		services.apply_finished_room_state.call()
	else:
		services.reset_chest_for_room.call()
		# Regular-room treasure is generated with the room and must be visible on
		# entry. It stays grey/locked until the enemy encounter is cleared.
		if room_type == DungeonGraph.ROOM_TREASURE and treasure_chest_claimed:
			services.set_runtime_property.call("chest_unlocked", true)
			services.set_runtime_property.call("chest_claimed", true)
			services.set_runtime_property.call("chest_evaporated", bool(state.get("chest_evaporated", true)))
		elif has_regular_treasure and regular_chest_claimed:
			services.set_runtime_property.call("chest_unlocked", true)
			services.set_runtime_property.call("chest_claimed", true)
			services.set_runtime_property.call("chest_evaporated", bool(state.get("chest_evaporated", true)))
		services.reset_slimes_for_room.call()
	services.restore_world_drop.call()
	services.restore_chroma_pickups.call()
	services.apply_chest_map_tint.call()


func _treasure_chest_claimed_from_state(state: Dictionary) -> bool:
	# Current saves explicitly persist chest_claimed, including false for an
	# uncleared/unclaimed chest. Older in-memory saves only recorded the presence
	# of item_rewarded or chest_evaporated, so the key itself is the legacy signal.
	if state.has("chest_claimed"):
		return !!state.get("chest_claimed", false)
	return state.has("chest_evaporated") or state.has("item_rewarded")


func save_treasure_chest_state(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id")
	var state := room_states.get(room_id, {}) as Dictionary
	state["chest_claimed"] = bool(root.get("chest_claimed"))
	state["chest_evaporated"] = bool(root.get("chest_evaporated"))
	room_states[room_id] = state


func save_current_room_state(context: RoomCheckpointContext) -> RoomCheckpointResult:
	var result: RoomCheckpointResult = ROOM_CHECKPOINT_RESULT_SCRIPT.new()
	if context != null:
		result.room_id = context.room_id
	if context == null or not context.is_valid():
		return result
	var state: Dictionary = room_states.get(context.room_id, {}) as Dictionary
	var room := context.room
	if context.room_type == DungeonGraph.ROOM_PUZZLE:
		state["finished"] = context.puzzle_finished
	elif room != null and (room.room_type == DungeonGraph.ROOM_TREASURE or bool(state.get("regular_room_treasure", false))):
		# Treasure completion belongs to the enemy encounter. The chest is an
		# optional reward and must not reopen or clear the room on a revisit.
		state["chest_claimed"] = context.chest_claimed
		state["chest_evaporated"] = context.chest_evaporated
		state["finished"] = bool(state.get("finished", false)) or context.room_is_cleared
	else:
		# Combat and boss rooms are completed by enemy defeat, not by opening a
		# chest. Preserve the clear state when the player leaves before re-entry.
		state["finished"] = bool(state.get("finished", false)) or context.room_is_cleared

	var saved_drops: Array = []
	for drop in context.world_item_drops:
		var sprite := drop.get("sprite") as Sprite2D
		var item := drop.get("item") as ItemInstance
		if sprite != null and is_instance_valid(sprite) and item != null:
			var saved_position := sprite.global_position
			if float(drop.get("air_time", 0.0)) > 0.0 and drop.has("landing_position"):
				saved_position = drop.get("landing_position") as Vector2
			saved_drops.append({"item": item.to_dictionary(), "position": saved_position})
	if saved_drops.is_empty():
		state.erase("world_item_drops")
	else:
		state["world_item_drops"] = saved_drops
	state.erase("world_item_drop")

	var saved_pickups: Array = []
	var pickup_controller := context.chroma_pickup_controller
	if pickup_controller != null:
		for index in pickup_controller.sprites.size():
			var pickup := pickup_controller.sprites[index]
			if pickup != null and is_instance_valid(pickup):
				saved_pickups.append({"position": pickup.global_position, "value": pickup_controller.values[index]})
	if saved_pickups.is_empty():
		state.erase("chroma_pickups")
	else:
		state["chroma_pickups"] = saved_pickups
	room_states[context.room_id] = state
	result.status = RoomCheckpointResult.Status.SAVED
	result.finished = bool(state.get("finished", false))
	if result.finished:
		mark_cleared_context(ROOM_CLEAR_CONTEXT_SCRIPT.new(context.room_id, room))
	return result

func _clear_active_world_drop(root: Object) -> void:
	root.call("_clear_world_item_drops")

func _restore_chroma_pickups(root: Object, state: Dictionary) -> void:
	var saved_pickups: Variant = state.get("chroma_pickups", [])
	if saved_pickups is Array:
		root.call("_restore_chroma_pickups", saved_pickups as Array)

func _restore_world_drop(root: Object, state: Dictionary) -> void:
	var saved_drops: Variant = state.get("world_item_drops", [])
	if saved_drops is Array:
		root.call("_restore_chest_item_drops", saved_drops as Array)
		return
	# Keep the old singular state readable for runs created before chest drops
	# became a collection, without making the runtime model singular again.
	var saved_drop: Variant = state.get("world_item_drop", {})
	if saved_drop is Dictionary:
		root.call("_restore_chest_item_drops", [saved_drop])


func build_entrance_blocks(root: Object) -> void:
	var blocks: Array[PackedVector2Array] = []
	var portals: Array[PackedVector2Array] = []
	var graph := root.get("dungeon_graph") as DungeonGraph
	for socket_id in dungeon_sockets.keys():
		var socket := dungeon_sockets.get(socket_id) as DungeonSocket
		if socket == null: continue
		var is_entrance := active_entrance_sockets.has(socket_id)
		var is_active := active_door_sockets.has(socket_id) or is_entrance
		if not is_active:
			continue
		var room_id: StringName = root.get("current_room_id")
		var connection := graph.get_connection_for_entry(room_id, socket_id) if is_entrance else graph.get_connection(room_id, socket_id)
		var connection_available: bool = connection != null and bool(root.call("_map_connection_available", connection, is_entrance))
		var boss_entrance_sealed: bool = is_entrance and root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS and not bool(root.get("entrance_open"))
		if connection_available and not boss_entrance_sealed:
			portals.append_array(_socket_portal_polygons(root, socket))
	root.set("entrance_block_polygons", blocks)
	var area := root.get("walkable_area") as WalkableArea
	if area != null:
		area.set_walkable_portals(portals)
	eject_player_from_closed_sockets(root)


func _socket_portal_polygons(root: Object, socket: DungeonSocket) -> Array[PackedVector2Array]:
	var portals: Array[PackedVector2Array] = []
	var area := root.get("walkable_area") as WalkableArea
	for tile in socket.block_tiles():
		var polygon := area.tile_polygon_for_sprite(tile) if area != null else PackedVector2Array()
		if polygon.size() >= 3:
			portals.append(polygon)
	if not portals.is_empty():
		return portals
	var trigger := _socket_trigger_polygon(socket)
	if trigger.size() >= 3:
		portals.append(trigger)
	return portals


func eject_player_from_closed_sockets(root: Object) -> bool:
	var player := root.get("player") as Sprite2D
	if player == null or not is_instance_valid(player) or bool(root.get("room_transition_locked")):
		return false
	var feet := _player_door_feet_rect(root, player)
	if not feet.has_area():
		return false
	var closed_triggers: Array[PackedVector2Array] = []
	var occupies_closed_socket := false
	var graph := root.get("dungeon_graph") as DungeonGraph
	if graph == null:
		return false
	for socket_id in dungeon_sockets.keys():
		var socket := dungeon_sockets.get(socket_id) as DungeonSocket
		if socket == null:
			continue
		var is_entrance := active_entrance_sockets.has(socket_id)
		if not is_entrance and not active_door_sockets.has(socket_id):
			continue
		var connection := graph.get_connection_for_entry(root.get("current_room_id"), socket_id) if is_entrance else graph.get_connection(root.get("current_room_id"), socket_id)
		if connection == null or bool(root.call("_map_connection_available", connection, is_entrance)):
			continue
		var trigger := _socket_trigger_polygon(socket)
		if trigger.size() < 3:
			continue
		closed_triggers.append(trigger)
		occupies_closed_socket = occupies_closed_socket or _rect_touches_polygon(feet, trigger)
	if not occupies_closed_socket:
		return false
	var requested_foot: Vector2 = root.call("_actor_foot", player)
	var nearest_foot := nearest_player_walkable_point(root, requested_foot, closed_triggers)
	if nearest_foot == Vector2.INF:
		return false
	var original_position := player.global_position
	player.global_position += nearest_foot - requested_foot
	var relocated_feet := _player_door_feet_rect(root, player)
	var valid := bool(root.call("_can_actor_stand_at_current_position", player)) and not bool(root.call("_collides_with_static", player))
	for trigger in closed_triggers:
		if _rect_touches_polygon(relocated_feet, trigger):
			valid = false
			break
	if not valid:
		player.global_position = original_position
		return false
	root.call("_update_depth_sorting")
	return true


func nearest_player_walkable_point(root: Object, requested_foot: Vector2, forbidden_triggers: Array[PackedVector2Array] = []) -> Vector2:
	var area := root.get("walkable_area") as WalkableArea
	var player := root.get("player") as Sprite2D
	if area == null or area.is_empty() or player == null:
		return Vector2.INF
	var candidates: Array[Vector2] = [area.nearest_walkable_point(requested_foot)]
	for point in area.points:
		candidates.append(point)
	for radius in PLAYER_DOOR_REPOSITION_RADII:
		for direction_index in PLAYER_DOOR_REPOSITION_DIRECTIONS:
			candidates.append(requested_foot + Vector2.RIGHT.rotated(TAU * float(direction_index) / float(PLAYER_DOOR_REPOSITION_DIRECTIONS)) * float(radius))
	var best := Vector2.INF
	var best_distance := INF
	for candidate in candidates:
		if not area.is_walkable(candidate) or not _player_foot_clear_of_triggers(root, player, candidate, forbidden_triggers):
			continue
		var distance := requested_foot.distance_squared_to(candidate)
		if distance >= best_distance:
			continue
		if not _player_position_is_valid_at_foot(root, player, candidate, forbidden_triggers):
			continue
		best = candidate
		best_distance = distance
	return best


func _player_position_is_valid_at_foot(root: Object, player: Sprite2D, foot: Vector2, forbidden_triggers: Array[PackedVector2Array]) -> bool:
	var original_position := player.global_position
	var original_foot: Vector2 = root.call("_actor_foot", player)
	player.global_position += foot - original_foot
	var valid := bool(root.call("_can_actor_stand_at_current_position", player)) and not bool(root.call("_collides_with_static", player))
	valid = valid and _player_foot_clear_of_triggers(root, player, foot, forbidden_triggers)
	player.global_position = original_position
	return valid


func _player_foot_clear_of_triggers(root: Object, player: Sprite2D, foot: Vector2, forbidden_triggers: Array[PackedVector2Array]) -> bool:
	if forbidden_triggers.is_empty():
		return true
	var original_position := player.global_position
	var original_foot: Vector2 = root.call("_actor_foot", player)
	player.global_position += foot - original_foot
	var feet := _player_door_feet_rect(root, player)
	var clear := true
	for trigger in forbidden_triggers:
		if _rect_touches_polygon(feet, trigger):
			clear = false
			break
	player.global_position = original_position
	return clear


func _player_door_feet_rect(root: Object, player: Sprite2D) -> Rect2:
	var feet: Rect2 = root.call("_collision_guide_rect_by_name", player, "DoorFeetGuide") as Rect2
	if feet.has_area():
		return feet
	var foot: Vector2 = root.call("_actor_foot", player)
	var size: Vector2 = root.get("PLAYER_DOOR_FOOT_COLLIDER_SIZE") if root.get("PLAYER_DOOR_FOOT_COLLIDER_SIZE") != null else Vector2(4, 2)
	return Rect2(foot - size * 0.5, size)


func try_enter_active_socket(root: Object, door_active: bool, entrance_open: bool, transition_lock: bool) -> bool:
	if transition_lock: return false
	var feet: Rect2 = root.call("_collision_guide_rect_by_name", root.get("player"), "DoorFeetGuide")
	if not feet.has_area():
		var foot: Vector2 = root.call("_actor_foot", root.get("player")); var size: Vector2 = root.get("PLAYER_DOOR_FOOT_COLLIDER_SIZE") if root.get("PLAYER_DOOR_FOOT_COLLIDER_SIZE") != null else Vector2(4, 2); feet = Rect2(foot - size * 0.5, size)
	if bool(root.get("final_exit_open")) and root.get("current_room_type") == DungeonGraph.ROOM_DOWNSTAIRS:
		var final_socket_id: StringName = root.get("final_exit_socket")
		var final_socket := dungeon_sockets.get(final_socket_id) as DungeonSocket
		if final_socket != null and _rect_touches_polygon(feet, _socket_trigger_polygon(final_socket)):
			root.call("_enter_final_settlement_room")
			return true
	# Authored Run 1 doors are independently gated by the map connection state.
	# The legacy room-wide flag can be false while a color-matched socket is
	# visibly open (notably after a special-room color change), so it must not
	# suppress every authored exit. Keep the tutorial starter gate explicit.
	var map_controller := root.get("dungeon_map_controller") as Node
	var authored_run1 := map_controller != null and bool(map_controller.call("is_authored_run1"))
	var starter_gate_locked: bool = root.get("current_room_type") == DungeonGraph.ROOM_START and not bool(root.get("starter_flame_attuned_this_run"))
	# A generated map can expose one color-matched connection while the legacy
	# room-wide flag is still false. Let the connection-level map check decide
	# whether that socket is traversable instead of blocking every exit first.
	if (door_active or map_controller != null or (authored_run1 and not starter_gate_locked)) and _try_enter_socket_set(root, active_door_sockets, feet, false): return true
	return entrance_open and _try_enter_socket_set(root, active_entrance_sockets, feet, true)


func _try_enter_socket_set(root: Object, sockets: Dictionary, feet: Rect2, is_entrance: bool) -> bool:
	for socket_value in sockets.values():
		var socket := socket_value as DungeonSocket; var polygon := _socket_trigger_polygon(socket)
		if polygon.size() < 3 or not _rect_touches_polygon(feet, polygon): continue
		var socket_id := socket.socket_id(); var graph := root.get("dungeon_graph") as DungeonGraph; var room_id: StringName = root.get("current_room_id")
		var connection := graph.get_connection_for_entry(room_id, socket_id) if is_entrance else graph.get_connection(room_id, socket_id)
		if connection == null: continue
		if not bool(root.call("_map_connection_available", connection, is_entrance)): continue
		var transition := plan_socket_transition(graph, room_id, socket_id, is_entrance)
		if enter_connected_room(root, transition):
			return true
	return false


func _socket_trigger_polygon(socket: DungeonSocket) -> PackedVector2Array:
	if socket == null or socket.trigger() == null or socket.trigger().polygon.size() < 3: return PackedVector2Array()
	var polygon := PackedVector2Array(); var guide := socket.trigger()
	for point in guide.polygon: polygon.append(guide.to_global(point))
	return polygon


func _rect_touches_polygon(rect: Rect2, polygon: PackedVector2Array) -> bool:
	if polygon.size() < 3: return false
	var bounds := Rect2(polygon[0], Vector2.ZERO)
	for index in range(1, polygon.size()): bounds = bounds.expand(polygon[index])
	if not bounds.intersects(rect, false): return false
	if Geometry2D.is_point_in_polygon(rect.get_center(), polygon): return true
	var corners := [rect.position, rect.position + Vector2(rect.size.x, 0), rect.position + rect.size, rect.position + Vector2(0, rect.size.y)]
	for point in corners: if Geometry2D.is_point_in_polygon(point, polygon): return true
	for point in polygon: if rect.has_point(point): return true
	return false


func mark_cleared(room_id: StringName) -> RoomClearResult:
	var graph: DungeonGraph = get_parent().get("dungeon_graph") as DungeonGraph if get_parent() != null else null
	var room := graph.get_room(room_id) if graph != null else null
	return mark_cleared_context(ROOM_CLEAR_CONTEXT_SCRIPT.new(room_id, room))


func mark_cleared_context(context: RoomClearContext) -> RoomClearResult:
	var result: RoomClearResult = ROOM_CLEAR_RESULT_SCRIPT.new()
	if context != null:
		result.room_id = context.room_id
		result.room_type = context.room.room_type if context.room != null else &""
	if context == null or not context.is_valid():
		return result
	var state: Dictionary = room_states.get(context.room_id, {}) as Dictionary
	result.was_finished = bool(state.get("finished", false))
	state["finished"] = true
	var had_popcorn_waiting := not (state.get("popcorn_respawn_waiting", {}) as Dictionary).is_empty()
	_schedule_room_popcorn_respawns(state, context.room_id)
	result.popcorn_respawn_scheduled = had_popcorn_waiting
	if context.room != null and context.room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY:
		state["special_clear_earned"] = true
		_ensure_special_enemy_respawn_timers(state)
		result.special_clear_earned = true
	room_states[context.room_id] = state
	result.became_finished = not result.was_finished
	result.status = RoomClearResult.Status.CLEARED if result.became_finished else RoomClearResult.Status.ALREADY_CLEARED
	if result.became_finished:
		room_cleared.emit(result)
	return result


func _schedule_room_popcorn_respawns(state: Dictionary, room_id: StringName) -> void:
	var waiting := state.get("popcorn_respawn_waiting", {}) as Dictionary
	if waiting.is_empty():
		return
	var pending := state.get("popcorn_respawn_slots", {}) as Dictionary
	var respawn_cycle := int(state.get("popcorn_respawn_cycle", 0)) + 1
	state["popcorn_respawn_cycle"] = respawn_cycle
	var random_source := RandomNumberGenerator.new()
	random_source.seed = String(room_id).hash() ^ int(state.get("enemy_spawn_seed", 0)) ^ respawn_cycle * 7919 ^ 0x504F5043
	for key in waiting.keys():
		var entry := waiting[key] as Dictionary
		var death_order := int(entry.get("death_order", 0))
		var dead_before_clear := maxf(0.0, float(entry.get("dead_before_clear", 0.0)))
		# Noise owns most of the result. Death order and time already spent dead
		# provide a restrained stagger while the final deadline remains 30-45s.
		var order_offset := minf(float(death_order) * 0.75, 4.0)
		var age_offset := minf(dead_before_clear * 0.15, 4.0)
		var delay := clampf(random_source.randf_range(POPCORN_RESPAWN_MIN_DELAY, POPCORN_RESPAWN_MAX_DELAY) + order_offset - age_offset, POPCORN_RESPAWN_MIN_DELAY, POPCORN_RESPAWN_MAX_DELAY)
		pending[str(key)] = delay
	state["popcorn_respawn_slots"] = pending
	state.erase("popcorn_respawn_waiting")


func is_cleared(room_id: StringName) -> bool:
	var state: Variant = room_states.get(room_id, {})
	return state is Dictionary and state.get("finished", false) == true


func _apply_special_enemy_color_policy(root: Object, state: Dictionary) -> void:
	var graph := root.get("dungeon_graph") as DungeonGraph
	var room := graph.get_room(root.get("current_room_id")) if graph != null else null
	if room == null or room.room_type != DungeonGraph.ROOM_SPECIAL_ENEMY or room.special_respawn_required_color.is_empty():
		return
	if not bool(state.get("special_clear_earned", false)):
		return
	var map_controller := root.get("dungeon_map_controller") as Node
	var active_color: StringName = StringName(map_controller.call("current_color")) if map_controller != null else &"neutral"
	state["finished"] = active_color == room.special_respawn_required_color
	room_states[root.get("current_room_id")] = state


func refresh_special_enemy_color_policy(root: Object) -> void:
	var state: Dictionary = room_states.get(root.get("current_room_id"), {}) as Dictionary
	var previous_finished := bool(state.get("finished", false))
	_apply_special_enemy_color_policy(root, state)
	var now_finished := bool(state.get("finished", false))
	if previous_finished == now_finished:
		return
	if now_finished:
		# Entering the required map color suppresses the room's current enemies,
		# but their respawn clocks remain anchored to when each slot disappeared.
		schedule_special_enemy_respawns(root)
		for slime in root.get("slimes") as Array[Sprite2D]: kill_slime_without_effects(root, slime)
		root.call("_set_door_active", true)
		root.call("_set_entrance_open", true)
	else:
		# Leaving the required color does not instantly repopulate the room. The
		# per-slot timers are allowed to finish and respawn enemies independently.
		schedule_special_enemy_respawns(root)
		root.call("_set_door_active", false)
		root.call("_set_entrance_open", true)


func apply_rest_state(root: Object) -> void:
	reset_slimes_for_room(root)
	var chest := root.get("chest") as Sprite2D
	var collision := root.get("collision_sprites") as Array[Sprite2D]
	chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true); root.set("chest_evaporated", true); collision.erase(chest)
	(root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest); root.call("_set_door_active", true); root.call("_set_entrance_open", true)
	var fire := root.get("rest_fire") as Sprite2D; fire.visible = true; var firepit := fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = true; if firepit != null and not collision.has(firepit): collision.append(firepit)
	_assign_rest_fire_palette(root)
	var demon := root.get("cloaked_demon") as Sprite2D
	demon.visible = root.get("current_room_type") == DungeonGraph.ROOM_START
	if demon.visible:
		demon.position = root.get("cloaked_demon_start_position"); var npc := root.get("npc_controller") as NpcController; npc.demon_wander_origin = root.get("cloaked_demon_start_position"); npc.demon_wander_timer = 0.0; npc.demon_patrol_direction = -1.0; npc.demon_patrol_paused = false; npc.demon_patrol_pause_timer = 0.0; npc.demon_patrol_position_x = demon.position.x; root.call("_configure_cloaked_demon_patrol_route")
		if not collision.has(demon): collision.append(demon)
	else: collision.erase(demon)
	root.call("_set_rest_fire_frame", 0); (root.get("rest_fire_controller") as RestFireController).reset_animation(); _mark_finished(root)


func _assign_rest_fire_palette(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id"); var room_type: StringName = root.get("current_room_type")
	var fire_palette: String
	var graph := root.get("dungeon_graph") as DungeonGraph
	var tutorial_run := graph != null and graph.completed_run_count == 0
	if room_type == DungeonGraph.ROOM_START:
		var profile := root.get("player_profile") as PlayerProfile
		fire_palette = profile.hub_palette() if profile != null else str(root.get("run_start_palette_name"))
		if fire_palette.is_empty(): fire_palette = str(root.get("run_start_palette_name"))
		if fire_palette.is_empty(): fire_palette = String((root.get("screen_state_controller") as Object).get("player_palette_name"))
	elif tutorial_run:
		fire_palette = str(root.get("run_start_palette_name"))
		if fire_palette.is_empty(): fire_palette = String((root.get("screen_state_controller") as Object).get("player_palette_name"))
	else:
		var room := graph.get_room(room_id) if graph != null else null
		if room != null and room.fire_flame != &"":
			fire_palette = ASPECT_CATALOG_SCRIPT.palette_for_flame(room.fire_flame)
		else:
			var state: Dictionary = room_states.get(room_id, {}) as Dictionary
			if not state.has("fire_palette"):
				var rng := root.get("rng") as RandomNumberGenerator
				state["fire_palette"] = PaletteLibrary.REST_FIRE_PALETTES[rng.randi_range(0, PaletteLibrary.REST_FIRE_PALETTES.size() - 1)]
				room_states[room_id] = state
			fire_palette = str(state.get("fire_palette"))
	root.call("_apply_rest_fire_palette", fire_palette)


func apply_npc_state(root: Object) -> void:
	reset_slimes_for_room(root)
	var chest := root.get("chest") as Sprite2D; var collision := root.get("collision_sprites") as Array[Sprite2D]; chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true); root.set("chest_evaporated", true); collision.erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest); var fire := root.get("rest_fire") as Sprite2D; fire.visible = false; var firepit := fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = false; collision.erase(firepit)
	var demon := root.get("cloaked_demon") as Sprite2D; demon.visible = true; demon.position = root.get("cloaked_demon_start_position"); var npc := root.get("npc_controller") as NpcController; npc.demon_wander_origin = demon.position; npc.demon_wander_timer = 0.0; npc.demon_patrol_direction = -1.0; npc.demon_patrol_paused = false; npc.demon_patrol_pause_timer = 0.0; npc.demon_patrol_position_x = demon.position.x; root.call("_configure_cloaked_demon_patrol_route"); if not collision.has(demon): collision.append(demon)
	root.call("_set_door_active", true); root.call("_set_entrance_open", true); _mark_finished(root)


func apply_puzzle_state(root: Object, solved: bool) -> void:
	reset_chest_for_room(root)
	var chest := root.get("chest") as Sprite2D
	var collision := root.get("collision_sprites") as Array[Sprite2D]
	chest.visible = false
	root.set("chest_unlocked", solved)
	root.set("chest_claimed", true)
	root.set("chest_evaporated", true)
	collision.erase(chest)
	(root.get("depth_sprites") as Array[Sprite2D]).erase(chest)
	(root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)
	root.call("_set_door_active", solved)
	root.call("_set_entrance_open", true)
	if solved:
		mark_cleared_context(_room_clear_context_from_root(root))


func apply_orb_state(root: Object) -> void:
	reset_chest_for_room(root, false)
	reset_slimes_for_room(root)
	root.call("_set_door_active", true)
	root.call("_set_entrance_open", true)


func apply_finished_state(root: Object) -> void:
	var fire := root.get("rest_fire") as Sprite2D; fire.visible = false; var firepit := fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(firepit); (root.get("cloaked_demon") as Sprite2D).visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(root.get("cloaked_demon")); reset_slimes_for_room(root)
	var room: DungeonGraph.RoomRecord = (root.get("dungeon_graph") as DungeonGraph).get_room(root.get("current_room_id"))
	var is_treasure := room != null and room.room_type == DungeonGraph.ROOM_TREASURE
	var is_regular_treasure := bool(root.get("regular_room_treasure"))
	var is_boss := room != null and room.room_type == DungeonGraph.ROOM_DOWNSTAIRS
	var chest := root.get("chest") as Sprite2D
	if (is_treasure or is_regular_treasure) and not bool(root.get("chest_claimed")) and not bool(root.get("chest_evaporated")):
		var normal_texture := root.get("chest_normal_texture") as Texture2D
		if normal_texture != null:
			chest.texture = normal_texture
		chest.visible = true; root.set("chest_unlocked", true); root.set("chest_evaporated", false)
		if not (root.get("collision_sprites") as Array[Sprite2D]).has(chest): (root.get("collision_sprites") as Array[Sprite2D]).append(chest)
		if not (root.get("depth_sprites") as Array[Sprite2D]).has(chest): (root.get("depth_sprites") as Array[Sprite2D]).append(chest)
		if not (root.get("occluder_sprites") as Array[Sprite2D]).has(chest): (root.get("occluder_sprites") as Array[Sprite2D]).append(chest)
	else:
		chest.visible = false; root.set("chest_unlocked", true); root.set("chest_claimed", true if not (is_treasure or is_regular_treasure) else root.get("chest_claimed")); root.set("chest_evaporated", true if not (is_treasure or is_regular_treasure) else root.get("chest_evaporated")); (root.get("collision_sprites") as Array[Sprite2D]).erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)
	if is_boss:
		root.call("_open_final_exit")
	else:
		root.call("_set_door_active", true); root.call("_set_entrance_open", true)
	root.set("chest_collect_flash_timer", 0.0)
	for key in [&"chest_unlock_overlay", &"chest_flash_overlay"]:
		var overlay := root.get(key) as Sprite2D
		if overlay != null: overlay.queue_free(); root.set(key, null)
	var prompt := root.get("interact_prompt") as Sprite2D
	if prompt != null: prompt.visible = false


func kill_slime_without_effects(root: Object, slime: Sprite2D) -> void:
	if root is GameplayState:
		var context := enemy_respawn_context()
		if context != null:
			context.services.clear_slime_without_effects(slime)


func record_enemy_death_context(context: RoomRespawnContext, slime: Sprite2D) -> void:
	## Typed room boundary for the three room-owned consequences of a combat
	## death. Combat owns damage, drops, and XP; this owner records room timers,
	## removes the actor from the active room, and queues popcorn policy.
	if context == null or not context.is_valid():
		return
	record_special_enemy_death_context(context, slime)
	context.services.clear_slime_without_effects(slime)
	record_popcorn_enemy_death_context(context, slime)


func save_enemy_runtime_state_context(context: RoomEnemyRuntimeContext) -> RoomEnemyRuntimeResult:
	var result: RoomEnemyRuntimeResult = ROOM_ENEMY_RUNTIME_RESULT_SCRIPT.new()
	if context != null:
		result.room_id = context.room_id
	if context == null or not context.is_valid():
		return result
	var state: Dictionary = room_states.get(context.room_id, {}) as Dictionary
	if context.active_variants.is_empty():
		state.erase("enemy_runtime")
		room_states[context.room_id] = state
		result.status = RoomEnemyRuntimeResult.Status.EMPTY
		return result
	var runtime: Dictionary = {}
	for slot in context.active_variants.size():
		if slot >= context.slimes.size():
			continue
		var slime := context.slimes[slot]
		if slime == null or not is_instance_valid(slime):
			continue
		var combat := context.combat_components[slot] if slot < context.combat_components.size() else null
		var health := context.health_components[slot] if slot < context.health_components.size() else null
		runtime[str(slot)] = {
			"alive": slime.visible and combat != null and not combat.dead and (health == null or health.current_health > 0.0),
			"position": slime.global_position,
			"health": health.current_health if health != null else 0.0,
		}
		result.saved_slots += 1
	state["enemy_runtime"] = runtime
	room_states[context.room_id] = state
	result.status = RoomEnemyRuntimeResult.Status.SAVED
	return result


func record_special_enemy_death(root: Object, slime: Sprite2D) -> void:
	if root is GameplayState:
		record_special_enemy_death_context(enemy_respawn_context(), slime)


func record_special_enemy_death_context(context: RoomRespawnContext, slime: Sprite2D) -> void:
	if context == null or not context.is_valid() or context.room_type != DungeonGraph.ROOM_SPECIAL_ENEMY:
		return
	var slot := context.slimes.find(slime)
	if slot < 0:
		return
	var state: Dictionary = room_states.get(context.room_id, {}) as Dictionary
	var timers := state.get("special_respawn_timers", {}) as Dictionary
	var timer_key := str(slot)
	if not timers.has(timer_key) or float(timers[timer_key]) <= 0.0:
		timers[timer_key] = SPECIAL_ROOM_RESPAWN_DELAY
	state["special_respawn_timers"] = timers
	room_states[context.room_id] = state


func _is_popcorn_respawn_room_context(context: RoomRespawnContext) -> bool:
	# Backtracking popcorn belongs to replayable combat spaces. Flame/Rest,
	# Cloaked/NPC, and Orb rooms are safe presentation or puzzle rooms and must
	# never receive an injected enemy.
	return context.room_type == DungeonGraph.ROOM_START or context.room_type == DungeonGraph.ROOM_COMBAT or context.room_type == DungeonGraph.ROOM_TREASURE or context.room_type == DungeonGraph.ROOM_DOWNSTAIRS or context.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY


func _maybe_add_backtrack_popcorn(_root: Object) -> void:
	# Popcorn is tied to the original encounter slots. Do not inject a new slot
	# merely because the player revisits a completed room; each popcorn slot gets
	# its own 45-second timer when that slot dies.
	return


func _is_popcorn_slot(state: Dictionary, slot: int) -> bool:
	var popcorn_flags := state.get("enemy_popcorn", []) as Array
	return slot >= 0 and slot < popcorn_flags.size() and bool(popcorn_flags[slot])


func _popcorn_type(state: Dictionary, slot: int) -> String:
	var types := state.get("enemy_popcorn_types", []) as Array
	if slot >= 0 and slot < types.size() and not str(types[slot]).is_empty():
		return str(types[slot])
	# Older room states only had the boolean flag. Treat those as room popcorn;
	# elite support is authored by the new encounter data going forward.
	return ROOM_POPCORN if _is_popcorn_slot(state, slot) else ""


func record_popcorn_enemy_death(root: Object, slime: Sprite2D) -> void:
	if root is GameplayState:
		record_popcorn_enemy_death_context(enemy_respawn_context(), slime)


func record_popcorn_enemy_death_context(context: RoomRespawnContext, slime: Sprite2D) -> void:
	if context == null or not context.is_valid() or not _is_popcorn_respawn_room_context(context):
		return
	var state: Dictionary = room_states.get(context.room_id, {}) as Dictionary
	var slot := context.slimes.find(slime)
	if slot < 0 or slot >= (state.get("enemy_variants", []) as Array).size():
		return
	# Ordinary encounters respawn from their complete initial roster. Boss and
	# special encounters only respawn their explicitly-authored support slots.
	if context.room_type in [DungeonGraph.ROOM_DOWNSTAIRS, DungeonGraph.ROOM_SPECIAL_ENEMY] and not _is_popcorn_slot(state, slot):
		return
	var waiting := state.get("popcorn_respawn_waiting", {}) as Dictionary
	if not waiting.has(str(slot)):
		waiting[str(slot)] = {"death_order": waiting.size(), "dead_before_clear": 0.0}
	state["popcorn_respawn_waiting"] = waiting
	room_states[context.room_id] = state


func begin_boss_jump_phase_popcorn(root: Object, boss: Sprite2D, anchor: Vector2) -> int:
	var wave: Array[Sprite2D] = []
	for index in 3:
		var popcorn := _acquire_boss_jump_phase_slot(root)
		if popcorn == null:
			continue
		var actor := popcorn as SlimeActor
		popcorn.set_meta("encounter_scale", 1.0)
		popcorn.set_meta("is_elite", false)
		popcorn.set_meta("is_popcorn", true)
		popcorn.set_meta("popcorn_type", SLIME_BOSS_JUMP_PHASE_POPCORN)
		popcorn.set_meta("boss_jump_phase_popcorn", true)
		if String(popcorn.get_meta("prepared_boss_variant", "")) != String(boss.get("variant")):
			root.call("_configure_slime_variant", popcorn, String(boss.get("variant")))
		var offset := Vector2(-12.0 + float(index) * 12.0, 8.0 if index % 2 == 0 else -8.0)
		var spawn_foot: Vector2 = root.call("_nearest_slime_walkable_point", anchor + offset)
		popcorn.global_position = spawn_foot - ACTOR_FOOT_OFFSET
		root.call("_apply_enemy_room_level", popcorn, maxi(1, _popcorn_enemy_level_for_root(root)))
		var tuning := root.get("slime_tuning") as SlimeTuning
		var maximum := float(root.call("_enemy_max_health", popcorn))
		if actor != null:
			actor.configure_health(maximum, tuning.regen_delay, tuning.regen_interval, tuning.regen_amount)
		var presenter := root.call("_slime_health_presenter", popcorn) as SlimeHealthPresenter
		if presenter != null:
			presenter.display_health = maximum
			presenter.damage_fill_hold_timer = 0.0
		root.call("_prepare_slime_idle_visual", popcorn)
		popcorn.visible = true
		if not (root.get("slimes") as Array[Sprite2D]).has(popcorn): (root.get("slimes") as Array[Sprite2D]).append(popcorn)
		(root.get("actor_sprites") as Array[Sprite2D]).append(popcorn)
		(root.get("collision_sprites") as Array[Sprite2D]).append(popcorn)
		(root.get("depth_sprites") as Array[Sprite2D]).append(popcorn)
		(root.get("occluder_sprites") as Array[Sprite2D]).append(popcorn)
		wave.append(popcorn)
	boss_jump_phase_waves[boss.get_instance_id()] = wave
	return wave.size()


func boss_jump_phase_popcorn_alive(_root: Object, boss: Sprite2D) -> bool:
	var wave := boss_jump_phase_waves.get(boss.get_instance_id(), []) as Array
	for popcorn in wave:
		if popcorn != null and is_instance_valid(popcorn) and not bool(popcorn.get_node("Combat").dead):
			return true
	return false


func clear_boss_jump_phase_popcorn(boss: Sprite2D) -> void:
	if boss != null:
		var wave := boss_jump_phase_waves.get(boss.get_instance_id(), []) as Array
		for popcorn in wave:
			if popcorn is Sprite2D:
				_deactivate_boss_jump_phase_slot(popcorn as Sprite2D)
		boss_jump_phase_waves.erase(boss.get_instance_id())


func initialize_boss_jump_phase_pool(root: Object) -> void:
	if not boss_jump_phase_pool.is_empty():
		return
	var template := root.get("slime_green") as Sprite2D
	if template == null:
		return
	var parent := template.get_parent()
	for index in 3:
		var popcorn := template.duplicate() as Sprite2D
		if popcorn == null:
			continue
		popcorn.name = "BossJumpPhasePool%d" % index
		parent.add_child(popcorn)
		var actor := popcorn as SlimeActor
		if actor != null:
			actor.ensure_components()
		var health := popcorn.get_node_or_null("Health") as HealthComponent
		if health != null:
			health.damaged.connect(Callable(root, "_on_slime_health_damaged").bind(popcorn))
			health.healed.connect(Callable(root, "_on_slime_health_healed").bind(popcorn))
			health.health_changed.connect(Callable(root, "_on_slime_health_changed").bind(popcorn))
		_deactivate_boss_jump_phase_slot(popcorn)
	var slimes := root.get("slimes") as Array[Sprite2D]
	for popcorn in boss_jump_phase_pool:
		slimes.append(popcorn)
	root.call("_build_slime_direction_textures")
	for popcorn in boss_jump_phase_pool:
		slimes.erase(popcorn)
	var hud := root.get("hud_controller") as HudController
	if hud != null:
		for popcorn in boss_jump_phase_pool:
			var frame := popcorn.get_node_or_null("HpOverhead") as Sprite2D
			var fill := popcorn.get_node_or_null("HpOverheadFill") as Sprite2D
			if frame != null and fill != null:
				hud.register_overhead_bar(popcorn, frame, fill, frame.global_position - popcorn.global_position, Callable(hud, "duplicate_fill_sprite"), Callable(root, "_pixel_particle_texture"))


func prepare_boss_jump_phase_pool(root: Object, variant: String) -> void:
	if boss_jump_phase_pool.is_empty():
		return
	var slimes := root.get("slimes") as Array[Sprite2D]
	for popcorn in boss_jump_phase_pool:
		root.call("_configure_slime_variant", popcorn, variant)
		popcorn.set_meta("encounter_scale", 1.0)
		popcorn.set_meta("prepared_boss_variant", variant)
		slimes.append(popcorn)
	root.call("_build_slime_direction_textures")
	root.call("_assign_slime_attack_frames")
	root.call("_assign_slime_shocked_frames")
	root.call("_assign_slime_spawn_frames")
	for popcorn in boss_jump_phase_pool:
		slimes.erase(popcorn)


func prepare_boss_jump_phase_pool_context(services: RoomEnemySpawnServices, variant: String) -> void:
	if services == null or boss_jump_phase_pool.is_empty():
		return
	for popcorn in boss_jump_phase_pool:
		services.configure_slime_variant(popcorn, variant)
		popcorn.set_meta("encounter_scale", 1.0)
		popcorn.set_meta("prepared_boss_variant", variant)
		services.slimes.append(popcorn)
	services.prepare_enemy_visuals_direct()
	for popcorn in boss_jump_phase_pool:
		services.slimes.erase(popcorn)


func _acquire_boss_jump_phase_slot(root: Object) -> Sprite2D:
	if boss_jump_phase_pool.is_empty():
		return null
	var popcorn: Sprite2D = boss_jump_phase_pool.pop_back() as Sprite2D
	var actor := popcorn as SlimeActor
	if actor != null:
		actor.reset_runtime_state(popcorn.position, root.call("_nearest_slime_walkable_point", root.call("_actor_foot", popcorn)), 0.5, 0.2, 0.0, 0.5)
	return popcorn


func _deactivate_boss_jump_phase_slot(popcorn: Sprite2D) -> void:
	if popcorn == null or not is_instance_valid(popcorn):
		return
	var combat := popcorn.get_node_or_null("Combat") as SlimeCombatComponent
	if combat != null:
		combat.clear_boss_jump_phase()
		combat.active = false
		combat.dead = true
	var spawn := popcorn.get_node_or_null("Spawn") as Node
	if spawn != null:
		spawn.call("cancel")
	popcorn.visible = false
	popcorn.self_modulate.a = 1.0
	popcorn.set_meta("boss_jump_phase_popcorn", false)
	popcorn.set_meta("is_elite", false)
	popcorn.set_meta("boss_airborne", false)
	for collection_name in ["actor_sprites", "collision_sprites", "depth_sprites", "occluder_sprites"]:
		var collection: Variant = get_parent().get(collection_name) if get_parent() != null else null
		if collection is Array:
			(collection as Array).erase(popcorn)
	if not boss_jump_phase_pool.has(popcorn):
		boss_jump_phase_pool.append(popcorn)


func _ensure_special_enemy_respawn_timers(state: Dictionary) -> void:
	var timers := state.get("special_respawn_timers", {}) as Dictionary
	var active_variants := state.get("enemy_variants", []) as Array
	var runtime_states := state.get("enemy_runtime", {}) as Dictionary
	for slot in active_variants.size():
		var timer_key := str(slot)
		var runtime_entry := runtime_states.get(timer_key, runtime_states.get(slot, {})) as Dictionary
		var enemy_alive := bool(runtime_entry.get("alive", false))
		# Re-entry must not put a living special-room enemy into the respawn
		# queue. Clear any stale timer if a saved live runtime entry wins; only
		# defeated/unrecorded slots need a timer.
		if enemy_alive:
			timers.erase(timer_key)
		elif not timers.has(timer_key):
			timers[timer_key] = SPECIAL_ROOM_RESPAWN_DELAY
	state["special_respawn_timers"] = timers


func schedule_special_enemy_respawns(root: Object) -> void:
	if root is GameplayState:
		schedule_special_enemy_respawns_context(enemy_respawn_context())


func schedule_special_enemy_respawns_context(context: RoomRespawnContext) -> void:
	if context == null or not context.is_valid() or context.room_type != DungeonGraph.ROOM_SPECIAL_ENEMY:
		return
	var state: Dictionary = room_states.get(context.room_id, {}) as Dictionary
	_ensure_special_enemy_respawn_timers(state)
	room_states[context.room_id] = state


func update_respawns(root: Object, delta: float) -> void:
	if root is GameplayState:
		update_respawns_context(enemy_respawn_context(), delta)


func update_respawns_context(context: RoomRespawnContext, delta: float) -> void:
	if context == null or not context.is_valid():
		return
	update_special_enemy_respawns_context(context, delta)
	update_popcorn_respawns_context(context, delta)


func _is_special_room_state_context(context: RoomRespawnContext, room_id: StringName, state: Dictionary) -> bool:
	var graph: DungeonGraph = context.services.dungeon_graph
	var room := graph.get_room(room_id) if graph != null else null
	if room != null:
		return room.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY
	return StringName(state.get("room_type", &"")) == DungeonGraph.ROOM_SPECIAL_ENEMY


func update_special_enemy_respawns(root: Object, delta: float) -> void:
	if root is GameplayState:
		update_special_enemy_respawns_context(enemy_respawn_context(), delta)



func update_special_enemy_respawns_context(context: RoomRespawnContext, delta: float) -> void:
	if context == null or not context.is_valid():
		return
	var services := context.services
	var active_room_id: StringName = context.room_id
	var current_state: Dictionary = {}
	var ready_slots: Array[int] = []
	for room_key in room_states.keys():
		var room_id: StringName = StringName(room_key)
		var state := room_states.get(room_key, {}) as Dictionary
		if not _is_special_room_state_context(context, room_id, state) or not bool(state.get("special_clear_earned", false)):
			continue
		var timers := state.get("special_respawn_timers", {}) as Dictionary
		if timers.is_empty() and bool(state.get("finished", false)):
			_ensure_special_enemy_respawn_timers(state)
			timers = state.get("special_respawn_timers", {}) as Dictionary
		if timers.is_empty():
			room_states[room_key] = state
			continue
		var room_is_current: bool = room_id == active_room_id and context.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY
		for timer_key in timers.keys():
			var remaining := maxf(0.0, float(timers[timer_key]) - maxf(delta, 0.0))
			timers[timer_key] = remaining
			if room_is_current and remaining <= 0.0 and not _special_room_hides_enemies_context(context, state, room_id):
				ready_slots.append(int(timer_key))
		state["special_respawn_timers"] = timers
		room_states[room_key] = state
		if room_is_current:
			current_state = state
	if ready_slots.is_empty():
		return
	var current_room_state: Dictionary = current_state
	var current_room_timers: Dictionary = current_room_state.get("special_respawn_timers", {}) as Dictionary
	_prepare_enemy_slot_visuals_context(context, current_room_state)
	var player_foot: Vector2 = context.player_foot
	var chest_rect: Rect2 = context.chest_rect
	var occupied: Array[Vector2] = []
	for slime in context.slimes:
		if slime.visible and not services.is_slime_dead(slime):
			occupied.append(services.actor_foot(slime))
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = int(current_room_state.get("enemy_spawn_seed", String(context.room_id).hash() + 303)) + 1771
	var did_respawn := false
	for slot in ready_slots:
		var timer_key := str(slot)
		if _spawn_enemy_slot_context(context, current_room_state, slot, occupied, layout_rng, player_foot, chest_rect, true):
			current_room_timers.erase(timer_key)
			did_respawn = true
		else:
			# Keep retrying if a temporary actor/wall arrangement prevents a valid
			# spawn. This does not reset the original staggered schedule.
			current_room_timers[timer_key] = 0.25
	current_room_state["special_respawn_timers"] = current_room_timers
	if did_respawn:
		_play_popcorn_spawn_sound_context(context)
		current_room_state["finished"] = false
		services.set_door_active.call(false)
		services.set_entrance_open.call(true)
		services.build_depth_lists.call()
	room_states[context.room_id] = current_room_state


func update_popcorn_respawns(root: Object, delta: float) -> void:
	if root is GameplayState:
		update_popcorn_respawns_context(enemy_respawn_context(), delta)



func update_popcorn_respawns_context(context: RoomRespawnContext, delta: float) -> void:
	if context == null or not context.is_valid():
		return
	# Advance every room's clocks, including rooms outside the active scene. A
	# ready off-room slot remains at zero until that room is visited again.
	var step := maxf(delta, 0.0)
	for room_key in room_states.keys():
		var clock_state := room_states.get(room_key, {}) as Dictionary
		var waiting := clock_state.get("popcorn_respawn_waiting", {}) as Dictionary
		if not waiting.is_empty() and not bool(clock_state.get("finished", false)):
			for waiting_key in waiting.keys():
				var waiting_entry := waiting[waiting_key] as Dictionary
				waiting_entry["dead_before_clear"] = float(waiting_entry.get("dead_before_clear", 0.0)) + step
				waiting[waiting_key] = waiting_entry
			clock_state["popcorn_respawn_waiting"] = waiting
		var clock_pending := clock_state.get("popcorn_respawn_slots", {}) as Dictionary
		if clock_pending.is_empty():
			room_states[room_key] = clock_state
			continue
		for clock_key in clock_pending.keys():
			clock_pending[clock_key] = maxf(0.0, float(clock_pending[clock_key]) - step)
		clock_state["popcorn_respawn_slots"] = clock_pending
		room_states[room_key] = clock_state
	if not _is_popcorn_respawn_room_context(context):
		return
	var room_id: StringName = context.room_id
	var state: Dictionary = room_states.get(room_id, {}) as Dictionary
	var pending := state.get("popcorn_respawn_slots", {}) as Dictionary
	if pending.is_empty():
		if state.has("popcorn_respawn_slots"):
			state.erase("popcorn_respawn_slots")
			room_states[room_id] = state
		return
	var ready_slots: Array[int] = []
	var active_variants := state.get("enemy_variants", []) as Array
	for pending_key in pending.keys():
		var slot := int(pending_key)
		if slot < 0 or slot >= active_variants.size():
			pending.erase(pending_key)
			continue
		if float(pending[pending_key]) <= 0.0:
			ready_slots.append(slot)
	if ready_slots.is_empty():
		if pending.is_empty():
			state.erase("popcorn_respawn_slots")
		else:
			state["popcorn_respawn_slots"] = pending
		room_states[room_id] = state
		return

	_prepare_enemy_slot_visuals_context(context, state)
	var services := context.services
	var player_foot: Vector2 = context.player_foot
	var chest_rect: Rect2 = context.chest_rect
	var occupied: Array[Vector2] = []
	for slime in context.slimes:
		if slime.visible and not services.is_slime_dead(slime):
			occupied.append(services.actor_foot(slime))
	var respawn_serial := int(state.get("popcorn_respawn_serial", 0)) + 1
	state["popcorn_respawn_serial"] = respawn_serial
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = int(state.get("enemy_spawn_seed", String(room_id).hash() + 303)) + 1771 + respawn_serial * 7919
	var spawn_positions := state.get("enemy_spawn_positions", {}) as Dictionary
	var did_respawn := false
	for slot in ready_slots:
		var timer_key := str(slot)
		if slot < 0 or slot >= context.slimes.size():
			pending.erase(timer_key)
			continue
		var slime := context.slimes[slot]
		if slime.visible and not services.is_slime_dead(slime):
			pending.erase(timer_key)
			continue
		# A defeated support slot gets a fresh position when it returns. The
		# spawn helper still validates it against walls, the player, and all
		# currently active actors.
		spawn_positions.erase(slot)
		spawn_positions.erase(timer_key)
		if _spawn_enemy_slot_context(context, state, slot, occupied, layout_rng, player_foot, chest_rect, true):
			pending.erase(timer_key)
			did_respawn = true
		else:
			pending[timer_key] = POPCORN_RESPAWN_RETRY_DELAY
	state["enemy_spawn_positions"] = spawn_positions
	if pending.is_empty():
		state.erase("popcorn_respawn_slots")
	else:
		state["popcorn_respawn_slots"] = pending
	if did_respawn:
		_play_popcorn_spawn_sound_context(context)
		state["finished"] = false
		services.set_door_active.call(false)
		services.set_entrance_open.call(false if context.room_type == DungeonGraph.ROOM_DOWNSTAIRS else true)
		services.build_depth_lists.call()
	room_states[room_id] = state


func _play_popcorn_spawn_sound_context(context: RoomRespawnContext) -> void:
	var pitch := 0.98
	if context.services.rng != null:
		pitch += context.services.rng.randf_range(-0.03, 0.03)
	context.services.play_sound.call("slime_spawn", -6.0, pitch)


func reset_chest_for_room(root: Object, show_chest: bool = true) -> void:
	var rest_fire := root.get("rest_fire") as Sprite2D; var demon := root.get("cloaked_demon") as Sprite2D; var chest := root.get("chest") as Sprite2D
	rest_fire.visible = false; var firepit := rest_fire.get_node_or_null("Firepit") as Sprite2D; if firepit != null: firepit.visible = false; (root.get("collision_sprites") as Array[Sprite2D]).erase(firepit); demon.visible = false; chest.position = _chest_position_for_room(root); chest.flip_h = false; chest.texture = root.get("chest_gray_texture"); chest.visible = show_chest; chest.self_modulate = Color.WHITE; root.set("chest_unlocked", false); root.set("chest_claimed", false); root.set("chest_evaporated", false); root.set("chest_collect_flash_timer", 0.0); root.call("_set_door_active", false)
	var unlock_overlay := root.get("chest_unlock_overlay") as Sprite2D; if unlock_overlay != null: unlock_overlay.queue_free(); root.set("chest_unlock_overlay", null)
	var flash_overlay := root.get("chest_flash_overlay") as Sprite2D; if flash_overlay != null: flash_overlay.queue_free(); root.set("chest_flash_overlay", null)
	var collision := root.get("collision_sprites") as Array[Sprite2D]
	if show_chest:
		if not collision.has(chest): collision.append(chest)
		if not (root.get("depth_sprites") as Array[Sprite2D]).has(chest): (root.get("depth_sprites") as Array[Sprite2D]).append(chest)
		if not (root.get("occluder_sprites") as Array[Sprite2D]).has(chest): (root.get("occluder_sprites") as Array[Sprite2D]).append(chest)
	else:
		collision.erase(chest); (root.get("depth_sprites") as Array[Sprite2D]).erase(chest); (root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)
	(root.get("occlusion_renderer") as OcclusionRenderer).sprite_images[chest] = (root.get("occlusion_renderer") as OcclusionRenderer).cached_texture_image(chest.texture)


func _chest_position_for_room(root: Object) -> Vector2:
	var default_position: Vector2 = root.get("chest_start_position")
	var graph := root.get("dungeon_graph") as DungeonGraph
	var room_id: StringName = StringName(root.get("current_room_id"))
	var room: DungeonGraph.RoomRecord = graph.get_room(room_id) if graph != null else null
	if room != null and room.chest_position != Vector2.ZERO:
		return room.chest_position
	return default_position


func hide_chest_presentation(root: Object) -> void:
	var chest := root.get("chest") as Sprite2D
	if chest == null:
		return
	chest.visible = false
	(root.get("collision_sprites") as Array[Sprite2D]).erase(chest)
	(root.get("depth_sprites") as Array[Sprite2D]).erase(chest)
	(root.get("occluder_sprites") as Array[Sprite2D]).erase(chest)


func _special_room_hides_enemies_context(context: RoomEnemyContext, state: Dictionary, room_id: StringName = &"") -> bool:
	if not bool(state.get("special_clear_earned", false)):
		return false
	var graph: DungeonGraph = context.services.dungeon_graph
	var target_room_id: StringName = room_id if not room_id.is_empty() else context.room_id
	var room := graph.get_room(target_room_id) if graph != null else null
	if room == null or room.special_respawn_required_color.is_empty():
		return false
	var map_controller: DungeonMapController = context.services.dungeon_map_controller
	var active_color: StringName = map_controller.current_color() if map_controller != null else &"neutral"
	return active_color == room.special_respawn_required_color


func _prepare_enemy_slot_visuals(root: Object, state: Dictionary) -> void:
	if root is GameplayState:
		_prepare_enemy_slot_visuals_context(enemy_spawn_context(), state)


func _prepare_enemy_slot_visuals_context(context: RoomEnemyContext, state: Dictionary) -> void:
	if context == null or not context.is_valid():
		return
	var services := context.services
	var slimes := context.slimes
	var active_variants := state.get("enemy_variants", []) as Array
	var active_ambush := state.get("enemy_ambush", []) as Array
	var active_scales := state.get("enemy_scales", []) as Array
	var active_elites := state.get("enemy_elite", []) as Array
	var signature := "%s|%s|%s|%s" % [active_variants, active_scales, active_ambush, active_elites]
	for slot in active_variants.size():
		if slot >= slimes.size():
			break
		var ambush_enabled := slot < active_ambush.size() and bool(active_ambush[slot])
		services.configure_slime_variant(slimes[slot], String(active_variants[slot]))
		slimes[slot].set_meta("encounter_scale", float(active_scales[slot]) if slot < active_scales.size() else 1.0)
		slimes[slot].set_meta("is_elite", _is_elite_enemy_slot(state, slot))
		services.configure_slime_ambush(slimes[slot], String(active_variants[slot]) == "purple" and ambush_enabled)
	if signature == _enemy_visual_preparation_signature:
		return
	_enemy_visual_preparation_signature = signature
	services.prepare_enemy_visuals_direct()
	if not active_variants.is_empty() and not active_scales.is_empty() and float(active_scales[0]) > 1.0:
		services.prepare_boss_jump_phase_pool.call(services, String(active_variants[0]))


func _is_elite_enemy_slot(state: Dictionary, slot: int) -> bool:
	var active_elites := state.get("enemy_elite", []) as Array
	if slot >= 0 and slot < active_elites.size():
		return bool(active_elites[slot])
	if StringName(state.get("encounter_tier", DungeonGraph.ENCOUNTER_NORMAL)) != DungeonGraph.ENCOUNTER_ELITE:
		return false
	var popcorn_flags := state.get("enemy_popcorn", []) as Array
	return not (slot < popcorn_flags.size() and bool(popcorn_flags[slot]))


func _spawn_enemy_slot(root: Object, state: Dictionary, slime_index: int, occupied: Array[Vector2], layout_rng: RandomNumberGenerator, player_foot: Vector2, chest_rect: Rect2, animate_spawn: bool = false) -> bool:
	if root is GameplayState:
		return _spawn_enemy_slot_context(enemy_spawn_context(), state, slime_index, occupied, layout_rng, player_foot, chest_rect, animate_spawn)
	return false


func _spawn_enemy_slot_context(context: RoomEnemyContext, state: Dictionary, slime_index: int, occupied: Array[Vector2], layout_rng: RandomNumberGenerator, player_foot: Vector2, chest_rect: Rect2, animate_spawn: bool = false) -> bool:
	if context == null or not context.is_valid():
		return false
	var services := context.services
	var slimes := context.slimes
	if slime_index < 0 or slime_index >= slimes.size():
		return false
	var active_variants := state.get("enemy_variants", []) as Array
	var active_levels := state.get("enemy_levels", []) as Array
	if slime_index >= active_variants.size() or slime_index >= active_levels.size():
		return false
	var active_scales := state.get("enemy_scales", []) as Array
	var spawn_positions: Dictionary
	if state.has("enemy_spawn_positions"):
		spawn_positions = state["enemy_spawn_positions"] as Dictionary
	else:
		spawn_positions = {}
		state["enemy_spawn_positions"] = spawn_positions
	var slime := slimes[slime_index]
	var popcorn_flags := state.get("enemy_popcorn", []) as Array
	var is_popcorn := slime_index < popcorn_flags.size() and bool(popcorn_flags[slime_index])
	var popcorn_type := _popcorn_type(state, slime_index)
	slime.set_meta("is_elite", _is_elite_enemy_slot(state, slime_index))
	var spawn_level := int(active_levels[slime_index])
	if is_popcorn:
		# Recalculate on every spawn so a level-up during a run also keeps a
		# respawning fodder slime five levels under the player.
		spawn_level = _popcorn_enemy_level_for_profile(services.player_profile)
		active_levels[slime_index] = spawn_level
	slime.set_meta("is_popcorn", is_popcorn)
	slime.set_meta("popcorn_type", popcorn_type)
	var tuning: SlimeTuning = services.slime_tuning
	var rng: RandomNumberGenerator = services.rng
	var actor_sprites: Array[Sprite2D] = services.actor_sprites
	var collision: Array[Sprite2D] = services.collision_sprites
	var depth_sprites: Array[Sprite2D] = services.depth_sprites
	var occluder_sprites: Array[Sprite2D] = services.occluder_sprites
	var encounter_scale := float(active_scales[slime_index]) if slime_index < active_scales.size() else 1.0
	if encounter_scale > 1.0:
		_apply_authored_boss_geometry(slime)
	slime.set_meta("encounter_scale", encounter_scale)
	services.set_actor_visual_scale.call(slime, Vector2.ONE)
	services.apply_actor_scale.call(slime, false)
	var has_saved_position := spawn_positions.has(slime_index) or spawn_positions.has(str(slime_index))
	var spawn_position: Vector2 = spawn_positions.get(slime_index, spawn_positions.get(str(slime_index), Vector2.ZERO))
	if not has_saved_position or not _valid_enemy_spawn_foot_context(context, slime, spawn_position + ACTOR_FOOT_OFFSET, player_foot, chest_rect, occupied):
		spawn_position = _choose_enemy_spawn_position_context(context, slime, layout_rng, occupied)
		spawn_positions[slime_index] = spawn_position
	var spawn_foot := spawn_position + ACTOR_FOOT_OFFSET
	if not _valid_enemy_spawn_foot_context(context, slime, spawn_foot, player_foot, chest_rect, occupied):
		spawn_positions.erase(slime_index)
		spawn_positions.erase(str(slime_index))
		slime.visible = false
		var failed_runtime := state.get("enemy_runtime", {}) as Dictionary
		failed_runtime[str(slime_index)] = {"alive": false, "position": slime.global_position, "health": 0.0}
		state["enemy_runtime"] = failed_runtime
		actor_sprites.erase(slime)
		collision.erase(slime)
		depth_sprites.erase(slime)
		occluder_sprites.erase(slime)
		return false
	occupied.append(spawn_foot)
	var actor := slime as SlimeActor
	var brain: SlimeBrain = services.slime_brain(slime)
	# The spawn solver returns a world-space position because it validates against
	# the world-space floor outline. Actors are children of the offset Actors
	# node, so assign through global_position instead of treating that point as a
	# local coordinate (the old path double-applied the 16:9 horizontal offset).
	slime.global_position = spawn_position
	if brain != null:
		brain.start_position = slime.position
	# Keep the slot hidden until its encounter variant, animation state, base
	# texture, and floor shadow have all been resolved. This closes the one-frame
	# window where a reused slot could briefly show its scene-default artwork
	# before the recolored spawn frames take over.
	slime.visible = false
	slime.flip_h = false
	services.apply_enemy_room_level.call(slime, spawn_level)
	var max_health := float(services.enemy_max_health.call(slime))
	if actor != null:
		actor.configure_health(max_health, tuning.regen_delay, tuning.regen_interval, tuning.regen_amount)
		actor.reset_runtime_state(slime.position, slime.position, rng.randf_range(tuning.repath_min, tuning.repath_max), rng.randf_range(tuning.hold_min, tuning.hold_max), 0.0, rng.randf_range(0.2, 0.6))
	var presenter: SlimeHealthPresenter = services.slime_health_presenter(slime)
	if presenter == null:
		return false
	presenter.display_health = max_health
	presenter.damage_fill_hold_timer = 0.0
	services.prepare_slime_idle_visual.call(slime)
	slime.visible = true
	slime.set_meta("movement_speed_multiplier", rng.randf_range(0.75, 1.20))
	# Bosses use the same authored attack timing as regular slimes. Their size,
	# health pool, and jump phase provide the distinction; an extra slowdown here
	# made the boss spend too long approaching without committing to attacks.
	slime.set_meta("attack_speed_multiplier", rng.randf_range(0.85, 1.20))
	services.set_actor_visual_scale.call(slime, Vector2.ONE)
	services.apply_actor_scale.call(slime, false)
	if not actor_sprites.has(slime):
		actor_sprites.append(slime)
	if not collision.has(slime):
		collision.append(slime)
	if not depth_sprites.has(slime):
		depth_sprites.append(slime)
	if not occluder_sprites.has(slime):
		occluder_sprites.append(slime)
	if animate_spawn and services.begin_slime_spawn.call(slime):
		# The actor remains rendered and depth-sorted during the intro, but it is
		# excluded from collisions and all combat queries until the final frame.
		collision.erase(slime)
	return true


func reset_slimes_for_room(root: Object) -> RoomSpawnResult:
	if root is GameplayState:
		return reset_slimes_for_room_context(enemy_spawn_context())
	return ROOM_SPAWN_RESULT_SCRIPT.new() as RoomSpawnResult


func reset_slimes_for_room_context(context: RoomSpawnContext) -> RoomSpawnResult:
	var result := ROOM_SPAWN_RESULT_SCRIPT.new() as RoomSpawnResult
	if context == null or not context.is_valid():
		result.reject(RoomSpawnResult.Status.MISSING_ROOT)
		return result
	var services := context.services
	result.room_id = context.room_id
	result.room_type = context.room_type
	services.effects_spawner.clear_slime_notices()
	for slime in context.slimes:
		services.clear_slime_without_effects(slime)
	# Hub, rest, NPC, puzzle, and orb rooms are intentionally enemy-free. Keep
	# the cleanup above, but do not interpret stale room-state data as an enemy
	# encounter when one of those rooms is entered.
	if context.room_type != DungeonGraph.ROOM_COMBAT and context.room_type != DungeonGraph.ROOM_SPECIAL_ENEMY and context.room_type != DungeonGraph.ROOM_TREASURE and context.room_type != DungeonGraph.ROOM_DOWNSTAIRS:
		last_spawn_result = result
		return result
	var state := context.state
	var active_variants := state.get("enemy_variants", []) as Array
	result.requested_slots = active_variants.size()
	var runtime_states := state.get("enemy_runtime", {}) as Dictionary
	var first_entry := not bool(state.get("enemy_spawned", false))
	result.first_entry = first_entry
	var spawn_positions: Dictionary
	if state.has("enemy_spawn_positions"):
		spawn_positions = state["enemy_spawn_positions"] as Dictionary
	else:
		spawn_positions = {}
		state["enemy_spawn_positions"] = spawn_positions
	var spawn_seed := int(state.get("enemy_spawn_seed", String(context.room_id).hash() + 303))
	var layout_rng := RandomNumberGenerator.new()
	layout_rng.seed = spawn_seed
	_prepare_enemy_slot_visuals_context(context, state)
	var player_foot: Vector2 = context.player_foot
	var chest_rect: Rect2 = context.chest_rect
	var occupied: Array[Vector2] = []
	var special_timers := state.get("special_respawn_timers", {}) as Dictionary
	var hide_special_enemies := _special_room_hides_enemies_context(context, state)
	var spawned_slots := 0
	var animated_spawn_started := false
	var spawn_audio_played := false
	# Legacy saves may contain the removed revisit-injection flag. It must never
	# create an immediate replacement on room entry.
	state.erase("backtrack_popcorn_pending")
	var backtrack_popcorn_pending := false
	var backtrack_spawn_started := false
	for slime_index in active_variants.size():
		if slime_index >= context.slimes.size():
			result.record_failure(slime_index)
			continue
		var timer_key := str(slime_index)
		if hide_special_enemies or (context.room_type == DungeonGraph.ROOM_SPECIAL_ENEMY and special_timers.has(timer_key) and float(special_timers[timer_key]) > 0.0):
			continue
		var has_runtime_entry := runtime_states.has(timer_key) or runtime_states.has(slime_index)
		var runtime_entry := runtime_states.get(timer_key, runtime_states.get(slime_index, {})) as Dictionary
		if has_runtime_entry and not bool(runtime_entry.get("alive", false)):
			continue
		if has_runtime_entry and runtime_entry.get("position") is Vector2:
			spawn_positions[slime_index] = runtime_entry["position"]
		var animate_spawn := (first_entry and not has_runtime_entry) or (backtrack_popcorn_pending and not has_runtime_entry and slime_index == active_variants.size() - 1)
		if _spawn_enemy_slot_context(context, state, slime_index, occupied, layout_rng, player_foot, chest_rect, animate_spawn):
			var spawn_started: bool = animate_spawn and services.is_slime_spawn_locked(context.slimes[slime_index])
			result.record_spawn(slime_index, spawn_started)
			spawned_slots += 1
			if has_runtime_entry:
				services.restore_enemy_health(context.slimes[slime_index], runtime_entry)
			if animate_spawn and services.is_slime_spawn_locked(context.slimes[slime_index]):
				backtrack_spawn_started = backtrack_popcorn_pending
				animated_spawn_started = true
				if not spawn_audio_played:
					var spawn_rng := services.rng
					services.play_sound.call("slime_spawn", -6.0, 0.98 + spawn_rng.randf_range(-0.03, 0.03))
					spawn_audio_played = true
		else:
			result.record_failure(slime_index)
	if first_entry and spawned_slots > 0:
		state["enemy_spawned"] = true
	if backtrack_spawn_started:
		state.erase("backtrack_popcorn_pending")
	state["enemy_spawn_positions"] = spawn_positions
	state["enemy_spawn_seed"] = spawn_seed
	room_states[context.room_id] = state
	if services.run_state != null and services.run_state.active:
		services.run_state.register_room_enemies(context.room_id, spawned_slots)
	if context.room_type == DungeonGraph.ROOM_DOWNSTAIRS and not animated_spawn_started:
		for slime in context.slimes:
			if slime.visible:
				services.trigger_slime_notice.call(slime)
	last_spawn_result = result
	return result


func rebase_enemy_spawn_positions(delta: Vector2) -> void:
	# Spawn positions are stored in world space because walkability, sockets, and
	# collision geometry are all queried in world space. When the wide display
	# mode moves Map and Actors together, keep saved room positions in that same
	# space so revisiting a room does not resurrect enemies at the old 3:2 edge.
	if delta == Vector2.ZERO:
		return
	for room_id in room_states.keys():
		var state := room_states[room_id] as Dictionary
		if state == null:
			continue
		var positions := state.get("enemy_spawn_positions", {}) as Dictionary
		for slot in positions.keys():
			var saved_position: Variant = positions[slot]
			if saved_position is Vector2:
				positions[slot] = (saved_position as Vector2) + delta
		if not positions.is_empty():
			state["enemy_spawn_positions"] = positions
			room_states[room_id] = state


func _get_boss_slime_authoring_template() -> Node:
	if boss_slime_authoring_template != null and is_instance_valid(boss_slime_authoring_template):
		return boss_slime_authoring_template
	if boss_slime_authoring_scene == null:
		boss_slime_authoring_scene = load(BOSS_SLIME_AUTHORING_SCENE) as PackedScene
	if boss_slime_authoring_scene == null:
		push_error("Boss slime authoring scene could not be loaded: %s" % BOSS_SLIME_AUTHORING_SCENE)
		return null
	boss_slime_authoring_template = boss_slime_authoring_scene.instantiate()
	return boss_slime_authoring_template


func _apply_authored_boss_geometry(slime: Sprite2D) -> void:
	var authored := _get_boss_slime_authoring_template()
	if authored == null:
		return
	var geometry_names := [&"CollisionGuide", &"CollisionPolygon", &"BodyHitbox", &"AttackGuideL", &"AttackGuideR"]
	for geometry_name in geometry_names:
		var source := authored.get_node_or_null(NodePath(geometry_name)) as Node
		if source == null:
			continue
		var existing := slime.get_node_or_null(NodePath(geometry_name)) as Node
		if existing != null:
			existing.free()
		var clone := source.duplicate() as Node
		if clone == null:
			continue
		slime.add_child(clone)
		# The authoring scene intentionally keeps these geometry overlays visible
		# for level-design work. They are collision data at runtime, not gameplay
		# UI, so cloned boss guides must start hidden as well.
		if clone is CanvasItem:
			(clone as CanvasItem).visible = false
		if clone is Node2D:
			clone.set_meta("authored_position", (clone as Node2D).position)


func _choose_enemy_spawn_position_context(context: RoomEnemyContext, slime: Sprite2D, layout_rng: RandomNumberGenerator, occupied: Array[Vector2]) -> Vector2:
	if context == null:
		return Vector2(INF, INF)
	return ROOM_ENEMY_PLACEMENT_SCRIPT.choose_spawn_position(context.services.walkable_area, slime, layout_rng, occupied, context.player_foot, context.chest_rect, context.services.actor_foot_offset, active_door_sockets, active_entrance_sockets, ENEMY_MIN_PLAYER_DISTANCE, ENEMY_MIN_SPAWN_DISTANCE, ENEMY_MIN_SOCKET_DISTANCE)


func _valid_enemy_spawn_foot_context(context: RoomEnemyContext, slime: Sprite2D, candidate_foot: Vector2, player_foot: Vector2, chest_rect: Rect2, occupied: Array[Vector2]) -> bool:
	if context == null:
		return false
	return ROOM_ENEMY_PLACEMENT_SCRIPT.valid_spawn_foot(slime, candidate_foot, player_foot, chest_rect, occupied, context.services.walkable_area, context.services.actor_foot_offset, active_door_sockets, active_entrance_sockets, ENEMY_MIN_PLAYER_DISTANCE, ENEMY_MIN_SPAWN_DISTANCE, ENEMY_MIN_SOCKET_DISTANCE)


func apply_room_geometry(_root: Object = null) -> void:
	if geometry_controller != null:
		geometry_controller.apply_room_geometry(current_room_type)


func apply_authored_boss_room_geometry(_root: Object = null) -> void:
	if geometry_controller != null:
		geometry_controller.apply_authored_boss_room_geometry()


func capture_normal_room_geometry(_root: Object = null) -> void:
	if geometry_controller != null:
		geometry_controller.capture_normal_room_geometry()


func restore_normal_room_geometry(_root: Object = null) -> void:
	if geometry_controller != null:
		geometry_controller.restore_normal_room_geometry()


func configure_large_room_camera(_root: Object, enabled: bool) -> void:
	if geometry_controller != null:
		geometry_controller.configure_large_room_camera(enabled)


func update_large_room_camera(_root: Object = null) -> void:
	if geometry_controller != null:
		geometry_controller.update_large_room_camera()


func _mark_finished(root: Object) -> void:
	var room_id: StringName = root.get("current_room_id")
	mark_cleared_context(_room_clear_context_from_root(root))


func _room_clear_context_from_root(root: Object) -> RoomClearContext:
	var room_id: StringName = StringName(root.get("current_room_id"))
	var graph := root.get("dungeon_graph") as DungeonGraph
	var room := graph.get_room(room_id) if graph != null else null
	return ROOM_CLEAR_CONTEXT_SCRIPT.new(room_id, room)
