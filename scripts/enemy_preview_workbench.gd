@tool
extends Node2D

## Factory-backed, presentation-only preview for one authored enemy variant at a time.
## Animation frames come from the same visual component and frame library as
## gameplay; this node never starts enemy AI, combat, timers, or save services.

enum PreviewState { IDLE, MOVE, ATTACK, SHOCKED, SPAWN, BOSS_JUMP, BOSS_SLAM }
enum PreviewActorSize { REGULAR, BOSS }
enum GeometryEditTarget { NONE, COLLISION_SHAPE, BODY_HITBOX, COLLISION_GUIDE, ATTACK_LEFT, ATTACK_RIGHT }

const PREVIEW_STATE_LABELS := ["Idle", "Move", "Attack", "Shocked", "Spawn", "Boss Jump", "Boss Slam"]
const PREVIEW_CANVAS_SIZE := Vector2(240.0, 160.0)
const BASE_PREVIEW_SCALE := 4.0
const BOSS_PREVIEW_SCALE := 2.0
const DESIGN_FRAME_TIME := 0.08
const DESIGN_MOTION_FRAMES := 8
const NORMAL_FRAME_SIZE := Vector2i(16, 16)
const IDLE_BREATH_WIDTH := 0.05
const IDLE_BREATH_HEIGHT := 0.04
const GEOMETRY_SNAP := 0.5
const GEOMETRY_HANDLE_HIT_RADIUS := 8.0
const MAX_GEOMETRY_UNDO_STEPS := 64
const PALETTE_DISPLAY_NAMES := {
	"grey": "Gray",
	"red": "Red",
	"blue": "Blue",
	"yellow": "Yellow",
	"green": "Green",
	"purple": "Purple",
	"orange": "Orange",
	"aquamarine": "Aquamarine",
}
const DEFINITION_EDITOR_PROPERTIES := [
	"display_name", "element", "damage_type", "appearance_palette",
	"vitality", "strength", "defense", "agility", "intelligence", "mind",
	"vitality_growth", "strength_growth", "defense_growth", "agility_growth",
	"intelligence_growth", "mind_growth", "spawn_role", "spawn_weight",
	"minimum_rank", "matchup_weight", "preferred_weight", "allow_preferred",
]

const ElementCatalogScript = preload("res://scripts/element_catalog.gd")
const SlimeVisualComponentScript = preload("res://scripts/slime_visual_component.gd")
const SpriteFrameLibraryScript = preload("res://scripts/sprite_frame_library.gd")
const SlimeVariantCatalogScript = preload("res://scripts/slime_variant_catalog.gd")

@export_group("Enemy Selection")
## Selects an enemy family by display label. The dropdown currently contains Slime once.
@export var enemy: String:
	get:
		return _type_picker_label_for_id(_selected_enemy_type_id)
	set(value):
		_set_enemy_type(_enemy_type_id_for_display_name(value))

## Selects a concrete authored variant of the selected enemy family.
@export var variant: String:
	get:
		return _variant_picker_label_for_id(_enemy_variant_id)
	set(value):
		_set_enemy_variant(_variant_id_for_picker_label(_selected_enemy_type_id, value))

## Stable-ID compatibility property for preview commands and existing scenes.
## The Inspector exposes the friendly Enemy and Variant controls above.
@export var enemy_id: StringName:
	get:
		return _enemy_variant_id
	set(value):
		_set_enemy_variant(value)

@export var selected_enemy_name: String:
	get:
		return _variant_picker_label_for_id(definition.variant_id) if definition != null else ""
	set(_value):
		pass

@export var selected_variant_id: StringName:
	get:
		return definition.variant_id if definition != null else &""
	set(_value):
		pass

@export var selected_type_id: StringName:
	get:
		return definition.type_id if definition != null else &""
	set(_value):
		pass

## The selected resource is exposed through the grouped controls below; keep
## its raw Dictionary and polygon properties out of the Inspector.
@export var selected_definition: EnemyDefinition:
	get:
		return _selected_definition
	set(value):
		if value == null or value == _selected_definition:
			return
		if _definition_is_dirty():
			_set_definition_notice("Save edits before selecting another definition.")
			notify_property_list_changed()
			return
		var registered := SlimeVariantCatalogScript.definition_resource(value.variant_id)
		if registered != value:
			_set_definition_notice("Select authored variants with the Variant picker.")
			notify_property_list_changed()
			return
		_selected_definition = value
		_workbench_notice = ""
		enemy_id = value.variant_id
		notify_property_list_changed()

@export_subgroup("Add Variant")
## Lowercase stable ID. The new variant starts from the selected variant's data.
@export var new_variant_id := ""
@export_tool_button("Create Variant from Selected") var create_variant_button: Callable

@export_subgroup("Add Enemy Family")
## New families must have their own EnemyFactory actor route and definition resource.
@export var family_authoring_status: String:
	get:
		return "Slime and Skeleton are supported. Other families need a definition and EnemyFactory actor route."
	set(_value):
		pass

@export_group("Identity & Appearance")
@export var display_name: String:
	get:
		return _variant_display_name_for_id(definition.variant_id) if definition != null else ""
	set(value):
		_set_definition_field(&"display_name", value)

@export_enum("Neutral", "Fire", "Water", "Electric", "Grass", "Shadow", "Ground", "Ice") var element: int:
	get:
		return definition.element if definition != null else ElementCatalogScript.Element.NEUTRAL
	set(value):
		_set_definition_field(&"element", value)

@export_enum("Physical", "Elemental Slime") var damage_type: String:
	get:
		return _damage_contract_display_name(definition.damage_contract) if definition != null else "Physical"
	set(value):
		_set_definition_field(&"damage_contract", _damage_contract_id_for_display_name(value))

@export_enum("Gray", "Red", "Blue", "Yellow", "Green", "Purple", "Orange", "Aquamarine") var appearance_palette: String:
	get:
		var palette_id := SlimeVisualComponentScript.palette_for_definition(definition) if definition != null else "green"
		return _palette_display_name(palette_id)
	set(value):
		_set_definition_field(&"visual_source", _palette_id_for_display_name(value))

@export_group("Combat & Growth")
@export_subgroup("Starting Stats")
@export_range(0, 99, 1) var vitality: int:
	get:
		return _base_stat_value("VIT")
	set(value):
		_set_base_stat("VIT", value)
@export_range(0, 99, 1) var strength: int:
	get:
		return _base_stat_value("STR")
	set(value):
		_set_base_stat("STR", value)
@export_range(0, 99, 1) var defense: int:
	get:
		return _base_stat_value("DEF")
	set(value):
		_set_base_stat("DEF", value)
@export_range(0, 99, 1) var agility: int:
	get:
		return _base_stat_value("AGI")
	set(value):
		_set_base_stat("AGI", value)
@export_range(0, 99, 1) var intelligence: int:
	get:
		return _base_stat_value("INT")
	set(value):
		_set_base_stat("INT", value)
@export_range(0, 99, 1) var mind: int:
	get:
		return _base_stat_value("MND")
	set(value):
		_set_base_stat("MND", value)

@export_subgroup("Growth Weights")
## Relative weights for how this enemy receives stats as it gains levels.
@export_range(0.0, 1.0, 0.01) var vitality_growth: float:
	get:
		return _growth_weight_value("VIT")
	set(value):
		_set_growth_weight("VIT", value)
@export_range(0.0, 1.0, 0.01) var strength_growth: float:
	get:
		return _growth_weight_value("STR")
	set(value):
		_set_growth_weight("STR", value)
@export_range(0.0, 1.0, 0.01) var defense_growth: float:
	get:
		return _growth_weight_value("DEF")
	set(value):
		_set_growth_weight("DEF", value)
@export_range(0.0, 1.0, 0.01) var agility_growth: float:
	get:
		return _growth_weight_value("AGI")
	set(value):
		_set_growth_weight("AGI", value)
@export_range(0.0, 1.0, 0.01) var intelligence_growth: float:
	get:
		return _growth_weight_value("INT")
	set(value):
		_set_growth_weight("INT", value)
@export_range(0.0, 1.0, 0.01) var mind_growth: float:
	get:
		return _growth_weight_value("MND")
	set(value):
		_set_growth_weight("MND", value)

@export_group("Encounter")
@export_enum("Baseline", "Matchup", "Late", "Shadow") var spawn_role: String:
	get:
		return _spawn_role_display_name(definition.encounter_role) if definition != null else "Matchup"
	set(value):
		_set_definition_field(&"encounter_role", StringName(value.to_lower()))
@export_range(0.0, 10.0, 0.01) var spawn_weight: float:
	get:
		return definition.encounter_weight if definition != null else 0.0
	set(value):
		_set_definition_field(&"encounter_weight", value)
@export_range(1, 99, 1) var minimum_rank: int:
	get:
		return definition.encounter_min_rank if definition != null else 1
	set(value):
		_set_definition_field(&"encounter_min_rank", value)

@export_subgroup("Matchups & Preferences")
@export_range(0.0, 10.0, 0.01) var matchup_weight: float:
	get:
		return definition.matchup_weight if definition != null else 0.0
	set(value):
		_set_definition_field(&"matchup_weight", value)
@export_range(0.0, 10.0, 0.01) var preferred_weight: float:
	get:
		return definition.preferred_weight if definition != null else 0.0
	set(value):
		_set_definition_field(&"preferred_weight", value)
@export var allow_preferred: bool:
	get:
		return definition.allow_preferred if definition != null else false
	set(value):
		_set_definition_field(&"allow_preferred", value)

@export_group("Preview")
@export_subgroup("State & Facing")
@export_enum("Idle", "Move", "Attack", "Shocked", "Spawn", "Boss Jump", "Boss Slam") var preview_state: int = PreviewState.IDLE:
	set(value):
		preview_state = clampi(value, PreviewState.IDLE, PreviewState.BOSS_SLAM)
		_current_frame = 0
		_frame_accumulator = 0.0
		_animation_finished = false
		_apply_preview_frame()
		queue_redraw()

@export_enum("Left", "Right") var facing_direction := 1:
	set(value):
		facing_direction = clampi(value, 0, 1)
		_apply_preview_frame()
		queue_redraw()

@export_enum("Regular actor", "Boss actor") var preview_actor_size: int = PreviewActorSize.REGULAR:
	set(value):
		preview_actor_size = clampi(value, PreviewActorSize.REGULAR, PreviewActorSize.BOSS)
		if is_node_ready():
			call_deferred("_build_preview")

@export_subgroup("Playback")
@export var playback_paused := false:
	set(value):
		playback_paused = value
		_frame_accumulator = 0.0
		queue_redraw()

@export var loop_animation := true

@export_range(0.03, 0.5, 0.01) var frame_duration := DESIGN_FRAME_TIME:
	set(value):
		frame_duration = maxf(value, 0.03)
		_frame_accumulator = 0.0

@export_tool_button("Pause / Resume") var playback_button: Callable
@export_tool_button("Step One Frame") var step_frame_button: Callable
@export_tool_button("Restart State") var restart_button: Callable
@export_tool_button("Refresh Preview") var refresh_button: Callable

@export_group("Geometry Guides")
@export var show_geometry_guides := true:
	set(value):
		show_geometry_guides = value
		_show_geometry()
		queue_redraw()

@export_subgroup("Visible Overlays")
@export var show_collision_shape := true:
	set(value):
		show_collision_shape = value
		_show_geometry()
		queue_redraw()
@export var show_body_hitbox := true:
	set(value):
		show_body_hitbox = value
		_show_geometry()
		queue_redraw()
@export var show_collision_guide := true:
	set(value):
		show_collision_guide = value
		_show_geometry()
		queue_redraw()
@export var show_attack_guide_left := true:
	set(value):
		show_attack_guide_left = value
		_show_geometry()
		queue_redraw()
@export var show_attack_guide_right := true:
	set(value):
		show_attack_guide_right = value
		_show_geometry()
		queue_redraw()

@export_subgroup("Edit in Preview")
@export_enum("None", "Actor Collision Boundary", "Body Hitbox", "Body Collision Guide", "Left Attack Range", "Right Attack Range") var geometry_edit_target: int = GeometryEditTarget.NONE:
	set(value):
		geometry_edit_target = clampi(value, GeometryEditTarget.NONE, GeometryEditTarget.ATTACK_RIGHT)
		queue_redraw()
		_queue_geometry_overlay_redraw()
@export_tool_button("Undo Geometry Edit") var undo_geometry_button: Callable
@export_tool_button("Redo Geometry Edit") var redo_geometry_button: Callable
@export_tool_button("Reset Selected Geometry") var reset_geometry_button: Callable

@export_group("Save & Validation")
@export var authoring_status: String:
	get:
		if not error_message.is_empty():
			return error_message
		if definition == null:
			return "Choose an authored enemy to begin editing."
		var problems := definition.validate()
		if not problems.is_empty():
			return "Needs attention: %s" % problems[0]
		return "Unsaved changes — save when ready." if _definition_is_dirty() else "All changes saved."
	set(_value):
		pass
@export_tool_button("Save Enemy Changes") var save_definition_button: Callable

var definition: EnemyDefinition
var preview_actor: SlimeActor
var preview_shadow: Sprite2D
var _geometry_overlay: Node2D
var frame_library: SpriteFrameLibrary
var preview_ready := false
var error_message := ""

var _current_frame := 0
var _frame_accumulator := 0.0
var _animation_finished := false
var _initializing_preview := true
var _enemy_variant_id: StringName = &"guard_slime"
var _selected_enemy_type_id: StringName = &"slime"
var _resolved_direction_assets: Array[String] = []
var _cached_frame_sets: Dictionary = {}
var _selected_definition: EnemyDefinition
var _tracked_definition: EnemyDefinition
var _original_variant_id: StringName = &""
var _observed_definition_record: Dictionary = {}
var _saved_definition_record: Dictionary = {}
var _workbench_notice := ""
var _geometry_drag_active := false
var _geometry_drag_target := GeometryEditTarget.NONE
var _geometry_drag_handle := -1
var _geometry_drag_start := Vector2.ZERO
var _geometry_drag_start_geometry: Dictionary = {}
var _geometry_undo_stack: Array[Dictionary] = []
var _geometry_redo_stack: Array[Dictionary] = []


func _validate_property(property: Dictionary) -> void:
	if property.name == "enemy_id":
		property.usage = PROPERTY_USAGE_NONE
		return
	if property.name == "enemy":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(_authored_type_picker_options())
		return
	if property.name == "variant":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = ",".join(_authored_variant_picker_options(_selected_enemy_type_id))
		return
	if property.name == "selected_definition":
		# The raw resource view exposes implementation details such as dictionaries
		# and polygon arrays. Friendly, typed controls above edit the same resource.
		property.usage = PROPERTY_USAGE_NONE
		return
	if property.name in [&"authoring_status", &"family_authoring_status"]:
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		return
	if property.name == "selected_enemy_name":
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		return
	if property.name in [&"selected_variant_id", &"selected_type_id"]:
		property.usage = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		return
	if String(property.name) in DEFINITION_EDITOR_PROPERTIES:
		# These controls are live views over the selected definition, not fields
		# owned by the preview scene. Persist edits through Save Enemy Changes.
		property.usage = PROPERTY_USAGE_EDITOR
		return
func _set_enemy_type(requested_type_id: StringName) -> void:
	if requested_type_id == _selected_enemy_type_id:
		return
	if _definition_is_dirty():
		_set_definition_notice("Save edits before switching enemies.")
		notify_property_list_changed()
		return
	var matching_variants := _authored_variant_ids_for_type(requested_type_id)
	if matching_variants.is_empty():
		_set_workbench_error("No authored variants exist for enemy type '%s'." % requested_type_id)
		return
	_selected_enemy_type_id = requested_type_id
	var current_definition := SlimeVariantCatalogScript.definition_resource(_enemy_variant_id)
	if current_definition == null or current_definition.type_id != requested_type_id:
		_set_enemy_variant(matching_variants[0])
	else:
		if is_node_ready() and not _initializing_preview:
			call_deferred("_build_preview")
		notify_property_list_changed()


func _set_enemy_variant(requested_variant_id: StringName) -> void:
	if requested_variant_id == _enemy_variant_id:
		return
	if _definition_is_dirty():
		_set_definition_notice("Save edits before switching variants.")
		notify_property_list_changed()
		return
	var selected_definition_resource := SlimeVariantCatalogScript.definition_resource(requested_variant_id)
	if selected_definition_resource == null:
		_set_workbench_error("Unknown enemy variant ID: %s" % requested_variant_id)
		return
	_enemy_variant_id = requested_variant_id
	_selected_enemy_type_id = selected_definition_resource.type_id
	if is_node_ready() and not _initializing_preview:
		call_deferred("_build_preview")
	notify_property_list_changed()


func _authored_type_picker_options() -> PackedStringArray:
	var result := PackedStringArray()
	for type_id in _authored_type_ids():
		result.append(_type_picker_label_for_id(type_id))
	return result


func _authored_variant_picker_options(type_id: StringName) -> PackedStringArray:
	var result := PackedStringArray()
	for variant_id_value in _authored_variant_ids_for_type(type_id):
		result.append(_variant_picker_label_for_id(variant_id_value))
	return result


func _authored_type_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	var seen_type_ids: Dictionary = {}
	for variant_id_value in _authored_variant_ids():
		var definition_resource_value := SlimeVariantCatalogScript.definition_resource(variant_id_value)
		if definition_resource_value == null or seen_type_ids.has(definition_resource_value.type_id):
			continue
		seen_type_ids[definition_resource_value.type_id] = true
		result.append(definition_resource_value.type_id)
	return result


func _authored_variant_ids_for_type(type_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for variant_id_value in _authored_variant_ids():
		var definition_resource_value := SlimeVariantCatalogScript.definition_resource(variant_id_value)
		if definition_resource_value != null and definition_resource_value.type_id == type_id:
			result.append(variant_id_value)
	return result


func _enemy_type_display_name(type_id: StringName) -> String:
	if type_id == &"slime":
		return "Slime"
	return String(type_id).replace("_", " ").capitalize()


func _type_picker_label_for_id(type_id: StringName) -> String:
	var label := _enemy_type_display_name(type_id)
	var matches := 0
	for candidate_type_id in _authored_type_ids():
		if _enemy_type_display_name(candidate_type_id) == label:
			matches += 1
	return "%s (%s)" % [label, type_id] if matches > 1 else label


func _enemy_type_id_for_display_name(display_name_value: String) -> StringName:
	for type_id in _authored_type_ids():
		if _type_picker_label_for_id(type_id) == display_name_value:
			return type_id
	return &""


func _variant_display_name_for_id(variant_id_value: StringName) -> String:
	var selected_definition_resource := SlimeVariantCatalogScript.definition_resource(variant_id_value)
	if selected_definition_resource == null:
		return String(variant_id_value)
	var label := selected_definition_resource.display_name.strip_edges()
	if label.is_empty():
		label = String(variant_id_value)
	if selected_definition_resource.type_id == &"slime" and label.to_lower().ends_with(" slime"):
		label = label.substr(0, label.length() - 6).strip_edges()
	return label


func _variant_picker_label_for_id(variant_id_value: StringName) -> String:
	var selected_definition_resource := SlimeVariantCatalogScript.definition_resource(variant_id_value)
	if selected_definition_resource == null:
		return String(variant_id_value)
	var label := _variant_display_name_for_id(variant_id_value)
	var matches := 0
	for candidate_variant_id in _authored_variant_ids_for_type(selected_definition_resource.type_id):
		if _variant_display_name_for_id(candidate_variant_id) == label:
			matches += 1
	return "%s (%s)" % [label, variant_id_value] if matches > 1 else label


func _variant_id_for_picker_label(type_id: StringName, display_name_value: String) -> StringName:
	for variant_id_value in _authored_variant_ids_for_type(type_id):
		if _variant_picker_label_for_id(variant_id_value) == display_name_value:
			return variant_id_value
	return &""


func _palette_display_name(palette_id: String) -> String:
	return String(PALETTE_DISPLAY_NAMES.get(palette_id, palette_id.capitalize()))


func _palette_id_for_display_name(display_name_value: String) -> String:
	for palette_id in PALETTE_DISPLAY_NAMES:
		if PALETTE_DISPLAY_NAMES[palette_id] == display_name_value:
			return palette_id
	return display_name_value.to_lower()


func _damage_contract_display_name(damage_contract: StringName) -> String:
	return "Elemental Slime" if damage_contract == &"elemental_slime" else "Physical"


func _damage_contract_id_for_display_name(display_name_value: String) -> StringName:
	return &"elemental_slime" if display_name_value == "Elemental Slime" else &"physical"


func _spawn_role_display_name(spawn_role_id: StringName) -> String:
	return String(spawn_role_id).capitalize()


func _set_definition_field(field_name: StringName, value: Variant) -> void:
	if definition == null or definition.get(field_name) == value:
		return
	definition.set(field_name, value)
	definition.emit_changed()
	_poll_definition_edits()


func _base_stat_value(stat_name: String) -> int:
	return int(definition.base_stats.get(stat_name, 0)) if definition != null else 0


func _set_base_stat(stat_name: String, value: int) -> void:
	if definition == null or _base_stat_value(stat_name) == value:
		return
	var values := definition.base_stats.duplicate(true)
	values[stat_name] = maxi(value, 0)
	_set_definition_field(&"base_stats", values)


func _growth_weight_value(stat_name: String) -> float:
	return float(definition.growth_weights.get(stat_name, 0.0)) if definition != null else 0.0


func _set_growth_weight(stat_name: String, value: float) -> void:
	if definition == null or is_equal_approx(_growth_weight_value(stat_name), value):
		return
	var values := definition.growth_weights.duplicate(true)
	values[stat_name] = clampf(value, 0.0, 1.0)
	_set_definition_field(&"growth_weights", values)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(Engine.is_editor_hint())
	var command_line_id := _enemy_id_from_command_line()
	if not command_line_id.is_empty() and SlimeVariantCatalogScript.is_variant(command_line_id):
		enemy_id = command_line_id
	if not SlimeVariantCatalogScript.is_variant(enemy_id):
		var authored_ids := _authored_variant_ids()
		if not authored_ids.is_empty():
			enemy_id = authored_ids[0]
	_build_preview()
	_initializing_preview = false


func _enter_tree() -> void:
	if playback_button.is_null():
		playback_button = Callable(self, "_toggle_playback")
	if step_frame_button.is_null():
		step_frame_button = Callable(self, "_step_preview_frame")
	if restart_button.is_null():
		restart_button = Callable(self, "_restart_preview_state")
	if refresh_button.is_null():
		refresh_button = Callable(self, "refresh_preview")
	if save_definition_button.is_null():
		save_definition_button = Callable(self, "save_selected_definition")
	if create_variant_button.is_null():
		create_variant_button = Callable(self, "create_authored_variant")
	if undo_geometry_button.is_null():
		undo_geometry_button = Callable(self, "undo_geometry_edit")
	if redo_geometry_button.is_null():
		redo_geometry_button = Callable(self, "redo_geometry_edit")
	if reset_geometry_button.is_null():
		reset_geometry_button = Callable(self, "reset_selected_geometry")


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	_poll_definition_edits()
	if _geometry_drag_active:
		return
	if playback_paused or _animation_finished:
		return
	if _selected_frame_count() <= 0:
		return
	_frame_accumulator += maxf(delta, 0.0)
	while _frame_accumulator >= frame_duration:
		_frame_accumulator -= frame_duration
		_advance_preview_frame()
		if playback_paused or _animation_finished:
			break


func refresh_preview() -> void:
	# Explicit refresh is the workbench's first cache-invalidation hook. The
	# underlying shared visual helpers remain the authority for all frame data.
	# Keep the original ID lookup alive while the Inspector contains a rejected
	# ID edit, so refreshing visuals cannot orphan that unsaved Resource.
	var definition_id_was_edited := definition != null and definition.variant_id != _original_variant_id
	if not definition_id_was_edited:
		SlimeVariantCatalogScript.invalidate_cache()
	_cached_frame_sets.clear()
	frame_library = SpriteFrameLibraryScript.new() as SpriteFrameLibrary
	SlimeVisualComponentScript.direction_texture_cache.clear()
	SlimeVisualComponentScript.frame_set_cache.clear()
	_build_preview()
	notify_property_list_changed()


func create_authored_variant() -> void:
	if _definition_is_dirty():
		_set_definition_notice("Save edits before creating another variant.")
		return
	if definition == null:
		_set_definition_notice("Select a variant to use as the starting point.")
		return
	var candidate_id := new_variant_id.strip_edges()
	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z][a-z0-9_]*$")
	if id_pattern.search(candidate_id) == null:
		_set_workbench_error("Variant ID must match ^[a-z][a-z0-9_]*$")
		return
	var authored_id := StringName(candidate_id)
	if SlimeVariantCatalogScript.is_variant(authored_id):
		_set_workbench_error("An authored variant already uses id '%s'" % candidate_id)
		return
	var resource_path := "res://resources/definitions/%s.tres" % candidate_id
	if FileAccess.file_exists(resource_path):
		_set_workbench_error("Definition already exists: %s" % resource_path)
		return

	var new_definition := definition.duplicate(true) as EnemyDefinition
	if new_definition == null:
		_set_workbench_error("Could not copy the selected variant.")
		return
	var source_variant_name := definition.display_name
	new_definition.id = authored_id
	new_definition.display_name = _new_variant_display_name(candidate_id)
	new_definition.resource_name = new_definition.display_name
	var save_error := ResourceSaver.save(new_definition, resource_path)
	if save_error != OK:
		_set_workbench_error("Could not create %s (error %d)" % [resource_path, save_error])
		return

	SlimeVariantCatalogScript.invalidate_cache()
	enemy_id = authored_id
	new_variant_id = ""
	_workbench_notice = "Created variant %s from %s" % [candidate_id, source_variant_name]
	notify_property_list_changed()
	queue_redraw()


func save_selected_definition() -> void:
	if definition == null:
		_set_definition_notice("Select an authored variant first.")
		return
	var saved_display_name := definition.display_name.strip_edges()
	if definition.type_id == &"slime" and saved_display_name.to_lower().ends_with(" slime"):
		definition.display_name = saved_display_name.substr(0, saved_display_name.length() - 6).strip_edges()
	if definition.variant_id != _original_variant_id:
		_set_definition_notice("Restore the original enemy ID before saving.")
		return
	var problems := definition.validate()
	if not problems.is_empty():
		_set_definition_notice("Cannot save: %s" % "; ".join(problems))
		return
	var source_path := SlimeVariantCatalogScript.definition_source_path(definition)
	if source_path.is_empty():
		_set_definition_notice("The selected definition has no authored file.")
		return
	var save_error: int = SlimeVariantCatalogScript.save_definition(definition)
	if save_error != OK:
		_set_definition_notice("Could not save definition (error %d)." % save_error)
		return
	definition.emit_changed()
	_observed_definition_record = definition.to_record().duplicate(true)
	_saved_definition_record = _observed_definition_record.duplicate(true)
	SlimeVariantCatalogScript.invalidate_cache()
	_workbench_notice = "Saved definition"
	error_message = ""
	print("Enemy preview workbench saved %s" % source_path)
	notify_property_list_changed()
	queue_redraw()


func _set_workbench_error(message: String) -> void:
	error_message = message
	push_warning("Enemy preview workbench: %s" % message)
	queue_redraw()


func _set_definition_notice(message: String) -> void:
	_workbench_notice = message
	push_warning("Enemy preview workbench: %s" % message)
	queue_redraw()


func _new_variant_display_name(variant_id_value: String) -> String:
	var display_words := variant_id_value.split("_", false)
	for index in display_words.size():
		display_words[index] = String(display_words[index]).capitalize()
	return " ".join(display_words)


func _authored_variant_ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for enemy_id_value in SlimeVariantCatalogScript.variant_ids():
		result.append(enemy_id_value)
	return result


func _enemy_id_from_command_line() -> StringName:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--enemy-id="):
			return StringName(argument.trim_prefix("--enemy-id="))
	return &""


func _build_preview() -> void:
	preview_ready = false
	error_message = ""
	definition = null
	_resolved_direction_assets.clear()
	_current_frame = 0
	_frame_accumulator = 0.0
	_animation_finished = false
	_release_preview_actor()
	if frame_library == null:
		frame_library = SpriteFrameLibraryScript.new() as SpriteFrameLibrary

	var selected_is_active := _selected_definition != null \
		and _selected_definition == _tracked_definition \
		and enemy_id == _original_variant_id
	if not EnemyFactory.is_variant(enemy_id) and not selected_is_active:
		error_message = "Unknown enemy id: %s" % enemy_id
		_clear_definition_binding()
		queue_redraw()
		return

	definition = _selected_definition if selected_is_active else EnemyFactory.definition(enemy_id)
	if definition == null:
		error_message = "Definition failed to load: %s" % enemy_id
		_clear_definition_binding()
		queue_redraw()
		return
	_track_definition(definition)

	preview_actor = EnemyFactory.assemble(definition)
	if preview_actor == null:
		error_message = "Unsupported enemy type: %s" % definition.type_id
		queue_redraw()
		return
	preview_actor.name = "PreviewEnemy"
	preview_actor.centered = false
	if preview_actor is SkeletonActor:
		preview_actor.offset = SkeletonActor.FRAME_OFFSET
	preview_actor.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_actor.process_mode = Node.PROCESS_MODE_DISABLED
	preview_actor.set_meta("encounter_scale", 2.0 if _is_boss_preview() else 1.0)
	preview_actor.position = _actor_preview_position()
	preview_actor.scale = Vector2.ONE * _actor_preview_scale()
	add_child(preview_actor)
	_ensure_geometry_overlay()
	_configure_visuals()
	_show_geometry()
	_apply_preview_frame()
	_update_preview_status()
	queue_redraw()


func _track_definition(value: EnemyDefinition) -> void:
	if value == null:
		_clear_definition_binding()
		return
	if _tracked_definition != value:
		_tracked_definition = value
		_original_variant_id = value.variant_id
		_observed_definition_record = value.to_record().duplicate(true)
		_saved_definition_record = _observed_definition_record.duplicate(true)
		_geometry_undo_stack.clear()
		_geometry_redo_stack.clear()
		_workbench_notice = ""
	_selected_definition = value
	notify_property_list_changed()


func _clear_definition_binding() -> void:
	definition = null
	_selected_definition = null
	_tracked_definition = null
	_original_variant_id = &""
	_observed_definition_record.clear()
	_saved_definition_record.clear()
	_geometry_undo_stack.clear()
	_geometry_redo_stack.clear()
	_geometry_drag_active = false
	_geometry_drag_start_geometry.clear()
	notify_property_list_changed()


func _definition_is_dirty() -> bool:
	return definition != null \
		and not _saved_definition_record.is_empty() \
		and definition.to_record() != _saved_definition_record


func _poll_definition_edits() -> void:
	if definition == null or definition != _tracked_definition:
		return
	var current_record := definition.to_record()
	if current_record == _observed_definition_record:
		return
	var previous_geometry := _geometry_snapshot_from_record(_observed_definition_record)
	var current_geometry := _capture_geometry()
	_observed_definition_record = current_record.duplicate(true)
	if not _geometry_drag_active and previous_geometry != current_geometry:
		# Inspector property edits already participate in Godot's editor undo
		# history. Drop the workbench-local canvas history to avoid applying an
		# older preview edit over a newer Inspector edit.
		_geometry_undo_stack.clear()
		_geometry_redo_stack.clear()
	if _definition_is_dirty():
		_workbench_notice = ""
	_apply_definition_edits_to_preview()
	queue_redraw()


func _apply_definition_edits_to_preview() -> void:
	if definition == null or preview_actor == null or not is_instance_valid(preview_actor):
		return
	preview_actor.variant = String(_original_variant_id)
	preview_actor.combat_element = definition.element
	preview_actor.set_meta("element", definition.element)
	preview_actor.set_meta("damage_contract", String(definition.damage_contract))
	preview_actor.set_meta("enemy_definition_id", definition.variant_id)
	preview_actor.set_meta("enemy_variant_id", definition.variant_id)
	preview_actor.set_meta("enemy_type_id", definition.type_id)
	preview_actor.set_meta("visual_source", definition.visual_source)
	preview_actor.set_meta("encounter_role", String(definition.encounter_role))
	preview_actor.set_meta("encounter_weight", definition.encounter_weight)
	preview_actor.set_meta("encounter_min_rank", definition.encounter_min_rank)
	preview_actor.set_meta("matchup_weight", definition.matchup_weight)
	preview_actor.set_meta("preferred_weight", definition.preferred_weight)
	preview_actor.set_meta("allow_preferred", definition.allow_preferred)
	var stats := preview_actor.get_node_or_null("Stats") as StatsComponent
	if stats != null:
		stats.apply_enemy_variant_profile(definition.base_stats, definition.growth_weights, _original_variant_id)
	EnemyFactory.apply_geometry(preview_actor, definition)
	_show_geometry()
	SlimeVisualComponentScript.apply_palette_material(preview_actor)
	_apply_preview_frame()
	_update_preview_status()


func _definition_status() -> String:
	if definition == null:
		return ""
	if definition.variant_id != _original_variant_id:
		return "RESTORE ORIGINAL ID"
	if not _workbench_notice.is_empty():
		return _workbench_notice
	if _definition_is_dirty():
		return "UNSAVED - SAVE DEFINITION"
	return ""


## Called by the project EditorPlugin with pointer coordinates converted into
## this workbench's local canvas space. The scene remains responsible for the
## authored data; the plugin only forwards editor viewport input.
func handle_editor_canvas_input(event: InputEvent, workbench_position: Vector2) -> bool:
	if not Engine.is_editor_hint() or definition == null or preview_actor == null:
		return false
	if _geometry_drag_active:
		if event is InputEventMouseMotion:
			_update_geometry_drag(workbench_position)
			return true
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_update_geometry_drag(workbench_position)
			_finish_geometry_drag()
			return true
		return false
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
		return false
	return _begin_geometry_drag(workbench_position)


func reset_selected_geometry() -> void:
	if definition == null or geometry_edit_target == GeometryEditTarget.NONE:
		return
	var before := _capture_geometry()
	var after := before.duplicate(true)
	var defaults := EnemyDefinition.new().geometry_record()
	var field_name := _geometry_field_name(geometry_edit_target)
	if field_name.is_empty():
		return
	after[field_name] = defaults[field_name].duplicate() if defaults[field_name] is PackedVector2Array else defaults[field_name]
	if before == after:
		return
	_push_geometry_undo(before)
	_geometry_redo_stack.clear()
	_apply_geometry_snapshot(after)


func undo_geometry_edit() -> void:
	if _geometry_undo_stack.is_empty() or definition == null:
		return
	var current := _capture_geometry()
	var previous: Dictionary = _geometry_undo_stack.pop_back()
	_geometry_redo_stack.append(current)
	_apply_geometry_snapshot(previous)


func redo_geometry_edit() -> void:
	if _geometry_redo_stack.is_empty() or definition == null:
		return
	var current := _capture_geometry()
	var next: Dictionary = _geometry_redo_stack.pop_back()
	_push_geometry_undo(current)
	_apply_geometry_snapshot(next)


func _begin_geometry_drag(workbench_position: Vector2) -> bool:
	if geometry_edit_target == GeometryEditTarget.NONE or not show_geometry_guides or not _geometry_target_visible(geometry_edit_target):
		return false
	var actor_position := preview_actor.to_local(to_global(workbench_position))
	var target_name := _geometry_field_name(geometry_edit_target)
	if target_name.is_empty():
		return false
	var handle := -1
	var current_value = definition.get(target_name)
	if current_value is PackedVector2Array:
		handle = _nearest_polygon_handle(current_value, workbench_position)
		if handle < 0:
			return false
	elif current_value is Rect2:
		handle = _rect_handle_at(current_value, workbench_position, actor_position)
		if handle == -2:
			return false
	else:
		return false
	_geometry_drag_active = true
	_geometry_drag_target = geometry_edit_target
	_geometry_drag_handle = handle
	_geometry_drag_start = actor_position
	_geometry_drag_start_geometry = _capture_geometry()
	queue_redraw()
	return true


func _nearest_polygon_handle(points: PackedVector2Array, workbench_position: Vector2) -> int:
	var nearest_index := -1
	var nearest_distance := GEOMETRY_HANDLE_HIT_RADIUS
	for index in points.size():
		var handle_position := _actor_point_to_workbench(points[index])
		var distance := handle_position.distance_to(workbench_position)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_index = index
	return nearest_index


func _rect_handle_at(rect: Rect2, workbench_position: Vector2, actor_position: Vector2) -> int:
	var corners := _rect_corners(rect)
	for index in corners.size():
		if _actor_point_to_workbench(corners[index]).distance_to(workbench_position) <= GEOMETRY_HANDLE_HIT_RADIUS:
			return index
	return -1 if rect.has_point(actor_position) else -2


func _update_geometry_drag(workbench_position: Vector2) -> void:
	var actor_position := _snap_geometry_point(preview_actor.to_local(to_global(workbench_position)))
	var field_name := _geometry_field_name(_geometry_drag_target)
	var initial_value = _geometry_drag_start_geometry[field_name]
	if initial_value is PackedVector2Array:
		var points: PackedVector2Array = initial_value.duplicate()
		if _geometry_drag_handle >= 0 and _geometry_drag_handle < points.size():
			points[_geometry_drag_handle] = actor_position
			definition.set(field_name, points)
	elif initial_value is Rect2:
		var updated_rect: Rect2 = initial_value
		if _geometry_drag_handle < 0:
			updated_rect.position = initial_value.position + _snap_geometry_point(actor_position - _geometry_drag_start)
		else:
			updated_rect = _resize_rect_from_handle(initial_value, _geometry_drag_handle, actor_position)
		definition.set(field_name, updated_rect)
	EnemyFactory.apply_geometry(preview_actor, definition)
	_show_geometry()
	_update_preview_status()
	queue_redraw()


func _resize_rect_from_handle(start_rect: Rect2, handle: int, pointer: Vector2) -> Rect2:
	const MIN_RECT_SIDE := 0.5
	var left := start_rect.position.x
	var top := start_rect.position.y
	var right := start_rect.end.x
	var bottom := start_rect.end.y
	if handle == 0 or handle == 3:
		left = minf(pointer.x, right - MIN_RECT_SIDE)
	else:
		right = maxf(pointer.x, left + MIN_RECT_SIDE)
	if handle == 0 or handle == 1:
		top = minf(pointer.y, bottom - MIN_RECT_SIDE)
	else:
		bottom = maxf(pointer.y, top + MIN_RECT_SIDE)
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


func _finish_geometry_drag() -> void:
	if not _geometry_drag_active:
		return
	_geometry_drag_active = false
	_geometry_drag_target = GeometryEditTarget.NONE
	_geometry_drag_handle = -1
	if _geometry_drag_start_geometry != _capture_geometry():
		_push_geometry_undo(_geometry_drag_start_geometry)
		_geometry_redo_stack.clear()
		definition.emit_changed()
		_observed_definition_record = definition.to_record().duplicate(true)
		_workbench_notice = ""
	_geometry_drag_start_geometry.clear()
	notify_property_list_changed()
	queue_redraw()


func _push_geometry_undo(snapshot: Dictionary) -> void:
	_geometry_undo_stack.append(snapshot.duplicate(true))
	while _geometry_undo_stack.size() > MAX_GEOMETRY_UNDO_STEPS:
		_geometry_undo_stack.pop_front()


func _apply_geometry_snapshot(snapshot: Dictionary) -> void:
	if definition == null:
		return
	definition.apply_geometry_record(snapshot)
	_observed_definition_record = definition.to_record().duplicate(true)
	EnemyFactory.apply_geometry(preview_actor, definition)
	_show_geometry()
	_update_preview_status()
	_workbench_notice = ""
	update_configuration_warnings()
	notify_property_list_changed()
	queue_redraw()


func _capture_geometry() -> Dictionary:
	return definition.geometry_record().duplicate(true) if definition != null else {}


func _geometry_snapshot_from_record(record: Dictionary) -> Dictionary:
	var geometry: Dictionary = {}
	for field_name in [
		"collision_guide_rect",
		"collision_polygon",
		"body_hitbox_polygon",
		"attack_guide_left_rect",
		"attack_guide_right_rect",
	]:
		if record.has(field_name):
			var value = record[field_name]
			geometry[field_name] = value.duplicate() if value is PackedVector2Array else value
	return geometry


func _geometry_field_name(target: int) -> String:
	match target:
		GeometryEditTarget.COLLISION_SHAPE:
			return "collision_polygon"
		GeometryEditTarget.BODY_HITBOX:
			return "body_hitbox_polygon"
		GeometryEditTarget.COLLISION_GUIDE:
			return "collision_guide_rect"
		GeometryEditTarget.ATTACK_LEFT:
			return "attack_guide_left_rect"
		GeometryEditTarget.ATTACK_RIGHT:
			return "attack_guide_right_rect"
	return ""


func _geometry_target_visible(target: int) -> bool:
	if not show_geometry_guides:
		return false
	match target:
		GeometryEditTarget.COLLISION_SHAPE:
			return show_collision_shape
		GeometryEditTarget.BODY_HITBOX:
			return show_body_hitbox
		GeometryEditTarget.COLLISION_GUIDE:
			return show_collision_guide
		GeometryEditTarget.ATTACK_LEFT:
			return show_attack_guide_left
		GeometryEditTarget.ATTACK_RIGHT:
			return show_attack_guide_right
	return false


func _snap_geometry_point(point: Vector2) -> Vector2:
	return Vector2(snappedf(point.x, GEOMETRY_SNAP), snappedf(point.y, GEOMETRY_SNAP))


func _actor_point_to_workbench(point: Vector2) -> Vector2:
	return to_local(preview_actor.to_global(point))


func _rect_corners(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	])


func _release_preview_actor() -> void:
	if preview_actor == null or not is_instance_valid(preview_actor):
		preview_actor = null
		preview_shadow = null
		_queue_geometry_overlay_redraw()
		return
	if preview_actor.get_parent() != null:
		preview_actor.get_parent().remove_child(preview_actor)
	preview_actor.free()
	preview_actor = null
	preview_shadow = null
	_queue_geometry_overlay_redraw()


func _configure_visuals() -> void:
	var actor_nodes: Array[Sprite2D] = [preview_actor]
	var source_paths := SlimeVisualComponentScript.direction_texture_paths(_is_boss_preview())
	var paths_by_actor: Dictionary = {preview_actor: source_paths}
	SlimeVisualComponentScript.build_direction_textures(actor_nodes, paths_by_actor, Callable(self, "_load_texture_or_null"))
	_resolved_direction_assets = source_paths.duplicate()

	var visual := preview_actor.get_node_or_null("Visual") as SlimeVisualComponent
	if visual == null:
		return
	var frame_sets := _get_shared_frame_sets()
	SlimeVisualComponentScript.assign_attack_frames(actor_nodes, frame_sets["attack"] as Dictionary)
	SlimeVisualComponentScript.assign_shocked_frames(actor_nodes, frame_sets["shocked"] as Dictionary)
	SlimeVisualComponentScript.assign_spawn_frames(actor_nodes, frame_sets["spawn"] as Dictionary)
	if _is_boss_preview():
		SlimeVisualComponentScript.assign_boss_ability_frames(actor_nodes, frame_library, _cached_frame_sets, Callable(self, "_ignore_warm_texture"))
	else:
		SlimeVisualComponentScript.assign_regular_shadow_frames(actor_nodes, frame_library, _cached_frame_sets, Callable(self, "_ignore_warm_texture"))
	if preview_actor is SkeletonActor:
		(preview_actor as SkeletonActor).apply_authored_visuals()
	_create_preview_shadow(visual)
	if not preview_actor is SkeletonActor:
		SlimeVisualComponentScript.apply_palette_material(preview_actor)


func _get_shared_frame_sets() -> Dictionary:
	if not _cached_frame_sets.has("attack"):
		_cached_frame_sets["attack"] = SlimeVisualComponentScript.build_attack_frame_library(
			frame_library, NORMAL_FRAME_SIZE, _cached_frame_sets, Callable(self, "_ignore_warm_texture")
		)
	if not _cached_frame_sets.has("shocked"):
		_cached_frame_sets["shocked"] = SlimeVisualComponentScript.build_shocked_frame_library(
			frame_library, NORMAL_FRAME_SIZE, _cached_frame_sets, Callable(self, "_ignore_warm_texture")
		)
	if not _cached_frame_sets.has("spawn"):
		_cached_frame_sets["spawn"] = SlimeVisualComponentScript.build_spawn_frame_library(
			frame_library, NORMAL_FRAME_SIZE, _cached_frame_sets, Callable(self, "_ignore_warm_texture")
		)
	return _cached_frame_sets


func _create_preview_shadow(visual: SlimeVisualComponent) -> void:
	preview_shadow = Sprite2D.new()
	preview_shadow.name = "SlimeFloorShadow"
	preview_shadow.centered = false
	preview_shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if preview_actor is SkeletonActor:
		preview_shadow.position = Vector2(-8.0, -9.0)
		preview_shadow.scale = Vector2(1.0, 0.6875)
		preview_shadow.texture = load("res://assets/artwork/TinyDemonShadow.png") as Texture2D
	else:
		preview_shadow.position = Vector2.ZERO
		preview_shadow.scale = Vector2.ONE / preview_actor.scale
		preview_shadow.texture = visual.shadow_idle_texture
	preview_shadow.modulate = Color(1.0, 1.0, 1.0, 0.25)
	preview_shadow.z_as_relative = true
	preview_shadow.z_index = -1
	preview_actor.add_child(preview_shadow)


func _show_geometry() -> void:
	if preview_actor == null or not is_instance_valid(preview_actor):
		return
	var guides_enabled := show_geometry_guides
	var collision_polygon := preview_actor.get_node_or_null("CollisionPolygon") as Polygon2D
	if collision_polygon != null:
		collision_polygon.color = Color(0.2, 0.9, 1.0, 0.16)
		collision_polygon.visible = guides_enabled and show_collision_shape
	var body_hitbox := preview_actor.get_node_or_null("BodyHitbox") as Polygon2D
	if body_hitbox != null:
		body_hitbox.color = Color(1.0, 0.25, 0.2, 0.18)
		body_hitbox.visible = guides_enabled and show_body_hitbox
	var guide_visibility := {
		&"CollisionGuide": guides_enabled and show_collision_guide,
		&"AttackGuideL": guides_enabled and show_attack_guide_left,
		&"AttackGuideR": guides_enabled and show_attack_guide_right,
	}
	for guide_name: StringName in [&"CollisionGuide", &"AttackGuideL", &"AttackGuideR"]:
		var guide := preview_actor.get_node_or_null(NodePath(guide_name)) as Node2D
		if guide == null:
			continue
		guide.set("draw_in_game", true)
		guide.visible = guide_visibility[guide_name]
		guide.queue_redraw()
	_queue_geometry_overlay_redraw()


func _ensure_geometry_overlay() -> void:
	if _geometry_overlay == null or not is_instance_valid(_geometry_overlay):
		_geometry_overlay = Node2D.new()
		_geometry_overlay.name = "GeometryEditOverlay"
		_geometry_overlay.z_index = 20
		add_child(_geometry_overlay)
		_geometry_overlay.draw.connect(_draw_geometry_overlay.bind(_geometry_overlay))
	elif _geometry_overlay.get_index() != get_child_count() - 1:
		move_child(_geometry_overlay, get_child_count() - 1)
	_geometry_overlay.queue_redraw()


func _queue_geometry_overlay_redraw() -> void:
	if _geometry_overlay != null and is_instance_valid(_geometry_overlay):
		_geometry_overlay.queue_redraw()


func _visuals_are_valid() -> bool:
	if preview_actor == null:
		return false
	var visual := preview_actor.get_node_or_null("Visual") as SlimeVisualComponent
	return visual != null and visual.left_texture != null and visual.right_texture != null


func _update_preview_status() -> void:
	var geometry_valid := _geometry_is_valid()
	var visuals_valid := _visuals_are_valid()
	preview_ready = geometry_valid and visuals_valid
	if not geometry_valid:
		error_message = "Factory output has invalid collision geometry"
	elif not visuals_valid:
		error_message = "One or more authored enemy visual assets could not be resolved"
	else:
		error_message = ""


func _geometry_is_valid() -> bool:
	if definition == null or preview_actor == null:
		return false
	var collision_polygon := preview_actor.get_node_or_null("CollisionPolygon") as Polygon2D
	var body_hitbox := preview_actor.get_node_or_null("BodyHitbox") as Polygon2D
	return collision_polygon != null \
		and body_hitbox != null \
		and _has_area(collision_polygon.polygon) \
		and _has_area(body_hitbox.polygon) \
		and _rect_has_area(definition.collision_guide_rect) \
		and _rect_has_area(definition.attack_guide_left_rect) \
		and _rect_has_area(definition.attack_guide_right_rect)


func _has_area(points: PackedVector2Array) -> bool:
	return EnemyDefinition.polygon_is_valid(points)


func _rect_has_area(rect: Rect2) -> bool:
	return rect.position.is_finite() \
		and rect.size.is_finite() \
		and rect.size.x > 0.0 \
		and rect.size.y > 0.0


func _selected_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if preview_actor == null:
		return frames
	var visual := preview_actor.get_node_or_null("Visual") as SlimeVisualComponent
	if visual == null:
		return frames
	if preview_actor is SkeletonActor:
		var skeleton := preview_actor as SkeletonActor
		if preview_state == PreviewState.ATTACK:
			return skeleton.attack_sequence_frames(facing_direction == 0)
		if preview_state == PreviewState.SHOCKED:
			return skeleton.shocked_left_frames if facing_direction == 0 else skeleton.shocked_frames
		if preview_state == PreviewState.SPAWN:
			return skeleton.spawn_left_frames if facing_direction == 0 else skeleton.spawn_frames
		return frames
	match preview_state:
		PreviewState.ATTACK:
			frames = visual.attack_left_frames if facing_direction == 0 else visual.attack_right_frames
		PreviewState.SHOCKED:
			frames = visual.boss_shocked_frames if _is_boss_preview() and not visual.boss_shocked_frames.is_empty() else visual.shocked_frames
		PreviewState.SPAWN:
			frames = visual.spawn_frames
		PreviewState.BOSS_JUMP:
			frames = visual.boss_jump_frames if _is_boss_preview() else frames
		PreviewState.BOSS_SLAM:
			frames = visual.boss_slam_frames if _is_boss_preview() else frames
	return frames


func _selected_shadow_frames() -> Array[Texture2D]:
	var frames: Array[Texture2D] = []
	if preview_actor == null:
		return frames
	if preview_actor is SkeletonActor:
		return frames
	var visual := preview_actor.get_node_or_null("Visual") as SlimeVisualComponent
	if visual == null:
		return frames
	match preview_state:
		PreviewState.ATTACK:
			frames = visual.shadow_attack_left_frames if facing_direction == 0 else visual.shadow_attack_right_frames
		PreviewState.SHOCKED:
			frames = visual.shadow_shocked_frames
		PreviewState.SPAWN:
			frames = visual.shadow_spawn_frames
		PreviewState.BOSS_JUMP:
			frames = visual.boss_shadow_jump_frames
		PreviewState.BOSS_SLAM:
			frames = visual.boss_shadow_slam_frames
	return frames


func _selected_frame_count() -> int:
	if preview_state in [PreviewState.IDLE, PreviewState.MOVE]:
		if preview_actor is SkeletonActor:
			var skeleton := preview_actor as SkeletonActor
			var frames := skeleton.idle_frames if preview_state == PreviewState.IDLE else skeleton.walk_frames
			return frames.size()
		return DESIGN_MOTION_FRAMES
	return _selected_frames().size()


func _advance_preview_frame() -> void:
	var frame_count := _selected_frame_count()
	if frame_count <= 0:
		return
	if _current_frame + 1 < frame_count:
		_current_frame += 1
	elif loop_animation:
		_current_frame = 0
	else:
		_current_frame = frame_count - 1
		_animation_finished = true
	_apply_preview_frame()
	queue_redraw()


func _apply_preview_frame() -> void:
	if preview_actor == null or not is_instance_valid(preview_actor):
		return
	var visual := preview_actor.get_node_or_null("Visual") as SlimeVisualComponent
	if visual == null:
		return
	var frame_count := _selected_frame_count()
	var has_frames := frame_count > 0
	if has_frames:
		_current_frame = clampi(_current_frame, 0, frame_count - 1)
	var base_texture := visual.left_texture if facing_direction == 0 else visual.right_texture
	var base_position := _actor_preview_position()
	var base_scale := Vector2.ONE * _actor_preview_scale()
	preview_actor.position = base_position
	preview_actor.scale = base_scale
	preview_actor.modulate = Color.WHITE

	if preview_state in [PreviewState.IDLE, PreviewState.MOVE]:
		preview_actor.texture = base_texture
		if preview_actor is SkeletonActor:
			var skeleton := preview_actor as SkeletonActor
			var skeleton_frames := skeleton.idle_left_frames if preview_state == PreviewState.IDLE and facing_direction == 0 else skeleton.idle_frames if preview_state == PreviewState.IDLE else skeleton.walk_left_frames if facing_direction == 0 else skeleton.walk_frames
			if not skeleton_frames.is_empty():
				preview_actor.texture = skeleton_frames[_current_frame % skeleton_frames.size()]
		else:
			var progress := float(_current_frame) / float(DESIGN_MOTION_FRAMES - 1)
			if preview_state == PreviewState.MOVE:
				preview_actor.scale = base_scale * visual.squish_scale(progress, Vector2.RIGHT)
				preview_actor.position.x += sin(progress * TAU) * 4.0
			else:
				var breathe := (sin(progress * TAU - PI * 0.5) + 1.0) * 0.5
				preview_actor.scale = base_scale * Vector2(1.0 + breathe * IDLE_BREATH_WIDTH, 1.0 - breathe * IDLE_BREATH_HEIGHT)
	else:
		var frames := _selected_frames()
		if not frames.is_empty():
			preview_actor.texture = frames[_current_frame]
		else:
			preview_actor.texture = base_texture

	if preview_shadow != null and is_instance_valid(preview_shadow):
		var shadow_frames := _selected_shadow_frames()
		if not shadow_frames.is_empty():
			preview_shadow.texture = shadow_frames[mini(_current_frame, shadow_frames.size() - 1)]
		elif preview_actor is SkeletonActor:
			preview_shadow.texture = load("res://assets/artwork/TinyDemonShadow.png") as Texture2D
		else:
			preview_shadow.texture = visual.shadow_idle_texture
	_queue_geometry_overlay_redraw()


func _toggle_playback() -> void:
	if _animation_finished:
		_current_frame = 0
		_animation_finished = false
		_apply_preview_frame()
		playback_paused = false
	else:
		playback_paused = not playback_paused


func _step_preview_frame() -> void:
	playback_paused = true
	_animation_finished = false
	_advance_preview_frame()


func _restart_preview_state() -> void:
	_current_frame = 0
	_frame_accumulator = 0.0
	_animation_finished = false
	_apply_preview_frame()
	queue_redraw()


func _actor_preview_position() -> Vector2:
	return Vector2(166.0, 46.0)


func _actor_preview_scale() -> float:
	return BASE_PREVIEW_SCALE if not _is_boss_preview() else BOSS_PREVIEW_SCALE


func _is_boss_preview() -> bool:
	return preview_actor_size == PreviewActorSize.BOSS


func _load_texture_or_null(path: String) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


func _ignore_warm_texture(_texture: Texture2D) -> void:
	pass


func get_preview_summary() -> Dictionary:
	if definition == null:
		return {"id": String(enemy_id), "variant_id": String(enemy_id), "ready": false, "error": error_message}
	return {
		"id": String(definition.variant_id),
		"variant_id": String(definition.variant_id),
		"type_id": String(definition.type_id),
		"appearance_palette": SlimeVisualComponentScript.palette_for_definition(definition),
		"display_name": definition.display_name,
		"element": ElementCatalogScript.display_name(definition.element),
		"damage_contract": String(definition.damage_contract),
		"base_stats": definition.base_stats.duplicate(true),
		"growth_weights": definition.growth_weights.duplicate(true),
		"visual_source": definition.visual_source,
		"encounter_role": String(definition.encounter_role),
		"encounter_weight": definition.encounter_weight,
		"encounter_min_rank": definition.encounter_min_rank,
		"matchup_weight": definition.matchup_weight,
		"preferred_weight": definition.preferred_weight,
		"allow_preferred": definition.allow_preferred,
		"dirty": _definition_is_dirty(),
		"resolved_direction_assets": _resolved_direction_assets.duplicate(),
		"preview_state": PREVIEW_STATE_LABELS[preview_state],
		"frame_index": _current_frame,
		"frame_count": _selected_frame_count(),
		"playing": not playback_paused and not _animation_finished,
		"geometry": definition.geometry_record(),
		"geometry_valid": _geometry_is_valid(),
		"ready": preview_ready,
	}


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, PREVIEW_CANVAS_SIZE), Color("101825"), true)
	draw_rect(Rect2(4, 4, 232, 152), Color("1b2a3d"), true)
	draw_rect(Rect2(4, 4, 232, 152), Color("5a7890"), false, 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(12, 17), "ENEMY DESIGN PREVIEW", HORIZONTAL_ALIGNMENT_LEFT, 216, 10, Color("b9e9ff"))

	if definition == null:
		draw_string(ThemeDB.fallback_font, Vector2(12, 42), error_message, HORIZONTAL_ALIGNMENT_LEFT, 216, 9, Color("ff8f8f"))
		return

	var state_label: String = PREVIEW_STATE_LABELS[preview_state]
	var frame_count := _selected_frame_count()
	var playback_label := "PAUSED" if playback_paused else "PLAYING" if not _animation_finished else "FINISHED"
	draw_string(ThemeDB.fallback_font, Vector2(12, 38), definition.display_name, HORIZONTAL_ALIGNMENT_LEFT, 142, 10, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(12, 51), "%s / %s" % [definition.type_id, definition.variant_id], HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 63), "element: %s" % ElementCatalogScript.display_name(definition.element), HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 75), "damage: %s" % definition.damage_contract, HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 87), "palette: %s" % SlimeVisualComponentScript.palette_for_definition(definition), HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("b7c9d8"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 103), "STR %d DEF %d VIT %d" % [int(definition.base_stats.get("STR", 0)), int(definition.base_stats.get("DEF", 0)), int(definition.base_stats.get("VIT", 0))], HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("d8e7f0"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 115), "AGI %d INT %d MND %d" % [int(definition.base_stats.get("AGI", 0)), int(definition.base_stats.get("INT", 0)), int(definition.base_stats.get("MND", 0))], HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("d8e7f0"))
	draw_string(ThemeDB.fallback_font, Vector2(12, 133), "%s  %s" % [state_label.to_upper(), playback_label], HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("b9e9ff"))
	var frame_label := "frame %d / %d" % [_current_frame + 1, frame_count] if frame_count > 0 else "no frames for this mode"
	draw_string(ThemeDB.fallback_font, Vector2(12, 145), frame_label, HORIZONTAL_ALIGNMENT_LEFT, 142, 8, Color("a8c1d5"))
	var status := error_message if not error_message.is_empty() else _definition_status()
	if status.is_empty():
		status = "READY" if preview_ready else "LOADING"
	var status_color := Color("8dffb1") if preview_ready and not _definition_is_dirty() else Color("ffcf7a")
	if not error_message.is_empty():
		status_color = Color("ff8f8f")
	draw_string(ThemeDB.fallback_font, Vector2(12, 154), status, HORIZONTAL_ALIGNMENT_LEFT, 216, 8, status_color)
	if preview_state in [PreviewState.BOSS_JUMP, PreviewState.BOSS_SLAM] and not _is_boss_preview():
		draw_string(ThemeDB.fallback_font, Vector2(166, 123), "select Boss actor", HORIZONTAL_ALIGNMENT_LEFT, 70, 8, Color("ffcf7a"))


func _draw_geometry_overlay(overlay: Node2D) -> void:
	if not Engine.is_editor_hint():
		return
	if preview_actor == null or geometry_edit_target == GeometryEditTarget.NONE or not _geometry_target_visible(geometry_edit_target):
		return
	var field_name := _geometry_field_name(geometry_edit_target)
	var value = definition.get(field_name)
	var points := PackedVector2Array()
	var handle_points := PackedVector2Array()
	if value is PackedVector2Array:
		for point in value:
			points.append(_actor_point_to_workbench(point))
		handle_points = points
	elif value is Rect2:
		var corners := _rect_corners(value)
		for corner in corners:
			points.append(_actor_point_to_workbench(corner))
		handle_points = points
		var center := _actor_point_to_workbench(value.get_center())
		overlay.draw_circle(center, 2.0, Color("fff07a"))
		_draw_handle(overlay, center, false)
	if points.size() < 2:
		return
	var outline := points.duplicate()
	outline.append(points[0])
	overlay.draw_polyline(outline, Color("fff07a"), 2.0, true)
	for point in handle_points:
		_draw_handle(overlay, point, value is Rect2)
	var guide_name := "DRAG VERTICES" if value is PackedVector2Array else "DRAG BOX / CORNERS"
	overlay.draw_string(ThemeDB.fallback_font, Vector2(150, 136), guide_name, HORIZONTAL_ALIGNMENT_LEFT, 84, 7, Color("fff07a"))


func _draw_handle(overlay: Node2D, point: Vector2, square: bool) -> void:
	if square:
		overlay.draw_rect(Rect2(point - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color("101825"), true)
		overlay.draw_rect(Rect2(point - Vector2(2.0, 2.0), Vector2(4.0, 4.0)), Color("fff07a"), false, 1.0)
	else:
		overlay.draw_circle(point, 2.0, Color("101825"))
		overlay.draw_arc(point, 2.0, 0.0, TAU, 12, Color("fff07a"), 1.0)
