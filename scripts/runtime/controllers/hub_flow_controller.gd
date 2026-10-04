extends Node
class_name HubFlowController

const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")
const HubEconomyControllerScript = preload("res://scripts/runtime/controllers/hub_economy_controller.gd")
const HubScreenActionsScript = preload("res://scripts/ui/hub_screen_actions.gd")

var economy_controller: RefCounted = HubEconomyControllerScript.new()

const HUB_PAGE_COUNT := HubMenuStateScript.HUB_PAGE_COUNT
const HUB_PAGE_ALLOCATE := HubMenuStateScript.HUB_PAGE_ALLOCATE
const HUB_PAGE_STATS := HubMenuStateScript.HUB_PAGE_STATS
const HUB_PAGE_EQUIPMENT := HubMenuStateScript.HUB_PAGE_EQUIPMENT
const HUB_PAGE_SHOP := HubMenuStateScript.HUB_PAGE_SHOP
const HUB_PAGE_FUSION := HubMenuStateScript.HUB_PAGE_FUSION
const HUB_PAGE_BIND := HubMenuStateScript.HUB_PAGE_BIND
const HUB_PAGE_STATUS := HubMenuStateScript.HUB_PAGE_STATUS
# The reworked hub exposes only the four authored command cells.  Equipment is
# still a private Pause route, and STATUS remains a Pause-only page; neither
# should be reachable from the Demon Hub command rail.
const HUB_COMMAND_PAGE_TARGETS := HubMenuStateScript.HUB_COMMAND_PAGE_TARGETS

const EQUIPMENT_MODE_COMMAND := HubMenuStateScript.EQUIPMENT_MODE_COMMAND
const EQUIPMENT_MODE_SLOT_EQUIP := HubMenuStateScript.EQUIPMENT_MODE_SLOT_EQUIP
const EQUIPMENT_MODE_SLOT_REMOVE := HubMenuStateScript.EQUIPMENT_MODE_SLOT_REMOVE
const EQUIPMENT_MODE_CANDIDATE := HubMenuStateScript.EQUIPMENT_MODE_CANDIDATE
const EQUIPMENT_MODE_REMOVE_ALL_CONFIRM := HubMenuStateScript.EQUIPMENT_MODE_REMOVE_ALL_CONFIRM

const SHOP_STATE_MODE_SELECT := HubMenuStateScript.SHOP_STATE_MODE_SELECT
const SHOP_STATE_ITEM_BROWSE := HubMenuStateScript.SHOP_STATE_ITEM_BROWSE
const SHOP_STATE_SELL_AMOUNT := HubMenuStateScript.SHOP_STATE_SELL_AMOUNT



func build_hub_ui(root: Object) -> void:
	var screen_state_controller := root.screen_state_controller as ScreenStateController
	var actions := HubScreenActionsScript.from_gameplay_root(root as Node) as HubScreenActions
	actions.pause_set_page = func(page: int): screen_state_controller.set_pause_page(root, page)
	screen_state_controller.build_hub(root.ui, Callable(root, "_pixel_text_texture"), actions)
	var debug_session := root.get_node_or_null("DebugSessionController") as Node
	if debug_session != null:
		if not screen_state_controller.debug_page_requested.is_connected(Callable(debug_session, "open_page")):
			screen_state_controller.debug_page_requested.connect(Callable(debug_session, "open_page"))
		if not screen_state_controller.debug_action_requested.is_connected(Callable(debug_session, "handle_action")):
			screen_state_controller.debug_action_requested.connect(Callable(debug_session, "handle_action"))


func show_hub(root: Object, from_npc: bool = false, pause_mode: bool = false) -> void:
	if root.screen_state_controller.hub_overlay == null:
		return
	if pause_mode:
		open_pause_menu(root)
		return
	# Inventory and equipped-slot state can change while the hub is closed. The
	# fusion page is intentionally cached for UI reads, so refresh its eligibility
	# whenever the hub is opened instead of showing a stale duplicate list.
	invalidate_hub_fusion_candidates(root)
	root.screen_state_controller.hub_opened_from_npc = from_npc
	root.screen_state_controller.hub_pause_mode = false
	root.screen_state_controller.hub_is_root = true
	root.screen_state_controller.hub_interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	root.screen_state_controller.hub_cancel_input_was_down = bool(root.call("_is_menu_cancel_input_pressed"))
	root.screen_state_controller.hub_page_previous_input_was_down = bool(root.call("_is_hub_previous_page_input_pressed"))
	root.screen_state_controller.hub_page_next_input_was_down = bool(root.call("_is_hub_next_page_input_pressed"))
	if root.screen_state_controller.title_overlay != null: root.screen_state_controller.title_overlay.visible = false
	if root.screen_state_controller.archetype_overlay != null: root.screen_state_controller.archetype_overlay.visible = false
	if root.loading_screen_overlay != null: root.loading_screen_overlay.visible = false
	if root.game_over_overlay != null: root.game_over_overlay.visible = false
	root.screen_state_controller.hub_overlay.visible = true
	root.screen_state_controller.set_menu_world_hidden(root, true)
	if root.screen_state_controller.pause_overlay != null: root.screen_state_controller.pause_overlay.visible = false
	# STATS is the first (and default) command in the reworked hub. STATUS is
	# retained only as a compatibility page alias for older callers.
	root.screen_state_controller.hub_page = root.screen_state_controller.HUB_PAGE_STATS
	root.screen_state_controller.hub_item_index = 0
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.hub_content_focus = false
	root.screen_state_controller.hub_binding_message = ""
	root.call("_hub_cancel_stats", false)
	# Opening either full-screen menu uses the same authored Blip cue. Confirm is
	# reserved for actions taken after the Demon Hub is already open.
	root.call("_play_sound", "ui_pause", 0.0, 1.0)
	root.screen_state_controller.set_state(&"hub")
	root.call("_select_hub_menu_row", 0)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))


func open_pause_menu(root: Object) -> void:
	if root.player_dead or root.player_death_pending or root.screen_state_controller.pause_overlay == null or root.screen_state_controller.pause_overlay.visible or (root.screen_state_controller.hub_overlay != null and root.screen_state_controller.hub_overlay.visible):
		return
	root.screen_state_controller.pause_input_was_down = true
	root.screen_state_controller.hub_pause_mode = true
	root.screen_state_controller.hub_item_index = 0
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	root.screen_state_controller.pause_page = 0
	root.screen_state_controller.hub_is_root = true
	root.screen_state_controller.pause_menu_row = 0
	root.screen_state_controller.pause_interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	root.screen_state_controller.pause_cancel_input_was_down = bool(root.call("_is_menu_cancel_input_pressed"))
	root.screen_state_controller.hub_overlay.visible = false
	if root.screen_state_controller.title_overlay != null: root.screen_state_controller.title_overlay.visible = false
	if root.screen_state_controller.archetype_overlay != null: root.screen_state_controller.archetype_overlay.visible = false
	root.screen_state_controller.pause_overlay.visible = true
	root.screen_state_controller.set_menu_world_hidden(root, true)
	root.screen_state_controller.set_state(&"pause")
	root.screen_state_controller.update_pause_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_pause", 0.0, 1.0)


func open_hub_from_cloaked_demon(root: Object) -> void:
	if root.player_dead or root.screen_state_controller.hub_overlay == null:
		return
	if root.npc_controller.dialogue_box != null and root.npc_controller.dialogue_box.visible:
		root.npc_controller.hide_dialogue(root)
	root.player_is_moving = false
	root.player_is_attacking = false
	root.player_is_rolling = false
	root.player_is_backflipping = false
	root.player_attack_visual.visible = false
	root.interact_prompt.visible = false
	show_hub(root, true)


func close_hub_to_run(root: Object) -> void:
	if root.screen_state_controller.hub_overlay == null and root.screen_state_controller.pause_overlay == null:
		return
	var was_pause: bool = bool(root.screen_state_controller.hub_pause_mode) or (root.screen_state_controller.pause_overlay != null and root.screen_state_controller.pause_overlay.visible)
	root.call("_hub_cancel_stats", false)
	HubMenuStateScript.set_equipment_mode(root.screen_state_controller, EQUIPMENT_MODE_COMMAND)
	root.screen_state_controller.menu_input_release_lock = bool(root.call("_is_menu_cancel_input_pressed"))
	if root.screen_state_controller.hub_overlay != null: root.screen_state_controller.hub_overlay.visible = false
	if root.screen_state_controller.pause_overlay != null: root.screen_state_controller.pause_overlay.visible = false
	root.screen_state_controller.set_menu_world_hidden(root, false)
	root.screen_state_controller.hub_opened_from_npc = false
	root.screen_state_controller.hub_pause_mode = false
	root.screen_state_controller.hub_is_root = true
	root.screen_state_controller.hub_shop_sell_mode = false
	root.screen_state_controller.hub_shop_state = SHOP_STATE_MODE_SELECT
	root.screen_state_controller.hub_shop_sell_amount = 1
	root.screen_state_controller.hub_shop_sell_amount_max = 1
	root.screen_state_controller.hub_action_column = 0
	root.screen_state_controller.pause_page = 0
	HubMenuStateScript.clear_touch_candidate(root.screen_state_controller)
	root.screen_state_controller.pause_interact_input_was_down = false
	root.screen_state_controller.pause_cancel_input_was_down = false
	root.interact_input_was_down = bool(root.call("_is_interact_input_pressed"))
	root.screen_state_controller.set_state(&"gameplay")
	# Pause uses the same explicit BACK affordance as every other menu route.
	# Keep the legacy unpause cue for the preparation hub, which is opened from
	# the Cloaked Demon rather than from the pause action.
	root.call("_play_sound", "ui_decline" if was_pause else "ui_unpause", 0.0, 1.0)
	if was_pause:
		return


func set_hub_page(root: Object, page: int) -> void:
	var screen: Object = root.screen_state_controller
	if page < 0:
		HubMenuStateScript.set_property_if_available(screen, &"hub_is_root", true)
		root.call("_hub_cancel_stats", false)
		HubMenuStateScript.set_property_if_available(screen, &"hub_stat_row", 0)
		HubMenuStateScript.set_property_if_available(screen, &"hub_item_index", 0)
		HubMenuStateScript.set_property_if_available(screen, &"hub_list_scroll", 0.0)
		HubMenuStateScript.set_property_if_available(screen, &"hub_choice_scroll", 0.0)
		HubMenuStateScript.set_property_if_available(screen, &"hub_fusion_count", 1)
		HubMenuStateScript.set_property_if_available(screen, &"hub_fusion_message", "")
		HubMenuStateScript.set_property_if_available(screen, &"hub_binding_message", "")
		HubMenuStateScript.set_property_if_available(screen, &"hub_shop_state", SHOP_STATE_MODE_SELECT)
		HubMenuStateScript.set_property_if_available(screen, &"hub_shop_sell_amount", 1)
		HubMenuStateScript.set_property_if_available(screen, &"hub_shop_sell_amount_max", 1)
		HubMenuStateScript.set_property_if_available(screen, &"hub_content_focus", false)
		HubMenuStateScript.set_equipment_mode(screen, EQUIPMENT_MODE_COMMAND)
		HubMenuStateScript.clear_touch_candidate(screen)
		screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
		return
	HubMenuStateScript.set_property_if_available(screen, &"hub_is_root", false)
	# The old STATUS route is now represented by the merged STATS page. Keep
	# accepting the numeric alias so older callers do not land on a blank page.
	var requested_page := posmod(page, HUB_PAGE_COUNT)
	if requested_page == HUB_PAGE_STATUS:
		requested_page = HUB_PAGE_STATS
	screen.hub_page = requested_page
	var command_index: int = int(HUB_COMMAND_PAGE_TARGETS.find(screen.hub_page))
	if command_index >= 0: HubMenuStateScript.set_property_if_available(screen, &"hub_menu_row", command_index)
	HubMenuStateScript.set_property_if_available(screen, &"hub_item_index", 0)
	HubMenuStateScript.clear_touch_candidate(screen)
	HubMenuStateScript.set_property_if_available(screen, &"hub_list_scroll", 0.0)
	HubMenuStateScript.set_property_if_available(screen, &"hub_shop_sell_confirm_pending", false)
	HubMenuStateScript.set_property_if_available(screen, &"hub_shop_state", SHOP_STATE_MODE_SELECT)
	HubMenuStateScript.set_property_if_available(screen, &"hub_shop_sell_amount", 1)
	HubMenuStateScript.set_property_if_available(screen, &"hub_shop_sell_amount_max", 1)
	HubMenuStateScript.set_property_if_available(screen, &"hub_shop_command_focus", screen.hub_page == HUB_PAGE_SHOP)
	HubMenuStateScript.set_property_if_available(screen, &"hub_choice_scroll", 0.0)
	# Fusion opens on a non-selected target preview. Confirming the preview
	# enters target browsing, where the footer becomes FUSE.
	HubMenuStateScript.set_property_if_available(screen, &"hub_fusion_state", 1 if screen.hub_page == HUB_PAGE_FUSION else 0)
	HubMenuStateScript.set_property_if_available(screen, &"hub_fusion_item_selected", false)
	HubMenuStateScript.set_property_if_available(screen, &"hub_binding_state", 1 if screen.hub_page == HUB_PAGE_BIND else 0)
	# Equipment has a deliberate three-step route. Entering the page always
	# lands on its top command row; Equip then descends into slots and finally
	# into the item list. Other transaction pages retain their normal content
	# focus behavior.
	var equipment_page: bool = screen.hub_page == HUB_PAGE_EQUIPMENT
	# Every command confirm enters its content. Equipment's first content level
	# is still its command row; the other three routes enter their list/stat
	# focus directly.
	# Confirming a command enters its content. STATS enters the allocation list
	# directly with its cursor on the first row (VIT). Equipment keeps its own
	# command-rail entry behavior.
	if screen.hub_page == HUB_PAGE_ALLOCATE:
		HubMenuStateScript.set_property_if_available(screen, &"hub_content_focus", true)
		HubMenuStateScript.set_property_if_available(screen, &"hub_stat_row", 0)
	elif screen.hub_page == HUB_PAGE_SHOP:
		HubMenuStateScript.set_property_if_available(screen, &"hub_content_focus", false)
	else:
		HubMenuStateScript.set_property_if_available(screen, &"hub_content_focus", true)
	HubMenuStateScript.set_equipment_mode(screen, EQUIPMENT_MODE_COMMAND if equipment_page else EQUIPMENT_MODE_SLOT_EQUIP)
	# SHOP remembers its last BUY/SELL choice while the hub stays open. A full
	# hub close clears it below, so a new hub session still starts on BUY.
	var sell_mode := bool(HubMenuStateScript.get_property_if_available(screen, &"hub_shop_sell_mode", false))
	HubMenuStateScript.set_property_if_available(screen, &"hub_action_column", 1 if screen.hub_page == HUB_PAGE_SHOP and sell_mode else 0)
	HubMenuStateScript.set_property_if_available(screen, &"hub_fusion_message", "")
	HubMenuStateScript.set_property_if_available(screen, &"hub_binding_message", "")
	HubMenuStateScript.set_property_if_available(screen, &"hub_fusion_count", 1)
	if screen.hub_page == HUB_PAGE_FUSION:
		invalidate_hub_fusion_candidates(root)
	if root.run_state != null and screen.hub_page == HUB_PAGE_SHOP:
		root.run_state.ensure_shop_stock(root.player_profile)
	root.screen_state_controller.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	# Entering Equipment is a deliberate command-rail selection, so it gets the
	# confirm open tone rather than the quiet hover used for simple page turns.
	root.call("_play_sound", "ui_confirm" if equipment_page else "ui_hover", -6.0, 1.0)


func back_to_hub_root(root: Object) -> void:
	var screen: Object = root.screen_state_controller
	if screen.hub_is_root:
		close_hub_to_run(root)
		return
	screen.hub_is_root = true
	root.call("_hub_cancel_stats", false)
	screen.hub_stat_row = 0
	screen.hub_item_index = 0
	screen.hub_list_scroll = 0.0
	screen.hub_choice_scroll = 0.0
	screen.hub_fusion_count = 1
	screen.hub_fusion_state = 0
	screen.hub_fusion_item_selected = false
	screen.hub_binding_state = 0
	screen.hub_fusion_message = ""
	# Keep the selected command preview when returning to the top shell. This is
	# important for the reworked hub: backing out of SHOP/FUSION/BIND should show
	# that command's content again, not reset the player to a stale STATUS page.
	if screen.hub_page == screen.HUB_PAGE_EQUIPMENT or screen.hub_page == screen.HUB_PAGE_STATUS:
		screen.hub_page = screen.HUB_PAGE_STATS
	var command_index := int(HUB_COMMAND_PAGE_TARGETS.find(screen.hub_page))
	if command_index >= 0:
		screen.hub_menu_row = command_index
	screen.hub_content_focus = false
	HubMenuStateScript.set_equipment_mode(screen, EQUIPMENT_MODE_COMMAND)
	HubMenuStateScript.clear_touch_candidate(screen)
	screen.hub_binding_message = ""
	screen.hub_fusion_state = 0
	screen.hub_fusion_item_selected = false
	screen.hub_binding_state = 0
	screen.update_hub_ui(root, Callable(root, "_pixel_text_texture"))
	root.call("_play_sound", "ui_decline", 0.0, 1.0)


