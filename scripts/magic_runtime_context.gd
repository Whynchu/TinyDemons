extends RefCounted
class_name MagicRuntimeContext

## Typed runtime context for MagicRuntimeController. Carries the shared state
## reads, writes, callables, and component references the controller previously
## reached for through `root.get/set/call`, so magic code never reaches into
## GameplayState by name. State writes stay behind typed get/set lambdas that
## delegate to the state owner. Built by GameplayFrameController.

var player: Sprite2D = null
var slimes: Array[Sprite2D] = []
var puzzle_torches: Array[Sprite2D] = []
var player_tuning: PlayerTuning = null
var combat_tuning: CombatTuning = null
var player_animation_component: PlayerAnimationComponent = null
var player_chroma_component: Node = null
var player_aspect_ability_component: Node = null
var player_equipment_visual_component: PlayerEquipmentVisualComponent = null
var magic_projectile_controller: Node = null
var effects_spawner: EffectsSpawner = null
var hud_controller: HudController = null
var rng: RandomNumberGenerator = null

var player_is_magic_casting_get: Callable = Callable()
var player_is_magic_casting_set: Callable = Callable()
var player_is_attacking_get: Callable = Callable()
var player_is_rolling_get: Callable = Callable()
var player_is_backflipping_get: Callable = Callable()
var player_is_defending_get: Callable = Callable()
var player_dead_get: Callable = Callable()
var last_player_facing_left_get: Callable = Callable()
var last_player_input_direction_get: Callable = Callable()
var current_player_palette_name_get: Callable = Callable()
var player_agi_get: Callable = Callable()
var player_spd_get: Callable = Callable()
var player_mp_fill_get: Callable = Callable()
var player_mp_fill_size_get: Callable = Callable()
var player_mp_fill_size_set: Callable = Callable()
var player_mp_text_get: Callable = Callable()
var player_anim_name_set: Callable = Callable()
var player_anim_frame_set: Callable = Callable()
var player_anim_timer_set: Callable = Callable()
var player_magic_flip_h_set: Callable = Callable()
var player_imbued_element_set: Callable = Callable()

var imbue_mp_cost := 40
var imbue_duration := 15.0
var imbue_cooldown := 20.0
var imbue_hold_threshold := 0.35
var magic_projectile_size := 4
var magic_projectile_lifetime := 0.6

var execute_current_aspect_ability: Callable = Callable()
var valid_current_target: Callable = Callable()
var closest_target: Callable = Callable()
var is_slime_targetable: Callable = Callable()
var slime_body_polygon: Callable = Callable()
var collision_rect: Callable = Callable()
var player_magic_damage_result_against: Callable = Callable()
var damage_slime_with_number: Callable = Callable()
var knockback_slime: Callable = Callable()
var magic_hit_slime: Callable = Callable()
var activate_puzzle_torch: Callable = Callable()
var spawn_damage_number: Callable = Callable()
var play_sound: Callable = Callable()
var record_run_style_action: Callable = Callable()
var load_texture_or_null: Callable = Callable()
var pixel_particle_texture: Callable = Callable()
var pixel_text_texture: Callable = Callable()
var start_player_palette_flash: Callable = Callable()
var sync_chroma_presentation: Callable = Callable()
var acknowledge_chroma_feedback: Callable = Callable()
var update_player_mp_ui: Callable = Callable()
var update_mp_desaturation: Callable = Callable()
var snap_half_pixel: Callable = Callable()
var build_equipment_visual_context: Callable = Callable()
var build_animation_context: Callable = Callable()
