extends Node
class_name ScreenStateController

signal debug_page_requested
signal debug_action_requested(action: StringName, amount: int)

const ASPECT_CATALOG_SCRIPT = preload("res://scripts/content/aspect_catalog.gd")
const HubProgressionDraftScript = preload("res://scripts/runtime/state/hub_progression_draft.gd")
const SoulVisualsScript = preload("res://scripts/runtime/services/soul_visuals.gd")
const PauseMenuLayoutScript = preload("res://scripts/ui/pause_menu_layout.gd")
const ShopMenuLayoutScript = preload("res://scripts/ui/shop_menu_layout.gd")
const FusionMenuLayoutScript = preload("res://scripts/ui/fusion_menu_layout.gd")
const BindMenuLayoutScript = preload("res://scripts/ui/bind_menu_layout.gd")
const FusionMenuModelScript = preload("res://scripts/ui/fusion_menu_model.gd")
const BindMenuModelScript = preload("res://scripts/ui/bind_menu_model.gd")
const ResponsiveLayoutScript = preload("res://scripts/ui/menu_responsive_layout.gd")
const TitleParticleControllerScript = preload("res://scripts/ui/title_particle_controller.gd")
const MenuWidgetFactoryScript = preload("res://scripts/ui/menu_widget_factory.gd")
const MenuCursorAnimatorScript = preload("res://scripts/ui/menu_cursor_animator.gd")
const LoadingScreenPresenterScript = preload("res://scripts/ui/loading_screen_presenter.gd")
const MenuPromptTextureFactoryScript = preload("res://scripts/ui/menu_prompt_texture_factory.gd")
const NameEntryWidgetPresenterScript = preload("res://scripts/ui/name_entry_widget_presenter.gd")
const NameEntryScreenControllerScript = preload("res://scripts/ui/name_entry_screen_controller.gd")
const SaveSelectScreenPresenterScript = preload("res://scripts/ui/save_select_screen_presenter.gd")
const TitleScreenPresenterScript = preload("res://scripts/ui/title_screen_presenter.gd")
const ArchetypeScreenPresenterScript = preload("res://scripts/ui/archetype_screen_presenter.gd")
const SettingsScreenPresenterScript = preload("res://scripts/ui/settings_screen_presenter.gd")
const GameOverScreenPresenterScript = preload("res://scripts/ui/game_over_screen_presenter.gd")
const RunCompleteScreenPresenterScript = preload("res://scripts/ui/run_complete_screen_presenter.gd")
const HubScreenActionsScript = preload("res://scripts/ui/hub_screen_actions.gd")
const HubStatsScreenPresenterScript = preload("res://scripts/ui/hub_stats_screen_presenter.gd")
const HubStatsInteractionPresenterScript = preload("res://scripts/ui/hub_stats_interaction_presenter.gd")
const HubPageVisibilityPresenterScript = preload("res://scripts/ui/hub_page_visibility_presenter.gd")
const HubCommandShellPresenterScript = preload("res://scripts/ui/hub_command_shell_presenter.gd")
const HubResponsiveLayoutPresenterScript = preload("res://scripts/ui/hub_responsive_layout_presenter.gd")
const HubResponsiveLayoutContextScript = preload("res://scripts/ui/hub_responsive_layout_context.gd")
const HubItemVisibilityPresenterScript = preload("res://scripts/ui/hub_item_visibility_presenter.gd")
const HubItemVisibilityContextScript = preload("res://scripts/ui/hub_item_visibility_context.gd")
const HubInputControllerScript = preload("res://scripts/ui/hub_input_controller.gd")
const HubEquipmentMenuPresenterScript = preload("res://scripts/ui/hub_equipment_menu_presenter.gd")
const HubEquipmentMenuContextScript = preload("res://scripts/ui/hub_equipment_menu_context.gd")
const HubTransactionMenuPresenterScript = preload("res://scripts/ui/hub_transaction_menu_presenter.gd")
const HubTransactionMenuContextScript = preload("res://scripts/ui/hub_transaction_menu_context.gd")
const HubMenuSignalBinderScript = preload("res://scripts/ui/hub_menu_signal_binder.gd")
const HubLegacyWidgetVisibilityPresenterScript = preload("res://scripts/ui/hub_legacy_widget_visibility_presenter.gd")
const HubLegacyWidgetScrollPresenterScript = preload("res://scripts/ui/hub_legacy_widget_scroll_presenter.gd")
const PauseScreenPresenterScript = preload("res://scripts/ui/pause_screen_presenter.gd")
const MENU_CIRCLE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_CIRCLE_TEXTURE
const MENU_X_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_X_TEXTURE
const MENU_TRIANGLE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_TRIANGLE_TEXTURE
const MENU_SQUARE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_SQUARE_TEXTURE
const GAME_VERSION := "0.3.35"
const MENU_CURSOR_TEXTURE: Texture2D = preload("res://assets/artwork/cursor.png")
const HUB_STAT_ADD_TEXTURE: Texture2D = HubStatsScreenPresenterScript.HUB_STAT_ADD_TEXTURE
const HUB_STAT_SUBTRACT_TEXTURE: Texture2D = HubStatsScreenPresenterScript.HUB_STAT_SUBTRACT_TEXTURE
const HUB_GOLD_TEXTURE: Texture2D = preload("res://assets/artwork/GoldFresh2.png")
const DEMON_HUB_MENU_SCENE: PackedScene = preload("res://scenes/menus/hub/demon_hub_menu.tscn")
## Shared left gutter for the hand cursor sprite. Menu buttons, slots, and
## prompts are targeted with their left edge this many pixels from the cursor's
## sprite origin, so the 16x16 hand's fingertip points at the item instead of
## floating far away from it.
const CURSOR_LEFT_GAP := 10.0
## Shifts the cursor sprite up this many pixels from the anchor callers pass,
## so the hand's fingertip sits 2px higher on the item.
const CURSOR_VERTICAL_RAISE := MenuCursorAnimatorScript.CURSOR_VERTICAL_RAISE
## Horizontal idle bob for the hand cursor: it glides this many pixels to the
## right of its resting spot, then flicks back left, looping.
const CURSOR_BOB_AMOUNT := MenuCursorAnimatorScript.CURSOR_BOB_AMOUNT
const CURSOR_BOB_SLIDE_TIME := MenuCursorAnimatorScript.CURSOR_BOB_SLIDE_TIME
const CURSOR_BOB_SNAP_TIME := MenuCursorAnimatorScript.CURSOR_BOB_SNAP_TIME
const HUB_ITEM_DETAIL_TOP := 105.0
const HUB_ITEM_DETAIL_PITCH := 7.0
const HUB_ITEM_DETAIL_PANEL_TOP := 103.0
const HUB_ITEM_DETAIL_PANEL_HEIGHT := 42.0
const HUB_GEAR_BROWSE_DETAIL_TOP := 136.0
const HUB_ITEM_TEXT_WRAP_LENGTH := 34
const STATUS_LEFT_ROW_COUNT := HubStatsScreenPresenterScript.STATUS_LEFT_ROW_COUNT
const STAT_VALUE_RIGHT_ANCHOR := HubStatsScreenPresenterScript.STAT_VALUE_RIGHT_ANCHOR
const STAT_LABEL_X := HubStatsScreenPresenterScript.STAT_LABEL_X
const STAT_LABEL_TOP := HubStatsScreenPresenterScript.STAT_LABEL_TOP
const STAT_ROW_PITCH := HubStatsScreenPresenterScript.STAT_ROW_PITCH
const STAT_ROW_LEFT_ARROW_X := HubStatsScreenPresenterScript.STAT_ROW_LEFT_ARROW_X
const STAT_ROW_RIGHT_ARROW_X := HubStatsScreenPresenterScript.STAT_ROW_RIGHT_ARROW_X
const STAT_SUBTRACT_MARKER_X := HubStatsScreenPresenterScript.STAT_SUBTRACT_MARKER_X
const STAT_ADD_MARKER_X := HubStatsScreenPresenterScript.STAT_ADD_MARKER_X
# Match EquipmentMenuLayout's command gutter: the cursor's resting origin is
# 20 px left and 3 px above the rendered glyph. _position_menu_cursor applies
# the shared 2 px vertical raise, so this helper supplies the remaining 1 px.
# The ordinary menu-cursor idle animation remains enabled; only the resting
# anchor is geometry-derived, so every command word uses the same relationship.
const HUB_COMMAND_CURSOR_TEXT_OFFSET := HubCommandShellPresenterScript.HUB_COMMAND_CURSOR_TEXT_OFFSET
const HUB_COMMAND_CURSOR_X_CORRECTIONS: Array[float] = HubCommandShellPresenterScript.HUB_COMMAND_CURSOR_X_CORRECTIONS
const HUB_COMMAND_DIMMED_BOB_OFFSET := HubCommandShellPresenterScript.HUB_COMMAND_DIMMED_BOB_OFFSET
const DERIVED_LABEL_X := HubStatsScreenPresenterScript.DERIVED_LABEL_X
const DERIVED_LABEL_TOP := HubStatsScreenPresenterScript.DERIVED_LABEL_TOP
const DERIVED_ROW_PITCH := HubStatsScreenPresenterScript.DERIVED_ROW_PITCH
const DERIVED_VALUE_RIGHT_ANCHOR := HubStatsScreenPresenterScript.DERIVED_VALUE_RIGHT_ANCHOR
const DIM_CURSOR_MODULATE := HubCommandShellPresenterScript.DIM_CURSOR_MODULATE
const ACTIVE_CURSOR_MODULATE := HubCommandShellPresenterScript.ACTIVE_CURSOR_MODULATE
const HUB_COMMAND_BUTTON_Y := HubCommandShellPresenterScript.HUB_COMMAND_BUTTON_Y
const STAT_CURSOR_X := HubStatsScreenPresenterScript.STAT_CURSOR_X
const STAT_UTILITY_Y := HubStatsScreenPresenterScript.STAT_UTILITY_Y

## Hub content pages retain the old numeric values for transaction callers.
## STATUS is now an alias for the merged STATS page; EQUIPMENT remains a
## legacy direct route used by Pause and by older save/menu probes, but is no
## longer exposed as a Demon Hub command. The authored hub presents only the
## four commands from the rework render.
const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")
const HUB_PAGE_ALLOCATE := HubMenuStateScript.HUB_PAGE_ALLOCATE
const HUB_PAGE_STATS := HubMenuStateScript.HUB_PAGE_STATS
const HUB_PAGE_EQUIPMENT := HubMenuStateScript.HUB_PAGE_EQUIPMENT
const HUB_PAGE_SHOP := HubMenuStateScript.HUB_PAGE_SHOP
const HUB_PAGE_FUSION := HubMenuStateScript.HUB_PAGE_FUSION
const HUB_PAGE_BIND := HubMenuStateScript.HUB_PAGE_BIND
const HUB_PAGE_STATUS := HubMenuStateScript.HUB_PAGE_STATUS
const HUB_PAGE_COUNT := HubMenuStateScript.HUB_PAGE_COUNT
const HUB_COMMAND_PAGE_TARGETS := HubMenuStateScript.HUB_COMMAND_PAGE_TARGETS

signal state_changed(state: StringName)
var state: StringName = &"gameplay"
var _title_particle_controller: TitleParticleController = TitleParticleControllerScript.new() as TitleParticleController
var _menu_widget_factory: MenuWidgetFactory = MenuWidgetFactoryScript.new() as MenuWidgetFactory
var _menu_cursor_animator: MenuCursorAnimator = MenuCursorAnimatorScript.new() as MenuCursorAnimator
var _loading_screen_presenter: LoadingScreenPresenter = LoadingScreenPresenterScript.new() as LoadingScreenPresenter
var _menu_prompt_texture_factory: MenuPromptTextureFactory = MenuPromptTextureFactoryScript.new() as MenuPromptTextureFactory
var _name_entry_screen_controller: NameEntryScreenController = NameEntryScreenControllerScript.new() as NameEntryScreenController
var _save_select_screen_presenter: SaveSelectScreenPresenter = SaveSelectScreenPresenterScript.new() as SaveSelectScreenPresenter
var _title_screen_presenter: TitleScreenPresenter = TitleScreenPresenterScript.new() as TitleScreenPresenter
var _archetype_screen_presenter: ArchetypeScreenPresenter = ArchetypeScreenPresenterScript.new() as ArchetypeScreenPresenter
var _settings_screen_presenter: SettingsScreenPresenter = SettingsScreenPresenterScript.new() as SettingsScreenPresenter
var _game_over_screen_presenter: GameOverScreenPresenter = GameOverScreenPresenterScript.new() as GameOverScreenPresenter
var _run_complete_screen_presenter: RunCompleteScreenPresenter = RunCompleteScreenPresenterScript.new() as RunCompleteScreenPresenter
var _pause_screen_presenter: PauseScreenPresenter = PauseScreenPresenterScript.new() as PauseScreenPresenter
var _hub_stats_presenter: HubStatsScreenPresenter = HubStatsScreenPresenterScript.new() as HubStatsScreenPresenter
var _hub_stats_interaction_presenter: HubStatsInteractionPresenter = HubStatsInteractionPresenterScript.new() as HubStatsInteractionPresenter
var _hub_page_visibility_presenter: HubPageVisibilityPresenter = HubPageVisibilityPresenterScript.new() as HubPageVisibilityPresenter
var _hub_command_shell_presenter: HubCommandShellPresenter = HubCommandShellPresenterScript.new() as HubCommandShellPresenter
var _hub_responsive_layout_presenter: HubResponsiveLayoutPresenter = HubResponsiveLayoutPresenterScript.new() as HubResponsiveLayoutPresenter
var _hub_responsive_layout_context: HubResponsiveLayoutContext = HubResponsiveLayoutContextScript.new() as HubResponsiveLayoutContext
var _hub_item_visibility_presenter: HubItemVisibilityPresenter = HubItemVisibilityPresenterScript.new() as HubItemVisibilityPresenter
var _hub_item_visibility_context: HubItemVisibilityContext = HubItemVisibilityContextScript.new() as HubItemVisibilityContext
var _hub_menu_state: HubMenuState = HubMenuStateScript.new() as HubMenuState
var _hub_input_controller: HubInputController = HubInputControllerScript.new() as HubInputController
var _hub_equipment_menu_presenter: HubEquipmentMenuPresenter = HubEquipmentMenuPresenterScript.new() as HubEquipmentMenuPresenter
var _hub_equipment_menu_context: HubEquipmentMenuContext = HubEquipmentMenuContextScript.new() as HubEquipmentMenuContext
var _hub_transaction_menu_presenter: HubTransactionMenuPresenterScript = HubTransactionMenuPresenterScript.new() as HubTransactionMenuPresenterScript
var _hub_transaction_menu_context: HubTransactionMenuContextScript = HubTransactionMenuContextScript.new() as HubTransactionMenuContextScript
var _hub_menu_signal_binder: HubMenuSignalBinderScript = HubMenuSignalBinderScript.new() as HubMenuSignalBinderScript
var _hub_legacy_widget_visibility_presenter: HubLegacyWidgetVisibilityPresenterScript = HubLegacyWidgetVisibilityPresenterScript.new() as HubLegacyWidgetVisibilityPresenterScript
var _hub_legacy_widget_scroll_presenter: HubLegacyWidgetScrollPresenterScript = HubLegacyWidgetScrollPresenterScript.new() as HubLegacyWidgetScrollPresenterScript
var _menu_world_hidden := false
var _menu_world_background_visible := true
var _menu_world_map_visible := true
var _menu_world_actors_visible := true
var hub_overlay: ColorRect = null
var hub_summary_text: Sprite2D = null
var hub_points_text: Sprite2D:
	get: return _hub_stats_presenter.points_text
	set(value): _hub_stats_presenter.points_text = value
var hub_gold_text: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_gold_text
	set(value): _hub_responsive_layout_presenter.hub_gold_text = value
var hub_soul_text: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_soul_text
	set(value): _hub_responsive_layout_presenter.hub_soul_text = value
var hub_gold_icon: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_gold_icon
	set(value): _hub_responsive_layout_presenter.hub_gold_icon = value
var hub_soul_icon: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_soul_icon
	set(value): _hub_responsive_layout_presenter.hub_soul_icon = value
var hub_stat_texts: Array[Sprite2D]:
	get: return _hub_stats_presenter.stat_texts
	set(value): _hub_stats_presenter.stat_texts = value
var hub_stat_value_texts: Array[Sprite2D]:
	get: return _hub_stats_presenter.stat_value_texts
	set(value): _hub_stats_presenter.stat_value_texts = value
var hub_derived_value_texts: Array[Sprite2D]:
	get: return _hub_stats_presenter.derived_value_texts
	set(value): _hub_stats_presenter.derived_value_texts = value
var hub_stat_add_marker: Sprite2D:
	get: return _hub_stats_presenter.stat_add_marker
	set(value): _hub_stats_presenter.stat_add_marker = value
var hub_stat_subtract_marker: Sprite2D:
	get: return _hub_stats_presenter.stat_subtract_marker
	set(value): _hub_stats_presenter.stat_subtract_marker = value
var hub_stat_buttons: Array[Button]:
	get: return _hub_stats_presenter.stat_buttons
	set(value): _hub_stats_presenter.stat_buttons = value
var hub_stat_left_buttons: Array[Button]:
	get: return _hub_stats_presenter.stat_left_buttons
	set(value): _hub_stats_presenter.stat_left_buttons = value
var hub_stat_right_buttons: Array[Button]:
	get: return _hub_stats_presenter.stat_right_buttons
	set(value): _hub_stats_presenter.stat_right_buttons = value
var hub_stat_row_buttons: Array[Button]:
	get: return _hub_stats_presenter.stat_row_buttons
	set(value): _hub_stats_presenter.stat_row_buttons = value
var hub_respec_button: Button:
	get: return _hub_stats_presenter.respec_button
	set(value): _hub_stats_presenter.respec_button = value
var hub_start_button: Button = null
var hub_title_button: Button = null
var hub_derived_texts: Array[Sprite2D]:
	get: return _hub_stats_presenter.derived_texts
	set(value): _hub_stats_presenter.derived_texts = value
var hub_apply_button: Button:
	get: return _hub_stats_presenter.apply_button
	set(value): _hub_stats_presenter.apply_button = value
var hub_cancel_button: Button:
	get: return _hub_stats_presenter.cancel_button
	set(value): _hub_stats_presenter.cancel_button = value
var hub_auto_button: Button:
	get: return _hub_stats_presenter.auto_button
	set(value): _hub_stats_presenter.auto_button = value
var hub_progression_draft = HubProgressionDraftScript.new()
var hub_pending_vit: int:
	get: return hub_progression_draft.vit
	set(value): hub_progression_draft.vit = maxi(int(value), 0)
var hub_pending_str: int:
	get: return hub_progression_draft.strength
	set(value): hub_progression_draft.strength = maxi(int(value), 0)
var hub_pending_def: int:
	get: return hub_progression_draft.def
	set(value): hub_progression_draft.def = maxi(int(value), 0)
var hub_pending_spd: int:
	get: return hub_progression_draft.spd
	set(value): hub_progression_draft.spd = maxi(int(value), 0)
var hub_pending_agi: int:
	get: return hub_progression_draft.agi
	set(value): hub_progression_draft.agi = maxi(int(value), 0)
var hub_pending_int: int:
	get: return hub_progression_draft.intelligence
	set(value): hub_progression_draft.intelligence = maxi(int(value), 0)
var hub_pending_mnd: int:
	get: return hub_progression_draft.mnd
	set(value): hub_progression_draft.mnd = maxi(int(value), 0)
var hub_opened_from_npc: bool:
	get: return _hub_menu_state.hub_opened_from_npc
	set(value): _hub_menu_state.hub_opened_from_npc = value
var hub_pause_mode: bool:
	get: return _hub_menu_state.hub_pause_mode
	set(value): _hub_menu_state.hub_pause_mode = value
var hub_is_root: bool:
	get: return _hub_menu_state.hub_is_root
	set(value): _hub_menu_state.hub_is_root = value
var hub_menu_row: int:
	get: return _hub_menu_state.hub_menu_row
	set(value): _hub_menu_state.hub_menu_row = value
var hub_stat_row: int:
	get: return _hub_menu_state.hub_stat_row
	set(value): _hub_menu_state.hub_stat_row = value
var hub_action_column: int:
	get: return _hub_menu_state.hub_action_column
	set(value): _hub_menu_state.hub_action_column = value
var hub_content_focus: bool:
	get: return _hub_menu_state.hub_content_focus
	set(value): _hub_menu_state.hub_content_focus = value
var hub_equipment_action_focus: bool:
	get: return _hub_menu_state.hub_equipment_action_focus
	set(value): _hub_menu_state.hub_equipment_action_focus = value
var hub_interact_input_was_down: bool:
	get: return _hub_menu_state.hub_interact_input_was_down
	set(value): _hub_menu_state.hub_interact_input_was_down = value
var hub_cancel_input_was_down: bool:
	get: return _hub_menu_state.hub_cancel_input_was_down
	set(value): _hub_menu_state.hub_cancel_input_was_down = value
var menu_input_release_lock := false
var hub_page_previous_input_was_down: bool:
	get: return _hub_menu_state.hub_page_previous_input_was_down
	set(value): _hub_menu_state.hub_page_previous_input_was_down = value
var hub_page_next_input_was_down: bool:
	get: return _hub_menu_state.hub_page_next_input_was_down
	set(value): _hub_menu_state.hub_page_next_input_was_down = value
var pause_input_was_down := false
var pause_interact_input_was_down := false
var pause_cancel_input_was_down := false
var hub_page: int:
	get: return _hub_menu_state.hub_page
	set(value): _hub_menu_state.hub_page = value
var hub_root_page: Control:
	get: return _hub_page_visibility_presenter.root_page
	set(value): _hub_page_visibility_presenter.root_page = value
var hub_page_roots: Dictionary:
	get: return _hub_page_visibility_presenter.page_roots
	set(value): _hub_page_visibility_presenter.page_roots = value
var hub_item_index: int:
	get: return _hub_menu_state.hub_item_index
	set(value): _hub_menu_state.hub_item_index = value
var hub_list_scroll: float:
	get: return _hub_menu_state.hub_list_scroll
	set(value): _hub_menu_state.hub_list_scroll = value
var hub_shop_sell_mode: bool:
	get: return _hub_menu_state.hub_shop_sell_mode
	set(value): _hub_menu_state.hub_shop_sell_mode = value
var hub_shop_sell_confirm_pending: bool:
	get: return _hub_menu_state.hub_shop_sell_confirm_pending
	set(value): _hub_menu_state.hub_shop_sell_confirm_pending = value
var hub_shop_command_focus: bool:
	get: return _hub_menu_state.hub_shop_command_focus
	set(value): _hub_menu_state.hub_shop_command_focus = value
var hub_shop_state: int:
	get: return _hub_menu_state.hub_shop_state
	set(value): _hub_menu_state.hub_shop_state = value
var hub_shop_sell_amount: int:
	get: return _hub_menu_state.hub_shop_sell_amount
	set(value): _hub_menu_state.hub_shop_sell_amount = value
var hub_shop_sell_amount_max: int:
	get: return _hub_menu_state.hub_shop_sell_amount_max
	set(value): _hub_menu_state.hub_shop_sell_amount_max = value
var hub_shop_cursor: Sprite2D = null
var hub_choice_scroll: float:
	get: return _hub_menu_state.hub_choice_scroll
	set(value): _hub_menu_state.hub_choice_scroll = value
var hub_list_cursor: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_list_cursor
	set(value): _hub_responsive_layout_presenter.hub_list_cursor = value
var hub_slot_cursor: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_slot_cursor
	set(value): _hub_responsive_layout_presenter.hub_slot_cursor = value
var hub_choice_cursor: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_choice_cursor
	set(value): _hub_responsive_layout_presenter.hub_choice_cursor = value
var hub_gear_candidate_indices: Dictionary:
	get: return _hub_menu_state.hub_gear_candidate_indices
	set(value): _hub_menu_state.hub_gear_candidate_indices = value
var hub_touch_candidate_slot: String:
	get: return _hub_menu_state.hub_touch_candidate_slot
	set(value): _hub_menu_state.hub_touch_candidate_slot = value
var hub_touch_candidate_index: int:
	get: return _hub_menu_state.hub_touch_candidate_index
	set(value): _hub_menu_state.hub_touch_candidate_index = value
var hub_gear_browsing: bool:
	get: return _hub_menu_state.hub_gear_browsing
	set(value): _hub_menu_state.hub_gear_browsing = value
var hub_fusion_candidates: Array[ItemInstance] = []
var hub_fusion_candidates_dirty := true
var hub_fusion_count: int:
	get: return _hub_menu_state.hub_fusion_count
	set(value): _hub_menu_state.hub_fusion_count = value
var hub_fusion_message: String:
	get: return _hub_menu_state.hub_fusion_message
	set(value): _hub_menu_state.hub_fusion_message = value
var hub_gear_choice_texts: Array[Sprite2D]:
	get: return _hub_responsive_layout_presenter.hub_gear_choice_texts
	set(value): _hub_responsive_layout_presenter.hub_gear_choice_texts = value
var hub_gear_choice_buttons: Array[Button]:
	get: return _hub_responsive_layout_presenter.hub_gear_choice_buttons
	set(value): _hub_responsive_layout_presenter.hub_gear_choice_buttons = value
var hub_gear_slot_buttons: Array[Button]:
	get: return _hub_responsive_layout_presenter.hub_gear_slot_buttons
	set(value): _hub_responsive_layout_presenter.hub_gear_slot_buttons = value
var hub_gear_stat_texts: Array[Sprite2D]:
	get: return _hub_responsive_layout_presenter.hub_gear_stat_texts
	set(value): _hub_responsive_layout_presenter.hub_gear_stat_texts = value
var hub_gear_stat_panel: Panel:
	get: return _hub_responsive_layout_presenter.hub_gear_stat_panel
	set(value): _hub_responsive_layout_presenter.hub_gear_stat_panel = value
var hub_allocate_panel: Panel:
	get: return _hub_stats_presenter.allocate_panel
	set(value): _hub_stats_presenter.allocate_panel = value
var hub_allocate_preview_panel: Panel:
	get: return _hub_stats_presenter.allocate_preview_panel
	set(value): _hub_stats_presenter.allocate_preview_panel = value
var hub_allocate_preview_title: Sprite2D:
	get: return _hub_stats_presenter.allocate_preview_title
	set(value): _hub_stats_presenter.allocate_preview_title = value
var hub_allocate_preview_texts: Array[Sprite2D]:
	get: return _hub_stats_presenter.allocate_preview_texts
	set(value): _hub_stats_presenter.allocate_preview_texts = value
var hub_item_list_panel: Panel:
	get: return _hub_responsive_layout_presenter.hub_item_list_panel
	set(value): _hub_responsive_layout_presenter.hub_item_list_panel = value
var hub_item_content_clip: Control:
	get: return _hub_responsive_layout_presenter.hub_item_content_clip
	set(value): _hub_responsive_layout_presenter.hub_item_content_clip = value
var hub_gear_choice_panel: Panel:
	get: return _hub_responsive_layout_presenter.hub_gear_choice_panel
	set(value): _hub_responsive_layout_presenter.hub_gear_choice_panel = value
var hub_gear_choice_content_clip: Control:
	get: return _hub_responsive_layout_presenter.hub_gear_choice_content_clip
	set(value): _hub_responsive_layout_presenter.hub_gear_choice_content_clip = value
var hub_cursor_text: Sprite2D:
	get: return _hub_command_shell_presenter.cursor
	set(value): _hub_command_shell_presenter.cursor = value
var hub_stat_cursor_text: Sprite2D:
	get: return _hub_stats_presenter.stat_cursor_text
	set(value): _hub_stats_presenter.stat_cursor_text = value
var hub_page_buttons: Array[Button]:
	get: return _hub_command_shell_presenter.page_buttons
	set(value): _hub_command_shell_presenter.page_buttons = value
var hub_back_button: Button:
	get: return _hub_command_shell_presenter.back_button
	set(value): _hub_command_shell_presenter.back_button = value
var hub_back_prompt_text: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_back_prompt_text
	set(value): _hub_responsive_layout_presenter.hub_back_prompt_text = value
var hub_footer_select_glyph: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_footer_select_glyph
	set(value): _hub_responsive_layout_presenter.hub_footer_select_glyph = value
var hub_footer_select_text: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_footer_select_text
	set(value): _hub_responsive_layout_presenter.hub_footer_select_text = value
var hub_footer_back_glyph: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_footer_back_glyph
	set(value): _hub_responsive_layout_presenter.hub_footer_back_glyph = value
var hub_footer_back_text: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_footer_back_text
	set(value): _hub_responsive_layout_presenter.hub_footer_back_text = value
var hub_player_card_panel: Panel:
	get: return _hub_responsive_layout_presenter.hub_player_card_panel
	set(value): _hub_responsive_layout_presenter.hub_player_card_panel = value
var hub_player_card_texts: Array[Sprite2D]:
	get: return _hub_responsive_layout_presenter.hub_player_card_texts
	set(value): _hub_responsive_layout_presenter.hub_player_card_texts = value
var hub_status_texts: Array[Sprite2D]:
	get: return _hub_stats_presenter.status_texts
	set(value): _hub_stats_presenter.status_texts = value
var hub_context_text: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_context_text
	set(value): _hub_responsive_layout_presenter.hub_context_text = value
var hub_currency_text: Sprite2D = null
var hub_currency_icon: Sprite2D = null
var hub_binding_panel: Panel:
	get: return _hub_responsive_layout_presenter.hub_binding_panel
	set(value): _hub_responsive_layout_presenter.hub_binding_panel = value
var hub_binding_texts: Array[Sprite2D]:
	get: return _hub_responsive_layout_presenter.hub_binding_texts
	set(value): _hub_responsive_layout_presenter.hub_binding_texts = value
var hub_binding_action_button: Button:
	get: return _hub_responsive_layout_presenter.hub_binding_action_button
	set(value): _hub_responsive_layout_presenter.hub_binding_action_button = value
var hub_binding_message: String:
	get: return _hub_menu_state.hub_binding_message
	set(value): _hub_menu_state.hub_binding_message = value
var hub_fusion_state: int:
	get: return _hub_menu_state.hub_fusion_state
	set(value): _hub_menu_state.hub_fusion_state = value
var hub_fusion_item_selected: bool:
	get: return _hub_menu_state.hub_fusion_item_selected
	set(value): _hub_menu_state.hub_fusion_item_selected = value
var hub_binding_state: int:
	get: return _hub_menu_state.hub_binding_state
	set(value): _hub_menu_state.hub_binding_state = value
var hub_fusion_menu: Control:
	get: return _hub_responsive_layout_presenter.hub_fusion_menu
	set(value): _hub_responsive_layout_presenter.hub_fusion_menu = value
var hub_bind_menu: Control:
	get: return _hub_responsive_layout_presenter.hub_bind_menu
	set(value): _hub_responsive_layout_presenter.hub_bind_menu = value
var pause_resume_button: Button = null
var pause_settings_button: Button:
	get: return _pause_screen_presenter.settings_button
	set(value): _pause_screen_presenter.settings_button = value
var pause_quit_button: Button:
	get: return _pause_screen_presenter.quit_button
	set(value): _pause_screen_presenter.quit_button = value
var pause_cursor_text: Sprite2D:
	get: return _pause_screen_presenter.cursor_text
	set(value): _pause_screen_presenter.cursor_text = value
var pause_menu_buttons: Array[Button]:
	get: return _pause_screen_presenter.menu_buttons
	set(value): _pause_screen_presenter.menu_buttons = value
var pause_overlay: ColorRect:
	get: return _pause_screen_presenter.overlay
	set(value): _pause_screen_presenter.overlay = value
var pause_title_text: Sprite2D:
	get: return _pause_screen_presenter.title_text
	set(value): _pause_screen_presenter.title_text = value
var pause_page := 0
var pause_root_page: Control:
	get: return _pause_screen_presenter.root_page
	set(value): _pause_screen_presenter.root_page = value
var pause_page_roots: Dictionary:
	get: return _pause_screen_presenter.page_roots
	set(value): _pause_screen_presenter.page_roots = value
var pause_menu_row := 0
var pause_command_list: MenuCommandList = null
var pause_player_card_panel: Panel = null
var pause_player_card_texts: Array[Sprite2D]:
	get: return _pause_screen_presenter.player_card_texts
	set(value): _pause_screen_presenter.player_card_texts = value
var pause_player_portrait: Sprite2D:
	get: return _pause_screen_presenter.player_portrait
	set(value): _pause_screen_presenter.player_portrait = value
var pause_gold_icon: Sprite2D:
	get: return _pause_screen_presenter.gold_icon
	set(value): _pause_screen_presenter.gold_icon = value
var pause_gold_text: Sprite2D:
	get: return _pause_screen_presenter.gold_text
	set(value): _pause_screen_presenter.gold_text = value
var pause_soul_text: Sprite2D:
	get: return _pause_screen_presenter.soul_text
	set(value): _pause_screen_presenter.soul_text = value
var pause_resource_icon: Sprite2D:
	get: return _pause_screen_presenter.resource_icon
	set(value): _pause_screen_presenter.resource_icon = value
var pause_status_texts: Array[Sprite2D]:
	get: return _pause_screen_presenter.status_texts
	set(value): _pause_screen_presenter.status_texts = value
var pause_equipment_texts: Array[Sprite2D]:
	get: return _pause_screen_presenter.equipment_texts
	set(value): _pause_screen_presenter.equipment_texts = value
var pause_description_text: Sprite2D:
	get: return _pause_screen_presenter.description_text
	set(value): _pause_screen_presenter.description_text = value
var pause_back_button: Button:
	get: return _pause_screen_presenter.back_button
	set(value): _pause_screen_presenter.back_button = value
var pause_status_button: Button:
	get: return _pause_screen_presenter.status_button
	set(value): _pause_screen_presenter.status_button = value
var pause_equipment_button: Button:
	get: return _pause_screen_presenter.equipment_button
	set(value): _pause_screen_presenter.equipment_button = value
var pause_debug_button: Button:
	get: return _pause_screen_presenter.debug_button
	set(value): _pause_screen_presenter.debug_button = value
var debug_menu_layout: RefCounted:
	get: return _pause_screen_presenter.debug_menu_layout
	set(value): _pause_screen_presenter.debug_menu_layout = value
var debug_menu_buttons: Array[Button]:
	get: return _pause_screen_presenter.debug_menu_buttons
	set(value): _pause_screen_presenter.debug_menu_buttons = value
var debug_menu_row := 0
var hub_item_name_text: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_item_name_text
	set(value): _hub_responsive_layout_presenter.hub_item_name_text = value
var hub_item_list_texts: Array[Sprite2D]:
	get: return _hub_responsive_layout_presenter.hub_item_list_texts
	set(value): _hub_responsive_layout_presenter.hub_item_list_texts = value
var hub_item_row_buttons: Array[Button]:
	get: return _hub_responsive_layout_presenter.hub_item_row_buttons
	set(value): _hub_responsive_layout_presenter.hub_item_row_buttons = value
var hub_shop_price_texts: Array[Sprite2D]:
	get: return _hub_responsive_layout_presenter.hub_shop_price_texts
	set(value): _hub_responsive_layout_presenter.hub_shop_price_texts = value
var hub_item_detail_texts: Array[Sprite2D]:
	get: return _hub_responsive_layout_presenter.hub_item_detail_texts
	set(value): _hub_responsive_layout_presenter.hub_item_detail_texts = value
var hub_item_detail_panel: Panel:
	get: return _hub_responsive_layout_presenter.hub_item_detail_panel
	set(value): _hub_responsive_layout_presenter.hub_item_detail_panel = value
var hub_item_action_button: Button:
	get: return _hub_responsive_layout_presenter.hub_item_action_button
	set(value): _hub_responsive_layout_presenter.hub_item_action_button = value
var hub_shop_mode_buttons: Array[Button]:
	get: return _hub_responsive_layout_presenter.hub_shop_mode_buttons
	set(value): _hub_responsive_layout_presenter.hub_shop_mode_buttons = value
var hub_shop_menu: Control:
	get: return _hub_responsive_layout_presenter.hub_shop_menu
	set(value): _hub_responsive_layout_presenter.hub_shop_menu = value
var hub_equipment_action_buttons: Array[Button]:
	get: return _hub_responsive_layout_presenter.hub_equipment_action_buttons
	set(value): _hub_responsive_layout_presenter.hub_equipment_action_buttons = value
## The authored equipment view is shared by the hub transaction route and the
## read-only Pause Equipment page.  Its nodes are created once by the scenes;
## the controller only supplies textures and state data.
var hub_equipment_menu: Control:
	get: return _hub_responsive_layout_presenter.hub_equipment_menu
	set(value): _hub_responsive_layout_presenter.hub_equipment_menu = value
## Compatibility alias retained for lightweight menu probes that reflect every
## build_hub dictionary key onto the controller by its short name.
var equipment_menu: Control = null
var pause_equipment_menu: Control:
	get: return _pause_screen_presenter.equipment_menu
	set(value): _pause_screen_presenter.equipment_menu = value
var hub_equipment_mode: int:
	get: return _hub_menu_state.hub_equipment_mode
	set(value): _hub_menu_state.hub_equipment_mode = value
var hub_remove_all_confirm_index: int:
	get: return _hub_menu_state.hub_remove_all_confirm_index
	set(value): _hub_menu_state.hub_remove_all_confirm_index = value
var hub_fusion_decrease_button: Button:
	get: return _hub_responsive_layout_presenter.hub_fusion_decrease_button
	set(value): _hub_responsive_layout_presenter.hub_fusion_decrease_button = value
var hub_fusion_increase_button: Button:
	get: return _hub_responsive_layout_presenter.hub_fusion_increase_button
	set(value): _hub_responsive_layout_presenter.hub_fusion_increase_button = value
var title_overlay: ColorRect:
	get: return _title_screen_presenter.overlay
	set(value): _title_screen_presenter.overlay = value
var title_start_button: Button:
	get: return _title_screen_presenter.start_button
	set(value): _title_screen_presenter.start_button = value
var title_continue_button: Button:
	get: return _title_screen_presenter.continue_button
	set(value): _title_screen_presenter.continue_button = value
var title_settings_button: Button:
	get: return _title_screen_presenter.settings_button
	set(value): _title_screen_presenter.settings_button = value
var title_cloud_button: Button:
	get: return _title_screen_presenter.cloud_button
	set(value): _title_screen_presenter.cloud_button = value
var title_frame_timer := 0.0
var title_screen_text: Sprite2D:
	get: return _title_screen_presenter.title_text
	set(value): _title_screen_presenter.title_text = value
var title_start_text: Sprite2D:
	get: return _title_screen_presenter.start_text
	set(value): _title_screen_presenter.start_text = value
var title_settings_text: Sprite2D:
	get: return _title_screen_presenter.settings_text
	set(value): _title_screen_presenter.settings_text = value
var title_cursor_text: Sprite2D:
	get: return _title_screen_presenter.cursor_text
	set(value): _title_screen_presenter.cursor_text = value
var title_menu_row: int:
	get: return _title_screen_presenter.menu_row
	set(value): _title_screen_presenter.menu_row = value
var title_command_list: MenuCommandList:
	get: return _title_screen_presenter.command_list
	set(value): _title_screen_presenter.command_list = value
var title_transition_active := false
var title_transition_timer := 0.0
var title_particle_layer: Node2D = null
var pending_title_destination := ""
var archetype_overlay: ColorRect:
	get: return _archetype_screen_presenter.overlay
	set(value): _archetype_screen_presenter.overlay = value
var archetype_hold_cover: ColorRect:
	get: return _archetype_screen_presenter.hold_cover
	set(value): _archetype_screen_presenter.hold_cover = value
var archetype_preview: Sprite2D:
	get: return _archetype_screen_presenter.preview
	set(value): _archetype_screen_presenter.preview = value
var archetype_name_text: Sprite2D:
	get: return _archetype_screen_presenter.name_text
	set(value): _archetype_screen_presenter.name_text = value
var archetype_preview_frames: Array[Texture2D] = []
var archetype_preview_palette := ""
var archetype_start_button: Button:
	get: return _archetype_screen_presenter.start_button
	set(value): _archetype_screen_presenter.start_button = value
var archetype_left_buttons: Array[Button]:
	get: return _archetype_screen_presenter.left_buttons
	set(value): _archetype_screen_presenter.left_buttons = value
var archetype_right_buttons: Array[Button]:
	get: return _archetype_screen_presenter.right_buttons
	set(value): _archetype_screen_presenter.right_buttons = value
var archetype_type_left_button: Button:
	get: return _archetype_screen_presenter.type_left_button
	set(value): _archetype_screen_presenter.type_left_button = value
var archetype_type_right_button: Button:
	get: return _archetype_screen_presenter.type_right_button
	set(value): _archetype_screen_presenter.type_right_button = value
var archetype_frame_timer := 0.0
var archetype_index := 0
var archetype_color_index := 0
var archetype_menu_row := 0
var archetype_transition_active := false
var archetype_transition_timer := 0.0
var archetype_fade_out := false
var archetype_arrow_anim_timer := 0.0
var archetype_arrow_anim_direction := 0
var selected_archetype := StatsComponent.AllocationProfile.BALANCED
var starter_flame_index := 0
var save_select_overlay: ColorRect:
	get: return _save_select_screen_presenter.overlay
	set(value): _save_select_screen_presenter.overlay = value
var save_select_mode := "continue"
var save_select_index := 0
var save_overwrite_slot := 0
var save_overwrite_prompt_active := false
var save_overwrite_choice := 0
var save_recovery_prompt_active := false
const NAME_ENTRY_COLUMNS := NameEntryWidgetPresenterScript.NAME_ENTRY_COLUMNS
const NAME_ENTRY_ROWS := NameEntryWidgetPresenterScript.NAME_ENTRY_ROWS
var name_entry_overlay: ColorRect:
	get: return _name_entry_screen_controller.widgets.overlay
	set(value): _name_entry_screen_controller.widgets.overlay = value
var name_entry_prompt_text: Sprite2D:
	get: return _name_entry_screen_controller.widgets.prompt_text
	set(value): _name_entry_screen_controller.widgets.prompt_text = value
var name_entry_name_text: Sprite2D:
	get: return _name_entry_screen_controller.widgets.name_text
	set(value): _name_entry_screen_controller.widgets.name_text = value
var name_entry_page_text: Sprite2D:
	get: return _name_entry_screen_controller.widgets.page_text
	set(value): _name_entry_screen_controller.widgets.page_text = value
var name_entry_message_text: Sprite2D:
	get: return _name_entry_screen_controller.widgets.message_text
	set(value): _name_entry_screen_controller.widgets.message_text = value
var name_entry_confirm_text: Sprite2D:
	get: return _name_entry_screen_controller.widgets.confirm_text
	set(value): _name_entry_screen_controller.widgets.confirm_text = value
var name_entry_back_text: Sprite2D:
	get: return _name_entry_screen_controller.widgets.back_text
	set(value): _name_entry_screen_controller.widgets.back_text = value
var name_entry_actions_text: Sprite2D:
	get: return _name_entry_screen_controller.widgets.actions_text
	set(value): _name_entry_screen_controller.widgets.actions_text = value
var name_entry_cursor_text: Sprite2D:
	get: return _name_entry_screen_controller.widgets.cursor_text
	set(value): _name_entry_screen_controller.widgets.cursor_text = value
var name_entry_preview: Sprite2D:
	get: return _name_entry_screen_controller.widgets.preview
	set(value): _name_entry_screen_controller.widgets.preview = value
var name_entry_field_panel: Panel:
	get: return _name_entry_screen_controller.widgets.field_panel
	set(value): _name_entry_screen_controller.widgets.field_panel = value
var name_entry_cell_buttons: Array[Button]:
	get: return _name_entry_screen_controller.widgets.cell_buttons
	set(value): _name_entry_screen_controller.widgets.cell_buttons = value
var name_entry_cell_texts: Array[Sprite2D]:
	get: return _name_entry_screen_controller.widgets.cell_texts
	set(value): _name_entry_screen_controller.widgets.cell_texts = value
var name_entry_name: String:
	get: return _name_entry_screen_controller.name
	set(value): _name_entry_screen_controller.name = value
var name_entry_page: int:
	get: return _name_entry_screen_controller.page
	set(value): _name_entry_screen_controller.page = value
var name_entry_row: int:
	get: return _name_entry_screen_controller.row
	set(value): _name_entry_screen_controller.row = value
var name_entry_column: int:
	get: return _name_entry_screen_controller.column
	set(value): _name_entry_screen_controller.column = value
var name_entry_finish_callback: Callable:
	get: return _name_entry_screen_controller.finish_callback
	set(value): _name_entry_screen_controller.finish_callback = value
var name_entry_cancel_callback: Callable:
	get: return _name_entry_screen_controller.cancel_callback
	set(value): _name_entry_screen_controller.cancel_callback = value
var run_complete_overlay: ColorRect:
	get: return _run_complete_screen_presenter.overlay
	set(value): _run_complete_screen_presenter.overlay = value
var run_complete_texts: Array[Sprite2D]:
	get: return _run_complete_screen_presenter.lines
	set(value): _run_complete_screen_presenter.lines = value
var run_complete_grade_text: Sprite2D:
	get: return _run_complete_screen_presenter.grade_text
	set(value): _run_complete_screen_presenter.grade_text = value
var run_complete_gold_icon: Sprite2D:
	get: return _run_complete_screen_presenter.gold_icon
	set(value): _run_complete_screen_presenter.gold_icon = value
var run_complete_button: Button:
	get: return _run_complete_screen_presenter.return_button
	set(value): _run_complete_screen_presenter.return_button = value
var run_complete_cursor: Sprite2D:
	get: return _run_complete_screen_presenter.cursor
	set(value): _run_complete_screen_presenter.cursor = value
var run_complete_footer_text: Sprite2D:
	get: return _run_complete_screen_presenter.footer_text
	set(value): _run_complete_screen_presenter.footer_text = value
var save_select_footer_text: Sprite2D:
	get: return _save_select_screen_presenter.footer_text
	set(value): _save_select_screen_presenter.footer_text = value
var archetype_footer_text: Sprite2D:
	get: return _archetype_screen_presenter.footer_text
	set(value): _archetype_screen_presenter.footer_text = value
var game_over_overlay: ColorRect:
	get: return _game_over_screen_presenter.overlay
	set(value): _game_over_screen_presenter.overlay = value
var game_over_button: Button:
	get: return _game_over_screen_presenter.restart_button
	set(value): _game_over_screen_presenter.restart_button = value
var game_over_title_button: Button:
	get: return _game_over_screen_presenter.title_button
	set(value): _game_over_screen_presenter.title_button = value
var game_over_cursor_text: Sprite2D:
	get: return _game_over_screen_presenter.cursor_text
	set(value): _game_over_screen_presenter.cursor_text = value
var game_over_footer_text: Sprite2D:
	get: return _game_over_screen_presenter.footer_text
	set(value): _game_over_screen_presenter.footer_text = value
var game_over_row: int:
	get: return _game_over_screen_presenter.row
	set(value): _game_over_screen_presenter.row = value
var game_over_fade_timer: float:
	get: return _game_over_screen_presenter.fade_timer
	set(value): _game_over_screen_presenter.fade_timer = value
var player_palette_name := "blue"
var settings_overlay: ColorRect:
	get: return _settings_screen_presenter.overlay
	set(value): _settings_screen_presenter.overlay = value
var settings_title_text: Sprite2D:
	get: return _settings_screen_presenter.title_text
	set(value): _settings_screen_presenter.title_text = value
var settings_row_labels: Array[Sprite2D]:
	get: return _settings_screen_presenter.row_labels
	set(value): _settings_screen_presenter.row_labels = value
var settings_value_buttons: Array[Button]:
	get: return _settings_screen_presenter.value_buttons
	set(value): _settings_screen_presenter.value_buttons = value
var settings_left_buttons: Array[Button]:
	get: return _settings_screen_presenter.left_buttons
	set(value): _settings_screen_presenter.left_buttons = value
var settings_right_buttons: Array[Button]:
	get: return _settings_screen_presenter.right_buttons
	set(value): _settings_screen_presenter.right_buttons = value
var settings_option_buttons: Array[Array]:
	get: return _settings_screen_presenter.option_buttons
	set(value): _settings_screen_presenter.option_buttons = value
var settings_option_labels: Array[Array]:
	get: return _settings_screen_presenter.option_labels
	set(value): _settings_screen_presenter.option_labels = value
var settings_description_text: Sprite2D:
	get: return _settings_screen_presenter.description_text
	set(value): _settings_screen_presenter.description_text = value
var settings_back_button: Button:
	get: return _settings_screen_presenter.back_button
	set(value): _settings_screen_presenter.back_button = value
var settings_cursor_text: Sprite2D:
	get: return _settings_screen_presenter.cursor_text
	set(value): _settings_screen_presenter.cursor_text = value
var settings_row: int:
	get: return _settings_screen_presenter.row
	set(value): _settings_screen_presenter.row = value
var settings_origin := &"title"
var settings_interact_input_was_down := false
var display_view_size := Vector2(DisplayLayout.NATIVE_SIZE)
var _display_layout_refreshing := false


# --- Display sizing and menu layout reflow ---
func apply_display_layout(root: GameplayState) -> void:
	var display := root.display_controller
	# FULL keeps the authored 160px height but can expose additional logical
	# width when the browser viewport is wider than the configured content size.
	# Menus are full-view overlays, so their frame and responsive anchors must
	# use that visible width instead of the narrower content-scale width.
	display_view_size = display.visible_view_size_value() if display != null and DisplayLayout.is_full_aspect(display.aspect_mode()) else (Vector2(display.view_size_value()) if display != null else Vector2(DisplayLayout.NATIVE_SIZE))
	var game_over := root.game_over_overlay
	for overlay in [title_overlay, save_select_overlay, name_entry_overlay, archetype_overlay, run_complete_overlay, game_over] as Array:
		if overlay != null and bool(overlay.get_meta("display_full_view", false)):
			overlay.size = display_view_size
			_resize_menu_frame(overlay, display_view_size)
	_title_screen_presenter.position_controls(display_view_size, CURSOR_LEFT_GAP, _menu_cursor_animator, self)
	if hub_overlay != null:
		hub_overlay.position = (display_view_size - hub_overlay.size) * 0.5
	if pause_overlay != null:
		pause_overlay.position = (display_view_size - pause_overlay.size) * 0.5
	_position_run_complete_controls()
	_archetype_screen_presenter.position_controls(display_view_size)
	if hub_overlay != null:
		hub_overlay.position = Vector2.ZERO
		hub_overlay.size = display_view_size
		# Orientation changes are geometry reflows, not route transitions. Keep
		# active cursor/glove motion alive while the anchors move.
		_position_hub_controls(false, true)
	if settings_overlay != null:
		settings_overlay.size = display_view_size
		_position_settings_controls()
	var cloud_panel := root.cloud_save_panel
	if cloud_panel != null: cloud_panel.apply_layout(display_view_size)
	if name_entry_overlay != null:
		name_entry_overlay.size = display_view_size
		_position_name_entry_controls()
	if pause_overlay != null:
		pause_overlay.position = Vector2.ZERO
		pause_overlay.size = display_view_size
		_resize_menu_frame(pause_overlay, display_view_size)
		_position_pause_controls(false, true)
	_refresh_active_menu_layout(root)
	_position_game_over_controls(root)
	_save_select_screen_presenter.position_controls(display_view_size)


func _view_size_for_parent(parent: Node) -> Vector2:
	var current: Node = parent
	while current != null:
		var display := current.get("display_controller") as DisplayController
		if display != null:
			return Vector2(display.view_size_value())
		current = current.get_parent()
	return display_view_size


func layout_view_size() -> Vector2:
	return display_view_size


func _hub_left_field_x(native_x: float) -> float:
	return PauseMenuLayoutScript.left_field_x(native_x, display_view_size.x)


func _refresh_active_menu_layout(_root: Object) -> void:
	if _display_layout_refreshing:
		return
	_display_layout_refreshing = true
	# apply_display_layout has already moved every static hub/pause node. The
	# active Hub cursors are re-anchored by _position_hub_controls; no
	# presenter is rebuilt, so scroll offsets, selected rows, draft allocations,
	# and in-progress animations survive an orientation change.
	if hub_overlay != null and hub_overlay.visible and hub_equipment_menu != null and hub_equipment_menu.visible and hub_equipment_menu.has_method("refresh_layout_preserving_state"):
		hub_equipment_menu.call("refresh_layout_preserving_state")
	if hub_overlay != null and hub_overlay.visible and hub_shop_menu != null and hub_shop_menu.visible and hub_shop_menu.has_method("refresh_layout_preserving_state"):
		hub_shop_menu.call("refresh_layout_preserving_state")
	if pause_overlay != null and pause_overlay.visible and pause_equipment_menu != null and pause_equipment_menu.visible and pause_equipment_menu.has_method("refresh_layout_preserving_state"):
		pause_equipment_menu.call("refresh_layout_preserving_state")
	_display_layout_refreshing = false


func create_view_overlay(parent: Node, overlay_name: String, color: Color, z_index: int, visible: bool = true) -> ColorRect:
	display_view_size = _view_size_for_parent(parent)
	var overlay := create_overlay(parent, overlay_name, display_view_size, color, z_index, visible)
	overlay.set_meta("display_full_view", true)
	return overlay

func retro_button_alpha(timer: float) -> float:
	return _menu_widget_factory.retro_button_alpha(timer)

func retro_button_bob(timer: float) -> float:
	return _menu_widget_factory.retro_button_bob(timer)


func _position_game_over_controls(_root: GameplayState) -> void:
	_game_over_screen_presenter.position_controls(display_view_size, _menu_cursor_animator, self, CURSOR_LEFT_GAP)


func _menu_cursor_target(button: Button) -> Vector2:
	var base_y := float(button.get_meta("menu_base_y", button.position.y))
	return Vector2(button.position.x - CURSOR_LEFT_GAP, base_y + 4.0)

# --- Shared menu visuals and screen-state routing ---
func set_archetype_button_state(button: Button, active: bool, color: Color) -> void:
	_menu_widget_factory.set_archetype_button_state(button, active, color)


func set_state(new_state: StringName) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(state)


func set_menu_world_hidden(root: Object, hidden: bool) -> void:
	var gameplay := root as GameplayState
	if gameplay == null:
		return
	var background: CanvasItem = gameplay.background_environment
	var map: CanvasItem = gameplay.map_root
	var actors := gameplay.get_node_or_null("Actors") as CanvasItem
	if hidden:
		if _menu_world_hidden:
			return
		_menu_world_hidden = true
		if background != null:
			_menu_world_background_visible = background.visible
			background.visible = false
		if map != null:
			_menu_world_map_visible = map.visible
			map.visible = false
		if actors != null:
			_menu_world_actors_visible = actors.visible
			actors.visible = false
		return
	if not _menu_world_hidden:
		return
	_menu_world_hidden = false
	if background != null:
		background.visible = _menu_world_background_visible
	if map != null:
		map.visible = _menu_world_map_visible
	if actors != null:
		actors.visible = _menu_world_actors_visible


# --- Title menu flow and command selection ---
func update_title_flow(root: GameplayState, delta: float) -> void:
	var cloud_panel := root.cloud_save_panel
	if cloud_panel != null and cloud_panel.overlay != null and cloud_panel.overlay.visible:
		cloud_panel.update_input()
		return
	if settings_overlay != null and settings_overlay.visible:
		root._update_settings_input()
		return
	if menu_input_release_lock:
		# A confirm used to close title Settings must be released before the title
		# screen can dispatch its focused button. Otherwise BACK immediately falls
		# through to New Game on the next frame.
		var released := not root._is_menu_confirm_pressed() and not root._is_menu_back_pressed()
		if released:
			menu_input_release_lock = false
		else:
			return
	if archetype_overlay != null and archetype_overlay.visible and not title_transition_active:
		update_archetype_input(root, delta)
		return
	if title_transition_active:
		update_particles(delta, Callable(root, "_snap_half_pixel"))
		title_transition_timer += delta
		var overlay := title_overlay
		var fade_start := 0.72
		var fade_duration := 0.42
		# Save selection is still a title-screen state. Keep the black cover
		# opaque while the fizzle runs; fading it out here exposes the live game
		# scene before the save menu has been opened.
		var opening_save_select := pending_title_destination == "save_select"
		overlay.modulate.a = 1.0 if opening_save_select or title_transition_timer < fade_start else clampf(1.0 - (title_transition_timer - fade_start) / fade_duration, 0.0, 1.0)
		if title_transition_timer >= fade_start + fade_duration:
			title_transition_active = false
			if pending_title_destination == "save_select":
				pending_title_destination = ""
				overlay.visible = true
				overlay.modulate.a = 1.0
				root._open_save_select_after_title_transition()
			else:
				overlay.visible = false
				archetype_transition_timer = -0.35
				root._select_archetype_menu_row(0)
		return
	title_frame_timer += delta
	var frame_timer := title_frame_timer
	var new_game := title_start_button
	var continue_button := title_continue_button
	var settings_button := title_settings_button
	var cloud_button := title_cloud_button
	var title_buttons: Array[Button] = [new_game, continue_button, cloud_button, settings_button]
	var visible_index := 0
	for button in title_buttons:
		if button == null or button.disabled or not button.visible: continue
		var phase := visible_index * 0.3
		button.modulate.a = retro_button_alpha(frame_timer + phase)
		var base_y := float(button.get_meta("menu_base_y", 93.0 + visible_index * 16.0))
		button.position.y = base_y
		visible_index += 1
	var command_list := title_command_list
	if command_list != null:
		command_list.configure(title_buttons, [93.0, 109.0, 125.0, 141.0])
		command_list.row = title_menu_row
		if command_list.available_rows().is_empty(): return
		if not command_list.available_rows().has(title_menu_row): title_menu_row = command_list.available_rows()[0]; command_list.row = title_menu_row
		if root._is_menu_direction_just_pressed(&"ui_up"):
			command_list.move_up(); title_menu_row = command_list.row
			root._play_sound("ui_hover", -6.0, 1.0)
		elif root._is_menu_direction_just_pressed(&"ui_down"):
			command_list.move_down(); title_menu_row = command_list.row
			root._play_sound("ui_hover", -6.0, 1.0)
		var cursor := title_cursor_text
		var selected := command_list.selected()
		if cursor != null and selected != null:
			cursor.visible = true
			move_menu_cursor(cursor, _menu_cursor_target(selected))
			cursor.texture = MENU_CURSOR_TEXTURE
		if root._is_menu_confirm_just_pressed() and selected != null and not selected.disabled:
			# Preserve the title transition's original fizzle cue for both NEW GAME
			# and CONTINUE. Generic menu confirms use the authored Confirm sound.
			root._play_sound("enemy_death", -6.0, 0.95)
			selected.pressed.emit()
		return


# --- Archetype selection and preview flow ---
func update_archetype_input(root: GameplayState, delta: float) -> void:
	if archetype_footer_text != null:
		archetype_footer_text.texture = _pixel_prompt_texture(Callable(root, "_pixel_text_texture"), _menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
	if archetype_transition_active:
		archetype_transition_timer += delta
		var transition_timer := archetype_transition_timer
		if transition_timer < 0.0:
			return
		if not archetype_fade_out:
			archetype_hold_cover.visible = false
			archetype_transition_active = false
			return
		archetype_overlay.modulate.a = clampf(1.0 - transition_timer / 0.42, 0.0, 1.0)
		if transition_timer >= 0.42:
			archetype_transition_active = false
			if archetype_fade_out:
				archetype_overlay.visible = false
		return
	if menu_input_release_lock:
		var released := not root._is_menu_confirm_pressed() and not root._is_menu_back_pressed()
		if released: menu_input_release_lock = false
		else: return
	if root._is_menu_back_just_pressed():
		root._cancel_character_creation()
		return
	archetype_frame_timer += delta
	archetype_arrow_anim_timer = maxf(archetype_arrow_anim_timer - delta, 0.0)
	update_archetype_preview_animation(root)
	update_archetype_arrow_animation(root)
	var button := archetype_start_button
	button.modulate.a = retro_button_alpha(archetype_frame_timer)
	button.position.y = 104.0 + retro_button_bob(archetype_frame_timer)
	var row := archetype_menu_row
	if root._is_menu_direction_just_pressed(&"ui_up"):
		select_archetype_menu_row(root, row - 1); root._play_sound("ui_hover", -6.0, 1.0)
	elif root._is_menu_direction_just_pressed(&"ui_down"):
		select_archetype_menu_row(root, row + 1); root._play_sound("ui_hover", -6.0, 1.0)
	elif root._is_menu_direction_just_pressed(&"ui_left") or root._is_menu_direction_just_pressed(&"ui_right"):
		var direction := -1 if root._is_menu_direction_just_pressed(&"ui_left") else 1
		if row == 0: shift_archetype(root, direction)
		else: select_archetype_menu_row(root, 1)
		root._play_sound("ui_hover", -6.0, 1.0)
	if root._is_menu_confirm_just_pressed():
		root._play_sound("ui_confirm", 0.0, 1.0)
		if row == 1: start_selected_archetype(root)
		else: select_archetype_menu_row(root, 1)


func start_selected_archetype(root: GameplayState) -> void:
	if archetype_overlay == null or not archetype_overlay.visible or root.loading_screen_active:
		return
	var profile := root.player_profile
	if profile != null and not profile.has_started:
		var stats := root.player_stats
		stats.manual_allocation_enabled = true
		# Starter aspect selection is presentation/element identity only. Every
		# new player starts from the same even two-point baseline.
		profile.base_vit = 2
		profile.base_str = 2
		profile.base_def = 2
		profile.base_agi = 2
		profile.base_int = 2
		profile.base_mnd = 2
		var starter_flame: StringName = ASPECT_CATALOG_SCRIPT.STARTER_FLAMES[starter_flame_index]
		profile.starter_flame = starter_flame
		profile.allocation_profile = int(StatsComponent.AllocationProfile.BALANCED)
		profile.palette_name = ASPECT_CATALOG_SCRIPT.palette_for_flame(starter_flame)
		profile.has_started = true
		profile.ensure_starter_items()
		root._apply_profile_to_runtime()
		root._save_player_profile()
	archetype_overlay.visible = false
	archetype_hold_cover.visible = false
	root.has_persistent_profile = true
	root._enter_starting_room_from_menu()


func shift_archetype(root: GameplayState, direction: int) -> void:
	starter_flame_index = posmod(starter_flame_index + direction, ASPECT_CATALOG_SCRIPT.STARTER_FLAMES.size())
	archetype_index = starter_flame_index
	archetype_arrow_pulse(root, direction)
	update_archetype_screen(root)


func shift_archetype_color(root: GameplayState, direction: int) -> void:
	archetype_color_index = posmod(archetype_color_index + direction, PaletteLibrary.SELECTABLE_PALETTES.size())
	archetype_arrow_pulse(root, direction)
	update_archetype_screen(root)


func archetype_arrow_pulse(_root: GameplayState, direction: int) -> void:
	archetype_arrow_anim_direction = direction
	archetype_arrow_anim_timer = 0.18


func update_archetype_arrow_animation(_root: GameplayState) -> void:
	var amount: float = clampf(archetype_arrow_anim_timer / 0.18, 0.0, 1.0)
	var pulse: float = 1.0 + amount * 0.22
	archetype_type_left_button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction < 0 and archetype_menu_row == 0 else 1.0)
	archetype_type_right_button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction > 0 and archetype_menu_row == 0 else 1.0)
	for button in archetype_left_buttons: button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction < 0 and archetype_menu_row == 1 else 1.0)
	for right_button in archetype_right_buttons: right_button.scale = Vector2.ONE * (pulse if archetype_arrow_anim_direction > 0 and archetype_menu_row == 1 else 1.0)


func select_archetype_menu_row(root: GameplayState, row: int) -> void:
	archetype_menu_row = posmod(row, 2)
	update_archetype_screen(root)


func update_archetype_screen(root: GameplayState) -> void:
	var display := root.get("display_controller") as DisplayController
	var view_width: float = layout_view_size().x
	var flame: StringName = ASPECT_CATALOG_SCRIPT.STARTER_FLAMES[starter_flame_index]
	var flame_name: String = ASPECT_CATALOG_SCRIPT.display_name(flame)
	var flame_palette: String = ASPECT_CATALOG_SCRIPT.palette_for_flame(flame)
	archetype_name_text.texture = root.call("_pixel_text_texture", flame_name, PaletteLibrary.normal(flame_palette) if archetype_menu_row == 0 else Color.WHITE) as Texture2D
	archetype_name_text.position = Vector2((view_width - archetype_name_text.texture.get_width()) * 0.5, 36)
	var colors: Array[String] = [flame_palette]
	var cached_palette_frames: Dictionary = root.player_animation_component.frames_by_palette.get(flame_palette, {}) as Dictionary
	var preview_source_frames: Array[Texture2D] = []
	var idle_value: Variant = cached_palette_frames.get("idle")
	if idle_value is Array:
		for frame: Texture2D in idle_value:
			preview_source_frames.append(frame)
	if preview_source_frames.is_empty():
		for frame in root.player_animation_component.idle_frames:
			preview_source_frames.append(root.player_animation_component.recolor_texture(frame, flame_palette))
	if not preview_source_frames.is_empty():
		if archetype_preview_palette != colors[0] or archetype_preview_frames.size() != preview_source_frames.size():
			archetype_preview_frames.clear()
			archetype_preview_palette = colors[0]
			for frame in preview_source_frames: archetype_preview_frames.append(frame)
		update_archetype_preview_animation(root)
	update_archetype_button_styles(root)


func update_archetype_preview_animation(root: GameplayState) -> void:
	if archetype_preview == null or archetype_preview_frames.is_empty(): return
	var frame_time: float = maxf(root.player_tuning.idle_frame_time, 0.01)
	var frame_index: int = posmod(int(archetype_frame_timer / frame_time), archetype_preview_frames.size())
	archetype_preview.texture = archetype_preview_frames[frame_index]
	var display := root.get("display_controller") as DisplayController
	var view_width: float = layout_view_size().x
	archetype_preview.position = Vector2((view_width - archetype_preview.texture.get_width() * archetype_preview.scale.x) * 0.5, 48)


func start_save_select(root: GameplayState, mode: String) -> void:
	if title_overlay == null or not title_overlay.visible:
		return
	save_select_mode = mode
	pending_title_destination = "save_select"
	root._spawn_title_ui_breakup()
	title_overlay.visible = true
	title_overlay.modulate.a = 1.0
	title_transition_active = true
	title_transition_timer = 0.0
	if title_screen_text != null: title_screen_text.visible = false
	var version := title_overlay.get_node_or_null("TitleVersion") as Sprite2D
	if version != null: version.visible = false
	if title_start_text != null: title_start_text.visible = false
	if title_start_button != null: title_start_button.visible = false; title_start_button.release_focus()
	if title_continue_button != null: title_continue_button.visible = false; title_continue_button.release_focus()
	if title_settings_button != null: title_settings_button.visible = false; title_settings_button.release_focus()
	if title_cloud_button != null: title_cloud_button.visible = false; title_cloud_button.release_focus()
	if title_cursor_text != null: title_cursor_text.visible = false


func show_character_creation(root: GameplayState) -> void:
	if title_overlay == null or archetype_overlay == null:
		return
	title_overlay.visible = false
	title_transition_active = false
	pending_title_destination = ""
	archetype_overlay.visible = true
	archetype_overlay.modulate.a = 1.0
	archetype_overlay.z_index = 3
	set_state(&"archetype")
	if archetype_hold_cover != null: archetype_hold_cover.visible = false
	archetype_transition_active = false
	menu_input_release_lock = true
	root._select_archetype_menu_row(0)


# --- Player death and game-over transitions ---
func update_player_death(root: GameplayState, delta: float, game_over_fade_time: float) -> void:
	var death_timer := root.player_death_timer + delta
	root.player_death_timer = death_timer
	var overlay := root.player_death_overlay
	var tuning := root.player_tuning
	if overlay != null:
		if death_timer < tuning.death_particle_delay:
			overlay.modulate.a = clampf(death_timer / tuning.death_fade_time, 0.0, 1.0)
		elif not root.player_death_particles_started:
			root.player_death_particles_started = true; root._spawn_player_death_pixels(); overlay.queue_free(); root.player_death_overlay = null
			root._play_sound("enemy_death", -4.0, 0.90 + RandomNumberGenerator.new().randf_range(-0.06, 0.06))
	if not root.player_death_particles_started:
		return
	var death_effect_end := tuning.death_particle_delay + tuning.death_particle_lifetime
	var game_over := game_over_overlay
	if game_over != null and game_over.visible:
		var fade_timer := game_over_fade_timer + delta
		var restart := game_over_button
		var title := game_over_title_button
		var selected := title if game_over_row == 1 and title != null and not title.disabled else restart
		if selected != null:
			game_over_row = 1 if selected == title else 0
		_position_game_over_controls(root)
		var footer_prompt := _pixel_prompt_texture(Callable(root, "_pixel_text_texture"), _menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
		_game_over_screen_presenter.update_fade(fade_timer, game_over_fade_time, footer_prompt, _menu_widget_factory)
	elif death_timer >= death_effect_end + tuning.death_observe_time:
		root._show_game_over()


func update_game_over_input(root: GameplayState) -> void:
	var overlay := game_over_overlay
	if overlay == null or not overlay.visible:
		return
	if menu_input_release_lock:
		if not root._is_menu_confirm_pressed() and not root._is_menu_back_pressed():
			menu_input_release_lock = false
		else:
			return
	var restart := game_over_button
	var title := game_over_title_button
	if root._is_menu_back_just_pressed():
		if title != null and not title.disabled:
			root._play_sound("ui_decline", 0.0, 1.0)
			title.pressed.emit()
		return
	if root._is_menu_direction_just_pressed(&"ui_up") or root._is_menu_direction_just_pressed(&"ui_down"):
		game_over_row = 1 - game_over_row
		root._play_sound("ui_hover", -6.0, 1.0)
	var selected := title if game_over_row == 1 else restart
	if selected == null or selected.disabled:
		selected = restart if restart != null and not restart.disabled else title
	if selected != null:
		game_over_row = 1 if selected == title else 0
		if game_over_cursor_text != null:
			game_over_cursor_text.visible = true
			move_menu_cursor(game_over_cursor_text, Vector2(selected.position.x - CURSOR_LEFT_GAP, selected.position.y + 3.0))
	if game_over_footer_text != null:
		game_over_footer_text.visible = true
		game_over_footer_text.texture = _pixel_prompt_texture(Callable(root, "_pixel_text_texture"), _menu_back_prompt_for(root), Color8(148, 220, 255)) as Texture2D
	if root._is_menu_confirm_just_pressed() and selected != null and not selected.disabled:
		root._play_sound("ui_confirm", 0.0, 1.0)
		selected.pressed.emit()


func update_archetype_button_styles(_root: Object) -> void:
	var flame: StringName = ASPECT_CATALOG_SCRIPT.STARTER_FLAMES[starter_flame_index]
	var color := PaletteLibrary.normal(ASPECT_CATALOG_SCRIPT.palette_for_flame(flame)); var row := archetype_menu_row
	var type_active := row == 0; var sprite_active := false; var start_active := row == 1
	var type_left := archetype_type_left_button; var type_right := archetype_type_right_button; var start := archetype_start_button
	set_archetype_button_state(type_left, type_active, color); set_archetype_button_state(type_right, type_active, color)
	for button in archetype_left_buttons: set_archetype_button_state(button, sprite_active, color)
	for button in archetype_right_buttons: set_archetype_button_state(button, sprite_active, color)
	set_archetype_button_state(start, start_active, color)


# --- Title-particle compatibility facade ---
func add_particle(particle_data: Dictionary) -> void:
	_title_particle_controller.add_particle(particle_data)


func clear_title_particles() -> void:
	_title_particle_controller.clear_title_particles()


func update_particles(delta: float, snap_position: Callable) -> void:
	_title_particle_controller.update_particles(delta, snap_position)


func spawn_pixel_breakup(source_sprite: Sprite2D, particle_parent: Node, pixel_texture: Callable, random_seed: int) -> void:
	_title_particle_controller.spawn_pixel_breakup(source_sprite, particle_parent, pixel_texture, random_seed)


func spawn_button_frame_breakup(button: Button, particle_parent: Node, pixel_texture: Callable, random_seed: int) -> void:
	_title_particle_controller.spawn_button_frame_breakup(button, particle_parent, pixel_texture, random_seed)


# --- Menu widget factory compatibility facade ---
func style_archetype_button(button: Button) -> void:
	_menu_widget_factory.style_archetype_button(button)


func make_retro_button(label: String, button_position: Vector2, size: Vector2, pixel_texture: Callable) -> Button:
	return _menu_widget_factory.make_retro_button(label, button_position, size, pixel_texture)


func make_menu_command_button(label: String, button_position: Vector2, size: Vector2, pixel_texture: Callable) -> Button:
	return _menu_widget_factory.make_menu_command_button(label, button_position, size, pixel_texture)


# --- Game-over and run-complete screens ---
func build_game_over(parent: Node, pixel_texture: Callable, restart: Callable, return_title: Callable) -> void:
	display_view_size = _view_size_for_parent(parent)
	_game_over_screen_presenter.build(parent, display_view_size, pixel_texture, restart, return_title, _menu_widget_factory)


func build_run_complete(parent: Node, pixel_texture: Callable, return_to_hub: Callable) -> void:
	display_view_size = _view_size_for_parent(parent)
	_run_complete_screen_presenter.build(parent, display_view_size, pixel_texture, return_to_hub, _menu_widget_factory)


func _add_menu_frame(overlay: ColorRect, panel_size: Vector2) -> void:
	_menu_widget_factory.add_menu_frame(overlay, panel_size)


func _resize_menu_frame(overlay: ColorRect, panel_size: Vector2) -> void:
	_menu_widget_factory.resize_menu_frame(overlay, panel_size)


func _position_run_complete_controls() -> void:
	_run_complete_screen_presenter.position_controls(display_view_size, _menu_cursor_animator, self, CURSOR_LEFT_GAP)


func _menu_card_style() -> StyleBoxFlat:
	return _menu_widget_factory.menu_card_style()


func _make_menu_card(parent: Node, card_name: String, card_position: Vector2, card_size: Vector2) -> Panel:
	return _menu_widget_factory.make_menu_card(parent, card_name, card_position, card_size)


func _make_transparent_touch_button(parent: Node, button_name: String, button_position: Vector2, button_size: Vector2, callback: Callable = Callable(), callback_arg: Variant = null) -> Button:
	return _menu_widget_factory.make_transparent_touch_button(parent, button_name, button_position, button_size, callback, callback_arg)


# --- Hub and pause screen construction ---
func build_hub(parent: Node, pixel_texture: Callable, actions: HubScreenActions) -> void:
	display_view_size = _view_size_for_parent(parent)
	var overlay := DEMON_HUB_MENU_SCENE.instantiate() as ColorRect
	if overlay == null:
		return
	overlay.name = "HubOverlay"
	overlay.position = Vector2.ZERO
	overlay.size = display_view_size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.z_index = 3
	overlay.visible = false
	overlay.set_meta("display_full_view", true)
	parent.add_child(overlay)
	# HubPreview* nodes are persistent editor-authoring guides. They make every
	# visible piece selectable in demon_hub_menu.tscn, while runtime presenters
	# own the live profile-dependent copies.
	for preview_node in overlay.get_children():
		if preview_node is CanvasItem and String(preview_node.name).begins_with("HubPreview"):
			(preview_node as CanvasItem).visible = false

	_hub_page_visibility_presenter.build_pages(overlay, pixel_texture)
	var root_page := hub_root_page
	var status_page := _hub_page_visibility_presenter.status_page
	var allocate_page := _hub_page_visibility_presenter.allocate_page
	var items_page := _hub_page_visibility_presenter.items_page
	var equipment_menu_node := items_page.get_node_or_null("EquipmentMenu") as EquipmentMenuLayout if items_page != null else null
	var shop_menu := items_page.get_node_or_null("ShopMenu") as ShopMenuLayout if items_page != null else null
	var fusion_menu := items_page.get_node_or_null("FusionMenu") as FusionMenuLayout if items_page != null else null
	hub_equipment_menu = equipment_menu_node
	self.equipment_menu = equipment_menu_node
	hub_shop_menu = shop_menu
	hub_fusion_menu = fusion_menu
	if equipment_menu_node != null:
		equipment_menu_node.visible = false
		if equipment_menu_node.has_method("set_pixel_texture"):
			equipment_menu_node.call("set_pixel_texture", pixel_texture)
		if equipment_menu_node.has_method("set_read_only"):
			equipment_menu_node.call("set_read_only", false)
	var bind_page := _hub_page_visibility_presenter.bind_page
	var bind_menu := bind_page.get_node_or_null("BindMenu") as BindMenuLayout if bind_page != null else null
	hub_bind_menu = bind_menu
	_hub_stats_presenter.build(
		allocate_page,
		status_page,
		overlay,
		display_view_size,
		pixel_texture,
		actions,
		_menu_widget_factory,
		Callable(self, "make_archetype_arrow")
	)

	hub_summary_text = _hub_responsive_layout_presenter.build_shell_chrome(
		root_page,
		overlay,
		_menu_widget_factory,
		HUB_GOLD_TEXTURE,
		SoulVisualsScript.texture()
	)
	hub_currency_text = _hub_responsive_layout_presenter.hub_gold_text
	hub_currency_icon = _hub_responsive_layout_presenter.hub_soul_icon
	_hub_command_shell_presenter.build_navigation(root_page, overlay, display_view_size, pixel_texture, actions, _menu_widget_factory)

	var item_name := create_sprite(items_page, "HubItemName", null, Vector2(14, 25), false)
	var item_list_panel := _make_menu_card(items_page, "HubItemListPanel", Vector2(14, 35), Vector2(150, 66))
	var item_content_clip := Control.new()
	item_content_clip.name = "HubItemContentClip"
	item_content_clip.position = Vector2(14, 35)
	item_content_clip.size = Vector2(150, 66)
	item_content_clip.clip_contents = true
	item_content_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	items_page.add_child(item_content_clip)
	var item_list: Array[Sprite2D] = []
	for list_index in HubResponsiveLayoutPresenterScript.LEGACY_ITEM_VISIBLE_ROWS:
		item_list.append(create_sprite(item_content_clip, "HubItemList%d" % list_index, null, Vector2(6, 4 + list_index * 10), false))
	var item_row_buttons: Array[Button] = []
	for list_index in HubResponsiveLayoutPresenterScript.LEGACY_ITEM_VISIBLE_ROWS:
		item_row_buttons.append(_make_transparent_touch_button(item_content_clip, "HubItemRow%d" % list_index, Vector2(0, list_index * 10), Vector2(150, 10), actions.select_item_row, list_index))
	var shop_prices: Array[Sprite2D] = []
	for list_index in HubResponsiveLayoutPresenterScript.LEGACY_ITEM_VISIBLE_ROWS:
		shop_prices.append(create_sprite(items_page, "HubShopPrice%d" % list_index, null, Vector2(174, 39 + list_index * 10), false))
	var gear_slot_buttons: Array[Button] = []
	for slot_index in ItemCatalog.SLOTS.size():
		gear_slot_buttons.append(_make_transparent_touch_button(item_content_clip, "HubGearSlot%d" % slot_index, Vector2(0, slot_index * 12), Vector2(150, 12), actions.select_gear_slot, slot_index))
	# Equipment has two distinct levels of information: the upper window always
	# remains the six equipped slots, while the lower window is the temporary
	# inventory picker for the selected slot. Keeping a separate clip prevents
	# candidate labels and slot labels from ever sharing the same pixels or hit
	# regions when the picker is open.
	var gear_choice_panel := _make_menu_card(items_page, "HubGearChoicePanel", Vector2(14, 91), Vector2(150, 42))
	gear_choice_panel.visible = false
	var gear_choice_content_clip := Control.new()
	gear_choice_content_clip.name = "HubGearChoiceContentClip"
	gear_choice_content_clip.position = Vector2(14, 91)
	gear_choice_content_clip.size = Vector2(150, 42)
	gear_choice_content_clip.clip_contents = true
	gear_choice_content_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_choice_content_clip.visible = false
	items_page.add_child(gear_choice_content_clip)
	var gear_choices: Array[Sprite2D] = []
	var gear_choice_buttons: Array[Button] = []
	for choice_index in HubResponsiveLayoutPresenterScript.LEGACY_GEAR_CHOICE_VISIBLE_ROWS:
		gear_choices.append(create_sprite(gear_choice_content_clip, "HubGearChoice%d" % choice_index, null, Vector2(6, 4 + choice_index * 10), false))
		var choice_button := _make_transparent_touch_button(gear_choice_content_clip, "HubGearChoiceButton%d" % choice_index, Vector2(0, choice_index * 10), Vector2(150, 10), actions.select_gear_candidate, choice_index)
		gear_choice_buttons.append(choice_button)
	var gear_stat_panel := Panel.new()
	gear_stat_panel.name = "HubGearStatPanel"; gear_stat_panel.position = Vector2(174, 35); gear_stat_panel.size = Vector2(maxf(display_view_size.x - 188.0, 48.0), 66); gear_stat_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_stat_panel.add_theme_stylebox_override("panel", _menu_card_style()); items_page.add_child(gear_stat_panel)
	var gear_stats: Array[Sprite2D] = []
	for stat_index in 6:
		gear_stats.append(create_sprite(items_page, "HubGearStat%d" % stat_index, null, Vector2(180, 41 + stat_index * 9), false))
	var item_detail_panel := _make_menu_card(items_page, "HubItemDetailPanel", Vector2(14, HUB_ITEM_DETAIL_PANEL_TOP), Vector2(maxf(display_view_size.x - 28.0, 80.0), HUB_ITEM_DETAIL_PANEL_HEIGHT))
	item_detail_panel.visible = false
	var item_details: Array[Sprite2D] = []
	for detail_index in 6:
		item_details.append(create_sprite(items_page, "HubItemDetail%d" % detail_index, null, Vector2(20, HUB_ITEM_DETAIL_TOP + detail_index * HUB_ITEM_DETAIL_PITCH), false))
	var item_action_button := make_retro_button("BUY", Vector2(maxf(96.0, display_view_size.x - 70.0), 119), Vector2(52, 13), pixel_texture)
	item_action_button.focus_mode = Control.FOCUS_NONE; item_action_button.pressed.connect(actions.item_action); items_page.add_child(item_action_button)
	for mode_index in 2:
		var mode_button := make_retro_button("BUY" if mode_index == 0 else "SELL", Vector2(132 + mode_index * 42, 21), Vector2(36, 13), pixel_texture)
		mode_button.focus_mode = Control.FOCUS_NONE
		mode_button.pressed.connect(func(selected_mode: int = mode_index):
			hub_shop_sell_mode = selected_mode == 1
			hub_shop_sell_confirm_pending = false
			hub_action_column = selected_mode
			hub_content_focus = true
			hub_shop_command_focus = false
			hub_item_index = 0
			hub_list_scroll = 0.0)
		items_page.add_child(mode_button)
		hub_shop_mode_buttons.append(mode_button)
	var equipment_actions: Array[Button] = []
	var equip_action := make_retro_button("EQUIP", Vector2(14, 22), Vector2(42, 12), pixel_texture)
	equip_action.name = "HubEquipmentEquip"; equip_action.focus_mode = Control.FOCUS_NONE; equip_action.pressed.connect(actions.item_action); items_page.add_child(equip_action); equipment_actions.append(equip_action)
	var remove_action := make_retro_button("REMOVE", Vector2(64, 22), Vector2(50, 12), pixel_texture)
	remove_action.name = "HubEquipmentRemove"; remove_action.focus_mode = Control.FOCUS_NONE
	if actions.equipment_remove.is_valid(): remove_action.pressed.connect(actions.equipment_remove)
	items_page.add_child(remove_action); equipment_actions.append(remove_action)
	var remove_all_action := make_retro_button("REMOVE ALL", Vector2(122, 22), Vector2(62, 12), pixel_texture)
	remove_all_action.name = "HubEquipmentRemoveAll"; remove_all_action.focus_mode = Control.FOCUS_NONE
	if actions.equipment_remove_all.is_valid(): remove_all_action.pressed.connect(actions.equipment_remove_all)
	items_page.add_child(remove_all_action); equipment_actions.append(remove_all_action)
	var fusion_decrease_button := make_retro_button("<", Vector2(14, 119), Vector2(22, 13), pixel_texture)
	fusion_decrease_button.name = "HubFusionDecrease"; fusion_decrease_button.focus_mode = Control.FOCUS_NONE
	if actions.adjust_fusion_count.is_valid(): fusion_decrease_button.pressed.connect(actions.adjust_fusion_count.bind(-1))
	items_page.add_child(fusion_decrease_button)
	var fusion_increase_button := make_retro_button(">", Vector2(39, 119), Vector2(22, 13), pixel_texture)
	fusion_increase_button.name = "HubFusionIncrease"; fusion_increase_button.focus_mode = Control.FOCUS_NONE
	if actions.adjust_fusion_count.is_valid(): fusion_increase_button.pressed.connect(actions.adjust_fusion_count.bind(1))
	items_page.add_child(fusion_increase_button)
	var binding_panel := Panel.new()
	binding_panel.name = "HubBindingPanel"; binding_panel.position = Vector2(14, 33); binding_panel.size = Vector2(maxf(display_view_size.x - 28.0, 80.0), 72); binding_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	binding_panel.add_theme_stylebox_override("panel", _menu_card_style()); bind_page.add_child(binding_panel)
	var binding_texts: Array[Sprite2D] = []
	binding_texts.append(create_sprite(bind_page, "HubBindingCurrent", null, Vector2(22, 41), false))
	binding_texts.append(create_sprite(bind_page, "HubBindingBound", null, Vector2(22, 53), false))
	binding_texts.append(create_sprite(bind_page, "HubBindingSouls", null, Vector2(22, 65), false))
	binding_texts.append(create_sprite(bind_page, "HubBindingCost", null, Vector2(22, 77), false))
	binding_texts.append(create_sprite(bind_page, "HubBindingMessage", null, Vector2(22, 91), false))
	var binding_action_button := make_retro_button("BIND", Vector2(display_view_size.x - 78.0, 119), Vector2(64, 13), pixel_texture)
	binding_action_button.focus_mode = Control.FOCUS_NONE
	if actions.bind_element.is_valid(): binding_action_button.pressed.connect(actions.bind_element)
	bind_page.add_child(binding_action_button)
	_hub_command_shell_presenter.build_cursor(root_page, _menu_widget_factory)
	var list_cursor := create_sprite(items_page, "HubListCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); list_cursor.visible = false
	var shop_cursor := create_sprite(items_page, "HubShopCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); shop_cursor.visible = false
	hub_shop_cursor = shop_cursor
	var slot_cursor := create_sprite(items_page, "HubSlotCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); slot_cursor.visible = false
	var choice_cursor := create_sprite(items_page, "HubChoiceCursor", MENU_CURSOR_TEXTURE, Vector2.ZERO, false); choice_cursor.visible = false
	if shop_menu != null:
		shop_menu.set_pixel_texture(pixel_texture)
	if fusion_menu != null:
		fusion_menu.set_pixel_texture(pixel_texture)
	if bind_menu != null:
		bind_menu.set_pixel_texture(pixel_texture)
	_hub_menu_signal_binder.bind(
		equipment_menu,
		shop_menu,
		fusion_menu,
		bind_menu,
		actions,
		Callable(self, "_set_hub_action_column")
	)
	hub_item_list_panel = item_list_panel
	hub_item_content_clip = item_content_clip
	hub_gear_choice_panel = gear_choice_panel
	hub_gear_choice_content_clip = gear_choice_content_clip
	hub_item_detail_panel = item_detail_panel

	# Keep this controller's handles for the overlay and retain transaction
	# widget references through their typed presenters, not a string-keyed bag.
	hub_overlay = overlay
	hub_start_button = null
	hub_title_button = null
	hub_item_name_text = item_name
	hub_item_list_texts = item_list
	hub_item_row_buttons = item_row_buttons
	hub_shop_price_texts = shop_prices
	hub_gear_choice_texts = gear_choices
	hub_gear_choice_buttons = gear_choice_buttons
	hub_gear_slot_buttons = gear_slot_buttons
	hub_gear_stat_texts = gear_stats
	hub_gear_stat_panel = gear_stat_panel
	hub_binding_panel = binding_panel
	hub_binding_texts = binding_texts
	hub_binding_action_button = binding_action_button
	hub_list_cursor = list_cursor
	hub_slot_cursor = slot_cursor
	hub_choice_cursor = choice_cursor
	hub_item_detail_texts = item_details
	hub_item_action_button = item_action_button
	hub_equipment_action_buttons = equipment_actions
	hub_fusion_decrease_button = fusion_decrease_button
	hub_fusion_increase_button = fusion_increase_button
	_hub_item_visibility_presenter.bind(
		_hub_responsive_layout_presenter,
		shop_cursor,
		_menu_widget_factory,
		_menu_prompt_texture_factory,
		_menu_cursor_animator,
		self
	)
	_hub_input_controller.bind(_hub_stats_presenter, _hub_responsive_layout_presenter)
	_pause_screen_presenter.build(parent, display_view_size, pixel_texture, actions, _menu_widget_factory, Callable(self, "_set_hub_action_column"))
	var pause_debug_page_handler := Callable(self, "_forward_pause_debug_page_requested")
	if not _pause_screen_presenter.debug_page_requested.is_connected(pause_debug_page_handler):
		_pause_screen_presenter.debug_page_requested.connect(pause_debug_page_handler)
	var pause_debug_action_handler := Callable(self, "_forward_pause_debug_action_requested")
	if not _pause_screen_presenter.debug_action_requested.is_connected(pause_debug_action_handler):
		_pause_screen_presenter.debug_action_requested.connect(pause_debug_action_handler)
	pause_resume_button = null
	pause_player_card_panel = null


func _set_hub_action_column(index: int) -> void:
	hub_action_column = index


func _forward_pause_debug_page_requested() -> void:
	debug_page_requested.emit()


func _forward_pause_debug_action_requested(action: StringName, amount: int) -> void:
	debug_action_requested.emit(action, amount)


func _make_menu_page(parent: Node, page_name: String) -> Control:
	var page := Control.new()
	page.name = page_name
	page.position = Vector2.ZERO
	page.size = display_view_size
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(page)
	return page


func _add_menu_title(overlay: ColorRect, title_name: String, label: String, pixel_texture: Callable) -> Sprite2D:
	return _menu_widget_factory.add_menu_title(overlay, title_name, label, pixel_texture, display_view_size)


# --- Hub and pause control positioning ---
func _position_menu_cursor(cursor: Sprite2D, target: Vector2, animate: bool = false, preserve_motion: bool = false) -> void:
	_menu_cursor_animator.position_menu_cursor(cursor, target, animate, preserve_motion, self)


func _position_hub_stat_markers(selected_row: int, marker_visible: bool) -> void:
	_hub_stats_presenter.position_markers(selected_row, marker_visible, display_view_size)


func _set_hub_stat_adjustment_targets(selected_row: int, enabled: bool) -> void:
	_hub_stats_presenter.set_adjustment_targets(selected_row, enabled)


func _position_hub_controls(animate_cursor: bool = false, preserve_cursor_motion: bool = false) -> void:
	if hub_overlay == null:
		return
	var context := _hub_responsive_layout_context
	context.overlay = hub_overlay
	context.view_size = display_view_size
	context.page = hub_page
	context.content_focus = hub_content_focus
	context.stat_row = hub_stat_row
	context.action_column = hub_action_column
	context.gear_browsing = hub_gear_browsing
	context.menu_row = hub_menu_row
	context.is_root = hub_is_root
	context.animate_cursor = animate_cursor
	context.preserve_cursor_motion = preserve_cursor_motion
	context.pages = _hub_page_visibility_presenter
	context.stats = _hub_stats_presenter
	context.commands = _hub_command_shell_presenter
	context.cursor_animator = _menu_cursor_animator
	context.tween_owner = self
	_hub_responsive_layout_presenter.position_controls(context)

func _position_pause_controls(animate_cursor: bool = false, preserve_cursor_motion: bool = false) -> void:
	if pause_overlay == null:
		return
	var width := display_view_size.x
	var height := display_view_size.y
	pause_overlay.position = Vector2.ZERO
	pause_overlay.size = display_view_size
	_resize_menu_frame(pause_overlay, display_view_size)
	for page_root: Control in pause_page_roots.values():
		page_root.position = Vector2.ZERO
		page_root.size = display_view_size
		var page_background := page_root.get_node_or_null("Background") as NinePatchRect
		if page_background != null: page_background.size = display_view_size
		var page_title_rule := page_root.get_node_or_null("TitleRule") as ColorRect
		if page_title_rule != null: page_title_rule.size.x = maxf(width - 16.0, 16.0)
	var divider_x := PauseMenuLayoutScript.divider_x(width)
	var panel_root := pause_overlay.get_node_or_null("PausePanel8Piece") as Control
	if panel_root != null:
		panel_root.position = Vector2.ZERO
		panel_root.size = display_view_size
	var command_divider := pause_overlay.get_node_or_null("CommandDivider") as ColorRect
	if command_divider != null:
		command_divider.position = Vector2(divider_x - 1.0, 2.0)
		command_divider.size = Vector2(1.0, maxf(PauseMenuLayoutScript.upper_rail_height(height) - 2.0, 1.0))
	var resource_divider := pause_overlay.get_node_or_null("ResourceDivider") as ColorRect
	if resource_divider != null:
		resource_divider.position = Vector2(divider_x, height - PauseMenuLayoutScript.RESOURCE_PANEL_HEIGHT)
		resource_divider.size = Vector2(maxf(width - divider_x - 1.0, 1.0), 1.0)
	for index in pause_menu_buttons.size(): pause_menu_buttons[index].position = PauseMenuLayoutScript.command_button_position(display_view_size, index)
	if debug_menu_layout != null: debug_menu_layout.call("apply_layout", display_view_size)
	if pause_back_button != null: pause_back_button.position = PauseMenuLayoutScript.back_button_position(display_view_size)
	if pause_player_portrait != null:
		pause_player_portrait.position = Vector2(PauseMenuLayoutScript.left_field_x(PauseMenuLayoutScript.PLAYER_PORTRAIT_POSITION.x, width), PauseMenuLayoutScript.PLAYER_PORTRAIT_POSITION.y)
	for index in pause_player_card_texts.size():
		var authored_position: Vector2 = PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS[index] if index < PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.size() else PauseMenuLayoutScript.PLAYER_CARD_TEXT_POSITIONS.back()
		pause_player_card_texts[index].position = Vector2(PauseMenuLayoutScript.left_field_x(authored_position.x, width), authored_position.y)
	for index in pause_status_texts.size():
		var column := 0 if index < STATUS_LEFT_ROW_COUNT else 1
		var row := index if index < STATUS_LEFT_ROW_COUNT else index - STATUS_LEFT_ROW_COUNT
		var authored_x := 14.0 if column == 0 else 122.0
		pause_status_texts[index].position = Vector2(PauseMenuLayoutScript.left_field_x(authored_x, width), 28 + row * 10)
	for index in pause_equipment_texts.size(): pause_equipment_texts[index].position = Vector2(14, 28 + index * 12)
	if pause_equipment_menu != null:
		pause_equipment_menu.position = Vector2.ZERO
		pause_equipment_menu.size = display_view_size
	if pause_description_text != null: pause_description_text.position = PauseMenuLayoutScript.select_prompt_position(display_view_size)
	if pause_gold_icon != null: pause_gold_icon.position = PauseMenuLayoutScript.resource_icon_position(display_view_size, false)
	if pause_resource_icon != null: pause_resource_icon.position = PauseMenuLayoutScript.resource_icon_position(display_view_size, true)
	_position_pause_resource_texts()
	if pause_cursor_text != null and not pause_menu_buttons.is_empty():
		var cursor_index := clampi(pause_menu_row, 0, pause_menu_buttons.size() - 1)
		_position_menu_cursor(pause_cursor_text, Vector2(pause_menu_buttons[cursor_index].position.x - CURSOR_LEFT_GAP, pause_menu_buttons[cursor_index].position.y + 3.0), animate_cursor, preserve_cursor_motion)


func _position_pause_resource_texts() -> void:
	_pause_screen_presenter.position_resource_texts(display_view_size)


func _reset_hub_cursor_layer() -> void:
	# Every hub render starts from an empty legacy cursor layer.  Each presenter
	# branch then opts in exactly the cursor(s) it owns, so Shop/Fusion and the
	# nested Equipment route cannot accumulate visible or still-tweening hands.
	for cursor in [hub_cursor_text, hub_stat_cursor_text, hub_list_cursor, hub_slot_cursor, hub_choice_cursor]:
		if cursor == null:
			continue
		cursor.visible = false
		cursor.modulate = ACTIVE_CURSOR_MODULATE
		if cursor.has_method("stop_motion"):
			cursor.call("stop_motion")


# --- Legacy hub presenters and shop calculations ---
func _hide_legacy_equipment_presenter() -> void:
	_hub_legacy_widget_visibility_presenter.hide_equipment_legacy(_hub_responsive_layout_presenter)


func _hide_legacy_shop_presenter() -> void:
	_hub_legacy_widget_visibility_presenter.hide_shop_legacy(_hub_responsive_layout_presenter)


func _shop_stat_comparison(_root: GameplayState, profile: PlayerProfile, catalog: ItemCatalog, item: ItemInstance) -> Array[Dictionary]:
	return _hub_transaction_menu_presenter.shop_stat_comparison(profile, catalog, item)


# --- Hub sub-screen rendering: fusion, binding, and shop ---
func _render_fusion_menu(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile) -> void:
	if hub_fusion_menu == null or profile == null:
		return
	var view := hub_fusion_menu
	var context := _hub_transaction_menu_context
	context.profile = profile
	context.catalog = ItemCatalog.new()
	context.fusion_candidates = root._hub_fusion_candidates()
	context.fusion_state = 0 if hub_is_root else hub_fusion_state
	context.fusion_item_selected = hub_fusion_item_selected
	context.selected_index = hub_item_index
	context.scroll = hub_list_scroll
	context.fusion_count = hub_fusion_count
	context.fusion_message = hub_fusion_message
	context.fusion_details.clear()
	if not context.fusion_candidates.is_empty():
		var selected := context.fusion_candidates[clampi(hub_item_index, 0, context.fusion_candidates.size() - 1)]
		var economy := root.hub_flow_controller.get("economy_controller") as RefCounted
		context.fusion_details = economy.call("fusion_candidate_details", root, selected) as Dictionary
	var model := _hub_transaction_menu_presenter.build_fusion_model(context)
	view.call("set_pixel_texture", pixel_texture)
	view.call("render_fusion", model)


func _fusion_item_label(catalog: ItemCatalog, profile: PlayerProfile, item: ItemInstance) -> String:
	return _hub_transaction_menu_presenter.fusion_item_label(catalog, profile, item)


func _render_bind_menu(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, highlight_color: Color) -> void:
	if hub_bind_menu == null or profile == null:
		return
	var view := hub_bind_menu
	var model := BindMenuModelScript.new()
	model.state = 0 if hub_is_root else hub_binding_state
	var chroma := root.player_chroma_component
	var current_aspect := chroma.call("aspect_name") as StringName if chroma != null else &"gray"
	model.current_element = ASPECT_CATALOG_SCRIPT.display_name(current_aspect)
	model.current_is_bound = profile.has_bound_element and profile.bound_element == current_aspect
	model.bound_element = ASPECT_CATALOG_SCRIPT.display_name(profile.bound_element) if profile.has_bound_element else "NONE"
	model.soul_count = profile.souls
	model.bind_cost = PlayerProfile.ELEMENT_BIND_SOUL_COST
	model.can_bind = current_aspect != &"gray" and profile.can_bind_element(current_aspect) and not model.current_is_bound and profile.souls >= model.bind_cost
	model.action_label = "BIND" if not model.current_is_bound else "BOUND"
	model.action_color = highlight_color
	model.status_message = hub_binding_message
	if model.status_message.is_empty():
		model.status_message = "READY TO BIND" if model.can_bind else "BIND UNAVAILABLE"
	view.call("set_pixel_texture", pixel_texture)
	view.call("render", model)


func _render_shop_menu(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, _highlight_color: Color) -> void:
	if hub_shop_menu == null or profile == null:
		return
	var view := hub_shop_menu
	var context := _hub_transaction_menu_context
	context.profile = profile
	context.catalog = ItemCatalog.new()
	context.sell_mode = hub_shop_sell_mode
	context.state = hub_shop_state
	context.items.clear()
	context.prices.clear()
	context.soul_values.clear()
	context.sold_flags.clear()
	context.item_slots.clear()
	context.sell_owned_counts.clear()
	if context.sell_mode:
		context.items = root._hub_shop_sellable_items()
		for item: ItemInstance in context.items:
			context.item_slots.append(context.catalog.definition_slot(item.definition_id))
			context.prices.append("%d" % context.catalog.sell_value(item))
			context.soul_values.append(context.catalog.sell_soul_value(item))
			context.sold_flags.append(false)
			context.sell_owned_counts.append(root._hub_shop_owned_matching_count(item))
	else:
		var run_state := root.run_state
		if run_state != null:
			run_state.ensure_shop_stock(profile)
			for entry: Dictionary in run_state.shop_stock:
				var item := ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary)
				context.items.append(item)
				context.item_slots.append(context.catalog.definition_slot(item.definition_id))
				var sold := bool(entry.get("sold", false))
				context.sold_flags.append(sold)
				context.prices.append("SOLD" if sold else "%d" % int(entry.get("price", 0)))
				context.soul_values.append(0)
				context.sell_owned_counts.append(0)
	var count := context.items.size()
	context.selected_index = clampi(hub_item_index, 0, maxi(count - 1, 0))
	hub_item_index = context.selected_index
	context.scroll = clampf(hub_list_scroll, 0.0, float(maxi(0, count - ShopMenuLayoutScript.VISIBLE_ROWS)))
	hub_list_scroll = context.scroll
	context.owned_count = 0
	context.max_quantity = 1
	context.quantity = hub_shop_sell_amount
	context.batch_value.clear()
	if count > 0:
		var selected_item := context.items[context.selected_index]
		if context.sell_mode:
			context.owned_count = root._hub_shop_owned_matching_count(selected_item)
			context.max_quantity = maxi(context.owned_count, 1)
		else:
			for data: Dictionary in profile.inventory:
				if ItemInstance.from_dictionary(data).inventory_stack_key() == selected_item.inventory_stack_key():
					context.owned_count += 1
		if context.sell_mode and hub_shop_state == ShopMenuLayoutScript.SELL_AMOUNT:
			context.batch_value = root._hub_shop_batch_value(selected_item, clampi(context.quantity, 1, maxi(context.owned_count, 1)))
	var model := _hub_transaction_menu_presenter.build_shop_model(context)
	hub_shop_sell_amount = model.quantity
	hub_shop_sell_amount_max = model.max_quantity
	view.call("render_model", model, pixel_texture)


# --- Hub page and player-card rendering ---
func update_hub_ui(root: GameplayState, pixel_texture: Callable) -> void:
	var profile := root.player_profile
	if profile == null: return
	# Fusion is a child of the shared Items page, so page-root visibility alone
	# cannot hide it when another route returns early below (notably BIND).
	# Reset this before any page-specific branch to prevent presenter bleed.
	_hub_page_visibility_presenter.prepare_fusion_visibility(hub_page, hub_fusion_menu)
	_reset_hub_cursor_layer()
	# The reworked hub keeps its title/command shell on screen while the
	# selected command previews its content underneath. Entering a command only
	# changes focus; it no longer swaps away the top shell.
	if hub_page == HUB_PAGE_STATUS:
		# STATUS no longer has a hub presenter. Normalize direct legacy writes to
		# the merged STATS route before any visibility or input decision.
		hub_page = HUB_PAGE_ALLOCATE
	_hub_page_visibility_presenter.show_page(hub_overlay, hub_page)
	_update_player_card(root._menu_player_context(), pixel_texture, hub_player_card_texts)
	# The previous root card is no longer part of the hub rework. Keep its data
	# refreshed for compatibility callers, but never let it draw over the live
	# command preview in HubContentPanel.
	if hub_player_card_panel != null: hub_player_card_panel.visible = false
	for card_text in hub_player_card_texts: card_text.visible = false
	var page := hub_page
	var equipment_view_active := _hub_page_visibility_presenter.update_transaction_menu_visibility(
		page,
		hub_content_focus,
		hub_is_root,
		hub_equipment_menu,
		hub_shop_menu,
		hub_fusion_menu,
		hub_back_button,
		pixel_texture
	)
	# Page changes alter the height of the shared inventory card (Equipment uses
	# six compact slot rows; Shop/Fusion use the larger inventory rows).
	_position_hub_controls()
	var page_buttons := hub_page_buttons
	var highlight_color := PaletteLibrary.accent(player_palette_name)
	highlight_color = root._health_feedback_color(player_palette_name)
	for page_index in page_buttons.size():
		page_buttons[page_index].visible = true
		page_buttons[page_index].mouse_filter = Control.MOUSE_FILTER_STOP
		# The command rail is pure navigation: the hand cursor marks the selected
		# command. No box or text highlight may draw around a command, matching the
		# mockup where only the cursor indicates selection.
		set_archetype_button_state(page_buttons[page_index], false, highlight_color)
		_set_menu_button_icon(page_buttons[page_index], null, false)
	# The command cursor stays as a dimmed breadcrumb while a nested route is open.
	_hub_command_shell_presenter.update_cursor_for_page(
		page,
		hub_menu_row,
		hub_is_root,
		_menu_cursor_animator,
		self
	)
	_hub_stats_interaction_presenter.update_cursor_for_page(
		_hub_stats_presenter,
		page,
		hub_content_focus,
		hub_stat_row,
		hub_action_column,
		display_view_size,
		_menu_cursor_animator,
		self
	)
	var title := hub_root_page.get_node_or_null("Title") as Sprite2D if hub_root_page != null else null
	if title != null:
		var title_texture := pixel_texture.call("DEMON HUB", Color.WHITE) as Texture2D
		title.texture = title_texture
	if hub_points_text != null: hub_points_text.visible = page == HUB_PAGE_ALLOCATE
	var confirm_prompt := _menu_confirm_prompt_for(root)
	if page == HUB_PAGE_EQUIPMENT:
		confirm_prompt = confirm_prompt.replace("SELECT", "EQUIP")
	var back_prompt := _menu_back_prompt_for(root)
	var confirm_prompt_texture := _pixel_prompt_texture(pixel_texture, confirm_prompt, Color.WHITE) as Texture2D
	var back_prompt_texture := _pixel_prompt_texture(pixel_texture, back_prompt, Color.WHITE) as Texture2D
	_hub_responsive_layout_presenter.update_footer_content(
		page,
		equipment_view_active,
		confirm_prompt_texture,
		back_prompt_texture,
		pixel_texture
	)
	if hub_currency_text != null:
		# Legacy single-currency alias: the visible footer now has both rows.
		hub_currency_text.visible = false
		hub_currency_text.texture = null
	if hub_gold_text != null:
		hub_gold_text.visible = true
		hub_gold_text.texture = pixel_texture.call(str(profile.gold), Color8(255, 205, 117)) as Texture2D
	if hub_soul_text != null:
		hub_soul_text.visible = true
		hub_soul_text.texture = pixel_texture.call(str(profile.souls), SoulVisualsScript.SOUL_HIGHLIGHT_COLOR) as Texture2D
	if hub_gold_icon != null: hub_gold_icon.visible = true
	if hub_soul_icon != null: hub_soul_icon.visible = true
	# The counts are regenerated above, so their widths can change (for example
	# when a player reaches a new digit). Re-apply the right edge anchor after the
	# textures exist instead of leaving a newly widened number one pixel off.
	_position_hub_controls()
	_hub_stats_interaction_presenter.update_page_visibility(
		_hub_stats_presenter,
		page,
		hub_is_root,
		hub_content_focus,
		hub_stat_row
	)
	_update_hub_item_visibility(profile, page, highlight_color)
	if hub_binding_panel != null: hub_binding_panel.visible = page == HUB_PAGE_BIND
	for node in hub_binding_texts: node.visible = page == HUB_PAGE_BIND
	if hub_binding_action_button != null:
		hub_binding_action_button.visible = page == HUB_PAGE_BIND and not hub_is_root
		hub_binding_action_button.mouse_filter = Control.MOUSE_FILTER_STOP if hub_content_focus else Control.MOUSE_FILTER_IGNORE
	if hub_bind_menu != null:
		hub_bind_menu.visible = page == HUB_PAGE_BIND
		if page != HUB_PAGE_BIND and hub_bind_menu.has_method("stop_cursor_motion"):
			hub_bind_menu.call("stop_cursor_motion")
	if page == HUB_PAGE_BIND:
		if hub_binding_panel != null: hub_binding_panel.visible = false
		for node in hub_binding_texts: node.visible = false
		if hub_binding_action_button != null:
			hub_binding_action_button.visible = false
			hub_binding_action_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if hub_bind_menu != null:
			hub_bind_menu.visible = true
			_render_bind_menu(root, pixel_texture, profile, highlight_color)
			return
		_update_hub_binding_page(root, pixel_texture, profile, highlight_color)
		return
	if page == HUB_PAGE_STATUS:
		_update_hub_status_page(root, pixel_texture, profile, highlight_color)
		return
	if page == HUB_PAGE_EQUIPMENT and hub_equipment_menu != null:
		# Keep the legacy arrays populated for existing callers, but never leave
		# the old inventory presenter visible underneath the authored scene. Its
		# cursors are always hidden by the reset at the top of this render.
		_hide_legacy_equipment_presenter()
		for cursor in [hub_list_cursor, hub_slot_cursor, hub_choice_cursor]:
			if cursor != null: cursor.visible = false
		_render_equipment_menu(root, pixel_texture, profile, highlight_color)
		return
	if page == HUB_PAGE_SHOP and hub_shop_menu != null:
		_hide_legacy_shop_presenter()
		_render_shop_menu(root, pixel_texture, profile, highlight_color)
		return
	if hub_fusion_menu != null:
		hub_fusion_menu.visible = page == HUB_PAGE_FUSION
		if page != HUB_PAGE_FUSION and hub_fusion_menu.has_method("stop_cursor_motion"):
			hub_fusion_menu.call("stop_cursor_motion")
	if page == HUB_PAGE_FUSION and hub_fusion_menu != null:
		_hide_legacy_shop_presenter()
		_render_fusion_menu(root, pixel_texture, profile)
		return
	if page != HUB_PAGE_ALLOCATE:
		_update_hub_item_page(root, pixel_texture, profile, page, hub_item_list_texts, hub_item_detail_texts, hub_item_action_button, highlight_color)
		return
	_update_hub_allocation_page(root, pixel_texture, profile, highlight_color)


func _update_hub_item_visibility(profile: PlayerProfile, page: int, highlight_color: Color) -> void:
	var context := _hub_item_visibility_context
	context.profile = profile
	context.page = page
	context.content_focus = hub_content_focus
	context.is_root = hub_is_root
	context.equipment_action_focus = hub_equipment_action_focus
	context.gear_browsing = hub_gear_browsing
	context.item_index = hub_item_index
	context.action_column = hub_action_column
	context.shop_command_focus = hub_shop_command_focus
	context.highlight_color = highlight_color
	_hub_item_visibility_presenter.update(context)


func _update_hub_allocation_page(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, highlight_color: Color) -> void:
	var pending: Array[int] = [hub_pending_vit, hub_pending_str, hub_pending_def, hub_pending_agi, hub_pending_int, hub_pending_mnd]
	_hub_stats_presenter.update_allocation_page(
		root,
		pixel_texture,
		profile,
		pending,
		hub_stat_row,
		hub_content_focus,
		hub_action_column,
		display_view_size,
		highlight_color,
		_menu_widget_factory,
		_menu_prompt_texture_factory
	)

func _update_player_card(context: MenuPlayerContext, pixel_texture: Callable, texts: Array[Sprite2D], summary: Sprite2D = null) -> void:
	if texts.is_empty() or context == null or not context.is_valid():
		return
	var profile := context.profile
	var max_health := context.max_health()
	var health := context.current_health()
	var xp_required := PlayerProfile.xp_required_for_level(profile.level, context.progression_tuning)
	var values := [
		PlayerProfile.normalize_player_name(profile.player_name),
		context.element_display_name(),
		"LV %d" % profile.level,
		"XP %d/%d" % [profile.xp, xp_required],
		"HP %d/%d" % [health, max_health],
		"CHR %d/%d" % [context.chroma(), context.max_chroma()],
		"READY",
	]
	for index in texts.size():
		var label: String = str(values[index]) if index < values.size() else ""
		var label_color := Color8(255, 205, 117) if index == 3 else Color.WHITE
		if index == 1:
			label_color = PaletteLibrary.accent(context.palette_name)
		texts[index].texture = pixel_texture.call(label, label_color) as Texture2D
	if summary != null:
		summary.visible = true


# --- Hub stats and pause-screen presentation ---
func _update_hub_status_page(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, _highlight_color: Color) -> void:
	var updated := _hub_stats_presenter.update_status_page(root, pixel_texture, profile)
	if updated and hub_context_text != null:
		hub_context_text.texture = null

func update_pause_ui(root: Object, pixel_texture: Callable) -> void:
	if pause_overlay == null or not pause_overlay.visible:
		return
	var highlight := PaletteLibrary.accent(player_palette_name)
	for page_root: Control in pause_page_roots.values(): page_root.visible = false
	var active_page := pause_page_roots.get(pause_page) as Control
	if active_page != null: active_page.visible = true
	var showing_root := pause_page == 0
	var pause_equipment_view_active := pause_page == 2 and pause_equipment_menu != null
	if pause_equipment_menu != null:
		pause_equipment_menu.visible = pause_equipment_view_active
		if pause_equipment_menu.has_method("stop_cursor_motion"):
			pause_equipment_menu.call("stop_cursor_motion")
		if pause_equipment_view_active:
			pause_equipment_menu.set_pixel_texture(pixel_texture)
	var pause_equipment_page_root := pause_page_roots.get(2) as Control
	if pause_equipment_page_root != null:
		for chrome_name in ["Background", "TitleTab", "Title", "TitleRule"]:
			var chrome := pause_equipment_page_root.get_node_or_null(chrome_name) as CanvasItem
			if chrome != null: chrome.visible = not pause_equipment_view_active
	var root_panel := pause_overlay.get_node_or_null("PausePanel8Piece") as Control
	if root_panel != null: root_panel.visible = showing_root
	var menu_player_context: MenuPlayerContext = (root as GameplayState)._menu_player_context() if root is GameplayState else null
	_pause_screen_presenter.update_player_info(menu_player_context, pixel_texture, display_view_size)
	var settings := root.get("settings_service") as SettingsService
	var debug_menu_enabled := settings != null and bool(settings.get_setting(&"debug_menu_enabled", false))
	for index in pause_menu_buttons.size():
		var button := pause_menu_buttons[index]
		var debug_command_hidden := index == 3 and not debug_menu_enabled
		button.visible = pause_page == 0 and not debug_command_hidden
		button.disabled = debug_command_hidden
		# The command rail is intentionally text-only. The cursor is the sole
		# selected-state treatment, matching the Demon Hub and FFIII reference.
		set_archetype_button_state(button, false, highlight)
		_set_menu_button_icon(button, null, false)
	if pause_back_button != null:
		pause_back_button.visible = not pause_equipment_view_active
		set_archetype_button_state(pause_back_button, false, highlight)
	var back_prompt := _menu_back_prompt_for(root)
	var confirm_prompt := _menu_confirm_prompt_for(root)
	_set_button_text(pause_back_button, back_prompt, pixel_texture, PauseMenuLayoutScript.MUTED_TEXT_COLOR)
	for node in pause_status_texts: node.visible = pause_page == 1
	for node in pause_equipment_texts: node.visible = pause_page == 2 and not pause_equipment_view_active
	if pause_description_text != null:
		pause_description_text.visible = not pause_equipment_view_active
		pause_description_text.texture = _pixel_prompt_texture(pixel_texture, confirm_prompt, PauseMenuLayoutScript.MUTED_TEXT_COLOR) as Texture2D
	if pause_gold_icon != null: pause_gold_icon.visible = showing_root
	if pause_resource_icon != null: pause_resource_icon.visible = showing_root
	if pause_gold_text != null: pause_gold_text.visible = showing_root
	if pause_soul_text != null: pause_soul_text.visible = showing_root
	if pause_page == 1:
		_pause_screen_presenter.update_status(menu_player_context, pixel_texture)
	elif pause_page == 2:
		var pause_profile: PlayerProfile = menu_player_context.profile if menu_player_context != null else root.get("player_profile") as PlayerProfile
		if pause_equipment_view_active:
			_render_equipment_menu(root, pixel_texture, pause_profile, highlight, pause_equipment_menu, false)
			return
		_pause_screen_presenter.update_equipment(pause_profile, pixel_texture)
	elif pause_page == 3:
		refresh_debug_menu(root)
	if pause_cursor_text != null and not pause_menu_buttons.is_empty():
		var cursor_index := clampi(pause_menu_row, 0, pause_menu_buttons.size() - 1)
		pause_cursor_text.visible = pause_page == 0
		move_menu_cursor(pause_cursor_text, Vector2(pause_menu_buttons[cursor_index].position.x - CURSOR_LEFT_GAP, pause_menu_buttons[cursor_index].position.y + 3.0))


func set_pause_page(root: Object, page: int) -> void:
	pause_page = clampi(page, 0, 3)
	# A pause page transition is a fresh route entry. Never carry a touch
	# candidate arm from Hub Equipment (or an earlier pause page) into it.
	hub_touch_candidate_slot = ""
	hub_touch_candidate_index = -1
	if pause_page == 2:
		# Pause Equipment shares the live equipment flow, but always enters at its
		# top command row just like the Demon Hub route.
		hub_equipment_mode = EquipmentMenuLayout.MODE_COMMAND
		hub_equipment_action_focus = true
		hub_gear_browsing = false
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	elif pause_page == 1:
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	elif pause_page == 3:
		debug_menu_row = 0
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
	update_pause_ui(root, Callable(root, "_pixel_text_texture"))


func is_pause_equipment_active() -> bool:
	return pause_overlay != null and pause_overlay.visible and pause_page == 2


func refresh_equipment_menu(root: Object) -> void:
	if is_pause_equipment_active():
		update_pause_ui(root, Callable(root, "_pixel_text_texture"))
	else:
		update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func pause_back(root: Object) -> void:
	if pause_page != 0:
		set_pause_page(root, 0)
		root.call("_play_sound", "ui_decline", 0.0, 1.0)
		return
	root.call("_close_hub_to_run")


func pause_equipment_back(root: Object) -> void:
	if hub_equipment_mode == EquipmentMenuLayout.MODE_REMOVE_ALL_CONFIRM:
		root.call("_cancel_hub_remove_all")
	elif hub_gear_browsing:
		root.call("_close_hub_gear_browse")
	elif not hub_equipment_action_focus:
		hub_equipment_action_focus = true
		hub_equipment_mode = EquipmentMenuLayout.MODE_COMMAND
		hub_touch_candidate_slot = ""
		hub_touch_candidate_index = -1
		refresh_equipment_menu(root)
		root.call("_play_sound", "ui_decline", 0.0, 1.0)
	else:
		pause_back(root)


# --- Hub binding and equipment presentation ---
func _update_hub_binding_page(root: Object, pixel_texture: Callable, profile: PlayerProfile, highlight_color: Color) -> void:
	if hub_binding_texts.size() < 5 or profile == null:
		return
	var chroma := root.get("player_chroma_component") as Node
	var current_aspect := &"gray"
	var current_is_bound := false
	if chroma != null:
		current_aspect = chroma.call("aspect_name") as StringName
		current_is_bound = bool(chroma.call("current_is_bound"))
	var current := ASPECT_CATALOG_SCRIPT.display_name(current_aspect)
	var bound := "NONE"
	if profile.has_bound_element:
		bound = String(profile.bound_element).to_upper()
	var cost := PlayerProfile.ELEMENT_BIND_SOUL_COST
	var can_bind := bool(root.call("_can_bind_current_element"))
	var enough_souls := profile.souls >= cost
	var action_enabled := can_bind and enough_souls
	var action_color := highlight_color if action_enabled else Color8(102, 108, 122) if not can_bind or not enough_souls else Color.WHITE
	hub_binding_texts[0].texture = pixel_texture.call("CURRENT %s%s" % [current, " BOUND" if current_is_bound else ""], highlight_color if can_bind else Color.WHITE) as Texture2D
	hub_binding_texts[1].texture = pixel_texture.call("BOUND %s" % bound, Color.WHITE) as Texture2D
	hub_binding_texts[2].texture = pixel_texture.call("SOULS %d" % profile.souls, Color8(211, 167, 255)) as Texture2D
	hub_binding_texts[3].texture = pixel_texture.call("COST %d SOULS" % cost, Color8(255, 205, 117)) as Texture2D
	var status := hub_binding_message
	if status.is_empty():
		if current_aspect == &"gray":
			status = "ATTUNE FIRST"
		elif current_is_bound:
			status = "ALREADY BOUND"
		elif not enough_souls:
			status = "NEED %d SOULS" % cost
		else:
			status = "READY TO BIND"
	hub_binding_texts[4].texture = pixel_texture.call(status, Color8(255, 105, 105) if not action_enabled and current_aspect != &"gray" and not current_is_bound else Color8(167, 240, 112)) as Texture2D
	if hub_binding_action_button != null:
		hub_binding_action_button.disabled = not action_enabled
		var action_label := hub_binding_action_button.get_child(0) as Sprite2D
		if action_label != null:
			var label := "BIND" if action_enabled else "BOUND" if current_is_bound else "NONE" if current_aspect == &"gray" else "NEED 50S"
			action_label.texture = pixel_texture.call(label, action_color) as Texture2D
		set_archetype_button_state(hub_binding_action_button, action_enabled, highlight_color)


## Compatibility facade; the render mode now belongs to HubMenuState.
func _equipment_mode_for_render() -> int:
	return _hub_menu_state.equipment_mode_for_render()


func _equipment_bonus_lines(catalog: ItemCatalog, item: ItemInstance) -> Array[String]:
	return _hub_equipment_menu_presenter.equipment_bonus_lines(catalog, item)


func _equipment_item_description(catalog: ItemCatalog, item: ItemInstance) -> Array[String]:
	return _hub_equipment_menu_presenter.equipment_item_description(catalog, item)


func _equipment_item_label(catalog: ItemCatalog, item: ItemInstance) -> String:
	return _hub_equipment_menu_presenter.equipment_item_label(catalog, item)

func _compact_equipment_navigation_prompt(prompt: String, fallback: String) -> String:
	# Face-art prompts already fit the authored 78-pixel cell. Keyboard and
	# touch labels such as "ENTER SELECT"/"ESC BACK" do not, so retain the
	# action word while preserving the same device-aware prompt on gamepads.
	if _menu_face_texture_for_prompt(prompt) != null:
		return prompt
	var tokens := prompt.strip_edges().split(" ", false)
	return str(tokens[tokens.size() - 1]) if not tokens.is_empty() else fallback


func _render_equipment_menu(root: GameplayState, pixel_texture: Callable, profile: PlayerProfile, _highlight_color: Color, target_view: Control = null, read_only: bool = false) -> void:
	var view := (target_view if target_view != null else hub_equipment_menu) as EquipmentMenuLayout
	if view == null or profile == null:
		return
	var selected_slot_index := clampi(_hub_menu_state.hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var selected_slot := ItemCatalog.SLOTS[selected_slot_index]
	var confirm_prompt := _compact_equipment_navigation_prompt(_menu_confirm_prompt_for(root), "SELECT")
	var back_prompt := _compact_equipment_navigation_prompt(_menu_back_prompt_for(root), "BACK")
	var context := _hub_equipment_menu_context
	context.view = view
	context.menu_state = _hub_menu_state
	context.profile = profile
	context.pixel_texture = pixel_texture
	context.navigation_texture = _pixel_prompt_sequence_texture(pixel_texture, [confirm_prompt, back_prompt], Color.WHITE, 9, 2) as Texture2D
	context.portrait_texture = root._equipment_portrait_texture()
	context.stat_snapshot = root._player_stat_snapshot()
	context.player_stats = root.player_stats
	context.selected_slot_candidates = root._hub_gear_candidates(selected_slot)
	context.legacy_slot_texts = hub_item_list_texts
	context.legacy_candidate_texts = hub_gear_choice_texts
	context.read_only = read_only
	context.show_navigation = target_view != null
	_hub_equipment_menu_presenter.render(context)

# --- Hub inventory and gear details ---
func _update_hub_item_page(root: Object, pixel_texture: Callable, profile: PlayerProfile, page: int, item_list: Array[Sprite2D], details: Array[Sprite2D], action: Button, highlight_color: Color) -> void:
	var catalog := ItemCatalog.new()
	var shop_prices := hub_shop_price_texts
	for detail in details:
		detail.texture = null
		detail.visible = false
	if page == 1:
		_update_hub_gear_slots(root, pixel_texture, profile, catalog, item_list, hub_gear_choice_texts, details, action, highlight_color)
		return
	var item: ItemInstance = null
	var price := 0
	var sold := false
	var index := hub_item_index
	var count := 0
	if page == 1:
		count = profile.inventory.size()
		if count > 0: item = ItemInstance.from_dictionary(profile.inventory[clampi(index, 0, count - 1)])
	elif page == 2:
		if hub_shop_sell_mode:
			var sellable := root.call("_hub_shop_sellable_items") as Array[ItemInstance]
			count = sellable.size()
			if count > 0:
				item = sellable[clampi(index, 0, count - 1)]
				price = catalog.sell_value(item)
		else:
			var run_state := root.get("run_state") as RunState
			if run_state != null:
				run_state.ensure_shop_stock(profile); count = run_state.shop_stock.size()
				if count > 0:
					var entry: Dictionary = run_state.shop_stock[clampi(index, 0, count - 1)]
					item = ItemInstance.from_dictionary(entry.get("item", {}) as Dictionary); price = int(entry.get("price", 0)); sold = bool(entry.get("sold", false))
	else:
		var fusion_items := root.call("_hub_fusion_candidates") as Array[ItemInstance]
		count = fusion_items.size()
		if count > 0:
			item = fusion_items[clampi(index, 0, count - 1)]
	var selected := clampi(index, 0, maxi(count - 1, 0))
	if hub_item_name_text != null:
		if item != null:
			var header_name: String = catalog.gear_name(item)
			if item.enhancement_level > 0: header_name += " F%d" % item.enhancement_level
			hub_item_name_text.texture = pixel_texture.call("%d/%d %s" % [selected + 1, count, header_name], catalog.rarity_color(item.rarity)) as Texture2D
		else:
			hub_item_name_text.texture = pixel_texture.call("0/0 NO ITEMS", Color8(140, 145, 160)) as Texture2D
		hub_item_name_text.visible = true
	var item_pitch := 10.0
	var visible_rows := item_list.size()
	hub_list_scroll = clampf(hub_list_scroll, 0.0, maxf(0.0, float(count - visible_rows)))
	_apply_hub_item_scroll(item_pitch)
	var window_start := int(hub_list_scroll)
	var scroll_frac: float = hub_list_scroll - float(window_start)
	for row in item_list.size():
		var source_index := window_start + row
		if source_index >= count:
			item_list[row].texture = null
			if row < shop_prices.size(): shop_prices[row].texture = null
			continue
		if row < hub_item_row_buttons.size():
			hub_item_row_buttons[row].visible = (page == 2 or page == 3) and hub_content_focus
			hub_item_row_buttons[row].mouse_filter = Control.MOUSE_FILTER_STOP if hub_item_row_buttons[row].visible else Control.MOUSE_FILTER_IGNORE
		var row_item: ItemInstance
		var row_sold := false
		var row_price := 0
		if page == 1:
			row_item = ItemInstance.from_dictionary(profile.inventory[source_index])
		elif page == 2:
			if hub_shop_sell_mode:
				# Keep the legacy list renderer on the same grouped sell rows as
				# _render_shop_menu.  Rebuilding directly from inventory makes plain
				# copies appear as separate rows and bypasses OWNED:x quantities.
				var sellable_rows := root.call("_hub_shop_sellable_items") as Array[ItemInstance]
				row_item = sellable_rows[source_index]
				row_price = catalog.sell_value(row_item)
			else:
				var row_state := root.get("run_state") as RunState
				var row_entry: Dictionary = row_state.shop_stock[source_index]
				row_item = ItemInstance.from_dictionary(row_entry.get("item", {}) as Dictionary); row_sold = bool(row_entry.get("sold", false)); row_price = int(row_entry.get("price", 0))
		else:
			var fusion_items := root.call("_hub_fusion_candidates") as Array[ItemInstance]
			if source_index >= fusion_items.size():
				item_list[row].texture = null; continue
			row_item = fusion_items[source_index]
		var rarity_mark := catalog.rarity_letter_grade(row_item.rarity)
		var row_label := "%s %s" % [rarity_mark, catalog.gear_name(row_item)]
		var row_mastery := row_item.enhancement_level
		if row_mastery > 0 and page != 3: row_label += " F%d" % row_mastery
		if page == 2 and row_sold: row_label += " SOLD"
		elif page == 3: row_label += "  F%d" % row_mastery
		if page == 3:
			var row_slot := catalog.definition_slot(row_item.definition_id)
			if profile.get_equipped_instance_id(row_slot) == row_item.instance_id:
				row_label += " E"
		var row_color := highlight_color if source_index == selected else Color8(120, 120, 130) if row_sold else catalog.rarity_color(row_item.rarity)
		item_list[row].texture = pixel_texture.call(row_label, row_color) as Texture2D
		if page == 2 and row < shop_prices.size():
			var sell_text := "%dG + %dS" % [row_price, catalog.sell_soul_value(row_item)] if hub_shop_sell_mode else ("SOLD" if row_sold else "%dG" % row_price)
			shop_prices[row].texture = pixel_texture.call(sell_text, highlight_color if source_index == selected else Color8(120, 120, 130) if row_sold else Color8(255, 205, 117)) as Texture2D
	# The hand cursor marks the selected row and moves with the scrolled content.
	if hub_list_cursor != null:
		var selected_visible_slot := selected - window_start
		if hub_content_focus and selected_visible_slot >= 0 and selected_visible_slot < item_list.size() and item != null:
			hub_list_cursor.visible = true
			var cursor_row_y := 35.0 + 4.0 + float(selected_visible_slot) * item_pitch - scroll_frac * item_pitch
			move_menu_cursor(hub_list_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, cursor_row_y + 3.0), false)
		else:
			hub_list_cursor.visible = false
	if item == null:
		if not item_list.is_empty():
			var empty_text := hub_fusion_message if page == 3 and not hub_fusion_message.is_empty() else ("NO FUSE / SALVAGE" if page == 3 else "NO ITEMS")
			item_list[0].texture = pixel_texture.call(empty_text, Color8(255, 205, 117) if page == 3 else Color.WHITE) as Texture2D
		for detail in details: detail.texture = null
		for stale_stat in hub_gear_stat_texts: stale_stat.texture = null
		if hub_item_detail_panel != null: hub_item_detail_panel.visible = true
		action.disabled = true
		return
	var mastery := item.enhancement_level
	var bonuses := catalog.bonuses(item, mastery); var bonus_parts: Array[String] = []
	if page != 3:
		for stat: String in bonuses:
			if stat == "speed":
				continue
			var bonus_label: String = str({"health_rate": "HP", "damage_rate": "DMG"}.get(stat, stat.to_upper()))
			var value := float(bonuses[stat])
			bonus_parts.append("%s %s%.1f" % [bonus_label, "+" if value > 0 else "", value])
		if not bonus_parts.is_empty():
			details[0].texture = pixel_texture.call("  ".join(bonus_parts), Color.WHITE) as Texture2D
			details[0].visible = not bonus_parts.is_empty()
	var selected_transmutation_name := catalog.transmutation_name(item.transmutation_id)
	if page == 3 and not selected_transmutation_name.is_empty():
		details[0].texture = pixel_texture.call("SPECIAL: %s" % selected_transmutation_name, Color8(148, 220, 255)) as Texture2D
		details[0].visible = true
	elif page == 3:
		details[0].texture = null
	var slot := catalog.definition_slot(item.definition_id)
	var equipped := profile.get_equipped_instance_id(slot) == item.instance_id
	var overflow := profile.can_salvage_overflow(item.instance_id, catalog)
	var material_count := profile.fusion_material_count(item.instance_id, catalog)
	var can_fuse := material_count > 0
	var fusion_count := clampi(hub_fusion_count, 1, maxi(material_count, 1))
	if page == 3 and overflow:
		details[1].texture = pixel_texture.call("MYTHIC +10  SALVAGE %dG" % catalog.overflow_salvage_value(item), Color8(255, 205, 117)) as Texture2D
		details[1].visible = true
		for stale_stat in hub_gear_stat_texts: stale_stat.texture = null
	elif page == 3:
		var batch_cost := profile.fusion_batch_cost(item, fusion_count)
		var fusion_color := Color8(211, 167, 255) if profile.souls >= batch_cost else Color8(255, 105, 105)
		var final_rarity := item.rarity
		var final_enhancement := mastery
		for step in fusion_count:
			if final_enhancement >= PlayerProfile.MAX_ITEM_ENHANCEMENT:
				final_rarity = ItemCatalog.next_rarity(final_rarity)
				final_enhancement = 0
			else:
				final_enhancement += 1
		var next_text := "%s -> %s +0" % [String(final_rarity).to_upper(), String(ItemCatalog.next_rarity(final_rarity)).to_upper()] if final_rarity != item.rarity else "+%d -> +%d" % [mastery, final_enhancement]
		details[1].texture = pixel_texture.call("FUSE x%d  %dS  S%d  MAT%d  %s" % [fusion_count, batch_cost, profile.souls, material_count, next_text], fusion_color) as Texture2D
		details[1].visible = true
		var projected := ItemInstance.from_dictionary(item.to_dictionary())
		projected.enhancement_level = final_enhancement
		projected.rarity = final_rarity
		var next_bonuses := catalog.bonuses(projected, 0)
		var preview_stats := hub_gear_stat_texts
		var preview_rows: Array[String] = []
		var preview_order := ["strength", "defense", "vitality", "agi", "intelligence", "mnd"]
		for stat: String in preview_order:
			var before := float(bonuses.get(stat, 0.0))
			var after := float(next_bonuses.get(stat, 0.0))
			if is_equal_approx(before, 0.0) and is_equal_approx(after, 0.0):
				continue
			var preview_label: String = str({"health_rate": "HP", "damage_rate": "DMG", "strength": "STR", "defense": "DEF", "vitality": "VIT", "speed": "AGI", "agi": "AGI", "intelligence": "INT", "mnd": "MND"}.get(stat, stat.to_upper()))
			preview_rows.append("%s %.1f>%.1f" % [preview_label, before, after])
		for row_index in preview_stats.size():
			if row_index < preview_rows.size():
				preview_stats[row_index].texture = pixel_texture.call(preview_rows[row_index], Color8(167, 240, 112)) as Texture2D
				preview_stats[row_index].visible = true
			else:
				preview_stats[row_index].texture = null
				preview_stats[row_index].visible = false
	else:
		var item_info: Array[String] = []
		if page == 2 and hub_shop_sell_mode:
			item_info.append("SELL FOR %dG + %dS" % [catalog.sell_value(item), catalog.sell_soul_value(item)])
			if hub_shop_sell_confirm_pending:
				item_info.append("ARE YOU SURE? CONFIRM / BACK")
		var random_text := catalog.random_stat_text(item)
		if not random_text.is_empty(): item_info.append(random_text)
		var player_rate_text := catalog.player_stat_rate_text(item)
		if not player_rate_text.is_empty(): item_info.append(player_rate_text)
		if not selected_transmutation_name.is_empty(): item_info.append("SPECIAL: %s" % selected_transmutation_name)
		if not item_info.is_empty():
			details[1].texture = pixel_texture.call("  ".join(item_info), Color8(148, 220, 255)) as Texture2D
		details[1].visible = not item_info.is_empty()
		var item_detail_lines := catalog.effect_display_lines(item)
		item_detail_lines.append_array(_wrap_gear_text(catalog.player_description(item), HUB_ITEM_TEXT_WRAP_LENGTH))
		_set_gear_detail_lines(details, pixel_texture, item_detail_lines, Color8(210, 220, 235))
	action.disabled = (hub_shop_sell_mode and equipped) or (not hub_shop_sell_mode and sold) or (page == 2 and not hub_shop_sell_mode and profile.gold < price) or (page == 1 and equipped) or (page == 3 and (not can_fuse and not overflow or (can_fuse and profile.souls < profile.fusion_batch_cost(item, fusion_count))))
	if hub_fusion_decrease_button != null:
		hub_fusion_decrease_button.disabled = page != 3 or not can_fuse or fusion_count <= 1
		set_archetype_button_state(hub_fusion_decrease_button, not hub_fusion_decrease_button.disabled, highlight_color)
	if hub_fusion_increase_button != null:
		hub_fusion_increase_button.disabled = page != 3 or not can_fuse or fusion_count >= material_count
		set_archetype_button_state(hub_fusion_increase_button, not hub_fusion_increase_button.disabled, highlight_color)
	var label := action.get_child(0) as Sprite2D
	if label != null: label.texture = pixel_texture.call(("SELL" if hub_shop_sell_mode else "BUY") if page == 2 else ("SALVAGE" if page == 3 and overflow else ("FUSE x%d" % fusion_count if page == 3 else "EQUIP")), Color.WHITE) as Texture2D
	set_archetype_button_state(action, true, highlight_color)
	_set_menu_button_icon(action, MENU_CIRCLE_TEXTURE, _menu_uses_face_art(root) and not action.disabled)


func _update_hub_gear_slots(root: Object, pixel_texture: Callable, profile: PlayerProfile, catalog: ItemCatalog, item_list: Array[Sprite2D], choices: Array[Sprite2D], details: Array[Sprite2D], action: Button, highlight_color: Color) -> void:
	# Equipment owns its top Equip/Remove action row. The old lower action
	# button belongs to Shop/Fusion and must never become a second, hidden focus
	# target while the slot picker is being navigated.
	action.visible = false
	action.disabled = true
	for button in hub_gear_choice_buttons: button.visible = false
	for stat in hub_gear_stat_texts:
		stat.texture = null
		stat.visible = false
	var selected_slot_index := clampi(hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)
	var selected_slot: StringName = ItemCatalog.SLOTS[selected_slot_index]
	var candidate_indices := hub_gear_candidate_indices
	var browsing := hub_gear_browsing
	var action_state := hub_equipment_action_focus and not browsing
	var selected_candidate: ItemInstance = null
	var slot_candidates := root.call("_hub_gear_candidates", selected_slot) as Array[ItemInstance]
	var slot_labels := ["WEAPON", "HEAD", "BODY", "ARM", "SHIELD", "ACCESSORY"]
	if hub_item_name_text != null:
		var header := "%s GEAR" % slot_labels[selected_slot_index] if browsing else "SELECT SLOT"
		hub_item_name_text.texture = pixel_texture.call(header, highlight_color if browsing else Color.WHITE) as Texture2D
		hub_item_name_text.visible = not action_state
	for detail in details:
		detail.texture = null
		detail.visible = false
	if action_state:
		# The action row is the complete Equipment screen at this depth. Clear
		# descendants so no slot header, stat card, or old picker label can sit
		# underneath it and look like a second active menu.
		for row in item_list:
			row.texture = null
		for choice in choices:
			choice.texture = null
		if hub_item_detail_panel != null:
			hub_item_detail_panel.visible = false
		if hub_gear_stat_panel != null:
			hub_gear_stat_panel.visible = false
		return
	var head_locked := profile._head_locked_by_body(catalog) if profile != null else false
	for row in item_list.size():
		if row >= ItemCatalog.SLOTS.size():
			item_list[row].texture = null
			continue
		var slot := ItemCatalog.SLOTS[row]
		var shown_item := profile.find_item(profile.get_equipped_instance_id(slot))
		if row == selected_slot_index:
			selected_candidate = shown_item
		var slot_name: String = slot_labels[row]
		var shown_name: String = "EMPTY"
		var shown_color := Color8(140, 145, 160)
		if shown_item != null:
			shown_name = catalog.gear_name(shown_item)
			var shown_mastery := shown_item.enhancement_level
			if shown_mastery > 0: shown_name += " F%d" % shown_mastery
			shown_color = catalog.rarity_color(shown_item.rarity)
		# Selection is represented by the slot cursor. Keep the gear's rarity color
		# intact even in the compatibility presenter used by older callers.
		var row_color := shown_color
		var slot_locked := slot == &"head" and head_locked
		if slot_locked:
			# The Demon Cloak occupies Body + Head; the Head slot is greyed out.
			item_list[row].texture = pixel_texture.call("%s: LOCKED" % slot_name, Color8(88, 92, 102)) as Texture2D
		else:
			item_list[row].texture = pixel_texture.call("%s: %s" % [slot_name, shown_name], row_color) as Texture2D
		if row < hub_gear_slot_buttons.size():
			hub_gear_slot_buttons[row].disabled = slot_locked
			hub_gear_slot_buttons[row].visible = not action_state
	if hub_slot_cursor != null:
		hub_slot_cursor.visible = not action_state and selected_slot_index >= 0 and selected_slot_index < item_list.size()
		if hub_slot_cursor.visible:
			move_menu_cursor(hub_slot_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, 35.0 + 4.0 + float(selected_slot_index) * 10.0 + 3.0), false)
	for choice in choices: choice.texture = null
	if browsing:
		var current_index := posmod(int(candidate_indices.get(String(selected_slot), 0)), maxi(slot_candidates.size(), 1))
		if not slot_candidates.is_empty(): selected_candidate = slot_candidates[current_index]
		var choice_pitch := 10.0
		var visible_choices := choices.size()
		hub_choice_scroll = clampf(hub_choice_scroll, 0.0, maxf(0.0, float(slot_candidates.size() - visible_choices)))
		_apply_hub_choice_scroll(choice_pitch)
		var window_start := int(hub_choice_scroll)
		var choice_frac: float = hub_choice_scroll - float(window_start)
		for choice_row in choices.size():
			var choice_index := window_start + choice_row
			if choice_index >= slot_candidates.size(): break
			if choice_row < hub_gear_choice_buttons.size(): hub_gear_choice_buttons[choice_row].visible = true
			var choice_item := slot_candidates[choice_index]
			var is_unequip := choice_item.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID
			var choice_label := "%s" % ("UNEQUIP SHIELD" if is_unequip else "%s %s" % [String(choice_item.rarity).substr(0, 1).to_upper(), catalog.gear_name(choice_item)])
			var choice_mastery := choice_item.enhancement_level
			if choice_mastery > 0: choice_label += " F%d" % choice_mastery
			# Candidate selection belongs to the cursor; the candidate name keeps its
			# rarity color so the equipment route has one consistent visual language.
			var choice_color := Color8(140, 145, 160) if is_unequip else catalog.rarity_color(choice_item.rarity)
			choices[choice_row].texture = pixel_texture.call(choice_label, choice_color) as Texture2D
		if hub_choice_cursor != null:
			var choice_visible_slot := current_index - window_start
			hub_choice_cursor.visible = choice_visible_slot >= 0 and choice_visible_slot < choices.size()
			if hub_choice_cursor.visible:
				var choice_cursor_y := 91.0 + 4.0 + float(choice_visible_slot) * choice_pitch - choice_frac * choice_pitch
				move_menu_cursor(hub_choice_cursor, Vector2(20.0 - CURSOR_LEFT_GAP, choice_cursor_y + 3.0), false)
		action.visible = false
		if hub_item_detail_panel != null: hub_item_detail_panel.visible = true
		if not details.is_empty():
			details[0].position = Vector2(20, HUB_GEAR_BROWSE_DETAIL_TOP)
			details[0].texture = pixel_texture.call("SELECT %s" % catalog.display_name(selected_candidate) if selected_candidate != null else "NO GEAR", highlight_color) as Texture2D
			details[0].visible = true
		if selected_candidate != null:
			_update_gear_comparison_stats(root, pixel_texture, profile, catalog, selected_candidate, selected_slot_index, true)
		return
	else:
		for choice in choices: choice.visible = false
	if hub_item_detail_panel != null: hub_item_detail_panel.visible = true
	for detail_index in details.size(): details[detail_index].position = Vector2(20, HUB_ITEM_DETAIL_TOP + detail_index * HUB_ITEM_DETAIL_PITCH)
	if selected_candidate == null:
		var available_candidates := slot_candidates
		if selected_slot_index == ItemCatalog.SLOTS.find(&"shield") and not available_candidates.is_empty():
			details[0].texture = pixel_texture.call("NO SHIELD EQUIPPED", Color8(255, 205, 117)) as Texture2D
			details[1].texture = pixel_texture.call("SELECT FROM INVENTORY", Color8(148, 220, 255)) as Texture2D
			details[0].visible = true; details[1].visible = true
		else:
			details[0].texture = pixel_texture.call("NO GEAR FOR THIS SLOT", Color8(255, 205, 117)) as Texture2D
			details[0].visible = true
		return
	_update_gear_comparison_stats(root, pixel_texture, profile, catalog, selected_candidate, selected_slot_index, browsing)
	details[0].texture = pixel_texture.call(catalog.display_name(selected_candidate), catalog.rarity_color(selected_candidate.rarity)) as Texture2D
	details[0].visible = true
	var transmutation_name := catalog.transmutation_name(selected_candidate.transmutation_id)
	var item_info: Array[String] = []
	var random_text := catalog.random_stat_text(selected_candidate)
	if not random_text.is_empty(): item_info.append(random_text)
	var player_rate_text := catalog.player_stat_rate_text(selected_candidate)
	if not player_rate_text.is_empty(): item_info.append(player_rate_text)
	if not transmutation_name.is_empty(): item_info.append("SPECIAL: %s" % transmutation_name)
	if selected_slot_index == ItemCatalog.SLOTS.find(&"shield"):
		var shield_values := catalog.shield_bonuses(selected_candidate)
		item_info.append("BLOCK +%d ARM +%d%%" % [roundi(float(shield_values.get("guard_durability", 0.0))), roundi(float(shield_values.get("guard_reduction", 0.0)))])
	if not item_info.is_empty():
		details[1].texture = pixel_texture.call("  ".join(item_info), Color8(148, 220, 255)) as Texture2D
		details[1].visible = true
	var description_lines := catalog.effect_display_lines(selected_candidate)
	description_lines.append_array(_wrap_gear_text(catalog.player_description(selected_candidate), HUB_ITEM_TEXT_WRAP_LENGTH))
	if not transmutation_name.is_empty():
		description_lines.append_array(_wrap_gear_text(catalog.transmutation_description(selected_candidate.transmutation_id), HUB_ITEM_TEXT_WRAP_LENGTH))
	_set_gear_detail_lines(details, pixel_texture, description_lines, Color8(210, 220, 235))
	action.disabled = true
	action.visible = false


func _set_transmutation_description(details: Array[Sprite2D], pixel_texture: Callable, description: String) -> void:
	for detail_index in range(2, details.size()):
		details[detail_index].texture = null
		details[detail_index].visible = false
	if description.is_empty():
		return
	var words := description.split(" ")
	var lines: Array[String] = []
	var line := ""
	for word in words:
		if word.length() > HUB_ITEM_TEXT_WRAP_LENGTH:
			if not line.is_empty():
				lines.append(line)
				line = ""
			while word.length() > HUB_ITEM_TEXT_WRAP_LENGTH:
				lines.append(word.left(HUB_ITEM_TEXT_WRAP_LENGTH))
				word = word.substr(HUB_ITEM_TEXT_WRAP_LENGTH)
		var candidate := word if line.is_empty() else "%s %s" % [line, word]
		if candidate.length() > HUB_ITEM_TEXT_WRAP_LENGTH and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = candidate
	if not line.is_empty(): lines.append(line)
	for line_index in mini(lines.size(), details.size() - 2):
		details[line_index + 2].texture = pixel_texture.call(lines[line_index], Color8(210, 220, 235)) as Texture2D
		details[line_index + 2].visible = true


func _wrap_gear_text(source_text: String, line_length: int) -> Array[String]:
	return _hub_equipment_menu_presenter.wrap_gear_text(source_text, line_length)


func _set_gear_detail_lines(details: Array[Sprite2D], pixel_texture: Callable, lines: Array[String], color: Color) -> void:
	for detail_index in range(2, details.size()):
		details[detail_index].texture = null
		details[detail_index].visible = false
	for line_index in mini(lines.size(), details.size() - 2):
		details[line_index + 2].texture = pixel_texture.call(lines[line_index], color) as Texture2D
		details[line_index + 2].visible = true


func _update_gear_comparison_stats(root: Object, pixel_texture: Callable, profile: PlayerProfile, catalog: ItemCatalog, candidate: ItemInstance, slot_index: int, comparing: bool) -> void:
	var stats := hub_gear_stat_texts
	var slot := ItemCatalog.SLOTS[clampi(slot_index, 0, ItemCatalog.SLOTS.size() - 1)]
	var live_snapshot := root.call("_player_stat_snapshot") as CombatStatSnapshot if root.has_method("_player_stat_snapshot") else null
	var player_stats := root.get("player_stats") as StatsComponent
	if live_snapshot != null and player_stats != null:
		# Preview through the same equipment component and shared snapshot used by
		# combat. This keeps rarity rates, transmutation health effects, and the
		# flat-before-rate ordering identical between the menu and runtime.
		var preview_equipment := EquipmentComponent.new()
		var preview_item := candidate
		if candidate != null and candidate.instance_id == ItemCatalog.UNEQUIP_SHIELD_ID:
			preview_item = null
		preview_equipment.configure_preview_from_profile(profile, catalog, slot, preview_item)
		var preview_snapshot := CombatStatSnapshot.from_components(player_stats, preview_equipment)
		var comparison_fields := [
			{"key": "vit", "label": "VIT"}, {"key": "strength", "label": "STR"},
			{"key": "def", "label": "DEF"}, {"key": "agi", "label": "AGI"},
			{"key": "intelligence", "label": "INT"}, {"key": "mnd", "label": "MND"},
		]
		for index in mini(stats.size(), comparison_fields.size()):
			var field: Dictionary = comparison_fields[index]
			var key := str(field["key"])
			var before := float(live_snapshot.get(key))
			var after := float(preview_snapshot.get(key))
			var delta := after - before
			var shown := delta if comparing else after
			var prefix := "+" if shown > 0.0 and comparing else "-" if shown < 0.0 and comparing else ""
			var color := Color8(148, 220, 255) if delta > 0.0 else Color8(239, 125, 87) if delta < 0.0 else Color8(167, 240, 112) if not comparing else Color8(150, 156, 170)
			stats[index].visible = true
			stats[index].texture = pixel_texture.call("%s %s%.1f" % [str(field["label"]), prefix, absf(shown) if comparing else shown], color) as Texture2D
		var tuning := root.get("combat_tuning") as CombatTuning
		var current_attack := CombatCalculator.attack_power_for_snapshot(live_snapshot, tuning)
		var preview_attack := CombatCalculator.attack_power_for_snapshot(preview_snapshot, tuning)
		var current_magic := CombatCalculator.magic_power_for_snapshot(live_snapshot, tuning)
		var preview_magic := CombatCalculator.magic_power_for_snapshot(preview_snapshot, tuning)
		if hub_context_text != null:
			var context := "P%.0f>%.0f M%.0f>%.0f" % [current_attack, preview_attack, current_magic, preview_magic] if comparing else "P%.0f M%.0f" % [preview_attack, preview_magic]
			var confirm_prompt := _menu_confirm_prompt_for(root).replace("SELECT", "EQUIP")
			hub_context_text.texture = pixel_texture.call("%s  %s" % [context, confirm_prompt], Color8(148, 220, 255)) as Texture2D
		preview_equipment.free()
		return
	# Lightweight test doubles and legacy callers may not expose a player
	# snapshot. Keep their package-only comparison readable while using the
	# canonical six-stat names.
	var equipped := profile.find_item(profile.get_equipped_instance_id(slot))
	var candidate_bonuses := _effective_item_bonuses(catalog, candidate, profile.mastery_level(candidate.definition_id))
	var equipped_bonuses := _effective_item_bonuses(catalog, equipped, profile.mastery_level(equipped.definition_id)) if equipped != null else {}
	var fallback_fields := [{"key": "vitality", "label": "VIT", "rate": false}, {"key": "strength", "label": "STR", "rate": false}, {"key": "defense", "label": "DEF", "rate": false}, {"key": "agi", "label": "AGI", "rate": false}, {"key": "intelligence", "label": "INT", "rate": false}, {"key": "mnd", "label": "MND", "rate": false}]
	for index in mini(stats.size(), fallback_fields.size()):
		var field: Dictionary = fallback_fields[index]
		var key := str(field["key"])
		var value := float(candidate_bonuses.get(key, 0.0)) - float(equipped_bonuses.get(key, 0.0)) if comparing else float(candidate_bonuses.get(key, 0.0))
		var prefix := "+" if value > 0 else "-" if value < 0 else ""
		var color := Color8(148, 220, 255) if value > 0 else Color8(239, 125, 87) if value < 0 else Color8(150, 156, 170)
		if is_zero_approx(value) and (key == "intelligence" or key == "mnd"):
			stats[index].texture = null
			stats[index].visible = false
		else:
			stats[index].visible = true
			stats[index].texture = pixel_texture.call("%s %s%.1f%s" % [str(field["label"]), prefix, absf(value), "%" if bool(field["rate"]) else ""], color) as Texture2D
	for index in range(fallback_fields.size(), stats.size()):
		stats[index].texture = null
		stats[index].visible = false


func _effective_item_bonuses(catalog: ItemCatalog, item: ItemInstance, mastery_level: int = 0) -> Dictionary:
	if item == null:
		return {}
	return catalog.bonuses(item, mastery_level)

# --- Pause routing, hub input, and debug input ---
func _pause_command_list() -> MenuCommandList:
	if pause_command_list == null:
		pause_command_list = MenuCommandList.new()
	var base_ys: Array[float] = []
	for index in pause_menu_buttons.size():
		base_ys.append(pause_menu_buttons[index].position.y if pause_menu_buttons[index] != null else 0.0)
	pause_command_list.configure(pause_menu_buttons, base_ys)
	pause_command_list.row = pause_menu_row
	return pause_command_list


func update_pause_input(root: GameplayState) -> void:
	if pause_overlay == null or not pause_overlay.visible:
		return
	if pause_page == 2 and is_pause_equipment_active():
		var touch_scroll := root._input_touch_scroll_y() as float
		if not is_zero_approx(touch_scroll):
			scroll_hub_content(root, touch_scroll)
			refresh_equipment_menu(root)
		_update_pause_equipment_input(root)
		return
	if bool(root._is_menu_back_just_pressed()):
		root._pause_back()
		return
	if pause_page == 3:
		_update_debug_page_input(root)
		return
	if pause_page != 0:
		return
	if bool(root._is_menu_direction_just_pressed(&"ui_up")) or bool(root._is_menu_direction_just_pressed(&"ui_down")):
		var command_list := _pause_command_list()
		if command_list != null:
			if bool(root._is_menu_direction_just_pressed(&"ui_up")): command_list.move_up()
			else: command_list.move_down()
			pause_menu_row = command_list.row
		else:
			if bool(root._is_menu_direction_just_pressed(&"ui_up")): pause_menu_row = posmod(pause_menu_row - 1, pause_menu_buttons.size())
			else: pause_menu_row = posmod(pause_menu_row + 1, pause_menu_buttons.size())
		update_pause_ui(root, Callable(root, "_pixel_text_texture")); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_confirm_just_pressed()):
		if pause_menu_row >= 0 and pause_menu_row < pause_menu_buttons.size():
			var action := pause_menu_buttons[pause_menu_row]
			if action != null and not action.disabled:
				action.pressed.emit()
			else:
				root._play_sound("ui_no_input", 0.0, 1.0)
		else:
			root._play_sound("ui_no_input", 0.0, 1.0)



# --- Debug-page and pause-equipment input ---
func refresh_debug_menu(root: GameplayState) -> void:
	if debug_menu_layout == null:
		return
	var session := root.get_node_or_null("DebugSessionController") as Node
	if session == null:
		return
	var stats := root.player_stats
	var debug_level := int(session.get("player_level_override"))
	var level := debug_level if debug_level > 0 else (stats.level if stats != null else 1)
	var geometry := root.actor_geometry_debug_drawer
	debug_menu_layout.call("refresh", Callable(root, "_pixel_text_texture"), int(session.get("selected_run_number")), level, int(session.get("debug_unassigned_stat_points")), bool(session.get("reset_confirmation_armed")), {&"invulnerable": bool(session.get("invulnerable")), &"unlimited_chroma": bool(session.get("unlimited_chroma")), &"pause_enemies": bool(session.get("enemies_paused")), &"geometry_guides": geometry.enabled if geometry != null else false})
	debug_menu_layout.call("select_row", debug_menu_row)


func _update_debug_page_input(root: GameplayState) -> void:
	if debug_menu_buttons.is_empty():
		return
	if bool(root._is_menu_direction_just_pressed(&"ui_up")):
		debug_menu_row = posmod(debug_menu_row - 1, debug_menu_buttons.size())
		refresh_debug_menu(root)
	elif bool(root._is_menu_direction_just_pressed(&"ui_down")):
		debug_menu_row = posmod(debug_menu_row + 1, debug_menu_buttons.size())
		refresh_debug_menu(root)
	elif bool(root._is_menu_confirm_just_pressed()):
		debug_menu_buttons[debug_menu_row].pressed.emit()
		root._play_sound("ui_confirm", 0.0, 1.0)


func _update_pause_equipment_input(root: GameplayState) -> void:
	if bool(root._is_menu_back_just_pressed()):
		if hub_equipment_mode == EquipmentMenuLayout.MODE_REMOVE_ALL_CONFIRM:
			root._cancel_hub_remove_all()
		elif hub_gear_browsing:
			root._close_hub_gear_browse()
		elif not hub_equipment_action_focus:
			hub_equipment_action_focus = true
			hub_equipment_mode = EquipmentMenuLayout.MODE_COMMAND
			refresh_equipment_menu(root)
			root._play_sound("ui_decline", 0.0, 1.0)
		else:
			root._pause_back()
		return
	if hub_equipment_mode == EquipmentMenuLayout.MODE_REMOVE_ALL_CONFIRM:
		if bool(root._is_menu_confirm_just_pressed()):
			root._remove_all_hub_gear()
		return
	if hub_gear_browsing:
		if bool(root._is_menu_direction_just_pressed(&"ui_up")): root._shift_hub_gear_candidate_grid(0, -1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")): root._shift_hub_gear_candidate_grid(0, 1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_gear_candidate_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_gear_candidate_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()): root._hub_item_action()
		return
	if hub_equipment_action_focus:
		if bool(root._is_menu_direction_just_pressed(&"ui_left")) or bool(root._is_menu_direction_just_pressed(&"ui_right")):
			root._shift_hub_action_column(-1 if bool(root._is_menu_direction_just_pressed(&"ui_left")) else 1)
			root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_confirm_just_pressed()):
			match hub_action_column:
				0: root._hub_item_action()
				1: root._remove_hub_gear()
				2: root._remove_all_hub_gear()
				_: root._play_sound("ui_no_input", 0.0, 1.0)
		return
	if hub_equipment_mode == EquipmentMenuLayout.MODE_SLOT_REMOVE:
		if bool(root._is_menu_confirm_just_pressed()): root._remove_hub_gear()
		elif bool(root._is_menu_direction_just_pressed(&"ui_up")): root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_down")): root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_slot_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_slot_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)
		return
	if bool(root._is_menu_confirm_just_pressed()): root._select_hub_gear_slot(hub_item_index)
	elif bool(root._is_menu_direction_just_pressed(&"ui_up")): root._shift_hub_item(-1); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_down")): root._shift_hub_item(1); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_left")): root._shift_hub_slot_grid(-1, 0); root._play_sound("ui_hover", -6.0, 1.0)
	elif bool(root._is_menu_direction_just_pressed(&"ui_right")): root._shift_hub_slot_grid(1, 0); root._play_sound("ui_hover", -6.0, 1.0)


func update_hub_input(root: GameplayState) -> void:
	_hub_input_controller.update(
		root,
		_hub_menu_state,
		Callable(self, "update_hub_ui"),
		Callable(self, "scroll_hub_content")
	)

# --- Title screen construction and layout ---
func build_title(parent: Node, pixel_texture: Callable, new_game_callback: Callable, continue_callback: Callable, has_profile: bool, settings_callback: Callable = Callable(), cloud_callback: Callable = Callable()) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	return _title_screen_presenter.build(parent, display_view_size, GAME_VERSION, pixel_texture, new_game_callback, continue_callback, has_profile, settings_callback, cloud_callback, _menu_widget_factory)


func refresh_title_menu_layout(has_profile: bool) -> void:
	_title_screen_presenter.refresh_menu_layout(has_profile)


# --- Settings construction, navigation, and value presentation ---
func build_settings(parent: Node, pixel_texture: Callable, adjust_callback: Callable, close_callback: Callable, select_option_callback: Callable = Callable()) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	var root_node := get_parent()
	var settings_service: SettingsService = root_node.get("settings_service") as SettingsService if root_node != null else null
	return _settings_screen_presenter.build(parent, display_view_size, pixel_texture, adjust_callback, close_callback, select_option_callback, _menu_widget_factory, _menu_prompt_texture_factory, _menu_cursor_animator, CURSOR_LEFT_GAP, self, settings_service)


func _position_settings_controls() -> void:
	_settings_screen_presenter.position_controls(display_view_size)


func open_settings(root: Object, origin: StringName) -> void:
	if settings_overlay == null:
		return
	settings_origin = origin
	settings_row = 0
	settings_interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	# Settings replaces its source screen. Leaving the pause panel visible under
	# it makes focus and touch hit-testing ambiguous, especially on the web port.
	if origin == &"pause":
		root.call("_play_sound", "ui_confirm", 0.0, 1.0)
		if pause_overlay != null:
			pause_overlay.visible = false
		set_menu_world_hidden(root, true)
	elif origin == &"title":
		if title_overlay != null:
			title_overlay.visible = false
	settings_overlay.visible = true
	settings_overlay.modulate.a = 1.0
	set_state(&"settings")
	update_settings_ui(root, Callable(root, "_pixel_text_texture"))
	_focus_settings_selection()


func close_settings(root: Object) -> void:
	if settings_overlay != null:
		settings_overlay.visible = false
	settings_interact_input_was_down = false
	if settings_origin == &"pause":
		if pause_overlay != null:
			pause_overlay.visible = true
		hub_pause_mode = true
		pause_page = 0
		pause_menu_row = 2
		set_state(&"pause")
		update_pause_ui(root, Callable(root, "_pixel_text_texture"))
	else:
		set_menu_world_hidden(root, false)
		if title_overlay != null: title_overlay.visible = true
		menu_input_release_lock = true
		set_state(&"title")
		title_menu_row = 2
		if title_settings_button != null: title_settings_button.visible = true
		if title_cloud_button != null: title_cloud_button.visible = true
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


func update_settings_ui(root: Object, pixel_texture: Callable) -> void:
	var service := root.get("settings_service") as SettingsService
	var highlight := PaletteLibrary.accent(String(root.get("current_player_palette_name")))
	_settings_screen_presenter.update_visuals(service, pixel_texture, highlight, _menu_back_prompt_for(root), _menu_uses_face_art(root))


func _settings_option_index(row: int, values: Dictionary) -> int:
	return _settings_screen_presenter.option_index(row, values)


func _settings_option_index_for_cursor(row: int) -> int:
	return _settings_screen_presenter.option_index_for_cursor(row)


func select_setting_option(root: Object, row: int, option_index: int) -> void:
	var service := root.get("settings_service") as SettingsService
	if service == null:
		return
	_settings_screen_presenter.select_option(service, row, option_index)
	update_settings_ui(root, Callable(root, "_pixel_text_texture"))


func adjust_setting(root: Object, row: int, direction: int) -> void:
	var service := root.get("settings_service") as SettingsService
	if service == null:
		return
	_settings_screen_presenter.adjust_option(service, row, direction)
	update_settings_ui(root, Callable(root, "_pixel_text_texture"))


func _update_settings_cursor() -> void:
	_settings_screen_presenter.update_cursor()


func _set_button_text(button: Button, label: String, pixel_texture: Callable, color: Color = Color.WHITE) -> void:
	_menu_prompt_texture_factory.set_button_text(button, label, pixel_texture, color)


func _menu_face_texture_for_prompt(label: String) -> Texture2D:
	return _menu_prompt_texture_factory.menu_face_texture_for_prompt(label)


## Preserve the stable face-button prompt API while the factory owns texture
## composition and caching for every screen that uses the shared treatment.
func _pixel_prompt_texture(pixel_texture: Callable, label: String, color: Color) -> Texture2D:
	return _menu_prompt_texture_factory.pixel_prompt_texture(pixel_texture, label, color)


func _pixel_prompt_sequence_texture(pixel_texture: Callable, labels: Array[String], color: Color, gap: int = 5, glyph_gap: int = 1) -> Texture2D:
	return _menu_prompt_texture_factory.pixel_prompt_sequence_texture(pixel_texture, labels, color, gap, glyph_gap)


func _menu_face_label_without_icon(label: String) -> String:
	return _menu_prompt_texture_factory.menu_face_label_without_icon(label)


func _menu_uses_face_art(root: Object) -> bool:
	if root == null or not root.has_method("_menu_confirm_prompt"):
		return false
	return str(root.call("_menu_confirm_prompt")).begins_with("O ")


func _set_menu_button_icon(button: Button, icon_texture: Texture2D, visible: bool) -> void:
	_menu_prompt_texture_factory.set_menu_button_icon(button, icon_texture, visible)


func _menu_confirm_prompt_for(root: Object) -> String:
	if root != null and root.has_method("_menu_confirm_prompt"):
		return str(root.call("_menu_confirm_prompt"))
	return "B SELECT"


func _menu_back_prompt_for(root: Object) -> String:
	if root != null and root.has_method("_menu_back_prompt"):
		return str(root.call("_menu_back_prompt"))
	return "A BACK"


func _focus_settings_selection() -> void:
	# Menu focus is rendered by our pixel cursor and owned by InputRouter. Native
	# Control focus must not remain on a hidden source page or steal a controller
	# edge from the active settings route.
	_update_settings_cursor()


func update_settings_input(root: Object) -> void:
	if settings_overlay == null or not settings_overlay.visible:
		return
	if bool(root.call("_is_menu_back_just_pressed")):
		close_settings(root)
		return
	var row_count := settings_value_buttons.size() + (1 if settings_back_button != null else 0)
	if bool(root.call("_is_menu_direction_just_pressed", &"ui_up")):
		settings_row = posmod(settings_row - 1, row_count)
		update_settings_ui(root, Callable(root, "_pixel_text_texture"))
		_focus_settings_selection()
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif bool(root.call("_is_menu_direction_just_pressed", &"ui_down")):
		settings_row = posmod(settings_row + 1, row_count)
		update_settings_ui(root, Callable(root, "_pixel_text_texture"))
		_focus_settings_selection()
		root.call("_play_sound", "ui_hover", -6.0, 1.0)
	elif settings_row < settings_value_buttons.size() and bool(root.call("_is_menu_direction_just_pressed", &"ui_left")):
		adjust_setting(root, settings_row, -1)
	elif settings_row < settings_value_buttons.size() and bool(root.call("_is_menu_direction_just_pressed", &"ui_right")):
		adjust_setting(root, settings_row, 1)
	elif bool(root.call("_is_menu_confirm_just_pressed")):
		if settings_row == settings_value_buttons.size() and settings_back_button != null:
			settings_back_button.pressed.emit()
		elif settings_row >= 0 and settings_row < settings_value_buttons.size():
			adjust_setting(root, settings_row, 1)

# --- Save-select and name-entry screen construction ---
func build_save_select(parent: Node, pixel_texture: Callable, select_callback: Callable, overwrite_yes: Callable = Callable(), overwrite_no: Callable = Callable(), portrait_texture: Callable = Callable(), back_callback: Callable = Callable()) -> ColorRect:
	display_view_size = _view_size_for_parent(parent)
	return _save_select_screen_presenter.build(parent, display_view_size, pixel_texture, select_callback, overwrite_yes, overwrite_no, portrait_texture, back_callback, _menu_widget_factory)


func build_name_entry(parent: Node, pixel_texture: Callable, finish_callback: Callable = Callable(), cancel_callback: Callable = Callable(), preview_texture: Callable = Callable()) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	return _name_entry_screen_controller.build(parent, display_view_size, pixel_texture, finish_callback, cancel_callback, preview_texture, _menu_widget_factory, _menu_prompt_texture_factory, _menu_cursor_animator, CURSOR_LEFT_GAP, self)


# --- Name-entry state, touch selection, and input ---
func _name_entry_page_characters(page: int = name_entry_page) -> Array[String]:
	return _name_entry_screen_controller.page_characters(page)


func name_entry_page_case_upper() -> bool:
	return _name_entry_screen_controller.page_case_upper()


func _name_entry_cell_label(token: String) -> String:
	return _name_entry_screen_controller.cell_label(token)


func _position_name_entry_controls() -> void:
	_name_entry_screen_controller.position_controls(display_view_size, _menu_cursor_animator, self)


func show_name_entry(root: Object, pending_slot: int) -> void:
	if name_entry_overlay == null:
		return
	_name_entry_screen_controller.begin(pending_slot)
	if title_overlay != null: title_overlay.visible = false
	if save_select_overlay != null: save_select_overlay.visible = false
	if archetype_overlay != null: archetype_overlay.visible = false
	name_entry_overlay.visible = true
	name_entry_overlay.modulate.a = 1.0
	menu_input_release_lock = true
	set_state(&"name_entry")
	update_name_entry_ui(root, Callable(root, "_pixel_text_texture"))


func cancel_name_entry(root: Object) -> void:
	_name_entry_screen_controller.cancel()
	menu_input_release_lock = true
	if save_select_overlay != null:
		save_select_overlay.visible = true
		if title_overlay != null: title_overlay.visible = true
		set_state(&"title")
		root.call("_update_save_select_cursor")
	else:
		if title_overlay != null: title_overlay.visible = true
		set_state(&"title")
	if root.has_method("_play_sound"): root.call("_play_sound", "ui_decline", 0.0, 1.0)


func pending_name_entry_slot() -> int:
	return _name_entry_screen_controller.pending_name_slot()


func complete_name_entry() -> void:
	_name_entry_screen_controller.complete()


func update_name_entry_ui(root: Object, pixel_texture: Callable) -> void:
	if name_entry_overlay == null:
		return
	_name_entry_screen_controller.update_visuals(pixel_texture, player_palette_name, _menu_confirm_prompt_for(root), _menu_back_prompt_for(root), _menu_prompt_texture_factory, display_view_size, _menu_cursor_animator, self)


func _activate_name_entry_cell(index: int) -> void:
	_name_entry_screen_controller.activate_cell(index)


func _update_name_entry_visuals() -> void:
	_name_entry_screen_controller.refresh_visuals()


func _move_name_entry_cursor(delta: Vector2i) -> void:
	_name_entry_screen_controller.move_cursor(delta)


func _name_entry_change_page(direction: int) -> void:
	_name_entry_screen_controller.change_page(direction)


func _name_entry_toggle_case() -> void:
	_name_entry_screen_controller.toggle_case()


func update_name_entry_input(root: Object) -> void:
	if name_entry_overlay == null or not name_entry_overlay.visible:
		return
	var gameplay_root := root as GameplayState
	if gameplay_root == null:
		return
	if menu_input_release_lock:
		var released := not gameplay_root._is_menu_confirm_pressed() and not gameplay_root._is_menu_back_pressed()
		if released: menu_input_release_lock = false
		else: return
	_name_entry_screen_controller.update_input(gameplay_root)


# --- Archetype and loading screen construction ---
func build_archetype(parent: Node, shift_type: Callable, shift_color: Callable, start_callback: Callable, pixel_texture: Callable) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	return _archetype_screen_presenter.build(parent, display_view_size, shift_type, shift_color, start_callback, pixel_texture, _menu_widget_factory)


func make_archetype_arrow(parent: Node, side: int, button_position: Vector2, pressed_callback: Callable, pixel_texture: Callable, hit_size: Vector2 = Vector2(10, 10)) -> Button:
	return _archetype_screen_presenter.make_arrow(parent, side, button_position, pressed_callback, pixel_texture, hit_size)


func build_loading(parent: Node, pixel_texture: Callable) -> Dictionary:
	display_view_size = _view_size_for_parent(parent)
	return _loading_screen_presenter.build_loading_screen(parent, display_view_size, pixel_texture, _menu_widget_factory)


func update_loading(overlay: ColorRect, text: Sprite2D, fading: bool, timer: float, delta: float, pixel_texture: Callable) -> Dictionary:
	var result := _loading_screen_presenter.update_loading_visuals(overlay, text, fading, timer, delta, pixel_texture, display_view_size)
	if bool(result["finished"]):
		_complete_loading_transition()
	return result


func _complete_loading_transition() -> void:
	if title_overlay != null: title_overlay.visible = false
	if archetype_overlay != null: archetype_overlay.visible = false
	if hub_overlay != null: hub_overlay.visible = false
	set_state(&"gameplay")


# --- Shared widget and hub-scroll compatibility facades ---
func _make_text_button(label: String, button_position: Vector2, normal_style: StyleBoxFlat, focus_style: StyleBoxFlat, pixel_texture: Callable, pressed_callback: Callable) -> Button:
	return _menu_widget_factory.make_text_button(label, button_position, normal_style, focus_style, pixel_texture, pressed_callback)


func create_overlay(parent: Node, overlay_name: String, size: Vector2, color: Color, z_index: int, visible: bool = true) -> ColorRect:
	return _menu_widget_factory.create_overlay(parent, overlay_name, size, color, z_index, visible)


func create_sprite(parent: Node, sprite_name: String, texture: Texture2D, sprite_position: Vector2, centered: bool, scale: Vector2 = Vector2.ONE, z_index: int = 0) -> Sprite2D:
	return _menu_widget_factory.create_sprite(parent, sprite_name, texture, sprite_position, centered, scale, z_index)


func move_menu_cursor(cursor: Sprite2D, target: Vector2, animate: bool = true) -> void:
	_menu_cursor_animator.move_menu_cursor(cursor, target, animate, self)


## Browser-style list scrolling: a touch drag moves the list CONTENT, never the
## cursor. Positive delta is finger movement downward (content follows the
## finger, revealing earlier rows).
# --- Hub-list scrolling and cursor tween cleanup ---
func scroll_hub_content(root: Object, delta_px: float) -> void:
	var equipment_active := hub_page == HUB_PAGE_EQUIPMENT or is_pause_equipment_active()
	if is_zero_approx(delta_px) or (hub_page < 0 and not equipment_active):
		return
	var pitch := 9.0 if equipment_active and hub_equipment_menu != null else 10.0
	var count := _hub_active_list_count(root)
	if count <= 0:
		return
	if equipment_active and hub_gear_browsing:
		var equipment_scroll_count := 8 if hub_equipment_menu != null else maxi(hub_gear_choice_texts.size(), 1)
		var max_start := EquipmentMenuLayout.candidate_max_scroll(count) if hub_equipment_menu != null else maxi(0, count - equipment_scroll_count)
		hub_choice_scroll = clampf(hub_choice_scroll - delta_px / pitch, 0.0, float(max_start))
		# A drag can move the visible window without changing the selected
		# candidate. Disarm the touch confirmation so a later tap cannot commit
		# an item the player has not just previewed in the current window.
		hub_touch_candidate_slot = ""
		hub_touch_candidate_index = -1
	else:
		# The authored Shop scene has eight visible rows; the legacy presenter keeps
		# its compatibility rows for other routes. Match the active presenter so a
		# drag never leaves the selected row below the visible shop window.
		var list_scroll_count := ShopMenuLayoutScript.VISIBLE_ROWS if hub_page == HUB_PAGE_SHOP and hub_shop_menu != null else FusionMenuLayoutScript.FUSION_VISIBLE_ROWS if hub_page == HUB_PAGE_FUSION and hub_fusion_menu != null else maxi(hub_item_list_texts.size(), 1)
		hub_list_scroll = clampf(hub_list_scroll - delta_px / pitch, 0.0, maxf(0.0, float(count - list_scroll_count)))
		if hub_page == HUB_PAGE_SHOP:
			hub_shop_sell_confirm_pending = false


func _hub_active_list_count(root: Object) -> int:
	if hub_page == HUB_PAGE_SHOP:
		var run_state := root.get("run_state") as RunState
		if hub_shop_sell_mode:
			var profile := root.get("player_profile") as PlayerProfile
			if profile == null:
				return 0
			var count := 0
			for data: Dictionary in profile.inventory:
				var item := ItemInstance.from_dictionary(data)
				if not profile.equipped_instance_ids.values().has(item.instance_id):
					count += 1
			return count
		if run_state == null:
			return 0
		run_state.ensure_shop_stock(root.get("player_profile"))
		return run_state.shop_stock.size()
	if hub_page == HUB_PAGE_FUSION:
		return (root.call("_hub_fusion_candidates") as Array).size()
	if (hub_page == HUB_PAGE_EQUIPMENT or is_pause_equipment_active()) and hub_gear_browsing:
		var selected_slot := ItemCatalog.SLOTS[clampi(hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		return (root.call("_hub_gear_candidates", selected_slot) as Array).size()
	return 0


## Controller/confirm selection changes re-center the content so the selected
## row stays visible; touch drags leave the cursor where it is.
func snap_hub_list_scroll_to_selection(root: Object) -> void:
	if (hub_page == HUB_PAGE_EQUIPMENT or is_pause_equipment_active()) and hub_gear_browsing:
		var selected_slot := ItemCatalog.SLOTS[clampi(hub_item_index, 0, ItemCatalog.SLOTS.size() - 1)]
		var candidates := root.call("_hub_gear_candidates", selected_slot) as Array
		var current_index := int(hub_gear_candidate_indices.get(String(selected_slot), 0))
		var equipment_visible_count := 8 if hub_equipment_menu != null else maxi(hub_gear_choice_texts.size(), 1)
		var max_start := EquipmentMenuLayout.candidate_max_scroll(candidates.size()) if hub_equipment_menu != null else maxi(0, candidates.size() - equipment_visible_count)
		var start := current_index - 2 if hub_equipment_menu != null else current_index - 1
		if hub_equipment_menu != null: start -= start % 2
		hub_choice_scroll = clampf(float(start), 0.0, float(max_start))
		return
	var count := _hub_active_list_count(root)
	if count <= 0:
		return
	var list_visible_count := ShopMenuLayoutScript.VISIBLE_ROWS if hub_page == HUB_PAGE_SHOP and hub_shop_menu != null else FusionMenuLayoutScript.FUSION_VISIBLE_ROWS if hub_page == HUB_PAGE_FUSION and hub_fusion_menu != null else maxi(hub_item_list_texts.size(), 1)
	# Controller browsing keeps the viewport fixed until the selection crosses
	# an edge: moving down past the final visible row advances the window, while
	# moving up past the first visible row retreats it. This prevents the list
	# from drifting as soon as the cursor moves away from the bottom.
	var max_scroll := maxf(0.0, float(count - list_visible_count))
	var window_start := int(floor(hub_list_scroll))
	if hub_item_index >= window_start + list_visible_count:
		window_start = hub_item_index - list_visible_count + 1
	elif hub_item_index < window_start:
		window_start = hub_item_index
	hub_list_scroll = clampf(float(window_start), 0.0, max_scroll)


## Applies the fractional item-list scroll to the row/button/price y positions.
func _apply_hub_item_scroll(pitch: float) -> void:
	_hub_legacy_widget_scroll_presenter.position_item_rows(_hub_responsive_layout_presenter, hub_list_scroll, pitch)


## Applies the fractional gear-choice scroll to the picker row positions.
func _apply_hub_choice_scroll(pitch: float) -> void:
	_hub_legacy_widget_scroll_presenter.position_gear_choices(_hub_responsive_layout_presenter, hub_choice_scroll, pitch)


## Resting idle for the hand cursor: it glides a few pixels to the right, then
## quickly flicks back left, looping forever. Horizontal only.
func _start_cursor_bob(cursor: Sprite2D) -> void:
	_menu_cursor_animator.start_cursor_bob(cursor, self)


func _kill_cursor_tween(cursor: Sprite2D) -> void:
	_menu_cursor_animator.kill_cursor_tween(cursor)
