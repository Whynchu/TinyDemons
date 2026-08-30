@tool
extends ColorRect

const EffectsSpawnerScript = preload("res://scripts/effects_spawner.gd")

const PAGE_TITLES := {
	"HubRootPage/Title": "DEMON HUB",
	"HubStatusPage/Title": "STATUS",
	"HubAllocatePage/Title": "ALLOCATE",
	"HubItemsPage/Title": "EQUIPMENT",
	"HubBindPage/Title": "BIND",
}


func _ready() -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return
	var renderer := EffectsSpawnerScript.new()
	for node_path: String in PAGE_TITLES:
		var title := get_node_or_null(node_path) as Sprite2D
		if title != null:
			title.texture = renderer.call("number_texture", PAGE_TITLES[node_path], Color.WHITE) as Texture2D
	renderer.free()
