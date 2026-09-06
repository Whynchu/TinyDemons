extends SceneTree

const FusionMenuLayoutScript = preload("res://scripts/fusion_menu_layout.gd")
const FusionMenuModelScript = preload("res://scripts/fusion_menu_model.gd")

var _finished := false
var _item_row := -1
var _count_delta := 0
var _action_presses := 0
var _back_presses := 0

func _initialize() -> void:
	call_deferred("_watchdog")
	var failures: Array[String] = []
	var scene := load("res://scenes/fusion_menu.tscn") as PackedScene
	_expect(scene != null, "Fusion scene loads", failures)
	if scene == null:
		quit(1)
		return
	var fusion := scene.instantiate() as Control
	get_root().add_child(fusion)
	_expect(fusion is FusionMenuLayoutScript, "Fusion uses the Shop-derived layout adapter", failures)
	_expect(fusion.get_node_or_null("ShopListPanel") != null and fusion.get_node_or_null("ShopStatsPanel") != null, "Fusion keeps the two independent Shop panels", failures)
	_expect(fusion.get_node_or_null("ListClip") != null and (fusion.get_node("ListClip") as Control).clip_contents, "Fusion keeps the clipped item list", failures)
	_expect(fusion.get_node_or_null("ListClip/SellRowSoulAmount0") != null and fusion.get_node_or_null("ListClip/SellRowSoulIcon0") != null, "Fusion uses the Shop Soul amount and icon row", failures)
	_expect(fusion.get_node_or_null("OwnedText") != null and fusion.get_node_or_null("SellQuestionText") != null, "Fusion uses the Shop owned and amount footer", failures)
	_expect(fusion.get_node_or_null("ModeBuyButton") != null and fusion.get_node_or_null("ModeSellButton") != null, "Fusion inherits Shop mode nodes for adapter suppression", failures)
	var layout := fusion as FusionMenuLayoutScript
	_expect(layout.visible_row_capacity() == 10, "Fusion exposes exactly ten visible item rows", failures)
	var overflow_button := fusion.get_node_or_null("ListClip/ItemButton10") as Button
	_expect(overflow_button == null or (not overflow_button.visible and overflow_button.mouse_filter == Control.MOUSE_FILTER_IGNORE), "Fusion overflow row is hidden and not touch-reachable", failures)
	_expect(layout.has_signal("item_action_pressed") and layout.has_signal("sell_amount_confirmed"), "Fusion exposes shared select and amount signals", failures)
	var browse_model := FusionMenuModelScript.new()
	browse_model.state = 1
	browse_model.rows = [{"label": "IRON SWORD", "slot": "weapon", "soul_cost": 4}]
	browse_model.selected_row = 0
	layout.render_fusion(browse_model)
	var fusion_button := fusion.get_node("SellConfirmButton") as Button
	_expect(fusion_button.visible and not fusion_button.disabled and fusion_button.mouse_filter == Control.MOUSE_FILTER_STOP, "Fusion SELECT footer has an active native touch target", failures)
	var amount_model := FusionMenuModelScript.new()
	amount_model.state = 2
	amount_model.item_selected = true
	amount_model.rows = browse_model.rows
	amount_model.selected_row = 0
	layout.render_fusion(amount_model)
	_expect(fusion_button.visible and not fusion_button.disabled and (fusion.get_node("SellCancelButton") as Button).visible, "Fusion amount footer keeps FUSE and BACK touch targets active", failures)
	layout.item_pressed.connect(func(index: int): _item_row = index)
	layout.sell_amount_changed.connect(func(delta: int): _count_delta += delta)
	layout.item_action_pressed.connect(func(): _action_presses += 1)
	layout.shop_back_pressed.connect(func(): _back_presses += 1)
	(fusion.get_node("ListClip/ItemButton2") as Button).pressed.emit()
	(fusion.get_node("SellPlusButton") as Button).pressed.emit()
	(fusion.get_node("SellConfirmButton") as Button).pressed.emit()
	(fusion.get_node("SellCancelButton") as Button).pressed.emit()
	(fusion.get_node("ShopBackButton") as Button).pressed.emit()
	_expect(_item_row == 2 and _count_delta == 1, "Fusion row and quantity signals retain Shop interaction wiring", failures)
	_expect(_action_presses == 1 and _back_presses == 2, "Fusion action and back signals are available to the hub route", failures)
	fusion.queue_free()
	_finished = true
	if failures.is_empty():
		print("FUSION_MENU_SCENE_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		quit(1)

func _watchdog() -> void:
	if _finished:
		return
	push_error("TEST_ABORTED: Fusion scene smoke failed before completion")
	quit(1)

func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append("FAILED: %s" % label)
