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
const ScreenStateFlowControllerScript = preload("res://scripts/ui/screen_state_flow_controller.gd")
const ScreenRouteControllerScript = preload("res://scripts/ui/screen_route_controller.gd")
const HubListScrollControllerScript = preload("res://scripts/ui/hub_list_scroll_controller.gd")
const ScreenLayoutControllerScript = preload("res://scripts/ui/screen_layout_controller.gd")
const ScreenAssemblyControllerScript = preload("res://scripts/ui/screen_assembly_controller.gd")
const HubScreenSetupControllerScript = preload("res://scripts/ui/hub_screen_setup_controller.gd")
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
const PauseDebugMenuContextScript = preload("res://scripts/ui/pause_debug_menu_context.gd")
const MENU_CIRCLE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_CIRCLE_TEXTURE
const MENU_X_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_X_TEXTURE
const MENU_TRIANGLE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_TRIANGLE_TEXTURE
const MENU_SQUARE_TEXTURE: Texture2D = MenuPromptTextureFactoryScript.MENU_SQUARE_TEXTURE
const GAME_VERSION := "0.3.55"
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
const PauseMenuStateScript = preload("res://scripts/ui/pause_menu_state.gd")
const PauseMenuInputControllerScript = preload("res://scripts/ui/pause_menu_input_controller.gd")
const HubScreenRenderControllerScript = preload("res://scripts/ui/hub_screen_render_controller.gd")
const HubLegacyInventoryPresenterScript = preload("res://scripts/ui/hub_legacy_inventory_presenter.gd")
const HubLegacyWidgetBuilderScript = preload("res://scripts/ui/hub_legacy_widget_builder.gd")
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

func _init() -> void:
	_screen_state_flow_controller.bind(self)
	_screen_route_controller.bind(self)
	_hub_list_scroll_controller.bind(self)
	_screen_layout_controller.bind(self)
	_hub_screen_setup_controller.bind(self)
	_screen_assembly_controller.bind(self)


var state: StringName = &"gameplay"
var _title_particle_controller: TitleParticleController = TitleParticleControllerScript.new() as TitleParticleController
var _screen_state_flow_controller = ScreenStateFlowControllerScript.new()
var state_flow_controller: Variant = _screen_state_flow_controller
var _screen_route_controller = ScreenRouteControllerScript.new()
var route_controller: Variant = _screen_route_controller
var _hub_list_scroll_controller = HubListScrollControllerScript.new()
var _screen_layout_controller = ScreenLayoutControllerScript.new()
var layout_controller = _screen_layout_controller
var _hub_screen_setup_controller = HubScreenSetupControllerScript.new()
var _screen_assembly_controller = ScreenAssemblyControllerScript.new()
var assembly_controller = _screen_assembly_controller
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
var title_presenter: TitleScreenPresenter:
	get: return _title_screen_presenter
var archetype_presenter: ArchetypeScreenPresenter:
	get: return _archetype_screen_presenter
var save_select_presenter: SaveSelectScreenPresenter:
	get: return _save_select_screen_presenter
var name_entry_controller: NameEntryScreenController:
	get: return _name_entry_screen_controller
var settings_presenter: SettingsScreenPresenter:
	get: return _settings_screen_presenter
var game_over_presenter: GameOverScreenPresenter:
	get: return _game_over_screen_presenter
var run_complete_presenter: RunCompleteScreenPresenter:
	get: return _run_complete_screen_presenter
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
var _pause_menu_state: PauseMenuState = PauseMenuStateScript.new() as PauseMenuState
var _pause_menu_input_controller: PauseMenuInputController = PauseMenuInputControllerScript.new() as PauseMenuInputController
var _hub_screen_render_controller = HubScreenRenderControllerScript.new()
var _hub_legacy_inventory_presenter = HubLegacyInventoryPresenterScript.new()
var _hub_legacy_widget_builder = HubLegacyWidgetBuilderScript.new()
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
var pause_input_was_down: bool:
	get: return _pause_menu_state.pause_input_was_down
	set(value): _pause_menu_state.pause_input_was_down = value
var pause_interact_input_was_down: bool:
	get: return _pause_menu_state.pause_interact_input_was_down
	set(value): _pause_menu_state.pause_interact_input_was_down = value
var pause_cancel_input_was_down: bool:
	get: return _pause_menu_state.pause_cancel_input_was_down
	set(value): _pause_menu_state.pause_cancel_input_was_down = value
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
var hub_shop_sell_target_key: String:
	get: return _hub_menu_state.hub_shop_sell_target_key
	set(value): _hub_menu_state.hub_shop_sell_target_key = value
var hub_shop_cursor: Sprite2D:
	get: return _hub_responsive_layout_presenter.hub_shop_cursor
	set(value): _hub_responsive_layout_presenter.hub_shop_cursor = value
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
var hub_fusion_target_instance_id: String:
	get: return _hub_menu_state.hub_fusion_target_instance_id
	set(value): _hub_menu_state.hub_fusion_target_instance_id = value
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
var pause_page: int:
	get: return _pause_menu_state.pause_page
	set(value): _pause_menu_state.pause_page = value
var pause_root_page: Control:
	get: return _pause_screen_presenter.root_page
	set(value): _pause_screen_presenter.root_page = value
var pause_page_roots: Dictionary:
	get: return _pause_screen_presenter.page_roots
	set(value): _pause_screen_presenter.page_roots = value
var pause_menu_row: int:
	get: return _pause_menu_state.pause_menu_row
	set(value): _pause_menu_state.pause_menu_row = value
var pause_command_list: MenuCommandList:
	get: return _pause_menu_state.command_list
	set(value): _pause_menu_state.command_list = value
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
var debug_menu_layout: DebugMenuLayout:
	get: return _pause_screen_presenter.debug_menu_layout
	set(value): _pause_screen_presenter.debug_menu_layout = value
var debug_menu_buttons: Array[Button]:
	get: return _pause_screen_presenter.debug_menu_buttons
	set(value): _pause_screen_presenter.debug_menu_buttons = value
var debug_menu_row: int:
	get: return _pause_menu_state.debug_menu_row
	set(value): _pause_menu_state.debug_menu_row = value
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
var pause_equipment_menu: EquipmentMenuLayout:
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
var title_particle_layer: Node2D = null
var save_select_mode := "continue"
var save_select_index := 0
var save_overwrite_slot := 0
var save_overwrite_prompt_active := false
var save_overwrite_choice := 0
var save_recovery_prompt_active := false
const NAME_ENTRY_COLUMNS := NameEntryWidgetPresenterScript.NAME_ENTRY_COLUMNS
const NAME_ENTRY_ROWS := NameEntryWidgetPresenterScript.NAME_ENTRY_ROWS
var player_palette_name := "blue"
var display_view_size := Vector2(DisplayLayout.NATIVE_SIZE)
var _display_layout_refreshing := false


# --- Shared screen-state routing ---
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


# --- Game-over and run-complete screens ---
func build_hub(parent: Node, pixel_texture: Callable, actions: HubScreenActions) -> void:
	_hub_screen_setup_controller.build_hub(parent, pixel_texture, actions)

func _set_hub_action_column(index: int) -> void:
	_hub_screen_setup_controller._set_hub_action_column(index)

func _select_hub_shop_mode(index: int) -> void:
	_hub_screen_setup_controller._select_hub_shop_mode(index)

func _forward_pause_debug_page_requested() -> void:
	_hub_screen_setup_controller._forward_pause_debug_page_requested()

func _forward_pause_debug_action_requested(action: StringName, amount: int) -> void:
	_hub_screen_setup_controller._forward_pause_debug_action_requested(action, amount)

# --- Legacy hub presenters and shop calculations ---
func _hide_legacy_equipment_presenter() -> void:
	_hub_legacy_widget_visibility_presenter.hide_equipment_legacy(_hub_responsive_layout_presenter)


func _hide_legacy_shop_presenter() -> void:
	_hub_legacy_widget_visibility_presenter.hide_shop_legacy(_hub_responsive_layout_presenter)


# --- Hub binding and equipment presentation ---
func is_pause_equipment_active() -> bool:
	return _screen_route_controller.is_pause_equipment_active()


func refresh_equipment_menu(root: Object) -> void:
	_screen_route_controller.refresh_equipment_menu(root)


func update_hub_ui(root: GameplayState, pixel_texture: Callable) -> void:
	_hub_screen_render_controller.bind(self as Node)
	_hub_legacy_inventory_presenter.bind(self as Node)
	_hub_screen_render_controller.update_hub_ui(root, pixel_texture)


func update_hub_input(root: GameplayState) -> void:
	_hub_input_controller.update(
		root,
		_hub_menu_state,
		Callable(self, "update_hub_ui"),
		Callable(self, "scroll_hub_content")
	)

# --- Title screen construction and layout ---
func refresh_title_menu_layout(has_profile: bool) -> void:
	_title_screen_presenter.refresh_menu_layout(has_profile)


func set_hud_visibility(root: GameplayState, is_visible: bool) -> void:
	if root.ui == null:
		return
	var player_hud := root.ui.get_node_or_null("PlayerHud") as CanvasItem
	if player_hud != null:
		player_hud.visible = is_visible


func _menu_uses_face_art(root: Object) -> bool:
	if root == null or not root.has_method("_menu_confirm_prompt"):
		return false
	return str(root.call("_menu_confirm_prompt")).begins_with("O ")


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
	_screen_route_controller._update_settings_cursor()


# --- Save-select and name-entry screen construction ---
# --- Name-entry state, touch selection, and input ---
func show_name_entry(root: Object, pending_slot: int) -> void:
	if name_entry_controller.widgets.overlay == null:
		return
	_name_entry_screen_controller.begin(pending_slot)
	if title_presenter.overlay != null: title_presenter.overlay.visible = false
	if save_select_presenter.overlay != null: save_select_presenter.overlay.visible = false
	if archetype_presenter.overlay != null: archetype_presenter.overlay.visible = false
	name_entry_controller.widgets.overlay.visible = true
	name_entry_controller.widgets.overlay.modulate.a = 1.0
	menu_input_release_lock = true
	set_state(&"name_entry")
	if name_entry_controller.widgets.overlay != null:
		_name_entry_screen_controller.update_visuals(Callable(root, "_pixel_text_texture"), player_palette_name, _menu_confirm_prompt_for(root), _menu_back_prompt_for(root), _menu_prompt_texture_factory, display_view_size, _menu_cursor_animator, self)


func cancel_name_entry(root: Object) -> void:
	_name_entry_screen_controller.cancel()
	menu_input_release_lock = true
	if save_select_presenter.overlay != null:
		save_select_presenter.overlay.visible = true
		if title_presenter.overlay != null: title_presenter.overlay.visible = true
		set_state(&"title")
		root.call("_update_save_select_cursor")
	else:
		if title_presenter.overlay != null: title_presenter.overlay.visible = true
		set_state(&"title")
	if root.has_method("_play_sound"): root.call("_play_sound", "ui_decline", 0.0, 1.0)


func _activate_name_entry_cell(index: int) -> void:
	_name_entry_screen_controller.activate_cell(index)


func update_name_entry_input(root: Object) -> void:
	if name_entry_controller.widgets.overlay == null or not name_entry_controller.widgets.overlay.visible:
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
# --- Shared widget and hub-scroll compatibility facades ---
## Browser-style list scrolling: a touch drag moves the list CONTENT, never the
## cursor. Positive delta is finger movement downward (content follows the
## finger, revealing earlier rows).
func scroll_hub_content(root: Object, delta_px: float) -> void:
	_hub_list_scroll_controller.scroll_hub_content(root, delta_px)

func _hub_active_list_count(root: Object) -> int:
	return _hub_list_scroll_controller._hub_active_list_count(root)

func snap_hub_list_scroll_to_selection(root: Object) -> void:
	_hub_list_scroll_controller.snap_hub_list_scroll_to_selection(root)

func _apply_hub_item_scroll(pitch: float) -> void:
	_hub_list_scroll_controller._apply_hub_item_scroll(pitch)

func _apply_hub_choice_scroll(pitch: float) -> void:
	_hub_list_scroll_controller._apply_hub_choice_scroll(pitch)

func _start_cursor_bob(cursor: Sprite2D) -> void:
	_hub_list_scroll_controller._start_cursor_bob(cursor)

func _kill_cursor_tween(cursor: Sprite2D) -> void:
	_hub_list_scroll_controller._kill_cursor_tween(cursor)
