@tool
extends RefCounted
class_name ItemVisualResolver

## Shared item drop presentation lookup. Typed definitions currently inherit
## the slot-level pickup art; this keeps runtime and editor previews in parity
## until per-item artwork becomes authoritative.

const ITEM_DROP_TEXTURE_PATHS: Dictionary = {
	&"weapon": "res://assets/artwork/sword_pickup.png",
	&"head": "res://assets/artwork/helm_pickup.png",
	&"body": "res://assets/artwork/armor_pickup.png",
	&"arm": "res://assets/artwork/hand_pickup.png",
	&"shield": "res://assets/artwork/shield_pickup.png",
	&"accessory": "res://assets/artwork/acc_pickup.png",
}

const ITEM_TYPE_LABELS: Dictionary = {
	&"weapon": "SWORD",
	&"head": "HEAD",
	&"body": "BODY",
	&"arm": "ARM",
	&"shield": "SHIELD",
	&"accessory": "ACCESSORY",
}


static func item_drop_texture(item: ItemInstance, catalog: ItemCatalog = null) -> Texture2D:
	if item == null:
		return null
	var items: ItemCatalog = catalog if catalog != null else ItemCatalog.new()
	var slot := items.definition_slot(item.definition_id)
	var path := str(ITEM_DROP_TEXTURE_PATHS.get(slot, ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


static func item_type_label(item: ItemInstance, catalog: ItemCatalog = null) -> String:
	if item == null:
		return "ITEM"
	var items: ItemCatalog = catalog if catalog != null else ItemCatalog.new()
	return str(ITEM_TYPE_LABELS.get(items.definition_slot(item.definition_id), "ITEM"))
