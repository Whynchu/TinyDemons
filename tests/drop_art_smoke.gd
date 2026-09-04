extends SceneTree

const PickupRuntime = preload("res://scripts/pickup_runtime_controller.gd")


func _initialize() -> void:
	var failures: Array[String] = []
	var catalog := ItemCatalog.new()
	var pickup := PickupRuntime.new()
	var expected_by_slot := {
		&"weapon": "sword_pickup.png",
		&"head": "helm_pickup.png",
		&"body": "armor_pickup.png",
		&"arm": "hand_pickup.png",
		&"shield": "shield_pickup.png",
		&"accessory": "acc_pickup.png",
	}
	var covered: Dictionary = {}
	var total := 0
	for slot in ItemCatalog.SLOTS:
		for definition_id in catalog.definitions_for_slot(slot):
			var item := ItemInstance.new()
			item.definition_id = definition_id
			item.rarity = &"common"
			var actual_slot := catalog.definition_slot(definition_id)
			var tex := pickup.item_drop_texture(item)
			var is_placeholder := tex is ImageTexture and tex.get_width() == 6 and tex.get_height() == 6
			if is_placeholder:
				_expect(false, "%s (%s) resolves to the placeholder" % [definition_id, slot], failures)
			var file := str(tex.resource_path).get_file() if tex != null and not str(tex.resource_path).is_empty() else "null"
			var expected: String = String(expected_by_slot.get(actual_slot, "MISSING"))
			_expect(file == expected, "%s (%s) uses %s, expected %s" % [definition_id, actual_slot, file, expected], failures)
			covered[actual_slot] = int(covered.get(actual_slot, 0)) + 1
			total += 1
	for slot in ItemCatalog.SLOTS:
		_expect(covered.get(slot, 0) > 0, "slot %s has drop art coverage" % slot, failures)
	_expect(total >= 66, "full catalogue checked (%d definitions)" % total, failures)
	if failures.is_empty():
		print("DROP_ART_SMOKE_OK")
		quit(0)
	else:
		for failure: String in failures:
			push_error("FAILED: %s" % failure)
		quit(1)


func _expect(condition: bool, label: String, failures: Array[String]) -> void:
	if not condition:
		failures.append(label)