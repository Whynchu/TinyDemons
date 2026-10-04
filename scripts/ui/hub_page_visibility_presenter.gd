extends RefCounted
class_name HubPageVisibilityPresenter

const HubMenuStateScript = preload("res://scripts/ui/hub_menu_state.gd")

var root_page: Control = null
var status_page: Control = null
var allocate_page: Control = null
var items_page: Control = null
var bind_page: Control = null
var page_roots: Dictionary = {}


func build_pages(overlay: Control, pixel_texture: Callable) -> void:
	root_page = overlay.get_node_or_null("HubRootPage") as Control
	status_page = overlay.get_node_or_null("HubStatusPage") as Control
	allocate_page = overlay.get_node_or_null("HubAllocatePage") as Control
	items_page = overlay.get_node_or_null("HubItemsPage") as Control
	bind_page = overlay.get_node_or_null("HubBindPage") as Control
	page_roots = {
		HubMenuStateScript.HUB_PAGE_STATUS: status_page,
		HubMenuStateScript.HUB_PAGE_ALLOCATE: allocate_page,
		HubMenuStateScript.HUB_PAGE_EQUIPMENT: items_page,
		HubMenuStateScript.HUB_PAGE_SHOP: items_page,
		HubMenuStateScript.HUB_PAGE_FUSION: items_page,
		HubMenuStateScript.HUB_PAGE_BIND: bind_page,
	}
	_set_page_title(root_page, "DEMON HUB", pixel_texture)
	_set_page_title(status_page, "STATUS", pixel_texture)
	_set_page_title(allocate_page, "ALLOCATE", pixel_texture)
	_set_page_title(items_page, "EQUIPMENT", pixel_texture)
	_set_page_title(bind_page, "BIND", pixel_texture)
	for page_root: Control in [status_page, allocate_page, items_page, bind_page]:
		if page_root != null:
			page_root.visible = false
	# Runtime presenters own the live profile-dependent copies. Keep the authored
	# legacy cards in the tree for probes, but hide their full-screen chrome.
	if root_page != null:
		for chrome_name in ["TitleTab", "TitleRule"]:
			var root_chrome := root_page.get_node_or_null(chrome_name) as CanvasItem
			if root_chrome != null:
				root_chrome.visible = false
	for page_root: Control in [status_page, allocate_page, items_page, bind_page]:
		if page_root == null:
			continue
		for chrome_name in ["Background", "TitleTab", "Title", "TitleRule"]:
			var page_chrome := page_root.get_node_or_null(chrome_name) as CanvasItem
			if page_chrome != null:
				page_chrome.visible = false


func show_page(overlay: Control, page: int) -> void:
	if root_page != null:
		root_page.visible = true
	for page_root: Control in [status_page, allocate_page, items_page, bind_page]:
		if page_root != null:
			page_root.visible = false
	var active_page := page_roots.get(page) as Control
	if active_page != null:
		active_page.visible = true
	if root_page != null:
		root_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if overlay == null:
		return
	var root_panel := overlay.get_node_or_null("HubPanel8Piece") as Control
	if root_panel != null:
		root_panel.visible = false


func prepare_fusion_visibility(page: int, fusion_menu: Control) -> void:
	# Fusion is nested under the shared Items page, so hide it before page-specific
	# update branches can return early for another route.
	if fusion_menu == null:
		return
	fusion_menu.visible = page == HubMenuStateScript.HUB_PAGE_FUSION
	if page != HubMenuStateScript.HUB_PAGE_FUSION and fusion_menu.has_method("stop_cursor_motion"):
		fusion_menu.call("stop_cursor_motion")


func update_transaction_menu_visibility(
	page: int,
	content_focus: bool,
	is_root: bool,
	equipment_menu: Control,
	shop_menu: Control,
	fusion_menu: Control,
	back_button: Button,
	pixel_texture: Callable
) -> bool:
	var equipment_view_active := page == HubMenuStateScript.HUB_PAGE_EQUIPMENT and content_focus and equipment_menu != null
	if equipment_menu != null:
		equipment_menu.visible = equipment_view_active
		if equipment_menu.has_method("stop_cursor_motion"):
			equipment_menu.call("stop_cursor_motion")
		if equipment_view_active and equipment_menu.has_method("set_pixel_texture"):
			equipment_menu.call("set_pixel_texture", pixel_texture)
	var shop_view_active := page == HubMenuStateScript.HUB_PAGE_SHOP and shop_menu != null
	if shop_menu != null:
		shop_menu.visible = shop_view_active
		if not shop_view_active and shop_menu.has_method("stop_cursor_motion"):
			shop_menu.call("stop_cursor_motion")
		elif shop_view_active and shop_menu.has_method("set_root_preview_mode"):
			# Nested Shop controls are owned only after the command is entered.
			shop_menu.call("set_root_preview_mode", is_root)
	var equipment_page_root := page_roots.get(HubMenuStateScript.HUB_PAGE_EQUIPMENT) as Control
	if equipment_page_root != null:
		# The authored Equipment scene provides its own full-width frame.
		for chrome_name in ["Background", "TitleTab", "Title", "TitleRule"]:
			var chrome := equipment_page_root.get_node_or_null(chrome_name) as CanvasItem
			if chrome != null:
				chrome.visible = false
	if back_button != null:
		back_button.visible = true
		back_button.modulate.a = 0.0
		# Authored Shop/Fusion views own their own Back and sell-cancel regions.
		var authored_transaction_back := (page == HubMenuStateScript.HUB_PAGE_SHOP and shop_menu != null) or (page == HubMenuStateScript.HUB_PAGE_FUSION and fusion_menu != null)
		back_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if authored_transaction_back else Control.MOUSE_FILTER_STOP
	return equipment_view_active


func _set_page_title(page: Control, title: String, pixel_texture: Callable) -> void:
	if page == null:
		return
	var title_sprite := page.get_node_or_null("Title") as Sprite2D
	if title_sprite != null:
		title_sprite.texture = pixel_texture.call(title, Color.WHITE) as Texture2D
